--[[--

The purpose of this file is to supply all the front-end modules 
with color, fonts and aura tables local to the addon only. 

--]]--

local ADDON, Private = ...

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, ADDON.." requires LibClientBuild to be loaded.")

local LibAuraData = Wheel("LibAuraData")
assert(LibAuraData, ADDON.." requires LibAuraData to be loaded.")

local LibPlayerData = Wheel("LibPlayerData")
assert(LibPlayerData, ADDON.." requires LibPlayerData to be loaded.")

local LibColorTool = Wheel("LibColorTool")
assert(LibColorTool, ADDON.." requires LibColorTool to be loaded.")

local LibFontTool = Wheel("LibFontTool")
assert(LibFontTool, ADDON.." requires LibFontTool to be loaded.")

-- Lua API
local _G = _G
local bit_band = bit.band
local math_floor = math.floor
local pairs = pairs
local rawget = rawget
local select = select
local setmetatable = setmetatable
local string_gsub = string.gsub
local string_match = string.match
local tonumber = tonumber
local unpack = unpack

-- WoW API
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitClassification = UnitClassification
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitIsFriend = UnitIsFriend
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel
local UnitPlayerControlled = UnitPlayerControlled

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()
local IsRetailShadowlands = LibClientBuild:IsRetailShadowlands()

-- Addon API
local HasInfoFlags = function(...) return LibAuraData:HasAuraInfoFlags(...) end
local AddUserFlags = function(...) LibAuraData.AddAuraUserFlags(Private, ...) end
local HasUserFlags = function(...) return LibAuraData.HasAuraUserFlags(Private, ...) end

-- Library Databases
local BitFilter = LibAuraData:GetAllAuraInfoBitFilters() -- Aura flags by keywords
local InfoFlags = LibAuraData:GetAllAuraInfoFlags() -- Aura info flags

-- Local Databases
local auraUserFlags = {} -- Aura filter flags 

-- Color Tables
-----------------------------------------------------------------
local Colors = LibColorTool:GetColorTable()
do 
	-- Our player health bar color
	Colors.health = Colors:CreateColor(245/255, 0/255, 45/255)

	-- Global UI vertex coloring
	Colors.ui = Colors:CreateColor(192/255, 192/255, 192/255)

	-- Power Colors
	local Fast = Colors:CreateColor(0/255, 208/255, 176/255) 
	local Slow = Colors:CreateColor(116/255, 156/255, 255/255)
	local Angry = Colors:CreateColor(156/255, 116/255, 255/255)

	Colors.power.ENERGY_CRYSTAL = Fast -- Rogues, Druids
	Colors.power.FOCUS_CRYSTAL = Slow -- Hunters Pets (?)
	Colors.power.FURY_CRYSTAL = Angry -- Havoc Demon Hunter 
	Colors.power.INSANITY_CRYSTAL = Angry -- Shadow Priests
	Colors.power.LUNAR_POWER_CRYSTAL = Slow -- Balance Druid Astral Power 
	Colors.power.MAELSTROM_CRYSTAL = Slow -- Elemental Shamans
	Colors.power.PAIN_CRYSTAL = Angry -- Vengeance Demon Hunter 
	Colors.power.RAGE_CRYSTAL = Angry -- Druids, Warriors
	Colors.power.RUNIC_POWER_CRYSTAL = Slow -- Death Knights

	-- Only occurs when the orb is manually disabled by the player.
	Colors.power.MANA_CRYSTAL = Colors:CreateColor(101/255, 93/255, 191/255) -- Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock

	-- Orb Power Colors
	Colors.power.MANA_ORB = Colors:CreateColor(135/255, 125/255, 255/255) -- Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock

	-- Standard Power Colors
	Colors.power.ENERGY = Colors:CreateColor(254/255, 245/255, 145/255) -- Rogues, Druids
	Colors.power.FURY = Colors:CreateColor(255/255, 0/255, 111/255) -- Vengeance Demon Hunter
	Colors.power.FOCUS = Colors:CreateColor(125/255, 168/255, 195/255) -- Hunter Pets
	Colors.power.INSANITY = Colors:CreateColor(102/255, 64/255, 204/255) -- Shadow Priests 
	Colors.power.LUNAR_POWER = Colors:CreateColor(121/255, 152/255, 192/255) -- Balance Druid Astral Power 
	Colors.power.MAELSTROM = Colors:CreateColor(0/255, 188/255, 255/255) -- Elemental Shamans
	Colors.power.MANA = Colors:CreateColor(80/255, 116/255, 255/255) -- Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock
	Colors.power.PAIN = Colors:CreateColor(190 *.75/255, 255 *.75/255, 0/255) 
	Colors.power.RAGE = Colors:CreateColor(215/255, 7/255, 7/255) -- Druids, Warriors
	Colors.power.RUNIC_POWER = Colors:CreateColor(0/255, 236/255, 255/255) -- Death Knights
end 

-- Aura Filter Bitflags
-----------------------------------------------------------------
-- These are front-end filters and describe display preference,
-- they are unrelated to the factual, purely descriptive back-end filters.
local ByPlayer 			= 2^0 -- Show when cast by player

-- Unit visibility
local OnPlayer 			= 2^1  -- Show on player frame
local OnTarget 			= 2^2  -- Show on target frame 
local OnPet 			= 2^3  -- Show on pet frame
local OnToT 			= 2^4  -- Shown on tot frame
local OnFocus 			= 2^5  -- Shown on focus frame
local OnParty 			= 2^6  -- Show on party members
local OnRaid 			= 2^7  -- Show on raid members
local OnBoss 			= 2^8  -- Show on boss frames
local OnEnemy 			= 2^9  -- Show on enemy units
local OnFriend 			= 2^10 -- Show on friendly units

-- Blacklisted and whitelisted
local NeverOnPlate 		= 2^14 -- Never show on plates (Blacklist)
local Never 			= 2^15 -- Never show (Blacklist)
local Always 			= 2^16 -- Always show (Whitelist)

-- Extra conditionals
local NoCombat 			= 2^17 -- Never show in combat 
local Warn 				= 2^18 -- Show when there is 30 secs left or less

-- Player role conditionals
-- *NOT CURRENTLY IMPLEMENTED!
local PlayerIsDPS 		= 2^11 -- Show when player is a damager
local PlayerIsHealer 	= 2^12 -- Show when player is a healer
local PlayerIsTank 		= 2^13 -- Show when player is a tank 

-- Priority conditionals
-- *NOT CURRENTLY IMPLEMENTED!
local PrioLow 			= 2^19 -- Low priority, will only be displayed if room
local PrioMedium 		= 2^20 -- Normal priority, same as not setting any
local PrioHigh 			= 2^21 -- High priority, shown first after boss
local PrioBoss 			= 2^22 -- Same priority as boss debuffs

-- Some constants to avoid a million auraIDs
local L_DRINK = GetSpellInfo(430)
local L_FOOD = GetSpellInfo(433)

-- Forcing this for classes still lacking strict filter lists,
-- or we'd end up with nothing being shown at all.
local playerClass = select(2, UnitClass("player"))
local SLACKMODE = (playerClass == "DEATHKNIGHT")
			   or (playerClass == "DEMONHUNTER")
			   --or (playerClass == "DRUID")
			   or (IsClassic and (playerClass == "HUNTER"))
			   --or (playerClass == "MAGE")
			   or (playerClass == "MONK")
			   or (playerClass == "PALADIN")
			   or (playerClass == "PRIEST")
			   or (playerClass == "ROGUE")
			   or (playerClass == "SHAMAN")
			   or (playerClass == "WARLOCK")
			   --or (playerClass == "WARRIOR")

-- Shorthand tags for quality of life, following the guidelines above.
-- Note: Do NOT add any of these together, they must be used as the ONLY tag when used!
local GroupBuff = 		OnPlayer + NoCombat + Warn 			-- Group buffs like MotW, Fortitude
local PlayerBuff = 		ByPlayer + NoCombat + Warn 			-- Self-cast only buffs, like Omen of Clarity
local Harmful = 		OnPlayer + OnEnemy 					-- CC and other non-damaging harmful effects
local Damage = 			ByPlayer + OnPlayer 				-- DoTs
local Healing = 		ByPlayer + OnEnemy 					-- HoTs
local Shielding = 		OnPlayer + OnEnemy 					-- Shields
local Boost = 			ByPlayer + OnEnemy 					-- Damage- and defensive cooldowns

