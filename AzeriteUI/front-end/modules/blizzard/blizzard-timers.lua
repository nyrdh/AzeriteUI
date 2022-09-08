local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end
local Module = Core:NewModule("BlizzardTimers", "LibMessage", "LibEvent", "LibSecureHook", "LibFrame", "LibStatusBar")

-- Lua API
local _G = _G
local math_floor = math.floor
local table_insert = table.insert
local table_sort = table.sort
local table_wipe = table.wipe
local unpack = unpack

-- WoW API
local GetAlternatePowerInfoByID = GetAlternatePowerInfoByID
local GetTime = GetTime
local GetUnitPowerBarInfo = GetUnitPowerBarInfo
local GetUnitPowerBarInfoByID = GetUnitPowerBarInfoByID
local GetUnitPowerBarStringsByID = GetUnitPowerBarStringsByID
local UnitPowerBarTimerInfo = UnitPowerBarTimerInfo

-- Private API
local GetLayout = Private.GetLayout
local IsClassic = Private.IsClassic
local IsTBC = Private.IsTBC
local IsRetail = Private.IsRetail

-- WoW Constants
local ALT_POWER_TYPE_COUNTER = ALT_POWER_TYPE_COUNTER or 4

-- Deprecated API
-- Sourced from Interface/AddOns/Blizzard_Deprecated/Deprecated_8_3_0.lua
if (not GetAlternatePowerInfoByID) then
	GetAlternatePowerInfoByID = function(barID)
		local barInfo = GetUnitPowerBarInfoByID(barID)
		if (barInfo) then
			local name, tooltip, cost = GetUnitPowerBarStringsByID(barID)
			return barInfo.barType,barInfo.minPower, barInfo.startInset, barInfo.endInset, barInfo.smooth, barInfo.hideFromOthers, barInfo.showOnRaid, barInfo.opaqueSpark, barInfo.opaqueFlash, barInfo.anchorTop, name, tooltip, cost, barInfo.ID, barInfo.forcePercentage, barInfo.sparkUnderFrame
		end
	end
end

-----------------------------------------------------------------
-- Utility
-----------------------------------------------------------------
local sort_mirrors = function(a, b)
	if (a.type and b.type and (a.type == b.type)) then
		return a.id < b.id -- same type, order by their id
	else
		return a.type < b.type -- different type, order by type
	end
end

local updateBuffTimer = function(self, elapsed)
	local timeLeft = self.timerExpiration - GetTime()
	if (timeLeft <= 0) then
		timeLeft = 0
		self:Hide()
		self:SetScript("OnUpdate", nil)
	end
	self.bar:SetValue(timeLeft)
	self.msg:SetText(timeLeft - timeLeft%1)
end

