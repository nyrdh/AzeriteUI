local LibAura = Wheel("LibAura")
assert(LibAura, "UnitGroupDebuff requires LibAura to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "UnitCast requires LibClientBuild to be loaded.")

-- Lua API
local _G = _G
local math_ceil = math.ceil
local select = select

-- WoW API
local GetActiveSpecGroup = GetActiveSpecGroup
local GetSpecialization = GetSpecialization
local GetTime = GetTime
local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitIsCharmed = UnitIsCharmed

-- Constants for client version
local IsAnyClassic = LibClientBuild:IsAnyClassic()
local IsClassic = LibClientBuild:IsClassic()
local IsTBC = LibClientBuild:IsTBC()
local IsWrath = LibClientBuild:IsWrath()
local IsRetail = LibClientBuild:IsRetail()

-- Player Constants
local _,playerClass = UnitClass("player")
local playerLevel = UnitLevel("player")

-- Base filter for everybody
local baseFilter = {
	HARMFUL = { Boss = true, Custom = true },
	HELPFUL = { Boss = true, Custom = true }
}

-- Class specific aura filter based on learning level of the dispel.
-- *The above is todo, all levels changed in Shadowlands. Blergh.
-- *Also note these are defensive dispels only, not offensive like Steal Magic.
--
-- https://wow.gamepedia.com/Dispel
local classFilter
if (IsClassic) then
	classFilter = ({
		-- CLASS 	= { FILTER_TYPE = { School = Level } }
		DRUID 		= { HARMFUL = { Curse = 1, Poison = 1 } },
		MAGE 		= { HARMFUL = { Curse = 1 } },
		PALADIN 	= { HARMFUL = { Magic = 1, Poison = 1, Disease = 1 } },
		PRIEST 		= { HARMFUL = { Magic = 1, Disease = 1 } },
		SHAMAN 		= { HARMFUL = { Poison = 1, Disease = 1 } },
		WARLOCK 	= { HARMFUL = { Magic = 1 } }
	})[playerClass]
elseif (IsTBC) then
	classFilter = ({
		-- CLASS 	= { FILTER_TYPE = { School = Level } }
		DRUID 		= { HARMFUL = { Curse = 1, Poison = 1 } },
		MAGE 		= { HARMFUL = { Curse = 1 } },
		PALADIN 	= { HARMFUL = { Magic = 1, Poison = 1, Disease = 1 } },
		PRIEST 		= { HARMFUL = { Magic = 1, Disease = 1 } },
		SHAMAN 		= { HARMFUL = { Poison = 1, Disease = 1 } },
		WARLOCK 	= { HARMFUL = { Magic = 1 } }
	})[playerClass]
elseif (IsWrath) then -- copy of retail? is retail still right?
	classFilter = ({
		-- CLASS 	= { FILTER_TYPE = { School = Level } }
		DRUID 		= { HARMFUL = { Curse = 1, Poison = 1 } },
		MAGE 		= { HARMFUL = { Curse = 1 } },
		PALADIN 	= { HARMFUL = { Poison = 1, Disease = 1 } },
		PRIEST 		= { HARMFUL = { Magic = 1, Disease = 1 } },
		SHAMAN 		= { HARMFUL = { Curse = 1 } }
	})[playerClass]
else
	classFilter = ({
		-- CLASS 	= { FILTER_TYPE = { School = Level } }
		DRUID 		= { HARMFUL = { Curse = 1, Poison = 1 } },
		MAGE 		= { HARMFUL = { Curse = 1 } },
		MONK 		= { HARMFUL = { Poison = 1, Disease = 1 } },
		PALADIN 	= { HARMFUL = { Poison = 1, Disease = 1 } },
		PRIEST 		= { HARMFUL = { Magic = 1, Disease = 1 } },
		SHAMAN 		= { HARMFUL = { Curse = 1 } }
	})[playerClass]
end

-- Only list dispels that require a specific spec.
-- *Basically this is all healer classes except priest.
-- *Note that this ONLY applies to Retail, not Classic!
local specFilter = (IsRetail) and ({
	-- CLASS 	= { FILTER_TYPE = { School = SpecID } }
	DRUID 		= { HARMFUL = { Magic = 4 } },
	MONK 		= { HARMFUL = { Magic = 2 } },
	PALADIN 	= { HARMFUL = { Magic = 1 } },
	SHAMAN 		= { HARMFUL = { Magic = 3 } }
})[playerClass]

local UpdateClassFilter = function(level)
	if (classFilter) then
		for filterType,schoolList in pairs(classFilter) do
			for auraType,thresholdLevel in pairs(schoolList) do
				--baseFilter[filterType][auraType] = (thresholdLevel <= level)
				baseFilter[filterType][auraType] = true
			end
		end
	end
	if (specFilter) then
		local activeGroup = GetActiveSpecGroup()
		local currentSpecID = activeGroup and GetSpecialization(false, false, activeGroup)
		if (currentSpecID) then
			for filterType,schoolList in pairs(specFilter) do
				for auraType,specID in pairs(schoolList) do
					baseFilter[filterType][auraType] = (specID == currentSpecID)
				end
			end
		end
	end
end
UpdateClassFilter(playerLevel)

-- SpellIDs that will have their type overridden,
-- to allow for specific auras to be tracked through our system.
local spellTypeOverride = {
	-- Tests (Require Custom to be enabled for Druids to try out)
	--[  8936] = "Custom"  -- Regrowth
}

-- Priority of aura types.
-- Higher means higher.
local PRIORITY_NONE = -9999 -- Start at something outlandishly low.
local priorities = {
	Magic   = 4,
	Curse   = 3,
	Disease = 2,
	Poison  = 1,
	Boss 	= 0, -- put dispellable before boss
	Custom 	= -1 -- put custom last
}

-- Utility Functions
-----------------------------------------------------
-- Time constants
local DAY, HOUR, MINUTE = 86400, 3600, 60
local LONG_THRESHOLD = MINUTE*3

local formatTime = function(time)
	if (time > DAY) then -- more than a day
		return "%.0f%s", math_ceil(time / DAY), "d"
	elseif (time > HOUR) then -- more than an hour
		return "%.0f%s", math_ceil(time / HOUR), "h"
	elseif (time > MINUTE) then -- more than a minute
		return "%.0f%s", math_ceil(time / MINUTE), "m"
	elseif (time > 5) then
		return "%.0f", math_ceil(time)
	elseif (time > .9) then
		return "|cffff8800%.0f|r", math_ceil(time)
	elseif (time > .05) then
		return "|cffff0000%.0f|r", time*10 - time*10%1
	else
		return ""
	end
end

-- Borrow the unitframe tooltip
local GetTooltip = function(element)
	return element.GetTooltip and element:GetTooltip() or element._owner.GetTooltip and element._owner:GetTooltip()
end

local Aura_UpdateTooltip = function(element)
	local tooltip = GetTooltip(element)
	tooltip:Hide()
	tooltip:SetMinimumWidth(160)

	if element.tooltipDefaultPosition then
		tooltip:SetDefaultAnchor(element)

	elseif element.tooltipPoint then
		tooltip:SetOwner(element)
		tooltip:Place(element.tooltipPoint, element.tooltipAnchor or element, element.tooltipRelPoint or element.tooltipPoint, element.tooltipOffsetX or 0, element.tooltipOffsetY or 0)
	else
		tooltip:SetSmartAnchor(element, element.tooltipOffsetX or 10, element.tooltipOffsetY or 10)
	end

	if (element.filter == "HELPFUL") then
		tooltip:SetUnitBuff(element.unit, element.index, element.filter)
	else
		tooltip:SetUnitDebuff(element.unit, element.index, element.filter)
	end
end

local Aura_OnEnter = function(element)
	if element.OnEnter then
		return element:OnEnter()
	end

	element.isMouseOver = true
	element.UpdateTooltip = Aura_UpdateTooltip
	element:UpdateTooltip()

	if element.PostEnter then
		return element:PostEnter()
	end
end

local Aura_OnLeave = function(element)
	if element.OnLeave then
		return element:OnLeave()
	end

	element.UpdateTooltip = nil

	local tooltip = GetTooltip(element)
	tooltip:Hide()

	if element.PostLeave then
		return element:PostLeave()
	end
end

local Aura_SetCooldownTimer = function(element, start, duration)
	local cooldown = element.Cooldown
	if (not cooldown) then
		return
	end
	if (element.showCooldownSpiral) then
		cooldown:SetSwipeColor(0, 0, 0, .75)
		cooldown:SetDrawEdge(false)
		cooldown:SetDrawBling(false)
		cooldown:SetDrawSwipe(true)

		if (duration > .5) then
			element:SetCooldown(start, duration)
			element:Show()
		else
			element:Hide()
		end
	else
		cooldown:Hide()
	end
end

local HZ = 1/20
local Aura_UpdateTimer = function(element, elapsed)
	if element.timeLeft then
		element.elapsed = (element.elapsed or 0) + elapsed
		if (element.elapsed >= HZ) then
			element.timeLeft = element.expirationTime - GetTime()
			if (element.timeLeft > 0) then
				if (element.Time) then
					if (element.timeLeft < LONG_THRESHOLD) or (element.showLongCooldownValues) then
						element.Time:SetFormattedText(formatTime(element.timeLeft))
					else
						element.Time:SetText("")
					end
				end
				if element.PostUpdateTimer then
					element:PostUpdateTimer()
				end
			else
				element:SetScript("OnUpdate", nil)
				Aura_SetCooldownTimer(element, 0,0)
				if (element.Time) then
					element.Time:SetText("")
				end
				element:ForceUpdate()
				if (element:IsShown() and element.PostUpdateTimer) then
					element:PostUpdateTimer()
				end
			end
			element.elapsed = 0
		end
	end
end

-- Use this to initiate the timer bars and spirals on the auras
local Aura_SetTimer = function(element, fullDuration, expirationTime)
	if (fullDuration) and (fullDuration > 0) then

		element.fullDuration = fullDuration
		element.timeStarted = expirationTime - fullDuration
		element.timeLeft = expirationTime - GetTime()
		element:SetScript("OnUpdate", Aura_UpdateTimer)

		Aura_SetCooldownTimer(element, element.timeStarted, element.fullDuration)

	else
		element:SetScript("OnUpdate", nil)

		Aura_SetCooldownTimer(element, 0,0)

		if (element.Time) then
			element.Time:SetText("")
		end
		element.fullDuration = 0
		element.timeStarted = 0
		element.timeLeft = 0
	end

	-- Run module post update
	if (element:IsShown()) and (element.PostUpdateTimer) then
		element:PostUpdateTimer()
	end
end

local Update = function(self, event, unit, ...)
	local forceUpdateFilter
	if (event == "PLAYER_LEVEL_UP") then
		local level = ...
		if (level and (level ~= playerLevel)) then
			playerLevel = level
			if ((not playerLevel) or (playerLevel < level)) then
				playerLevel = level
			end
			UpdateClassFilter(playerLevel)
		end
	elseif (event == "PLAYER_SPECIALIZATION_CHANGED") or (event == "PLAYER_TALENT_UPDATE") or (event == "CHARACTER_POINTS_CHANGED") then
		UpdateClassFilter(playerLevel)
	end
	if (not unit) or (unit ~= self.unit) then
		return
	end

	-- Different GUID means a different player or NPC,
	-- so we want updates to be instant, not smoothed.
	local guid = UnitGUID(unit)
	local forced = event == "Forced"

	local element = self.GroupAura
	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end

	-- Store some basic values on the element
	local forced = forced or guid ~= element.guid
	element.guid = guid

	local canAttack = UnitCanAttack("player", unit)
	local isCharmed = UnitIsCharmed(unit)

	local newID, newPriority, newType, newDebuffType, newFilter, newSpellID
	local newIcon, newCount, newDuration, newExpirationTime

	-- Use a local priority comparison,
	-- avoid changing anything on the element while it's iterating.
	local currentPrio = PRIORITY_NONE

	-- Once for each filter type, as UnitAura can't list HELPFUL and HARMFUL at the same time.
	for filterType,schoolList in pairs(baseFilter) do

		-- Iterate auras until no more exists,
		-- don't rely on values that will be different in Classic and Live.
		local auraID = 0
		while true do
			auraID = auraID + 1

			local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = LibAura:GetUnitAura(unit, auraID, filterType)

			if (not name) then
				break
			end

			-- Clunky, but still shortest current way to bake the overrides into the system
			local auraType = isBossDebuff and "Boss" or spellTypeOverride[spellID] or debuffType

			-- Don't show if the unit is mindcontrolled or attackable for some reason.
			if (auraType and (not isCharmed) and (not canAttack)) then

				-- Do we have a priority for the current aura?
				local prio = schoolList[auraType] and priorities[auraType]
				if (prio and (prio > currentPrio)) then
					newID = auraID
					newPriority = prio
					newType = auraType
					newDebuffType = debuffType
					newFilter = filterType
					newSpellID = spellID
					newIcon = icon
					newCount = count
					newDuration = duration
					newExpirationTime = expirationTime

					-- Update our local prio tracker
					currentPrio = prio
				end
			end
		end
	end

	-- Update the element
	if (newID) then

		-- Too much?
		--element:Hide()
		--print(newSpellID, newID)

		-- Values have to be set before it's shown,
		-- to avoid the update timer bugging out.
		element.priority = newPriority
		element.index = newID
		element.filter = newFilter
		element.type = newType
		element.debuffType = newDebuffType
		element.spellID = newSpellID
		element.duration = newDuration
		element.expirationTime = newExpirationTime

		-- Update element icon
		if (element.Icon) then
			element.Icon:SetTexture(newIcon)
		end

		-- Update stack counts
		if (element.Count) then
			element.Count:SetText((newCount > 1) and newCount or "")
		end

		-- Update timers
		Aura_SetTimer(element, newDuration, newExpirationTime)

		-- Show the button and start the update timer
		element:Show()
	else

		-- Hide the element and halt update timer
		element:Hide()

		-- Clear the icon
		if (element.Icon) then
			element.Icon:SetTexture("")
		end

		-- Clear the stack count
		if (element.Count) then
			element.Count:SetText("")
		end

		-- Clear the timer
		Aura_SetTimer(element)

		-- Clear out the values only after it's been hidden,
		-- to avoid bugging out our update timer.
		element.priority = nil
		element.index = nil
		element.filter = nil
		element.type = nil
		element.debuffType = nil
		element.spellID = nil
		element.duration = nil
		element.expirationTime = nil
	end

	-- Run module post updates.
	if (element.PostUpdate) then
		return element:PostUpdate(unit)
	end
end

local Proxy = function(self, ...)
	return (self.GroupAura.Override or Update)(self, ...)
end

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local element = self.GroupAura
	if (element) then
		local unit = self.unit

		element._owner = self
		element.unit = unit
		element.ForceUpdate = ForceUpdate

		-- Let's make sure this is cleared
		element:SetScript("OnUpdate", nil)

		-- Let the modules decide whether or not
		-- we will use tooltips and mouse capture.
		if (element.disableMouse) then
			element:EnableMouse(false)
			element:SetScript("OnEnter", nil)
			element:SetScript("OnLeave", nil)
		else
			element:EnableMouse(true)
			element:SetScript("OnEnter", Aura_OnEnter)
			element:SetScript("OnLeave", Aura_OnLeave)
		end

		self:RegisterEvent("CHARACTER_POINTS_CHANGED", Proxy, true)
		self:RegisterEvent("UNIT_AURA", Proxy)

		if (IsRetail) then
			self:RegisterEvent("PLAYER_TALENT_UPDATE", Proxy, true)
			self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", Proxy, true)
		end

		return true
	end
end

local Disable = function(self)
	local element = self.GroupAura
	if (element) then
		self:UnregisterEvent("CHARACTER_POINTS_CHANGED", Proxy)
		self:UnregisterEvent("UNIT_AURA", Proxy)

		if (IsRetail) then
			self:UnregisterEvent("PLAYER_TALENT_UPDATE", Proxy)
			self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", Proxy)
		end

		element:Hide()
		element:SetScript("OnUpdate", nil)
	end
end

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do
	Lib:RegisterElement("GroupAura", Enable, Disable, Proxy, 33)
end