-- Aura Filter Lists
-----------------------------------------------------------------
-- WoW Classic
if (IsClassic) then

	-- Blacklists
	-----------------------------------------------------------------
	do
		-- General Blacklist
		-- Auras listed here won't be shown on any unitframes.
		------------------------------------------------------------------------
		AddUserFlags(17670, Never) 							-- Argent Dawn Commission

		-- General NoCombat Blacklist
		-- Auras listed here won't be shown while in combat.
		------------------------------------------------------------------------
		AddUserFlags(26013, NoCombat) 						-- Deserter

		-- Nameplate Blacklist
		------------------------------------------------------------------------
		-- Auras listed here will be excluded from the nameplates.
		-- Many similar to these will be excluded by default filters too,
		-- but we still with to eventually include all relevant ones.
		------------------------------------------------------------------------
		AddUserFlags(26013, NeverOnPlate) 					-- Deserter

		-- Proximity Auras
		AddUserFlags(13159, NeverOnPlate) 					-- Aspect of the Pack
		AddUserFlags( 7805, NeverOnPlate) 					-- Blood Pact
		AddUserFlags(11767, NeverOnPlate) 					-- Blood Pact
		AddUserFlags(19746, NeverOnPlate) 					-- Concentration Aura
		AddUserFlags(10293, NeverOnPlate) 					-- Devotion Aura
		AddUserFlags(19898, NeverOnPlate) 					-- Frost Resistance Aura
		AddUserFlags(24932, NeverOnPlate) 					-- Leader of the Pack
		AddUserFlags(24907, NeverOnPlate) 					-- Moonkin Aura
		AddUserFlags(19480, NeverOnPlate) 					-- Paranoia
		AddUserFlags(10301, NeverOnPlate) 					-- Retribution Aura
		AddUserFlags(20218, NeverOnPlate) 					-- Sanctity Aura
		AddUserFlags(19896, NeverOnPlate) 					-- Shadow Resistance Aura
		AddUserFlags(20906, NeverOnPlate) 					-- Trueshot Aura

		-- Timed Buffs
		-- TODO: Add all the missing ranks.
		AddUserFlags(23028, NeverOnPlate) 					-- Arcane Brilliance (Rank ?)
		AddUserFlags( 1461, NeverOnPlate) 					-- Arcane Intellect (Rank ?)
		AddUserFlags(10157, NeverOnPlate) 					-- Arcane Intellect (Rank ?)
		AddUserFlags( 6673, NeverOnPlate) 					-- Battle Shout (Rank 1)
		AddUserFlags(11551, NeverOnPlate) 					-- Battle Shout (Rank ?)
		AddUserFlags(20217, NeverOnPlate) 					-- Blessing of Kings (Rank ?)
		AddUserFlags(19838, NeverOnPlate) 					-- Blessing of Might (Rank ?)
		AddUserFlags(11743, NeverOnPlate) 					-- Detect Greater Invisibility
		AddUserFlags(27841, NeverOnPlate) 					-- Divine Spirit (Rank ?)
		AddUserFlags(25898, NeverOnPlate) 					-- Greater Blessing of Kings (Rank ?)
		AddUserFlags(25899, NeverOnPlate) 					-- Greater Blessing of Sanctuary (Rank ?)
		AddUserFlags(21849, NeverOnPlate) 					-- Gift of the Wild (Rank 2)
		AddUserFlags(21850, NeverOnPlate) 					-- Gift of the Wild (Rank 2)
		AddUserFlags(10220, NeverOnPlate) 					-- Ice Armor (Rank ?)
		AddUserFlags( 1126, NeverOnPlate) 					-- Mark of the Wild (Rank 1)
		AddUserFlags( 5232, NeverOnPlate) 					-- Mark of the Wild (Rank 2)
		AddUserFlags( 6756, NeverOnPlate) 					-- Mark of the Wild (Rank 3)
		AddUserFlags( 5234, NeverOnPlate) 					-- Mark of the Wild (Rank 4)
		AddUserFlags( 8907, NeverOnPlate) 					-- Mark of the Wild (Rank 5)
		AddUserFlags( 9884, NeverOnPlate) 					-- Mark of the Wild (Rank 6)
		AddUserFlags( 9885, NeverOnPlate) 					-- Mark of the Wild (Rank 7)
		AddUserFlags(10938, NeverOnPlate) 					-- Power Word: Fortitude (Rank ?)
		AddUserFlags(21564, NeverOnPlate) 					-- Prayer of Fortitude (Rank ?)
		AddUserFlags(27681, NeverOnPlate) 					-- Prayer of Spirit (Rank ?)
		AddUserFlags(10958, NeverOnPlate) 					-- Shadow Protection
		AddUserFlags(  467, NeverOnPlate) 					-- Thorns (Rank 1)
		AddUserFlags(  782, NeverOnPlate) 					-- Thorns (Rank 2)
		AddUserFlags( 1075, NeverOnPlate) 					-- Thorns (Rank 3)
		AddUserFlags( 8914, NeverOnPlate) 					-- Thorns (Rank 4)
		AddUserFlags( 9756, NeverOnPlate) 					-- Thorns (Rank 5)
		AddUserFlags( 9910, NeverOnPlate) 					-- Thorns (Rank 6)
	end

	-- Druid
	-----------------------------------------------------------------
	do
		-- Druid (Balance)
		-- https://classic.wowhead.com/druid-abilities/balance
		-- https://classic.wowhead.com/balance-druid-talents
		------------------------------------------------------------------------
		AddUserFlags(22812, ByPlayer) 						-- Barkskin
		AddUserFlags(  339, Harmful) 						-- Entangling Roots (Rank 1)
		AddUserFlags( 1062, Harmful) 						-- Entangling Roots (Rank 2)
		AddUserFlags( 5195, Harmful) 						-- Entangling Roots (Rank 3)
		AddUserFlags( 5196, Harmful) 						-- Entangling Roots (Rank 4)
		AddUserFlags( 9852, Harmful) 						-- Entangling Roots (Rank 5)
		AddUserFlags( 9853, Harmful) 						-- Entangling Roots (Rank 6)
		AddUserFlags(  770, Harmful) 						-- Faerie Fire (Rank 1)
		AddUserFlags(  778, Harmful) 						-- Faerie Fire (Rank 2)
		AddUserFlags( 9749, Harmful) 						-- Faerie Fire (Rank 3)
		AddUserFlags( 9907, Harmful) 						-- Faerie Fire (Rank 4)
		AddUserFlags( 2637, Harmful) 						-- Hibernate (Rank 1)
		AddUserFlags(18657, Harmful) 						-- Hibernate (Rank 2)
		AddUserFlags(18658, Harmful) 						-- Hibernate (Rank 3)
		AddUserFlags( 8921, Damage) 						-- Moonfire (Rank 1)
		AddUserFlags( 8924, Damage) 						-- Moonfire (Rank 2)
		AddUserFlags( 8925, Damage) 						-- Moonfire (Rank 3)
		AddUserFlags( 8926, Damage) 						-- Moonfire (Rank 4)
		AddUserFlags( 8927, Damage) 						-- Moonfire (Rank 5)
		AddUserFlags( 8928, Damage) 						-- Moonfire (Rank 6)
		AddUserFlags( 8929, Damage) 						-- Moonfire (Rank 7)
		AddUserFlags( 9833, Damage) 						-- Moonfire (Rank 8)
		AddUserFlags( 9834, Damage) 						-- Moonfire (Rank 9)
		AddUserFlags( 9835, Damage) 						-- Moonfire (Rank 10)
		AddUserFlags(24907, Never) 							-- Moonkin Aura
		AddUserFlags(24858, Never) 							-- Moonkin Form (Shapeshift)(Talent)
		AddUserFlags(16689, Harmful) 						-- Nature's Grasp (Rank 1)(Talent)
		AddUserFlags(16810, Harmful) 						-- Nature's Grasp (Rank 2)
		AddUserFlags(16811, Harmful) 						-- Nature's Grasp (Rank 3)
		AddUserFlags(16812, Harmful) 						-- Nature's Grasp (Rank 4)
		AddUserFlags(16813, Harmful) 						-- Nature's Grasp (Rank 5)
		AddUserFlags(17329, Harmful) 						-- Nature's Grasp (Rank 6)
		AddUserFlags(16864, PlayerBuff) 					-- Omen of Clarity (Buff)(Talent)
		AddUserFlags(16870, PlayerBuff) 					-- Omen of Clarity (Proc)(Talent)
		AddUserFlags( 2908, ByPlayer) 						-- Soothe Animal (Rank 1)
		AddUserFlags( 8955, ByPlayer) 						-- Soothe Animal (Rank 2)
		AddUserFlags( 9901, ByPlayer) 						-- Soothe Animal (Rank 3)
		AddUserFlags(  467, GroupBuff) 						-- Thorns (Rank 1)
		AddUserFlags(  782, GroupBuff) 						-- Thorns (Rank 2)
		AddUserFlags( 1075, GroupBuff) 						-- Thorns (Rank 3)
		AddUserFlags( 8914, GroupBuff) 						-- Thorns (Rank 4)
		AddUserFlags( 9756, GroupBuff) 						-- Thorns (Rank 5)
		AddUserFlags( 9910, GroupBuff) 						-- Thorns (Rank 6)

		-- Druid (Feral)
		-- https://classic.wowhead.com/druid-abilities/feral-combat
		-- https://classic.wowhead.com/feral-combat-druid-talents
		------------------------------------------------------------------------
		AddUserFlags( 1066, Never) 							-- Aquatic Form (Shapeshift)
		AddUserFlags( 5211, Harmful) 						-- Bash (Rank 1)
		AddUserFlags( 6798, Harmful) 						-- Bash (Rank 2)
		AddUserFlags( 8983, Harmful) 						-- Bash (Rank 3)
		AddUserFlags(  768, Never) 							-- Cat Form (Shapeshift)
		AddUserFlags( 5209, OnEnemy) 						-- Challenging Roar (Taunt)
		AddUserFlags(   99, ByPlayer) 						-- Demoralizing Roar (Rank 1)
		AddUserFlags( 1735, ByPlayer) 						-- Demoralizing Roar (Rank 2)
		AddUserFlags( 9490, ByPlayer) 						-- Demoralizing Roar (Rank 3)
		AddUserFlags( 9747, ByPlayer) 						-- Demoralizing Roar (Rank 4)
		AddUserFlags( 9898, ByPlayer) 						-- Demoralizing Roar (Rank 5)
		AddUserFlags( 1850, Harmful) 						-- Dash (Rank 1)
		AddUserFlags( 9821, Harmful) 						-- Dash (Rank 2)
		AddUserFlags( 9634, Never) 							-- Dire Bear Form (Shapeshift)
		AddUserFlags( 5229, ByPlayer) 						-- Enrage
		AddUserFlags(16857, Damage) 						-- Faerie Fire (Feral) (Rank 1)(Talent)
		AddUserFlags(17390, Damage) 						-- Faerie Fire (Feral) (Rank 2)
		AddUserFlags(17391, Damage) 						-- Faerie Fire (Feral) (Rank 3)
		AddUserFlags(17392, Damage) 						-- Faerie Fire (Feral) (Rank 4)
		AddUserFlags(16979, Harmful) 						-- Feral Charge Effect (Talent)
		AddUserFlags(22842, ByPlayer) 						-- Frenzied Regeneration (Rank 1)
		AddUserFlags(22895, ByPlayer) 						-- Frenzied Regeneration (Rank 2)
		AddUserFlags(22896, ByPlayer) 						-- Frenzied Regeneration (Rank 3)
		AddUserFlags( 6795, OnEnemy) 						-- Growl (Taunt)
		AddUserFlags(24932, Never) 							-- Leader of the Pack(Talent)
		AddUserFlags( 9007, Damage) 						-- Pounce Bleed (Rank 1)
		AddUserFlags( 9824, Damage) 						-- Pounce Bleed (Rank 2)
		AddUserFlags( 9826, Damage) 						-- Pounce Bleed (Rank 3)
		AddUserFlags( 5215, Never) 							-- Prowl (Rank 1)
		AddUserFlags( 6783, Never) 							-- Prowl (Rank 2)
		AddUserFlags( 9913, Never) 							-- Prowl (Rank 3)
		AddUserFlags( 1822, Damage) 						-- Rake (Rank 1)
		AddUserFlags( 1823, Damage) 						-- Rake (Rank 2)
		AddUserFlags( 1824, Damage) 						-- Rake (Rank 3)
		AddUserFlags( 9904, Damage) 						-- Rake (Rank 4)
		AddUserFlags( 1079, Damage) 						-- Rip (Rank 1)
		AddUserFlags( 9492, Damage) 						-- Rip (Rank 2)
		AddUserFlags( 9493, Damage) 						-- Rip (Rank 3)
		AddUserFlags( 9752, Damage) 						-- Rip (Rank 4)
		AddUserFlags( 9894, Damage) 						-- Rip (Rank 5)
		AddUserFlags( 9896, Damage) 						-- Rip (Rank 6)
		AddUserFlags( 5217, ByPlayer) 						-- Tiger's Fury (Rank 1)
		AddUserFlags( 6793, ByPlayer) 						-- Tiger's Fury (Rank 2)
		AddUserFlags( 9845, ByPlayer) 						-- Tiger's Fury (Rank 3)
		AddUserFlags( 9846, ByPlayer) 						-- Tiger's Fury (Rank 4)
		AddUserFlags(  783, Never) 							-- Travel Form (Shapeshift)

		-- Druid (Restoration)
		-- https://classic.wowhead.com/druid-abilities/restoration
		-- https://classic.wowhead.com/restoration-druid-talents
		------------------------------------------------------------------------
		AddUserFlags( 2893, ByPlayer) 						-- Abolish Poison
		AddUserFlags(21849, GroupBuff) 						-- Gift of the Wild (Rank 1)
		AddUserFlags(21850, GroupBuff) 						-- Gift of the Wild (Rank 2)
		AddUserFlags(29166, Boost) 							-- Innervate
		AddUserFlags( 5570, Damage) 						-- Insect Swarm (Rank 1)(Talent)
		AddUserFlags(24974, Damage) 						-- Insect Swarm (Rank 2)
		AddUserFlags(24975, Damage) 						-- Insect Swarm (Rank 3)
		AddUserFlags(24976, Damage) 						-- Insect Swarm (Rank 4)
		AddUserFlags(24977, Damage) 						-- Insect Swarm (Rank 5)
		AddUserFlags( 1126, GroupBuff) 						-- Mark of the Wild (Rank 1)
		AddUserFlags( 5232, GroupBuff) 						-- Mark of the Wild (Rank 2)
		AddUserFlags( 6756, GroupBuff) 						-- Mark of the Wild (Rank 3)
		AddUserFlags( 5234, GroupBuff) 						-- Mark of the Wild (Rank 4)
		AddUserFlags( 8907, GroupBuff) 						-- Mark of the Wild (Rank 5)
		AddUserFlags( 9884, GroupBuff) 						-- Mark of the Wild (Rank 6)
		AddUserFlags( 9885, GroupBuff) 						-- Mark of the Wild (Rank 7)
		AddUserFlags(17116, Boost) 							-- Nature's Swiftness (Talent)
		AddUserFlags( 8936, Healing) 						-- Regrowth (Rank 1)
		AddUserFlags( 8938, Healing) 						-- Regrowth (Rank 2)
		AddUserFlags( 8939, Healing) 						-- Regrowth (Rank 3)
		AddUserFlags( 8940, Healing) 						-- Regrowth (Rank 4)
		AddUserFlags( 8941, Healing) 						-- Regrowth (Rank 5)
		AddUserFlags( 9750, Healing) 						-- Regrowth (Rank 6)
		AddUserFlags( 9856, Healing) 						-- Regrowth (Rank 7)
		AddUserFlags( 9857, Healing) 						-- Regrowth (Rank 8)
		AddUserFlags( 9858, Healing) 						-- Regrowth (Rank 9)
		AddUserFlags(  774, Healing) 						-- Rejuvenation (Rank 1)
		AddUserFlags( 1058, Healing) 						-- Rejuvenation (Rank 2)
		AddUserFlags( 1430, Healing) 						-- Rejuvenation (Rank 3)
		AddUserFlags( 2090, Healing) 						-- Rejuvenation (Rank 4)
		AddUserFlags( 2091, Healing) 						-- Rejuvenation (Rank 5)
		AddUserFlags( 3627, Healing) 						-- Rejuvenation (Rank 6)
		AddUserFlags( 8910, Healing) 						-- Rejuvenation (Rank 7)
		AddUserFlags( 9839, Healing) 						-- Rejuvenation (Rank 8)
		AddUserFlags( 9840, Healing) 						-- Rejuvenation (Rank 9)
		AddUserFlags( 9841, Healing) 						-- Rejuvenation (Rank 10)
		AddUserFlags(  740, Healing) 						-- Tranquility (Rank 1)
		AddUserFlags( 8918, Healing) 						-- Tranquility (Rank 2)
		AddUserFlags( 9862, Healing) 						-- Tranquility (Rank 3)
		AddUserFlags( 9863, Healing) 						-- Tranquility (Rank 4)
	end

	-- Mage
	-----------------------------------------------------------------
	do
		-- Mage (Arcane)
		-- https://classic.wowhead.com/mage-abilities/arcane
		-- https://classic.wowhead.com/arcane-mage-talents
		------------------------------------------------------------------------
		AddUserFlags( 1008, GroupBuff) 						-- Amplify Magic (Rank 1)
		AddUserFlags( 8455, GroupBuff) 						-- Amplify Magic (Rank 2)
		AddUserFlags(10169, GroupBuff) 						-- Amplify Magic (Rank 3)
		AddUserFlags(10170, GroupBuff) 						-- Amplify Magic (Rank 4)
		AddUserFlags(23028, GroupBuff) 						-- Arcane Brilliance (Rank 1)
		AddUserFlags( 1459, GroupBuff) 						-- Arcane Intellect (Rank 1)
		AddUserFlags( 1460, GroupBuff) 						-- Arcane Intellect (Rank 2)
		AddUserFlags( 1461, GroupBuff) 						-- Arcane Intellect (Rank 3)
		AddUserFlags(10156, GroupBuff) 						-- Arcane Intellect (Rank 4)
		AddUserFlags(10157, GroupBuff) 						-- Arcane Intellect (Rank 5)
		AddUserFlags(12042, Boost) 							-- Arcane Power (Talent)(Boost)
		AddUserFlags( 1953, ByPlayer) 						-- Blink
		AddUserFlags(12536, Boost) 							-- Clearcasting (Proc)(Talent)(Boost)
		AddUserFlags(  604, GroupBuff) 						-- Dampen Magic (Rank 1)
		AddUserFlags( 8450, GroupBuff) 						-- Dampen Magic (Rank 2)
		AddUserFlags( 8451, GroupBuff) 						-- Dampen Magic (Rank 3)
		AddUserFlags(10173, GroupBuff) 						-- Dampen Magic (Rank 4)
		AddUserFlags(10174, GroupBuff) 						-- Dampen Magic (Rank 5)
		AddUserFlags( 2855, GroupBuff) 						-- Detect Magic
		AddUserFlags(12051, Boost) 							-- Evocation
		AddUserFlags( 6117, GroupBuff) 						-- Mage Armor (Rank 1)
		AddUserFlags(22782, GroupBuff) 						-- Mage Armor (Rank 2)
		AddUserFlags(22783, GroupBuff) 						-- Mage Armor (Rank 3)
		AddUserFlags( 1463, GroupBuff) 						-- Mana Shield (Rank 1)
		AddUserFlags( 8494, GroupBuff) 						-- Mana Shield (Rank 2)
		AddUserFlags( 8495, GroupBuff) 						-- Mana Shield (Rank 3)
		AddUserFlags(10191, GroupBuff) 						-- Mana Shield (Rank 4)
		AddUserFlags(10192, GroupBuff) 						-- Mana Shield (Rank 5)
		AddUserFlags(10193, GroupBuff) 						-- Mana Shield (Rank 6)
		AddUserFlags(  118, Harmful) 						-- Polymorph (Rank 1)
		AddUserFlags(12824, Harmful) 						-- Polymorph (Rank 2)
		AddUserFlags(12825, Harmful) 						-- Polymorph (Rank 3)
		AddUserFlags(12826, Harmful) 						-- Polymorph (Rank 4)
		AddUserFlags(28270, Harmful) 						-- Polymorph: Cow
		AddUserFlags(28272, Harmful) 						-- Polymorph: Pig
		AddUserFlags(28271, Harmful) 						-- Polymorph: Turtle
		AddUserFlags(12043, Boost) 							-- Presence of Mind (Talent)(Boost)(Clearcast,Instant)
		AddUserFlags(  130, Harmful) 						-- Slow Fall

		-- Mage (Fire)
		-- https://classic.wowhead.com/mage-abilities/fire
		-- https://classic.wowhead.com/fire-mage-talents
		------------------------------------------------------------------------
		AddUserFlags(11113, Harmful) 						-- Blast Wave (Rank 1)(Talent)
		AddUserFlags(13018, Harmful) 						-- Blast Wave (Rank 2)(Talent)
		AddUserFlags(13019, Harmful) 						-- Blast Wave (Rank 3)(Talent)
		AddUserFlags(13020, Harmful) 						-- Blast Wave (Rank 4)(Talent)
		AddUserFlags(13021, Harmful) 						-- Blast Wave (Rank 5)(Talent)
		AddUserFlags(28682, Boost) 							-- Combustion (Talent)(Boost)
		AddUserFlags(  133, Damage) 						-- Fireball (Rank 1)
		AddUserFlags(  143, Damage) 						-- Fireball (Rank 2)
		AddUserFlags(  145, Damage) 						-- Fireball (Rank 3)
		AddUserFlags( 3140, Damage) 						-- Fireball (Rank 4)
		AddUserFlags( 8400, Damage) 						-- Fireball (Rank 5)
		AddUserFlags( 8401, Damage) 						-- Fireball (Rank 6)
		AddUserFlags( 8402, Damage) 						-- Fireball (Rank 7)
		AddUserFlags(10148, Damage) 						-- Fireball (Rank 8)
		AddUserFlags(10149, Damage) 						-- Fireball (Rank 9)
		AddUserFlags(10150, Damage) 						-- Fireball (Rank 10)
		AddUserFlags(10151, Damage) 						-- Fireball (Rank 11)
		AddUserFlags(25306, Damage) 						-- Fireball (Rank 12)
		AddUserFlags(  543, Damage) 						-- Fire Ward (Rank 1)
		AddUserFlags( 8457, Damage) 						-- Fire Ward (Rank 2)
		AddUserFlags( 8458, Damage) 						-- Fire Ward (Rank 3)
		AddUserFlags(10223, Damage) 						-- Fire Ward (Rank 4)
		AddUserFlags(10225, Damage) 						-- Fire Ward (Rank 5)
		AddUserFlags( 2120, Damage) 						-- Flamestrike (Rank 1)
		AddUserFlags( 2121, Damage) 						-- Flamestrike (Rank 2)
		AddUserFlags( 8422, Damage) 						-- Flamestrike (Rank 3)
		AddUserFlags( 8423, Damage) 						-- Flamestrike (Rank 4)
		AddUserFlags(10215, Damage) 						-- Flamestrike (Rank 5)
		AddUserFlags(10216, Damage) 						-- Flamestrike (Rank 6)
		AddUserFlags(12654, Damage) 						-- Ignite Burn CHECK!
		AddUserFlags(12355, Harmful) 						-- Impact (Proc)(Talent)
		AddUserFlags(11366, Damage) 						-- Pyroblast (Rank 1)(Talent)
		AddUserFlags(12505, Damage) 						-- Pyroblast (Rank 2)(Talent)
		AddUserFlags(12522, Damage) 						-- Pyroblast (Rank 3)(Talent)
		AddUserFlags(12523, Damage) 						-- Pyroblast (Rank 4)(Talent)
		AddUserFlags(12524, Damage) 						-- Pyroblast (Rank 5)(Talent)
		AddUserFlags(12525, Damage) 						-- Pyroblast (Rank 6)(Talent)
		AddUserFlags(12526, Damage) 						-- Pyroblast (Rank 7)(Talent)
		AddUserFlags(18809, Damage) 						-- Pyroblast (Rank 8)(Talent)

		-- Mage (Frost)
		-- https://classic.wowhead.com/mage-abilities/frost
		-- https://classic.wowhead.com/frost-mage-talents
		------------------------------------------------------------------------
		AddUserFlags(   10, Damage) 						-- Blizzard (Rank 1)
		AddUserFlags( 6141, Damage) 						-- Blizzard (Rank 2)
		AddUserFlags( 8427, Damage) 						-- Blizzard (Rank 3)
		AddUserFlags(10185, Damage) 						-- Blizzard (Rank 4)
		AddUserFlags(10186, Damage) 						-- Blizzard (Rank 5)
		AddUserFlags(10187, Damage) 						-- Blizzard (Rank 6)
		AddUserFlags( 6136, Harmful) 						-- Chilled (Proc)
		AddUserFlags( 7321, Harmful) 						-- Chilled (Ice Armor Proc)
		AddUserFlags(12484, Harmful) 						-- Chilled (Proc)
		AddUserFlags(12485, Harmful) 						-- Chilled (Proc)
		AddUserFlags(12486, Harmful) 						-- Chilled (Proc)
		AddUserFlags(12531, Harmful) 						-- Chilling Touch (Proc)
		AddUserFlags(  120, Harmful) 						-- Cone of Cold (Rank 1)
		AddUserFlags( 8492, Harmful) 						-- Cone of Cold (Rank 2)
		AddUserFlags(10159, Harmful) 						-- Cone of Cold (Rank 3)
		AddUserFlags(10160, Harmful) 						-- Cone of Cold (Rank 4)
		AddUserFlags(10161, Harmful) 						-- Cone of Cold (Rank 5)
		AddUserFlags(  116, Harmful) 						-- Frostbolt (Rank 1)
		AddUserFlags(  205, Harmful) 						-- Frostbolt (Rank 2)
		AddUserFlags(  837, Harmful) 						-- Frostbolt (Rank 3)
		AddUserFlags( 7322, Harmful) 						-- Frostbolt (Rank 4)
		AddUserFlags( 8406, Harmful) 						-- Frostbolt (Rank 5)
		AddUserFlags( 8407, Harmful) 						-- Frostbolt (Rank 6)
		AddUserFlags( 8408, Harmful) 						-- Frostbolt (Rank 7)
		AddUserFlags(10179, Harmful) 						-- Frostbolt (Rank 8)
		AddUserFlags(10180, Harmful) 						-- Frostbolt (Rank 9)
		AddUserFlags(10181, Harmful) 						-- Frostbolt (Rank 10)
		AddUserFlags(25304, Harmful) 						-- Frostbolt (Rank 11)
		AddUserFlags(  122, Harmful) 						-- Frost Nova (Rank 1)
		AddUserFlags(  865, Harmful) 						-- Frost Nova (Rank 2)
		AddUserFlags( 6131, Harmful) 						-- Frost Nova (Rank 3)
		AddUserFlags(10230, Harmful) 						-- Frost Nova (Rank 4)
		AddUserFlags(  168, PlayerBuff) 					-- Frost Armor (Rank 1)
		AddUserFlags( 7300, PlayerBuff) 					-- Frost Armor (Rank 2)
		AddUserFlags( 7301, PlayerBuff) 					-- Frost Armor (Rank 3)
		AddUserFlags( 6143, Boost) 							-- Frost Ward (Rank 1)(Defensive)
		AddUserFlags( 8461, Boost) 							-- Frost Ward (Rank 2)(Defensive)
		AddUserFlags( 8462, Boost) 							-- Frost Ward (Rank 3)(Defensive)
		AddUserFlags(10177, Boost) 							-- Frost Ward (Rank 4)(Defensive)
		AddUserFlags(28609, Boost) 							-- Frost Ward (Rank 5)(Defensive)
		AddUserFlags( 7302, PlayerBuff) 					-- Ice Armor (Rank 1)
		AddUserFlags( 7320, PlayerBuff) 					-- Ice Armor (Rank 2)
		AddUserFlags(10219, PlayerBuff) 					-- Ice Armor (Rank 3)
		AddUserFlags(10220, PlayerBuff) 					-- Ice Armor (Rank 4)
		AddUserFlags(11426, Boost) 							-- Ice Barrier (Rank 1)(Defensive)
		AddUserFlags(13031, Boost) 							-- Ice Barrier (Rank 2)(Defensive)
		AddUserFlags(13032, Boost) 							-- Ice Barrier (Rank 3)(Defensive)
		AddUserFlags(13033, Boost) 							-- Ice Barrier (Rank 4)(Defensive)
		AddUserFlags(11958, Boost) 							-- Ice Block (Talent)(Defensive)
		AddUserFlags(12579, Boost) 							-- Winter's Chill (Proc)(Talent)(Boost)
	end

	-- Warrior
	-----------------------------------------------------------------
	do
		-- Warrior (Arms)
		-- https://classic.wowhead.com/warrior-abilities/arms
		-- https://classic.wowhead.com/arms-warrior-talents
		------------------------------------------------------------------------
		AddUserFlags( 2457, Never) 							-- Battle Stance (Shapeshift) CHECK!
		AddUserFlags( 7922, Harmful) 						-- Charge Stun
		AddUserFlags(12162, Boost) 							-- Deep Wounds Bleed (Rank 1) CHECK!
		AddUserFlags(12850, Boost) 							-- Deep Wounds Bleed (Rank 2) CHECK!
		AddUserFlags(12868, Boost) 							-- Deep Wounds Bleed (Rank 3) CHECK!
		AddUserFlags( 1715, Harmful) 						-- Hamstring (Rank 1)
		AddUserFlags( 7372, Harmful) 						-- Hamstring (Rank 2)
		AddUserFlags( 7373, Harmful) 						-- Hamstring (Rank 3)
		AddUserFlags(  694, OnEnemy) 						-- Mocking Blow (Rank 1) (Taunt)
		AddUserFlags( 7400, OnEnemy) 						-- Mocking Blow (Rank 2) (Taunt)
		AddUserFlags( 7402, OnEnemy) 						-- Mocking Blow (Rank 3) (Taunt)
		AddUserFlags(20559, OnEnemy) 						-- Mocking Blow (Rank 4) (Taunt)
		AddUserFlags(20560, OnEnemy) 						-- Mocking Blow (Rank 5) (Taunt)
		AddUserFlags(12294, Harmful) 						-- Mortal Strike (Rank 1)(Talent)
		AddUserFlags(21551, Harmful) 						-- Mortal Strike (Rank 2)
		AddUserFlags(21552, Harmful) 						-- Mortal Strike (Rank 3)
		AddUserFlags(21553, Harmful) 						-- Mortal Strike (Rank 4)
		AddUserFlags(  772, Damage) 						-- Rend (Rank 1)
		AddUserFlags( 6546, Damage) 						-- Rend (Rank 2)
		AddUserFlags( 6547, Damage) 						-- Rend (Rank 3)
		AddUserFlags( 6548, Damage) 						-- Rend (Rank 4)
		AddUserFlags(11572, Damage) 						-- Rend (Rank 5)
		AddUserFlags(11573, Damage) 						-- Rend (Rank 6)
		AddUserFlags(11574, Damage) 						-- Rend (Rank 7)
		AddUserFlags(20230, Boost) 							-- Retaliation (Boost)
		AddUserFlags(12292, ByPlayer) 						-- Sweeping Strikes (Talent)
		AddUserFlags( 6343, Harmful) 						-- Thunder Clap (Rank 1)
		AddUserFlags( 8198, Harmful) 						-- Thunder Clap (Rank 2)
		AddUserFlags( 8204, Harmful) 						-- Thunder Clap (Rank 3)
		AddUserFlags( 8205, Harmful) 						-- Thunder Clap (Rank 4)
		AddUserFlags(11580, Harmful) 						-- Thunder Clap (Rank 5)
		AddUserFlags(11581, Harmful) 						-- Thunder Clap (Rank 6)

		-- Warrior (Fury)
		-- https://classic.wowhead.com/warrior-abilities/fury
		-- https://classic.wowhead.com/fury-warrior-talents
		------------------------------------------------------------------------
		AddUserFlags( 6673, GroupBuff) 						-- Battle Shout (Rank 1)
		AddUserFlags( 5242, GroupBuff) 						-- Battle Shout (Rank 2)
		AddUserFlags( 6192, GroupBuff) 						-- Battle Shout (Rank 3)
		AddUserFlags(11549, GroupBuff) 						-- Battle Shout (Rank 4)
		AddUserFlags(11550, GroupBuff) 						-- Battle Shout (Rank 5)
		AddUserFlags(11551, GroupBuff) 						-- Battle Shout (Rank 6)
		AddUserFlags(25289, GroupBuff) 						-- Battle Shout (Rank 7)
		AddUserFlags(18499, Boost) 							-- Berserker Rage (Boost)
		AddUserFlags( 2458, Never) 							-- Berserker Stance (Shapeshift)
		AddUserFlags(16488, ByPlayer) 						-- Blood Craze (Rank 1)(Talent)
		AddUserFlags(16490, ByPlayer) 						-- Blood Craze (Rank 2)
		AddUserFlags(16491, ByPlayer) 						-- Blood Craze (Rank 3)
		AddUserFlags( 1161, OnEnemy) 						-- Challenging Shout (Taunt)
		AddUserFlags(12328, Boost) 							-- Death Wish (Boost)(Talent)
		AddUserFlags( 1160, Harmful) 						-- Demoralizing Shout (Rank 1)
		AddUserFlags( 6190, Harmful) 						-- Demoralizing Shout (Rank 2)
		AddUserFlags(11554, Harmful) 						-- Demoralizing Shout (Rank 3)
		AddUserFlags(11555, Harmful) 						-- Demoralizing Shout (Rank 4)
		AddUserFlags(11556, Harmful) 						-- Demoralizing Shout (Rank 5)
		AddUserFlags(12880, ByPlayer) 						-- Enrage (Rank 1)
		AddUserFlags(14201, ByPlayer) 						-- Enrage (Rank 2)
		AddUserFlags(14202, ByPlayer) 						-- Enrage (Rank 3)
		AddUserFlags(14203, ByPlayer) 						-- Enrage (Rank 4)
		AddUserFlags(14204, ByPlayer) 						-- Enrage (Rank 5)
		AddUserFlags(12966, ByPlayer) 						-- Flurry (Rank 1)(Talent)
		AddUserFlags(12967, ByPlayer) 						-- Flurry (Rank 2)
		AddUserFlags(12968, ByPlayer) 						-- Flurry (Rank 3)
		AddUserFlags(12969, ByPlayer) 						-- Flurry (Rank 4)
		AddUserFlags(12970, ByPlayer) 						-- Flurry (Rank 5)
		AddUserFlags(20253, Harmful) 						-- Intercept Stun (Rank 1)
		AddUserFlags(20614, Harmful) 						-- Intercept Stun (Rank 2)
		AddUserFlags(20615, Harmful) 						-- Intercept Stun (Rank 3)
		AddUserFlags( 5246, Harmful) 						-- Intimidating Shout
		AddUserFlags(12323, Harmful) 						-- Piercing Howl (Talent)
		AddUserFlags( 1719, Boost) 							-- Recklessness (Boost)

		-- Warrior (Protection)
		-- https://classic.wowhead.com/warrior-abilities/protection
		------------------------------------------------------------------------
		AddUserFlags(29131, ByPlayer) 						-- Bloodrage
		AddUserFlags(12809, Harmful) 						-- Concussion Blow (Talent)
		AddUserFlags(   71, Never) 							-- Defensive Stance (Shapeshift)
		AddUserFlags(  676, Harmful) 						-- Disarm
		AddUserFlags( 2565, ByPlayer) 						-- Shield Block
		AddUserFlags(  871, Boost) 							-- Shield Wall (Defensive)
		AddUserFlags( 7386, Harmful) 						-- Sunder Armor (Rank 1)
		AddUserFlags( 7405, Harmful) 						-- Sunder Armor (Rank 2)
		AddUserFlags( 8380, Harmful) 						-- Sunder Armor (Rank 3)
		AddUserFlags(11596, Harmful) 						-- Sunder Armor (Rank 4)
		AddUserFlags(11597, Harmful) 						-- Sunder Armor (Rank 5)
	end

	-- Maybe just add an additional name based filter for these(?)
	AddUserFlags(  430, PlayerBuff) 						-- Drink (Level 1)
	AddUserFlags(  431, PlayerBuff) 						-- Drink (Level 15)
	AddUserFlags(  432, PlayerBuff) 						-- Drink (Level 25)
	AddUserFlags( 1133, PlayerBuff) 						-- Drink (Level 35)
	AddUserFlags( 1135, PlayerBuff) 						-- Drink (Level 45)
	AddUserFlags( 1137, PlayerBuff) 						-- Drink (Level 55)

	
	AddUserFlags(11196, ByPlayer) 							-- Recently Bandaged

