local LibAura = Wheel:Set("LibAura", 37)
if (not LibAura) then
	return
end

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibAura requires LibMessage to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibAura requires LibEvent to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibCast requires LibClientBuild to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibAura requires LibFrame to be loaded.")

local LibAuraData = Wheel("LibAuraData")
assert(LibAuraData, "LibAura requires LibAuraData to be loaded.")

LibMessage:Embed(LibAura)
LibEvent:Embed(LibAura)
LibFrame:Embed(LibAura)
LibAuraData:Embed(LibAura)

-- Lua API
local _G = _G
local assert = assert
local bit_band = bit.band
local date = date
local debugstack = debugstack
local error = error
local pairs = pairs
local select = select
local string_byte = string.byte
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_join = string.join
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local table_remove = table.remove
local tonumber = tonumber
local type = type

-- WoW API
local UnitAura = UnitAura
local UnitBuff = UnitBuff
local UnitClass = UnitClass
local UnitDebuff = UnitDebuff
local UnitGUID = UnitGUID
local UnitIsFeignDeath = UnitIsFeignDeath
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitIsUnit = UnitIsUnit

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Shortcuts
local AuraInfoFlags = LibAuraData:GetAllAuraInfoFlags()
local BitFilters = LibAuraData:GetAllAuraInfoBitFilters()

-- Sourced from FrameXML/BuffFrame.lua
local BUFF_MAX_DISPLAY = BUFF_MAX_DISPLAY
local DEBUFF_MAX_DISPLAY = DEBUFF_MAX_DISPLAY 

-- Add in support for LibClassicDurations.
local LCD
if (IsClassic) then
	LCD = LibStub and LibStub("LibClassicDurations", true)
	if (LCD) then
		local ADDON, Private = ...
		LCD:RegisterFrame(Private)
	end
end

-- Library registries
LibAura.embeds = LibAura.embeds or {}

-- Kill off remnants of old library versions
LibAura.auraCache = nil
LibAura.auraCacheByGUID = nil
LibAura.auraWatches = nil
if (LibAura.frame) then
	LibAura.frame:SetScript("OnUpdate",nil)
	LibAura.frame:SetScript("OnEvent",nil)
	LibAura.frame:UnregisterAllEvents()
	LibAura.frame:Hide()
	LibAura.frame = nil 
end

-- Utility Functions
--------------------------------------------------------------------------
-- Syntax check 
local check = function(value, num, ...)
	assert(type(num) == "number", ("Bad argument #%.0f to '%s': %s expected, got %s"):format(2, "Check", "number", type(num)))
	for i = 1,select("#", ...) do
		if type(value) == select(i, ...) then 
			return 
		end
	end
	local types = string_join(", ", ...)
	local name = string_match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
	error(string_format("Bad argument #%.0f to '%s': %s expected, got %s", num, name, types, type(value)), 3)
end

-- Utility function to parse and order a filter, 
-- to make sure we avoid duplicate caches. 
local parseFilter = function(filter, harmful)
	
	-- speed it up for default situations
	if ((not filter) or (filter == "")) then 
		return harmful and "HARMFUL" or "HELPFUL"
	end

	-- parse the string, ignore separator types and order

	-- debuffs
	local harmful = string_match(filter, "HARMFUL")

	-- buffs
	local helpful = string_match(filter, "HELPFUL")

	-- auras that were applied by the player
	local player = string_match(filter, "PLAYER") 

	-- auras that can be applied (if HELPFUL) or dispelled (if HARMFUL) by the player
	local raid = string_match(filter, "RAID") 

	-- buffs that cannot be removed
	local not_cancelable = string_match(filter, "NOT_CANCELABLE") 
	if (not_cancelable) then
		-- Dumb way to avoid NOT_CANCELABLE also firing for CANCELABLE
		filter = string_gsub(filter, "NOT_CANCELABLE", "")
	end

	-- buffs that can be removed (such as by right-clicking or using the /cancelaura command)
	local cancelable = string_match(filter, "CANCELABLE") 

	-- return a nil value for invalid filters. 
	-- *this might cause an error, but that is the intention.
	if (harmful and helpful) or (cancelable and not_cancelable) then 
		return 
	end

	-- Always include these, as we're always using UnitAura() to retrieve buffs/debuffs.
	-- Default to buffs when no help/harm is mentioned. 
	local parsedFilter = (harmful) and "HARMFUL" or "HELPFUL"

	-- Return a parsed filter with arguments separated by spaces, and in our preferred order.
	-- This way filters with the same arguments can be directly compared later on.
	return parsedFilter .. (player and " PLAYER" or "") 
						.. (raid and " RAID" or "") 
						.. (cancelable and " CANCELABLE" or "") 
						.. (not_cancelable and " NOT_CANCELABLE" or "") 
