local ADDON,Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end

local LibNumbers = Wheel("LibNumbers")
assert(LibNumbers, ADDON..":Minimap requires LibNumbers to be loaded.")

local L = Wheel("LibLocale"):GetLocale(ADDON)
local Module = Core:NewModule("Minimap", "LibEvent", "LibDB", "LibFrame", "LibMinimap", "LibTooltip", "LibTime", "LibSound", "LibPlayerData")

-- Lua API
local _G = _G
local ipairs = ipairs
local math_floor = math.floor
local select = select
local string_format = string.format
local string_match = string.match
local table_insert = table.insert
local tonumber = tonumber
local unpack = unpack

-- WoW API
local CancelTrackingBuff = CancelTrackingBuff
local CastSpellByID = CastSpellByID
local GetAzeriteItemXPInfo = C_AzeriteItem and C_AzeriteItem.GetAzeriteItemXPInfo
local GetFactionInfo = GetFactionInfo
local GetFactionParagonInfo = C_Reputation and C_Reputation.GetFactionParagonInfo
local GetFramerate = GetFramerate
local GetFriendshipReputation = GetFriendshipReputation
local GetNetStats = GetNetStats
local GetNumFactions = GetNumFactions
local GetPowerLevel = C_AzeriteItem and C_AzeriteItem.GetPowerLevel
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = GetSpellTexture
local GetTrackingTexture = GetTrackingTexture
local GetWatchedFactionInfo = GetWatchedFactionInfo
local IsFactionParagon = C_Reputation and C_Reputation.IsFactionParagon
local IsPlayerSpell = IsPlayerSpell
local IsXPUserDisabled = IsXPUserDisabled
local SetCursor = SetCursor
local ToggleCalendar = ToggleCalendar
local UnitExists = UnitExists
local UnitLevel = UnitLevel
local UnitRace = UnitRace

-- Number Abbreviation
local short = LibNumbers:GetNumberAbbreviationShort()
local large = LibNumbers:GetNumberAbbreviationLong()

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetLayout = Private.GetLayout
local IsAnyClassic = Private.IsAnyClassic
local IsClassic = Private.IsClassic
local IsTBC = Private.IsTBC
local IsWrath = Private.IsWrath
local IsRetail = Private.IsRetail

-- WoW Strings
local REPUTATION = REPUTATION
local STANDING = STANDING
local UNKNOWN = UNKNOWN

-- Custom strings & constants
local Spinner = {}
local NEW = "*"
local shortXPString = "%s%%"
local longXPString = "%s / %s"
local fullXPString = "%s / %s (%s)"
local restedString = " (%s%% %s)"
local shortLevelString = "%s %.0f"

-- Constant to track player level
local LEVEL = UnitLevel("player")

----------------------------------------------------
-- Utility Functions
----------------------------------------------------
local getTimeStrings = function(h, m, suffix, useStandardTime, abbreviateSuffix)
	if (useStandardTime) then
		return "%.0f:%02.0f |cff888888%s|r", h, m, abbreviateSuffix and string_match(suffix, "^.") or suffix
	else
		return "%02.0f:%02.0f", h, m
	end
end

local MouseIsOver = function(frame)
	return (frame == GetMouseFocus())
end

if (IsTBC or IsWrath or IsWrath) then
	GetTrackingTexture = function()
		local count = GetNumTrackingTypes()
		for id = 1, count do
			local texture, active, category = select(2, GetTrackingInfo(id))
			if (active) then
				if (category == "spell") then
					return texture
				end
			end
		end
	end
end

----------------------------------------------------
-- Callbacks
----------------------------------------------------
local XP_PostUpdate = function(element, min, max, restedLeft, restedTimeLeft)
	local description = element.Value and element.Value.Description
	if description then
		local level = LEVEL or UnitLevel("player")
		if (level and (level > 0)) then
			description:SetFormattedText(L["to level %s"], level + 1)
		else
			description:SetText("")
		end
	end
end

local Rep_PostUpdate = function(element, current, min, max, factionName, standingID, standingLabel)
	local description = element.Value and element.Value.Description
	if description then
		if (standingID == MAX_REPUTATION_REACTION) then
			description:SetText(standingLabel)
		else
			local nextStanding = standingID and _G["FACTION_STANDING_LABEL"..(standingID + 1)]
			if nextStanding then
				description:SetFormattedText(L["to %s"], nextStanding)
			else
				description:SetText("")
			end
		end
	end
end

local AP_PostUpdate = function(element, min, max, level)
	local description = element.Value and element.Value.Description
	if description then
		description:SetText(L["to next level"])
	end
end

local Performance_UpdateTooltip = function(self)
	local tooltip = Private:GetMinimapTooltip()

	local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = GetNetStats()
	local fps = GetFramerate()

	local colors = self._owner.colors
	local rt, gt, bt = unpack(colors.title)
	local r, g, b = unpack(colors.normal)
	local rh, gh, bh = unpack(colors.highlight)
	local rg, gg, bg = unpack(colors.quest.green)

	tooltip:SetDefaultAnchor(self)
	tooltip:SetMaximumWidth(360)
	tooltip:AddLine(L["Network Stats"], rt, gt, bt)
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(L["World latency:"], ("%.0f|cff888888%s|r"):format(math_floor(latencyWorld), MILLISECONDS_ABBR), rh, gh, bh, r, g, b)
	tooltip:AddLine(L["This is the latency of the world server, and affects casting, crafting, interaction with other players and NPCs. This is the value that decides how delayed your combat actions are."], rg, gg, bg, true)
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(L["Home latency:"], ("%.0f|cff888888%s|r"):format(math_floor(latencyHome), MILLISECONDS_ABBR), rh, gh, bh, r, g, b)
	tooltip:AddLine(L["This is the latency of the home server, which affects things like chat, guild chat, the auction house and some other non-combat related things."], rg, gg, bg, true)
	tooltip:Show()
end

local Performance_OnEnter = function(self)
	self.UpdateTooltip = Performance_UpdateTooltip
	self:UpdateTooltip()
end

local Performance_OnLeave = function(self)
	Private:GetMinimapTooltip():Hide()
	self.UpdateTooltip = nil
end

local Tracking_OnClick = function(self, button)
	if (IsAnyClassic) then
		if (button == "LeftButton") then
			Module:ShowMinimapTrackingMenu()
		elseif (button == "RightButton") then
			CancelTrackingBuff()
		end
	else
		Module:ShowMinimapTrackingMenu()
	end
end

local Tracking_OnEnter = function(self)
	local tooltip = Private:GetMinimapTooltip()
	tooltip:SetDefaultAnchor(self)
	tooltip:SetMaximumWidth(360)
	tooltip:SetTrackingSpell()
end

local Tracking_OnLeave = function(self)
	Private:GetMinimapTooltip():Hide()
end