-- WoW Retail (Battle for Azeroth)
elseif (IsRetail) then

	-- Demon Hunter
	------------------------------------------------------------------------
	do
		AddUserFlags(203981, ByPlayer) 						-- Soul Fragments (Buff)

		-- Demon Hunter (Vengeance)
		-- https://www.wowhead.com/vengeance-demon-hunter-abilities/live-only:on
		------------------------------------------------------------------------
	end

	-- Death Knight
	------------------------------------------------------------------------
	do
		-- Death Knight (Blood)
		-- https://www.wowhead.com/blood-death-knight-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(188290, ByPlayer) 						-- Death and Decay (Buff)
	end

	-- Druid
	-----------------------------------------------------------------
	do
		-- Druid (Abilities)
		-- https://www.wowhead.com/druid-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(  5487, Never) 						-- Bear Form (Shapeshift)
		AddUserFlags(   768, Never) 						-- Cat Form (Shapeshift)
		AddUserFlags(  1850, ByPlayer) 						-- Dash
		AddUserFlags(   339, Harmful) 						-- Entangling Roots
		AddUserFlags(164862, ByPlayer) 						-- Flap
		AddUserFlags(165962, Never) 						-- Flight Form (Shapeshift)
		AddUserFlags(  6795, OnEnemy) 						-- Growl (Taunt)
		AddUserFlags(  2637, Harmful) 						-- Hibernate
		AddUserFlags(164812, Damage) 						-- Moonfire
		AddUserFlags(  8936, ByPlayer) 						-- Regrowth
		AddUserFlags(210053, Never) 						-- Stag Form (Shapeshift)
		AddUserFlags(164815, Damage) 						-- Sunfire
		AddUserFlags(106830, Damage) 						-- Thrash
		AddUserFlags(   783, Never) 						-- Travel Form (Shapeshift)

		-- Druid (Talents)
		-- https://www.wowhead.com/druid-talents/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(155835, ByPlayer) 						-- Bristling Fur
		AddUserFlags(102351, OnFriend) 						-- Cenarion Ward
		AddUserFlags(202770, ByPlayer) 						-- Fury of Elune
		AddUserFlags(102558, Boost) 						-- Incarnation: Guardian of Ursoc (Shapeshift)
		AddUserFlags(102543, Boost) 						-- Incarnation: King of the Jungle (Shapeshift)
		AddUserFlags( 33891, Boost) 						-- Incarnation: Tree of Life (Shapeshift)
		AddUserFlags(102359, Harmful) 						-- Mass Entanglement
		AddUserFlags(  5211, Harmful) 						-- Mighty Bash
		AddUserFlags( 52610, ByPlayer) 						-- Savage Roar
		AddUserFlags(202347, Damage) 						-- Stellar Flare
		AddUserFlags(252216, ByPlayer) 						-- Tiger Dash
		AddUserFlags( 61391, Harmful) 						-- Typhoon (Proc)
		AddUserFlags(102793, Harmful) 						-- Ursol's Vortex
		AddUserFlags(202425, ByPlayer) 						-- Warrior of Elune

		-- Druid (Balance)
		-- https://www.wowhead.com/balance-druid-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags( 22812, ByPlayer) 						-- Barkskin
		AddUserFlags(194223, ByPlayer) 						-- Celestial Alignment
		AddUserFlags( 29166, Boost) 						-- Innervate
		AddUserFlags( 24858, Never) 						-- Moonkin Form (Shapeshift)
		AddUserFlags(  5215, Never) 						-- Prowl
		AddUserFlags( 78675, Damage) 						-- Solar Beam
		AddUserFlags(191034, Damage) 						-- Starfall
		AddUserFlags( 93402, Damage) 						-- Sunfire

		-- Druid (Feral)
		-- https://www.wowhead.com/feral-druid-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(106951, Boost) 						-- Berserk
		AddUserFlags(135700, ByPlayer) 						-- Clearcasting (Omen of Clarity Proc)
		AddUserFlags( 58180, Harmful) 						-- Infected Wounds (Proc)
		AddUserFlags( 22570, Harmful) 						-- Maim
		--AddUserFlags(  5215, Never) 						-- Prowl
		AddUserFlags(155722, Damage) 						-- Rake
		AddUserFlags(  1079, Damage) 						-- Rip
		AddUserFlags(106898, ByPlayer) 						-- Stampeding Roar
		AddUserFlags( 61336, ByPlayer) 						-- Survival Instincts
		AddUserFlags(  5217, ByPlayer) 						-- Tiger's Fury

		-- Druid (Guardian)
		-- https://www.wowhead.com/guardian-druid-abilities/live-only:on
		------------------------------------------------------------------------
		--AddUserFlags( 22812, ByPlayer) 					-- Barkskin
		AddUserFlags( 22842, Healing) 						-- Frenzied Regeneration
		AddUserFlags(    99, Harmful) 						-- Incapacitating Roar
		AddUserFlags(192081, ByPlayer) 						-- Ironfur
		--AddUserFlags(  5215, Never) 						-- Prowl
		--AddUserFlags(106898, ByPlayer) 					-- Stampeding Roar
		--AddUserFlags( 61336, ByPlayer) 					-- Survival Instincts

		-- Druid (Restoration)
		-- https://www.wowhead.com/restoration-druid-abilities/live-only:on
		------------------------------------------------------------------------
		--AddUserFlags( 22812, ByPlayer) 					-- Barkskin
		AddUserFlags( 16870, ByPlayer) 						-- Clearcasting (Lifebloom Proc)
		--AddUserFlags( 29166, Boost) 						-- Innervate
		AddUserFlags(102342, ByPlayer) 						-- Ironbark
		AddUserFlags( 33763, Healing) 						-- Lifebloom
		--AddUserFlags(  5215, Never) 						-- Prowl
		AddUserFlags(   774, Healing) 						-- Rejuvenation
		--AddUserFlags( 93402, Damage) 						-- Sunfire
		AddUserFlags(   740, Healing) 						-- Tranquility
		AddUserFlags( 48438, Healing) 						-- Wild Growth
	end

	-- Hunter
	-----------------------------------------------------------------
	do
		-- Hunter (Abilities)
		-- https://www.wowhead.com/hunter-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags( 61648, ByPlayer) 				-- Aspect of the Chameleon
		AddUserFlags(186257, ByPlayer) 				-- Aspect of the Cheetah
		AddUserFlags(186265, ByPlayer) 				-- Aspect of the Turtle
		AddUserFlags(  6197, ByPlayer) 				-- Eagle Eye
		AddUserFlags(  5384, ByPlayer) 				-- Feign Death
		AddUserFlags(209997, ByPlayer) 				-- Play Dead
		AddUserFlags(  1515, ByPlayer) 				-- Tame Beast

		-- Hunter (Talents)
		-- https://www.wowhead.com/hunter-talents/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(131894, ByPlayer) 				-- A Murder of Crows
		AddUserFlags(199483, ByPlayer) 				-- Camouflage
		AddUserFlags(260402, Boost) 				-- Double Tap
		AddUserFlags(212431, Damage) 				-- Explosive Shot
		AddUserFlags(257284, ByPlayer) 				-- Hunter's Mark
		AddUserFlags(194594, Boost) 				-- Lock and Load (Proc)
		AddUserFlags(271788, Damage) 				-- Serpent Sting
		AddUserFlags(194407, Boost) 				-- Spitting Cobra
		AddUserFlags(268552, Boost) 				-- Viper's Venom (Proc)

		-- Hunter (Beast Mastery)
		-- https://www.wowhead.com/beast-mastery-hunter-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(193530, ByPlayer) 				-- Aspect of the Wild
		AddUserFlags(217200, Damage) 				-- Barbed Shot
		AddUserFlags( 19574, Boost) 				-- Bestial Wrath
		AddUserFlags(  5116, Harmful) 				-- Concussive Shot
		AddUserFlags( 19577, ByPlayer) 				-- Intimidation
		AddUserFlags( 34477, ByPlayer) 				-- Misdirection
		AddUserFlags(118922, ByPlayer) 				-- Posthaste (Disengage Proc)
		AddUserFlags(185791, Boost) 				-- Wild Call

		-- Hunter (Marksmanship)
		-- https://www.wowhead.com/marksmanship-hunter-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(186387, Harmful) 				-- Bursting Shot
		AddUserFlags(257044, Damage) 				-- Rapid Fire
		AddUserFlags(288613, Boost) 				-- Trueshot

		-- Hunter (Survival)
		-- https://www.wowhead.com/survival-hunter-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(186289, ByPlayer) 				-- Aspect of the Eagle
		AddUserFlags(266779, Boost) 				-- Coordinated Assault
		AddUserFlags(186260, Harmful) 				-- Harpoon
		AddUserFlags(259491, Damage) 				-- Serpent Sting (Survival)
		AddUserFlags(195645, Harmful) 				-- Wing Clip
	end

	-- Warrior
	-----------------------------------------------------------------
	do
		-- Warrior (Abilities)
		-- https://www.wowhead.com/warrior-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(  6673, GroupBuff) 					-- Battle Shout
		AddUserFlags(115767, Damage) 						-- Deep Wounds
		AddUserFlags(   355, OnEnemy) 						-- Taunt
		AddUserFlags(  7922, Harmful) 						-- Warbringer (Charge Stun)
		AddUserFlags(213427, Harmful) 						-- Warbringer (Charge Stun)

		-- Warrior (Talents)
		-- https://www.wowhead.com/warrior-talents/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(107574, Boost) 						-- Avatar (Boost)
		AddUserFlags( 46924, Boost) 						-- Bladestorm (Boost)
		AddUserFlags(262228, ByPlayer) 						-- Deadly Calm (Clearcast)
		AddUserFlags(197690, Never) 						-- Defensive Stance (Stance)
		AddUserFlags(118000, Harmful) 						-- Dragon Roar
		AddUserFlags(215572, ByPlayer) 						-- Frothing Berserker (Proc)
		AddUserFlags(275335, Damage) 						-- Punish
		AddUserFlags(   772, Damage) 						-- Rend
		AddUserFlags(152277, ByPlayer) 						-- Ravager (Arms)
		AddUserFlags(228920, ByPlayer) 						-- Ravager (Protection)
		AddUserFlags(107570, Harmful) 						-- Storm Bolt
		AddUserFlags(262232, Harmful) 						-- War Machine (Proc)

		-- Warrior (Arms)
		-- https://www.wowhead.com/arms-warrior-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags( 18499, Boost) 						-- Berserker Rage (Boost)
		AddUserFlags(227847, Boost) 						-- Bladestorm (Boost)
		AddUserFlags(262115, Damage) 						-- Deep Wounds
		AddUserFlags(118038, Boost) 						-- Die by the Sword (Defensive)
		AddUserFlags(  1715, Harmful) 						-- Hamstring
		AddUserFlags(  5246, Harmful) 						-- Intimidating Shout
		AddUserFlags(  7384, ByPlayer) 						-- Overpower (Proc)
		AddUserFlags(260708, ByPlayer) 						-- Sweeping Strikes

		-- Warrior (Fury)
		-- https://www.wowhead.com/fury-warrior-abilities/live-only:on
		------------------------------------------------------------------------
		--AddUserFlags( 18499, Boost) 						-- Berserker Rage (Boost)
		--AddUserFlags( 5246, Harmful) 						-- Intimidating Shout
		AddUserFlags( 12323, Harmful) 						-- Piercing Howl
		AddUserFlags(  1719, Boost) 						-- Recklessness (Boost)

		-- Warrior (Protection)
		-- https://www.wowhead.com/protection-warrior-abilities/live-only:on
		------------------------------------------------------------------------
		--AddUserFlags( 18499, Boost) 						-- Berserker Rage (Boost)
		AddUserFlags(  1160, ByPlayer) 						-- Demoralizing Shout (Debuff)
		AddUserFlags(190456, Boost) 						-- Ignore Pain (Defensive)
		--AddUserFlags( 5246, Harmful) 						-- Intimidating Shout
		AddUserFlags( 12975, Boost) 						-- Last Stand (Defensive)
		AddUserFlags(   871, Boost) 						-- Shield Wall (Defensive)
		AddUserFlags( 46968, Harmful) 						-- Shockwave
		AddUserFlags( 23920, Boost) 						-- Spell Reflection (Defensive)
		AddUserFlags(  6343, Harmful) 						-- Thunder Clap
	end

	-- Mage
	-----------------------------------------------------------------
	do
		-- Mage (Abilities)
		-- https://www.wowhead.com/mage-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(  1459, GroupBuff) 					-- Arcane Intellect (Raid)
		AddUserFlags(  1953, ByPlayer) 						-- Blink
		AddUserFlags( 33395, Harmful) 						-- Freeze
		AddUserFlags(   122, Harmful) 						-- Frost Nova
		AddUserFlags( 45438, Boost) 						-- Ice Block (Defensive)
		AddUserFlags( 61305, Harmful) 						-- Polymorph: Black Cat
		AddUserFlags(277792, Harmful) 						-- Polymorph: Bumblebee
		AddUserFlags(277787, Harmful) 						-- Polymorph: Direhorn
		AddUserFlags(161354, Harmful) 						-- Polymorph: Monkey
		AddUserFlags(161372, Harmful) 						-- Polymorph: Peacock
		AddUserFlags(161355, Harmful) 						-- Polymorph: Penguin
		AddUserFlags( 28272, Harmful) 						-- Polymorph: Pig
		AddUserFlags(161353, Harmful) 						-- Polymorph: Polar Bear Cub
		AddUserFlags(126819, Harmful) 						-- Polymorph: Porcupine
		AddUserFlags( 61721, Harmful) 						-- Polymorph: Rabbit
		AddUserFlags(   118, Harmful) 						-- Polymorph: Sheep
		AddUserFlags( 61780, Harmful) 						-- Polymorph: Turkey
		AddUserFlags( 28271, Harmful) 						-- Polymorph: Turtle
		AddUserFlags(   130, Harmful) 						-- Slow Fall
		AddUserFlags( 80353, Boost) 						-- Time Warp (Boost)(Raid)

		-- Mage (Talents)
		-- https://www.wowhead.com/mage-talents/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(210126, ByPlayer) 						-- Arcane Familiar
		AddUserFlags(157981, Harmful) 						-- Blast Wave
		AddUserFlags(205766, ByPlayer) 						-- Bone Chilling
		AddUserFlags(236298, ByPlayer) 						-- Chrono Shift (Player Speed Boost)
		AddUserFlags(236299, Harmful) 						-- Chrono Shift (Target Speed Reduction)
		AddUserFlags(277726, ByPlayer) 						-- Clearcasting (Amplification Proc)(Clearcast)
		AddUserFlags(226757, Damage) 						-- Conflagration
		AddUserFlags(236060, ByPlayer) 						-- Frenetic Speed
		AddUserFlags(199786, Harmful) 						-- Glacial Spike
		AddUserFlags(108839, ByPlayer) 						-- Ice Floes
		AddUserFlags(157997, Harmful) 						-- Ice Nova
		AddUserFlags( 44457, Damage) 						-- Living Bomb
		AddUserFlags(114923, Damage) 						-- Nether Tempest
		AddUserFlags(235450, Boost) 						-- Prismatic Barrier (Mana Shield)(Defensive)
		AddUserFlags(205021, Harmful) 						-- Ray of Frost
		AddUserFlags(212653, ByPlayer) 						-- Shimmer
		AddUserFlags(210824, Damage) 						-- Touch of the Magi

		-- Mage (Arcane)
		-- https://www.wowhead.com/arcane-mage-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags( 12042, ByPlayer) 						-- Arcane Power
		AddUserFlags( 12051, Boost) 						-- Evocation
		AddUserFlags(110960, ByPlayer) 						-- Greater Invisibility
		AddUserFlags(    66, ByPlayer) 						-- Invisibility CHECK!
		AddUserFlags(205025, Boost) 						-- Presence of Mind
		AddUserFlags(235450, ByPlayer) 						-- Prismatic Barrier
		AddUserFlags( 31589, Harmful) 						-- Slow

		-- Mage (Fire)
		-- https://www.wowhead.com/fire-mage-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(190319, Boost) 						-- Combustion
		AddUserFlags(235313, ByPlayer) 						-- Blazing Barrier
		AddUserFlags(235314, Boost) 						-- Blazing Barrier (Proc)
		AddUserFlags(108843, Boost) 						-- Blazing Speed (Cauterize Proc)
		AddUserFlags( 31661, Harmful) 						-- Dragon's Breath
		AddUserFlags(157644, ByPlayer) 						-- Enhanced Pyrotechnics
		AddUserFlags(  2120, Harmful) 						-- Flamestrike
		AddUserFlags(195283, ByPlayer) 						-- Hot Streak (Proc)

		-- Mage (Frost)
		-- https://www.wowhead.com/frost-mage-abilities/live-only:on
		------------------------------------------------------------------------
		AddUserFlags(   120, Harmful) 						-- Cone of Cold
		AddUserFlags( 11426, ByPlayer) 						-- Ice Barrier (PlayerBuff) CHECK!
		AddUserFlags( 12472, Boost) 						-- Icy Veins

	end

	-- Blacklists
	-----------------------------------------------------------------
	do
		-- Spammy stuff that is implicit and not really needed
		AddUserFlags(204242, NeverOnPlate) 					-- Consecration (talent Consecrated Ground)

		-- NPC buffs that are completely useless
		------------------------------------------------------------------------
		AddUserFlags( 63501, Never) 						-- Argent Crusade Champion's Pennant
		AddUserFlags( 60023, Never) 						-- Scourge Banner Aura (Boneguard Commander in Icecrown)
		AddUserFlags( 63406, Never) 						-- Darnassus Champion's Pennant
		AddUserFlags( 63405, Never) 						-- Darnassus Valiant's Pennant
		AddUserFlags( 63423, Never) 						-- Exodar Champion's Pennant
		AddUserFlags( 63422, Never) 						-- Exodar Valiant's Pennant
		AddUserFlags( 63396, Never) 						-- Gnomeregan Champion's Pennant
		AddUserFlags( 63395, Never) 						-- Gnomeregan Valiant's Pennant
		AddUserFlags( 63427, Never) 						-- Ironforge Champion's Pennant
		AddUserFlags( 63426, Never) 						-- Ironforge Valiant's Pennant
		AddUserFlags( 63433, Never) 						-- Orgrimmar Champion's Pennant
		AddUserFlags( 63432, Never) 						-- Orgrimmar Valiant's Pennant
		AddUserFlags( 63399, Never) 						-- Sen'jin Champion's Pennant
		AddUserFlags( 63398, Never) 						-- Sen'jin Valiant's Pennant
		AddUserFlags( 63403, Never) 						-- Silvermoon Champion's Pennant
		AddUserFlags( 63402, Never) 						-- Silvermoon Valiant's Pennant
		AddUserFlags( 62594, Never) 						-- Stormwind Champion's Pennant
		AddUserFlags( 62596, Never) 						-- Stormwind Valiant's Pennant
		AddUserFlags( 63436, Never) 						-- Thunder Bluff Champion's Pennant
		AddUserFlags( 63435, Never) 						-- Thunder Bluff Valiant's Pennant
		AddUserFlags( 63430, Never) 						-- Undercity Champion's Pennant
		AddUserFlags( 63429, Never) 						-- Undercity Valiant's Pennant
	end

	-- Whitelists
	-----------------------------------------------------------------
	do
		-- Quests and stuff that are game-breaking to not have there
		------------------------------------------------------------------------
		AddUserFlags(105241, Always) 						-- Absorb Blood (Amalgamation Stacks, some raid)
		AddUserFlags(304696, OnPlayer) 						-- Alpha Fin (constantly moving mount Nazjatar)
		AddUserFlags(298047, OnPlayer) 						-- Arcane Leylock (Untangle World Quest Nazjatar)
		AddUserFlags(298565, OnPlayer) 						-- Arcane Leylock (Untangle World Quest Nazjatar)
		AddUserFlags(298654, OnPlayer) 						-- Arcane Leylock (Untangle World Quest Nazjatar)
		AddUserFlags(298657, OnPlayer) 						-- Arcane Leylock (Untangle World Quest Nazjatar)
		AddUserFlags(298659, OnPlayer) 						-- Arcane Leylock (Untangle World Quest Nazjatar)
		AddUserFlags(298661, OnPlayer) 						-- Arcane Runelock (Puzzle World Quest Nazjatar)
		AddUserFlags(298663, OnPlayer) 						-- Arcane Runelock (Puzzle World Quest Nazjatar)
		AddUserFlags(298665, OnPlayer) 						-- Arcane Runelock (Puzzle World Quest Nazjatar)
		AddUserFlags(272004, OnPlayer) 						-- Choking Fog (outdoors debuff Stormsong Valley)
		AddUserFlags(304037, OnPlayer) 						-- Fermented Deviate Fish (transform)
		AddUserFlags(188030, ByPlayer) 						-- Leytorrent Potion (channeled) (Legion Consumables)
		AddUserFlags(295858, OnPlayer) 						-- Molted Shell (constantly moving mount Nazjatar)
		AddUserFlags(188027, ByPlayer) 						-- Potion of Deadly Grace (Legion Consumables)
		AddUserFlags(188028, ByPlayer) 						-- Potion of the Old War (Legion Consumables)
		AddUserFlags(188029, ByPlayer) 						-- Unbending Potion (Legion Consumables)
		AddUserFlags(127372, OnPlayer) 						-- Unstable Serum (Klaxxi Enhancement: Raining Blood)
		AddUserFlags(240640, OnPlayer) 						-- The Shadow of the Sentinax (Mark of the Sentinax)
		AddUserFlags(254873, OnPlayer) 						-- Irontide Recruit (Tiragarde Sound Storyline)
		
		-- Heroism
		------------------------------------------------------------------------
		AddUserFlags( 90355, OnPlayer + PrioHigh) 			-- Ancient Hysteria
		AddUserFlags(  2825, OnPlayer + PrioHigh) 			-- Bloodlust
		AddUserFlags( 32182, OnPlayer + PrioHigh) 			-- Heroism
		AddUserFlags(160452, OnPlayer + PrioHigh) 			-- Netherwinds
		AddUserFlags( 80353, OnPlayer + PrioHigh) 			-- Time Warp
		AddUserFlags( 57723, OnPlayer) 						-- Exhaustion "Cannot benefit from Heroism or other similar effects." (Alliance version)
		AddUserFlags(160455, OnPlayer) 						-- Fatigued "Cannot benefit from Netherwinds or other similar effects." (Pet version)
		AddUserFlags( 95809, OnPlayer) 						-- Insanity "Cannot benefit from Ancient Hysteria or other similar effects." (Pet version)
		AddUserFlags( 57724, OnPlayer) 						-- Sated "Cannot benefit from Bloodlust or other similar effects." (Horde version)
		AddUserFlags( 80354, OnPlayer) 						-- Temporal Displacement

		-- Deserters
		------------------------------------------------------------------------
		AddUserFlags( 26013, OnPlayer + PrioHigh) 			-- Deserter
		AddUserFlags( 99413, OnPlayer + PrioHigh) 			-- Deserter
		AddUserFlags( 71041, OnPlayer + PrioHigh) 			-- Dungeon Deserter
		AddUserFlags(144075, OnPlayer + PrioHigh) 			-- Dungeon Deserter
		AddUserFlags(170616, OnPlayer + PrioHigh) 			-- Pet Deserter

		-- Other big ones
		------------------------------------------------------------------------
		AddUserFlags( 67556, OnPlayer) 						-- Cooking Speed
		AddUserFlags(243138, OnPlayer) 						-- Happy Feet event 
		AddUserFlags(246050, OnPlayer) 						-- Happy Feet buff gained restoring health
		AddUserFlags( 33206, OnPlayer) 						-- Pain Suppression
		AddUserFlags( 10060, OnPlayer) 						-- Power Infusion
		AddUserFlags( 15007, OnPlayer + PrioHigh) 			-- Resurrection Sickness
		AddUserFlags( 64901, OnPlayer) 						-- Symbol of Hope
	end

