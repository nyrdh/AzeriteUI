local LibAuraData = Wheel:Set("LibAuraData", 30)
if (not LibAuraData) then
	return
end

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibAuraData requires LibClientBuild to be loaded.")

-- Lua API
local bit_band = bit.band
local bit_bor = bit.bor
local pairs = pairs
local select = select

-- Library registries
---------------------------------------------------------------------
LibAuraData.embeds = LibAuraData.embeds or {}
LibAuraData.infoFlags = LibAuraData.infoFlags or {} -- library bitfilters. (ignore the misleading old name)
LibAuraData.auraFlags = LibAuraData.auraFlags or {} -- library info flag cache
LibAuraData.userFlags = LibAuraData.userFlags or {} -- user/module flag cache

-- Quality of Life
---------------------------------------------------------------------
-- Using more appropriate names for the shortcuts.
local BitFilters = LibAuraData.infoFlags
local InfoFlags = LibAuraData.auraFlags
local UserFlags = LibAuraData.userFlags

-- BitFilters
-- The flags in this DB should only describe factual properties
-- of the auras like type of spell, what class it belongs to, etc.
--------------------------------------------------------------------------
-- Clear out any old filters.
-- It is important we reuse the old table, 
-- as modules can have requested it before 
-- the library upgrade took place.
for i in pairs(BitFilters) do
	BitFilters[i] = nil
end

-- Populate the table with the current ones.
-- Note that in classic we are limited to 32 bits,
-- so it's preferable to stay within this limit always.
BitFilters.IsPlayerSpell 		= 2^0
BitFilters.IsRacialSpell 		= 2^1
BitFilters.DEATHKNIGHT 			= 2^2
BitFilters.DEMONHUNTER 			= 2^3
BitFilters.DRUID 				= 2^4
BitFilters.EVOKER 				= 2^31
BitFilters.HUNTER 				= 2^5
BitFilters.MAGE 				= 2^6
BitFilters.MONK 				= 2^7
BitFilters.PALADIN 				= 2^8
BitFilters.PRIEST 				= 2^9
BitFilters.ROGUE 				= 2^10
BitFilters.SHAMAN 				= 2^11
BitFilters.WARLOCK 				= 2^12
BitFilters.WARRIOR 				= 2^13
BitFilters.IsBoss 				= 2^15
BitFilters.IsDungeon 			= 2^16
BitFilters.IsCrowdControl 		= 2^17
BitFilters.IsIncapacitate 		= 2^18
BitFilters.IsRoot 				= 2^19
BitFilters.IsSnare 				= 2^20
BitFilters.IsSilence 			= 2^21
BitFilters.IsStun 				= 2^22
BitFilters.IsTaunt 				= 2^23
BitFilters.IsImmune 			= 2^24
BitFilters.IsImmuneCC 			= 2^25
BitFilters.IsImmuneSpell 		= 2^26
BitFilters.IsImmunePhysical 	= 2^27
BitFilters.IsDisarm 			= 2^28
BitFilters.IsFood 				= 2^29
BitFilters.IsFlask 				= 2^30

--------------------------------------------------------------------------
-- InfoFlag queries
--------------------------------------------------------------------------
-- Add flags to or create the cache entry
-- This is to avoid duplicate entries removing flags
-- self:AddAuraInfoFlags(spellID[,spellID, spellID, ...], flags)
LibAuraData.AddAuraInfoFlags = function(self, ...)
	local numArgs = select("#", ...)
	local flags = select(numArgs, ...)
	for i = 1,(numArgs-1) do
		local spellID = select(i,...)
		if (InfoFlags[spellID]) then 
			InfoFlags[spellID] = bit_bor(InfoFlags[spellID], flags)
		else
			InfoFlags[spellID] = flags
		end 
	end
end

-- Retrieve the current info flags for the aura, or nil if none are set
LibAuraData.GetAuraInfoFlags = function(_, spellID)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	return InfoFlags[spellID]
end

-- Not a fan of this in the slightest,
-- but for purposes of speed we need to hand this table out to the modules. 
-- and in case of library updates we need this table to be the same,
LibAuraData.GetAllAuraInfoFlags = function()
	return InfoFlags
end

-- Check if the provided info flags are set for the aura
-- Comma-separated flags means logical OR,
-- flags added into single input means logical AND.
LibAuraData.HasAuraInfoFlags = function(_, spellID, ...)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	local auraFlags = InfoFlags[spellID]
	if (auraFlags) then
		for i = 1, select("#", ...) do
			local flags = select(i, ...)
			if (bit_band(auraFlags, flags) ~= 0) then
				return true
			end
		end
	end
	return false