-----------------------------------------------------------------
-- Styling
-----------------------------------------------------------------
Module.StyleTimer = function(self, frame, ignoreTextureFix)
	local layout = self.layout
	local timer = self.timers[frame.bar]
	local bar = timer.bar

	if (not ignoreTextureFix) then
		for i = 1,frame:GetNumRegions() do
			local region = select(i, frame:GetRegions())
			if (region and region:IsObjectType("Texture")) then
				region:SetTexture(nil)
			end
		end
		for i = 1,bar:GetNumRegions() do
			local region = select(i, bar:GetRegions())
			if (region and region:IsObjectType("Texture")) then
				region:SetTexture(nil)
			end
		end
	end

	frame:SetSize(unpack(layout.MirrorSize))

	bar:ClearAllPoints()
	bar:SetPoint(unpack(layout.MirrorBarPlace))
	bar:SetSize(unpack(layout.MirrorBarSize))
	bar:SetStatusBarTexture(layout.MirrorBarTexture)
	bar:SetFrameLevel(frame:GetFrameLevel() + 5)

	local backdrop = bar:CreateTexture()
	backdrop:SetPoint(unpack(layout.MirrorBackdropPlace))
	backdrop:SetSize(unpack(layout.MirrorBackdropSize))
	backdrop:SetDrawLayer(unpack(layout.MirrorBackdropDrawLayer))
	backdrop:SetTexture(layout.MirrorBackdropTexture)
	backdrop:SetVertexColor(unpack(layout.MirrorBackdropColor))

	if (not ignoreTextureFix) then
		-- just hide the spark for now
		local spark = timer.spark
		if spark then
			spark:SetDrawLayer("OVERLAY") -- needs to be OVERLAY, as ARTWORK will sometimes be behind the bars
			spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
			spark:SetSize(.001,.001)
			spark:SetTexture(layout.MirrorBlankTexture)
			spark:SetVertexColor(0,0,0,0)
		end

		-- hide the default border
		local border = timer.border
		if border then
			border:ClearAllPoints()
			border:SetPoint("CENTER", 0, 0)
			border:SetSize(.001, .001)
			border:SetTexture(layout.MirrorBlankTexture)
			border:SetVertexColor(0,0,0,0)
		end
	end

	local msg = timer.msg
	if msg then
		msg:SetParent(bar)
		msg:ClearAllPoints()
		msg:SetPoint(unpack(layout.MirrorBarValuePlace))
		msg:SetDrawLayer("OVERLAY", 1)
		msg:SetJustifyH("CENTER")
		msg:SetJustifyV("MIDDLE")
		msg:SetFontObject(layout.MirrorBarValueFont)
		msg:SetTextColor(unpack(layout.MirrorBarValueColor))
	end

	if (not ignoreTextureFix) then
		self:SetSecureHook(bar, "SetValue", "UpdateBarTexture")
		self:SetSecureHook(bar, "SetMinMaxValues", "UpdateBarTexture")
	end
end