end

-- Retrieve a shortcut to the now existing userflag table
-- This will be used by the aura filter above.
local UserFlags = LibAuraData.GetAllAuraUserFlags(Private)

-- Aura Filter Functions
-----------------------------------------------------------------
-- Whether or not the spellID should be hidden from the tooltips
local hideUnfilteredSpellID, hideFilteredSpellID = false, false

-- Aura duration thresholds
local buffDurationThreshold, debuffDurationThreshold = 61, 601
--local shortBuffDurationThreshold, shortDebuffDurationThreshold = 31, 31

-- @return <boolean> true if the current time left falls within the limits to be shown
local checkTimeAndStackbasedConditionals = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	-- Show auras with stacks
	if (count and count > 1) then
		return true
	end

	-- Check if the remaining duration falls within our thresholds to show it
	local timeLeft
	if (expirationTime and expirationTime > 0) then 
		timeLeft = expirationTime - GetTime()
	end
	if (isBuff) then 
		if (timeLeft and (timeLeft > 0) and (timeLeft < buffDurationThreshold))
		or (duration and (duration > 0) and (duration < buffDurationThreshold)) then
			return true
		end
	else 
		if (timeLeft and (timeLeft > 0) and (timeLeft < debuffDurationThreshold))
		or (duration and (duration > 0) and (duration < debuffDurationThreshold)) then
			return true
		end
	end

	-- Nothing to show
	return false
