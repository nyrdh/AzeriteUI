local ADDON, Private = ...

local LibAuraData = Wheel("LibAuraData")
assert(LibAuraData, ADDON.." requires LibAuraData to be loaded.")

-- Lua API
local assert = assert
local debugstack = debugstack
local error = error
local math_floor = math.floor
local select = select
local string_format = string.format
local string_join = string.join
local string_match = string.match
local type = type

-- WoW API
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitClassification = UnitClassification
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitIsFriend = UnitIsFriend
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel

-- Private API
local IsClassic = Private.IsClassic
local IsRetail = Private.IsRetail

-- Library Databases
local BitFilters = LibAuraData:GetAllAuraInfoBitFilters() -- Aura bit filters
local InfoFlags = LibAuraData:GetAllAuraInfoFlags() -- Aura info flags
local UserFlags -- populated and created farther down

-- Speed API
local AddUserFlags = function(...) 
	LibAuraData.AddAuraUserFlags(Private, ...) 
	if (not UserFlags) then
		-- Used by filters later on, 
		-- defined by the back-end after the previous call.
		UserFlags = LibAuraData.GetAllAuraUserFlags(Private)
	end
end

local HasAuraUserFlags = LibAuraData.HasAuraUserFlags
local HasAuraInfoFlags = LibAuraData.HasAuraInfoFlags


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


-- Custom Bitflags used by the Aura User Flags
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
local L_DRINK = GetSpellInfo(430) -- 104270
local L_FOOD = GetSpellInfo(433) -- 104935
local L_FOOD_N_DRINK = GetSpellInfo(257425)

-- Shorthand tags for quality of life, following the guidelines above.
-- Note: Do NOT add any of these together, they must be used as the ONLY tag when used!
local GroupBuff = 		OnPlayer + NoCombat + Warn 			-- Group buffs like MotW, Fortitude
local PlayerBuff = 		ByPlayer + NoCombat + Warn 			-- Self-cast only buffs, like Omen of Clarity
local Harmful = 		OnPlayer + OnEnemy 					-- CC and other non-damaging harmful effects
local Damage = 			ByPlayer + OnPlayer 				-- DoTs
local Healing = 		ByPlayer + OnEnemy 					-- HoTs
local Shielding = 		OnPlayer + OnEnemy 					-- Shields
local Boost = 			ByPlayer + OnEnemy 					-- Damage- and defensive cooldowns

-- Aura Filter Functions
-----------------------------------------------------------------
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
		if (HasAuraUserFlags(Private, spellID, Warn)) then
			if (checkTimeAndStackbasedConditionals(...)) then
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
		if (HasAuraUserFlags(Private, spellID, Always)) then
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
		if (HasAuraUserFlags(Private, spellID, Never)) then

			-- Do we need to warn about this running out?
			if (checkWarningConditionals(...)) then
				return false
			end
			
			-- No warn flag set or active, this should be hidden!
			return true
		end

		-- User nameplate blacklisted
		if (HasAuraUserFlags(Private, spellID, NeverOnPlate)) and (string_match(unit, "^nameplate%d$")) then
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
		if (HasAuraUserFlags(Private, spellID, ByPlayer) and isCastByPlayer)
		or (HasAuraUserFlags(Private, spellID, OnPlayer) and UnitIsUnit(unit, "player"))
		or (HasAuraUserFlags(Private, spellID, OnEnemy) and UnitCanAttack("player", unit))
		or (HasAuraUserFlags(Private, spellID, OnFriend) and UnitIsFriend("player", unit))
		or (HasAuraUserFlags(Private, spellID, OnTarget) and UnitIsUnit(unit, "target"))
		or (HasAuraUserFlags(Private, spellID, OnToT) and UnitIsUnit(unit, "targettarget"))
		or (HasAuraUserFlags(Private, spellID, OnFocus) and UnitIsUnit(unit, "focus"))
		or (HasAuraUserFlags(Private, spellID, OnPet) and UnitIsUnit(unit, "pet"))
		or (HasAuraUserFlags(Private, spellID, OnParty) and UnitInParty(unit))
		or (HasAuraUserFlags(Private, spellID, OnRaid) and UnitInRaid(unit))
		then
			return true
		end

		-- Boss Units
		-- Testing these bit by bit, to avoid extra function calls.
		if (HasAuraUserFlags(Private, spellID, OnBoss)) then
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
		if (HasAuraUserFlags(Private, spellID, NoCombat) and (element.inCombat)) then

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
-- @return displayAura <boolean>, displayPriority <number,nil>
local auraFilter = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	-- Show all boss or encounter debuffs
	if (isBossDebuff) then
		return true, nil
	end

	-- Show Eat/Drink on player(?)
	if (element.isYou) and ((name == L_DRINK) or (name == L_FOOD) or (name == L_FOOD_N_DRINK)) then
		return true, nil
	end

	if (element.isEnemy) and (element._owner.unitGroup == "boss") and (not isCastByPlayer) then
		return false, nil
	end

	-- Show anything explicitly whitelisted
	if (checkWhitelistConditionals(...)) then
		return true, nil

	-- Hide anything explicitly blacklisted
	elseif (checkBlacklistConditionals(...)) then
		return false, nil

	-- Show auras based on units and casters
	elseif (checkUnitConditionals(...)) then

		-- Do a final check to see if it should be hidden in combat,
		-- or visible because it's an important buff about to run out.
		if (checkCombatConditionals(...)) then
			return true, nil
		end
	end

	-- Show time based debuffs from environment or NPCs
	if (not isBuff) and (element.isYou) and (not unitCaster or not UnitIsPlayer(unitCaster)) then
		if (checkTimeAndStackbasedConditionals(...)) then
			return true, nil
		end
	end

	-- Show time based auras from any sources.
	if (SLACKMODE) or (element.enableSlackMode) then
		if (checkTimeAndStackbasedConditionals(...)) then
			return true, nil
		end
	end

	-- Show static crap out of combat
	if (element.enableSpamMode) and (not element.inCombat) then
		if (not duration) or (duration == 0) then
			return true, nil
		else
			if (isBuff) then 
				if (timeLeft and (timeLeft > 0) and (timeLeft > buffDurationThreshold))
				or (duration and (duration > 0) and (duration > buffDurationThreshold)) then
					return true, nil
				end
			else 
				if (timeLeft and (timeLeft > 0) and (timeLeft > debuffDurationThreshold))
				or (duration and (duration > 0) and (duration > debuffDurationThreshold)) then
					return true, nil
				end
			end
		end
	end

	-- Hide everything else
	return false, nil