Module.StyleBuffTimer = function(self, timer, auraID)
	local layout = self.layout

	-- Iterate the timer pool for available timers
	for i = 1, #self.buffTimers do
		local frame = self.buffTimers[i]

		-- First hidden one will be used
		if (not frame:IsShown()) then

			-- Retrieve the timer object
			local timer = self.timers[frame.bar]

			-- Store the timer object as an active bufftimer
			self.buffTimersByAuraID[auraID] = timer

			-- Return the timer object, report it's a new one
			return timer, true
		end
	end

	-- Create a timer if none was available
	local frame = self:CreateFrame("Frame", nil, layout.Anchor)
	frame:Hide()

	local bar = frame:CreateStatusBar()
	bar:SetSparkMap(layout.MirrorBarSparkMap)
	bar:SetStatusBarColor(unpack(layout.MirrorBarColor))
	frame.bar = bar

	local msg = bar:CreateFontString()
	frame.msg = msg

	-- Create the timer object
	local timer = {}
	timer.frame = frame
	timer.bar = bar
	timer.msg = msg
	timer.type = 1000
	timer.id = #self.buffTimers + 1

	-- Store the timer object
	self.timers[frame.bar] = timer

	-- Store the buffTimer frame
	self.buffTimers[#self.buffTimers + 1] = frame

	-- Store this as an active bufftimer
	self.buffTimersByAuraID[auraID] = timer

	-- Style the new timer before returning it
	self:StyleTimer(frame, true)

	-- Return the timer object, report it's a new one
	return timer, true
end

Module.KillWidgetPowerBarFrame = function(self, event, addon)
	if (not IsRetail) then
		return
	end
	if (event == "ADDON_LOADED") then
		if (addon ~= "Blizzard_UIWidgets") then
			return
		end
		self:UnregisterEvent("ADDON_LOADED", "KillWidgetPowerBarFrame")
	end
	local bar = UIWidgetPowerBarContainerFrame
	if (not bar) then
		return self:RegisterEvent("ADDON_LOADED", "KillWidgetPowerBarFrame")
	end
	-- Only way that works.
	-- Any messing with the bar, or the widget system's API == TAINT!
	local Hider = CreateFrame("Frame")
	Hider:Hide()
	bar:SetParent(Hider)
end

Module.GetBuffTimer = function(self, auraID)
	local layout = self.layout

	-- Attempt to retrieve the existing timer
	local timer = self.buffTimersByAuraID[auraID]
	if (timer and timer.frame:IsShown()) then
		return timer, false
	end

	return self:StyleBuffTimer(timer, auraID)
end

-----------------------------------------------------------------
-- Callbacks
-----------------------------------------------------------------
Module.UpdateAnchors = function(self, event, ...)
	local layout = self.layout
	local timers = self.timers
	local order = self.order or {}

	-- Reset the order table
	for i = #order,1,-1 do
		order[i] = nil
	end

	-- Release the points of all timers
	for bar,timer in pairs(timers) do
		timer.frame:SetParent(layout.MirrorAnchor)
		timer.frame:ClearAllPoints()
		if (timer.frame:IsShown()) then
			order[#order + 1] = timer
		end
	end

	-- Sort and arrange visible timers
	if (#order > 0) then

		-- Sort by type -> id
		table_sort(order, sort_mirrors)

		-- Figure out the start offset
		local offsetY = layout.MirrorAnchorOffsetY

		-- Add space for capturebars, if visible
		if self.captureBarVisible then
			offsetY = offsetY + layout.MirrorGrowth
		end

		-- Position the bars
		for i = 1, #order do
			order[i].frame:SetPoint(layout.MirrorAnchorPoint, layout.MirrorAnchor, layout.MirrorAnchorPoint, layout.MirrorAnchorOffsetX, offsetY)
			offsetY = offsetY + layout.MirrorGrowth
		end
	end
end

Module.UpdateBarTexture = function(self, event, bar)
	local min, max = bar:GetMinMaxValues()
	local value = bar:GetValue()
	if ((not min) or (not max) or (not value)) then
		return
	end
	if (value > max) then
		value = max
	elseif (value < min) then
		value = min
	end
	bar:GetStatusBarTexture():SetTexCoord(0, (value-min)/(max-min), 0, 1) -- cropping, not shrinking
end

Module.UpdateBuffTimers = function(self, event, unit)
	if ((event == "UNIT_POWER_BAR_TIMER_UPDATE") and (unit ~= "player")) then
		return
	end

	-- Flag all active bars for hiding
	for auraID,timer in pairs(self.buffTimersByAuraID) do
		timer.flagForHide = true
	end

	-- Iterate available bars
	local id = 1
	local duration, expiration, barID, auraID = UnitPowerBarTimerInfo("player", id)
	while barID do

		-- Counters are just numeral representation of player alt power,
		-- and we have an alt power bar for this already.
		local barType = GetAlternatePowerInfoByID(barID)
		if (barType ~= ALT_POWER_TYPE_COUNTER) then

			-- Retrieve or create the timer frame
			local timer, needsReset = self:GetBuffTimer(auraID)

			-- Unflag the bar for hiding
			timer.flagForHide = nil

			-- update bar values, make it an instant update
			timer.bar:SetMinMaxValues(0, duration, true)
			timer.bar:SetValue(duration, true)

			-- update expiration value
			timer.frame.timerExpiration = expiration

			if needsReset then
				timer.frame:SetScript("OnUpdate", updateBuffTimer)
				timer.frame:Show()
			end
		end

		id = id + 1
		duration, expiration, barID, auraID = UnitPowerBarTimerInfo("player", id)
	end

	-- Hide all active but flagged bars
	for auraID,timer in pairs(self.buffTimersByAuraID) do
		if timer.flagForHide then
			timer.frame:Hide()
			timer.frame:SetScript("OnUpdate", nil)

			-- Remove the reference from the list of active timers
			self.buffTimersByAuraID[auraID] = nil
		end
	end

	if (event ~= "ForceUpdate") then
		self:UpdateAnchors()
	end
end

Module.UpdateMirrorTimers = function(self)
	local timers = self.timers
	for i = 1, MIRRORTIMER_NUMTIMERS do
		local name  = "MirrorTimer"..i
		local frame = _G[name]

		if (frame and (not frame.bar or not timers[frame.bar])) then
			frame.bar = _G[name.."StatusBar"] or frame.StatusBar

			timers[frame.bar] = {}
			timers[frame.bar].frame = frame
			timers[frame.bar].name = name
			timers[frame.bar].bar = frame.bar
			timers[frame.bar].msg = _G[name.."Text"] or _G[name.."StatusBarTimeText"]
			timers[frame.bar].border = _G[name.."Border"] or _G[name.."StatusBarBorder"]
			timers[frame.bar].type = 1
			timers[frame.bar].id = i

			self:StyleTimer(frame)
		end
	end
	if (event ~= "ForceUpdate") then
		self:UpdateAnchors()
	end
end

Module.UpdateTimerTrackers = function(self, event, ...)
	local timers = self.timers
	for i,frame in pairs(TimerTracker.timerList) do
		if (frame and (not frame.bar or not timers[frame.bar])) then
			local name = frame:GetName()

			timers[frame.bar] = {}
			timers[frame.bar].frame = frame
			timers[frame.bar].name = name
			timers[frame.bar].bar = frame.bar
			timers[frame.bar].msg = _G[name.."TimeText"] or _G[name.."StatusBarTimeText"] or frame.timeText
			timers[frame.bar].border = _G[name.."Border"] or _G[name.."StatusBarBorder"]
			timers[frame.bar].type = 2
			timers[frame.bar].id = i

			self:StyleTimer(frame)
		end
	end
	if (event ~= "ForceUpdate") then
		self:UpdateAnchors()
	end
end

Module.UpdateAll = function(self)
	self:UpdateMirrorTimers("ForceUpdate")

	if (IsRetail) then
		self:UpdateBuffTimers("ForceUpdate")
		self:UpdateTimerTrackers("ForceUpdate")
	end

	self:UpdateAnchors()
end

-----------------------------------------------------------------
-- Startup
-----------------------------------------------------------------
Module.OnCaptureBarVisible = function(self, event, ...)
	self.captureBarVisible = true

	-- update timer anchors
	self:UpdateAnchors()
end

Module.OnCaptureBarHidden = function(self, event, ...)
	self.captureBarVisible = nil

	-- update timer anchors
	self:UpdateAnchors()
end

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	self.timers = {} -- all timer data, hashed by bar objects

	if (IsRetail) then
		self.buffTimers = {} -- all buff timer frames, indexed
		self.buffTimersByAuraID = {} -- all active buff timers, hashed by auraID
	end

	-- Update mirror timers (breath/fatigue)
	self:SetSecureHook("MirrorTimer_Show", "UpdateMirrorTimers")

	if (IsRetail) then
		-- Update timer trackers (instance/bg countdowns)
		self:RegisterEvent("START_TIMER", "UpdateTimerTrackers")

		-- Update buff timers (timers and counts related to the alt power)
		self:RegisterEvent("UNIT_POWER_BAR_TIMER_UPDATE", "UpdateBuffTimers")

		-- Update anchors to keep the parenting correct
		self:SetSecureHook("FreeTimerTrackerTimer", "UpdateAnchors")

		-- Damn this.
		self:KillWidgetPowerBarFrame()
	end

	-- Update all on world entering
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAll")

	-- PvP capture bars
	-- Not yet implemented do to being part of blizzard's awful minimap widgets.
	--self:RegisterMessage("CG_CAPTUREBAR_VISIBLE", "OnCaptureBarVisible")
	--self:RegisterMessage("CG_CAPTUREBAR_HIDDEN", "OnCaptureBarHidden")

end