end

-- @return <boolean> - true if this is an expiring aura tagged for warnings, false if it fails and should be hidden
local checkWarningConditionals = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	if (UserFlags[spellID]) then
		if (HasUserFlags(spellID, Warn)) then
			if (checkTimeAndStackbasedConditionals(spellID, unit, count, duration, expirationTime, isBuff)) then
				return true
			end
		end
	end

	-- No filters for warnings detected
	return false
end

-- @return <boolean> - true if whitelisted, false if not
local checkWhitelistConditionals = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	-- Cast by or on vehicles
	if (IsRetail) then 
		if (UnitHasVehicleUI("player")) then
			if (isBuff) then
				if ((isCastByPlayer) or (unitCaster == "pet") or (unitCaster == "vehicle")) then
					return true
				end
			else
				return true
			end
		end
	end

	-- User whitelisted
	if (UserFlags[spellID]) then
		if (HasUserFlags(spellID, Always)) then
			return true
		end
	end
	
	-- Not whitelisted
	return false
end

-- Note: This function doesn't returen a visibility boolean,
-- but rather a blacklist boolean, meaning returns are reversed!
-- @return <boolean> - true if blacklisted, false if not
local checkBlacklistConditionals = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	if (UserFlags[spellID]) then
		-- User blacklisted
		if (HasUserFlags(spellID, Never)) then

			-- Do we need to warn about this running out?
			if (checkWarningConditionals(...)) then
				return false
			end
			
			-- No warn flag set or active, this should be hidden!
			return true
		end

		-- User nameplate blacklisted
		if (HasUserFlags(spellID, NeverOnPlate)) and (string_match(unit, "^nameplate%d$")) then
			return true
		end
	end

	-- Not blacklisted
	return false