end

local auraFilterFocus = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	-- Show all boss or encounter debuffs
	if (isBossDebuff) then
		return true, nil
	end

	-- Show anything explicitly whitelisted
	if (checkWhitelistConditionals(...)) then
		return true, nil
	end	

	-- Show time based debuffs from environment or NPCs, or from you.
	if (isCastByPlayer) or ((not isBuff) and (not unitCaster or not UnitIsPlayer(unitCaster))) then
		if (checkTimeAndStackbasedConditionals(...)) then
			return true, nil
		end
	end

	-- Show time based auras from any sources.
	--if (SLACKMODE) or (element.enableSlackMode) then
	--	if (checkTimeAndStackbasedConditionals(...)) then
	--		return true, nil
	--	end
	--end
	
	-- Hide everything else
	return false, nil
end

local auraFilterBoss = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	-- Show all boss or encounter debuffs
	if (isBossDebuff) then
		return true, nil
	end

	-- Show anything explicitly whitelisted
	if (checkWhitelistConditionals(...)) then
		return true, nil
	end	

	-- Show time based debuffs from environment or NPCs, or from you.
	if (isCastByPlayer) or ((not isBuff) and (not unitCaster or not UnitIsPlayer(unitCaster))) then
		if (checkTimeAndStackbasedConditionals(...)) then
			return true, nil
		end
	end
	
	-- Hide everything else
	return false, nil
end

-- Back-end expects these return values from any filter:
-- @return displayAura <boolean>, displayPriority <number,nil>
local auraFilterLegacy = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	-- Hide player and friend debuffs, enemy buffs
	if ((element.isYou or element.isFriend) and (not isBuff)) or ((element.isEnemy) and (isBuff)) then
		return false, nil
	end

	-- Pass the rest through the standard filter 
	return auraFilter(...)
end

-- Back-end expects these return values from any filter:
-- @return displayAura <boolean>, displayPriority <number,nil>
local auraFilterLegacySecondary = function(...)
	local element, isBuff, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = ...

	-- Hide player and friend buffs, enemy debuffs
	if ((element.isYou or element.isFriend) and (isBuff)) or ((element.isEnemy) and (not isBuff)) then
		return false, nil
	end

	-- Pass the rest through the standard filter 
	return auraFilter(...)
end

-- Public API
-----------------------------------------------------------------
-- Returns a copy of our primary filter function
Private.GetAuraFilter = function(...) 
	local filterType = ...
	if (filterType == "legacy") then
		return auraFilterLegacy
	elseif (filterType == "legacy-secondary") then
		return auraFilterLegacySecondary
	elseif (filterType == "focus") then
		return auraFilterFocus
	elseif (filterType == "boss") then
		return auraFilterBoss
	else
		return auraFilter
	end
end

-- Whether or not aura filters are in forced slack mode.
-- This happens if aura data isn't available for the current class.
Private.IsForcingSlackAuraFilterMode = function() 
	return SLACKMODE 
end


-- Aura Info Flags
-- These are factual flags about auras, 
-- like what class cast it, what type of aura it is, etc.
-- Nothing here is about choice, it's all facts.
-----------------------------------------------------------------
-- For convenience farther down the list here
local IsDeathKnight = BitFilters.IsPlayerSpell + BitFilters.DEATHKNIGHT
local IsDemonHunter = BitFilters.IsPlayerSpell + BitFilters.DEMONHUNTER
local IsDruid = BitFilters.IsPlayerSpell + BitFilters.DRUID
local IsHunter = BitFilters.IsPlayerSpell + BitFilters.HUNTER
local IsMage = BitFilters.IsPlayerSpell + BitFilters.MAGE
local IsMonk = BitFilters.IsPlayerSpell + BitFilters.MONK
local IsPaladin = BitFilters.IsPlayerSpell + BitFilters.PALADIN
local IsPriest = BitFilters.IsPlayerSpell + BitFilters.PRIEST
local IsRogue = BitFilters.IsPlayerSpell + BitFilters.ROGUE
local IsShaman = BitFilters.IsPlayerSpell + BitFilters.SHAMAN
local IsWarlock = BitFilters.IsPlayerSpell + BitFilters.WARLOCK
local IsWarrior = BitFilters.IsPlayerSpell + BitFilters.WARRIOR

local IsBoss = BitFilters.IsBoss
local IsDungeon = BitFilters.IsDungeon

local IsIncap = BitFilters.IsCrowdControl + BitFilters.IsIncapacitate
local IsRoot = BitFilters.IsCrowdControl + BitFilters.IsRoot
local IsSnare = BitFilters.IsCrowdControl + BitFilters.IsSnare
local IsSilence = BitFilters.IsCrowdControl + BitFilters.IsSilence
local IsStun = BitFilters.IsCrowdControl + BitFilters.IsStun
local IsTaunt = BitFilters.IsTaunt
local IsImmune = BitFilters.IsImmune
local IsImmuneCC = BitFilters.IsImmuneCC
local IsImmuneSpell = BitFilters.IsImmuneSpell
local IsImmunePhysical = BitFilters.IsImmunePhysical
local IsDisarm = BitFilters.IsDisarm
local IsFood = BitFilters.IsFood
local IsFlask = BitFilters.IsFlask