-- This is the XP and AP tooltip (and rep/honor later on)
local Toggle_UpdateTooltip = function(toggle)

	local tooltip = Private:GetMinimapTooltip()
	local hasXP = Module:PlayerHasXP()
	local hasRep = Module:PlayerHasRep()
	local hasAP = IsRetail and Module:PlayerHasAP()

	local NC = "|r"
	local colors = toggle._owner.colors
	local rt, gt, bt = unpack(colors.title)
	local r, g, b = unpack(colors.normal)
	local rh, gh, bh = unpack(colors.highlight)
	local rgg, ggg, bgg = unpack(colors.quest.gray)
	local rg, gg, bg = unpack(colors.quest.green)
	local rr, gr, br = unpack(colors.quest.red)
	local green = colors.quest.green.colorCode
	local normal = colors.normal.colorCode
	local highlight = colors.highlight.colorCode

	local resting, restState, restedName, mult
	local restedLeft, restedTimeLeft

	if (hasXP or hasAP or hasRep) then
		tooltip:SetDefaultAnchor(toggle)
		tooltip:SetMaximumWidth(360)
	end

	-- XP tooltip
	-- Currently more or less a clone of the blizzard tip, we should improve!
	if (hasXP) then
		resting = IsResting()
		restState, restedName, mult = GetRestState()
		restedLeft, restedTimeLeft = GetXPExhaustion(), GetTimeToWellRested()

		local min, max = UnitXP("player"), UnitXPMax("player")

		tooltip:AddDoubleLine(POWER_TYPE_EXPERIENCE, LEVEL or UnitLevel("player"), rt, gt, bt, rt, gt, bt)
		tooltip:AddDoubleLine(L["Current XP: "], fullXPString:format(normal..(min > 0 and short(min) or min)..NC, normal..short(max)..NC, highlight..math_floor(min/max*100).."%"..NC), rh, gh, bh, rgg, ggg, bgg)

		-- add rested bonus if it exists
		if (restedLeft and (restedLeft > 0)) then
			tooltip:AddDoubleLine(L["Rested Bonus: "], fullXPString:format(normal..short(restedLeft)..NC, normal..short(max * 1.5)..NC, highlight..math_floor(restedLeft/(max * 1.5)*100).."%"..NC), rh, gh, bh, rgg, ggg, bgg)
		end

		if (restState) and (restState == 1) then
			if (resting) and (restedTimeLeft) and (restedTimeLeft > 0) then
				tooltip:AddLine(" ")
				--tooltip:AddLine(L["Resting"], rh, gh, bh)
				if (restedTimeLeft > hour*2) then
					tooltip:AddLine(L["You must rest for %s additional hours to become fully rested."]:format(highlight..math_floor(restedTimeLeft/hour)..NC), r, g, b, true)
				else
					tooltip:AddLine(L["You must rest for %s additional minutes to become fully rested."]:format(highlight..math_floor(restedTimeLeft/minute)..NC), r, g, b, true)
				end
			else
				tooltip:AddLine(" ")
				--tooltip:AddLine(L["Rested"], rh, gh, bh)
				tooltip:AddLine(L["%s of normal experience gained from monsters."]:format(shortXPString:format((mult or 1)*100)), rg, gg, bg, true)
			end
		elseif (restState) and (restState >= 2) then
			if not(restedTimeLeft and restedTimeLeft > 0) then
				tooltip:AddLine(" ")
				tooltip:AddLine(L["You should rest at an Inn."], rr, gr, br)
			else
				-- No point telling people there's nothing to tell them, is there?
				--tooltip:AddLine(" ")
				--tooltip:AddLine(L["Normal"], rh, gh, bh)
				--tooltip:AddLine(L["%s of normal experience gained from monsters."]:format(shortXPString:format((mult or 1)*100)), rg, gg, bg, true)
			end
		end
	end

	-- New BfA Artifact Power tooltip!
	if (hasAP) then
		if (hasXP) then
			tooltip:AddLine(" ")
		end

		local min, max = GetAzeriteItemXPInfo(hasAP)
		local level = GetPowerLevel(hasAP)

		tooltip:AddDoubleLine(ARTIFACT_POWER, level, rt, gt, bt, rt, gt, bt)
		tooltip:AddDoubleLine(L["Current Artifact Power: "], fullXPString:format(normal..short(min)..NC, normal..short(max)..NC, highlight..math_floor(min/max*100).."%"..NC), rh, gh, bh, rgg, ggg, bgg)
	end

	-- Rep tooltip
	if (hasRep) then
		if (hasXP or hasAP) then
			tooltip:AddLine(" ")
		end

		local name, reaction, min, max, current, factionID = GetWatchedFactionInfo()

		if (IsRetail) then
			if (factionID and IsFactionParagon(factionID)) then
				local currentValue, threshold, _, hasRewardPending = GetFactionParagonInfo(factionID)
				if (currentValue and threshold) then
					min, max = 0, threshold
					current = currentValue % threshold
					if (hasRewardPending) then
						current = current + threshold
					end
				end
			end
		end

		local standingID, isFriend, friendText
		local standingLabel, standingDescription
		for i = 1, GetNumFactions() do
			local factionName, description, standingId, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)

			if (factionName == name) then

				-- Retrieve friendship reputation info, if any.
				if (IsRetail) then
					local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionID)

					if (friendID) then
						isFriend = true
						if nextFriendThreshold then
							min = friendThreshold
							max = nextFriendThreshold
						else
							min = 0
							max = friendMaxRep
							current = friendRep
						end
						standingLabel = friendTextLevel
						standingDescription = friendText
					end
				end

				standingID = standingId
				break
			end
		end

		if (standingID) then
			if (hasXP) then
				tooltip:AddLine(" ")
			end
			if (not isFriend) then
				standingLabel = _G["FACTION_STANDING_LABEL"..standingID]
			end
			tooltip:AddDoubleLine(name, standingLabel, rt, gt, bt, rt, gt, bt)

			local barMax = max - min
			local barValue = current - min
			if (barMax > 0) then
				tooltip:AddDoubleLine(L["Current Standing: "], fullXPString:format(normal..short(current-min)..NC, normal..short(max-min)..NC, highlight..math_floor((current-min)/(max-min)*100).."%"..NC), rh, gh, bh, rgg, ggg, bgg)
			else
				tooltip:AddDoubleLine(L["Current Standing: "], "100%", rh, gh, bh, r, g, b)
			end
		else
			-- Don't add additional spaces if we can't display the information
			hasRep = nil
		end
	end

	-- Only adding the sticky toggle to the toggle button for now, not the frame.
	if (MouseIsOver(toggle)) then
		tooltip:AddLine(" ")
		if (Module.db.stickyBars) then
			tooltip:AddLine(L["%s to disable sticky bars."]:format(green..L["<Left-Click>"]..NC), rh, gh, bh)
		else
			tooltip:AddLine(L["%s to enable sticky bars."]:format(green..L["<Left-Click>"]..NC), rh, gh, bh)
		end
	end

	tooltip:Show()
end

-- Full clear of any cancelled fade-ins
local Toggle_Clear = function(toggle)
	toggle.Frame:Hide()
	toggle.Frame:SetAlpha(0)
	toggle.Frame.isMouseOver = nil
	toggle:SetScript("OnUpdate", nil)
	toggle.fading = nil
	toggle.fadeDirection = nil
	toggle.fadeDuration = 0
	toggle.fadeDelay = 0
	toggle.timeFading = 0
end

local Toggle_OnUpdate = function(toggle, elapsed)
	if (toggle.fadeDelay > 0) then
		local fadeDelay = toggle.fadeDelay - elapsed
		if (fadeDelay > 0) then
			toggle.fadeDelay = fadeDelay
			return
		end
		toggle.fadeDelay = 0
		toggle.timeFading = 0
	end

	toggle.timeFading = toggle.timeFading + elapsed

	if (toggle.fadeDirection == "OUT") then
		local alpha = 1 - (toggle.timeFading / toggle.fadeDuration)
		if (alpha > 0) then
			toggle.Frame:SetAlpha(alpha)
		else
			toggle:SetScript("OnUpdate", nil)
			toggle.Frame:Hide()
			toggle.Frame:SetAlpha(0)
			toggle.fading = nil
			toggle.fadeDirection = nil
			toggle.fadeDuration = 0
			toggle.timeFading = 0
		end

	elseif (toggle.fadeDirection == "IN") then
		local alpha = toggle.timeFading / toggle.fadeDuration
		if (alpha < 1) then
			toggle.Frame:SetAlpha(alpha)
		else
			toggle:SetScript("OnUpdate", nil)
			toggle.Frame:SetAlpha(1)
			toggle.fading = nil
			toggle.fadeDirection = nil
			toggle.fadeDuration = 0
			toggle.timeFading = 0
		end
	end
end