end

-- @return <boolean> - true if a unit flag matches, false if none do
local checkUnitConditionals = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	if (UserFlags[spellID]) then
		-- Listing these in the order of frequency in my filters,
		-- to avoid any excessive unneeded use of function calls.
		if (HasUserFlags(spellID, ByPlayer) and isCastByPlayer)
		or (HasUserFlags(spellID, OnPlayer) and UnitIsUnit(unit, "player"))
		or (HasUserFlags(spellID, OnEnemy) and UnitCanAttack("player", unit))
		or (HasUserFlags(spellID, OnFriend) and UnitIsFriend("player", unit))
		or (HasUserFlags(spellID, OnTarget) and UnitIsUnit(unit, "target"))
		or (HasUserFlags(spellID, OnToT) and UnitIsUnit(unit, "targettarget"))
		or (HasUserFlags(spellID, OnFocus) and UnitIsUnit(unit, "focus"))
		or (HasUserFlags(spellID, OnPet) and UnitIsUnit(unit, "pet"))
		or (HasUserFlags(spellID, OnParty) and UnitInParty(unit))
		or (HasUserFlags(spellID, OnRaid) and UnitInRaid(unit))
		then
			return true
		end

		-- Boss Units
		-- Testing these bit by bit, to avoid extra function calls.
		if (HasUserFlags(spellID, OnBoss)) then
			-- Check if the unitID is a boss unit
			if (string_match(unit, "^boss%d$")) then
				return true
			end
			-- Regular checks for dungeon- and world bosses
			local unitLevel = UnitLevel(unit)
			if (unitLevel and unitLevel < 1) or (UnitClassification(unit) == "worldboss") then
				return true
			end
		end
	end

	return false
