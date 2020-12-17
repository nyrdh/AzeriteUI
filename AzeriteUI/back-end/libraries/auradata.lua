local LibAuraData = Wheel:Set("LibAuraData", 14)
if (not LibAuraData) then
	return
end

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibAuraData requires LibClientBuild to be loaded.")

-- Lua API
local _G = _G
local assert = assert
local bit_band = bit.band
local bit_bor = bit.bor
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

-- Library registries
---------------------------------------------------------------------
LibAuraData.embeds = LibAuraData.embeds or {}
LibAuraData.infoFlags = LibAuraData.infoFlags or {} -- static library info flags about the auras
LibAuraData.auraFlags = LibAuraData.auraFlags or {} -- static library aura flag cache
LibAuraData.userFlags = LibAuraData.userFlags or {} -- static user/module flag cache

-- Quality of Life
---------------------------------------------------------------------
local InfoFlags = LibAuraData.infoFlags
local AuraFlags = LibAuraData.auraFlags
local UserFlags = LibAuraData.userFlags

-- Local constants & tables
---------------------------------------------------------------------
-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

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

--------------------------------------------------------------------------
-- InfoFlag queries
--------------------------------------------------------------------------
-- Not a fan of this in the slightest,
-- but for purposes of speed we need to hand this table out to the modules. 
-- and in case of library updates we need this table to be the same,
LibAuraData.GetAllAuraInfoFlags = function()
	return AuraFlags
end

-- Return the hashed info flag table,
-- to allow easy usage of keywords in the modules.
-- We will have make sure the keywords remain consistent.
LibAuraData.GetAllAuraInfoBitFilters = function()
	return InfoFlags
end

-- Check if the provided info flags are set for the aura
-- Comma-separated flags means logical OR,
-- flags added into single input means logical AND.
LibAuraData.HasAuraInfoFlags = function(_, spellID, ...)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	if (AuraFlags[spellID]) then
		for i = 1, select("#", ...) do
			local flags = select(i, ...)
			if (bit_band(AuraFlags[spellID], flags) ~= 0) then
				return true
			end
		end
	end
	return false
end

-- Retrieve the current info flags for the aura, or nil if none are set
LibAuraData.GetAuraInfoFlags = function(_, spellID)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	return AuraFlags[spellID]
end

--------------------------------------------------------------------------
-- UserFlags
-- The flags set here are registered per module, 
-- and are to be used for the front-end's own purposes, 
-- whether that be display preference, blacklists, whitelists, etc. 
-- Nothing here is global, and all is separate from the InfoFlags.
--------------------------------------------------------------------------
-- Adds a custom aura flag
LibAuraData.AddAuraUserFlags = function(self, spellID, flags)
	check(spellID, 1, "number")
	check(flags, 2, "number")
	if (not UserFlags[self]) then 
		UserFlags[self] = {}
	end 
	if (not UserFlags[self][spellID]) then 
		UserFlags[self][spellID] = flags
		return 
	end 
	UserFlags[self][spellID] = bit_bor(UserFlags[self][spellID], flags)
end 

-- Retrieve the current set flags for the aura, or nil if none are set
LibAuraData.GetAuraUserFlags = function(self, spellID)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	if (not UserFlags[self]) or (not UserFlags[self][spellID]) then 
		return 
	end 
	return UserFlags[self][spellID]
end

-- Return the full user flag table for the module
LibAuraData.GetAllAuraUserFlags = function(self)
	return UserFlags[self]
end

-- Check if the provided user flags are set for the aura
-- Comma-separated flags means logical OR,
-- flags added into single input means logical AND.
LibAuraData.HasAuraUserFlags = function(self, spellID, ...)
	-- Not verifying input types as we don't want the extra function calls on 
	-- something that might be called multiple times each second. 
	if (UserFlags[self] and UserFlags[self][spellID]) then 
		for i = 1, select("#", ...) do
			local flags = select(i, ...)
			if (bit_band(UserFlags[self][spellID], flags) ~= 0) then
				return true
			end
		end
	end
	return false
end

-- Remove a set of user flags, or all if no removalFlags are provided.
LibAuraData.RemoveAuraUserFlags = function(self, spellID, removalFlags)
	check(spellID, 1, "number")
	check(removalFlags, 2, "number", "nil")
	if (not UserFlags[self]) or (not UserFlags[self][spellID]) then 
		return 
	end 
	local userFlags = UserFlags[self][spellID]
	if removalFlags  then 
		local changed
		for i = 1,64 do -- bit.bits ? 
			local bit = (i-1)^2 -- create a mask 
			local userFlagsHasBit = bit_band(userFlags, bit) -- see if the user filter has the bit set
			local removalFlagsHasBit = bit_band(removalFlags, bit) -- see if the removal flags has the bit set
			if (userFlagsHasBit and removalFlagsHasBit) then 
				userFlags = userFlags - bit -- just simply deduct the masked bit value if it was set
				changed = true 
			end 
		end 
		if (changed) then 
			UserFlags[self][spellID] = userFlags
		end 
	else 
		UserFlags[self][spellID] = nil
	end 
end 