-- This method is called upon entering or leaving
-- either the toggle button, the visible ring frame,
-- or by clicking the toggle button.
-- Its purpose should be to decide ring frame visibility.
local Toggle_UpdateFrame = function(toggle)
	local db = Module.db
	local frame = toggle.Frame
	local frameIsShown = frame:IsShown()

	-- If sticky bars is enabled, we should only fade in, and keep it there,
	-- and then just remove the whole update handler until the sticky setting is changed.
	if (db.stickyBars) then

		-- if the frame isn't shown,
		-- reset the alpha and initiate fade-in
		if (not frameIsShown) then
			frame:SetAlpha(0)
			frame:Show()

			toggle.fadeDirection = "IN"
			toggle.fadeDelay = 0
			toggle.fadeDuration = .25
			toggle.timeFading = 0
			toggle.fading = true

			if not toggle:GetScript("OnUpdate") then
				toggle:SetScript("OnUpdate", Toggle_OnUpdate)
			end

		-- If it is shown, we should probably just keep going.
		-- This is probably just called because the user moved
		-- between the toggle button and the frame.
		else


		end

	-- Move towards full visibility if we're over the toggle or the visible frame
	elseif (toggle.isMouseOver) then

		-- If we entered while fading, it's most likely a fade-out that needs to be reversed.
		if (toggle.fading) then

			-- Reverse the fade-out.
			if (toggle.fadeDirection == "OUT") then
				toggle.fadeDirection = "IN"
				toggle.fadeDuration = .25
				toggle.fadeDelay = 0
				toggle.timeFading = 0
				if (not toggle:GetScript("OnUpdate")) then
					toggle:SetScript("OnUpdate", Toggle_OnUpdate)
				end
			else
				-- this is a fade-in we wish to keep running.
			end

		-- If it's not fading it's either because it's hidden, at full alpha,
		-- or because sticky bars just got disabled and it's still fully visible.
		else
			-- Inititate a fade-in delay, but only if the frame is hidden.
			if (not frameIsShown) then
				frame:SetAlpha(0)
				frame:Show()
				toggle.fadeDirection = "IN"
				toggle.fadeDuration = .25
				toggle.fadeDelay = .5
				toggle.timeFading = 0
				toggle.fading = true
				if not toggle:GetScript("OnUpdate") then
					toggle:SetScript("OnUpdate", Toggle_OnUpdate)
				end
			else
				-- The frame is shown, just keep showing it and do nothing.
			end
		end

	elseif (frame.isMouseOver) then
		-- This happens when we've quickly left the toggle button,
		-- like when the mouse accidentally passes it on its way somewhere else.
		if (not toggle.isMouseOver) and (toggle.fading) and (toggle.fadeDelay > 0) and (frameIsShown and frame.isMouseOver) then
			return Toggle_Clear(toggle)
		end

	-- We're not above the toggle or a visible frame,
	-- so we should initiate a fade-out or cancel pending fade-ins.
	else
		-- if the frame is visible, this should be a fade-out.
		if (frameIsShown) then
			-- Only initiate the fade delay if the frame previously was fully shown,
			-- do not start a delay if we moved back into a fading frame then out again
			-- before it could reach its full alpha, or the frame will appear to be "stuck"
			-- in a semi-transparent state for a few seconds. Ewwww.
			if (toggle.fading) then
				-- This was a queued fade-in that now will be cancelled,
				-- because the mouse is not above the toggle button anymore.
				if (toggle.fadeDirection == "IN") and (toggle.fadeDelay > 0) then
					return Toggle_Clear(toggle)
				else
					-- This is a semi-visible frame,
					-- that needs to get its fade-out initiated or updated.
					toggle.fadeDirection = "OUT"
					toggle.fadeDelay = 0
					toggle.fadeDuration = (.25 - (toggle.timeFading or 0))
					toggle.timeFading = toggle.timeFading or 0
				end
			else
				-- Most likely a fully visible frame we just left.
				-- Now we initiate the delay and a following fade-out.
				toggle.fadeDirection = "OUT"
				toggle.fadeDelay = .5
				toggle.fadeDuration = .25
				toggle.timeFading = 0
				toggle.fading = true
			end
			if (not toggle:GetScript("OnUpdate")) then
				toggle:SetScript("OnUpdate", Toggle_OnUpdate)
			end
		end
	end
end

local Toggle_OnMouseUp = function(toggle, button)
	local db = Module.db
	db.stickyBars = not db.stickyBars

	Toggle_UpdateFrame(toggle)

	if toggle.UpdateTooltip then
		toggle:UpdateTooltip()
	end

	if Module.db.stickyBars then
		print(toggle._owner.colors.title.colorCode..L["Sticky Minimap bars enabled."].."|r")
	else
		print(toggle._owner.colors.title.colorCode..L["Sticky Minimap bars disabled."].."|r")
	end
end

local Toggle_OnEnter = function(toggle)
	toggle.UpdateTooltip = Toggle_UpdateTooltip
	toggle.isMouseOver = true

	Toggle_UpdateFrame(toggle)

	toggle:UpdateTooltip()
end

local Toggle_OnLeave = function(toggle)
	local db = Module.db

	toggle.isMouseOver = nil
	toggle.UpdateTooltip = nil

	-- Update this to avoid a flicker or delay
	-- when moving directly from the toggle button to the ringframe.
	toggle.Frame.isMouseOver = MouseIsOver(toggle.Frame)

	Toggle_UpdateFrame(toggle)

	if not((toggle.Frame.isMouseOver) and (toggle.Frame:IsShown())) then
		Private:GetMinimapTooltip():Hide()
	end
end

local RingFrame_UpdateTooltip = function(frame)
	local toggle = frame._owner

	Toggle_UpdateTooltip(toggle)
end

local RingFrame_OnEnter = function(frame)
	local toggle = frame._owner
	local isShown = frame:IsShown()

	frame.UpdateTooltip = RingFrame_UpdateTooltip
	frame.isMouseOver = isShown and true

	Toggle_UpdateFrame(toggle)
	isShown = frame:IsShown()

	local toggle = frame._owner
	if (not isShown) then
		toggle.fading = nil
		toggle.fadeDirection = nil
		toggle.fadeDuration = 0
		toggle.fadeDelay = 0
		toggle.timeFading = 0
	end

	-- The above method can actually hide this frame,
	-- trigger the OnLeave handler, and remove UpdateTooltip.
	-- We need to check if it still exists before running it.
	if (isShown) and (frame.UpdateTooltip) then
		frame:UpdateTooltip()
	end
end

local RingFrame_OnLeave = function(frame)
	local db = Module.db
	local toggle = frame._owner

	frame.isMouseOver = nil
	frame.UpdateTooltip = nil

	-- Update this to avoid a flicker or delay
	-- when moving directly from the ringframe to the toggle button.
	toggle.isMouseOver = MouseIsOver(toggle)

	Toggle_UpdateFrame(toggle)

	if (not toggle.isMouseOver) then
		Private:GetMinimapTooltip():Hide()
	end
end

local Time_UpdateTooltip = function(self)
	local tooltip = Private:GetMinimapTooltip()

	local colors = self._owner.colors
	local rt, gt, bt = unpack(colors.title)
	local r, g, b = unpack(colors.normal)
	local rh, gh, bh = unpack(colors.highlight)
	local rg, gg, bg = unpack(colors.quest.green)
	local green = colors.quest.green.colorCode
	local NC = "|r"

	local useStandardTime = Module.db.useStandardTime
	local useServerTime = Module.db.useServerTime

	-- client time
	local lh, lm, lsuffix = Module:GetLocalTime(useStandardTime)

	-- server time
	local sh, sm, ssuffix = Module:GetServerTime(useStandardTime)

	tooltip:SetDefaultAnchor(self)
	tooltip:SetMaximumWidth(360)
	tooltip:AddLine(TIMEMANAGER_TOOLTIP_TITLE, rt, gt, bt)
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_LOCALTIME, string_format(getTimeStrings(lh, lm, lsuffix, useStandardTime)), rh, gh, bh, r, g, b)
	tooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_REALMTIME, string_format(getTimeStrings(sh, sm, ssuffix, useStandardTime)), rh, gh, bh, r, g, b)
	tooltip:AddLine(" ")

	if (IsRetail) then
		tooltip:AddLine(L["%s to toggle calendar."]:format(green..L["<Left-Click>"]..NC), rh, gh, bh)
	else
		tooltip:AddLine(green..L["<Left-Click>"]..NC .. " " .. TIMEMANAGER_SHOW_STOPWATCH, rh, gh, bh)
	end

	if useServerTime then
		tooltip:AddLine(L["%s to use local computer time."]:format(green..L["<Middle-Click>"]..NC), rh, gh, bh)
	else
		tooltip:AddLine(L["%s to use game server time."]:format(green..L["<Middle-Click>"]..NC), rh, gh, bh)
	end

	if useStandardTime then
		tooltip:AddLine(L["%s to use military (24-hour) time."]:format(green..L["<Right-Click>"]..NC), rh, gh, bh)
	else
		tooltip:AddLine(L["%s to use standard (12-hour) time."]:format(green..L["<Right-Click>"]..NC), rh, gh, bh)
	end

	tooltip:Show()