end 

LibAura.GetUnitAura = function(self, unit, auraID, filter)
	local filter = parseFilter(filter)
	if (not filter) then 
		return 
	end

	local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = UnitAura(unit, auraID, filter)

	if (name) then
		
		-- Add Classic aura duration info
		if (IsClassic) and (LCD) then 
			local durationNew, expirationTimeNew = LCD:GetAuraDurationByUnit(unit, spellId, caster)
			if ((not duration) or (duration == 0)) and (durationNew) then
				duration = durationNew
				expirationTime = expirationTimeNew
			end
		end
		
		-- Add boss flags. Applies to both classic and retail.
		if (AuraInfoFlags[spellId]) then
			if (not isBossDebuff) and (LibAura:HasAuraInfoFlags(spellId, BitFilters.IsBoss)) then
				isBossDebuff = true
			end
		end
		
		-- This just makes more sense, and it works.
		-- The blizzard flag just shows if the player CAN cast it, 
		-- while we're interested if in the player ACTUALLY did it.
		isCastByPlayer = unitCaster == "player"

	end

	return name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3
	
end

LibAura.GetUnitBuff = function(self, unit, auraID, filter)
	--local filter = parseFilter(filter)
	--if (not filter) then 
	--	return 
	--end

	local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff(unit, auraID, filter)

	if (name) then
		
		-- Add Classic aura duration info
		if (IsClassic) and (LCD) then 
			local durationNew, expirationTimeNew = LCD:GetAuraDurationByUnit(unit, spellId, caster)
			if ((not duration) or (duration == 0)) and (durationNew) then
				duration = durationNew
				expirationTime = expirationTimeNew
			end
		end
		
		-- Add boss flags. Applies to both classic and retail.
		if (AuraInfoFlags[spellId]) then
			if (not isBossDebuff) and (LibAura:HasAuraInfoFlags(spellId, BitFilters.IsBoss)) then
				isBossDebuff = true
			end
		end
		
		-- This just makes more sense, and it works.
		-- The blizzard flag just shows if the player CAN cast it, 
		-- while we're interested if in the player ACTUALLY did it.
		isCastByPlayer = unitCaster == "player"

	end

	return name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3

end

LibAura.GetUnitDebuff = function(self, unit, auraID, filter)
	--local filter = parseFilter(filter, true)
	--if (not filter) then 
	--	return 
	--end

	local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = UnitDebuff(unit, auraID, filter)

	if (name) then
		
		-- Add Classic aura duration info
		if (IsClassic) and (LCD) then 
			local durationNew, expirationTimeNew = LCD:GetAuraDurationByUnit(unit, spellId, caster)
			if ((not duration) or (duration == 0)) and (durationNew) then
				duration = durationNew
				expirationTime = expirationTimeNew
			end
		end
		
		-- Add boss flags. Applies to both classic and retail.
		if (AuraInfoFlags[spellId]) then
			if (not isBossDebuff) and (LibAura:HasAuraInfoFlags(spellId, BitFilters.IsBoss)) then
				isBossDebuff = true
			end
		end
		
		-- This just makes more sense, and it works.
		-- The blizzard flag just shows if the player CAN cast it, 
		-- while we're interested if in the player ACTUALLY did it.
		isCastByPlayer = unitCaster == "player"

	end

	return name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3

end

local embedMethods = {
	GetUnitAura = true,
	GetUnitBuff = true,
	GetUnitDebuff = true
}

LibAura.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibAura.embeds) do
	LibAura:Embed(target)
end
