local LibPlayerData = Wheel:Set("LibPlayerData", 20)
if (not LibPlayerData) then
	return
end

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibCast requires LibClientBuild to be loaded.")

-- Lua API
local _G = _G
local assert = assert
local date = date
local debugstack = debugstack
local error = error
local pairs = pairs
local select = select
local string_byte = string.byte
local string_find = string.find
local string_format = string.format
local string_join = string.join
local string_match = string.match
local string_sub = string.sub
local table_concat = table.concat
local type = type

-- WoW API
local FindActiveAzeriteItem = C_AzeriteItem and C_AzeriteItem.FindActiveAzeriteItem
local GetMaxLevelForLatestExpansion = GetMaxLevelForLatestExpansion
local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetWatchedFactionInfo = GetWatchedFactionInfo
local IsAzeriteItemLocationBankBag = AzeriteUtil and AzeriteUtil.IsAzeriteItemLocationBankBag
local IsXPUserDisabled = IsXPUserDisabled
local UnitLevel = UnitLevel

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Library registries
---------------------------------------------------------------------	
LibPlayerData.embeds = LibPlayerData.embeds or {}

-- Utility Functions
---------------------------------------------------------------------	
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

if (IsClassic) then

	-- Return whether the player currently can gain XP
	LibPlayerData.PlayerHasXP = function() return (UnitLevel("player") < 60) end

	-- Returns whether the player is  tracking a reputation
	LibPlayerData.PlayerHasRep = function()
		return GetWatchedFactionInfo() and true or false 
	end

	-- Just in case I slip up and use the wrong API.
	LibPlayerData.PlayerHasAP = function() end

elseif (IsRetail) then

	-- Return whether the player currently can gain XP
	LibPlayerData.PlayerHasXP = function(useExpansionMax)
		if (not IsXPUserDisabled()) then 
			if (useExpansionMax) then 
				return (UnitLevel("player") < GetMaxLevelForLatestExpansion())
			else
				return (UnitLevel("player") < GetMaxLevelForPlayerExpansion())
			end 
		end
		return false
	end

	LibPlayerData.PlayerHasAP = function()
		local azeriteItemLocation = FindActiveAzeriteItem()
		if (azeriteItemLocation) and (not IsAzeriteItemLocationBankBag(azeriteItemLocation)) then
			return azeriteItemLocation
		end
	end

	-- Returns whether the player is  tracking a reputation
	LibPlayerData.PlayerHasRep = function()
		local name, reaction, min, max, current, factionID = GetWatchedFactionInfo()
		if name then 
			local numFactions = GetNumFactions()
			for i = 1, numFactions do
				local factionName, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)
				local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionID)
				if (factionName == name) then
					if (standingID) then 
						return true
					else 
						return false
					end 
				end
			end
		end 
	end

end

local embedMethods = {
	PlayerHasRep = true,
	PlayerHasXP = true,
	PlayerHasAP = true
}

LibPlayerData.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	LibPlayerData.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibPlayerData.embeds) do
	LibPlayerData:Embed(target)
end