end

-- Return the hashed info flag table,
-- to allow easy usage of keywords in the modules.
-- We will have make sure the keywords remain consistent.
LibAuraData.GetAllAuraInfoBitFilters = function()
	return BitFilters
end

--------------------------------------------------------------------------
-- UserFlags
-- The flags set here are registered per module, 
-- and are to be used for the front-end's own purposes, 
-- whether that be display preference, blacklists, whitelists, etc. 
-- Nothing here is global, and all is separate from the InfoFlags.
--------------------------------------------------------------------------
-- Adds a custom aura flag
-- self:AddAuraUserFlags(spellID[,spellID, spellID, ...], flags)
LibAuraData.AddAuraUserFlags = function(self, ...)
	local numArgs = select("#", ...)
	local flags = select(numArgs, ...)
	for i = 1,(numArgs-1) do
		local spellID = select(i,...)
		local userFlags = UserFlags[self]
		if (userFlags) then
			-- If the spellID exists, add additional flags, otherwise just set the flags.
			userFlags[spellID] = userFlags[spellID] and bit_bor(userFlags[spellID], flags) or flags
		else
			-- We didn't have a database at all, so we create it and set the spellID.
			userFlags = { [spellID] = flags }
			UserFlags[self] = userFlags
		end
	end
end 

-- Retrieve the current set flags for the aura, or nil if none are set
LibAuraData.GetAuraUserFlags = function(self, spellID)
	local userFlags = UserFlags[self]
	return userFlags and userFlags[spellID]
end

-- Return the full user flag table for the module.
-- This is supposed to return nil when nothing is registered.
LibAuraData.GetAllAuraUserFlags = function(self)
	return UserFlags[self]
end

-- Check if the provided user flags are set for the aura
-- Comma-separated flags means logical OR,
-- flags added into single input means logical AND.
LibAuraData.HasAuraUserFlags = function(self, spellID, ...)
	local userFlags = UserFlags[self]
	local userFlagsForSpellID = userFlags and userFlags[spellID]
	if (userFlagsForSpellID) then 
		for i = 1, select("#", ...) do
			local flags = select(i, ...)
			if (bit_band(userFlagsForSpellID, flags) ~= 0) then
				return true
			end
		end
	end
	return false
end

-- Remove a set of user flags, or all if no removalFlags are provided.
LibAuraData.RemoveAuraUserFlags = function(self, spellID, removalFlags)
	local userFlags = UserFlags[self]
	local userFlagsForSpellID = userFlags and userFlags[spellID]
	if (not userFlagsForSpellID) then 
		return 
	end 
	local userFlags = UserFlags[self][spellID]
	if removalFlags  then 
		local changed
		for i = 1,64 do -- bit.bits ? 
			local bit = (i-1)^2 -- create a mask 
			local userFlagsHasBit = bit_band(userFlagsForSpellID, bit) -- see if the user filter has the bit set
			local removalFlagsHasBit = bit_band(removalFlags, bit) -- see if the removal flags has the bit set
			if (userFlagsHasBit and removalFlagsHasBit) then 
				userFlagsForSpellID = userFlagsForSpellID - bit -- just simply deduct the masked bit value if it was set
				changed = true 
			end 
		end 
		if (changed) then 
			userFlags[spellID] = userFlagsForSpellID
		end 
	else 
		userFlags[spellID] = nil
	end 
end 

local embedMethods = {
	-- Info flags API
	-- These flags are global, 
	-- and should only be used for factual flags.
	-- Meaning what class or npc can cast it, what type it is, etc.
	-- Nothing related to preference or choice should be registered here.
	GetAllAuraInfoFlags = true, -- retrieve the full info flag table
	GetAllAuraInfoBitFilters = true, -- retrieve the bit filter table
	AddAuraInfoFlags = true, -- add info flags to an auraID
	GetAuraInfoFlags = true, -- get all info flags on an auraID
	HasAuraInfoFlags = true, -- check for a specific info flag on an auraID
	-- User flags API
	-- All are local to the module or object used for registering or calling.
	-- The modules are free to register anything here.
	GetAllAuraUserFlags = true, -- retrieve the full user flag table
	AddAuraUserFlags = true, -- add user flags to an auraID
	GetAuraUserFlags = true, -- retrieve the user flags for an auraID
	HasAuraUserFlags = true, -- check for a specific user flag on an auraID
	RemoveAuraUserFlags = true -- remove a user flag from an auraID
}

LibAuraData.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	LibAuraData.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibAuraData.embeds) do
	LibAuraData:Embed(target)
end