end

-- @return <boolean> - true if it passes the extra conditionals, false if it fails and should be hidden
local checkCombatConditionals = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	-- Only show out of combat
	if (UserFlags[spellID]) then
		if (HasUserFlags(spellID, NoCombat) and (UnitAffectingCombat("player"))) then

			-- Do we need to warn about this running out mid combat?
			if (checkWarningConditionals(...)) then
				return true
			end

			-- No flag set for warnings, or too much time left.
			return false
		end
	end

	-- No filters for removal detected, so showing this one.
	return true
end

-- Back-end expects these return values from any filter:
-- @return displayAura <boolean>, displayPriority <number,nil>, isFiltered <boolean>
local strictFilter = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	-- Show all boss or encounter debuffs
	if (isBossDebuff) then
		return true
	end

	-- Show Eat/Drink on player(?)
	if (name == L_DRINK) or (name == L_FOOD) then
		return true, nil, hideFilteredSpellID
	end
	
	-- Show anything explicitly whitelisted
	if (checkWhitelistConditionals(...)) then
		return true, nil, hideFilteredSpellID

	-- Show anything explicitly blacklisted
	elseif (checkBlacklistConditionals(...)) then
		return false, nil, hideFilteredSpellID

	-- Show auras based on units and casters
	elseif (checkUnitConditionals(...)) then

		-- Do a final check to see if it should be hidden in combat,
		-- or visible because it's an important buff about to run out.
		if (checkCombatConditionals(...)) then
			return true, nil, hideFilteredSpellID
		end
	end

	-- Show time based debuffs from environment or NPCs
	if (not isBuff) and (UnitIsUnit(unit, "player")) and (not unitCaster or not UnitIsPlayer(unitCaster)) then
		if (checkTimeAndStackbasedConditionals(...)) then
			return true, nil, hideUnfilteredSpellID
		end
	end

	-- Show time based auras from any sources.
	if (SLACKMODE) or (element.enableSlackMode) then
		if (checkTimeAndStackbasedConditionals(...)) then
			return true, nil, hideUnfilteredSpellID
		end
	end

	-- Show static crap out of combat
	if ((SLACKMODE) or (element.enableSpamMode)) and (not UnitAffectingCombat("player")) then
		if (not duration) or (duration == 0) then
			return true, nil, hideUnfilteredSpellID
		else
			if (isBuff) then 
				if (timeLeft and (timeLeft > 0) and (timeLeft > buffDurationThreshold))
				or (duration and (duration > 0) and (duration > buffDurationThreshold)) then
					return true
				end
			else 
				if (timeLeft and (timeLeft > 0) and (timeLeft > debuffDurationThreshold))
				or (duration and (duration > 0) and (duration > debuffDurationThreshold)) then
					return true
				end
			end
		end
	end

	-- Hide everything else
	return false, nil, hideUnfilteredSpellID
end

-- Private Addon API
-----------------------------------------------------------------
Private.Colors = Colors
Private.GetAuraFilterFunc = function() return strictFilter end
Private.GetFont = function(...) return LibFontTool:GetFont(...) end
Private.GetMedia = function(name, type) return ([[Interface\AddOns\%s\media\%s.%s]]):format(ADDON, name, type or "tga") end
Private.IsForcingSlackAuraFilterMode = function() return SLACKMODE end