local embedMethods = {
	GetAllAuraInfoFlags = true,
	GetAllAuraUserFlags = true,
	GetAllAuraInfoBitFilters = true,
	GetAuraInfoFlags = true,
	HasAuraInfoFlags = true,
	AddAuraUserFlags = true,
	GetAuraUserFlags = true,
	HasAuraUserFlags = true,
	RemoveAuraUserFlags = true
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

-- Databases
--------------------------------------------------------------------------
--------------------------------------------------------------------------
-- InfoFlags
-- The flags in this DB should only describe factual properties
-- of the auras like type of spell, what class it belongs to, etc.
--------------------------------------------------------------------------

local PlayerSpell 		= 2^0
local RacialSpell 		= 2^1

local DEATHKNIGHT 		= 2^2
local DEMONHUNTER 		= 2^3
local DRUID 			= 2^4
local HUNTER 			= 2^5
local MAGE 				= 2^6
local MONK 				= 2^7
local PALADIN 			= 2^8
local PRIEST 			= 2^9
local ROGUE 			= 2^10
local SHAMAN 			= 2^11
local WARLOCK 			= 2^12
local WARRIOR 			= 2^13

local Boss 				= 2^15
local Dungeon 			= 2^16

local CrowdControl 		= 2^17
local Incapacitate 		= 2^18
local Root 				= 2^19
local Snare 			= 2^20
local Silence 			= 2^21
local Stun 				= 2^22
local Taunt 			= 2^23
local Immune 			= 2^24
local ImmuneCC 			= 2^25
local ImmuneSpell 		= 2^26
local ImmunePhysical 	= 2^27
local Disarm 			= 2^28

local Food 				= 2^29
local Flask 			= 2^30

InfoFlags.IsPlayerSpell = PlayerSpell
InfoFlags.IsRacialSpell = RacialSpell

InfoFlags.DEATHKNIGHT = DEATHKNIGHT
InfoFlags.DEMONHUNTER = DEMONHUNTER
InfoFlags.DRUID = DRUID
InfoFlags.HUNTER = HUNTER
InfoFlags.MAGE = MAGE
InfoFlags.MONK = MONK
InfoFlags.PALADIN = PALADIN
InfoFlags.PRIEST = PRIEST
InfoFlags.ROGUE = ROGUE
InfoFlags.SHAMAN = SHAMAN
InfoFlags.WARLOCK = WARLOCK
InfoFlags.WARRIOR = WARRIOR

InfoFlags.IsBoss = Boss
InfoFlags.IsDungeon = Dungeon

InfoFlags.IsCrowdControl = CrowdControl
InfoFlags.IsIncapacitate = Incapacitate
InfoFlags.IsRoot = Root
InfoFlags.IsSnare = Snare
InfoFlags.IsSilence = Silence
InfoFlags.IsStun = Stun
InfoFlags.IsImmune = Immune
InfoFlags.IsImmuneCC = ImmuneCC
InfoFlags.IsImmuneSpell = ImmuneSpell
InfoFlags.IsImmunePhysical = ImmunePhysical
InfoFlags.IsDisarm = Disarm
InfoFlags.IsFood = Food
InfoFlags.IsFlask = Flask

-- For convenience farther down the list here
local IsDeathKnight = PlayerSpell + DEATHKNIGHT
local IsDemonHunter = PlayerSpell + DEMONHUNTER
local IsDruid = PlayerSpell + DRUID
local IsHunter = PlayerSpell + HUNTER
local IsMage = PlayerSpell + MAGE
local IsMonk = PlayerSpell + MONK
local IsPaladin = PlayerSpell + PALADIN
local IsPriest = PlayerSpell + PRIEST
local IsRogue = PlayerSpell + ROGUE
local IsShaman = PlayerSpell + SHAMAN
local IsWarlock = PlayerSpell + WARLOCK
local IsWarrior = PlayerSpell + WARRIOR

local IsBoss = Boss
local IsDungeon = Dungeon

local IsIncap = CrowdControl + Incapacitate
local IsRoot = CrowdControl + Root
local IsSnare = CrowdControl + Snare
local IsSilence = CrowdControl + Silence
local IsStun = CrowdControl + Stun
local IsTaunt = Taunt
local IsImmune = Immune
local IsImmuneCC = ImmuneCC
local IsImmuneSpell = ImmuneSpell
local IsImmunePhysical = ImmunePhysical
local IsDisarm = Disarm
local IsFood = Food
local IsFlask = Flask

-- Add flags to or create the cache entry
-- This is to avoid duplicate entries removing flags
local AddFlags = function(spellID, flags)
	if (not AuraFlags[spellID]) then 
		AuraFlags[spellID] = flags
		return 
	end 
	AuraFlags[spellID] = bit_bor(AuraFlags[spellID], flags)
end

local PopulateClassicClassDatabase = function()

	-- Druid
	-----------------------------------------------------------------
	do
		-- Druid (Balance)
		-- https://classic.wowhead.com/druid-abilities/balance
		-- https://classic.wowhead.com/balance-druid-talents
		------------------------------------------------------------------------
		AddFlags(22812, IsDruid) 					-- Barkskin
		AddFlags(  339, IsDruid + IsRoot) 			-- Entangling Roots (Rank 1)
		AddFlags( 1062, IsDruid + IsRoot) 			-- Entangling Roots (Rank 2)
		AddFlags( 5195, IsDruid + IsRoot) 			-- Entangling Roots (Rank 3)
		AddFlags( 5196, IsDruid + IsRoot) 			-- Entangling Roots (Rank 4)
		AddFlags( 9852, IsDruid + IsRoot) 			-- Entangling Roots (Rank 5)
		AddFlags( 9853, IsDruid + IsRoot) 			-- Entangling Roots (Rank 6)
		AddFlags(  770, IsDruid) 					-- Faerie Fire (Rank 1)
		AddFlags(  778, IsDruid) 					-- Faerie Fire (Rank 2)
		AddFlags( 9749, IsDruid) 					-- Faerie Fire (Rank 3)
		AddFlags( 9907, IsDruid) 					-- Faerie Fire (Rank 4)
		AddFlags( 2637, IsDruid + IsIncap) 			-- Hibernate (Rank 1)
		AddFlags(18657, IsDruid + IsIncap) 			-- Hibernate (Rank 2)
		AddFlags(18658, IsDruid + IsIncap) 			-- Hibernate (Rank 3)
		AddFlags(16914, IsDruid) 					-- Hurricane (Rank 1)
		AddFlags(17401, IsDruid) 					-- Hurricane (Rank 2)
		AddFlags(17402, IsDruid) 					-- Hurricane (Rank 3)
		AddFlags( 8921, IsDruid) 					-- Moonfire (Rank 1)
		AddFlags( 8924, IsDruid) 					-- Moonfire (Rank 2)
		AddFlags( 8925, IsDruid) 					-- Moonfire (Rank 3)
		AddFlags( 8926, IsDruid) 					-- Moonfire (Rank 4)
		AddFlags( 8927, IsDruid) 					-- Moonfire (Rank 5)
		AddFlags( 8928, IsDruid) 					-- Moonfire (Rank 6)
		AddFlags( 8929, IsDruid) 					-- Moonfire (Rank 7)
		AddFlags( 9833, IsDruid) 					-- Moonfire (Rank 8)
		AddFlags( 9834, IsDruid) 					-- Moonfire (Rank 9)
		AddFlags( 9835, IsDruid) 					-- Moonfire (Rank 10)
		AddFlags(24907, IsDruid) 					-- Moonkin Aura
		AddFlags(24858, IsDruid) 					-- Moonkin Form (Shapeshift)(Talent)
		AddFlags(16689, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 1)(Talent)
		AddFlags(16810, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 2)
		AddFlags(16811, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 3)
		AddFlags(16812, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 4)
		AddFlags(16813, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 5)
		AddFlags(17329, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 6)
		AddFlags(16864, IsDruid) 					-- Omen of Clarity (Buff)(Talent)
		AddFlags(16870, IsDruid) 					-- Omen of Clarity (Proc)(Talent)
		AddFlags( 2908, IsDruid) 					-- Soothe Animal (Rank 1)
		AddFlags( 8955, IsDruid) 					-- Soothe Animal (Rank 2)
		AddFlags( 9901, IsDruid) 					-- Soothe Animal (Rank 3)
		AddFlags(  467, IsDruid) 					-- Thorns (Rank 1)
		AddFlags(  782, IsDruid) 					-- Thorns (Rank 2)
		AddFlags( 1075, IsDruid) 					-- Thorns (Rank 3)
		AddFlags( 8914, IsDruid) 					-- Thorns (Rank 4)
		AddFlags( 9756, IsDruid) 					-- Thorns (Rank 5)
		AddFlags( 9910, IsDruid) 					-- Thorns (Rank 6)

		-- Druid (Feral)
		-- https://classic.wowhead.com/druid-abilities/feral-combat
		-- https://classic.wowhead.com/feral-combat-druid-talents
		------------------------------------------------------------------------
		AddFlags( 1066, IsDruid) 					-- Aquatic Form (Shapeshift)
		AddFlags( 5211, IsDruid + IsStun) 			-- Bash (Rank 1)
		AddFlags( 6798, IsDruid + IsStun) 			-- Bash (Rank 2)
		AddFlags( 8983, IsDruid + IsStun) 			-- Bash (Rank 3)
		AddFlags(  768, IsDruid) 					-- Cat Form (Shapeshift)
		AddFlags( 5209, IsDruid + IsTaunt) 			-- Challenging Roar (Taunt)
		AddFlags(   99, IsDruid) 					-- Demoralizing Roar (Rank 1)
		AddFlags( 1735, IsDruid) 					-- Demoralizing Roar (Rank 2)
		AddFlags( 9490, IsDruid) 					-- Demoralizing Roar (Rank 3)
		AddFlags( 9747, IsDruid) 					-- Demoralizing Roar (Rank 4)
		AddFlags( 9898, IsDruid) 					-- Demoralizing Roar (Rank 5)
		AddFlags( 1850, IsDruid) 					-- Dash (Rank 1)
		AddFlags( 9821, IsDruid) 					-- Dash (Rank 2)
		AddFlags( 9634, IsDruid) 					-- Dire Bear Form (Shapeshift)
		AddFlags( 5229, IsDruid) 					-- Enrage
		AddFlags(16857, IsDruid) 					-- Faerie Fire (Feral) (Rank 1)(Talent)
		AddFlags(17390, IsDruid) 					-- Faerie Fire (Feral) (Rank 2)
		AddFlags(17391, IsDruid) 					-- Faerie Fire (Feral) (Rank 3)
		AddFlags(17392, IsDruid) 					-- Faerie Fire (Feral) (Rank 4)
		AddFlags(16979, IsDruid + IsRoot) 			-- Feral Charge Effect (Talent)
		AddFlags(22842, IsDruid) 					-- Frenzied Regeneration (Rank 1)
		AddFlags(22895, IsDruid) 					-- Frenzied Regeneration (Rank 2)
		AddFlags(22896, IsDruid) 					-- Frenzied Regeneration (Rank 3)
		AddFlags( 6795, IsDruid + IsTaunt) 			-- Growl (Taunt)
		AddFlags(24932, IsDruid) 					-- Leader of the Pack(Talent)
		AddFlags( 9005, IsDruid + IsStun) 			-- Pounce (Stun) (Rank 1)
		AddFlags( 9823, IsDruid + IsStun) 			-- Pounce (Stun) (Rank 2)
		AddFlags( 9827, IsDruid + IsStun) 			-- Pounce (Stun) (Rank 3)
		AddFlags( 9007, IsDruid) 					-- Pounce Bleed (Rank 1)
		AddFlags( 9824, IsDruid) 					-- Pounce Bleed (Rank 2)
		AddFlags( 9826, IsDruid) 					-- Pounce Bleed (Rank 3)
		AddFlags( 5215, IsDruid) 					-- Prowl (Rank 1)
		AddFlags( 6783, IsDruid) 					-- Prowl (Rank 2)
		AddFlags( 9913, IsDruid) 					-- Prowl (Rank 3)
		AddFlags( 1822, IsDruid) 					-- Rake (Rank 1)
		AddFlags( 1823, IsDruid) 					-- Rake (Rank 2)
		AddFlags( 1824, IsDruid) 					-- Rake (Rank 3)
		AddFlags( 9904, IsDruid) 					-- Rake (Rank 4)
		AddFlags( 1079, IsDruid) 					-- Rip (Rank 1)
		AddFlags( 9492, IsDruid) 					-- Rip (Rank 2)
		AddFlags( 9493, IsDruid) 					-- Rip (Rank 3)
		AddFlags( 9752, IsDruid) 					-- Rip (Rank 4)
		AddFlags( 9894, IsDruid) 					-- Rip (Rank 5)
		AddFlags( 9896, IsDruid) 					-- Rip (Rank 6)
		AddFlags( 5217, IsDruid) 					-- Tiger's Fury (Rank 1)
		AddFlags( 6793, IsDruid) 					-- Tiger's Fury (Rank 2)
		AddFlags( 9845, IsDruid) 					-- Tiger's Fury (Rank 3)
		AddFlags( 9846, IsDruid) 					-- Tiger's Fury (Rank 4)
		AddFlags(  783, IsDruid) 					-- Travel Form (Shapeshift)

		-- Druid (Restoration)
		-- https://classic.wowhead.com/druid-abilities/restoration
		-- https://classic.wowhead.com/restoration-druid-talents
		------------------------------------------------------------------------
		AddFlags( 2893, IsDruid) 					-- Abolish Poison
		AddFlags(21849, IsDruid) 					-- Gift of the Wild (Rank 1)
		AddFlags(21850, IsDruid) 					-- Gift of the Wild (Rank 2)
		AddFlags(29166, IsDruid) 					-- Innervate
		AddFlags( 5570, IsDruid) 					-- Insect Swarm (Rank 1)(Talent)
		AddFlags(24974, IsDruid) 					-- Insect Swarm (Rank 2)
		AddFlags(24975, IsDruid) 					-- Insect Swarm (Rank 3)
		AddFlags(24976, IsDruid) 					-- Insect Swarm (Rank 4)
		AddFlags(24977, IsDruid) 					-- Insect Swarm (Rank 5)
		AddFlags( 1126, IsDruid) 					-- Mark of the Wild (Rank 1)
		AddFlags( 5232, IsDruid) 					-- Mark of the Wild (Rank 2)
		AddFlags( 6756, IsDruid) 					-- Mark of the Wild (Rank 3)
		AddFlags( 5234, IsDruid) 					-- Mark of the Wild (Rank 4)
		AddFlags( 8907, IsDruid) 					-- Mark of the Wild (Rank 5)
		AddFlags( 9884, IsDruid) 					-- Mark of the Wild (Rank 6)
		AddFlags( 9885, IsDruid) 					-- Mark of the Wild (Rank 7)
		AddFlags(17116, IsDruid) 					-- Nature's Swiftness (Clearcast,Instant)(Talent)
		AddFlags( 8936, IsDruid) 					-- Regrowth (Rank 1)
		AddFlags( 8938, IsDruid) 					-- Regrowth (Rank 2)
		AddFlags( 8939, IsDruid) 					-- Regrowth (Rank 3)
		AddFlags( 8940, IsDruid) 					-- Regrowth (Rank 4)
		AddFlags( 8941, IsDruid) 					-- Regrowth (Rank 5)
		AddFlags( 9750, IsDruid) 					-- Regrowth (Rank 6)
		AddFlags( 9856, IsDruid) 					-- Regrowth (Rank 7)
		AddFlags( 9857, IsDruid) 					-- Regrowth (Rank 8)
		AddFlags( 9858, IsDruid) 					-- Regrowth (Rank 9)
		AddFlags(  774, IsDruid) 					-- Rejuvenation (Rank 1)
		AddFlags( 1058, IsDruid) 					-- Rejuvenation (Rank 2)
		AddFlags( 1430, IsDruid) 					-- Rejuvenation (Rank 3)
		AddFlags( 2090, IsDruid) 					-- Rejuvenation (Rank 4)
		AddFlags( 2091, IsDruid) 					-- Rejuvenation (Rank 5)
		AddFlags( 3627, IsDruid) 					-- Rejuvenation (Rank 6)
		AddFlags( 8910, IsDruid) 					-- Rejuvenation (Rank 7)
		AddFlags( 9839, IsDruid) 					-- Rejuvenation (Rank 8)
		AddFlags( 9840, IsDruid) 					-- Rejuvenation (Rank 9)
		AddFlags( 9841, IsDruid) 					-- Rejuvenation (Rank 10)
		AddFlags(25299, IsDruid) 					-- Rejuvenation (Rank 11)
		AddFlags(  740, IsDruid) 					-- Tranquility (Rank 1)
		AddFlags( 8918, IsDruid) 					-- Tranquility (Rank 2)
		AddFlags( 9862, IsDruid) 					-- Tranquility (Rank 3)
		AddFlags( 9863, IsDruid) 					-- Tranquility (Rank 4)
	end

	-- Mage
	-----------------------------------------------------------------
	do
		-- Mage (Arcane)
		-- https://classic.wowhead.com/mage-abilities/arcane
		-- https://classic.wowhead.com/arcane-mage-talents
		------------------------------------------------------------------------
		AddFlags( 1008, IsMage) 					-- Amplify Magic (Rank 1)
		AddFlags( 8455, IsMage) 					-- Amplify Magic (Rank 2)
		AddFlags(10169, IsMage) 					-- Amplify Magic (Rank 3)
		AddFlags(10170, IsMage) 					-- Amplify Magic (Rank 4)
		AddFlags(23028, IsMage) 					-- Arcane Brilliance (Rank 1)
		AddFlags( 1459, IsMage) 					-- Arcane Intellect (Rank 1)
		AddFlags( 1460, IsMage) 					-- Arcane Intellect (Rank 2)
		AddFlags( 1461, IsMage) 					-- Arcane Intellect (Rank 3)
		AddFlags(10156, IsMage) 					-- Arcane Intellect (Rank 4)
		AddFlags(10157, IsMage) 					-- Arcane Intellect (Rank 5)
		AddFlags(12042, IsMage) 					-- Arcane Power (Talent)(Boost)
		AddFlags( 1953, IsMage) 					-- Blink
		AddFlags(12536, IsMage) 					-- Clearcasting (Proc)(Talent)
		AddFlags(  604, IsMage) 					-- Dampen Magic (Rank 1)
		AddFlags( 8450, IsMage) 					-- Dampen Magic (Rank 2)
		AddFlags( 8451, IsMage) 					-- Dampen Magic (Rank 3)
		AddFlags(10173, IsMage) 					-- Dampen Magic (Rank 4)
		AddFlags(10174, IsMage) 					-- Dampen Magic (Rank 5)
		AddFlags( 2855, IsMage) 					-- Detect Magic
		AddFlags(12051, IsMage) 					-- Evocation
		AddFlags( 6117, IsMage) 					-- Mage Armor (Rank 1)
		AddFlags(22782, IsMage) 					-- Mage Armor (Rank 2)
		AddFlags(22783, IsMage) 					-- Mage Armor (Rank 3)
		AddFlags( 1463, IsMage) 					-- Mana Shield (Rank 1)
		AddFlags( 8494, IsMage) 					-- Mana Shield (Rank 2)
		AddFlags( 8495, IsMage) 					-- Mana Shield (Rank 3)
		AddFlags(10191, IsMage) 					-- Mana Shield (Rank 4)
		AddFlags(10192, IsMage) 					-- Mana Shield (Rank 5)
		AddFlags(10193, IsMage) 					-- Mana Shield (Rank 6)
		AddFlags(  118, IsMage + IsIncap) 			-- Polymorph (Rank 1)
		AddFlags(12824, IsMage + IsIncap) 			-- Polymorph (Rank 2)
		AddFlags(12825, IsMage + IsIncap) 			-- Polymorph (Rank 3)
		AddFlags(12826, IsMage + IsIncap) 			-- Polymorph (Rank 4)
		AddFlags(28270, IsMage + IsIncap) 			-- Polymorph: Cow
		AddFlags(28272, IsMage + IsIncap) 			-- Polymorph: Pig
		AddFlags(28271, IsMage + IsIncap) 			-- Polymorph: Turtle
		AddFlags(12043, IsMage) 					-- Presence of Mind (Talent)(Clearcast,Instant)
		AddFlags(  130, IsMage) 					-- Slow Fall

		-- Mage (Fire)
		-- https://classic.wowhead.com/mage-abilities/fire
		-- https://classic.wowhead.com/fire-mage-talents
		------------------------------------------------------------------------
		AddFlags(11113, IsMage + IsSnare) 			-- Blast Wave (Rank 1)(Talent)
		AddFlags(13018, IsMage + IsSnare) 			-- Blast Wave (Rank 2)(Talent)
		AddFlags(13019, IsMage + IsSnare) 			-- Blast Wave (Rank 3)(Talent)
		AddFlags(13020, IsMage + IsSnare) 			-- Blast Wave (Rank 4)(Talent)
		AddFlags(13021, IsMage + IsSnare) 			-- Blast Wave (Rank 5)(Talent)
		AddFlags(28682, IsMage) 					-- Combustion (Talent)(Boost)
		AddFlags(  133, IsMage) 					-- Fireball (Rank 1)
		AddFlags(  143, IsMage) 					-- Fireball (Rank 2)
		AddFlags(  145, IsMage) 					-- Fireball (Rank 3)
		AddFlags( 3140, IsMage) 					-- Fireball (Rank 4)
		AddFlags( 8400, IsMage) 					-- Fireball (Rank 5)
		AddFlags( 8401, IsMage) 					-- Fireball (Rank 6)
		AddFlags( 8402, IsMage) 					-- Fireball (Rank 7)
		AddFlags(10148, IsMage) 					-- Fireball (Rank 8)
		AddFlags(10149, IsMage) 					-- Fireball (Rank 9)
		AddFlags(10150, IsMage) 					-- Fireball (Rank 10)
		AddFlags(10151, IsMage) 					-- Fireball (Rank 11)
		AddFlags(25306, IsMage) 					-- Fireball (Rank 12)
		AddFlags(  543, IsMage) 					-- Fire Ward (Rank 1)
		AddFlags( 8457, IsMage) 					-- Fire Ward (Rank 2)
		AddFlags( 8458, IsMage) 					-- Fire Ward (Rank 3)
		AddFlags(10223, IsMage) 					-- Fire Ward (Rank 4)
		AddFlags(10225, IsMage) 					-- Fire Ward (Rank 5)
		AddFlags( 2120, IsMage) 					-- Flamestrike (Rank 1)
		AddFlags( 2121, IsMage) 					-- Flamestrike (Rank 2)
		AddFlags( 8422, IsMage) 					-- Flamestrike (Rank 3)
		AddFlags( 8423, IsMage) 					-- Flamestrike (Rank 4)
		AddFlags(10215, IsMage) 					-- Flamestrike (Rank 5)
		AddFlags(10216, IsMage) 					-- Flamestrike (Rank 6)
		AddFlags(12654, IsMage) 					-- Ignite Burn CHECK!
		AddFlags(12355, IsMage + IsStun) 			-- Impact (Proc)(Talent)
		AddFlags(11366, IsMage) 					-- Pyroblast (Rank 1)(Talent)
		AddFlags(12505, IsMage) 					-- Pyroblast (Rank 2)(Talent)
		AddFlags(12522, IsMage) 					-- Pyroblast (Rank 3)(Talent)
		AddFlags(12523, IsMage) 					-- Pyroblast (Rank 4)(Talent)
		AddFlags(12524, IsMage) 					-- Pyroblast (Rank 5)(Talent)
		AddFlags(12525, IsMage) 					-- Pyroblast (Rank 6)(Talent)
		AddFlags(12526, IsMage) 					-- Pyroblast (Rank 7)(Talent)
		AddFlags(18809, IsMage) 					-- Pyroblast (Rank 8)(Talent)

		-- Mage (Frost)
		-- https://classic.wowhead.com/mage-abilities/frost
		-- https://classic.wowhead.com/frost-mage-talents
		------------------------------------------------------------------------
		AddFlags(   10, IsMage) 					-- Blizzard (Rank 1)
		AddFlags( 6141, IsMage) 					-- Blizzard (Rank 2)
		AddFlags( 8427, IsMage) 					-- Blizzard (Rank 3)
		AddFlags(10185, IsMage) 					-- Blizzard (Rank 4)
		AddFlags(10186, IsMage) 					-- Blizzard (Rank 5)
		AddFlags(10187, IsMage) 					-- Blizzard (Rank 6)
		AddFlags( 6136, IsMage + IsSnare) 			-- Chilled (Proc)
		AddFlags( 7321, IsMage + IsSnare) 			-- Chilled (Ice Armor Proc)
		AddFlags(12484, IsMage + IsSnare) 			-- Chilled (Proc)
		AddFlags(12485, IsMage + IsSnare) 			-- Chilled (Proc)
		AddFlags(12486, IsMage + IsSnare) 			-- Chilled (Proc)
		AddFlags(12531, IsMage + IsSnare) 			-- Chilling Touch (Proc)
		AddFlags(  120, IsMage + IsSnare) 			-- Cone of Cold (Rank 1)
		AddFlags( 8492, IsMage + IsSnare) 			-- Cone of Cold (Rank 2)
		AddFlags(10159, IsMage + IsSnare) 			-- Cone of Cold (Rank 3)
		AddFlags(10160, IsMage + IsSnare) 			-- Cone of Cold (Rank 4)
		AddFlags(10161, IsMage + IsSnare) 			-- Cone of Cold (Rank 5)
		AddFlags(  116, IsMage + IsSnare) 			-- Frostbolt (Rank 1)
		AddFlags(  205, IsMage + IsSnare) 			-- Frostbolt (Rank 2)
		AddFlags(  837, IsMage + IsSnare) 			-- Frostbolt (Rank 3)
		AddFlags( 7322, IsMage + IsSnare) 			-- Frostbolt (Rank 4)
		AddFlags( 8406, IsMage + IsSnare) 			-- Frostbolt (Rank 5)
		AddFlags( 8407, IsMage + IsSnare) 			-- Frostbolt (Rank 6)
		AddFlags( 8408, IsMage + IsSnare) 			-- Frostbolt (Rank 7)
		AddFlags(10179, IsMage + IsSnare) 			-- Frostbolt (Rank 8)
		AddFlags(10180, IsMage + IsSnare) 			-- Frostbolt (Rank 9)
		AddFlags(10181, IsMage + IsSnare) 			-- Frostbolt (Rank 10)
		AddFlags(25304, IsMage + IsSnare) 			-- Frostbolt (Rank 11)
		AddFlags(  168, IsMage) 					-- Frost Armor (Rank 1)
		AddFlags( 7300, IsMage) 					-- Frost Armor (Rank 2)
		AddFlags( 7301, IsMage) 					-- Frost Armor (Rank 3)
		AddFlags(  122, IsMage + IsRoot) 			-- Frost Nova (Rank 1)
		AddFlags(  865, IsMage + IsRoot) 			-- Frost Nova (Rank 2)
		AddFlags( 6131, IsMage + IsRoot) 			-- Frost Nova (Rank 3)
		AddFlags(10230, IsMage + IsRoot) 			-- Frost Nova (Rank 4)
		AddFlags( 6143, IsMage) 					-- Frost Ward (Rank 1)(Defensive)
		AddFlags( 8461, IsMage) 					-- Frost Ward (Rank 2)(Defensive)
		AddFlags( 8462, IsMage) 					-- Frost Ward (Rank 3)(Defensive)
		AddFlags(10177, IsMage) 					-- Frost Ward (Rank 4)(Defensive)
		AddFlags(28609, IsMage) 					-- Frost Ward (Rank 5)(Defensive)
		AddFlags( 7302, IsMage) 					-- Ice Armor (Rank 1)
		AddFlags( 7320, IsMage) 					-- Ice Armor (Rank 2)
		AddFlags(10219, IsMage) 					-- Ice Armor (Rank 3)
		AddFlags(10220, IsMage) 					-- Ice Armor (Rank 4)
		AddFlags(11426, IsMage) 					-- Ice Barrier (Rank 1)(Defensive)
		AddFlags(13031, IsMage) 					-- Ice Barrier (Rank 2)(Defensive)
		AddFlags(13032, IsMage) 					-- Ice Barrier (Rank 3)(Defensive)
		AddFlags(13033, IsMage) 					-- Ice Barrier (Rank 4)(Defensive)
		AddFlags(11958, IsMage + IsImmune) 			-- Ice Block (Talent)(Defensive)
		AddFlags(12579, IsMage) 					-- Winter's Chill (Proc)(Talent)(Boost)
	end

	-- Warrior
	-----------------------------------------------------------------
	do
		-- Warrior (Arms)
		-- https://classic.wowhead.com/warrior-abilities/arms
		-- https://classic.wowhead.com/arms-warrior-talents
		------------------------------------------------------------------------
		AddFlags( 2457, IsWarrior) 					-- Battle Stance (Shapeshift) CHECK!
		AddFlags( 7922, IsWarrior + IsStun) 		-- Charge Stun
		AddFlags(12162, IsWarrior) 					-- Deep Wounds Bleed (Rank 1) CHECK!
		AddFlags(12850, IsWarrior) 					-- Deep Wounds Bleed (Rank 2) CHECK!
		AddFlags(12868, IsWarrior) 					-- Deep Wounds Bleed (Rank 3) CHECK!
		AddFlags( 1715, IsWarrior + IsSnare) 		-- Hamstring (Rank 1)
		AddFlags( 7372, IsWarrior + IsSnare) 		-- Hamstring (Rank 2)
		AddFlags( 7373, IsWarrior + IsSnare) 		-- Hamstring (Rank 3)
		AddFlags(  694, IsWarrior + IsTaunt) 		-- Mocking Blow (Rank 1)(Taunt)
		AddFlags( 7400, IsWarrior + IsTaunt) 		-- Mocking Blow (Rank 2)
		AddFlags( 7402, IsWarrior + IsTaunt) 		-- Mocking Blow (Rank 3)
		AddFlags(20559, IsWarrior + IsTaunt) 		-- Mocking Blow (Rank 4)
		AddFlags(20560, IsWarrior + IsTaunt) 		-- Mocking Blow (Rank 5)
		AddFlags(12294, IsWarrior) 					-- Mortal Strike (Rank 1)(Talent)
		AddFlags(21551, IsWarrior) 					-- Mortal Strike (Rank 2)
		AddFlags(21552, IsWarrior) 					-- Mortal Strike (Rank 3)
		AddFlags(21553, IsWarrior) 					-- Mortal Strike (Rank 4)
		AddFlags(  772, IsWarrior) 					-- Rend (Rank 1)
		AddFlags( 6546, IsWarrior) 					-- Rend (Rank 2)
		AddFlags( 6547, IsWarrior) 					-- Rend (Rank 3)
		AddFlags( 6548, IsWarrior) 					-- Rend (Rank 4)
		AddFlags(11572, IsWarrior) 					-- Rend (Rank 5)
		AddFlags(11573, IsWarrior) 					-- Rend (Rank 6)
		AddFlags(11574, IsWarrior) 					-- Rend (Rank 7)
		AddFlags(20230, IsWarrior) 					-- Retaliation (Boost)
		AddFlags(12292, IsWarrior) 					-- Sweeping Strikes (Talent)
		AddFlags( 6343, IsWarrior) 					-- Thunder Clap (Rank 1)
		AddFlags( 8198, IsWarrior) 					-- Thunder Clap (Rank 2)
		AddFlags( 8204, IsWarrior) 					-- Thunder Clap (Rank 3)
		AddFlags( 8205, IsWarrior) 					-- Thunder Clap (Rank 4)
		AddFlags(11580, IsWarrior) 					-- Thunder Clap (Rank 5)
		AddFlags(11581, IsWarrior) 					-- Thunder Clap (Rank 6)

		-- Warrior (Fury)
		-- https://classic.wowhead.com/warrior-abilities/fury
		-- https://classic.wowhead.com/fury-warrior-talents
		------------------------------------------------------------------------
		AddFlags( 6673, IsWarrior) 					-- Battle Shout (Rank 1)
		AddFlags( 5242, IsWarrior) 					-- Battle Shout (Rank 2)
		AddFlags( 6192, IsWarrior) 					-- Battle Shout (Rank 3)
		AddFlags(11549, IsWarrior) 					-- Battle Shout (Rank 4)
		AddFlags(11550, IsWarrior) 					-- Battle Shout (Rank 5)
		AddFlags(11551, IsWarrior) 					-- Battle Shout (Rank 6)
		AddFlags(25289, IsWarrior) 					-- Battle Shout (Rank 7)
		AddFlags(18499, IsWarrior + ImmuneCC) 		-- Berserker Rage (Boost)
		AddFlags( 2458, IsWarrior) 					-- Berserker Stance (Shapeshift)
		AddFlags(16488, IsWarrior) 					-- Blood Craze (Rank 1)(Talent)
		AddFlags(16490, IsWarrior) 					-- Blood Craze (Rank 2)(Talent)
		AddFlags(16491, IsWarrior) 					-- Blood Craze (Rank 3)(Talent)
		AddFlags( 1161, IsWarrior) 					-- Challenging Shout (Taunt)
		AddFlags(12328, IsWarrior + ImmuneCC) 		-- Death Wish (Boost)(Talent)
		AddFlags( 1160, IsWarrior) 					-- Demoralizing Shout (Rank 1)
		AddFlags( 6190, IsWarrior) 					-- Demoralizing Shout (Rank 2)
		AddFlags(11554, IsWarrior) 					-- Demoralizing Shout (Rank 3)
		AddFlags(11555, IsWarrior) 					-- Demoralizing Shout (Rank 4)
		AddFlags(11556, IsWarrior) 					-- Demoralizing Shout (Rank 5)
		AddFlags(12880, IsWarrior) 					-- Enrage (Rank 1)
		AddFlags(14201, IsWarrior) 					-- Enrage (Rank 2)
		AddFlags(14202, IsWarrior) 					-- Enrage (Rank 3)
		AddFlags(14203, IsWarrior) 					-- Enrage (Rank 4)
		AddFlags(14204, IsWarrior) 					-- Enrage (Rank 5)
		AddFlags(12966, IsWarrior) 					-- Flurry (Rank 1)(Talent)
		AddFlags(12967, IsWarrior) 					-- Flurry (Rank 2)(Talent)
		AddFlags(12968, IsWarrior) 					-- Flurry (Rank 3)(Talent)
		AddFlags(12969, IsWarrior) 					-- Flurry (Rank 4)(Talent)
		AddFlags(12970, IsWarrior) 					-- Flurry (Rank 5)(Talent)
		AddFlags(20253, IsWarrior + IsStun) 		-- Intercept Stun (Rank 1)
		AddFlags(20614, IsWarrior + IsStun) 		-- Intercept Stun (Rank 2)
		AddFlags(20615, IsWarrior + IsStun) 		-- Intercept Stun (Rank 3)
		AddFlags( 5246, IsWarrior + IsStun) 		-- Intimidating Shout
		AddFlags(12323, IsWarrior + IsSnare) 		-- Piercing Howl (Talent)
		AddFlags( 1719, IsWarrior + ImmuneCC) 		-- Recklessness (Boost)

		-- Warrior (Protection)
		-- https://classic.wowhead.com/warrior-abilities/protection
		-- https://classic.wowhead.com/protection-warrior-talents
		------------------------------------------------------------------------
		AddFlags(29131, IsWarrior) 					-- Bloodrage
		AddFlags(12809, IsWarrior + IsStun) 		-- Concussion Blow (Talent)
		AddFlags(   71, IsWarrior) 					-- Defensive Stance (Shapeshift)
		AddFlags(  676, IsWarrior) 					-- Disarm
		AddFlags( 2565, IsWarrior) 					-- Shield Block
		AddFlags(  871, IsWarrior) 					-- Shield Wall (Defensive)
		AddFlags( 7386, IsWarrior) 					-- Sunder Armor (Rank 1)
		AddFlags( 7405, IsWarrior) 					-- Sunder Armor (Rank 2)
		AddFlags( 8380, IsWarrior) 					-- Sunder Armor (Rank 3)
		AddFlags(11596, IsWarrior) 					-- Sunder Armor (Rank 4)
		AddFlags(11597, IsWarrior) 					-- Sunder Armor (Rank 5)
	end

	-- Rogue
	-----------------------------------------------------------------
	do
		-- Rogue (Assassination)
		-- https://classic.wowhead.com/rogue-abilities/assassination
		-- https://classic.wowhead.com/assassination-rogue-talents
		------------------------------------------------------------------------
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 

		-- Rogue (Combat)
		-- https://classic.wowhead.com/rogue-abilities/combat
		------------------------------------------------------------------------
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 

		-- Rogue (Subtlety)
		-- https://classic.wowhead.com/rogue-abilities/subtlety
		------------------------------------------------------------------------
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 

		-- Rogue (Poisons)
		-- https://classic.wowhead.com/rogue-abilities/poisons
		-- https://classic.wowhead.com/search?q=poison+proc
		------------------------------------------------------------------------
		--AddFlags(28428, IsRogue) 					-- Instant Poison CHECK!
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
		AddFlags(00000, IsRogue) 					-- 
	end

end

local PopulateClassicNPCDatabase = function()

	-- Blackwing Lair
	------------------------------------------------------------------------
	-- Nefarian
	AddFlags( 23402, IsBoss) -- Corrupted Healing

end

local PopulateRetailClassDatabase = function()

	-- Death Knight
	------------------------------------------------------------------------
	do
		-- Death Knight (Blood)
		-- https://www.wowhead.com/mage-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags(188290, IsDeathKnight) 			-- Death and Decay (Buff)
	end

	-- Druid
	-----------------------------------------------------------------
	do
		-- Druid (Abilities)
		-- https://www.wowhead.com/druid-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags(  5487, IsDruid) 					-- Bear Form (Shapeshift)
		AddFlags(   768, IsDruid) 					-- Cat Form (Shapeshift)
		AddFlags(  1850, IsDruid) 					-- Dash
		AddFlags(   339, IsDruid + IsRoot) 			-- Entangling Roots
		AddFlags(164862, IsDruid) 					-- Flap
		AddFlags(165962, IsDruid) 					-- Flight Form (Shapeshift)
		AddFlags(  6795, IsDruid + IsTaunt) 		-- Growl
		AddFlags(  2637, IsDruid + IsIncap) 		-- Hibernate
		AddFlags(164812, IsDruid) 					-- Moonfire
		AddFlags(  8936, IsDruid) 					-- Regrowth
		AddFlags(210053, IsDruid) 					-- Stag Form (Shapeshift)
		AddFlags(164815, IsDruid) 					-- Sunfire
		AddFlags(106830, IsDruid) 					-- Thrash
		AddFlags(   783, IsDruid) 					-- Travel Form (Shapeshift)

		-- Druid (Talents)
		-- https://www.wowhead.com/druid-talents/live-only:on
		------------------------------------------------------------------------
		AddFlags(155835, IsDruid) 					-- Bristling Fur
		AddFlags(102351, IsDruid) 					-- Cenarion Ward
		AddFlags(202770, IsDruid) 					-- Fury of Elune
		AddFlags(102558, IsDruid) 					-- Incarnation: Guardian of Ursoc (Shapeshift) (Defensive)
		AddFlags(102543, IsDruid) 					-- Incarnation: King of the Jungle (Shapeshift) (Boost)
		AddFlags( 33891, IsDruid) 					-- Incarnation: Tree of Life (Shapeshift)
		AddFlags(102359, IsDruid + IsRoot) 			-- Mass Entanglement
		AddFlags(  5211, IsDruid + IsStun) 			-- Mighty Bash
		AddFlags( 52610, IsDruid) 					-- Savage Roar
		AddFlags(202347, IsDruid) 					-- Stellar Flare
		AddFlags(252216, IsDruid) 					-- Tiger Dash
		AddFlags( 61391, IsDruid + IsSnare) 		-- Typhoon (Proc)
		AddFlags(102793, IsDruid + IsSnare) 		-- Ursol's Vortex
		AddFlags(202425, IsDruid) 					-- Warrior of Elune

		-- Druid (Balance)
		-- https://www.wowhead.com/balance-druid-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags( 22812, IsDruid) 					-- Barkskin (Defensive)
		AddFlags(194223, IsDruid) 					-- Celestial Alignment
		AddFlags( 29166, IsDruid) 					-- Innervate
		AddFlags( 24858, IsDruid) 					-- Moonkin Form (Shapeshift)
		AddFlags(  5215, IsDruid) 					-- Prowl
		AddFlags( 78675, IsDruid) 					-- Solar Beam
		AddFlags(191034, IsDruid) 					-- Starfall
		AddFlags( 93402, IsDruid) 					-- Sunfire

		-- Druid (Feral)
		-- https://www.wowhead.com/feral-druid-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags(106951, IsDruid) 					-- Berserk (Boost)
		AddFlags(135700, IsDruid) 					-- Clearcasting (Omen of Clarity Proc)
		AddFlags(58180, IsDruid) 					-- Infected Wounds (Proc)
		AddFlags( 22570, IsDruid + IsStun) 			-- Maim
		AddFlags(  5215, IsDruid) 					-- Prowl
		AddFlags(155722, IsDruid) 					-- Rake
		AddFlags(  1079, IsDruid) 					-- Rip
		AddFlags(106898, IsDruid) 					-- Stampeding Roar
		AddFlags( 61336, IsDruid) 					-- Survival Instincts (Defensive)
		AddFlags(  5217, IsDruid) 					-- Tiger's Fury

		-- Druid (Guardian)
		-- https://www.wowhead.com/guardian-druid-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags( 22812, IsDruid) 					-- Barkskin (Defensive)
		AddFlags( 22842, IsDruid) 					-- Frenzied Regeneration
		AddFlags(    99, IsDruid + IsIncap) 		-- Incapacitating Roar
		AddFlags(192081, IsDruid) 					-- Ironfur
		AddFlags(  5215, IsDruid) 					-- Prowl
		AddFlags(106898, IsDruid) 					-- Stampeding Roar
		AddFlags( 61336, IsDruid) 					-- Survival Instincts (Defensive)

		-- Druid (Restoration)
		-- https://www.wowhead.com/restoration-druid-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags( 22812, IsDruid) 					-- Barkskin (Defensive)
		AddFlags( 16870, IsDruid) 					-- Clearcasting (Lifebloom Proc)
		AddFlags( 29166, IsDruid) 					-- Innervate
		AddFlags(102342, IsDruid) 					-- Ironbark
		AddFlags( 33763, IsDruid) 					-- Lifebloom
		AddFlags(  5215, IsDruid) 					-- Prowl
		AddFlags(   774, IsDruid) 					-- Rejuvenation
		AddFlags( 93402, IsDruid) 					-- Sunfire
		AddFlags(   740, IsDruid) 					-- Tranquility
		AddFlags( 48438, IsDruid) 					-- Wild Growth
	end

	-- Mage
	-----------------------------------------------------------------
	do
		-- Mage (Abilities)
		-- https://www.wowhead.com/mage-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags(  1459, IsMage) 					-- Arcane Intellect (Raid)
		AddFlags(  1953, IsMage) 					-- Blink
		AddFlags( 33395, IsMage + IsRoot) 			-- Freeze
		AddFlags(   122, IsMage + IsRoot) 			-- Frost Nova
		AddFlags( 45438, IsMage + IsImmune) 		-- Ice Block (Defensive)
		AddFlags( 61305, IsMage + IsIncap) 			-- Polymorph: Black Cat
		AddFlags(277792, IsMage + IsIncap) 			-- Polymorph: Bumblebee
		AddFlags(277787, IsMage + IsIncap) 			-- Polymorph: Direhorn
		AddFlags(161354, IsMage + IsIncap) 			-- Polymorph: Monkey
		AddFlags(161372, IsMage + IsIncap) 			-- Polymorph: Peacock
		AddFlags(161355, IsMage + IsIncap) 			-- Polymorph: Penguin
		AddFlags( 28272, IsMage + IsIncap) 			-- Polymorph: Pig
		AddFlags(161353, IsMage + IsIncap) 			-- Polymorph: Polar Bear Cub
		AddFlags(126819, IsMage + IsIncap) 			-- Polymorph: Porcupine
		AddFlags( 61721, IsMage + IsIncap) 			-- Polymorph: Rabbit
		AddFlags(   118, IsMage + IsIncap) 			-- Polymorph: Sheep
		AddFlags( 61780, IsMage + IsIncap) 			-- Polymorph: Turkey
		AddFlags( 28271, IsMage + IsIncap) 			-- Polymorph: Turtle
		AddFlags(   130, IsMage) 					-- Slow Fall
		AddFlags( 80353, IsMage) 					-- Time Warp (Boost)(Raid)

		-- Mage (Talents)
		-- https://www.wowhead.com/mage-talents/live-only:on
		------------------------------------------------------------------------
		AddFlags(210126, IsMage) 					-- Arcane Familiar
		AddFlags(157981, IsMage + IsSnare) 			-- Blast Wave
		AddFlags(205766, IsMage) 					-- Bone Chilling
		AddFlags(236298, IsMage) 					-- Chrono Shift (Player Speed Boost)
		AddFlags(236299, IsMage + IsSnare) 			-- Chrono Shift (Target Speed Reduction)
		AddFlags(277726, IsMage) 					-- Clearcasting (Amplification Proc)(Clearcast)
		AddFlags(226757, IsMage) 					-- Conflagration
		AddFlags(236060, IsMage) 					-- Frenetic Speed
		AddFlags(199786, IsMage + IsRoot) 			-- Glacial Spike
		AddFlags(108839, IsMage) 					-- Ice Floes
		AddFlags(157997, IsMage + IsRoot) 			-- Ice Nova
		AddFlags( 44457, IsMage) 					-- Living Bomb
		AddFlags(114923, IsMage) 					-- Nether Tempest
		AddFlags(235450, IsMage) 					-- Prismatic Barrier (Mana Shield)(Defensive)
		AddFlags(205021, IsMage + IsSnare) 			-- Ray of Frost
		AddFlags(212653, IsMage) 					-- Shimmer
		AddFlags(210824, IsMage) 					-- Touch of the Magi

		-- Mage (Arcane)
		-- https://www.wowhead.com/arcane-mage-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags( 12042, IsMage) 					-- Arcane Power
		AddFlags( 12051, IsMage) 					-- Evocation
		AddFlags(110960, IsMage) 					-- Greater Invisibility
		AddFlags(    66, IsMage) 					-- Invisibility CHECK!
		AddFlags(205025, IsMage) 					-- Presence of Mind
		AddFlags(235450, IsMage) 					-- Prismatic Barrier
		AddFlags( 31589, IsMage + IsSnare) 			-- Slow

		-- Mage (Fire)
		-- https://www.wowhead.com/fire-mage-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags(190319, IsMage) 					-- Combustion
		AddFlags(235313, IsMage) 					-- Blazing Barrier
		AddFlags(235314, IsMage) 					-- Blazing Barrier (Proc)
		AddFlags(108843, IsMage + IsImmuneCC) 		-- Blazing Speed (Cauterize Proc)
		AddFlags( 31661, IsMage + IsIncap) 			-- Dragon's Breath
		AddFlags(157644, IsMage) 					-- Enhanced Pyrotechnics
		AddFlags(  2120, IsMage + IsSnare) 			-- Flamestrike
		AddFlags(195283, IsMage) 					-- Hot Streak (Proc)

		-- Mage (Frost)
		-- https://www.wowhead.com/frost-mage-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags(   120, IsMage + IsSnare) 			-- Cone of Cold
		AddFlags( 11426, IsMage + IsSnare) 			-- Ice Barrier (PlayerBuff) CHECK!
		AddFlags( 12472, IsMage) 					-- Icy Veins
		
	end

	-- Hunter
	-----------------------------------------------------------------
	do
		-- Hunter (Abilities)
		-- https://www.wowhead.com/hunter-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags( 61648, IsHunter) 				-- Aspect of the Chameleon
		AddFlags(186257, IsHunter) 				-- Aspect of the Cheetah
		AddFlags(186265, IsHunter) 				-- Aspect of the Turtle
		AddFlags(209997, IsHunter) 				-- Play Dead
		AddFlags(  6197, IsHunter) 				-- Eagle Eye
		AddFlags(  5384, IsHunter) 				-- Feign Death
		AddFlags(  1515, IsHunter) 				-- Tame Beast

		-- Hunter (Talents)
		-- https://www.wowhead.com/hunter-talents/live-only:on
		------------------------------------------------------------------------
		AddFlags(131894, IsHunter) 				-- A Murder of Crows
		AddFlags(199483, IsHunter) 				-- Camouflage
		AddFlags(  5116, IsHunter + IsSnare) 	-- Concussive Shot
		AddFlags(260402, IsHunter) 				-- Double Tap
		AddFlags(212431, IsHunter) 				-- Explosive Shot
		AddFlags(257284, IsHunter) 				-- Hunter's Mark
		AddFlags(194594, IsHunter) 				-- Lock and Load (Proc)
		AddFlags( 34477, IsHunter) 				-- Misdirection
		AddFlags(118922, IsHunter) 				-- Posthaste (Disengage Proc)
		AddFlags(271788, IsHunter) 				-- Serpent Sting
		AddFlags(194407, IsHunter) 				-- Spitting Cobra
		AddFlags(268552, IsHunter) 				-- Viper's Venom (Proc)

		-- Hunter (Beast Mastery)
		-- https://www.wowhead.com/beast-mastery-hunter-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags(193530, IsHunter) 				-- Aspect of the Wild
		AddFlags(217200, IsHunter) 				-- Barbed Shot
		AddFlags( 19574, IsHunter) 				-- Bestial Wrath
		AddFlags( 19577, IsHunter + IsTaunt) 	-- Intimidation
		AddFlags(185791, IsHunter) 				-- Wild Call (Proc)

		-- Hunter (Marksmanship)
		-- https://www.wowhead.com/marksmanship-hunter-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags(186387, IsHunter + IsSnare) 	-- Bursting Shot
		AddFlags(257044, IsHunter) 				-- Rapid Fire
		AddFlags(288613, IsHunter) 				-- Trueshot

		-- Hunter (Survival)
		-- https://www.wowhead.com/survival-hunter-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags(266779, IsHunter) 				-- Coordinated Assault
		AddFlags(259491, IsHunter) 				-- Serpent Sting (Survival)
		AddFlags(186260, IsHunter + IsStun) 	-- Harpoon
		AddFlags(195645, IsHunter + IsSnare) 	-- Wing Clip
		AddFlags(186289, IsHunter) 				-- Aspect of the Eagle
	end

	-- Warrior
	-----------------------------------------------------------------
	do
		-- Warrior (Abilities)
		-- https://www.wowhead.com/warrior-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags(  6673, IsWarrior) 				-- Battle Shout
		AddFlags(115767, IsWarrior) 				-- Deep Wounds
		AddFlags(   355, IsWarrior + IsTaunt) 		-- Taunt
		AddFlags(  7922, IsWarrior + IsStun) 		-- Warbringer (Charge Stun)
		AddFlags(213427, IsWarrior + IsStun) 		-- Warbringer (Charge Stun)

		-- Warrior (Talents)
		-- https://www.wowhead.com/warrior-talents/live-only:on
		------------------------------------------------------------------------
		AddFlags(107574, IsWarrior) 				-- Avatar (Boost)
		AddFlags( 46924, IsWarrior + IsImmuneCC) 	-- Bladestorm (Boost)
		AddFlags(262228, IsWarrior) 				-- Deadly Calm (Clearcast)
		AddFlags(197690, IsWarrior) 				-- Defensive Stance
		AddFlags(118000, IsWarrior + IsSnare) 		-- Dragon Roar
		AddFlags(215572, IsWarrior) 				-- Frothing Berserker (Proc)
		AddFlags(275335, IsWarrior) 				-- Punish (Debuff)
		AddFlags(152277, IsWarrior) 				-- Ravager (Boost)
		AddFlags(228920, IsWarrior) 				-- Ravager (Defensive)
		AddFlags(   772, IsWarrior) 				-- Rend
		AddFlags(107570, IsWarrior + IsStun) 		-- Storm Bolt
		AddFlags(262232, IsWarrior + IsSnare) 		-- War Machine (Proc)

		-- Warrior (Arms)
		-- https://www.wowhead.com/arms-warrior-abilities/live-only:on
		------------------------------------------------------------------------
		AddFlags( 18499, IsWarrior + IsImmuneCC) 	-- Berserker Rage (Boost)
		AddFlags(227847, IsWarrior + IsImmuneCC) 	-- Bladestorm (Boost)
		AddFlags(262115, IsWarrior) 				-- Deep Wounds
		AddFlags(118038, IsWarrior) 				-- Die by the Sword (Defensive)
		AddFlags(  1715, IsWarrior + IsSnare) 		-- Hamstring
		AddFlags(  5246, IsWarrior + IsIncap) 		-- Intimidating Shout
		AddFlags(  7384, IsWarrior) 				-- Overpower (Proc)
		AddFlags(260708, IsWarrior) 				-- Sweeping Strikes

		-- Warrior (Fury)
		-- https://www.wowhead.com/fury-warrior-abilities/live-only:on
		------------------------------------------------------------------------
		--AddFlags( 18499, IsWarrior + IsImmuneCC) 	-- Berserker Rage (Boost)
		--AddFlags( 5246, IsWarrior + IsIncap) 		-- Intimidating Shout
		AddFlags( 12323, IsWarrior + IsSnare) 		-- Piercing Howl
		AddFlags(  1719, IsWarrior) 				-- Recklessness (Boost)

		-- Warrior (Protection)
		-- https://www.wowhead.com/protection-warrior-abilities/live-only:on
		------------------------------------------------------------------------
		--AddFlags( 18499, IsWarrior + IsImmuneCC) 	-- Berserker Rage (Boost)
		AddFlags(  1160, IsWarrior) 				-- Demoralizing Shout (Debuff)
		AddFlags(190456, IsWarrior) 				-- Ignore Pain (Defensive)
		--AddFlags( 5246, IsWarrior + IsIncap) 		-- Intimidating Shout
		AddFlags( 12975, IsWarrior) 				-- Last Stand (Defensive)
		AddFlags(   871, IsWarrior) 				-- Shield Wall (Defensive)
		AddFlags( 46968, IsWarrior + IsStun) 		-- Shockwave
		AddFlags( 23920, IsWarrior) 				-- Spell Reflection (Defensive)
		AddFlags(  6343, IsWarrior + IsSnare) 		-- Thunder Clap
	end

end

local PopulateRetailNPCDatabase = function()

	-- Mythic+ Dungeons
	------------------------------------------------------------------------
	AddFlags(240443, IsBoss) -- Bursting
	AddFlags(240559, IsBoss) -- Grievous
	AddFlags(196376, IsBoss) -- Grievous Tear
	AddFlags(209858, IsBoss) -- Necrotic
	AddFlags(226512, IsBoss) -- Sanguine

	-- 8.3 Affix
	AddFlags(314478, IsBoss) -- Cascading Terror
	AddFlags(314483, IsBoss) -- Cascading Terror
	AddFlags(314406, IsBoss) -- Crippling Pestilence
	AddFlags(314565, IsBoss) -- Defiled Ground
	AddFlags(314411, IsBoss) -- Lingering Doubt
	AddFlags(314592, IsBoss) -- Mind Flay
	AddFlags(314308, IsBoss) -- Spirit Breaker
	AddFlags(314531, IsBoss) -- Tear Flesh
	AddFlags(314392, IsBoss) -- Vile Corruption
	
	------------------------------------------------------------------------
	-- Battle for Azeroth Dungeons
	-- *some auras might be under the wrong dungeon, 
	--  this is because wowhead doesn't always tell what casts this.
	------------------------------------------------------------------------
	-- Atal'Dazar
	------------------------------------------------------------------------
	AddFlags(253721, IsDungeon) -- Bulwark of Juju
	AddFlags(253548, IsDungeon) -- Bwonsamdi's Mantle
	AddFlags(255421, IsBoss) 	-- Devour
	AddFlags(256201, IsDungeon) -- Incendiary Rounds
	AddFlags(250371, IsBoss) 	-- Lingering Nausea
	AddFlags(250372, IsDungeon) -- Lingering Nausea
	AddFlags(255582, IsBoss) 	-- Molten Gold
	AddFlags(257407, IsDungeon) -- Pursuit
	AddFlags(255814, IsBoss) 	-- Rending Maul
	AddFlags(255434, IsBoss) 	-- Serrated Teeth
	AddFlags(254959, IsBoss) 	-- Soulburn
	AddFlags(256577, IsBoss) 	-- Soulfeast
	AddFlags(254958, IsDungeon) -- Soulforged Construct
	AddFlags(259187, IsDungeon) -- Soulrend
	AddFlags(255558, IsDungeon) -- Tainted Blood
	AddFlags(255041, IsBoss) 	-- Terrifying Screech
	AddFlags(255371, IsBoss) 	-- Terrifying Visage
	AddFlags(255577, IsDungeon) -- Transfusion
	AddFlags(260667, IsDungeon) -- Transfusion
	AddFlags(260668, IsDungeon) -- Transfusion
	AddFlags(252781, IsBoss) 	-- Unstable Hex
	AddFlags(252687, IsBoss) 	-- Venomfang Strike
	AddFlags(253562, IsBoss) 	-- Wildfire
	AddFlags(250096, IsBoss) 	-- Wracking Pain

	-- Freehold
	------------------------------------------------------------------------
	AddFlags(258875, IsBoss) 	-- Blackout Barrel
	AddFlags(257739, IsDungeon) -- Blind Rage
	AddFlags(257305, IsDungeon) -- Cannon Barrage
	AddFlags(265168, IsDungeon) -- Caustic Freehold Brew
	AddFlags(278467, IsDungeon) -- Caustic Freehold Brew
	AddFlags(265085, IsDungeon) -- Confidence-Boosting Freehold Brew
	AddFlags(265088, IsDungeon) -- Confidence-Boosting Freehold Brew
	AddFlags(268717, IsDungeon) -- Dive Bomb
	AddFlags(258323, IsBoss) 	-- Infected Wound
	AddFlags(264608, IsDungeon) -- Invigorating Freehold Brew
	AddFlags(265056, IsDungeon) -- Invigorating Freehold Brew
	AddFlags(257908, IsBoss) 	-- Oiled Blade
	AddFlags(257775, IsBoss) 	-- Plague Step
	AddFlags(257436, IsBoss) 	-- Poisoning Strike
	AddFlags(274383, IsDungeon) -- Rat Traps
	AddFlags(274389, IsBoss) 	-- Rat Traps
	AddFlags(256363, IsBoss) 	-- Ripper Punch
	AddFlags(274555, IsBoss) 	-- Scabrous Bites
	AddFlags(258777, IsDungeon) -- Sea Spout
	AddFlags(257732, IsDungeon) -- Shattering Bellow
	AddFlags(274507, IsDungeon) -- Slippery Suds

	-- King's Rest
	------------------------------------------------------------------------
	AddFlags(274387, IsDungeon) -- Absorbed in Darkness 
	AddFlags(270084, IsBoss) 	-- Axe Barrage
	AddFlags(266951, IsDungeon) -- Barrel Through
	AddFlags(268586, IsDungeon) -- Blade Combo
	AddFlags(267639, IsDungeon) -- Burn Corruption
	AddFlags(270889, IsDungeon) -- Channel Lightning
	AddFlags(271640, IsBoss) 	-- Dark Revelation
	AddFlags(267626, IsBoss) 	-- Dessication
	AddFlags(267618, IsBoss) 	-- Drain Fluids
	AddFlags(271564, IsBoss) 	-- Embalming Fluid
	AddFlags(269936, IsDungeon) -- Fixate
	AddFlags(268419, IsDungeon) -- Gale Slash
	AddFlags(270514, IsDungeon) -- Ground Crush
	AddFlags(270492, IsBoss) 	-- Hex
	AddFlags(270865, IsBoss) 	-- Hidden Blade
	AddFlags(268796, IsBoss) 	-- Impaling Spear
	AddFlags(265923, IsDungeon) -- Lucre's Call
	AddFlags(276031, IsBoss) 	-- Pit of Despair
	AddFlags(270507, IsBoss) 	-- Poison Barrage
	AddFlags(267273, IsBoss) 	-- Poison Nova
	AddFlags(270284, IsDungeon) -- Purification Beam
	AddFlags(270289, IsDungeon) -- Purification Beam
	AddFlags(270920, IsBoss) 	-- Seduction
	AddFlags(265781, IsDungeon) -- Serpentine Gust
	AddFlags(266231, IsBoss) 	-- Severing Axe
	AddFlags(270487, IsBoss) 	-- Severing Blade
	AddFlags(272388, IsBoss) 	-- Shadow Barrage
	AddFlags(266238, IsBoss) 	-- Shattered Defenses
	AddFlags(265773, IsBoss) 	-- Spit Gold
	AddFlags(270003, IsBoss) 	-- Suppression Slam
	AddFlags(266191, IsBoss) 	-- Whirling Axes
	AddFlags(267763, IsBoss) 	-- Wretched Discharge

	-- Motherlode
	------------------------------------------------------------------------
	AddFlags(262510, IsDungeon) -- Azerite Heartseeker
	AddFlags(262513, IsBoss) 	-- Azerite Heartseeker
	AddFlags(262515, IsDungeon) -- Azerite Heartseeker
	AddFlags(262516, IsDungeon) -- Azerite Heartseeker
	AddFlags(281534, IsDungeon) -- Azerite Heartseeker
	AddFlags(270276, IsDungeon) -- Big Red Rocket
	AddFlags(270277, IsDungeon) -- Big Red Rocket
	AddFlags(270278, IsDungeon) -- Big Red Rocket
	AddFlags(270279, IsDungeon) -- Big Red Rocket
	AddFlags(270281, IsDungeon) -- Big Red Rocket
	AddFlags(270282, IsDungeon) -- Big Red Rocket
	AddFlags(256163, IsDungeon) -- Blazing Azerite
	AddFlags(256493, IsDungeon) -- Blazing Azerite
	AddFlags(270882, IsBoss) 	-- Blazing Azerite
	AddFlags(280605, IsBoss) 	-- Brain Freeze
	AddFlags(259853, IsDungeon) -- Chemical Burn
	AddFlags(259856, IsBoss) 	-- Chemical Burn
	AddFlags(263637, IsBoss) 	-- Clothesline
	AddFlags(268846, IsBoss) 	-- Echo Blade
	AddFlags(262794, IsBoss) 	-- Energy Lash
	AddFlags(263074, IsBoss) 	-- Festering Bite
	AddFlags(260811, IsDungeon) -- Homing Missile
	AddFlags(260813, IsDungeon) -- Homing Missile
	AddFlags(260815, IsDungeon) -- Homing Missile
	AddFlags(260829, IsBoss) 	-- Homing Missile (travelling)
	AddFlags(260835, IsDungeon) -- Homing Missile
	AddFlags(260836, IsDungeon) -- Homing Missile
	AddFlags(260837, IsDungeon) -- Homing Missile
	AddFlags(260838, IsBoss) 	-- Homing Missile (exploded)
	AddFlags(280604, IsBoss) 	-- Iced Spritzer
	AddFlags(257544, IsBoss) 	-- Jagged Cut
	AddFlags(257582, IsDungeon) -- Raging Gaze
	AddFlags(258622, IsDungeon) -- Resonant Pulse
	AddFlags(271579, IsDungeon) -- Rock Lance
	AddFlags(263202, IsDungeon) -- Rock Lance
	AddFlags(257337, IsBoss) 	-- Shocking Claw
	AddFlags(262347, IsDungeon) -- Static Pulse
	AddFlags(257371, IsBoss) 	-- Tear Gas
	AddFlags(275905, IsDungeon) -- Tectonic Smash
	AddFlags(275907, IsDungeon) -- Tectonic Smash
	AddFlags(269302, IsBoss) 	-- Toxic Blades
	AddFlags(268797, IsBoss) 	-- Transmute: Enemy to Goo
	AddFlags(269298, IsDungeon) -- Widowmaker Toxin

	-- Operation Mechagon
	------------------------------------------------------------------------
	AddFlags(294195, IsBoss) 	-- Arcing Zap
	AddFlags(302274, IsBoss) 	-- Fulminating Zap
	AddFlags(294929, IsBoss) 	-- Blazing Chomp
	AddFlags(294855, IsBoss) 	-- Blossom Blast
	AddFlags(299475, IsBoss) 	-- B.O.R.K
	AddFlags(297283, IsBoss) 	-- Cave In
	AddFlags(293670, IsBoss) 	-- Chain Blade
	AddFlags(296560, IsBoss) 	-- Clinging Static
	AddFlags(300659, IsBoss) 	-- Consuming Slime
	AddFlags(291914, IsBoss) 	-- Cutting Beam
	AddFlags(297257, IsBoss) 	-- Electrical Charge
	AddFlags(291972, IsBoss) 	-- Explosive Leap
	AddFlags(291928, IsBoss) 	-- Giga-Zap
	AddFlags(292267, IsBoss) 	-- Giga-Zap
	AddFlags(285443, IsBoss) 	-- "Hidden" Flame Cannon
	AddFlags(291974, IsBoss) 	-- Obnoxious Monologue
	AddFlags(301712, IsBoss) 	-- Pounce
	AddFlags(299572, IsBoss) 	-- Shrink
	AddFlags(298602, IsBoss) 	-- Smoke Cloud
	AddFlags(302384, IsBoss) 	-- Static Discharge
	AddFlags(300650, IsBoss) 	-- Suffocating Smog
	AddFlags(298669, IsBoss) 	-- Taze
	AddFlags(296150, IsBoss) 	-- Vent Blast
	AddFlags(295445, IsBoss) 	-- Wreck

	-- Shrine of the Storm
	------------------------------------------------------------------------
	AddFlags(274720, IsBoss) 	-- Abyssal Strike
	AddFlags(269131, IsDungeon) -- Ancient Mindbender
	AddFlags(268086, IsDungeon) -- Aura of Dread
	AddFlags(268214, IsBoss) 	-- Carving Flesh
	AddFlags(264560, IsBoss) 	-- Choking Brine
	AddFlags(268233, IsBoss) 	-- Electrifying Shock
	AddFlags(268104, IsBoss) 	-- Explosive Void
	AddFlags(264526, IsBoss) 	-- Grasp of the Depths
	AddFlags(276268, IsBoss) 	-- Heaving Blow
	AddFlags(267899, IsDungeon) -- Hindering Cleave
	AddFlags(268391, IsBoss) 	-- Mental Assault
	AddFlags(268896, IsBoss) 	-- Mind Rend
	AddFlags(268212, IsDungeon) -- Minor Reinforcing Ward
	AddFlags(268183, IsDungeon) -- Minor Swiftness Ward
	AddFlags(268184, IsDungeon) -- Minor Swiftness Ward
	AddFlags(267905, IsDungeon) -- Reinforcing Ward
	AddFlags(268186, IsDungeon) -- Reinforcing Ward
	AddFlags(268317, IsBoss) 	-- Rip Mind
	AddFlags(268239, IsDungeon) -- Shipbreaker Storm
	AddFlags(267818, IsBoss) 	-- Slicing Blast
	AddFlags(276286, IsDungeon) -- Slicing Hurricane
	AddFlags(274633, IsBoss) 	-- Sundering Blow
	AddFlags(264101, IsDungeon) -- Surging Rush
	AddFlags(267890, IsDungeon) -- Swiftness Ward
	AddFlags(267891, IsDungeon) -- Swiftness Ward
	AddFlags(268322, IsBoss) 	-- Touch of the Drowned
	AddFlags(264166, IsBoss) 	-- Undertow
	AddFlags(268309, IsBoss) 	-- Unending Darkness
	AddFlags(276297, IsDungeon) -- Void Seed
	AddFlags(267034, IsBoss) 	-- Whispers of Power
	AddFlags(267037, IsDungeon) -- Whispers of Power
	AddFlags(269399, IsDungeon) -- Yawning Gate

	-- Siege of Boralus
	------------------------------------------------------------------------
	AddFlags(272571, IsBoss) 	-- Choking Waters
	AddFlags(256897, IsBoss) 	-- Clamping Jaws
	AddFlags(269029, IsDungeon) -- Clear the Deck
	AddFlags(272144, IsDungeon) -- Cover
	AddFlags(272713, IsBoss) 	-- Crushing Slam
	AddFlags(257168, IsBoss) 	-- Cursed Slash
	AddFlags(273470, IsBoss) 	-- Gut Shot
	AddFlags(261428, IsBoss) 	-- Hangman's Noose
	AddFlags(257292, IsBoss) 	-- Heavy Slash
	AddFlags(273930, IsBoss) 	-- Hindering Cut
	AddFlags(260954, IsDungeon) -- Iron Gaze
	AddFlags(274991, IsBoss) 	-- Putrid Waters
	AddFlags(275014, IsDungeon) -- Putrid Waters
	AddFlags(272588, IsBoss) 	-- Rotting Wounds
	AddFlags(257170, IsDungeon) -- Savage Tempest
	AddFlags(272421, IsDungeon) -- Sighted Artillery
	AddFlags(269266, IsDungeon) -- Slam
	AddFlags(275836, IsDungeon) -- Stinging Venom
	AddFlags(275835, IsBoss) 	-- Stinging Venom Coating
	AddFlags(257169, IsBoss) 	-- Terrifying Roar
	AddFlags(276068, IsDungeon) -- Tidal Surge
	AddFlags(272874, IsBoss) 	-- Trample
	AddFlags(272834, IsBoss) 	-- Viscous Slobber
	AddFlags(260569, IsDungeon) -- Wildfire (?) Waycrest Manor? CHECK!

	-- Temple of Sethraliss
	------------------------------------------------------------------------
	AddFlags(263958, IsBoss) 	-- A Knot of Snakes
	AddFlags(263914, IsBoss) 	-- Blinding Sand
	AddFlags(263371, IsBoss) 	-- Conduction
	AddFlags(263573, IsDungeon) -- Cyclone Strike
	AddFlags(267027, IsBoss) 	-- Cytotoxin
	AddFlags(256333, IsDungeon) -- Dust Cloud
	AddFlags(260792, IsDungeon) -- Dust Cloud
	AddFlags(272659, IsDungeon) -- Electrified Scales
	AddFlags(269670, IsDungeon) -- Empowerment
	AddFlags(268013, IsBoss) 	-- Flame Shock
	AddFlags(266923, IsBoss) 	-- Galvanize
	AddFlags(268007, IsBoss) 	-- Heart Attack
	AddFlags(263246, IsDungeon) -- Lightning Shield
	AddFlags(273563, IsBoss) 	-- Neurotoxin
	AddFlags(272657, IsBoss) 	-- Noxious Breath
	AddFlags(275566, IsDungeon) -- Numb Hands
	AddFlags(269686, IsBoss) 	-- Plague
	AddFlags(272655, IsBoss) 	-- Scouring Sand
	AddFlags(268008, IsBoss) 	-- Snake Charm
	AddFlags(263257, IsDungeon) -- Static Shock
	AddFlags(272699, IsBoss) 	-- Venomous Spit

	-- Tol Dagor
	------------------------------------------------------------------------
	AddFlags(256199, IsDungeon) -- Azerite Rounds: Blast
	AddFlags(256198, IsBoss) 	-- Azerite Rounds: Incendiary
	AddFlags(256955, IsDungeon) -- Cinderflame
	AddFlags(257777, IsBoss) 	-- Crippling Shiv
	AddFlags(256083, IsDungeon) -- Cross Ignition
	AddFlags(256038, IsDungeon) -- Deadeye
	AddFlags(256044, IsBoss) 	-- Deadeye
	AddFlags(258128, IsBoss) 	-- Debilitating Shout
	AddFlags(256101, IsBoss) 	-- Explosive Burst
	AddFlags(256105, IsDungeon) -- Explosive Burst
	AddFlags(257785, IsDungeon) -- Flashing Daggers
	AddFlags(257028, IsBoss) 	-- Fuselighter
	AddFlags(258313, IsBoss) 	-- Handcuff
	AddFlags(256474, IsBoss) 	-- Heartstopper Venom
	AddFlags(257791, IsBoss) 	-- Howling Fear
	AddFlags(258075, IsDungeon) -- Itchy Bite
	AddFlags(260016, IsBoss) 	-- Itchy Bite
	AddFlags(259711, IsBoss) 	-- Lockdown
	AddFlags(258079, IsBoss) 	-- Massive Chomp
	AddFlags(258917, IsBoss) 	-- Righteous Flames
	AddFlags(258317, IsDungeon) -- Riot Shield
	AddFlags(257495, IsDungeon) -- Sandstorm
	AddFlags(257119, IsBoss) 	-- Sand Trap
	AddFlags(258058, IsBoss) 	-- Squeeze
	AddFlags(258864, IsBoss) 	-- Suppression Fire
	AddFlags(265889, IsBoss) 	-- Torch Strike
	AddFlags(260067, IsBoss) 	-- Vicious Mauling
	AddFlags(258153, IsDungeon) -- Watery Dome

	-- Underrot
	------------------------------------------------------------------------
	AddFlags(272592, IsDungeon) -- Abyssal Reach
	AddFlags(265533, IsBoss) 	-- Blood Maw
	AddFlags(264603, IsDungeon) -- Blood Mirror
	AddFlags(260292, IsDungeon) -- Charge
	AddFlags(265568, IsDungeon) -- Dark Omen
	AddFlags(265625, IsBoss) 	-- Dark Omen
	AddFlags(272180, IsBoss) 	-- Death Bolt
	AddFlags(278961, IsBoss) 	-- Decaying Mind
	AddFlags(259714, IsBoss) 	-- Decaying Spores
	AddFlags(273226, IsDungeon) -- Decaying Spores
	AddFlags(265377, IsBoss) 	-- Hooked Snare
	AddFlags(260793, IsDungeon) -- Indigestion
	AddFlags(272609, IsBoss) 	-- Maddening Gaze
	AddFlags(257437, IsDungeon) -- Poisoning Strike
	AddFlags(269301, IsBoss) 	-- Putrid Blood
	AddFlags(264757, IsDungeon) -- Sanguine Feast
	AddFlags(265019, IsBoss) 	-- Savage Cleave
	AddFlags(260455, IsBoss) 	-- Serrated Fangs
	AddFlags(260685, IsBoss) 	-- Taint of G'huun
	AddFlags(266107, IsBoss) 	-- Thirst for Blood
	AddFlags(259718, IsDungeon) -- Upheaval
	AddFlags(269843, IsDungeon) -- Vile Expulsion
	AddFlags(273285, IsDungeon) -- Volatile Pods
	AddFlags(265468, IsBoss) 	-- Withering Curse

	-- Waycrest Manor
	------------------------------------------------------------------------
	AddFlags(268080, IsDungeon) -- Aura of Apathy
	AddFlags(266035, IsBoss) 	-- Bone Splinter
	AddFlags(260541, IsDungeon) -- Burning Brush
	AddFlags(268202, IsBoss) 	-- Death Lens
	AddFlags(265881, IsBoss) 	-- Decaying Touch
	AddFlags(268306, IsDungeon) -- Discordant Cadenza
	AddFlags(266036, IsBoss) 	-- Drain Essence
	AddFlags(265880, IsBoss) 	-- Dread Mark
	AddFlags(263943, IsBoss) 	-- Etch
	AddFlags(264378, IsBoss) 	-- Fragment Soul
	AddFlags(263891, IsBoss) 	-- Grasping Thorns
	AddFlags(264050, IsBoss) 	-- Infected Thorn
	AddFlags(278444, IsDungeon) -- Infest
	AddFlags(278456, IsBoss) 	-- Infest
	AddFlags(261265, IsDungeon) -- Ironbark Shield
	AddFlags(260741, IsBoss) 	-- Jagged Nettles
	AddFlags(265882, IsBoss) 	-- Lingering Dread
	AddFlags(263905, IsBoss) 	-- Marking Cleave
	AddFlags(271178, IsDungeon) -- Ravaging Leap
	AddFlags(264694, IsDungeon) -- Rotten Expulsion
	AddFlags(264105, IsBoss) 	-- Runic Mark
	AddFlags(261266, IsDungeon) -- Runic Ward
	AddFlags(261264, IsDungeon) -- Soul Armor
	AddFlags(260512, IsDungeon) -- Soul Harvest
	AddFlags(260907, IsBoss) 	-- Soul Manipulation
	AddFlags(260551, IsBoss) 	-- Soul Thorns
	AddFlags(264556, IsBoss) 	-- Tearing Strike
	AddFlags(264923, IsDungeon) -- Tenderize
	AddFlags(265760, IsBoss) 	-- Thorned Barrage
	AddFlags(265761, IsDungeon) -- Thorned Barrage
	AddFlags(260703, IsBoss) 	-- Unstable Runic Mark
	AddFlags(261440, IsBoss) 	-- Virulent Pathogen
	AddFlags(263961, IsDungeon) -- Warding Candles
	AddFlags(261438, IsBoss) 	-- Wasting Strike

	-- Uldir
	------------------------------------------------------------------------
	-- MOTHER
	AddFlags(268095, IsBoss) -- Cleansing Purge
	AddFlags(268198, IsBoss) -- Clinging Corruption
	AddFlags(267821, IsBoss) -- Defense Grid
	AddFlags(268277, IsBoss) -- Purifying Flame
	AddFlags(267787, IsBoss) -- Sundering Scalpel
	AddFlags(268253, IsBoss) -- Surgical Beam

	-- Vectis
	AddFlags(265212, IsBoss) -- Gestate
	AddFlags(265206, IsBoss) -- Immunosuppression
	AddFlags(265127, IsBoss) -- Lingering Infection
	AddFlags(265178, IsBoss) -- Mutagenic Pathogen
	AddFlags(265129, IsBoss) -- Omega Vector
	AddFlags(267160, IsBoss) -- Omega Vector
	AddFlags(267161, IsBoss) -- Omega Vector
	AddFlags(267162, IsBoss) -- Omega Vector
	AddFlags(267163, IsBoss) -- Omega Vector
	AddFlags(267164, IsBoss) -- Omega Vector

	-- Mythrax
	--AddFlags(272146, IsBoss) -- Annihilation
	AddFlags(274693, IsBoss) -- Essence Shear
	AddFlags(272536, IsBoss) -- Imminent Ruin
	AddFlags(272407, IsBoss) -- Oblivion Sphere

	-- Fetid Devourer
	AddFlags(262314, IsBoss) -- Deadly Disease
	AddFlags(262313, IsBoss) -- Malodorous Miasma
	AddFlags(262292, IsBoss) -- Rotting Regurgitation

	-- Taloc
	AddFlags(270290, IsBoss) -- Blood Storm
	AddFlags(275270, IsBoss) -- Fixate
	AddFlags(271224, IsBoss) -- Plasma Discharge
	AddFlags(271225, IsBoss) -- Plasma Discharge

	-- Zul
	AddFlags(272018, IsBoss) -- Absorbed in Darkness
	--AddFlags(274195, IsBoss) -- Corrupted Blood
	AddFlags(273365, IsBoss) -- Dark Revelation
	AddFlags(273434, IsBoss) -- Pit of Despair
	AddFlags(274358, IsBoss) -- Rupturing Blood

	-- Zek'voz, Herald of N'zoth
	AddFlags(265662, IsBoss) -- Corruptor's Pact
	AddFlags(265360, IsBoss) -- Roiling Deceit
	AddFlags(265237, IsBoss) -- Shatter
	AddFlags(265264, IsBoss) -- Void Lash
	AddFlags(265646, IsBoss) -- Will of the Corruptor

	-- G'huun
	AddFlags(270287, IsBoss) -- Blighted Ground
	AddFlags(263235, IsBoss) -- Blood Feast
	AddFlags(267409, IsBoss) -- Dark Bargain
	AddFlags(272506, IsBoss) -- Explosive Corruption
	AddFlags(263436, IsBoss) -- Imperfect Physiology
	AddFlags(263372, IsBoss) -- Power Matrix
	AddFlags(263227, IsBoss) -- Putrid Blood
	AddFlags(267430, IsBoss) -- Torment

	-- Siege of Zuldazar
	------------------------------------------------------------------------
	-- Rawani Kanae / Frida Ironbellows
	AddFlags(283582, IsBoss) 	-- Consecration
	AddFlags(283651, IsBoss) 	-- Blinding Faith
	AddFlags(284595, IsBoss) 	-- Penance
	AddFlags(283573, IsBoss) 	-- Sacred Blade
	AddFlags(283617, IsBoss) 	-- Wave of Light
	
	-- Grong
	AddFlags(285671, IsBoss) 	-- Crushed
	AddFlags(285998, IsBoss) 	-- Ferocious Roar
	AddFlags(283069, IsBoss) 	-- Megatomic Fire
	AddFlags(285875, IsBoss) 	-- Rending Bite
	
	-- Jaina
	AddFlags(285254, IsBoss) 	-- Avalanche
	AddFlags(287993, IsBoss) 	-- Chilling Touch
	AddFlags(287490, IsBoss) 	-- Frozen Solid
	AddFlags(287626, IsBoss) 	-- Grasp of Frost
	AddFlags(285253, IsBoss) 	-- Ice Shard
	AddFlags(288038, IsBoss) 	-- Marked Target
	AddFlags(287199, IsBoss) 	-- Ring of Ice
	AddFlags(287365, IsBoss) 	-- Searing Pitch
	AddFlags(288392, IsBoss) 	-- Vengeful Seas
	
	-- Stormwall Blockade
	AddFlags(286680, IsBoss) 	-- Roiling Tides
	AddFlags(284369, IsBoss) 	-- Sea Storm
	AddFlags(284410, IsBoss) 	-- Tempting Song
	AddFlags(284405, IsBoss) 	-- Tempting Song
	AddFlags(284121, IsBoss) 	-- Thunderous Boom

	-- Opulence
	AddFlags(289383, IsBoss) 	-- Chaotic Displacement
	AddFlags(286501, IsBoss) 	-- Creeping Blaze
	AddFlags(283610, IsBoss) 	-- Crush
	AddFlags(285479, IsBoss) 	-- Flame Jet
	AddFlags(283063, IsBoss) 	-- Flames of Punishment
	AddFlags(283507, IsBoss) 	-- Volatile Charge
	
	-- King Rastakhan
	AddFlags(289858, IsBoss) 	-- Crushed
	AddFlags(285349, IsBoss) 	-- Plague of Fire
	AddFlags(285010, IsBoss) 	-- Poison Toad Slime
	AddFlags(284831, IsBoss) 	-- Scorching Detonation
	AddFlags(284662, IsBoss) 	-- Seal of Purification
	AddFlags(284676, IsBoss) 	-- Seal of Purification
	AddFlags(285178, IsBoss) 	-- Serpent's Breath
	AddFlags(285044, IsBoss) 	-- Toad Toxin
	AddFlags(284995, IsBoss) 	-- Zombie Dust
	
	-- Jadefire Masters
	AddFlags(284374, IsBoss) 	-- Magma Trap
	AddFlags(282037, IsBoss) 	-- Rising Flames
	AddFlags(286988, IsBoss) 	-- Searing Embers
	AddFlags(285632, IsBoss) 	-- Stalking
	AddFlags(284089, IsBoss) 	-- Successful Defense
	AddFlags(288151, IsBoss) 	-- Tested
	
	-- Mekkatorque
	AddFlags(286516, IsBoss) 	-- Anti-Tampering Shock
	AddFlags(286480, IsBoss) 	-- Anti-Tampering Shock
	AddFlags(289023, IsBoss) 	-- Enormous
	AddFlags(288806, IsBoss) 	-- Gigavolt Blast
	AddFlags(286646, IsBoss) 	-- Gigavolt Charge
	AddFlags(288939, IsBoss) 	-- Gigavolt Radiation
	AddFlags(284168, IsBoss) 	-- Shrunk
	AddFlags(284214, IsBoss) 	-- Trample
	
	-- Conclave of the Chosen
	AddFlags(286811, IsBoss) 	-- Akunda's Wrath
	AddFlags(282592, IsBoss) 	-- Bleeding Wounds
	AddFlags(284663, IsBoss) 	-- Bwonsamdi's Wrath
	AddFlags(282135, IsBoss) 	-- Crawling Hex
	AddFlags(286060, IsBoss) 	-- Cry of the Fallen
	AddFlags(282447, IsBoss) 	-- Kimbul's Wrath
	AddFlags(282834, IsBoss) 	-- Kimbul's Wrath
	AddFlags(282444, IsBoss) 	-- Lacerating Claws
	AddFlags(282209, IsBoss) 	-- Mark of Prey
	AddFlags(285879, IsBoss) 	-- Mind Wipe
	AddFlags(286838, IsBoss) 	-- Static Orb

	-- Crucible of Storms
	------------------------------------------------------------------------
	-- The Restless Cabal
	AddFlags(282386, IsBoss) 	-- Aphotic Blast
	AddFlags(282432, IsBoss) 	-- Crushing Doubt
	AddFlags(282561, IsBoss) 	-- Dark Herald
	AddFlags(282589, IsBoss) 	-- Mind Scramble
	AddFlags(292826, IsBoss) 	-- Mind Scramble
	AddFlags(282566, IsBoss) 	-- Promises of Power
	AddFlags(282384, IsBoss) 	-- Shear Mind

	-- Fathuul the Feared
	AddFlags(284733, IsBoss) 	-- Embrace of the Void
	AddFlags(286457, IsBoss) 	-- Feedback: Ocean
	AddFlags(286458, IsBoss) 	-- Feedback: Storm
	AddFlags(286459, IsBoss) 	-- Feedback: Void
	AddFlags(285652, IsBoss) 	-- Insatiable Torment
	AddFlags(285345, IsBoss) 	-- Maddening Eyes of N'Zoth
	AddFlags(285477, IsBoss) 	-- Obscurity
	AddFlags(285367, IsBoss) 	-- Piercing Gaze of N'Zoth
	AddFlags(284851, IsBoss) 	-- Touch of the End
	AddFlags(284722, IsBoss) 	-- Umbral Shell

	-- Eternal Palace
	------------------------------------------------------------------------
	-- Lady Ashvane
	AddFlags(296942, IsBoss) 	-- Arcing Azerite
	AddFlags(296938, IsBoss) 	-- Arcing Azerite
	AddFlags(296941, IsBoss) 	-- Arcing Azerite
	AddFlags(296939, IsBoss) 	-- Arcing Azerite
	AddFlags(296943, IsBoss) 	-- Arcing Azerite
	AddFlags(296940, IsBoss) 	-- Arcing Azerite
	AddFlags(296725, IsBoss) 	-- Barnacle Bash
	AddFlags(297333, IsBoss) 	-- Briny Bubble
	AddFlags(297397, IsBoss) 	-- Briny Bubble
	AddFlags(296752, IsBoss) 	-- Cutting Coral
	AddFlags(296693, IsBoss) 	-- Waterlogged

	-- Abyssal Commander Sivara
	AddFlags(295850, IsBoss) 	-- Delirious
	AddFlags(295704, IsBoss) 	-- Frost Bolt
	AddFlags(294711, IsBoss) 	-- Frost Mark
	AddFlags(295807, IsBoss) 	-- Frozen
	AddFlags(300883, IsBoss) 	-- Inversion Sickness
	AddFlags(295348, IsBoss) 	-- Overflowing Chill
	AddFlags(295421, IsBoss) 	-- Overflowing Venom
	AddFlags(300701, IsBoss) 	-- Rimefrost
	AddFlags(300705, IsBoss) 	-- Septic Taint
	AddFlags(295705, IsBoss) 	-- Toxic Bolt
	AddFlags(294715, IsBoss) 	-- Toxic Brand
	AddFlags(294847, IsBoss) 	-- Unstable Mixture

	-- The Queens Court
	AddFlags(296851, IsBoss) 	-- Fanatical Verdict
	AddFlags(299914, IsBoss) 	-- Frenetic Charge
	AddFlags(300545, IsBoss) 	-- Mighty Rupture
	AddFlags(301830, IsBoss) 	-- Pashmar's Touch
	AddFlags(297836, IsBoss) 	-- Potent Spark
	AddFlags(304410, IsBoss) 	-- Repeat Performance
	AddFlags(303306, IsBoss) 	-- Sphere of Influence
	AddFlags(297586, IsBoss) 	-- Suffering

	-- Radiance of Azshara
	AddFlags(295920, IsBoss) 	-- Ancient Tempest
	AddFlags(296737, IsBoss) 	-- Arcane Bomb
	AddFlags(296746, IsBoss) 	-- Arcane Bomb
	AddFlags(296462, IsBoss) 	-- Squall Trap
	AddFlags(296566, IsBoss) 	-- Tide Fist

	-- Orgozoa
	AddFlags(298156, IsBoss) 	-- Desensitizing Sting
	AddFlags(298306, IsBoss) 	-- Incubation Fluid

	-- Blackwater Behemoth
	AddFlags(292127, IsBoss) 	-- Darkest Depths
	AddFlags(301494, IsBoss) 	-- Piercing Barb
	AddFlags(292138, IsBoss) 	-- Radiant Biomass
	AddFlags(292167, IsBoss) 	-- Toxic Spine

	-- Zaqul
	AddFlags(298192, IsBoss) 	-- Dark Beyond
	AddFlags(295249, IsBoss) 	-- Delirium Realm
	AddFlags(292963, IsBoss) 	-- Dread
	AddFlags(293509, IsBoss) 	-- Manifest Nightmares
	AddFlags(295495, IsBoss) 	-- Mind Tether
	AddFlags(295480, IsBoss) 	-- Mind Tether
	AddFlags(303819, IsBoss) 	-- Nightmare Pool
	AddFlags(294545, IsBoss) 	-- Portal of Madness
	AddFlags(295327, IsBoss) 	-- Shattered Psyche
	AddFlags(300133, IsBoss) 	-- Snapped

	-- Queen Azshara
	AddFlags(303657, IsBoss) 	-- Arcane Burst
	AddFlags(298781, IsBoss) 	-- Arcane Orb
	AddFlags(302999, IsBoss) 	-- Arcane Vulnerability
	AddFlags(302141, IsBoss) 	-- Beckon
	AddFlags(301078, IsBoss) 	-- Charged Spear
	AddFlags(298014, IsBoss) 	-- Cold Blast
	AddFlags(297907, IsBoss) 	-- Cursed Heart
	AddFlags(298018, IsBoss) 	-- Frozen
	AddFlags(299276, IsBoss) 	-- Sanction
	AddFlags(298756, IsBoss) 	-- Serrated Edge

	-- Nyalotha
	------------------------------------------------------------------------
	-- Wrathion
	AddFlags(313255, IsBoss) 	-- Creeping Madness (Slow Effect)
	AddFlags(306163, IsBoss) 	-- Incineration
	AddFlags(306015, IsBoss) 	-- Searing Armor [tank]
	
	-- Maut
	AddFlags(314337, IsBoss) 	-- Ancient Curse
	AddFlags(314992, IsBoss) 	-- Darin Essence
	AddFlags(307805, IsBoss) 	-- Devour Magic
	AddFlags(306301, IsBoss) 	-- Forbidden Mana
	AddFlags(307399, IsBoss) 	-- Shadow Claws [tank]

	-- Prophet Skitra
	AddFlags(306387, IsBoss) 	-- Shadow Shock
	AddFlags(313276, IsBoss) 	-- Shred Psyche

	-- Dark Inquisitor
	AddFlags(311551, IsBoss) 	-- Abyssal Strike [tank]
	AddFlags(306311, IsBoss) 	-- Soul Flay
	AddFlags(312406, IsBoss) 	-- Void Woken

	-- Hivemind
	AddFlags(313672, IsBoss) 	-- Acid Pool
	AddFlags(313461, IsBoss) 	-- Corrosion
	AddFlags(313460, IsBoss) 	-- Nullification

	-- Shadhar
	AddFlags(306929, IsBoss) 	-- Bubbling Breath
	AddFlags(307471, IsBoss) 	-- Crush [tank]
	AddFlags(307358, IsBoss) 	-- Debilitating Spit
	AddFlags(307472, IsBoss) 	-- Dissolve [tank]
	AddFlags(312530, IsBoss) 	-- Entropic Breath
	AddFlags(306928, IsBoss) 	-- Umbral Breath

	-- Drest
	AddFlags(310552, IsBoss) 	-- Mind Flay
	AddFlags(310358, IsBoss) 	-- Mutterings of Insanity
	AddFlags(310406, IsBoss) 	-- Void Glare
	AddFlags(310478, IsBoss) 	-- Void Miasma
	AddFlags(310277, IsBoss) 	-- Volatile Seed [tank]
	AddFlags(310309, IsBoss) 	-- Volatile Vulnerability

	-- Ilgy
	AddFlags(314396, IsBoss) 	-- Cursed Blood
	AddFlags(309961, IsBoss) 	-- Eye of Nzoth [tank]
	AddFlags(275269, IsBoss) 	-- Fixate
	AddFlags(310322, IsBoss) 	-- Morass of Corruption
	AddFlags(312486, IsBoss) 	-- Recurring Nightmare
	AddFlags(311401, IsBoss) 	-- Touch of the Corruptor

	-- Vexiona
	AddFlags(307421, IsBoss) 	-- Annihilation
	AddFlags(315932, IsBoss) 	-- Brutal Smash
	AddFlags(307359, IsBoss) 	-- Despair
	AddFlags(307317, IsBoss) 	-- Encroaching Shadows
	AddFlags(307284, IsBoss) 	-- Terrifying Presence
	AddFlags(307218, IsBoss) 	-- Twilight Decimator
	AddFlags(307019, IsBoss) 	-- Void Corruption [tank]

	-- Raden
	AddFlags(310019, IsBoss) 	-- Charged Bonds
	AddFlags(316065, IsBoss) 	-- Corrupted Existence
	AddFlags(313227, IsBoss) 	-- Decaying Wound
	AddFlags(315258, IsBoss) 	-- Dread Inferno
	AddFlags(306279, IsBoss) 	-- Insanity Exposure
	AddFlags(306819, IsBoss) 	-- Nullifying Strike [tank]
	AddFlags(306257, IsBoss) 	-- Unstable Vita

	-- Carapace
	AddFlags(316848, IsBoss) 	-- Adaptive Membrane
	AddFlags(315954, IsBoss) 	-- Black Scar [tank]
	AddFlags(306973, IsBoss) 	-- Madness
	AddFlags(313364, IsBoss) 	-- Mental Decay
	AddFlags(307044, IsBoss) 	-- Nightmare Antibody
	AddFlags(317627, IsBoss) 	-- Infinite Void

	-- Nzoth
	AddFlags(313400, IsBoss) 	-- Corrupted Mind
	AddFlags(317112, IsBoss) 	-- Evoke Anguish
	AddFlags(318442, IsBoss) 	-- Paranoia
	AddFlags(313793, IsBoss) 	-- Flames of Insanity
	AddFlags(316771, IsBoss) 	-- Mindwrack
	AddFlags(314889, IsBoss) 	-- Probe Mind
	AddFlags(318976, IsBoss) 	-- Stupefying Glare


	-- Castle Nathria
	------------------------------------------------------------------------
	-- Hecutis
	AddFlags(334860, IsBoss) 	-- Crushing Stone

end

if (IsClassic) then
	PopulateClassicClassDatabase()
	PopulateClassicNPCDatabase()
elseif (IsRetail) then
	PopulateRetailClassDatabase()
	PopulateRetailNPCDatabase()
end