end

local Time_OnEnter = function(self)
	self.UpdateTooltip = Time_UpdateTooltip
	self:UpdateTooltip()
end

local Time_OnLeave = function(self)
	Private:GetMinimapTooltip():Hide()
	self.UpdateTooltip = nil
end

local Time_OnClick = function(self, mouseButton)
	if (mouseButton == "LeftButton") then
		if (IsRetail) then
			if (ToggleCalendar) then
				ToggleCalendar()
			end
		else
			if (not IsAddOnLoaded("Blizzard_TimeManager")) then
				UIParentLoadAddOn("Blizzard_TimeManager")
			end
			Stopwatch_Toggle()
			if (StopwatchFrame:IsShown()) then
				Module:PlaySoundKitID(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			else
				Module:PlaySoundKitID(SOUNDKIT.IG_MAINMENU_QUIT)
			end
		end

	elseif (mouseButton == "MiddleButton") then
		Module.db.useServerTime = not Module.db.useServerTime

		self.clock.useServerTime = Module.db.useServerTime
		self.clock:ForceUpdate()

		if self.UpdateTooltip then
			self:UpdateTooltip()
		end

		if Module.db.useServerTime then
			print(self._owner.colors.title.colorCode..L["Now using game server time."].."|r")
		else
			print(self._owner.colors.title.colorCode..L["Now using local computer time."].."|r")
		end

	elseif (mouseButton == "RightButton") then
		Module.db.useStandardTime = not Module.db.useStandardTime

		self.clock.useStandardTime = Module.db.useStandardTime
		self.clock:ForceUpdate()

		if self.UpdateTooltip then
			self:UpdateTooltip()
		end

		if Module.db.useStandardTime then
			print(self._owner.colors.title.colorCode..L["Now using standard (12-hour) time."].."|r")
		else
			print(self._owner.colors.title.colorCode..L["Now using military (24-hour) time."].."|r")
		end
	end
end

local Zone_OnEnter = function(self)
	local tooltip = Private:GetMinimapTooltip()

end

local Zone_OnLeave = function(self)
	Private:GetMinimapTooltip():Hide()
end

----------------------------------------------------
-- Map Setup
----------------------------------------------------
Module.SetUpMinimap = function(self)
	local db = self.db
	local layout = self.layout

	-- Frame
	----------------------------------------------------
	-- Retrieve an unique element handler for our module
	-- This also syncs the minimap and sets it up for us.
	local Handler = self:GetMinimapHandler()
	Handler.colors = Colors

	-- Reposition minimap tooltip
	local tooltip = self:GetMinimapTooltip()

	-- Blob & Ring Textures
	-- Set the alpha values of the various map blob and ring textures. Values range from 0-255.
	-- Using tested versions from DiabolicUI, which makes the map IMO much more readable.
	if (IsRetail) then
		self:SetMinimapBlobAlpha(unpack(layout.BlobAlpha))
	end

	-- Blip textures
	local clientPatch = GetBuildInfo()
	local blips = layout.BlipTextures[clientPatch]
	if (blips) then
		self:SetMinimapBlips(layout.BlipTextures[clientPatch], clientPatch)
		self:SetMinimapScale(layout.BlipScale or 1)
	end

	-- Minimap Buttons
	----------------------------------------------------
	-- Only allow these when MBB is loaded.
	self:SetMinimapAllowAddonButtons(self.MBB)

	-- Minimap Compass
	self:SetMinimapCompassEnabled(true)
	self:SetMinimapCompassText(unpack(layout.CompassTexts))
	self:SetMinimapCompassTextFontObject(layout.CompassFont)
	self:SetMinimapCompassTextColor(unpack(layout.CompassColor))
	self:SetMinimapCompassRadiusInset(layout.CompassRadiusInset)

	-- Background
	local mapBackdrop = Handler:CreateBackdropTexture()
	mapBackdrop:SetDrawLayer("BACKGROUND")
	mapBackdrop:SetAllPoints()
	mapBackdrop:SetTexture(layout.MapBackdropTexture)
	mapBackdrop:SetVertexColor(unpack(layout.MapBackdropColor))

	-- Overlay
	local mapOverlay = Handler:CreateContentTexture()
	mapOverlay:SetDrawLayer("BORDER")
	mapOverlay:SetAllPoints()
	mapOverlay:SetTexture(layout.MapOverlayTexture)
	mapOverlay:SetVertexColor(unpack(layout.MapOverlayColor))

	-- Border
	local border = Handler:CreateBorderTexture()
	border:SetDrawLayer("BACKGROUND")
	border:SetTexture(layout.MapBorderTexture)
	border:SetSize(unpack(layout.MapBorderSize))
	border:SetVertexColor(unpack(layout.MapBorderColor))
	border:SetPoint(unpack(layout.MapBorderPlace))
	Handler.Border = border

	-- Mail
	local mail = Handler:CreateOverlayFrame()
	mail:SetSize(unpack(layout.MailSize))
	mail:Place(unpack(layout.MailPlace))

	local icon = mail:CreateTexture()
	icon:SetTexture(layout.MailTexture)
	icon:SetDrawLayer(unpack(layout.MailTextureDrawLayer))
	icon:SetPoint(unpack(layout.MailTexturePlace))
	icon:SetSize(unpack(layout.MailTextureSize))
	icon:SetRotation(layout.MailTextureRotation)
	Handler.Mail = mail

	-- Clock
	local clockFrame = Handler:CreateBorderFrame("Button")
	Handler.ClockFrame = clockFrame

	local clock = Handler:CreateFontString()
	clock:SetPoint(unpack(layout.ClockPlace))
	clock:SetDrawLayer("OVERLAY")
	clock:SetJustifyH("RIGHT")
	clock:SetJustifyV("BOTTOM")
	clock:SetFontObject(layout.ClockFont)
	clock:SetTextColor(unpack(layout.ClockColor))
	clock.useStandardTime = db.useStandardTime -- standard (12-hour) or military (24-hour) time
	clock.useServerTime = db.useServerTime -- realm time or local time
	clock.showSeconds = false -- show seconds in the clock
	clock.OverrideValue = layout.Clock_OverrideValue

	-- Make the clock clickable to change time settings
	clockFrame:SetAllPoints(clock)
	clockFrame:SetScript("OnEnter", Time_OnEnter)
	clockFrame:SetScript("OnLeave", Time_OnLeave)
	clockFrame:SetScript("OnClick", Time_OnClick)

	-- Register all buttons separately, as "AnyUp" doesn't include the middle button!
	clockFrame:RegisterForClicks("RightButtonUp", "LeftButtonUp", "MiddleButtonUp")
	clockFrame.clock = clock
	clockFrame._owner = Handler

	clock:SetParent(clockFrame)

	Handler.Clock = clock

	-- Zone Information
	local zoneFrame = Handler:CreateBorderFrame()
	Handler.ZoneFrame = zoneFrame

	local zone = zoneFrame:CreateFontString()
	zone:SetPoint(layout.ZonePlaceFunc(Handler))
	zone:SetDrawLayer("OVERLAY")
	zone:SetJustifyH("RIGHT")
	zone:SetJustifyV("BOTTOM")
	zone:SetFontObject(layout.ZoneFont)
	zone:SetAlpha(layout.ZoneAlpha or 1)
	zone.colorPvP = true -- color zone names according to their PvP type
	zone.colorcolorDifficulty = true -- color instance names according to their difficulty
	zone.showResting = true -- show resting status next to zone name

	-- Strap the frame to the text
	zoneFrame:SetAllPoints(zone)
	zoneFrame:SetScript("OnEnter", Zone_OnEnter)
	zoneFrame:SetScript("OnLeave", Zone_OnLeave)
	Handler.Zone = zone

	-- Coordinates
	local coordinates = Handler:CreateBorderText()
	coordinates:SetPoint(unpack(layout.CoordinatePlace))
	coordinates:SetDrawLayer("OVERLAY")
	coordinates:SetJustifyH("CENTER")
	coordinates:SetJustifyV("BOTTOM")
	coordinates:SetFontObject(layout.CoordinateFont)
	coordinates:SetTextColor(unpack(layout.CoordinateColor))
	coordinates.OverrideValue = layout.Coordinates_OverrideValue
	Handler.Coordinates = coordinates

	-- Performance Information
	local performanceFrame = Handler:CreateBorderFrame()
	performanceFrame._owner = Handler
	Handler.PerformanceFrame = performanceFrame

	local framerate = performanceFrame:CreateFontString()
	framerate:SetDrawLayer("OVERLAY")
	framerate:SetJustifyH("RIGHT")
	framerate:SetJustifyV("BOTTOM")
	framerate:SetFontObject(layout.FrameRateFont)
	framerate:SetTextColor(unpack(layout.FrameRateColor))
	framerate.OverrideValue = layout.FrameRate_OverrideValue
	framerate.PostUpdate = layout.Performance_PostUpdate

	Handler.FrameRate = framerate

	local latency = performanceFrame:CreateFontString()
	latency:SetDrawLayer("OVERLAY")
	latency:SetJustifyH("CENTER")
	latency:SetJustifyV("BOTTOM")
	latency:SetFontObject(layout.LatencyFont)
	latency:SetTextColor(unpack(layout.LatencyColor))
	latency.OverrideValue = layout.Latency_OverrideValue
	latency.PostUpdate = layout.Performance_PostUpdate

	Handler.Latency = latency

	-- Strap the frame to the text
	performanceFrame:SetScript("OnEnter", Performance_OnEnter)
	performanceFrame:SetScript("OnLeave", Performance_OnLeave)

	if (layout.PerformanceFramePlaceAdvancedFunc) then
		layout.PerformanceFramePlaceAdvancedFunc(performanceFrame, Handler)
	elseif (layout.PerformanceFramePlaceFunc) then
		performanceFrame:Place(layout.PerformanceFramePlaceFunc(Handler))
	end

	framerate:Place(layout.FrameRatePlaceFunc(Handler))
	latency:Place(layout.LatencyPlaceFunc(Handler))


	-- Ring frame
	if (layout.UseBars) then

		local ringFrame = Handler:CreateOverlayFrame()
		ringFrame:Hide()
		ringFrame:SetAllPoints() -- set it to cover the map
		ringFrame:EnableMouse(true) -- make sure minimap blips and their tooltips don't punch through
		ringFrame:SetScript("OnEnter", RingFrame_OnEnter)
		ringFrame:SetScript("OnLeave", RingFrame_OnLeave)

		ringFrame:HookScript("OnShow", function()
			local compassFrame = Wheel("LibMinimap"):GetCompassFrame()
			if (compassFrame) then
				compassFrame.supressCompass = true
			end
		end)

		ringFrame:HookScript("OnHide", function()
			local compassFrame = Wheel("LibMinimap"):GetCompassFrame()
			if compassFrame then
				compassFrame.supressCompass = nil
			end
		end)

		-- Wait with this until now to trigger compass visibility changes
		ringFrame:SetShown(db.stickyBars)

		-- ring frame backdrops
		local ringFrameBg = ringFrame:CreateTexture()
		ringFrameBg:SetPoint(unpack(layout.RingFrameBackdropPlace))
		ringFrameBg:SetSize(unpack(layout.RingFrameBackdropSize))
		ringFrameBg:SetDrawLayer(unpack(layout.RingFrameBackdropDrawLayer))
		ringFrameBg:SetTexture(layout.RingFrameBackdropTexture)
		ringFrameBg:SetVertexColor(unpack(layout.RingFrameBackdropColor))
		ringFrame.Bg = ringFrameBg

		-- Toggle button for ring frame
		local toggle = Handler:CreateOverlayFrame()
		toggle:SetFrameLevel(toggle:GetFrameLevel() + 10) -- need this above the ring frame and the rings
		toggle:SetPoint("CENTER", Handler, "BOTTOM", 2, -6)
		toggle:SetSize(unpack(layout.ToggleSize))
		toggle:EnableMouse(true)
		toggle:SetScript("OnEnter", Toggle_OnEnter)
		toggle:SetScript("OnLeave", Toggle_OnLeave)
		toggle:SetScript("OnMouseUp", Toggle_OnMouseUp)
		toggle._owner = Handler
		ringFrame._owner = toggle
		toggle.Frame = ringFrame

		local toggleBackdrop = toggle:CreateTexture()
		toggleBackdrop:SetDrawLayer("BACKGROUND")
		toggleBackdrop:SetSize(unpack(layout.ToggleBackdropSize))
		toggleBackdrop:SetPoint("CENTER", 0, 0)
		toggleBackdrop:SetTexture(layout.ToggleBackdropTexture)
		toggleBackdrop:SetVertexColor(unpack(layout.ToggleBackdropColor))

		Handler.Toggle = toggle

		-- outer ring
		local ring1 = ringFrame:CreateSpinBar()
		ring1:SetPoint(unpack(layout.OuterRingPlace))
		ring1:SetSize(unpack(layout.OuterRingSize))
		ring1:SetSparkOffset(layout.OuterRingSparkOffset)
		ring1:SetSparkFlash(unpack(layout.OuterRingSparkFlash))
		ring1:SetSparkBlendMode(layout.OuterRingSparkBlendMode)
		ring1:SetClockwise(layout.OuterRingClockwise)
		ring1:SetDegreeOffset(layout.OuterRingDegreeOffset)
		ring1:SetDegreeSpan(layout.OuterRingDegreeSpan)
		ring1.showSpark = layout.OuterRingShowSpark
		ring1.colorXP = layout.OuterRingColorXP
		ring1.colorPower = layout.OuterRingColorPower
		ring1.colorStanding = layout.OuterRingColorStanding
		ring1.colorValue = layout.OuterRingColorValue
		ring1.backdropMultiplier = layout.OuterRingBackdropMultiplier
		ring1.sparkMultiplier = layout.OuterRingSparkMultiplier

		-- outer ring value text
		local ring1Value = ring1:CreateFontString()
		ring1Value:SetPoint(unpack(layout.OuterRingValuePlace))
		ring1Value:SetJustifyH(layout.OuterRingValueJustifyH)
		ring1Value:SetJustifyV(layout.OuterRingValueJustifyV)
		ring1Value:SetFontObject(layout.OuterRingValueFont)
		ring1Value.showDeficit = layout.OuterRingValueShowDeficit
		ring1.Value = ring1Value

		-- outer ring value description text
		local ring1ValueDescription = ring1:CreateFontString()
		ring1ValueDescription:SetPoint(unpack(layout.OuterRingValueDescriptionPlace))
		ring1ValueDescription:SetWidth(layout.OuterRingValueDescriptionWidth)
		ring1ValueDescription:SetTextColor(unpack(layout.OuterRingValueDescriptionColor))
		ring1ValueDescription:SetJustifyH(layout.OuterRingValueDescriptionJustifyH)
		ring1ValueDescription:SetJustifyV(layout.OuterRingValueDescriptionJustifyV)
		ring1ValueDescription:SetFontObject(layout.OuterRingValueDescriptionFont)
		ring1ValueDescription:SetIndentedWordWrap(false)
		ring1ValueDescription:SetWordWrap(true)
		ring1ValueDescription:SetNonSpaceWrap(false)
		ring1.Value.Description = ring1ValueDescription

		local outerPercent = toggle:CreateFontString()
		outerPercent:SetDrawLayer("OVERLAY")
		outerPercent:SetJustifyH("CENTER")
		outerPercent:SetJustifyV("MIDDLE")
		outerPercent:SetFontObject(layout.OuterRingValuePercentFont)
		outerPercent:SetShadowOffset(0, 0)
		outerPercent:SetShadowColor(0, 0, 0, 0)
		outerPercent:SetPoint("CENTER", 1, -1)
		ring1.Value.Percent = outerPercent

		-- inner ring
		local ring2 = ringFrame:CreateSpinBar()
		ring2:SetPoint(unpack(layout.InnerRingPlace))
		ring2:SetSize(unpack(layout.InnerRingSize))
		ring2:SetSparkSize(unpack(layout.InnerRingSparkSize))
		ring2:SetSparkInset(layout.InnerRingSparkInset)
		ring2:SetSparkOffset(layout.InnerRingSparkOffset)
		ring2:SetSparkFlash(unpack(layout.InnerRingSparkFlash))
		ring2:SetSparkBlendMode(layout.InnerRingSparkBlendMode)
		ring2:SetClockwise(layout.InnerRingClockwise)
		ring2:SetDegreeOffset(layout.InnerRingDegreeOffset)
		ring2:SetDegreeSpan(layout.InnerRingDegreeSpan)
		ring2:SetStatusBarTexture(layout.InnerRingBarTexture)
		ring2.showSpark = layout.InnerRingShowSpark
		ring2.colorXP = layout.InnerRingColorXP
		ring2.colorPower = layout.InnerRingColorPower
		ring2.colorStanding = layout.InnerRingColorStanding
		ring2.colorValue = layout.InnerRingColorValue
		ring2.backdropMultiplier = layout.InnerRingBackdropMultiplier
		ring2.sparkMultiplier = layout.InnerRingSparkMultiplier

		-- inner ring value text
		local ring2Value = ring2:CreateFontString()
		ring2Value:SetPoint("BOTTOM", ringFrameBg, "CENTER", 0, 2)
		ring2Value:SetJustifyH("CENTER")
		ring2Value:SetJustifyV("TOP")
		ring2Value:SetFontObject(layout.InnerRingValueFont)
		ring2Value.showDeficit = true
		ring2.Value = ring2Value

		local innerPercent = ringFrame:CreateFontString()
		innerPercent:SetDrawLayer("OVERLAY")
		innerPercent:SetJustifyH("CENTER")
		innerPercent:SetJustifyV("MIDDLE")
		innerPercent:SetFontObject(layout.InnerRingValuePercentFont)
		innerPercent:SetShadowOffset(0, 0)
		innerPercent:SetShadowColor(0, 0, 0, 0)
		innerPercent:SetPoint("CENTER", ringFrameBg, "CENTER", 2, -64)
		ring2.Value.Percent = innerPercent

		-- Store the bars locally
		Spinner[1] = ring1
		Spinner[2] = ring2
	end

	-- Classic Tracking button
	-- BC seems to use the dropdown with multiple tracking types...?
	if (IsClassic or IsTBC or IsWrath) then
		local tracking = Handler:CreateOverlayFrame("Button")
		tracking:SetFrameLevel(tracking:GetFrameLevel() + 10) -- need this above the ring frame and the rings
		tracking:SetPoint(unpack(layout.TrackingButtonPlace))
		tracking:SetSize(unpack(layout.TrackingButtonSize))
		tracking:EnableMouse(true)
		tracking:RegisterForClicks("AnyUp")
		tracking._owner = Handler

		local trackingBackdrop = tracking:CreateTexture()
		trackingBackdrop:SetDrawLayer("BACKGROUND")
		trackingBackdrop:SetSize(unpack(layout.TrackingButtonBackdropSize))
		trackingBackdrop:SetPoint("CENTER", 0, 0)
		trackingBackdrop:SetTexture(layout.TrackingButtonBackdropTexture)
		trackingBackdrop:SetVertexColor(unpack(layout.TrackingButtonBackdropColor))

		local trackingTextureBg = tracking:CreateTexture()
		trackingTextureBg:SetDrawLayer("ARTWORK", 0)
		trackingTextureBg:SetPoint("CENTER")
		trackingTextureBg:SetSize(unpack(layout.TrackingButtonIconBgSize))
		trackingTextureBg:SetTexture(layout.TrackingButtonIconBgTexture)
		trackingTextureBg:SetVertexColor(0,0,0,1)

		local trackingTexture = tracking:CreateTexture()
		trackingTexture:SetDrawLayer("ARTWORK", 1)
		trackingTexture:SetPoint("CENTER")
		trackingTexture:SetSize(unpack(layout.TrackingButtonIconSize))
		trackingTexture:SetMask(layout.TrackingButtonIconMask)
		trackingTexture:SetTexture(GetTrackingTexture())
		tracking.Texture = trackingTexture

		tracking:SetScript("OnClick", Tracking_OnClick)
		tracking:SetScript("OnEnter", Tracking_OnEnter)
		tracking:SetScript("OnLeave", Tracking_OnLeave)

		--Minimap:SetScript("OnMouseUp", function(_, button)
		--	if (button == "RightButton") then
		--		--self:ShowTrackingMenu()
		--	else
		--		Minimap_OnClick(Minimap)
		--	end
		--end)

		self:RegisterEvent("UNIT_AURA", "OnEvent")

		Handler.Tracking = tracking
	end

	-- Classic battleground eye
	if (IsClassic or IsTBC or IsWrath) then
		local BGFrame = MiniMapBattlefieldFrame
		local BGFrameBorder = MiniMapBattlefieldBorder
		local BGIcon = MiniMapBattlefieldIcon

		if (BGFrame) then
			local button = Handler:CreateOverlayFrame()
			button:SetFrameLevel(button:GetFrameLevel() + 10)
			button:Place(unpack(layout.BattleGroundEyePlace))
			button:SetSize(unpack(layout.BattleGroundEyeSize))

			local point, x, y = unpack(layout.BattleGroundEyePlace)

			-- For some reason any other points
			BGFrame:ClearAllPoints()
			BGFrame:SetPoint("TOPRIGHT", Minimap, -4, -2)
			BGFrame:SetHitRectInsets(-8, -8, -8, -8)
			BGFrameBorder:Hide()
			BGIcon:SetAlpha(0)

			local eye = button:CreateTexture()
			eye:SetDrawLayer("OVERLAY", 1)
			eye:SetPoint("CENTER", 0, 0)
			eye:SetSize(unpack(layout.BattleGroundEyeSize))
			eye:SetTexture(layout.BattleGroundEyeTexture)
			eye:SetVertexColor(unpack(layout.BattleGroundEyeColor))
			eye:SetShown(BGFrame:IsShown())

			-- This is there in Classic, not BC.
			local tracking = Handler.Tracking
			if (tracking) then
				tracking:Place(unpack(BGFrame:IsShown() and layout.TrackingButtonPlaceAlternate or layout.TrackingButtonPlace))
				BGFrame:HookScript("OnShow", function()
					eye:Show()
					tracking:Place(unpack(layout.TrackingButtonPlaceAlternate))
				end)
				BGFrame:HookScript("OnHide", function()
					eye:Hide()
					tracking:Place(unpack(layout.TrackingButtonPlace))
				end)
			end
		end
	end

	-- Retail groupfinder eye
	if (IsRetail) then
		local queueButton = QueueStatusMinimapButton
		if queueButton then
			local button = Handler:CreateOverlayFrame()
			button:SetFrameLevel(button:GetFrameLevel() + 10)
			button:Place(unpack(layout.GroupFinderEyePlace))
			button:SetSize(unpack(layout.GroupFinderEyeSize))

			queueButton:SetParent(button)
			queueButton:ClearAllPoints()
			queueButton:SetPoint("CENTER", 0, 0)
			queueButton:SetSize(unpack(layout.GroupFinderEyeSize))

			local UIHider = CreateFrame("Frame")
			UIHider:Hide()
			queueButton.Eye.texture:SetParent(UIHider)
			queueButton.Eye.texture:SetAlpha(0)

			--local iconTexture = button:CreateTexture()
			local iconTexture = queueButton:CreateTexture()
			iconTexture:SetDrawLayer("ARTWORK", 1)
			iconTexture:SetPoint("CENTER", 0, 0)
			iconTexture:SetSize(unpack(layout.GroupFinderEyeSize))
			iconTexture:SetTexture(layout.GroupFinderEyeTexture)
			iconTexture:SetVertexColor(unpack(layout.GroupFinderEyeColor))

			QueueStatusFrame:ClearAllPoints()
			QueueStatusFrame:SetPoint(unpack(layout.GroupFinderQueueStatusPlace))
		end
	end

end

-- Set up the MBB (MinimapButtonBag) integration
Module.SetUpMBB = function(self)
	local layout = self.layout

	local Handler = self:GetMinimapHandler()

	local button = Handler:CreateOverlayFrame()
	button:SetFrameLevel(button:GetFrameLevel() + 10)
	button:Place(unpack(layout.MBBPlace))
	button:SetSize(unpack(layout.MBBSize))
	button:SetFrameStrata("LOW") -- MEDIUM collides with Immersion

	local mbbFrame = _G.MBB_MinimapButtonFrame
	mbbFrame:SetParent(button)
	mbbFrame:RegisterForDrag()
	mbbFrame:SetSize(unpack(layout.MBBSize))
	mbbFrame:ClearAllPoints()
	mbbFrame:SetFrameStrata("LOW") -- MEDIUM collides with Immersion
	mbbFrame:SetPoint("CENTER", 0, 0)
	mbbFrame:SetHighlightTexture("")
	mbbFrame:DisableDrawLayer("OVERLAY")

	mbbFrame.ClearAllPoints = function() end
	mbbFrame.SetPoint = function() end
	mbbFrame.SetAllPoints = function() end

	local mbbIcon = _G.MBB_MinimapButtonFrame_Texture
	mbbIcon:ClearAllPoints()
	mbbIcon:SetPoint("CENTER", 0, 0)
	mbbIcon:SetSize(unpack(layout.MBBSize))
	mbbIcon:SetTexture(layout.MBBTexture)
	mbbIcon:SetTexCoord(0,1,0,1)
	mbbIcon:SetAlpha(.85)

	local down, over
	local setalpha = function()
		if (down and over) then
			mbbIcon:SetAlpha(1)
		elseif (down or over) then
			mbbIcon:SetAlpha(.95)
		else
			mbbIcon:SetAlpha(.85)
		end
	end

	mbbFrame:SetScript("OnMouseDown", function(self)
		down = true
		setalpha()
	end)

	mbbFrame:SetScript("OnMouseUp", function(self)
		down = false
		setalpha()
	end)

	mbbFrame:SetScript("OnEnter", function(self)
		over = true
		_G.MBB_ShowTimeout = -1

		local tooltip = Private:GetMinimapTooltip()
		tooltip:SetDefaultAnchor(self)
		tooltip:SetMaximumWidth(320)
		tooltip:AddLine("MinimapButtonBag v" .. MBB_Version)
		tooltip:AddLine(MBB_TOOLTIP1, 0, 1, 0, true)
		tooltip:Show()

		setalpha()
	end)

	mbbFrame:SetScript("OnLeave", function(self)
		over = false
		_G.MBB_ShowTimeout = 0

		local tooltip = Private:GetMinimapTooltip()
		tooltip:Hide()

		setalpha()
	end)
end

-- Fix the frame strata of the Narcissus button
Module.SetUpNarcissus = function(self)
	if (not Narci_MinimapButton) then
		return
	end

	local Handler = self:GetMinimapHandler()
	local Holder = Handler:CreateOverlayFrame()
	local Minimap = self:GetFrame("Minimap")
	local MinimapButton = Narci_MinimapButton

	MinimapButton:SetScript("OnDragStart", nil)
	MinimapButton:SetScript("OnDragStop", nil)

	local dragFrame = MinimapButton.DraggingFrame or Narci_MinimapButton_DraggingFrame
	if (dragFrame) then
		dragFrame:SetScript("OnUpdate", nil)
		dragFrame:SetScript("OnHide", nil)
		dragFrame:Hide()
	end

	MinimapButton_UpdateAngle = function() end
	Narci_MinimapButton_OnLoad = function() end
	Narci_MinimapButton_DraggingFrame_OnUpdate = function() end

	local theme = Private.GetLayoutID()
	local lockdown
	local SetPosition = function()
		if (lockdown) then
			return
		end
		lockdown = true
			MinimapButton:SetParent(Holder)
			MinimapButton:SetFrameStrata("LOW")
			MinimapButton:SetFrameLevel(62)
			MinimapButton:ClearAllPoints()

			-- Narci_MinimapButton.Background:SetSize(56,56)

			if (theme == "Azerite") then
				MinimapButton:SetSize(56,56) -- 36,36
				MinimapButton:SetPoint("CENTER", Minimap, "TOP", 0, 8)
				MinimapButton.Background:SetSize(64,64) -- 42,42

			elseif (theme == "Legacy") then
				MinimapButton:SetSize(48,48) -- 36,36
				MinimapButton:SetPoint("CENTER", Minimap, "TOP", 0, 4)
				MinimapButton.Background:SetVertexColor(.75, .75, .75, 1)
				MinimapButton.Background:SetSize(52,52) -- 42,42
				MinimapButton.Color:SetVertexColor(.85, .85, .85, 1)
			else
				MinimapButton:SetPoint("CENTER", Minimap, "TOP", 0, 0)
			end
		lockdown = nil
	end

	SetPosition()
	hooksecurefunc(MinimapButton, "SetFrameStrata", SetPosition)
	hooksecurefunc(MinimapButton, "SetParent", SetPosition)
	hooksecurefunc(MinimapButton, "SetPoint", SetPosition)
	hooksecurefunc(MinimapButton.Background, "SetSize", SetPosition)

end

-- Perform and initial update of all elements,
-- as this is not done automatically by the back-end.
Module.EnableAllElements = function(self)
	local Handler = self:GetMinimapHandler()
	Handler:EnableAllElements()
end

----------------------------------------------------
-- Map Post Updates
----------------------------------------------------
-- Set the mask texture
Module.UpdateMinimapMask = function(self)
	-- Transparency in these textures also affect the indoors opacity
	-- of the minimap, something changing the map alpha directly does not.
	self:SetMinimapMaskTexture(self.layout.MaskTexture)
end

-- Set the size and position
-- Can't change this in combat, will cause taint!
Module.UpdateMinimapSize = function(self)
	if InCombatLockdown() then
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	end

	local layout = self.layout

	self:SetMinimapSize(unpack(layout.Size))
	self:SetMinimapPosition(unpack(layout.Place))
end

Module.UpdateBars = function(self, event, ...)
	local layout = self.layout
	if (not layout.UseBars) then
		return
	end

	local Handler = self:GetMinimapHandler()
	local hasXP = self:PlayerHasXP()
	local hasRep = self:PlayerHasRep()
	local hasAP = IsRetail and self:PlayerHasAP()

	local first, second
	if (IsClassic or IsTBC or IsWrath) then
		if (hasXP) then
			first = "XP"
			second = hasRep and "Reputation"
		elseif (hasRep) then
			first = "Reputation"
		end
	elseif (IsRetail) then
		if hasXP then
			first = "XP"
		elseif hasRep then
			first = "Reputation"
		elseif hasAP then
			first = "ArtifactPower"
		end
		if first then
			if hasRep and (first ~= "Reputation") then
				second = "Reputation"
			elseif hasAP and (first ~= "ArtifactPower") then
				second = "ArtifactPower"
			end
		end
	end

	if (first or second) then
		if (not Handler.Toggle:IsShown()) then
			Handler.Toggle:Show()
		end

		-- Dual bars
		if (first and second) then

			-- Setup the bars and backdrops for dual bar mode
			if (self.spinnerMode ~= "Dual") then

				-- Set the backdrop to the two bar backdrop
				Handler.Toggle.Frame.Bg:SetTexture(layout.RingFrameBackdropDoubleTexture)

				-- Update the look of the outer spinner
				Spinner[1]:SetStatusBarTexture(layout.RingFrameOuterRingTexture)
				Spinner[1]:SetSparkSize(unpack(layout.RingFrameOuterRingSparkSize))
				Spinner[1]:SetSparkInset(unpack(layout.RingFrameOuterRingSparkInset))
				Spinner[1].PostUpdate = nil
				Spinner[2].PostUpdate = nil

				layout.RingFrameOuterRingValueFunc(Spinner[1].Value, Handler)
			end

			-- Assign the spinners to the elements
			if (self.spinner1 ~= first) then

				-- Disable the old element
				if (self.spinner1) then
					self:DisableMinimapElement(self.spinner1)
				end

				-- Link the correct spinner
				Handler[first] = Spinner[1]

				-- Assign the correct post updates
				if (first == "XP") then
					Spinner[1].OverrideValue = layout.XP_OverrideValue

				elseif (first == "Reputation") then
					Spinner[1].OverrideValue = layout.Rep_OverrideValue

				elseif (first == "ArtifactPower") then
					Spinner[1].OverrideValue = layout.AP_OverrideValue
				end

				-- Enable the updated element
				self:EnableMinimapElement(first)

				-- Run an update
				Handler[first]:ForceUpdate()
			end

			if (self.spinner2 ~= second) then

				-- Disable the old element
				if (self.spinner2) then
					self:DisableMinimapElement(self.spinner2)
				end

				-- Link the correct spinner
				Handler[second] = Spinner[2]

				-- Assign the correct post updates
				if (second == "XP") then
					Handler[second].OverrideValue = layout.XP_OverrideValue

				elseif (second == "Reputation") then
					Handler[second].OverrideValue = layout.Rep_OverrideValue

				elseif (second == "ArtifactPower") then
					Handler[second].OverrideValue = layout.AP_OverrideValue
				end

				-- Enable the updated element
				self:EnableMinimapElement(second)

				-- Run an update
				Handler[second]:ForceUpdate()
			end

			-- Store the current modes
			self.spinnerMode = "Dual"
			self.spinner1 = first
			self.spinner2 = second

		-- Single bar
		else

			-- Disable any previously active secondary element
			if (self.spinner2) and (Handler[self.spinner2]) then
				self:DisableMinimapElement(self.spinner2)
				Handler[self.spinner2] = nil
			end

			-- Setup the bars and backdrops for single bar mode
			if (self.spinnerMode ~= "Single") then

				-- Set the backdrop to the single thick bar backdrop
				Handler.Toggle.Frame.Bg:SetTexture(layout.RingFrameBackdropTexture)

				-- Update the look of the outer spinner to the big single bar look
				Spinner[1]:SetStatusBarTexture(layout.RingFrameSingleRingTexture)
				Spinner[1]:SetSparkSize(unpack(layout.RingFrameSingleRingSparkSize))
				Spinner[1]:SetSparkInset(unpack(layout.RingFrameSingleRingSparkInset))

				layout.RingFrameSingleRingValueFunc(Spinner[1].Value, Handler)

				-- Hide 2nd spinner values
				Spinner[2].Value:SetText("")
				Spinner[2].Value.Percent:SetText("")

				forceUpdate = true
			end

			-- If the second spinner is still shown, hide it!
			if (Spinner[2]:IsShown()) then
				Spinner[2]:Hide()
			end

			-- Update the element if needed
			local forceUpdate
			if (self.spinner1 ~= first) then

				-- Disable the old element
				if (self.spinner1) then
					self:DisableMinimapElement(self.spinner1)
				end

				-- Link the correct spinner
				Handler[first] = Spinner[1]

				-- Assign the correct post updates
				if (first == "XP") then
					Handler[first].OverrideValue = layout.XP_OverrideValue

				elseif (first == "Reputation") then
					Handler[first].OverrideValue = layout.Rep_OverrideValue

				elseif (first == "ArtifactPower") then
					Handler[first].OverrideValue = layout.AP_OverrideValue
				end

				-- Enable the active element
				self:EnableMinimapElement(first)

				forceUpdate = true
			end

			if (forceUpdate) then
				-- Assign the correct post updates
				if (first == "XP") then
					Handler[first].PostUpdate = XP_PostUpdate

				elseif (first == "Reputation") then
					Handler[first].PostUpdate = Rep_PostUpdate

				elseif (first == "ArtifactPower") then
					Handler[first].PostUpdate = AP_PostUpdate
				end

				-- Make sure descriptions are updated
				Handler[first].Value.Description:Show()

				-- Update the visible element
				Handler[first]:ForceUpdate()
			end

			-- Store the current modes
			self.spinnerMode = "Single"
			self.spinner1 = first
			self.spinner2 = nil
		end

		-- Post update the frame, could be sticky
		Toggle_UpdateFrame(Handler.Toggle)
	else
		Handler.Toggle:Hide()
		Handler.Toggle.Frame:Hide()
	end
end

Module.UpdateTracking = function(self)
	if (IsClassic or IsTBC or IsWrath) then
		local Handler = self:GetMinimapHandler()
		local icon = GetTrackingTexture()
		if (icon) then
			Handler.Tracking.Texture:SetTexture(icon)
			Handler.Tracking:Show()
		else
			Handler.Tracking:Hide()
		end
	end
end

----------------------------------------------------
-- Module Initialization
----------------------------------------------------
Module.OnEvent = function(self, event, ...)
	if (event == "PLAYER_LEVEL_UP") then
		local level = ...
		if (level and (level ~= LEVEL)) then
			LEVEL = level
		else
			local level = UnitLevel("player")
			if (not LEVEL) or (LEVEL < level) then
				LEVEL = level
			end
		end
	elseif (event == "PLAYER_REGEN_ENABLED") then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		self:UpdateMinimapSize()
		return
	elseif (event == "PLAYER_ENTERING_WORLD") or (event == "VARIABLES_LOADED") then
		self:UpdateMinimapSize()
		self:UpdateMinimapMask()
		self:UpdateTracking()
		-- Can this force an update in minimap pin addons?
		-- Problem: GatherMate2, HandyNotes and Questie sometimes break for us.
		SetCVar("rotateMinimap", GetCVar("rotateMinimap"))

	elseif (event == "ADDON_LOADED") then
		local addon = ...
		if (addon == "MBB") then
			self:SetUpMBB()
			self.addonCounter = self.addonCounter - 1
			if (self.addonCounter == 0) then
				self:UnregisterEvent("ADDON_LOADED", "OnEvent")
			end
			return
		elseif (addon == "Narcissus") then
			self:SetUpNarcissus()
			self.addonCounter = self.addonCounter - 1
			if (self.addonCounter == 0) then
				self:UnregisterEvent("ADDON_LOADED", "OnEvent")
			end
		end
	elseif (event == "UNIT_AURA") then
		self:UpdateTracking()
	end
	self:UpdateBars()
end

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end
	self.db = GetConfig(self:GetName())
	self.MBB = self:IsAddOnEnabled("MBB")
	self.Narcissus = self:IsAddOnEnabled("Narcissus")

	self:SetUpMinimap()

	if (self.MBB) then
		if (IsAddOnLoaded("MBB")) then
			self:SetUpMBB()
		else
			self.addonCounter = (self.addonCounter or 0) + 1
			self:RegisterEvent("ADDON_LOADED", "OnEvent")
		end
	end

	if (self.Narcissus) then
		if (IsAddOnLoaded("Narcissus")) then
			self:SetUpNarcissus()
		else
			self.addonCounter = (self.addonCounter or 0) + 1
			self:RegisterEvent("ADDON_LOADED", "OnEvent")
		end
	end

	if (self.layout.UseBars) then
		self:UpdateBars()
	end
end

Module.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("VARIABLES_LOADED", "OnEvent") -- size and mask must be updated after this
	self:RegisterEvent("PLAYER_ALIVE", "OnEvent")
	self:RegisterEvent("PLAYER_FLAGS_CHANGED", "OnEvent")
	self:RegisterEvent("PLAYER_LEVEL_UP", "OnEvent")
	--self:RegisterEvent("PLAYER_XP_UPDATE", "OnEvent") -- not sure why I removed this, but surely a reason.
	self:RegisterEvent("UPDATE_FACTION", "OnEvent")

	if (IsRetail) then
		self:RegisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED", "OnEvent") -- bar count updates
		self:RegisterEvent("DISABLE_XP_GAIN", "OnEvent")
		self:RegisterEvent("ENABLE_XP_GAIN", "OnEvent")
		self:RegisterEvent("BAG_UPDATE", "OnEvent") -- needed for artifact power sometimes
	end

	self:EnableAllElements()
end