-- Proxy!
-- AddFlags(spellID[, spellID[, spellID[, ...]], flags)
local AddFlags = function(...) 
	LibAuraData:AddAuraInfoFlags(...)
end

-- Classic Aura Info Lists!
if (IsClassic) then

	-- Druid (Balance)
	-- https://classic.wowhead.com/druid-abilities/balance
	-- https://classic.wowhead.com/balance-druid-talents
	------------------------------------------------------------------------
		AddFlags(22812, IsDruid) 													-- Barkskin
		AddFlags(339,1062,5195,5196,9852,9853, IsDruid + IsRoot) 					-- Entangling Roots (Rank 1-6)
		AddFlags(770,778,9749,9907, IsDruid) 										-- Faerie Fire (Rank 1-4)
		AddFlags(2637,18657,18658, IsDruid + IsIncap) 								-- Hibernate (Rank 1-3)
		AddFlags(16914,17401,17402, IsDruid) 										-- Hurricane (Rank 1-3)
		AddFlags(8921,8924,8925,8926,8927,8928,8929,9833,9834,9835, IsDruid) 		-- Moonfire (Rank 1-10)
		AddFlags(24907, IsDruid) 													-- Moonkin Aura
		AddFlags(24858, IsDruid) 													-- Moonkin Form (Shapeshift)(Talent)
		AddFlags(16689,16810,16811,16812,16813,17329, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 1-6)(Talent)
		AddFlags(16864, IsDruid) 													-- Omen of Clarity (Buff)(Talent)
		AddFlags(16870, IsDruid) 													-- Omen of Clarity (Proc)(Talent)
		AddFlags(2908,8955,9901, IsDruid) 											-- Soothe Animal (Rank 1-3)
		AddFlags(467,782,1075,8914,9756,9910, IsDruid) 								-- Thorns (Rank 1-6)

	-- Druid (Feral)
	-- https://classic.wowhead.com/druid-abilities/feral-combat
	-- https://classic.wowhead.com/feral-combat-druid-talents
	------------------------------------------------------------------------
		AddFlags(1066, IsDruid) 													-- Aquatic Form (Shapeshift)
		AddFlags(5211,6798,8983, IsDruid + IsStun) 									-- Bash (Rank 1-3)
		AddFlags(768, IsDruid) 														-- Cat Form (Shapeshift)
		AddFlags(5209, IsDruid + IsTaunt) 											-- Challenging Roar (Taunt)
		AddFlags(99,1735,9490,9747,9898, IsDruid) 									-- Demoralizing Roar (Rank 1-5)
		AddFlags(1850,9821, IsDruid) 												-- Dash (Rank 1-2)
		AddFlags(9634, IsDruid) 													-- Dire Bear Form (Shapeshift)
		AddFlags(5229, IsDruid) 													-- Enrage
		AddFlags(16857,17390,17391,17392, IsDruid) 									-- Faerie Fire (Feral) (Rank 1-4)(Talent)
		AddFlags(16979, IsDruid + IsRoot) 											-- Feral Charge Effect (Talent)
		AddFlags(22842,22895,22896, IsDruid) 										-- Frenzied Regeneration (Rank 1-3)
		AddFlags(6795, IsDruid + IsTaunt) 											-- Growl (Taunt)
		AddFlags(24932, IsDruid) 													-- Leader of the Pack(Talent)
		AddFlags(9005,9823,9827, IsDruid + IsStun) 									-- Pounce (Stun) (Rank 1-3)
		AddFlags(9007,9824,9826, IsDruid) 											-- Pounce Bleed (Rank 1-3)
		AddFlags(5215,6783,9913, IsDruid) 											-- Prowl (Rank 1-3)
		AddFlags(1822,1823,1824,9904, IsDruid) 										-- Rake (Rank 1-4)
		AddFlags(1079,9492,9493,9752,9894,9896, IsDruid) 							-- Rip (Rank 1-6)
		AddFlags(5217,6793,9845,9846, IsDruid) 										-- Tiger's Fury (Rank 1-4)
		AddFlags(783, IsDruid) 														-- Travel Form (Shapeshift)

	-- Druid (Restoration)
	-- https://classic.wowhead.com/druid-abilities/restoration
	-- https://classic.wowhead.com/restoration-druid-talents
	------------------------------------------------------------------------
		AddFlags(2893, IsDruid) 													-- Abolish Poison
		AddFlags(21849,21850, IsDruid) 												-- Gift of the Wild (Rank 1-2)
		AddFlags(29166, IsDruid) 													-- Innervate
		AddFlags(5570,24974,24975,24976,24977, IsDruid) 							-- Insect Swarm (Rank 1-5)(Talent)
		AddFlags(1126,5232,6756,5234,8907,9884,9885, IsDruid) 						-- Mark of the Wild (Rank 1-7)
		AddFlags(17116, IsDruid) 													-- Nature's Swiftness (Clearcast,Instant)(Talent)
		AddFlags(8936,8938,8939,8940,8941,9750,9856,9857,9858, IsDruid) 			-- Regrowth (Rank 1-9)
		AddFlags(774,1058,1430,2090,2091,3627,8910,9839,9840,9841,25299, IsDruid) 	-- Rejuvenation (Rank 1-11)
		AddFlags(740,8918,9862,9863, IsDruid) 										-- Tranquility (Rank 1-4)

	-- Mage (Arcane)
	-- https://classic.wowhead.com/mage-abilities/arcane
	-- https://classic.wowhead.com/arcane-mage-talents
	------------------------------------------------------------------------
		AddFlags(1008,8455,10169,10170, IsMage) 									-- Amplify Magic (Rank 1-4)
		AddFlags(23028, IsMage) 													-- Arcane Brilliance (Rank 1)
		AddFlags(1459,1460,1461,10156,10157, IsMage) 								-- Arcane Intellect (Rank 1-5)
		AddFlags(12042, IsMage) 													-- Arcane Power (Talent)(Boost)
		AddFlags(1953, IsMage) 														-- Blink
		AddFlags(12536, IsMage) 													-- Clearcasting (Proc)(Talent)
		AddFlags(604,8450,8451,10173,10174, IsMage) 								-- Dampen Magic (Rank 1-5)
		AddFlags(2855, IsMage) 														-- Detect Magic
		AddFlags(12051, IsMage) 													-- Evocation
		AddFlags(6117,22782,22783, IsMage) 											-- Mage Armor (Rank 1-3)
		AddFlags(1463,8494,8495,10191,10192,10193, IsMage) 							-- Mana Shield (Rank 1-6)
		AddFlags(118,12824,12825,12826, IsMage + IsIncap) 							-- Polymorph (Rank 1-4)
		AddFlags(28270,28272,28271, IsMage + IsIncap) 								-- Polymorph: Cow, Pig, Turtle
		AddFlags(12043, IsMage) 													-- Presence of Mind (Talent)(Clearcast,Instant)
		AddFlags(130, IsMage) 														-- Slow Fall

	-- Mage (Fire)
	-- https://classic.wowhead.com/mage-abilities/fire
	-- https://classic.wowhead.com/fire-mage-talents
	------------------------------------------------------------------------
		AddFlags(11113,13018,13019,13020,13021, IsMage + IsSnare) 						-- Blast Wave (Rank 1-5)(Talent)
		AddFlags(28682, IsMage) 														-- Combustion (Talent)(Boost)
		AddFlags(133,143,145,3140,8400,8401,8402,10148,10149,10150,10151,25306, IsMage) -- Fireball (Rank 1-12)
		AddFlags(543,8457,8458,10223,10225, IsMage) 									-- Fire Ward (Rank 1-5)
		AddFlags(2120,2121,8422,8423,10215,10216, IsMage) 								-- Flamestrike (Rank 1-6)
		AddFlags(12654, IsMage) 														-- Ignite Burn CHECK!
		AddFlags(12355, IsMage + IsStun) 												-- Impact (Proc)(Talent)
		AddFlags(11366,12505,12522,12523,12524,12525,12526,18809, IsMage) 				-- Pyroblast (Rank 1-8)(Talent)

	-- Mage (Frost)
	-- https://classic.wowhead.com/mage-abilities/frost
	-- https://classic.wowhead.com/frost-mage-talents
	------------------------------------------------------------------------
		AddFlags(10,6141,8427,10185,10186,10187, IsMage) 									-- Blizzard (Rank 1-6)
		AddFlags(7321, IsMage + IsSnare) 													-- Chilled (Ice Armor Proc)
		AddFlags(6136,12484,12485,12486, IsMage + IsSnare) 									-- Chilled (Proc)
		AddFlags(12531, IsMage + IsSnare) 													-- Chilling Touch (Proc)
		AddFlags(120,8492,10159,10160,10161, IsMage + IsSnare) 								-- Cone of Cold (Rank 1-5)
		AddFlags(116,205,837,7322,8406,8407,8408,10179,10180,10181,25304, IsMage + IsSnare) -- Frostbolt (Rank 1-11)
		AddFlags(168,7300,7301, IsMage) 													-- Frost Armor (Rank 1-3)
		AddFlags(122,865,6131,10230, IsMage + IsRoot) 										-- Frost Nova (Rank 1-4)
		AddFlags(6143,8461,8462,10177,28609, IsMage) 										-- Frost Ward (Rank 1-5)(Defensive)
		AddFlags(7302,7320,10219,10220, IsMage) 											-- Ice Armor (Rank 1-4)
		AddFlags(11426,13031,13032,13033, IsMage) 											-- Ice Barrier (Rank 1-4)(Defensive)
		AddFlags(11958, IsMage + IsImmune) 													-- Ice Block (Talent)(Defensive)
		AddFlags(12579, IsMage) 															-- Winter's Chill (Proc)(Talent)(Boost)

	-- Warrior (Arms)
	-- https://classic.wowhead.com/warrior-abilities/arms
	-- https://classic.wowhead.com/arms-warrior-talents
	------------------------------------------------------------------------
		AddFlags(2457, IsWarrior) 										-- Battle Stance (Shapeshift) CHECK!
		AddFlags(7922, IsWarrior + IsStun) 								-- Charge Stun
		AddFlags(12162,1285012868, IsWarrior) 							-- Deep Wounds Bleed (Rank 1-3) CHECK!
		AddFlags(1715,7372,7373, IsWarrior + IsSnare) 					-- Hamstring (Rank 1-3)
		AddFlags(694,7400,7402,20559,20560, IsWarrior + IsTaunt) 		-- Mocking Blow (Rank 1-5)(Taunt)
		AddFlags(12294,21551,21552,21553, IsWarrior) 					-- Mortal Strike (Rank 1-4)(Talent)
		AddFlags(772,6546,6547,6548,11572,11573,11574, IsWarrior) 		-- Rend (Rank 1-7)
		AddFlags(20230, IsWarrior) 										-- Retaliation (Boost)
		AddFlags(12292, IsWarrior) 										-- Sweeping Strikes (Talent)
		AddFlags(6343,8198,8204,8205,11580,11581, IsWarrior) 			-- Thunder Clap (Rank 1-6)

	-- Warrior (Fury)
	-- https://classic.wowhead.com/warrior-abilities/fury
	-- https://classic.wowhead.com/fury-warrior-talents
	------------------------------------------------------------------------
		AddFlags(6673,5242,6192,11549,11550,11551,25289, IsWarrior) 	-- Battle Shout (Rank 1-7)
		AddFlags(18499, IsWarrior + IsImmuneCC) 						-- Berserker Rage (Boost)
		AddFlags(2458, IsWarrior) 										-- Berserker Stance (Shapeshift)
		AddFlags(16488,16490,16491, IsWarrior) 							-- Blood Craze (Rank 1-3)(Talent)
		AddFlags(1161, IsWarrior) 										-- Challenging Shout (Taunt)
		AddFlags(12328, IsWarrior + IsImmuneCC) 						-- Death Wish (Boost)(Talent)
		AddFlags(1160,6190,11554,11555,11556, IsWarrior) 				-- Demoralizing Shout (Rank 1-5)
		AddFlags(12880,14201,14202,14203,14204, IsWarrior) 				-- Enrage (Rank 1-5)
		AddFlags(12966,12967,12968,12969,12970, IsWarrior) 				-- Flurry (Rank 1-5)(Talent)
		AddFlags(20253,20614,20615, IsWarrior + IsStun) 				-- Intercept Stun (Rank 1-3)
		AddFlags(5246, IsWarrior + IsStun) 								-- Intimidating Shout
		AddFlags(12323, IsWarrior + IsSnare) 							-- Piercing Howl (Talent)
		AddFlags(1719, IsWarrior + IsImmuneCC) 							-- Recklessness (Boost)

	-- Warrior (Protection)
	-- https://classic.wowhead.com/warrior-abilities/protection
	-- https://classic.wowhead.com/protection-warrior-talents
	------------------------------------------------------------------------
		AddFlags(29131, IsWarrior) 										-- Bloodrage
		AddFlags(12809, IsWarrior + IsStun) 							-- Concussion Blow (Talent)
		AddFlags(71, IsWarrior) 										-- Defensive Stance (Shapeshift)
		AddFlags(676, IsWarrior) 										-- Disarm
		AddFlags(2565, IsWarrior) 										-- Shield Block
		AddFlags(871, IsWarrior) 										-- Shield Wall (Defensive)
		AddFlags(7386,7405,8380,11596,11597, IsWarrior) 				-- Sunder Armor (Rank 1-5)


	-- Rogue (Assassination)
	-- https://classic.wowhead.com/rogue-abilities/assassination
	-- https://classic.wowhead.com/assassination-rogue-talents
	------------------------------------------------------------------------

	-- Rogue (Combat)
	-- https://classic.wowhead.com/rogue-abilities/combat
	------------------------------------------------------------------------

	-- Rogue (Subtlety)
	-- https://classic.wowhead.com/rogue-abilities/subtlety
	------------------------------------------------------------------------

	-- Rogue (Poisons)
	-- https://classic.wowhead.com/rogue-abilities/poisons
	-- https://classic.wowhead.com/search?q=poison+proc
	------------------------------------------------------------------------
		--AddFlags(28428, IsRogue) 					-- Instant Poison CHECK!



	-- Blackwing Lair
	------------------------------------------------------------------------
		-- Nefarian
		AddFlags(23402, IsBoss) -- Corrupted Healing

end

-- Retail Aura Info Lists!
if (IsRetail) then

	-- Death Knight (Blood)
	-- https://www.wowhead.com/mage-abilities/live-only:on
	------------------------------------------------------------------------
		AddFlags(188290, IsDeathKnight) 			-- Death and Decay (Buff)

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


	-- Mythic+ Dungeons
	------------------------------------------------------------------------
		-- General Affix
		AddFlags(240443, IsBoss) -- Bursting
		AddFlags(240559, IsBoss) -- Grievous
		AddFlags(196376, IsBoss) -- Grievous Tear
		AddFlags(209858, IsBoss) -- Necrotic
		AddFlags(226512, IsBoss) -- Sanguine
		-- 8.3 BFA Affix
		AddFlags(314478, IsBoss) -- Cascading Terror
		AddFlags(314483, IsBoss) -- Cascading Terror
		AddFlags(314406, IsBoss) -- Crippling Pestilence
		AddFlags(314565, IsBoss) -- Defiled Ground
		AddFlags(314411, IsBoss) -- Lingering Doubt
		AddFlags(314592, IsBoss) -- Mind Flay
		AddFlags(314308, IsBoss) -- Spirit Breaker
		AddFlags(314531, IsBoss) -- Tear Flesh
		AddFlags(314392, IsBoss) -- Vile Corruption
		-- 9.x Shadowlands Affix
		AddFlags(342494, IsBoss) -- Belligerent Boast (Prideful)
	
	------------------------------------------------------------------------
	-- Battle for Azeroth Dungeons
	-- *some auras might be under the wrong dungeon, 
	--  this is because wowhead doesn't always tell what casts this.
	------------------------------------------------------------------------
	-- BFA: Atal'Dazar
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

	-- BFA: Freehold
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

	-- BFA: King's Rest
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

	-- BFA: Motherlode
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

	-- BFA: Operation Mechagon
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

	-- BFA: Shrine of the Storm
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

	-- BFA: Siege of Boralus
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

	-- BFA: Temple of Sethraliss
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

	-- BFA: Tol Dagor
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

	-- BFA: Underrot
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

	-- BFA: Waycrest Manor
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

	-- BFA: Uldir
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

	-- BFA: Siege of Zuldazar
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

	-- BFA: Crucible of Storms
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

	-- BFA: Eternal Palace
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

	-- BFA: Nyalotha
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

	------------------------------------------------------------------------
	-- Shadowlands Dungeons
	-- *some auras might be under the wrong dungeon, 
	--  this is because wowhead doesn't always tell what casts this.
	------------------------------------------------------------------------
	-- SL: Halls of Atonement
	------------------------------------------------------------------------
		AddFlags(326891, IsBoss)	-- Anguish
		AddFlags(326874, IsBoss)	-- Ankle Bites
		AddFlags(325876, IsBoss)	-- Curse of Obliteration
		AddFlags(319603, IsBoss)	-- Curse of Stone
		AddFlags(323650, IsBoss)	-- Haunting Fixation
		AddFlags(329321, IsBoss)	-- Jagged Swipe 1
		AddFlags(344993, IsBoss)	-- Jagged Swipe 2
		AddFlags(340446, IsBoss)	-- Mark of Envy
		AddFlags(335338, IsBoss)	-- Ritual of Woe
		AddFlags(326632, IsBoss)	-- Stony Veins
		AddFlags(319611, IsBoss)	-- Turned to Stone

	-- SL: Mists of Tirna Scithe
	------------------------------------------------------------------------
		AddFlags(325224, IsBoss)	-- Anima Injection
		AddFlags(323043, IsBoss)	-- Bloodletting
		AddFlags(325027, IsBoss)	-- Bramble Burst
		AddFlags(326092, IsBoss)	-- Debilitating Poison
		AddFlags(321891, IsBoss)	-- Freeze Tag Fixation
		AddFlags(322563, IsBoss)	-- Marked Prey
		AddFlags(331172, IsBoss)	-- Mind Link
		AddFlags(325021, IsBoss)	-- Mistveil Tear
		AddFlags(322487, IsBoss)	-- Overgrowth 1
		AddFlags(322486, IsBoss)	-- Overgrowth 2
		AddFlags(328756, IsBoss)	-- Repulsive Visage
		AddFlags(322557, IsBoss)	-- Soul Split
		AddFlags(325418, IsBoss)	-- Volatile Acid

	-- SL: Plaguefall
	------------------------------------------------------------------------
		AddFlags(333406, IsBoss)	-- Assassinate
		AddFlags(322358, IsBoss)	-- Burning Strain
		AddFlags(330069, IsBoss)	-- Concentrated Plague
		AddFlags(320512, IsBoss)	-- Corroded Claws
		AddFlags(325552, IsBoss)	-- Cytotoxic Slash
		AddFlags(328180, IsBoss)	-- Gripping Infection
		AddFlags(340355, IsBoss)	-- Rapid Infection
		AddFlags(331818, IsBoss)	-- Shadow Ambush
		AddFlags(332397, IsBoss)	-- Shroudweb
		AddFlags(329110, IsBoss)	-- Slime Injection
		AddFlags(336258, IsBoss)	-- Solitary Prey
		AddFlags(328395, IsBoss)	-- Venompiercer
		AddFlags(320542, IsBoss)	-- Wasting Blight
		AddFlags(336301, IsBoss)	-- Web Wrap
		AddFlags(322410, IsBoss)	-- Withering Filth

	-- SL: The Necrotic Wake
	------------------------------------------------------------------------
		AddFlags(320717, IsBoss)	-- Blood Hunger
		AddFlags(324381, IsBoss)	-- Chill Scythe
		AddFlags(323365, IsBoss)	-- Clinging Darkness
		AddFlags(323198, IsBoss)	-- Dark Exile
		AddFlags(343504, IsBoss)	-- Dark Grasp
		AddFlags(323464, IsBoss)	-- Dark Ichor
		AddFlags(321821, IsBoss)	-- Disgusting Guts
		AddFlags(333485, IsBoss)	-- Disease Cloud
		AddFlags(334748, IsBoss)	-- Drain FLuids
		AddFlags(328181, IsBoss)	-- Frigid Cold
		AddFlags(338353, IsBoss)	-- Goresplatter
		AddFlags(343556, IsBoss)	-- Morbid Fixation 1
		AddFlags(338606, IsBoss)	-- Morbid Fixation 2
		AddFlags(320170, IsBoss)	-- Necrotic Bolt
		AddFlags(333489, IsBoss)	-- Necrotic Breath
		AddFlags(333492, IsBoss)	-- Necrotic Ichor
		AddFlags(320573, IsBoss)	-- Shadow Well
		AddFlags(338357, IsBoss)	-- Tenderize

	-- SL: Theater of Pain
	------------------------------------------------------------------------
		AddFlags(342675, IsBoss)	-- Bone Spear
		AddFlags(333299, IsBoss)	-- Curse of Desolation 1
		AddFlags(333301, IsBoss)	-- Curse of Desolation 2
		AddFlags(323831, IsBoss)	-- Death Grasp
		AddFlags(330700, IsBoss)	-- Decaying Blight
		AddFlags(326892, IsBoss)	-- Fixate
		AddFlags(323825, IsBoss)	-- Grasping Rift
		AddFlags(323406, IsBoss)	-- Jagged Gash
		AddFlags(324449, IsBoss)	-- Manifest Death
		AddFlags(330868, IsBoss)	-- Necrotic Bolt Volley
		AddFlags(321768, IsBoss)	-- On the Hook
		AddFlags(319626, IsBoss)	-- Phantasmal Parasite
		AddFlags(319539, IsBoss)	-- Soulless
		AddFlags(330608, IsBoss)	-- Vile Eruption
		AddFlags(323750, IsBoss)	-- Vile Gas
		AddFlags(341949, IsBoss)	-- Withering Blight

	-- SL: Sanguine Depths
	------------------------------------------------------------------------
		AddFlags(328593, IsBoss)	-- Agonize
		AddFlags(335306, IsBoss)	-- Barbed Shackles
		AddFlags(321038, IsBoss)	-- Burden Soul
		AddFlags(322554, IsBoss)	-- Castigate
		AddFlags(326836, IsBoss)	-- Curse of Suppression
		AddFlags(326827, IsBoss)	-- Dread Bindings
		AddFlags(334653, IsBoss)	-- Engorge
		AddFlags(325254, IsBoss)	-- Iron Spikes
		AddFlags(322429, IsBoss)	-- Severing Slice

	-- SL: Spires of Ascension
	------------------------------------------------------------------------
		AddFlags(323792, IsBoss)	-- Anima Field
		AddFlags(324205, IsBoss)	-- Blinding Flash
		AddFlags(338729, IsBoss)	-- Charged Stomp
		AddFlags(327481, IsBoss)	-- Dark Lance
		AddFlags(331251, IsBoss)	-- Deep Connection
		AddFlags(328331, IsBoss)	-- Forced Confession
		AddFlags(317661, IsBoss)	-- Insidious Venom
		AddFlags(328434, IsBoss)	-- Intimidated
		AddFlags(322817, IsBoss)	-- Lingering Doubt
		AddFlags(322818, IsBoss)	-- Lost Confidence
		AddFlags(338747, IsBoss)	-- Purifying Blast
		AddFlags(330683, IsBoss)	-- Raw Anima
		AddFlags(341215, IsBoss)	-- Volatile Anima

	-- SL: De Other Side
	------------------------------------------------------------------------
		AddFlags(323687, IsBoss)	-- Arcane Lightning
		AddFlags(323692, IsBoss)	-- Arcane Vulnerability
		AddFlags(334535, IsBoss)	-- Beak Slice
		AddFlags(330434, IsBoss)	-- Buzz-Saw 1
		AddFlags(320144, IsBoss)	-- Buzz-Saw 2
		AddFlags(322746, IsBoss)	-- Corrupted Blood
		AddFlags(325725, IsBoss)	-- Cosmic Artifice
		AddFlags(327649, IsBoss)	-- Crushed Soul
		AddFlags(323877, IsBoss)	-- Echo Finger Laser X-treme
		AddFlags(332678, IsBoss)	-- Gushing Wound
		AddFlags(331379, IsBoss)	-- Lubricate
		AddFlags(334913, IsBoss)	-- Master of Death
		AddFlags(339978, IsBoss)	-- Pacifying Mists
		AddFlags(320786, IsBoss)	-- Power Overwhelming
		AddFlags(333250, IsBoss)	-- Reaver
		AddFlags(334496, IsBoss)	-- Soporific Shimmerdust
		AddFlags(331847, IsBoss)	-- W-00F
		AddFlags(328987, IsBoss)	-- Zealous

	-- SL: Castle Nathria
	------------------------------------------------------------------------
		-- Shriekwing
		AddFlags(329370, IsBoss)	-- Deadly Descent
		AddFlags(336494, IsBoss)	-- Echo Screech
		AddFlags(328897, IsBoss)	-- Exsanguinated
		AddFlags(330713, IsBoss)	-- Reverberating Pain
		-- Huntsman Altimor
		AddFlags(334945, IsBoss)	-- Bloody Thrash
		AddFlags(334860, IsBoss)	-- Crushing Stone (Hecutis)
		AddFlags(335111, IsBoss)	-- Huntsman's Mark 1
		AddFlags(335112, IsBoss)	-- Huntsman's Mark 2
		AddFlags(335113, IsBoss)	-- Huntsman's Mark 3
		AddFlags(334971, IsBoss)	-- Jagged Claws
		AddFlags(335304, IsBoss)	-- Sinseeker
		-- Hungering Destroyer
		AddFlags(329298, IsBoss)	-- Gluttonous Miasma
		AddFlags(334228, IsBoss)	-- Volatile Ejection
		-- Lady Inerva Darkvein
		AddFlags(332664, IsBoss)	-- Concentrate Anima
		AddFlags(335396, IsBoss)	-- Hidden Desire
		AddFlags(325936, IsBoss)	-- Shared Cognition
		AddFlags(324983, IsBoss)	-- Shared Suffering
		AddFlags(324982, IsBoss)	-- Shared Suffering (Partner)
		AddFlags(325382, IsBoss)	-- Warped Desires
		-- Sun King's Salvation
		AddFlags(326078, IsBoss)	-- Infuser's Boon
		AddFlags(325251, IsBoss)	-- Sin of Pride
		AddFlags(333002, IsBoss)	-- Vulgar Brand
		-- Artificer Xy'mox
		AddFlags(327902, IsBoss)	-- Fixate
		AddFlags(325236, IsBoss)	-- Glyph of Destruction
		AddFlags(327414, IsBoss)	-- Possession
		AddFlags(326302, IsBoss)	-- Stasis Trap
		-- The Council of Blood
		AddFlags(331636, IsBoss)	-- Dark Recital 1
		AddFlags(331637, IsBoss)	-- Dark Recital 2
		AddFlags(327052, IsBoss)	-- Drain Essence 1
		AddFlags(327773, IsBoss)	-- Drain Essence 2
		AddFlags(346651, IsBoss)	-- Drain Essence Mythic
		AddFlags(331706, IsBoss)	-- Scarlet Letter
		AddFlags(328334, IsBoss)	-- Tactical Advance
		AddFlags(330848, IsBoss)	-- Wrong Moves
		-- Sludgefist
		AddFlags(335293, IsBoss)	-- Chain Link
		AddFlags(335270, IsBoss)	-- Chain This One!
		AddFlags(335470, IsBoss)	-- Chain Slam
		AddFlags(339181, IsBoss)	-- Chain Slam (Root)
		AddFlags(331209, IsBoss)	-- Hateful Gaze
		AddFlags(335295, IsBoss)	-- Shattering Chain
		-- Stone Legion Generals
		AddFlags(339690, IsBoss)	-- Crystalize
		AddFlags(334541, IsBoss)	-- Curse of Petrification
		AddFlags(334765, IsBoss)	-- Heart Rend
		AddFlags(334616, IsBoss)	-- Petrified
		AddFlags(334498, IsBoss)	-- Seismic Upheaval
		AddFlags(337643, IsBoss)	-- Unstable Footing
		AddFlags(342655, IsBoss)	-- Volatile Anima Infusion
		AddFlags(342698, IsBoss)	-- Volatile Anima Infection
		AddFlags(333377, IsBoss)	-- Wicked Mark
		-- Sire Denathrius
		AddFlags(326851, IsBoss)	-- Blood Price
		AddFlags(326699, IsBoss)	-- Burden of Sin
		AddFlags(327992, IsBoss)	-- Desolation
		AddFlags(329951, IsBoss)	-- Impale
		AddFlags(328276, IsBoss)	-- March of the Penitent
		AddFlags(327796, IsBoss)	-- Night Hunter
		AddFlags(335873, IsBoss)	-- Rancor
		AddFlags(329181, IsBoss)	-- Wracking Pain

end


-- Aura User Flags
-- These affect when and how we want to show something, 
-- and are all about personal preference. 
-- This is where we add blacklists and whitelists.
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
end

-- WoW Retail (Battle for Azeroth)
if (IsRetail) then

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

	-- Warlock
	-----------------------------------------------------------------
	do
		AddUserFlags(146739, ByPlayer) 						-- Corruption
		AddUserFlags(317031, ByPlayer) 						-- Corruption (Instant)
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

		-- Mage Azerite Traits
		------------------------------------------------------------------------
		AddUserFlags(280177, ByPlayer) 						-- Cauterizing Blink
		

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
		AddUserFlags(309806, OnPlayer) 						-- Gormlings Lured (Ardenweald World Quest)
		AddUserFlags(188030, ByPlayer) 						-- Leytorrent Potion (channeled) (Legion Consumables)
		AddUserFlags(295858, OnPlayer) 						-- Molted Shell (constantly moving mount Nazjatar)
		AddUserFlags(188027, ByPlayer) 						-- Potion of Deadly Grace (Legion Consumables)
		AddUserFlags(188028, ByPlayer) 						-- Potion of the Old War (Legion Consumables)
		AddUserFlags(188029, ByPlayer) 						-- Unbending Potion (Legion Consumables)
		AddUserFlags(127372, OnPlayer) 						-- Unstable Serum (Klaxxi Enhancement: Raining Blood)
		AddUserFlags(240640, OnPlayer) 						-- The Shadow of the Sentinax (Mark of the Sentinax)
		AddUserFlags(254873, OnPlayer) 						-- Irontide Recruit (Tiragarde Sound Storyline)
		AddUserFlags(312394, OnPlayer) 						-- Shackled Soul (Battered and Bruised World Quest Revendreth)


		-- Heroism
		------------------------------------------------------------------------
		AddUserFlags( 90355, OnPlayer + PrioHigh) 			-- Ancient Hysteria
		AddUserFlags(  2825, OnPlayer + PrioHigh) 			-- Bloodlust
		AddUserFlags( 32182, OnPlayer + PrioHigh) 			-- Heroism
		AddUserFlags(160452, OnPlayer + PrioHigh) 			-- Netherwinds
		AddUserFlags(264667, OnPlayer + PrioHigh) 			-- Primal Rage (Hunter Pet Ferocity Ability)
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

		-- Fucking Costumes (Hallow's End)
		------------------------------------------------------------------------
		AddUserFlags(172010, OnPlayer) 						-- Abomination Costume
		AddUserFlags(218132, OnPlayer) 						-- Banshee Costume
		AddUserFlags( 24732, OnPlayer) 						-- Bat Costume
		AddUserFlags(191703, OnPlayer) 						-- Bat Costume
		AddUserFlags(285521, OnPlayer) 						-- Blue Dragon Body Costume
		AddUserFlags(285519, OnPlayer) 						-- Blue Dragon Head Costume
		AddUserFlags(285523, OnPlayer) 						-- Blue Dragon Tail Costume
		AddUserFlags( 97135, OnPlayer) 						-- Children's Costume Aura
		AddUserFlags(257204, OnPlayer) 						-- Dirty Horse Costume
		AddUserFlags(257205, OnPlayer) 						-- Dirty Horse Costume
		AddUserFlags(191194, OnPlayer) 						-- Exquisite Deathwing Costume
		AddUserFlags(192472, OnPlayer) 						-- Exquisite Deathwing Costume
		AddUserFlags(217917, OnPlayer) 						-- Exquisite Grommash Costume
		AddUserFlags(171958, OnPlayer) 						-- Exquisite Lich King Costume
		AddUserFlags(190837, OnPlayer) 						-- Exquisite VanCleef Costume
		AddUserFlags(246237, OnPlayer) 						-- Exquisite Xavius Costume
		AddUserFlags(191210, OnPlayer) 						-- Gargoyle Costume
		AddUserFlags(172015, OnPlayer) 						-- Geist Costume
		AddUserFlags( 24735, OnPlayer) 						-- Ghost Costume
		AddUserFlags( 24736, OnPlayer) 						-- Ghost Costume
		AddUserFlags(191700, OnPlayer) 						-- Ghost Costume
		AddUserFlags(191698, OnPlayer) 						-- Ghost Costume
		AddUserFlags(172008, OnPlayer) 						-- Ghoul Costume
		AddUserFlags(285522, OnPlayer) 						-- Green Dragon Body Costume
		AddUserFlags(285520, OnPlayer) 						-- Green Dragon Head Costume
		AddUserFlags(285524, OnPlayer) 						-- Green Dragon Tail Costume
		AddUserFlags(246242, OnPlayer) 						-- Horse Head Costume
		AddUserFlags(246241, OnPlayer) 						-- Horse Tail Costume
		AddUserFlags( 44212, OnPlayer) 						-- Jack-o'-Lanterned!
		AddUserFlags(177656, OnPlayer) 						-- Kor'kron Foot Soldier Costume
		AddUserFlags(177657, OnPlayer) 						-- Kor'kron Foot Soldier Costume
		AddUserFlags( 24712, OnPlayer) 						-- Leper Gnome Costume
		AddUserFlags( 24713, OnPlayer) 						-- Leper Gnome Costume
		AddUserFlags(191701, OnPlayer) 						-- Leper Gnome Costume
		AddUserFlags(171479, OnPlayer) 						-- "Lil' Starlet" Costume
		AddUserFlags(171470, OnPlayer) 						-- "Mad Alchemist" Costume
		AddUserFlags(191211, OnPlayer) 						-- Nerubian Costume
		AddUserFlags( 24710, OnPlayer) 						-- Ninja Costume
		AddUserFlags( 24711, OnPlayer) 						-- Ninja Costume
		AddUserFlags(191686, OnPlayer) 						-- Ninja Costume
		AddUserFlags( 24708, OnPlayer) 						-- Pirate Costume
		AddUserFlags(173958, OnPlayer) 						-- Pirate Costume
		AddUserFlags(173959, OnPlayer) 						-- Pirate Costume
		AddUserFlags(191682, OnPlayer) 						-- Pirate Costume
		AddUserFlags(191683, OnPlayer) 						-- Pirate Costume
		AddUserFlags( 61716, OnPlayer) 						-- Rabbit Costume
		AddUserFlags(233598, OnPlayer) 						-- Red Dragon Body Costume
		AddUserFlags(233594, OnPlayer) 						-- Red Dragon Head Costume
		AddUserFlags(233599, OnPlayer) 						-- Red Dragon Tail Costume
		AddUserFlags( 30167, OnPlayer) 						-- Red Ogre Costume
		AddUserFlags(102362, OnPlayer) 						-- Red Ogre Mage Costume
		AddUserFlags( 24723, OnPlayer) 						-- Skeleton Costume
		AddUserFlags(191702, OnPlayer) 						-- Skeleton Costume
		AddUserFlags(172003, OnPlayer) 						-- Slime Costume
		AddUserFlags(172020, OnPlayer) 						-- Spider Costume
		AddUserFlags( 99976, OnPlayer) 						-- Squashling Costume
		AddUserFlags(243321, OnPlayer) 						-- Tranquil Mechanical Yeti Costume
		AddUserFlags(178306, OnPlayer) 						-- Warsong Orc Costume
		AddUserFlags(178307, OnPlayer) 						-- Warsong Orc Costume
		AddUserFlags(191208, OnPlayer) 						-- Wight Costume
		AddUserFlags( 24740, OnPlayer) 						-- Wisp Costume
		AddUserFlags(279509, OnPlayer) 						-- Witch!
		AddUserFlags(171930, OnPlayer) 						-- "Yipp-Saron" Costume
		
	end

end
