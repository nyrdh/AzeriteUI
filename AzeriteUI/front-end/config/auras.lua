local ADDON, Private = ...

local LibAuraData = Wheel("LibAuraData")
assert(LibAuraData, ADDON.." requires LibAuraData to be loaded.")

-- Lua API
local select = select
local string_match = string.match
local table_remove = table.remove
local type = type
local unpack = unpack

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
local IsTBC = Private.IsTBC
local IsRetail = Private.IsRetail

-- Library Databases
local BitFilters = LibAuraData:GetAllAuraInfoBitFilters() -- Aura bit filters
local InfoFlags = LibAuraData:GetAllAuraInfoFlags() -- Aura info flags
local UserFlags = {} -- populated and created farther down

-- Forcing this for classes still lacking strict filter lists,
-- or we'd end up with nothing being shown at all.
local playerClass = select(2, UnitClass("player"))
local SLACKMODE = true

if (IsClassic) then
	if (playerClass == "DRUID") 
	or (playerClass == "HUNTER") 
	or (playerClass == "MAGE")
	or (playerClass == "WARRIOR") then 
		SLACKMODE = true
	end
elseif (IsTBC) then
elseif (IsRetail) then
	if (playerClass == "DRUID") 
	or (playerClass == "MAGE")
	or (playerClass == "WARRIOR") then 
		SLACKMODE = true
	end
end


 -- Speed APIs
-----------------------------------------------------------------
local HasAuraUserFlags = LibAuraData.HasAuraUserFlags
local HasAuraInfoFlags = LibAuraData.HasAuraInfoFlags

-- Add info flags to aura list
local DefineAura = function(...) 
	LibAuraData:AddAuraInfoFlags(...)
end

-- Add user flags to aura list
local SetFilter = function(...) 
	LibAuraData.AddAuraUserFlags(Private, ...) 
	if (not UserFlags) then
		-- Used by filters later on, 
		-- defined by the back-end after the previous call.
		UserFlags = LibAuraData.GetAllAuraUserFlags(Private)
	end
end

-- Aura Info Bigflags
-- These are factual flags about auras, 
-- like what class cast it, what type of aura it is, etc.
-- Nothing here is about choice, it's all facts.
-----------------------------------------------------------------
-- Notice that they all start with the prefix 'Is'. 
-- This is intended to make them easy to tell apart from the user flags.
-----------------------------------------------------------------
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

-- Aura User Bitflags
-- These are front-end filters and describe display preference,
-- they are unrelated to the factual, purely descriptive back-end filters.
-----------------------------------------------------------------
-- * Please do not ever make a user flag prefixed with 'Is',
--   as that would only cause unneeded confusion, chaos and death.
-----------------------------------------------------------------
local ByPlayer 			= 2^0 -- Show when cast by player
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
local NeverOnPlate 		= 2^14 -- Never show on plates (Blacklist)
local Never 			= 2^15 -- Never show (Blacklist)
local Always 			= 2^16 -- Always show (Whitelist)
local NoCombat 			= 2^17 -- Never show in combat 
local Warn 				= 2^18 -- Show when there is 30 secs left or less, even in combat!
local PlayerIsDPS 		= 2^11 -- Show when player is a damager *NOT CURRENTLY IMPLEMENTED!
local PlayerIsHealer 	= 2^12 -- Show when player is a healer *NOT CURRENTLY IMPLEMENTED!
local PlayerIsTank 		= 2^13 -- Show when player is a tank  *NOT CURRENTLY IMPLEMENTED!
local PrioLow 			= 2^19 -- Low priority, will only be displayed if room *NOT CURRENTLY IMPLEMENTED!
local PrioMedium 		= 2^20 -- Normal priority, same as not setting any *NOT CURRENTLY IMPLEMENTED!
local PrioHigh 			= 2^21 -- High priority, shown first after boss *NOT CURRENTLY IMPLEMENTED!
local PrioBoss 			= 2^22 -- Same priority as boss debuffs *NOT CURRENTLY IMPLEMENTED!

-- Shorthand tags for quality of life, following the guidelines above.
-- Note: Do NOT add any of these together, they must be used as the ONLY tag when used!
local GroupBuff 		= OnPlayer + NoCombat + Warn 	-- Group buffs like MotW, Fortitude
local PlayerBuff 		= ByPlayer + NoCombat + Warn 	-- Self-cast only buffs, like Omen of Clarity
local Harmful 			= OnPlayer + OnEnemy 			-- CC and other non-damaging harmful effects
local Damage 			= ByPlayer + OnPlayer 			-- DoTs
local Healing 			= ByPlayer + OnEnemy 			-- HoTs
local Shielding 		= OnPlayer + OnEnemy 			-- Shields
local Boost 			= ByPlayer + OnEnemy 			-- Damage- and defensive cooldowns

-- Some constants to avoid a million auraIDs
local L_DRINK 			= GetSpellInfo(430) -- 104270
local L_FOOD 			= GetSpellInfo(433) -- 104935
local L_FOOD_N_DRINK 	= GetSpellInfo(257425)

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

-- Classic Aura Lists!
-----------------------------------------------------------------
if (IsClassic) then

	-- Druid (Balance)
	-- https://classic.wowhead.com/druid-abilities/balance
	-- https://classic.wowhead.com/balance-druid-talents
	------------------------------------------------------------------------
		DefineAura(22812, IsDruid) 													-- Barkskin
		DefineAura(339,1062,5195,5196,9852,9853, IsDruid + IsRoot) 					-- Entangling Roots (Rank 1-6)
		DefineAura(770,778,9749,9907, IsDruid) 										-- Faerie Fire (Rank 1-4)
		DefineAura(2637,18657,18658, IsDruid + IsIncap) 							-- Hibernate (Rank 1-3)
		DefineAura(16914,17401,17402, IsDruid) 										-- Hurricane (Rank 1-3)
		DefineAura(8921,8924,8925,8926,8927,8928,8929,9833,9834,9835, IsDruid) 		-- Moonfire (Rank 1-10)
		DefineAura(24907, IsDruid) 													-- Moonkin Aura
		DefineAura(24858, IsDruid) 													-- Moonkin Form (Shapeshift)(Talent)
		DefineAura(16689,16810,16811,16812,16813,17329, IsDruid + IsRoot) 			-- Nature's Grasp (Rank 1-6)(Talent)
		DefineAura(16864, IsDruid) 													-- Omen of Clarity (Buff)(Talent)
		DefineAura(16870, IsDruid) 													-- Omen of Clarity (Proc)(Talent)
		DefineAura(2908,8955,9901, IsDruid) 										-- Soothe Animal (Rank 1-3)
		DefineAura(467,782,1075,8914,9756,9910, IsDruid) 							-- Thorns (Rank 1-6)

		SetFilter(22812, ByPlayer)  												-- Barkskin
		SetFilter(339,1062,5195,5196,9852,9853, Harmful)							-- Entangling Roots (Rank 1-6)
		SetFilter(770,778,9749,9907, Harmful)  										-- Faerie Fire (Rank 1-4)
		SetFilter(2637,18657,18658, Harmful)										-- Hibernate (Rank 1-3)
		SetFilter(8921,8924,8925,8926,8927,8928,8929,9833,9834,9835, Damage) 		-- Moonfire (Rank 1-10)
		SetFilter(24907, Never + NeverOnPlate) 										-- Moonkin Aura
		SetFilter(24858, Never) 													-- Moonkin Form (Shapeshift)(Talent)
		SetFilter(16689,16810,16811,16812,16813,17329, Harmful) 					-- Nature's Grasp (Rank 1-6)(Talent)
		SetFilter(16864, PlayerBuff) 												-- Omen of Clarity (Buff)(Talent)
		SetFilter(16870, PlayerBuff) 												-- Omen of Clarity (Proc)(Talent)
		SetFilter(2908,8955,9901, ByPlayer)											-- Soothe Animal (Rank 1-3)	
		SetFilter(467,782,1075,8914,9756,9910, GroupBuff + NeverOnPlate) 			-- Thorns (Rank 1-6)
	
	-- Druid (Feral)
	-- https://classic.wowhead.com/druid-abilities/feral-combat
	-- https://classic.wowhead.com/feral-combat-druid-talents
	------------------------------------------------------------------------
		DefineAura(1066, IsDruid) 							-- Aquatic Form (Shapeshift)
		DefineAura(5211,6798,8983, IsDruid + IsStun) 		-- Bash (Rank 1-3)
		DefineAura(768, IsDruid) 							-- Cat Form (Shapeshift)
		DefineAura(5209, IsDruid + IsTaunt) 				-- Challenging Roar (Taunt)
		DefineAura(99,1735,9490,9747,9898, IsDruid) 		-- Demoralizing Roar (Rank 1-5)
		DefineAura(1850,9821, IsDruid) 						-- Dash (Rank 1-2)
		DefineAura(9634, IsDruid) 							-- Dire Bear Form (Shapeshift)
		DefineAura(5229, IsDruid) 							-- Enrage
		DefineAura(16857,17390,17391,17392, IsDruid) 		-- Faerie Fire (Feral) (Rank 1-4)(Talent)
		DefineAura(16979, IsDruid + IsRoot) 				-- Feral Charge Effect (Talent)
		DefineAura(22842,22895,22896, IsDruid) 				-- Frenzied Regeneration (Rank 1-3)
		DefineAura(6795, IsDruid + IsTaunt) 				-- Growl (Taunt)
		DefineAura(24932, IsDruid) 							-- Leader of the Pack(Talent)
		DefineAura(9005,9823,9827, IsDruid + IsStun) 		-- Pounce (Stun) (Rank 1-3)
		DefineAura(9007,9824,9826, IsDruid) 				-- Pounce Bleed (Rank 1-3)
		DefineAura(5215,6783,9913, IsDruid) 				-- Prowl (Rank 1-3)
		DefineAura(1822,1823,1824,9904, IsDruid) 			-- Rake (Rank 1-4)
		DefineAura(1079,9492,9493,9752,9894,9896, IsDruid) 	-- Rip (Rank 1-6)
		DefineAura(5217,6793,9845,9846, IsDruid) 			-- Tiger's Fury (Rank 1-4)
		DefineAura(783, IsDruid) 							-- Travel Form (Shapeshift)

		SetFilter(1066, Never) 								-- Aquatic Form (Shapeshift)
		SetFilter(5211,6798,8983, Harmful) 					-- Bash (Rank 1-3)
		SetFilter(768, Never)								-- Cat Form (Shapeshift)
		SetFilter(5209, OnEnemy) 							-- Challenging Roar (Taunt)
		SetFilter(99,1735,9490,9747,9898, ByPlayer)			-- Demoralizing Roar (Rank 1-5)
		SetFilter(1850,9821, Harmful)  						-- Dash (Rank 1-2)
		SetFilter(9634, Never) 								-- Dire Bear Form (Shapeshift)
		SetFilter(5229, ByPlayer) 							-- Enrage
		SetFilter(16857,17390,17391,17392, Damage) 			-- Faerie Fire (Feral) (Rank 1-4)(Talent)
		SetFilter(16979, Harmful) 							-- Feral Charge Effect (Talent)
		SetFilter(22842,22895,22896, ByPlayer) 				-- Frenzied Regeneration (Rank 1-3)
		SetFilter(6795, OnEnemy) 							-- Growl (Taunt)
		SetFilter(24932, Never + NeverOnPlate)				-- Leader of the Pack(Talent)
		SetFilter(9005,9823,9827, Harmful) 					-- Pounce (Stun) (Rank 1-3) 
		SetFilter(9007,9824,9826, Damage) 					-- Pounce Bleed (Rank 1-3)
		SetFilter(5215,6783,9913, Never) 					-- Prowl (Rank 1-3)
		SetFilter(1822,1823,1824,9904, Damage) 				-- Rake (Rank 1-4)
		SetFilter(1079,9492,9493,9752,9894,9896, Damage) 	-- Rip (Rank 1-6)
		SetFilter(5217,6793,9845,9846, ByPlayer) 			-- Tiger's Fury (Rank 1-4)
		SetFilter(783, Never)  								-- Travel Form (Shapeshift)

	-- Druid (Restoration)
	-- https://classic.wowhead.com/druid-abilities/restoration
	-- https://classic.wowhead.com/restoration-druid-talents
	------------------------------------------------------------------------
		DefineAura(2893, IsDruid) 														-- Abolish Poison
		DefineAura(21849,21850, IsDruid) 												-- Gift of the Wild (Rank 1-2)
		DefineAura(29166, IsDruid) 														-- Innervate
		DefineAura(5570,24974,24975,24976,24977, IsDruid) 								-- Insect Swarm (Rank 1-5)(Talent)
		DefineAura(1126,5232,6756,5234,8907,9884,9885, IsDruid) 						-- Mark of the Wild (Rank 1-7)
		DefineAura(17116, IsDruid) 														-- Nature's Swiftness (Clearcast,Instant)(Talent)
		DefineAura(8936,8938,8939,8940,8941,9750,9856,9857,9858, IsDruid) 				-- Regrowth (Rank 1-9)
		DefineAura(774,1058,1430,2090,2091,3627,8910,9839,9840,9841,25299, IsDruid) 	-- Rejuvenation (Rank 1-11)
		DefineAura(740,8918,9862,9863, IsDruid) 										-- Tranquility (Rank 1-4)

		SetFilter(2893, ByPlayer) 														-- Abolish Poison
		SetFilter(21849,21850, GroupBuff + NeverOnPlate) 								-- Gift of the Wild (Rank 1-2)
		SetFilter(29166, Boost) 														-- Innervate
		SetFilter(5570,24974,24975,24976,24977, Damage) 								-- Insect Swarm (Rank 1-5)(Talent)
		SetFilter(1126,5232,6756,5234,8907,9884,9885, GroupBuff + NeverOnPlate) 		-- Mark of the Wild (Rank 1-7)
		SetFilter(17116, Boost) 														-- Nature's Swiftness (Clearcast,Instant)(Talent)
		SetFilter(8936,8938,8939,8940,8941,9750,9856,9857,9858, Healing) 				-- Regrowth (Rank 1-9)
		SetFilter(774,1058,1430,2090,2091,3627,8910,9839,9840,9841,25299, Healing) 		-- Rejuvenation (Rank 1-11)
		SetFilter(740,8918,9862,9863, Healing) 											-- Tranquility (Rank 1-4)

	-- Mage (Arcane)
	-- https://classic.wowhead.com/mage-abilities/arcane
	-- https://classic.wowhead.com/arcane-mage-talents
	------------------------------------------------------------------------
		DefineAura(1008,8455,10169,10170, IsMage) 										-- Amplify Magic (Rank 1-4)
		DefineAura(23028, IsMage) 														-- Arcane Brilliance (Rank 1)
		DefineAura(1459,1460,1461,10156,10157, IsMage) 									-- Arcane Intellect (Rank 1-5)
		DefineAura(12042, IsMage) 														-- Arcane Power (Talent)(Boost)
		DefineAura(1953, IsMage) 														-- Blink
		DefineAura(12536, IsMage) 														-- Clearcasting (Proc)(Talent)
		DefineAura(604,8450,8451,10173,10174, IsMage) 									-- Dampen Magic (Rank 1-5)
		DefineAura(2855, IsMage) 														-- Detect Magic
		DefineAura(12051, IsMage) 														-- Evocation
		DefineAura(6117,22782,22783, IsMage) 											-- Mage Armor (Rank 1-3)
		DefineAura(1463,8494,8495,10191,10192,10193, IsMage) 							-- Mana Shield (Rank 1-6)
		DefineAura(118,12824,12825,12826, IsMage + IsIncap) 							-- Polymorph (Rank 1-4)
		DefineAura(28270,28272,28271, IsMage + IsIncap) 								-- Polymorph: Cow, Pig, Turtle
		DefineAura(12043, IsMage) 														-- Presence of Mind (Talent)(Clearcast,Instant)
		DefineAura(130, IsMage) 														-- Slow Fall

		SetFilter(1008,8455,10169,10170, GroupBuff) 									-- Amplify Magic (Rank 1-4)
		SetFilter(23028, GroupBuff + NeverOnPlate) 										-- Arcane Brilliance (Rank 1)
		SetFilter(1459,1460,1461,10156,10157, GroupBuff + NeverOnPlate) 				-- Arcane Intellect (Rank 1-5)
		SetFilter(12042, Boost) 														-- Arcane Power (Talent)(Boost)
		SetFilter(1953, ByPlayer) 														-- Blink
		SetFilter(12536, Boost) 														-- Clearcasting (Proc)(Talent)
		SetFilter(604,8450,8451,10173,10174, GroupBuff) 								-- Dampen Magic (Rank 1-5)
		SetFilter(2855, GroupBuff) 														-- Detect Magic
		SetFilter(12051, Boost) 														-- Evocation
		SetFilter(6117,22782,22783, GroupBuff) 											-- Mage Armor (Rank 1-3)
		SetFilter(1463,8494,8495,10191,10192,10193, GroupBuff) 							-- Mana Shield (Rank 1-6)
		SetFilter(118,12824,12825,12826, Harmful) 										-- Polymorph (Rank 1-4)
		SetFilter(28270,28272,28271, Harmful) 											-- Polymorph: Cow, Pig, Turtle
		SetFilter(12043, Boost) 														-- Presence of Mind (Talent)(Clearcast,Instant)
		SetFilter(130, Harmful) 														-- Slow Fall

	-- Mage (Fire)
	-- https://classic.wowhead.com/mage-abilities/fire
	-- https://classic.wowhead.com/fire-mage-talents
	------------------------------------------------------------------------
		DefineAura(11113,13018,13019,13020,13021, IsMage + IsSnare) 						-- Blast Wave (Rank 1-5)(Talent)
		DefineAura(28682, IsMage) 															-- Combustion (Talent)(Boost)
		DefineAura(133,143,145,3140,8400,8401,8402,10148,10149,10150,10151,25306, IsMage) 	-- Fireball (Rank 1-12)
		DefineAura(543,8457,8458,10223,10225, IsMage) 										-- Fire Ward (Rank 1-5)
		DefineAura(2120,2121,8422,8423,10215,10216, IsMage) 								-- Flamestrike (Rank 1-6)
		DefineAura(12654, IsMage) 															-- Ignite Burn CHECK!
		DefineAura(12355, IsMage + IsStun) 													-- Impact (Proc)(Talent)
		DefineAura(11366,12505,12522,12523,12524,12525,12526,18809, IsMage) 				-- Pyroblast (Rank 1-8)(Talent)

		SetFilter(11113,13018,13019,13020,13021, Harmful) 									-- Blast Wave (Rank 1-5)(Talent)
		SetFilter(28682, Boost) 															-- Combustion (Talent)(Boost)
		SetFilter(133,143,145,3140,8400,8401,8402,10148,10149,10150,10151,25306, Damage) 	-- Fireball (Rank 1-12)
		SetFilter(543,8457,8458,10223,10225, Damage) 										-- Fire Ward (Rank 1-5)
		SetFilter(2120,2121,8422,8423,10215,10216, Damage) 									-- Flamestrike (Rank 1-6)
		SetFilter(12654, Damage) 															-- Ignite Burn CHECK!
		SetFilter(12355, Harmful) 															-- Impact (Proc)(Talent)
		SetFilter(11366,12505,12522,12523,12524,12525,12526,18809, Damage) 					-- Pyroblast (Rank 1-8)(Talent)

	-- Mage (Frost)
	-- https://classic.wowhead.com/mage-abilities/frost
	-- https://classic.wowhead.com/frost-mage-talents
	------------------------------------------------------------------------
		DefineAura(10,6141,8427,10185,10186,10187, IsMage) 										-- Blizzard (Rank 1-6)
		DefineAura(7321, IsMage + IsSnare) 														-- Chilled (Ice Armor Proc)
		DefineAura(6136,12484,12485,12486, IsMage + IsSnare) 									-- Chilled (Proc)
		DefineAura(12531, IsMage + IsSnare) 													-- Chilling Touch (Proc)
		DefineAura(120,8492,10159,10160,10161, IsMage + IsSnare) 								-- Cone of Cold (Rank 1-5)
		DefineAura(116,205,837,7322,8406,8407,8408,10179,10180,10181,25304, IsMage + IsSnare) 	-- Frostbolt (Rank 1-11)
		DefineAura(168,7300,7301, IsMage) 														-- Frost Armor (Rank 1-3)
		DefineAura(122,865,6131,10230, IsMage + IsRoot) 										-- Frost Nova (Rank 1-4)
		DefineAura(6143,8461,8462,10177,28609, IsMage) 											-- Frost Ward (Rank 1-5)(Defensive)
		DefineAura(7302,7320,10219,10220, IsMage) 												-- Ice Armor (Rank 1-4)
		DefineAura(11426,13031,13032,13033, IsMage) 											-- Ice Barrier (Rank 1-4)(Defensive)
		DefineAura(11958, IsMage + IsImmune) 													-- Ice Block (Talent)(Defensive)
		DefineAura(12579, IsMage) 																-- Winter's Chill (Proc)(Talent)(Boost)

		SetFilter(10,6141,8427,10185,10186,10187, Damage) 										-- Blizzard (Rank 1-6)
		SetFilter(7321, Harmful) 																-- Chilled (Ice Armor Proc)
		SetFilter(6136,12484,12485,12486, Harmful) 												-- Chilled (Proc)
		SetFilter(12531, Harmful) 																-- Chilling Touch (Proc)
		SetFilter(120,8492,10159,10160,10161, Harmful) 											-- Cone of Cold (Rank 1-5)
		SetFilter(116,205,837,7322,8406,8407,8408,10179,10180,10181,25304, Harmful) 			-- Frostbolt (Rank 1-11)
		SetFilter(168,7300,7301, PlayerBuff) 													-- Frost Armor (Rank 1-3)
		SetFilter(122,865,6131,10230, Harmful) 													-- Frost Nova (Rank 1-4)
		SetFilter(6143,8461,8462,10177,28609, Boost) 											-- Frost Ward (Rank 1-5)(Defensive)
		SetFilter(7302,7320,10219,10220, PlayerBuff + NeverOnPlate) 							-- Ice Armor (Rank 1-4)
		SetFilter(11426,13031,13032,13033, Boost) 												-- Ice Barrier (Rank 1-4)(Defensive)
		SetFilter(11958, Boost) 																-- Ice Block (Talent)(Defensive)
		SetFilter(12579, Boost) 																-- Winter's Chill (Proc)(Talent)(Boost)

	-- Warrior (Arms)
	-- https://classic.wowhead.com/warrior-abilities/arms
	-- https://classic.wowhead.com/arms-warrior-talents
	------------------------------------------------------------------------
		DefineAura(2457, IsWarrior) 										-- Battle Stance (Shapeshift) CHECK!
		DefineAura(7922, IsWarrior + IsStun) 								-- Charge Stun
		DefineAura(12162,1285012868, IsWarrior) 							-- Deep Wounds Bleed (Rank 1-3) CHECK!
		DefineAura(1715,7372,7373, IsWarrior + IsSnare) 					-- Hamstring (Rank 1-3)
		DefineAura(694,7400,7402,20559,20560, IsWarrior + IsTaunt) 			-- Mocking Blow (Rank 1-5)(Taunt)
		DefineAura(12294,21551,21552,21553, IsWarrior) 						-- Mortal Strike (Rank 1-4)(Talent)
		DefineAura(772,6546,6547,6548,11572,11573,11574, IsWarrior) 		-- Rend (Rank 1-7)
		DefineAura(20230, IsWarrior) 										-- Retaliation (Boost)
		DefineAura(12292, IsWarrior) 										-- Sweeping Strikes (Talent)
		DefineAura(6343,8198,8204,8205,11580,11581, IsWarrior) 				-- Thunder Clap (Rank 1-6)

		SetFilter(2457, Never) 												-- Battle Stance (Shapeshift) CHECK!
		SetFilter(7922, Harmful) 											-- Charge Stun
		SetFilter(12162,1285012868, Boost) 									-- Deep Wounds Bleed (Rank 1-3) CHECK!
		SetFilter(1715,7372,7373, Harmful) 									-- Hamstring (Rank 1-3)
		SetFilter(694,7400,7402,20559,20560, OnEnemy) 						-- Mocking Blow (Rank 1-5)(Taunt)
		SetFilter(12294,21551,21552,21553, Harmful) 						-- Mortal Strike (Rank 1-4)(Talent)
		SetFilter(772,6546,6547,6548,11572,11573,11574, Damage) 			-- Rend (Rank 1-7)
		SetFilter(20230, Boost) 											-- Retaliation (Boost)
		SetFilter(12292, ByPlayer) 											-- Sweeping Strikes (Talent)
		SetFilter(6343,8198,8204,8205,11580,11581, Harmful) 				-- Thunder Clap (Rank 1-6)

	-- Warrior (Fury)
	-- https://classic.wowhead.com/warrior-abilities/fury
	-- https://classic.wowhead.com/fury-warrior-talents
	------------------------------------------------------------------------
		DefineAura(6673,5242,6192,11549,11550,11551,25289, IsWarrior) 		-- Battle Shout (Rank 1-7)
		DefineAura(18499, IsWarrior + IsImmuneCC) 							-- Berserker Rage (Boost)
		DefineAura(2458, IsWarrior) 										-- Berserker Stance (Shapeshift)
		DefineAura(16488,16490,16491, IsWarrior) 							-- Blood Craze (Rank 1-3)(Talent)
		DefineAura(1161, IsWarrior) 										-- Challenging Shout (Taunt)
		DefineAura(12328, IsWarrior + IsImmuneCC) 							-- Death Wish (Boost)(Talent)
		DefineAura(1160,6190,11554,11555,11556, IsWarrior) 					-- Demoralizing Shout (Rank 1-5)
		DefineAura(12880,14201,14202,14203,14204, IsWarrior) 				-- Enrage (Rank 1-5)
		DefineAura(12966,12967,12968,12969,12970, IsWarrior) 				-- Flurry (Rank 1-5)(Talent)
		DefineAura(20253,20614,20615, IsWarrior + IsStun) 					-- Intercept Stun (Rank 1-3)
		DefineAura(5246, IsWarrior + IsStun) 								-- Intimidating Shout
		DefineAura(12323, IsWarrior + IsSnare) 								-- Piercing Howl (Talent)
		DefineAura(1719, IsWarrior + IsImmuneCC) 							-- Recklessness (Boost)

		SetFilter(6673,5242,6192,11549,11550,11551,25289, GroupBuff + NeverOnPlate) 	-- Battle Shout (Rank 1-7)
		SetFilter(18499, Boost) 														-- Berserker Rage (Boost)
		SetFilter(2458, Never) 															-- Berserker Stance (Shapeshift)
		SetFilter(16488,16490,16491, ByPlayer) 											-- Blood Craze (Rank 1-3)(Talent)
		SetFilter(1161, OnEnemy) 														-- Challenging Shout (Taunt)
		SetFilter(12328, Boost) 														-- Death Wish (Boost)(Talent)
		SetFilter(1160,6190,11554,11555,11556, Harmful) 								-- Demoralizing Shout (Rank 1-5)
		SetFilter(12880,14201,14202,14203,14204, ByPlayer) 								-- Enrage (Rank 1-5)
		SetFilter(12966,12967,12968,12969,12970, ByPlayer) 								-- Flurry (Rank 1-5)(Talent)
		SetFilter(20253,20614,20615, Harmful) 											-- Intercept Stun (Rank 1-3)
		SetFilter(5246, Harmful) 														-- Intimidating Shout
		SetFilter(12323, Harmful) 														-- Piercing Howl (Talent)
		SetFilter(1719, Boost) 															-- Recklessness (Boost)

	-- Warrior (Protection)
	-- https://classic.wowhead.com/warrior-abilities/protection
	-- https://classic.wowhead.com/protection-warrior-talents
	------------------------------------------------------------------------
		DefineAura(29131, IsWarrior) 										-- Bloodrage
		DefineAura(12809, IsWarrior + IsStun) 								-- Concussion Blow (Talent)
		DefineAura(71, IsWarrior) 											-- Defensive Stance (Shapeshift)
		DefineAura(676, IsWarrior) 											-- Disarm
		DefineAura(2565, IsWarrior) 										-- Shield Block
		DefineAura(871, IsWarrior) 											-- Shield Wall (Defensive)
		DefineAura(7386,7405,8380,11596,11597, IsWarrior) 					-- Sunder Armor (Rank 1-5)

		SetFilter(29131, ByPlayer) 											-- Bloodrage
		SetFilter(12809, Harmful) 											-- Concussion Blow (Talent)
		SetFilter(71, Never) 												-- Defensive Stance (Shapeshift)
		SetFilter(676, Harmful) 											-- Disarm
		SetFilter(2565, ByPlayer) 											-- Shield Block
		SetFilter(871, Boost) 												-- Shield Wall (Defensive)
		SetFilter(7386,7405,8380,11596,11597, Harmful) 						-- Sunder Armor (Rank 1-5)

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
		--DefineAura(28428, IsRogue) 					-- Instant Poison CHECK!


	-- Various yet uncategorized Blacklists
	-----------------------------------------------------------------
		SetFilter(17670, Never) 						-- Argent Dawn Commission
		SetFilter(26013, NeverOnPlate + NoCombat) 		-- Deserter

		SetFilter(13159, NeverOnPlate) 					-- Aspect of the Pack
		SetFilter(7805, NeverOnPlate) 					-- Blood Pact
		SetFilter(11767, NeverOnPlate) 					-- Blood Pact
		SetFilter(19746, NeverOnPlate) 					-- Concentration Aura
		SetFilter(10293, NeverOnPlate) 					-- Devotion Aura
		SetFilter(19898, NeverOnPlate) 					-- Frost Resistance Aura

		SetFilter(19480, NeverOnPlate) 					-- Paranoia
		SetFilter(10301, NeverOnPlate) 					-- Retribution Aura
		SetFilter(20218, NeverOnPlate) 					-- Sanctity Aura
		SetFilter(19896, NeverOnPlate) 					-- Shadow Resistance Aura
		SetFilter(20906, NeverOnPlate) 					-- Trueshot Aura

		SetFilter(20217, NeverOnPlate) 					-- Blessing of Kings (Rank ?)
		SetFilter(19838, NeverOnPlate) 					-- Blessing of Might (Rank ?)
		SetFilter(11743, NeverOnPlate) 					-- Detect Greater Invisibility
		SetFilter(27841, NeverOnPlate) 					-- Divine Spirit (Rank ?)
		SetFilter(25898, NeverOnPlate) 					-- Greater Blessing of Kings (Rank ?)
		SetFilter(25899, NeverOnPlate) 					-- Greater Blessing of Sanctuary (Rank ?)
		SetFilter(10938, NeverOnPlate) 					-- Power Word: Fortitude (Rank ?)
		SetFilter(21564, NeverOnPlate) 					-- Prayer of Fortitude (Rank ?)
		SetFilter(27681, NeverOnPlate) 					-- Prayer of Spirit (Rank ?)
		SetFilter(10958, NeverOnPlate) 					-- Shadow Protection

	-- Food & Drink
	-- Maybe just add an additional name based filter for these(?)
	------------------------------------------------------------------------
		SetFilter(430, PlayerBuff) 	-- Drink (Level 1)
		SetFilter(431, PlayerBuff) 	-- Drink (Level 15)
		SetFilter(432, PlayerBuff) 	-- Drink (Level 25)
		SetFilter(1133, PlayerBuff) -- Drink (Level 35)
		SetFilter(1135, PlayerBuff) -- Drink (Level 45)
		SetFilter(1137, PlayerBuff) -- Drink (Level 55)
		SetFilter(11196, ByPlayer) 	-- Recently Bandaged

	-- Blackwing Lair
	------------------------------------------------------------------------
		-- Nefarian
		DefineAura(23402, IsBoss) -- Corrupted Healing

end

-- TBC Aura Lists!
-----------------------------------------------------------------
if (IsTBC) then
	-- Not happening. Deal with it.
end

-- Retail Aura Lists!
-----------------------------------------------------------------
if (IsRetail) then

	-- Death Knight (Blood)
	-- https://www.wowhead.com/mage-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(188290, IsDeathKnight) 				-- Death and Decay (Buff)
		SetFilter(188290, ByPlayer) 					-- Death and Decay (Buff)

	-- Demon Hunter (Vengeance)
	-- https://www.wowhead.com/vengeance-demon-hunter-abilities/live-only:on
	------------------------------------------------------------------------
		-- Note: Can't even remember the spec, I just needed it added!
		SetFilter(203981, ByPlayer) 					-- Soul Fragments (Buff)

	-- Druid (Abilities)
	-- https://www.wowhead.com/druid-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(5487, IsDruid) 						-- Bear Form (Shapeshift)
		DefineAura(768, IsDruid) 						-- Cat Form (Shapeshift)
		DefineAura(1850, IsDruid) 						-- Dash
		DefineAura(339, IsDruid + IsRoot) 				-- Entangling Roots
		DefineAura(164862, IsDruid) 					-- Flap
		DefineAura(165962, IsDruid) 					-- Flight Form (Shapeshift)
		DefineAura(6795, IsDruid + IsTaunt) 			-- Growl
		DefineAura(2637, IsDruid + IsIncap) 			-- Hibernate
		DefineAura(164812, IsDruid) 					-- Moonfire
		DefineAura(8936, IsDruid) 						-- Regrowth
		DefineAura(210053, IsDruid) 					-- Stag Form (Shapeshift)
		DefineAura(164815, IsDruid) 					-- Sunfire
		DefineAura(106830, IsDruid) 					-- Thrash
		DefineAura(783, IsDruid) 						-- Travel Form (Shapeshift)

		SetFilter(5487, Never) 							-- Bear Form (Shapeshift)
		SetFilter(768, Never) 							-- Cat Form (Shapeshift)
		SetFilter(1850, ByPlayer) 						-- Dash
		SetFilter(339, Harmful) 						-- Entangling Roots
		SetFilter(164862, ByPlayer) 					-- Flap
		SetFilter(165962, Never) 						-- Flight Form (Shapeshift)
		SetFilter(6795, OnEnemy) 						-- Growl (Taunt)
		SetFilter(2637, Harmful) 						-- Hibernate
		SetFilter(164812, Damage) 						-- Moonfire
		SetFilter(8936, ByPlayer) 						-- Regrowth
		SetFilter(210053, Never) 						-- Stag Form (Shapeshift)
		SetFilter(164815, Damage) 						-- Sunfire
		SetFilter(106830, Damage) 						-- Thrash
		SetFilter(783, Never) 							-- Travel Form (Shapeshift)

	-- Druid (Talents)
	-- https://www.wowhead.com/druid-talents/live-only:on
	------------------------------------------------------------------------
		DefineAura(155835, IsDruid) 					-- Bristling Fur
		DefineAura(102351, IsDruid) 					-- Cenarion Ward
		DefineAura(202770, IsDruid) 					-- Fury of Elune
		DefineAura(102558, IsDruid) 					-- Incarnation: Guardian of Ursoc (Shapeshift) (Defensive)
		DefineAura(102543, IsDruid) 					-- Incarnation: King of the Jungle (Shapeshift) (Boost)
		DefineAura(33891, IsDruid) 						-- Incarnation: Tree of Life (Shapeshift)
		DefineAura(102359, IsDruid + IsRoot) 			-- Mass Entanglement
		DefineAura(5211, IsDruid + IsStun) 				-- Mighty Bash
		DefineAura(52610, IsDruid) 						-- Savage Roar
		DefineAura(202347, IsDruid) 					-- Stellar Flare
		DefineAura(252216, IsDruid) 					-- Tiger Dash
		DefineAura(61391, IsDruid + IsSnare) 			-- Typhoon (Proc)
		DefineAura(102793, IsDruid + IsSnare) 			-- Ursol's Vortex
		DefineAura(202425, IsDruid) 					-- Warrior of Elune

		SetFilter(155835, ByPlayer) 					-- Bristling Fur
		SetFilter(102351, OnFriend) 					-- Cenarion Ward
		SetFilter(202770, ByPlayer) 					-- Fury of Elune
		SetFilter(102558, Boost) 						-- Incarnation: Guardian of Ursoc (Shapeshift)
		SetFilter(102543, Boost) 						-- Incarnation: King of the Jungle (Shapeshift)
		SetFilter(33891, Boost) 						-- Incarnation: Tree of Life (Shapeshift)
		SetFilter(102359, Harmful) 						-- Mass Entanglement
		SetFilter(5211, Harmful) 						-- Mighty Bash
		SetFilter(52610, ByPlayer) 						-- Savage Roar
		SetFilter(202347, Damage) 						-- Stellar Flare
		SetFilter(252216, ByPlayer) 					-- Tiger Dash
		SetFilter(61391, Harmful) 						-- Typhoon (Proc)
		SetFilter(102793, Harmful) 						-- Ursol's Vortex
		SetFilter(202425, ByPlayer) 					-- Warrior of Elune

	-- Druid (Balance)
	-- https://www.wowhead.com/balance-druid-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(22812, IsDruid) 						-- Barkskin (Defensive)
		DefineAura(194223, IsDruid) 					-- Celestial Alignment
		DefineAura(29166, IsDruid) 						-- Innervate
		DefineAura(24858, IsDruid) 						-- Moonkin Form (Shapeshift)
		DefineAura(5215, IsDruid) 						-- Prowl
		DefineAura(78675, IsDruid) 						-- Solar Beam
		DefineAura(191034, IsDruid) 					-- Starfall
		DefineAura(93402, IsDruid) 						-- Sunfire

		SetFilter(22812, ByPlayer) 						-- Barkskin
		SetFilter(194223, ByPlayer) 					-- Celestial Alignment
		SetFilter(29166, Boost) 						-- Innervate
		SetFilter(24858, Never) 						-- Moonkin Form (Shapeshift)
		SetFilter(5215, Never) 							-- Prowl
		SetFilter(78675, Damage) 						-- Solar Beam
		SetFilter(191034, Damage) 						-- Starfall
		SetFilter(93402, Damage) 						-- Sunfire

	-- Druid (Feral)
	-- https://www.wowhead.com/feral-druid-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(106951, IsDruid) 					-- Berserk (Boost)
		DefineAura(135700, IsDruid) 					-- Clearcasting (Omen of Clarity Proc)
		DefineAura(58180, IsDruid) 						-- Infected Wounds (Proc)
		DefineAura(22570, IsDruid + IsStun) 			-- Maim
		DefineAura(5215, IsDruid) 						-- Prowl
		DefineAura(155722, IsDruid) 					-- Rake
		DefineAura(1079, IsDruid) 						-- Rip
		DefineAura(106898, IsDruid) 					-- Stampeding Roar
		DefineAura(61336, IsDruid) 						-- Survival Instincts (Defensive)
		DefineAura(5217, IsDruid) 						-- Tiger's Fury

		SetFilter(106951, Boost) 						-- Berserk
		SetFilter(135700, ByPlayer) 					-- Clearcasting (Omen of Clarity Proc)
		SetFilter(58180, Harmful) 						-- Infected Wounds (Proc)
		SetFilter(22570, Harmful) 						-- Maim
		SetFilter(5215, ByPlayer) 						-- Prowl
		SetFilter(155722, Damage) 						-- Rake
		SetFilter(1079, Damage) 						-- Rip
		SetFilter(106898, ByPlayer) 					-- Stampeding Roar
		SetFilter(61336, ByPlayer) 						-- Survival Instincts
		SetFilter(5217, ByPlayer) 						-- Tiger's Fury

	-- Druid (Guardian)
	-- https://www.wowhead.com/guardian-druid-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(22812, IsDruid) 						-- Barkskin (Defensive)
		DefineAura(22842, IsDruid) 						-- Frenzied Regeneration
		DefineAura(99, IsDruid + IsIncap) 				-- Incapacitating Roar
		DefineAura(192081, IsDruid) 					-- Ironfur
		DefineAura(5215, IsDruid) 						-- Prowl
		DefineAura(106898, IsDruid) 					-- Stampeding Roar
		DefineAura(61336, IsDruid) 						-- Survival Instincts (Defensive)

		--SetFilter(22812, ByPlayer) 					-- Barkskin
		SetFilter(22842, Healing) 						-- Frenzied Regeneration
		SetFilter(99, Harmful) 							-- Incapacitating Roar
		SetFilter(192081, ByPlayer) 					-- Ironfur
		--SetFilter(5215, Never) 						-- Prowl
		--SetFilter(106898, ByPlayer) 					-- Stampeding Roar
		--SetFilter(61336, ByPlayer) 					-- Survival Instincts
		
	-- Druid (Restoration)
	-- https://www.wowhead.com/restoration-druid-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(22812, IsDruid) 						-- Barkskin (Defensive)
		DefineAura(16870, IsDruid) 						-- Clearcasting (Lifebloom Proc)
		DefineAura(29166, IsDruid) 						-- Innervate
		DefineAura(102342, IsDruid) 					-- Ironbark
		DefineAura(33763, IsDruid) 						-- Lifebloom
		DefineAura(5215, IsDruid) 						-- Prowl
		DefineAura(774, IsDruid) 						-- Rejuvenation
		DefineAura(93402, IsDruid) 						-- Sunfire
		DefineAura(740, IsDruid) 						-- Tranquility
		DefineAura(48438, IsDruid) 						-- Wild Growth

		--SetFilter(22812, ByPlayer) 					-- Barkskin
		SetFilter(16870, ByPlayer) 						-- Clearcasting (Lifebloom Proc)
		--SetFilter(29166, Boost) 						-- Innervate
		SetFilter(102342, ByPlayer) 					-- Ironbark
		SetFilter(33763, Healing) 						-- Lifebloom
		--SetFilter(5215, Never) 						-- Prowl
		SetFilter(774, Healing) 						-- Rejuvenation
		--SetFilter(93402, Damage) 						-- Sunfire
		SetFilter(740, Healing) 						-- Tranquility
		SetFilter(48438, Healing) 						-- Wild Growth

	-- Hunter (Abilities)
	-- https://www.wowhead.com/hunter-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(61648, IsHunter) 				-- Aspect of the Chameleon
		DefineAura(186257, IsHunter) 				-- Aspect of the Cheetah
		DefineAura(186265, IsHunter) 				-- Aspect of the Turtle
		DefineAura(209997, IsHunter) 				-- Play Dead
		DefineAura(6197, IsHunter) 					-- Eagle Eye
		DefineAura(5384, IsHunter) 					-- Feign Death
		DefineAura(1515, IsHunter) 					-- Tame Beast

		SetFilter(61648, ByPlayer) 					-- Aspect of the Chameleon
		SetFilter(186257, ByPlayer) 				-- Aspect of the Cheetah
		SetFilter(186265, ByPlayer) 				-- Aspect of the Turtle
		SetFilter(6197, ByPlayer) 					-- Eagle Eye
		SetFilter(5384, ByPlayer) 					-- Feign Death
		SetFilter(209997, ByPlayer) 				-- Play Dead
		SetFilter(1515, ByPlayer) 					-- Tame Beast

	-- Hunter (Talents)
	-- https://www.wowhead.com/hunter-talents/live-only:on
	------------------------------------------------------------------------
		DefineAura(131894, IsHunter) 				-- A Murder of Crows
		DefineAura(199483, IsHunter) 				-- Camouflage
		DefineAura(5116, IsHunter + IsSnare) 		-- Concussive Shot
		DefineAura(260402, IsHunter) 				-- Double Tap
		DefineAura(212431, IsHunter) 				-- Explosive Shot
		DefineAura(257284, IsHunter) 				-- Hunter's Mark
		DefineAura(194594, IsHunter) 				-- Lock and Load (Proc)
		DefineAura(34477, IsHunter) 				-- Misdirection
		DefineAura(118922, IsHunter) 				-- Posthaste (Disengage Proc)
		DefineAura(271788, IsHunter) 				-- Serpent Sting
		DefineAura(194407, IsHunter) 				-- Spitting Cobra
		DefineAura(268552, IsHunter) 				-- Viper's Venom (Proc)

		SetFilter(131894, ByPlayer) 				-- A Murder of Crows
		SetFilter(199483, ByPlayer) 				-- Camouflage
		SetFilter(260402, Boost) 					-- Double Tap
		SetFilter(212431, Damage) 					-- Explosive Shot
		SetFilter(257284, ByPlayer) 				-- Hunter's Mark
		SetFilter(194594, Boost) 					-- Lock and Load (Proc)
		SetFilter(271788, Damage) 					-- Serpent Sting
		SetFilter(194407, Boost) 					-- Spitting Cobra
		SetFilter(268552, Boost) 					-- Viper's Venom (Proc)

	-- Hunter (Beast Mastery)
	-- https://www.wowhead.com/beast-mastery-hunter-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(193530, IsHunter) 				-- Aspect of the Wild
		DefineAura(217200, IsHunter) 				-- Barbed Shot
		DefineAura(19574, IsHunter) 				-- Bestial Wrath
		DefineAura(19577, IsHunter + IsTaunt) 		-- Intimidation
		DefineAura(185791, IsHunter) 				-- Wild Call (Proc)

		SetFilter(193530, ByPlayer) 				-- Aspect of the Wild
		SetFilter(217200, Damage) 					-- Barbed Shot
		SetFilter(19574, Boost) 					-- Bestial Wrath
		SetFilter(5116, Harmful) 					-- Concussive Shot
		SetFilter(19577, ByPlayer) 					-- Intimidation
		SetFilter(34477, ByPlayer) 					-- Misdirection
		SetFilter(118922, ByPlayer) 				-- Posthaste (Disengage Proc)
		SetFilter(185791, Boost) 					-- Wild Call

	-- Hunter (Marksmanship)
	-- https://www.wowhead.com/marksmanship-hunter-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(186387, IsHunter + IsSnare) 		-- Bursting Shot
		DefineAura(257044, IsHunter) 				-- Rapid Fire
		DefineAura(288613, IsHunter) 				-- Trueshot

		SetFilter(186387, Harmful) 					-- Bursting Shot
		SetFilter(257044, Damage) 					-- Rapid Fire
		SetFilter(288613, Boost) 					-- Trueshot

	-- Hunter (Survival)
	-- https://www.wowhead.com/survival-hunter-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(186289, IsHunter) 				-- Aspect of the Eagle
		DefineAura(266779, IsHunter) 				-- Coordinated Assault
		DefineAura(186260, IsHunter + IsStun) 		-- Harpoon
		DefineAura(259491, IsHunter) 				-- Serpent Sting (Survival)
		DefineAura(195645, IsHunter + IsSnare) 		-- Wing Clip

		SetFilter(186289, ByPlayer) 				-- Aspect of the Eagle
		SetFilter(266779, Boost) 					-- Coordinated Assault
		SetFilter(186260, Harmful) 					-- Harpoon
		SetFilter(259491, Damage) 					-- Serpent Sting (Survival)
		SetFilter(195645, Harmful) 					-- Wing Clip

	-- Mage (Abilities)
	-- https://www.wowhead.com/mage-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(1459, IsMage) 						-- Arcane Intellect (Raid)
		DefineAura(1953, IsMage) 						-- Blink
		DefineAura(33395, IsMage + IsRoot) 				-- Freeze
		DefineAura(122, IsMage + IsRoot) 				-- Frost Nova
		DefineAura(45438, IsMage + IsImmune) 			-- Ice Block (Defensive)
		DefineAura(61305, IsMage + IsIncap) 			-- Polymorph: Black Cat
		DefineAura(277792, IsMage + IsIncap) 			-- Polymorph: Bumblebee
		DefineAura(277787, IsMage + IsIncap) 			-- Polymorph: Direhorn
		DefineAura(161354, IsMage + IsIncap) 			-- Polymorph: Monkey
		DefineAura(161372, IsMage + IsIncap) 			-- Polymorph: Peacock
		DefineAura(161355, IsMage + IsIncap) 			-- Polymorph: Penguin
		DefineAura(28272, IsMage + IsIncap) 			-- Polymorph: Pig
		DefineAura(161353, IsMage + IsIncap) 			-- Polymorph: Polar Bear Cub
		DefineAura(126819, IsMage + IsIncap) 			-- Polymorph: Porcupine
		DefineAura(61721, IsMage + IsIncap) 			-- Polymorph: Rabbit
		DefineAura(118, IsMage + IsIncap) 				-- Polymorph: Sheep
		DefineAura(61780, IsMage + IsIncap) 			-- Polymorph: Turkey
		DefineAura(28271, IsMage + IsIncap) 			-- Polymorph: Turtle
		DefineAura(130, IsMage) 						-- Slow Fall
		DefineAura(80353, IsMage) 						-- Time Warp (Boost)(Raid)

		SetFilter(1459, GroupBuff) 						-- Arcane Intellect (Raid)
		SetFilter(1953, ByPlayer) 						-- Blink
		SetFilter(33395, Harmful) 						-- Freeze
		SetFilter(122, Harmful) 						-- Frost Nova
		SetFilter(45438, Boost) 						-- Ice Block (Defensive)
		SetFilter(61305, Harmful) 						-- Polymorph: Black Cat
		SetFilter(277792, Harmful) 						-- Polymorph: Bumblebee
		SetFilter(277787, Harmful) 						-- Polymorph: Direhorn
		SetFilter(161354, Harmful) 						-- Polymorph: Monkey
		SetFilter(161372, Harmful) 						-- Polymorph: Peacock
		SetFilter(161355, Harmful) 						-- Polymorph: Penguin
		SetFilter(28272, Harmful) 						-- Polymorph: Pig
		SetFilter(161353, Harmful) 						-- Polymorph: Polar Bear Cub
		SetFilter(126819, Harmful) 						-- Polymorph: Porcupine
		SetFilter(61721, Harmful) 						-- Polymorph: Rabbit
		SetFilter(118, Harmful) 						-- Polymorph: Sheep
		SetFilter(61780, Harmful) 						-- Polymorph: Turkey
		SetFilter(28271, Harmful) 						-- Polymorph: Turtle
		SetFilter(130, Harmful) 						-- Slow Fall
		SetFilter(80353, Boost) 						-- Time Warp (Boost)(Raid)

	-- Mage (Talents)
	-- https://www.wowhead.com/mage-talents/live-only:on
	------------------------------------------------------------------------
		DefineAura(210126, IsMage) 						-- Arcane Familiar
		DefineAura(157981, IsMage + IsSnare) 			-- Blast Wave
		DefineAura(205766, IsMage) 						-- Bone Chilling
		DefineAura(236298, IsMage) 						-- Chrono Shift (Player Speed Boost)
		DefineAura(236299, IsMage + IsSnare) 			-- Chrono Shift (Target Speed Reduction)
		DefineAura(277726, IsMage) 						-- Clearcasting (Amplification Proc)(Clearcast)
		DefineAura(226757, IsMage) 						-- Conflagration
		DefineAura(236060, IsMage) 						-- Frenetic Speed
		DefineAura(199786, IsMage + IsRoot) 			-- Glacial Spike
		DefineAura(108839, IsMage) 						-- Ice Floes
		DefineAura(157997, IsMage + IsRoot) 			-- Ice Nova
		DefineAura(44457, IsMage) 						-- Living Bomb
		DefineAura(114923, IsMage) 						-- Nether Tempest
		DefineAura(235450, IsMage) 						-- Prismatic Barrier (Mana Shield)(Defensive)
		DefineAura(205021, IsMage + IsSnare) 			-- Ray of Frost
		DefineAura(212653, IsMage) 						-- Shimmer
		DefineAura(210824, IsMage) 						-- Touch of the Magi

		SetFilter(210126, ByPlayer) 					-- Arcane Familiar
		SetFilter(157981, Harmful) 						-- Blast Wave
		SetFilter(205766, ByPlayer) 					-- Bone Chilling
		SetFilter(236298, ByPlayer) 					-- Chrono Shift (Player Speed Boost)
		SetFilter(236299, Harmful) 						-- Chrono Shift (Target Speed Reduction)
		SetFilter(277726, ByPlayer) 					-- Clearcasting (Amplification Proc)(Clearcast)
		SetFilter(226757, Damage) 						-- Conflagration
		SetFilter(236060, ByPlayer) 					-- Frenetic Speed
		SetFilter(199786, Harmful) 						-- Glacial Spike
		SetFilter(108839, ByPlayer) 					-- Ice Floes
		SetFilter(157997, Harmful) 						-- Ice Nova
		SetFilter(44457, Damage) 						-- Living Bomb
		SetFilter(114923, Damage) 						-- Nether Tempest
		SetFilter(235450, Boost) 						-- Prismatic Barrier (Mana Shield)(Defensive)
		SetFilter(205021, Harmful) 						-- Ray of Frost
		SetFilter(212653, ByPlayer) 					-- Shimmer
		SetFilter(210824, Damage) 						-- Touch of the Magi

	-- Mage (Arcane)
	-- https://www.wowhead.com/arcane-mage-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(12042, IsMage) 						-- Arcane Power
		DefineAura(12051, IsMage) 						-- Evocation
		DefineAura(110960, IsMage) 						-- Greater Invisibility
		DefineAura(66, IsMage) 							-- Invisibility CHECK!
		DefineAura(205025, IsMage) 						-- Presence of Mind
		DefineAura(235450, IsMage) 						-- Prismatic Barrier
		DefineAura(31589, IsMage + IsSnare) 			-- Slow

		SetFilter(12042, ByPlayer) 						-- Arcane Power
		SetFilter(12051, Boost) 						-- Evocation
		SetFilter(110960, ByPlayer) 					-- Greater Invisibility
		SetFilter(66, ByPlayer) 						-- Invisibility CHECK!
		SetFilter(205025, Boost) 						-- Presence of Mind
		SetFilter(235450, ByPlayer) 					-- Prismatic Barrier
		SetFilter(31589, Harmful) 						-- Slow

	-- Mage (Fire)
	-- https://www.wowhead.com/fire-mage-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(190319, IsMage) 						-- Combustion
		DefineAura(235313, IsMage) 						-- Blazing Barrier
		DefineAura(235314, IsMage) 						-- Blazing Barrier (Proc)
		DefineAura(108843, IsMage + IsImmuneCC) 		-- Blazing Speed (Cauterize Proc)
		DefineAura(31661, IsMage + IsIncap) 			-- Dragon's Breath
		DefineAura(157644, IsMage) 						-- Enhanced Pyrotechnics
		DefineAura(2120, IsMage + IsSnare) 				-- Flamestrike
		DefineAura(195283, IsMage) 						-- Hot Streak (Proc)

		SetFilter(190319, Boost) 						-- Combustion
		SetFilter(235313, ByPlayer) 					-- Blazing Barrier
		SetFilter(235314, Boost) 						-- Blazing Barrier (Proc)
		SetFilter(108843, Boost) 						-- Blazing Speed (Cauterize Proc)
		SetFilter(31661, Harmful) 						-- Dragon's Breath
		SetFilter(157644, ByPlayer) 					-- Enhanced Pyrotechnics
		SetFilter(2120, Harmful) 						-- Flamestrike
		SetFilter(195283, ByPlayer) 					-- Hot Streak (Proc)

	-- Mage (Frost)
	-- https://www.wowhead.com/frost-mage-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(120, IsMage + IsSnare) 				-- Cone of Cold
		DefineAura(11426, IsMage + IsSnare) 			-- Ice Barrier (PlayerBuff) CHECK!
		DefineAura(12472, IsMage) 						-- Icy Veins
		
		SetFilter(120, Harmful) 						-- Cone of Cold
		SetFilter(11426, ByPlayer) 						-- Ice Barrier (PlayerBuff) CHECK!
		SetFilter(12472, Boost) 						-- Icy Veins

	-- BFA: Mage Azerite Traits
	------------------------------------------------------------------------
		SetFilter(280177, ByPlayer) 					-- Cauterizing Blink

	-- Warlock
	------------------------------------------------------------------------
		-- Will look this up later, just needed it added!
		SetFilter(146739, ByPlayer) 					-- Corruption
		SetFilter(317031, ByPlayer) 					-- Corruption (Instant)

	-- Warrior (Abilities)
	-- https://www.wowhead.com/warrior-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(6673, IsWarrior) 					-- Battle Shout
		DefineAura(115767, IsWarrior) 					-- Deep Wounds
		DefineAura(355, IsWarrior + IsTaunt) 			-- Taunt
		DefineAura(7922, 213427, IsWarrior + IsStun) 	-- Warbringer (Charge Stun)

		SetFilter(6673, GroupBuff) 						-- Battle Shout
		SetFilter(115767, Damage) 						-- Deep Wounds
		SetFilter(355, OnEnemy) 						-- Taunt
		SetFilter(7922, 213427, Harmful) 				-- Warbringer (Charge Stun)

	-- Warrior (Talents)
	-- https://www.wowhead.com/warrior-talents/live-only:on
	------------------------------------------------------------------------
		DefineAura(107574, IsWarrior) 					-- Avatar (Boost)
		DefineAura(46924, IsWarrior + IsImmuneCC) 		-- Bladestorm (Boost)
		DefineAura(262228, IsWarrior) 					-- Deadly Calm (Clearcast)
		DefineAura(197690, IsWarrior) 					-- Defensive Stance
		DefineAura(118000, IsWarrior + IsSnare) 		-- Dragon Roar
		DefineAura(215572, IsWarrior) 					-- Frothing Berserker (Proc)
		DefineAura(275335, IsWarrior) 					-- Punish (Debuff)
		DefineAura(152277, IsWarrior) 					-- Ravager (Boost)
		DefineAura(228920, IsWarrior) 					-- Ravager (Defensive)
		DefineAura(772, IsWarrior) 						-- Rend
		DefineAura(107570, IsWarrior + IsStun) 			-- Storm Bolt
		DefineAura(262232, IsWarrior + IsSnare) 		-- War Machine (Proc)

		SetFilter(107574, Boost) 						-- Avatar (Boost)
		SetFilter(46924, Boost) 						-- Bladestorm (Boost)
		SetFilter(262228, ByPlayer) 					-- Deadly Calm (Clearcast)
		SetFilter(197690, Never) 						-- Defensive Stance (Stance)
		SetFilter(118000, Harmful) 						-- Dragon Roar
		SetFilter(215572, ByPlayer) 					-- Frothing Berserker (Proc)
		SetFilter(275335, Damage) 						-- Punish
		SetFilter(772, Damage) 							-- Rend
		SetFilter(152277, ByPlayer) 					-- Ravager (Arms)
		SetFilter(228920, ByPlayer) 					-- Ravager (Protection)
		SetFilter(107570, Harmful) 						-- Storm Bolt
		SetFilter(262232, Harmful) 						-- War Machine (Proc)

	-- Warrior (Arms)
	-- https://www.wowhead.com/arms-warrior-abilities/live-only:on
	------------------------------------------------------------------------
		DefineAura(18499, IsWarrior + IsImmuneCC) 		-- Berserker Rage (Boost)
		DefineAura(227847, IsWarrior + IsImmuneCC) 		-- Bladestorm (Boost)
		DefineAura(262115, IsWarrior) 					-- Deep Wounds
		DefineAura(118038, IsWarrior) 					-- Die by the Sword (Defensive)
		DefineAura(1715, IsWarrior + IsSnare) 			-- Hamstring
		DefineAura(5246, IsWarrior + IsIncap) 			-- Intimidating Shout
		DefineAura(7384, IsWarrior) 					-- Overpower (Proc)
		DefineAura(260708, IsWarrior) 					-- Sweeping Strikes

		SetFilter(18499, Boost) 						-- Berserker Rage (Boost)
		SetFilter(227847, Boost) 						-- Bladestorm (Boost)
		SetFilter(262115, Damage) 						-- Deep Wounds
		SetFilter(118038, Boost) 						-- Die by the Sword (Defensive)
		SetFilter(1715, Harmful) 						-- Hamstring
		SetFilter(5246, Harmful) 						-- Intimidating Shout
		SetFilter(7384, ByPlayer) 						-- Overpower (Proc)
		SetFilter(260708, ByPlayer) 					-- Sweeping Strikes

	-- Warrior (Fury)
	-- https://www.wowhead.com/fury-warrior-abilities/live-only:on
	------------------------------------------------------------------------
		--DefineAura(18499, IsWarrior + IsImmuneCC) 	-- Berserker Rage (Boost)
		--DefineAura(5246, IsWarrior + IsIncap) 		-- Intimidating Shout
		DefineAura(12323, IsWarrior + IsSnare) 			-- Piercing Howl
		DefineAura(1719, IsWarrior) 					-- Recklessness (Boost)

		--SetFilter(18499, Boost) 						-- Berserker Rage (Boost)
		--SetFilter(5246, Harmful) 						-- Intimidating Shout
		SetFilter(12323, Harmful) 						-- Piercing Howl
		SetFilter(1719, Boost) 							-- Recklessness (Boost)

	-- Warrior (Protection)
	-- https://www.wowhead.com/protection-warrior-abilities/live-only:on
	------------------------------------------------------------------------
		--DefineAura(18499, IsWarrior + IsImmuneCC) 	-- Berserker Rage (Boost)
		DefineAura(1160, IsWarrior) 					-- Demoralizing Shout (Debuff)
		DefineAura(190456, IsWarrior) 					-- Ignore Pain (Defensive)
		--DefineAura(5246, IsWarrior + IsIncap) 		-- Intimidating Shout
		DefineAura(12975, IsWarrior) 					-- Last Stand (Defensive)
		DefineAura(871, IsWarrior) 						-- Shield Wall (Defensive)
		DefineAura(46968, IsWarrior + IsStun) 			-- Shockwave
		DefineAura(23920, IsWarrior) 					-- Spell Reflection (Defensive)
		DefineAura(6343, IsWarrior + IsSnare) 			-- Thunder Clap

		--SetFilter(18499, Boost) 						-- Berserker Rage (Boost)
		SetFilter(1160, ByPlayer) 						-- Demoralizing Shout (Debuff)
		SetFilter(190456, Boost) 						-- Ignore Pain (Defensive)
		--SetFilter(5246, Harmful) 						-- Intimidating Shout
		SetFilter(12975, Boost) 						-- Last Stand (Defensive)
		SetFilter(871, Boost) 							-- Shield Wall (Defensive)
		SetFilter(46968, Harmful) 						-- Shockwave
		SetFilter(23920, Boost) 						-- Spell Reflection (Defensive)
		SetFilter(6343, Harmful) 						-- Thunder Clap


	-- Blacklists
	-----------------------------------------------------------------
		-- Spammy stuff that is implicit and not really needed
		------------------------------------------------------------------------
			SetFilter(204242, NeverOnPlate) 			-- Consecration (talent Consecrated Ground)

		-- NPC buffs that are completely useless
		------------------------------------------------------------------------
			SetFilter(63501, Never) 					-- Argent Crusade Champion's Pennant
			SetFilter(60023, Never) 					-- Scourge Banner Aura (Boneguard Commander in Icecrown)
			SetFilter(63406, Never) 					-- Darnassus Champion's Pennant
			SetFilter(63405, Never) 					-- Darnassus Valiant's Pennant
			SetFilter(63423, Never) 					-- Exodar Champion's Pennant
			SetFilter(63422, Never) 					-- Exodar Valiant's Pennant
			SetFilter(63396, Never) 					-- Gnomeregan Champion's Pennant
			SetFilter(63395, Never) 					-- Gnomeregan Valiant's Pennant
			SetFilter(63427, Never) 					-- Ironforge Champion's Pennant
			SetFilter(63426, Never) 					-- Ironforge Valiant's Pennant
			SetFilter(63433, Never) 					-- Orgrimmar Champion's Pennant
			SetFilter(63432, Never) 					-- Orgrimmar Valiant's Pennant
			SetFilter(63399, Never) 					-- Sen'jin Champion's Pennant
			SetFilter(63398, Never) 					-- Sen'jin Valiant's Pennant
			SetFilter(63403, Never) 					-- Silvermoon Champion's Pennant
			SetFilter(63402, Never) 					-- Silvermoon Valiant's Pennant
			SetFilter(62594, Never) 					-- Stormwind Champion's Pennant
			SetFilter(62596, Never) 					-- Stormwind Valiant's Pennant
			SetFilter(63436, Never) 					-- Thunder Bluff Champion's Pennant
			SetFilter(63435, Never) 					-- Thunder Bluff Valiant's Pennant
			SetFilter(63430, Never) 					-- Undercity Champion's Pennant
			SetFilter(63429, Never) 					-- Undercity Valiant's Pennant

		
	-- Whitelists
	-----------------------------------------------------------------
		-- Quests and stuff that are game-breaking to not have there
		------------------------------------------------------------------------
			SetFilter(105241, Always) 					-- Absorb Blood (Amalgamation Stacks, some raid)
			SetFilter(304696, OnPlayer) 				-- Alpha Fin (constantly moving mount Nazjatar)
			SetFilter(298047, OnPlayer) 				-- Arcane Leylock (Untangle World Quest Nazjatar)
			SetFilter(298565, OnPlayer) 				-- Arcane Leylock (Untangle World Quest Nazjatar)
			SetFilter(298654, OnPlayer) 				-- Arcane Leylock (Untangle World Quest Nazjatar)
			SetFilter(298657, OnPlayer) 				-- Arcane Leylock (Untangle World Quest Nazjatar)
			SetFilter(298659, OnPlayer) 				-- Arcane Leylock (Untangle World Quest Nazjatar)
			SetFilter(298661, OnPlayer) 				-- Arcane Runelock (Puzzle World Quest Nazjatar)
			SetFilter(298663, OnPlayer) 				-- Arcane Runelock (Puzzle World Quest Nazjatar)
			SetFilter(298665, OnPlayer) 				-- Arcane Runelock (Puzzle World Quest Nazjatar)
			SetFilter(272004, OnPlayer) 				-- Choking Fog (outdoors debuff Stormsong Valley)
			SetFilter(304037, OnPlayer) 				-- Fermented Deviate Fish (transform)
			SetFilter(309806, OnPlayer) 				-- Gormlings Lured (Ardenweald World Quest)
			SetFilter(188030, ByPlayer) 				-- Leytorrent Potion (channeled) (Legion Consumables)
			SetFilter(295858, OnPlayer) 				-- Molted Shell (constantly moving mount Nazjatar)
			SetFilter(188027, ByPlayer) 				-- Potion of Deadly Grace (Legion Consumables)
			SetFilter(188028, ByPlayer) 				-- Potion of the Old War (Legion Consumables)
			SetFilter(188029, ByPlayer) 				-- Unbending Potion (Legion Consumables)
			SetFilter(127372, OnPlayer) 				-- Unstable Serum (Klaxxi Enhancement: Raining Blood)
			SetFilter(240640, OnPlayer) 				-- The Shadow of the Sentinax (Mark of the Sentinax)
			SetFilter(254873, OnPlayer) 				-- Irontide Recruit (Tiragarde Sound Storyline)
			SetFilter(312394, OnPlayer) 				-- Shackled Soul (Battered and Bruised World Quest Revendreth)


		-- Heroism
		------------------------------------------------------------------------
			SetFilter(90355, OnPlayer + PrioHigh) 		-- Ancient Hysteria
			SetFilter(2825, OnPlayer + PrioHigh) 		-- Bloodlust
			SetFilter(32182, OnPlayer + PrioHigh) 		-- Heroism
			SetFilter(160452, OnPlayer + PrioHigh) 		-- Netherwinds
			SetFilter(264667, OnPlayer + PrioHigh) 		-- Primal Rage (Hunter Pet Ferocity Ability)
			SetFilter(80353, OnPlayer + PrioHigh) 		-- Time Warp

			SetFilter(57723, OnPlayer) 					-- Exhaustion "Cannot benefit from Heroism or other similar effects." (Alliance version)
			SetFilter(160455, OnPlayer) 				-- Fatigued "Cannot benefit from Netherwinds or other similar effects." (Pet version)
			SetFilter(95809, OnPlayer) 					-- Insanity "Cannot benefit from Ancient Hysteria or other similar effects." (Pet version)
			SetFilter(57724, OnPlayer) 					-- Sated "Cannot benefit from Bloodlust or other similar effects." (Horde version)
			SetFilter(80354, OnPlayer) 					-- Temporal Displacement

		-- Deserters
		------------------------------------------------------------------------
			SetFilter(26013, OnPlayer + PrioHigh) 		-- Deserter
			SetFilter(99413, OnPlayer + PrioHigh) 		-- Deserter
			SetFilter(71041, OnPlayer + PrioHigh) 		-- Dungeon Deserter
			SetFilter(144075, OnPlayer + PrioHigh) 		-- Dungeon Deserter
			SetFilter(170616, OnPlayer + PrioHigh) 		-- Pet Deserter

		-- Other big ones
		------------------------------------------------------------------------
			SetFilter(67556, OnPlayer) 					-- Cooking Speed
			SetFilter(243138, OnPlayer) 				-- Happy Feet event 
			SetFilter(246050, OnPlayer) 				-- Happy Feet buff gained restoring health
			SetFilter(33206, OnPlayer) 					-- Pain Suppression
			SetFilter(10060, OnPlayer) 					-- Power Infusion
			SetFilter(15007, OnPlayer + PrioHigh) 		-- Resurrection Sickness
			SetFilter(64901, OnPlayer) 					-- Symbol of Hope

		-- Fucking Costumes (Hallow's End)
		-- *We need these visible to cancel them. 
		------------------------------------------------------------------------
			SetFilter(172010, OnPlayer) 	-- Abomination Costume
			SetFilter(218132, OnPlayer) 	-- Banshee Costume
			SetFilter(24732, OnPlayer) 		-- Bat Costume
			SetFilter(191703, OnPlayer) 	-- Bat Costume
			SetFilter(285521, OnPlayer) 	-- Blue Dragon Body Costume
			SetFilter(285519, OnPlayer) 	-- Blue Dragon Head Costume
			SetFilter(285523, OnPlayer) 	-- Blue Dragon Tail Costume
			SetFilter(97135, OnPlayer) 		-- Children's Costume Aura
			SetFilter(257204, OnPlayer) 	-- Dirty Horse Costume
			SetFilter(257205, OnPlayer) 	-- Dirty Horse Costume
			SetFilter(191194, OnPlayer) 	-- Exquisite Deathwing Costume
			SetFilter(192472, OnPlayer) 	-- Exquisite Deathwing Costume
			SetFilter(217917, OnPlayer) 	-- Exquisite Grommash Costume
			SetFilter(171958, OnPlayer) 	-- Exquisite Lich King Costume
			SetFilter(190837, OnPlayer) 	-- Exquisite VanCleef Costume
			SetFilter(246237, OnPlayer) 	-- Exquisite Xavius Costume
			SetFilter(191210, OnPlayer) 	-- Gargoyle Costume
			SetFilter(172015, OnPlayer) 	-- Geist Costume
			SetFilter(24735, OnPlayer) 		-- Ghost Costume
			SetFilter(24736, OnPlayer) 		-- Ghost Costume
			SetFilter(191700, OnPlayer) 	-- Ghost Costume
			SetFilter(191698, OnPlayer) 	-- Ghost Costume
			SetFilter(172008, OnPlayer) 	-- Ghoul Costume
			SetFilter(285522, OnPlayer) 	-- Green Dragon Body Costume
			SetFilter(285520, OnPlayer) 	-- Green Dragon Head Costume
			SetFilter(285524, OnPlayer) 	-- Green Dragon Tail Costume
			SetFilter(246242, OnPlayer) 	-- Horse Head Costume
			SetFilter(246241, OnPlayer) 	-- Horse Tail Costume
			SetFilter(44212, OnPlayer) 		-- Jack-o'-Lanterned!
			SetFilter(177656, OnPlayer) 	-- Kor'kron Foot Soldier Costume
			SetFilter(177657, OnPlayer) 	-- Kor'kron Foot Soldier Costume
			SetFilter(24712, OnPlayer) 		-- Leper Gnome Costume
			SetFilter(24713, OnPlayer) 		-- Leper Gnome Costume
			SetFilter(191701, OnPlayer) 	-- Leper Gnome Costume
			SetFilter(171479, OnPlayer) 	-- "Lil' Starlet" Costume
			SetFilter(171470, OnPlayer) 	-- "Mad Alchemist" Costume
			SetFilter(191211, OnPlayer) 	-- Nerubian Costume
			SetFilter(24710, OnPlayer) 		-- Ninja Costume
			SetFilter(24711, OnPlayer) 		-- Ninja Costume
			SetFilter(191686, OnPlayer) 	-- Ninja Costume
			SetFilter(24708, OnPlayer) 		-- Pirate Costume
			SetFilter(173958, OnPlayer) 	-- Pirate Costume
			SetFilter(173959, OnPlayer) 	-- Pirate Costume
			SetFilter(191682, OnPlayer) 	-- Pirate Costume
			SetFilter(191683, OnPlayer) 	-- Pirate Costume
			SetFilter(61716, OnPlayer) 		-- Rabbit Costume
			SetFilter(233598, OnPlayer) 	-- Red Dragon Body Costume
			SetFilter(233594, OnPlayer) 	-- Red Dragon Head Costume
			SetFilter(233599, OnPlayer) 	-- Red Dragon Tail Costume
			SetFilter(30167, OnPlayer) 		-- Red Ogre Costume
			SetFilter(102362, OnPlayer) 	-- Red Ogre Mage Costume
			SetFilter(24723, OnPlayer) 		-- Skeleton Costume
			SetFilter(191702, OnPlayer) 	-- Skeleton Costume
			SetFilter(172003, OnPlayer) 	-- Slime Costume
			SetFilter(172020, OnPlayer) 	-- Spider Costume
			SetFilter(99976, OnPlayer) 		-- Squashling Costume
			SetFilter(243321, OnPlayer) 	-- Tranquil Mechanical Yeti Costume
			SetFilter(178306, OnPlayer) 	-- Warsong Orc Costume
			SetFilter(178307, OnPlayer) 	-- Warsong Orc Costume
			SetFilter(191208, OnPlayer) 	-- Wight Costume
			SetFilter(24740, OnPlayer) 		-- Wisp Costume
			SetFilter(279509, OnPlayer) 	-- Witch!
			SetFilter(171930, OnPlayer) 	-- "Yipp-Saron" Costume


	-- Mythic+ Dungeons
	------------------------------------------------------------------------
		-- General Affix
		DefineAura(240443, IsBoss) -- Bursting
		DefineAura(240559, IsBoss) -- Grievous
		DefineAura(196376, IsBoss) -- Grievous Tear
		DefineAura(209858, IsBoss) -- Necrotic
		DefineAura(226512, IsBoss) -- Sanguine
		-- 8.3 BFA Affix
		DefineAura(314478, IsBoss) -- Cascading Terror
		DefineAura(314483, IsBoss) -- Cascading Terror
		DefineAura(314406, IsBoss) -- Crippling Pestilence
		DefineAura(314565, IsBoss) -- Defiled Ground
		DefineAura(314411, IsBoss) -- Lingering Doubt
		DefineAura(314592, IsBoss) -- Mind Flay
		DefineAura(314308, IsBoss) -- Spirit Breaker
		DefineAura(314531, IsBoss) -- Tear Flesh
		DefineAura(314392, IsBoss) -- Vile Corruption
		-- 9.x Shadowlands Affix
		DefineAura(342494, IsBoss) -- Belligerent Boast (Prideful)
	
	------------------------------------------------------------------------
	-- Battle for Azeroth Dungeons
	-- *some auras might be under the wrong dungeon, 
	--  this is because wowhead doesn't always tell what casts this.
	------------------------------------------------------------------------
	-- BFA: Atal'Dazar
	------------------------------------------------------------------------
		DefineAura(253721, IsDungeon) 	-- Bulwark of Juju
		DefineAura(253548, IsDungeon) 	-- Bwonsamdi's Mantle
		DefineAura(255421, IsBoss) 	-- Devour
		DefineAura(256201, IsDungeon) 	-- Incendiary Rounds
		DefineAura(250371, IsBoss) 	-- Lingering Nausea
		DefineAura(250372, IsDungeon) 	-- Lingering Nausea
		DefineAura(255582, IsBoss) 	-- Molten Gold
		DefineAura(257407, IsDungeon) 	-- Pursuit
		DefineAura(255814, IsBoss) 	-- Rending Maul
		DefineAura(255434, IsBoss) 	-- Serrated Teeth
		DefineAura(254959, IsBoss) 	-- Soulburn
		DefineAura(256577, IsBoss) 	-- Soulfeast
		DefineAura(254958, IsDungeon) 	-- Soulforged Construct
		DefineAura(259187, IsDungeon) 	-- Soulrend
		DefineAura(255558, IsDungeon) 	-- Tainted Blood
		DefineAura(255041, IsBoss) 	-- Terrifying Screech
		DefineAura(255371, IsBoss) 	-- Terrifying Visage
		DefineAura(255577, IsDungeon) 	-- Transfusion
		DefineAura(260667, IsDungeon) 	-- Transfusion
		DefineAura(260668, IsDungeon) 	-- Transfusion
		DefineAura(252781, IsBoss) 	-- Unstable Hex
		DefineAura(252687, IsBoss) 	-- Venomfang Strike
		DefineAura(253562, IsBoss) 	-- Wildfire
		DefineAura(250096, IsBoss) 	-- Wracking Pain

	-- BFA: Freehold
	------------------------------------------------------------------------
		DefineAura(258875, IsBoss) 	-- Blackout Barrel
		DefineAura(257739, IsDungeon) 	-- Blind Rage
		DefineAura(257305, IsDungeon) 	-- Cannon Barrage
		DefineAura(265168, IsDungeon) 	-- Caustic Freehold Brew
		DefineAura(278467, IsDungeon) 	-- Caustic Freehold Brew
		DefineAura(265085, IsDungeon) 	-- Confidence-Boosting Freehold Brew
		DefineAura(265088, IsDungeon) 	-- Confidence-Boosting Freehold Brew
		DefineAura(268717, IsDungeon) 	-- Dive Bomb
		DefineAura(258323, IsBoss) 	-- Infected Wound
		DefineAura(264608, IsDungeon) 	-- Invigorating Freehold Brew
		DefineAura(265056, IsDungeon) 	-- Invigorating Freehold Brew
		DefineAura(257908, IsBoss) 	-- Oiled Blade
		DefineAura(257775, IsBoss) 	-- Plague Step
		DefineAura(257436, IsBoss) 	-- Poisoning Strike
		DefineAura(274383, IsDungeon) 	-- Rat Traps
		DefineAura(274389, IsBoss) 	-- Rat Traps
		DefineAura(256363, IsBoss) 	-- Ripper Punch
		DefineAura(274555, IsBoss) 	-- Scabrous Bites
		DefineAura(258777, IsDungeon) 	-- Sea Spout
		DefineAura(257732, IsDungeon) 	-- Shattering Bellow
		DefineAura(274507, IsDungeon) 	-- Slippery Suds

	-- BFA: King's Rest
	------------------------------------------------------------------------
		DefineAura(274387, IsDungeon) -- Absorbed in Darkness 
		DefineAura(270084, IsBoss) 	-- Axe Barrage
		DefineAura(266951, IsDungeon) -- Barrel Through
		DefineAura(268586, IsDungeon) -- Blade Combo
		DefineAura(267639, IsDungeon) -- Burn Corruption
		DefineAura(270889, IsDungeon) -- Channel Lightning
		DefineAura(271640, IsBoss) 	-- Dark Revelation
		DefineAura(267626, IsBoss) 	-- Dessication
		DefineAura(267618, IsBoss) 	-- Drain Fluids
		DefineAura(271564, IsBoss) 	-- Embalming Fluid
		DefineAura(269936, IsDungeon) -- Fixate
		DefineAura(268419, IsDungeon) -- Gale Slash
		DefineAura(270514, IsDungeon) -- Ground Crush
		DefineAura(270492, IsBoss) 	-- Hex
		DefineAura(270865, IsBoss) 	-- Hidden Blade
		DefineAura(268796, IsBoss) 	-- Impaling Spear
		DefineAura(265923, IsDungeon) -- Lucre's Call
		DefineAura(276031, IsBoss) 	-- Pit of Despair
		DefineAura(270507, IsBoss) 	-- Poison Barrage
		DefineAura(267273, IsBoss) 	-- Poison Nova
		DefineAura(270284, IsDungeon) -- Purification Beam
		DefineAura(270289, IsDungeon) -- Purification Beam
		DefineAura(270920, IsBoss) 	-- Seduction
		DefineAura(265781, IsDungeon) -- Serpentine Gust
		DefineAura(266231, IsBoss) 	-- Severing Axe
		DefineAura(270487, IsBoss) 	-- Severing Blade
		DefineAura(272388, IsBoss) 	-- Shadow Barrage
		DefineAura(266238, IsBoss) 	-- Shattered Defenses
		DefineAura(265773, IsBoss) 	-- Spit Gold
		DefineAura(270003, IsBoss) 	-- Suppression Slam
		DefineAura(266191, IsBoss) 	-- Whirling Axes
		DefineAura(267763, IsBoss) 	-- Wretched Discharge

	-- BFA: Motherlode
	------------------------------------------------------------------------
		DefineAura(262510, IsDungeon) -- Azerite Heartseeker
		DefineAura(262513, IsBoss) 	-- Azerite Heartseeker
		DefineAura(262515, IsDungeon) -- Azerite Heartseeker
		DefineAura(262516, IsDungeon) -- Azerite Heartseeker
		DefineAura(281534, IsDungeon) -- Azerite Heartseeker
		DefineAura(270276, IsDungeon) -- Big Red Rocket
		DefineAura(270277, IsDungeon) -- Big Red Rocket
		DefineAura(270278, IsDungeon) -- Big Red Rocket
		DefineAura(270279, IsDungeon) -- Big Red Rocket
		DefineAura(270281, IsDungeon) -- Big Red Rocket
		DefineAura(270282, IsDungeon) -- Big Red Rocket
		DefineAura(256163, IsDungeon) -- Blazing Azerite
		DefineAura(256493, IsDungeon) -- Blazing Azerite
		DefineAura(270882, IsBoss) 	-- Blazing Azerite
		DefineAura(280605, IsBoss) 	-- Brain Freeze
		DefineAura(259853, IsDungeon) -- Chemical Burn
		DefineAura(259856, IsBoss) 	-- Chemical Burn
		DefineAura(263637, IsBoss) 	-- Clothesline
		DefineAura(268846, IsBoss) 	-- Echo Blade
		DefineAura(262794, IsBoss) 	-- Energy Lash
		DefineAura(263074, IsBoss) 	-- Festering Bite
		DefineAura(260811, IsDungeon) -- Homing Missile
		DefineAura(260813, IsDungeon) -- Homing Missile
		DefineAura(260815, IsDungeon) -- Homing Missile
		DefineAura(260829, IsBoss) 	-- Homing Missile (travelling)
		DefineAura(260835, IsDungeon) -- Homing Missile
		DefineAura(260836, IsDungeon) -- Homing Missile
		DefineAura(260837, IsDungeon) -- Homing Missile
		DefineAura(260838, IsBoss) 	-- Homing Missile (exploded)
		DefineAura(280604, IsBoss) 	-- Iced Spritzer
		DefineAura(257544, IsBoss) 	-- Jagged Cut
		DefineAura(257582, IsDungeon) -- Raging Gaze
		DefineAura(258622, IsDungeon) -- Resonant Pulse
		DefineAura(271579, IsDungeon) -- Rock Lance
		DefineAura(263202, IsDungeon) -- Rock Lance
		DefineAura(257337, IsBoss) 	-- Shocking Claw
		DefineAura(262347, IsDungeon) -- Static Pulse
		DefineAura(257371, IsBoss) 	-- Tear Gas
		DefineAura(275905, IsDungeon) -- Tectonic Smash
		DefineAura(275907, IsDungeon) -- Tectonic Smash
		DefineAura(269302, IsBoss) 	-- Toxic Blades
		DefineAura(268797, IsBoss) 	-- Transmute: Enemy to Goo
		DefineAura(269298, IsDungeon) -- Widowmaker Toxin

	-- BFA: Operation Mechagon
	------------------------------------------------------------------------
		DefineAura(294195, IsBoss) 	-- Arcing Zap
		DefineAura(302274, IsBoss) 	-- Fulminating Zap
		DefineAura(294929, IsBoss) 	-- Blazing Chomp
		DefineAura(294855, IsBoss) 	-- Blossom Blast
		DefineAura(299475, IsBoss) 	-- B.O.R.K
		DefineAura(297283, IsBoss) 	-- Cave In
		DefineAura(293670, IsBoss) 	-- Chain Blade
		DefineAura(296560, IsBoss) 	-- Clinging Static
		DefineAura(300659, IsBoss) 	-- Consuming Slime
		DefineAura(291914, IsBoss) 	-- Cutting Beam
		DefineAura(297257, IsBoss) 	-- Electrical Charge
		DefineAura(291972, IsBoss) 	-- Explosive Leap
		DefineAura(291928, IsBoss) 	-- Giga-Zap
		DefineAura(292267, IsBoss) 	-- Giga-Zap
		DefineAura(285443, IsBoss) 	-- "Hidden" Flame Cannon
		DefineAura(291974, IsBoss) 	-- Obnoxious Monologue
		DefineAura(301712, IsBoss) 	-- Pounce
		DefineAura(299572, IsBoss) 	-- Shrink
		DefineAura(298602, IsBoss) 	-- Smoke Cloud
		DefineAura(302384, IsBoss) 	-- Static Discharge
		DefineAura(300650, IsBoss) 	-- Suffocating Smog
		DefineAura(298669, IsBoss) 	-- Taze
		DefineAura(296150, IsBoss) 	-- Vent Blast
		DefineAura(295445, IsBoss) 	-- Wreck

	-- BFA: Shrine of the Storm
	------------------------------------------------------------------------
		DefineAura(274720, IsBoss) 	-- Abyssal Strike
		DefineAura(269131, IsDungeon) -- Ancient Mindbender
		DefineAura(268086, IsDungeon) -- Aura of Dread
		DefineAura(268214, IsBoss) 	-- Carving Flesh
		DefineAura(264560, IsBoss) 	-- Choking Brine
		DefineAura(268233, IsBoss) 	-- Electrifying Shock
		DefineAura(268104, IsBoss) 	-- Explosive Void
		DefineAura(264526, IsBoss) 	-- Grasp of the Depths
		DefineAura(276268, IsBoss) 	-- Heaving Blow
		DefineAura(267899, IsDungeon) -- Hindering Cleave
		DefineAura(268391, IsBoss) 	-- Mental Assault
		DefineAura(268896, IsBoss) 	-- Mind Rend
		DefineAura(268212, IsDungeon) -- Minor Reinforcing Ward
		DefineAura(268183, IsDungeon) -- Minor Swiftness Ward
		DefineAura(268184, IsDungeon) -- Minor Swiftness Ward
		DefineAura(267905, IsDungeon) -- Reinforcing Ward
		DefineAura(268186, IsDungeon) -- Reinforcing Ward
		DefineAura(268317, IsBoss) 	-- Rip Mind
		DefineAura(268239, IsDungeon) -- Shipbreaker Storm
		DefineAura(267818, IsBoss) 	-- Slicing Blast
		DefineAura(276286, IsDungeon) -- Slicing Hurricane
		DefineAura(274633, IsBoss) 	-- Sundering Blow
		DefineAura(264101, IsDungeon) -- Surging Rush
		DefineAura(267890, IsDungeon) -- Swiftness Ward
		DefineAura(267891, IsDungeon) -- Swiftness Ward
		DefineAura(268322, IsBoss) 	-- Touch of the Drowned
		DefineAura(264166, IsBoss) 	-- Undertow
		DefineAura(268309, IsBoss) 	-- Unending Darkness
		DefineAura(276297, IsDungeon) -- Void Seed
		DefineAura(267034, IsBoss) 	-- Whispers of Power
		DefineAura(267037, IsDungeon) -- Whispers of Power
		DefineAura(269399, IsDungeon) -- Yawning Gate

	-- BFA: Siege of Boralus
	------------------------------------------------------------------------
		DefineAura(272571, IsBoss) 	-- Choking Waters
		DefineAura(256897, IsBoss) 	-- Clamping Jaws
		DefineAura(269029, IsDungeon) -- Clear the Deck
		DefineAura(272144, IsDungeon) -- Cover
		DefineAura(272713, IsBoss) 	-- Crushing Slam
		DefineAura(257168, IsBoss) 	-- Cursed Slash
		DefineAura(273470, IsBoss) 	-- Gut Shot
		DefineAura(261428, IsBoss) 	-- Hangman's Noose
		DefineAura(257292, IsBoss) 	-- Heavy Slash
		DefineAura(273930, IsBoss) 	-- Hindering Cut
		DefineAura(260954, IsDungeon) -- Iron Gaze
		DefineAura(274991, IsBoss) 	-- Putrid Waters
		DefineAura(275014, IsDungeon) -- Putrid Waters
		DefineAura(272588, IsBoss) 	-- Rotting Wounds
		DefineAura(257170, IsDungeon) -- Savage Tempest
		DefineAura(272421, IsDungeon) -- Sighted Artillery
		DefineAura(269266, IsDungeon) -- Slam
		DefineAura(275836, IsDungeon) -- Stinging Venom
		DefineAura(275835, IsBoss) 	-- Stinging Venom Coating
		DefineAura(257169, IsBoss) 	-- Terrifying Roar
		DefineAura(276068, IsDungeon) -- Tidal Surge
		DefineAura(272874, IsBoss) 	-- Trample
		DefineAura(272834, IsBoss) 	-- Viscous Slobber
		DefineAura(260569, IsDungeon) -- Wildfire (?) Waycrest Manor? CHECK!

	-- BFA: Temple of Sethraliss
	------------------------------------------------------------------------
		DefineAura(263958, IsBoss) 	-- A Knot of Snakes
		DefineAura(263914, IsBoss) 	-- Blinding Sand
		DefineAura(263371, IsBoss) 	-- Conduction
		DefineAura(263573, IsDungeon) -- Cyclone Strike
		DefineAura(267027, IsBoss) 	-- Cytotoxin
		DefineAura(256333, IsDungeon) -- Dust Cloud
		DefineAura(260792, IsDungeon) -- Dust Cloud
		DefineAura(272659, IsDungeon) -- Electrified Scales
		DefineAura(269670, IsDungeon) -- Empowerment
		DefineAura(268013, IsBoss) 	-- Flame Shock
		DefineAura(266923, IsBoss) 	-- Galvanize
		DefineAura(268007, IsBoss) 	-- Heart Attack
		DefineAura(263246, IsDungeon) -- Lightning Shield
		DefineAura(273563, IsBoss) 	-- Neurotoxin
		DefineAura(272657, IsBoss) 	-- Noxious Breath
		DefineAura(275566, IsDungeon) -- Numb Hands
		DefineAura(269686, IsBoss) 	-- Plague
		DefineAura(272655, IsBoss) 	-- Scouring Sand
		DefineAura(268008, IsBoss) 	-- Snake Charm
		DefineAura(263257, IsDungeon) -- Static Shock
		DefineAura(272699, IsBoss) 	-- Venomous Spit

	-- BFA: Tol Dagor
	------------------------------------------------------------------------
		DefineAura(256199, IsDungeon) -- Azerite Rounds: Blast
		DefineAura(256198, IsBoss) 	-- Azerite Rounds: Incendiary
		DefineAura(256955, IsDungeon) -- Cinderflame
		DefineAura(257777, IsBoss) 	-- Crippling Shiv
		DefineAura(256083, IsDungeon) -- Cross Ignition
		DefineAura(256038, IsDungeon) -- Deadeye
		DefineAura(256044, IsBoss) 	-- Deadeye
		DefineAura(258128, IsBoss) 	-- Debilitating Shout
		DefineAura(256101, IsBoss) 	-- Explosive Burst
		DefineAura(256105, IsDungeon) -- Explosive Burst
		DefineAura(257785, IsDungeon) -- Flashing Daggers
		DefineAura(257028, IsBoss) 	-- Fuselighter
		DefineAura(258313, IsBoss) 	-- Handcuff
		DefineAura(256474, IsBoss) 	-- Heartstopper Venom
		DefineAura(257791, IsBoss) 	-- Howling Fear
		DefineAura(258075, IsDungeon) -- Itchy Bite
		DefineAura(260016, IsBoss) 	-- Itchy Bite
		DefineAura(259711, IsBoss) 	-- Lockdown
		DefineAura(258079, IsBoss) 	-- Massive Chomp
		DefineAura(258917, IsBoss) 	-- Righteous Flames
		DefineAura(258317, IsDungeon) -- Riot Shield
		DefineAura(257495, IsDungeon) -- Sandstorm
		DefineAura(257119, IsBoss) 	-- Sand Trap
		DefineAura(258058, IsBoss) 	-- Squeeze
		DefineAura(258864, IsBoss) 	-- Suppression Fire
		DefineAura(265889, IsBoss) 	-- Torch Strike
		DefineAura(260067, IsBoss) 	-- Vicious Mauling
		DefineAura(258153, IsDungeon) -- Watery Dome

	-- BFA: Underrot
	------------------------------------------------------------------------
		DefineAura(272592, IsDungeon) -- Abyssal Reach
		DefineAura(265533, IsBoss) 	-- Blood Maw
		DefineAura(264603, IsDungeon) -- Blood Mirror
		DefineAura(260292, IsDungeon) -- Charge
		DefineAura(265568, IsDungeon) -- Dark Omen
		DefineAura(265625, IsBoss) 	-- Dark Omen
		DefineAura(272180, IsBoss) 	-- Death Bolt
		DefineAura(278961, IsBoss) 	-- Decaying Mind
		DefineAura(259714, IsBoss) 	-- Decaying Spores
		DefineAura(273226, IsDungeon) -- Decaying Spores
		DefineAura(265377, IsBoss) 	-- Hooked Snare
		DefineAura(260793, IsDungeon) -- Indigestion
		DefineAura(272609, IsBoss) 	-- Maddening Gaze
		DefineAura(257437, IsDungeon) -- Poisoning Strike
		DefineAura(269301, IsBoss) 	-- Putrid Blood
		DefineAura(264757, IsDungeon) -- Sanguine Feast
		DefineAura(265019, IsBoss) 	-- Savage Cleave
		DefineAura(260455, IsBoss) 	-- Serrated Fangs
		DefineAura(260685, IsBoss) 	-- Taint of G'huun
		DefineAura(266107, IsBoss) 	-- Thirst for Blood
		DefineAura(259718, IsDungeon) -- Upheaval
		DefineAura(269843, IsDungeon) -- Vile Expulsion
		DefineAura(273285, IsDungeon) -- Volatile Pods
		DefineAura(265468, IsBoss) 	-- Withering Curse

	-- BFA: Waycrest Manor
	------------------------------------------------------------------------
		DefineAura(268080, IsDungeon) -- Aura of Apathy
		DefineAura(266035, IsBoss) 	-- Bone Splinter
		DefineAura(260541, IsDungeon) -- Burning Brush
		DefineAura(268202, IsBoss) 	-- Death Lens
		DefineAura(265881, IsBoss) 	-- Decaying Touch
		DefineAura(268306, IsDungeon) -- Discordant Cadenza
		DefineAura(266036, IsBoss) 	-- Drain Essence
		DefineAura(265880, IsBoss) 	-- Dread Mark
		DefineAura(263943, IsBoss) 	-- Etch
		DefineAura(264378, IsBoss) 	-- Fragment Soul
		DefineAura(263891, IsBoss) 	-- Grasping Thorns
		DefineAura(264050, IsBoss) 	-- Infected Thorn
		DefineAura(278444, IsDungeon) -- Infest
		DefineAura(278456, IsBoss) 	-- Infest
		DefineAura(261265, IsDungeon) -- Ironbark Shield
		DefineAura(260741, IsBoss) 	-- Jagged Nettles
		DefineAura(265882, IsBoss) 	-- Lingering Dread
		DefineAura(263905, IsBoss) 	-- Marking Cleave
		DefineAura(271178, IsDungeon) -- Ravaging Leap
		DefineAura(264694, IsDungeon) -- Rotten Expulsion
		DefineAura(264105, IsBoss) 	-- Runic Mark
		DefineAura(261266, IsDungeon) -- Runic Ward
		DefineAura(261264, IsDungeon) -- Soul Armor
		DefineAura(260512, IsDungeon) -- Soul Harvest
		DefineAura(260907, IsBoss) 	-- Soul Manipulation
		DefineAura(260551, IsBoss) 	-- Soul Thorns
		DefineAura(264556, IsBoss) 	-- Tearing Strike
		DefineAura(264923, IsDungeon) -- Tenderize
		DefineAura(265760, IsBoss) 	-- Thorned Barrage
		DefineAura(265761, IsDungeon) -- Thorned Barrage
		DefineAura(260703, IsBoss) 	-- Unstable Runic Mark
		DefineAura(261440, IsBoss) 	-- Virulent Pathogen
		DefineAura(263961, IsDungeon) -- Warding Candles
		DefineAura(261438, IsBoss) 	-- Wasting Strike

	-- BFA: Uldir
	------------------------------------------------------------------------
		-- MOTHER
		DefineAura(268095, IsBoss) -- Cleansing Purge
		DefineAura(268198, IsBoss) -- Clinging Corruption
		DefineAura(267821, IsBoss) -- Defense Grid
		DefineAura(268277, IsBoss) -- Purifying Flame
		DefineAura(267787, IsBoss) -- Sundering Scalpel
		DefineAura(268253, IsBoss) -- Surgical Beam
		-- Vectis
		DefineAura(265212, IsBoss) -- Gestate
		DefineAura(265206, IsBoss) -- Immunosuppression
		DefineAura(265127, IsBoss) -- Lingering Infection
		DefineAura(265178, IsBoss) -- Mutagenic Pathogen
		DefineAura(265129, IsBoss) -- Omega Vector
		DefineAura(267160, IsBoss) -- Omega Vector
		DefineAura(267161, IsBoss) -- Omega Vector
		DefineAura(267162, IsBoss) -- Omega Vector
		DefineAura(267163, IsBoss) -- Omega Vector
		DefineAura(267164, IsBoss) -- Omega Vector
		-- Mythrax
		--DefineAura(272146, IsBoss) -- Annihilation
		DefineAura(274693, IsBoss) -- Essence Shear
		DefineAura(272536, IsBoss) -- Imminent Ruin
		DefineAura(272407, IsBoss) -- Oblivion Sphere
		-- Fetid Devourer
		DefineAura(262314, IsBoss) -- Deadly Disease
		DefineAura(262313, IsBoss) -- Malodorous Miasma
		DefineAura(262292, IsBoss) -- Rotting Regurgitation
		-- Taloc
		DefineAura(270290, IsBoss) -- Blood Storm
		DefineAura(275270, IsBoss) -- Fixate
		DefineAura(271224, IsBoss) -- Plasma Discharge
		DefineAura(271225, IsBoss) -- Plasma Discharge
		-- Zul
		DefineAura(272018, IsBoss) -- Absorbed in Darkness
		--DefineAura(274195, IsBoss) -- Corrupted Blood
		DefineAura(273365, IsBoss) -- Dark Revelation
		DefineAura(273434, IsBoss) -- Pit of Despair
		DefineAura(274358, IsBoss) -- Rupturing Blood
		-- Zek'voz, Herald of N'zoth
		DefineAura(265662, IsBoss) -- Corruptor's Pact
		DefineAura(265360, IsBoss) -- Roiling Deceit
		DefineAura(265237, IsBoss) -- Shatter
		DefineAura(265264, IsBoss) -- Void Lash
		DefineAura(265646, IsBoss) -- Will of the Corruptor
		-- G'huun
		DefineAura(270287, IsBoss) -- Blighted Ground
		DefineAura(263235, IsBoss) -- Blood Feast
		DefineAura(267409, IsBoss) -- Dark Bargain
		DefineAura(272506, IsBoss) -- Explosive Corruption
		DefineAura(263436, IsBoss) -- Imperfect Physiology
		DefineAura(263372, IsBoss) -- Power Matrix
		DefineAura(263227, IsBoss) -- Putrid Blood
		DefineAura(267430, IsBoss) -- Torment

	-- BFA: Siege of Zuldazar
	------------------------------------------------------------------------
		-- Rawani Kanae / Frida Ironbellows
		DefineAura(283582, IsBoss) 	-- Consecration
		DefineAura(283651, IsBoss) 	-- Blinding Faith
		DefineAura(284595, IsBoss) 	-- Penance
		DefineAura(283573, IsBoss) 	-- Sacred Blade
		DefineAura(283617, IsBoss) 	-- Wave of Light
		-- Grong
		DefineAura(285671, IsBoss) 	-- Crushed
		DefineAura(285998, IsBoss) 	-- Ferocious Roar
		DefineAura(283069, IsBoss) 	-- Megatomic Fire
		DefineAura(285875, IsBoss) 	-- Rending Bite
		-- Jaina
		DefineAura(285254, IsBoss) 	-- Avalanche
		DefineAura(287993, IsBoss) 	-- Chilling Touch
		DefineAura(287490, IsBoss) 	-- Frozen Solid
		DefineAura(287626, IsBoss) 	-- Grasp of Frost
		DefineAura(285253, IsBoss) 	-- Ice Shard
		DefineAura(288038, IsBoss) 	-- Marked Target
		DefineAura(287199, IsBoss) 	-- Ring of Ice
		DefineAura(287365, IsBoss) 	-- Searing Pitch
		DefineAura(288392, IsBoss) 	-- Vengeful Seas
		-- Stormwall Blockade
		DefineAura(286680, IsBoss) 	-- Roiling Tides
		DefineAura(284369, IsBoss) 	-- Sea Storm
		DefineAura(284410, IsBoss) 	-- Tempting Song
		DefineAura(284405, IsBoss) 	-- Tempting Song
		DefineAura(284121, IsBoss) 	-- Thunderous Boom
		-- Opulence
		DefineAura(289383, IsBoss) 	-- Chaotic Displacement
		DefineAura(286501, IsBoss) 	-- Creeping Blaze
		DefineAura(283610, IsBoss) 	-- Crush
		DefineAura(285479, IsBoss) 	-- Flame Jet
		DefineAura(283063, IsBoss) 	-- Flames of Punishment
		DefineAura(283507, IsBoss) 	-- Volatile Charge
		-- King Rastakhan
		DefineAura(289858, IsBoss) 	-- Crushed
		DefineAura(285349, IsBoss) 	-- Plague of Fire
		DefineAura(285010, IsBoss) 	-- Poison Toad Slime
		DefineAura(284831, IsBoss) 	-- Scorching Detonation
		DefineAura(284662, IsBoss) 	-- Seal of Purification
		DefineAura(284676, IsBoss) 	-- Seal of Purification
		DefineAura(285178, IsBoss) 	-- Serpent's Breath
		DefineAura(285044, IsBoss) 	-- Toad Toxin
		DefineAura(284995, IsBoss) 	-- Zombie Dust
		-- Jadefire Masters
		DefineAura(284374, IsBoss) 	-- Magma Trap
		DefineAura(282037, IsBoss) 	-- Rising Flames
		DefineAura(286988, IsBoss) 	-- Searing Embers
		DefineAura(285632, IsBoss) 	-- Stalking
		DefineAura(284089, IsBoss) 	-- Successful Defense
		DefineAura(288151, IsBoss) 	-- Tested
		-- Mekkatorque
		DefineAura(286516, IsBoss) 	-- Anti-Tampering Shock
		DefineAura(286480, IsBoss) 	-- Anti-Tampering Shock
		DefineAura(289023, IsBoss) 	-- Enormous
		DefineAura(288806, IsBoss) 	-- Gigavolt Blast
		DefineAura(286646, IsBoss) 	-- Gigavolt Charge
		DefineAura(288939, IsBoss) 	-- Gigavolt Radiation
		DefineAura(284168, IsBoss) 	-- Shrunk
		DefineAura(284214, IsBoss) 	-- Trample
		-- Conclave of the Chosen
		DefineAura(286811, IsBoss) 	-- Akunda's Wrath
		DefineAura(282592, IsBoss) 	-- Bleeding Wounds
		DefineAura(284663, IsBoss) 	-- Bwonsamdi's Wrath
		DefineAura(282135, IsBoss) 	-- Crawling Hex
		DefineAura(286060, IsBoss) 	-- Cry of the Fallen
		DefineAura(282447, IsBoss) 	-- Kimbul's Wrath
		DefineAura(282834, IsBoss) 	-- Kimbul's Wrath
		DefineAura(282444, IsBoss) 	-- Lacerating Claws
		DefineAura(282209, IsBoss) 	-- Mark of Prey
		DefineAura(285879, IsBoss) 	-- Mind Wipe
		DefineAura(286838, IsBoss) 	-- Static Orb

	-- BFA: Crucible of Storms
	------------------------------------------------------------------------
		-- The Restless Cabal
		DefineAura(282386, IsBoss) 	-- Aphotic Blast
		DefineAura(282432, IsBoss) 	-- Crushing Doubt
		DefineAura(282561, IsBoss) 	-- Dark Herald
		DefineAura(282589, IsBoss) 	-- Mind Scramble
		DefineAura(292826, IsBoss) 	-- Mind Scramble
		DefineAura(282566, IsBoss) 	-- Promises of Power
		DefineAura(282384, IsBoss) 	-- Shear Mind
		-- Fathuul the Feared
		DefineAura(284733, IsBoss) 	-- Embrace of the Void
		DefineAura(286457, IsBoss) 	-- Feedback: Ocean
		DefineAura(286458, IsBoss) 	-- Feedback: Storm
		DefineAura(286459, IsBoss) 	-- Feedback: Void
		DefineAura(285652, IsBoss) 	-- Insatiable Torment
		DefineAura(285345, IsBoss) 	-- Maddening Eyes of N'Zoth
		DefineAura(285477, IsBoss) 	-- Obscurity
		DefineAura(285367, IsBoss) 	-- Piercing Gaze of N'Zoth
		DefineAura(284851, IsBoss) 	-- Touch of the End
		DefineAura(284722, IsBoss) 	-- Umbral Shell

	-- BFA: Eternal Palace
	------------------------------------------------------------------------
		-- Lady Ashvane
		DefineAura(296942, IsBoss) 	-- Arcing Azerite
		DefineAura(296938, IsBoss) 	-- Arcing Azerite
		DefineAura(296941, IsBoss) 	-- Arcing Azerite
		DefineAura(296939, IsBoss) 	-- Arcing Azerite
		DefineAura(296943, IsBoss) 	-- Arcing Azerite
		DefineAura(296940, IsBoss) 	-- Arcing Azerite
		DefineAura(296725, IsBoss) 	-- Barnacle Bash
		DefineAura(297333, IsBoss) 	-- Briny Bubble
		DefineAura(297397, IsBoss) 	-- Briny Bubble
		DefineAura(296752, IsBoss) 	-- Cutting Coral
		DefineAura(296693, IsBoss) 	-- Waterlogged
		-- Abyssal Commander Sivara
		DefineAura(295850, IsBoss) 	-- Delirious
		DefineAura(295704, IsBoss) 	-- Frost Bolt
		DefineAura(294711, IsBoss) 	-- Frost Mark
		DefineAura(295807, IsBoss) 	-- Frozen
		DefineAura(300883, IsBoss) 	-- Inversion Sickness
		DefineAura(295348, IsBoss) 	-- Overflowing Chill
		DefineAura(295421, IsBoss) 	-- Overflowing Venom
		DefineAura(300701, IsBoss) 	-- Rimefrost
		DefineAura(300705, IsBoss) 	-- Septic Taint
		DefineAura(295705, IsBoss) 	-- Toxic Bolt
		DefineAura(294715, IsBoss) 	-- Toxic Brand
		DefineAura(294847, IsBoss) 	-- Unstable Mixture
		-- The Queens Court
		DefineAura(296851, IsBoss) 	-- Fanatical Verdict
		DefineAura(299914, IsBoss) 	-- Frenetic Charge
		DefineAura(300545, IsBoss) 	-- Mighty Rupture
		DefineAura(301830, IsBoss) 	-- Pashmar's Touch
		DefineAura(297836, IsBoss) 	-- Potent Spark
		DefineAura(304410, IsBoss) 	-- Repeat Performance
		DefineAura(303306, IsBoss) 	-- Sphere of Influence
		DefineAura(297586, IsBoss) 	-- Suffering
		-- Radiance of Azshara
		DefineAura(295920, IsBoss) 	-- Ancient Tempest
		DefineAura(296737, IsBoss) 	-- Arcane Bomb
		DefineAura(296746, IsBoss) 	-- Arcane Bomb
		DefineAura(296462, IsBoss) 	-- Squall Trap
		DefineAura(296566, IsBoss) 	-- Tide Fist
		-- Orgozoa
		DefineAura(298156, IsBoss) 	-- Desensitizing Sting
		DefineAura(298306, IsBoss) 	-- Incubation Fluid
		-- Blackwater Behemoth
		DefineAura(292127, IsBoss) 	-- Darkest Depths
		DefineAura(301494, IsBoss) 	-- Piercing Barb
		DefineAura(292138, IsBoss) 	-- Radiant Biomass
		DefineAura(292167, IsBoss) 	-- Toxic Spine
		-- Zaqul
		DefineAura(298192, IsBoss) 	-- Dark Beyond
		DefineAura(295249, IsBoss) 	-- Delirium Realm
		DefineAura(292963, IsBoss) 	-- Dread
		DefineAura(293509, IsBoss) 	-- Manifest Nightmares
		DefineAura(295495, IsBoss) 	-- Mind Tether
		DefineAura(295480, IsBoss) 	-- Mind Tether
		DefineAura(303819, IsBoss) 	-- Nightmare Pool
		DefineAura(294545, IsBoss) 	-- Portal of Madness
		DefineAura(295327, IsBoss) 	-- Shattered Psyche
		DefineAura(300133, IsBoss) 	-- Snapped
		-- Queen Azshara
		DefineAura(303657, IsBoss) 	-- Arcane Burst
		DefineAura(298781, IsBoss) 	-- Arcane Orb
		DefineAura(302999, IsBoss) 	-- Arcane Vulnerability
		DefineAura(302141, IsBoss) 	-- Beckon
		DefineAura(301078, IsBoss) 	-- Charged Spear
		DefineAura(298014, IsBoss) 	-- Cold Blast
		DefineAura(297907, IsBoss) 	-- Cursed Heart
		DefineAura(298018, IsBoss) 	-- Frozen
		DefineAura(299276, IsBoss) 	-- Sanction
		DefineAura(298756, IsBoss) 	-- Serrated Edge

	-- BFA: Nyalotha
	------------------------------------------------------------------------
		-- Wrathion
		DefineAura(313255, IsBoss) 	-- Creeping Madness (Slow Effect)
		DefineAura(306163, IsBoss) 	-- Incineration
		DefineAura(306015, IsBoss) 	-- Searing Armor [tank]
		-- Maut
		DefineAura(314337, IsBoss) 	-- Ancient Curse
		DefineAura(314992, IsBoss) 	-- Darin Essence
		DefineAura(307805, IsBoss) 	-- Devour Magic
		DefineAura(306301, IsBoss) 	-- Forbidden Mana
		DefineAura(307399, IsBoss) 	-- Shadow Claws [tank]
		-- Prophet Skitra
		DefineAura(306387, IsBoss) 	-- Shadow Shock
		DefineAura(313276, IsBoss) 	-- Shred Psyche
		-- Dark Inquisitor
		DefineAura(311551, IsBoss) 	-- Abyssal Strike [tank]
		DefineAura(306311, IsBoss) 	-- Soul Flay
		DefineAura(312406, IsBoss) 	-- Void Woken
		-- Hivemind
		DefineAura(313672, IsBoss) 	-- Acid Pool
		DefineAura(313461, IsBoss) 	-- Corrosion
		DefineAura(313460, IsBoss) 	-- Nullification
		-- Shadhar
		DefineAura(306929, IsBoss) 	-- Bubbling Breath
		DefineAura(307471, IsBoss) 	-- Crush [tank]
		DefineAura(307358, IsBoss) 	-- Debilitating Spit
		DefineAura(307472, IsBoss) 	-- Dissolve [tank]
		DefineAura(312530, IsBoss) 	-- Entropic Breath
		DefineAura(306928, IsBoss) 	-- Umbral Breath
		-- Drest
		DefineAura(310552, IsBoss) 	-- Mind Flay
		DefineAura(310358, IsBoss) 	-- Mutterings of Insanity
		DefineAura(310406, IsBoss) 	-- Void Glare
		DefineAura(310478, IsBoss) 	-- Void Miasma
		DefineAura(310277, IsBoss) 	-- Volatile Seed [tank]
		DefineAura(310309, IsBoss) 	-- Volatile Vulnerability
		-- Ilgy
		DefineAura(314396, IsBoss) 	-- Cursed Blood
		DefineAura(309961, IsBoss) 	-- Eye of Nzoth [tank]
		DefineAura(275269, IsBoss) 	-- Fixate
		DefineAura(310322, IsBoss) 	-- Morass of Corruption
		DefineAura(312486, IsBoss) 	-- Recurring Nightmare
		DefineAura(311401, IsBoss) 	-- Touch of the Corruptor
		-- Vexiona
		DefineAura(307421, IsBoss) 	-- Annihilation
		DefineAura(315932, IsBoss) 	-- Brutal Smash
		DefineAura(307359, IsBoss) 	-- Despair
		DefineAura(307317, IsBoss) 	-- Encroaching Shadows
		DefineAura(307284, IsBoss) 	-- Terrifying Presence
		DefineAura(307218, IsBoss) 	-- Twilight Decimator
		DefineAura(307019, IsBoss) 	-- Void Corruption [tank]
		-- Raden
		DefineAura(310019, IsBoss) 	-- Charged Bonds
		DefineAura(316065, IsBoss) 	-- Corrupted Existence
		DefineAura(313227, IsBoss) 	-- Decaying Wound
		DefineAura(315258, IsBoss) 	-- Dread Inferno
		DefineAura(306279, IsBoss) 	-- Insanity Exposure
		DefineAura(306819, IsBoss) 	-- Nullifying Strike [tank]
		DefineAura(306257, IsBoss) 	-- Unstable Vita
		-- Carapace
		DefineAura(316848, IsBoss) 	-- Adaptive Membrane
		DefineAura(315954, IsBoss) 	-- Black Scar [tank]
		DefineAura(306973, IsBoss) 	-- Madness
		DefineAura(313364, IsBoss) 	-- Mental Decay
		DefineAura(307044, IsBoss) 	-- Nightmare Antibody
		DefineAura(317627, IsBoss) 	-- Infinite Void
		-- Nzoth
		DefineAura(313400, IsBoss) 	-- Corrupted Mind
		DefineAura(317112, IsBoss) 	-- Evoke Anguish
		DefineAura(318442, IsBoss) 	-- Paranoia
		DefineAura(313793, IsBoss) 	-- Flames of Insanity
		DefineAura(316771, IsBoss) 	-- Mindwrack
		DefineAura(314889, IsBoss) 	-- Probe Mind
		DefineAura(318976, IsBoss) 	-- Stupefying Glare

	------------------------------------------------------------------------
	-- Shadowlands Dungeons
	-- *some auras might be under the wrong dungeon, 
	--  this is because wowhead doesn't always tell what casts this.
	------------------------------------------------------------------------
	-- SL: Halls of Atonement
	------------------------------------------------------------------------
		DefineAura(326891, IsBoss)	-- Anguish
		DefineAura(326874, IsBoss)	-- Ankle Bites
		DefineAura(325876, IsBoss)	-- Curse of Obliteration
		DefineAura(319603, IsBoss)	-- Curse of Stone
		DefineAura(323650, IsBoss)	-- Haunting Fixation
		DefineAura(329321, IsBoss)	-- Jagged Swipe 1
		DefineAura(344993, IsBoss)	-- Jagged Swipe 2
		DefineAura(340446, IsBoss)	-- Mark of Envy
		DefineAura(335338, IsBoss)	-- Ritual of Woe
		DefineAura(326632, IsBoss)	-- Stony Veins
		DefineAura(319611, IsBoss)	-- Turned to Stone

	-- SL: Mists of Tirna Scithe
	------------------------------------------------------------------------
		DefineAura(325224, IsBoss)	-- Anima Injection
		DefineAura(323043, IsBoss)	-- Bloodletting
		DefineAura(325027, IsBoss)	-- Bramble Burst
		DefineAura(326092, IsBoss)	-- Debilitating Poison
		DefineAura(321891, IsBoss)	-- Freeze Tag Fixation
		DefineAura(322563, IsBoss)	-- Marked Prey
		DefineAura(331172, IsBoss)	-- Mind Link
		DefineAura(325021, IsBoss)	-- Mistveil Tear
		DefineAura(322487, IsBoss)	-- Overgrowth 1
		DefineAura(322486, IsBoss)	-- Overgrowth 2
		DefineAura(328756, IsBoss)	-- Repulsive Visage
		DefineAura(322557, IsBoss)	-- Soul Split
		DefineAura(325418, IsBoss)	-- Volatile Acid

	-- SL: Plaguefall
	------------------------------------------------------------------------
		DefineAura(333406, IsBoss)	-- Assassinate
		DefineAura(322358, IsBoss)	-- Burning Strain
		DefineAura(330069, IsBoss)	-- Concentrated Plague
		DefineAura(320512, IsBoss)	-- Corroded Claws
		DefineAura(325552, IsBoss)	-- Cytotoxic Slash
		DefineAura(328180, IsBoss)	-- Gripping Infection
		DefineAura(340355, IsBoss)	-- Rapid Infection
		DefineAura(331818, IsBoss)	-- Shadow Ambush
		DefineAura(332397, IsBoss)	-- Shroudweb
		DefineAura(329110, IsBoss)	-- Slime Injection
		DefineAura(336258, IsBoss)	-- Solitary Prey
		DefineAura(328395, IsBoss)	-- Venompiercer
		DefineAura(320542, IsBoss)	-- Wasting Blight
		DefineAura(336301, IsBoss)	-- Web Wrap
		DefineAura(322410, IsBoss)	-- Withering Filth

	-- SL: The Necrotic Wake
	------------------------------------------------------------------------
		DefineAura(320717, IsBoss)	-- Blood Hunger
		DefineAura(324381, IsBoss)	-- Chill Scythe
		DefineAura(323365, IsBoss)	-- Clinging Darkness
		DefineAura(323198, IsBoss)	-- Dark Exile
		DefineAura(343504, IsBoss)	-- Dark Grasp
		DefineAura(323464, IsBoss)	-- Dark Ichor
		DefineAura(321821, IsBoss)	-- Disgusting Guts
		DefineAura(333485, IsBoss)	-- Disease Cloud
		DefineAura(334748, IsBoss)	-- Drain FLuids
		DefineAura(328181, IsBoss)	-- Frigid Cold
		DefineAura(338353, IsBoss)	-- Goresplatter
		DefineAura(343556, IsBoss)	-- Morbid Fixation 1
		DefineAura(338606, IsBoss)	-- Morbid Fixation 2
		DefineAura(320170, IsBoss)	-- Necrotic Bolt
		DefineAura(333489, IsBoss)	-- Necrotic Breath
		DefineAura(333492, IsBoss)	-- Necrotic Ichor
		DefineAura(320573, IsBoss)	-- Shadow Well
		DefineAura(338357, IsBoss)	-- Tenderize

	-- SL: Theater of Pain
	------------------------------------------------------------------------
		DefineAura(342675, IsBoss)	-- Bone Spear
		DefineAura(333299, IsBoss)	-- Curse of Desolation 1
		DefineAura(333301, IsBoss)	-- Curse of Desolation 2
		DefineAura(323831, IsBoss)	-- Death Grasp
		DefineAura(330700, IsBoss)	-- Decaying Blight
		DefineAura(326892, IsBoss)	-- Fixate
		DefineAura(323825, IsBoss)	-- Grasping Rift
		DefineAura(323406, IsBoss)	-- Jagged Gash
		DefineAura(324449, IsBoss)	-- Manifest Death
		DefineAura(330868, IsBoss)	-- Necrotic Bolt Volley
		DefineAura(321768, IsBoss)	-- On the Hook
		DefineAura(319626, IsBoss)	-- Phantasmal Parasite
		DefineAura(319539, IsBoss)	-- Soulless
		DefineAura(330608, IsBoss)	-- Vile Eruption
		DefineAura(323750, IsBoss)	-- Vile Gas
		DefineAura(341949, IsBoss)	-- Withering Blight

	-- SL: Sanguine Depths
	------------------------------------------------------------------------
		DefineAura(328593, IsBoss)	-- Agonize
		DefineAura(335306, IsBoss)	-- Barbed Shackles
		DefineAura(321038, IsBoss)	-- Burden Soul
		DefineAura(322554, IsBoss)	-- Castigate
		DefineAura(326836, IsBoss)	-- Curse of Suppression
		DefineAura(326827, IsBoss)	-- Dread Bindings
		DefineAura(334653, IsBoss)	-- Engorge
		DefineAura(325254, IsBoss)	-- Iron Spikes
		DefineAura(322429, IsBoss)	-- Severing Slice

	-- SL: Spires of Ascension
	------------------------------------------------------------------------
		DefineAura(323792, IsBoss)	-- Anima Field
		DefineAura(324205, IsBoss)	-- Blinding Flash
		DefineAura(338729, IsBoss)	-- Charged Stomp
		DefineAura(327481, IsBoss)	-- Dark Lance
		DefineAura(331251, IsBoss)	-- Deep Connection
		DefineAura(328331, IsBoss)	-- Forced Confession
		DefineAura(317661, IsBoss)	-- Insidious Venom
		DefineAura(328434, IsBoss)	-- Intimidated
		DefineAura(322817, IsBoss)	-- Lingering Doubt
		DefineAura(322818, IsBoss)	-- Lost Confidence
		DefineAura(338747, IsBoss)	-- Purifying Blast
		DefineAura(330683, IsBoss)	-- Raw Anima
		DefineAura(341215, IsBoss)	-- Volatile Anima

	-- SL: De Other Side
	------------------------------------------------------------------------
		DefineAura(323687, IsBoss)	-- Arcane Lightning
		DefineAura(323692, IsBoss)	-- Arcane Vulnerability
		DefineAura(334535, IsBoss)	-- Beak Slice
		DefineAura(330434, IsBoss)	-- Buzz-Saw 1
		DefineAura(320144, IsBoss)	-- Buzz-Saw 2
		DefineAura(322746, IsBoss)	-- Corrupted Blood
		DefineAura(325725, IsBoss)	-- Cosmic Artifice
		DefineAura(327649, IsBoss)	-- Crushed Soul
		DefineAura(323877, IsBoss)	-- Echo Finger Laser X-treme
		DefineAura(332678, IsBoss)	-- Gushing Wound
		DefineAura(331379, IsBoss)	-- Lubricate
		DefineAura(334913, IsBoss)	-- Master of Death
		DefineAura(339978, IsBoss)	-- Pacifying Mists
		DefineAura(320786, IsBoss)	-- Power Overwhelming
		DefineAura(333250, IsBoss)	-- Reaver
		DefineAura(334496, IsBoss)	-- Soporific Shimmerdust
		DefineAura(331847, IsBoss)	-- W-00F
		DefineAura(328987, IsBoss)	-- Zealous

	-- SL: Castle Nathria
	------------------------------------------------------------------------
		-- Shriekwing
		DefineAura(329370, IsBoss)	-- Deadly Descent
		DefineAura(336494, IsBoss)	-- Echo Screech
		DefineAura(328897, IsBoss)	-- Exsanguinated
		DefineAura(330713, IsBoss)	-- Reverberating Pain
		-- Huntsman Altimor
		DefineAura(334945, IsBoss)	-- Bloody Thrash
		DefineAura(334860, IsBoss)	-- Crushing Stone (Hecutis)
		DefineAura(335111, IsBoss)	-- Huntsman's Mark 1
		DefineAura(335112, IsBoss)	-- Huntsman's Mark 2
		DefineAura(335113, IsBoss)	-- Huntsman's Mark 3
		DefineAura(334971, IsBoss)	-- Jagged Claws
		DefineAura(335304, IsBoss)	-- Sinseeker
		-- Hungering Destroyer
		DefineAura(329298, IsBoss)	-- Gluttonous Miasma
		DefineAura(334228, IsBoss)	-- Volatile Ejection
		-- Lady Inerva Darkvein
		DefineAura(332664, IsBoss)	-- Concentrate Anima
		DefineAura(335396, IsBoss)	-- Hidden Desire
		DefineAura(325936, IsBoss)	-- Shared Cognition
		DefineAura(324983, IsBoss)	-- Shared Suffering
		DefineAura(324982, IsBoss)	-- Shared Suffering (Partner)
		DefineAura(325382, IsBoss)	-- Warped Desires
		-- Sun King's Salvation
		DefineAura(326078, IsBoss)	-- Infuser's Boon
		DefineAura(325251, IsBoss)	-- Sin of Pride
		DefineAura(333002, IsBoss)	-- Vulgar Brand
		-- Artificer Xy'mox
		DefineAura(327902, IsBoss)	-- Fixate
		DefineAura(325236, IsBoss)	-- Glyph of Destruction
		DefineAura(327414, IsBoss)	-- Possession
		DefineAura(326302, IsBoss)	-- Stasis Trap
		-- The Council of Blood
		DefineAura(331636, IsBoss)	-- Dark Recital 1
		DefineAura(331637, IsBoss)	-- Dark Recital 2
		DefineAura(327052, IsBoss)	-- Drain Essence 1
		DefineAura(327773, IsBoss)	-- Drain Essence 2
		DefineAura(346651, IsBoss)	-- Drain Essence Mythic
		DefineAura(331706, IsBoss)	-- Scarlet Letter
		DefineAura(328334, IsBoss)	-- Tactical Advance
		DefineAura(330848, IsBoss)	-- Wrong Moves
		-- Sludgefist
		DefineAura(335293, IsBoss)	-- Chain Link
		DefineAura(335270, IsBoss)	-- Chain This One!
		DefineAura(335470, IsBoss)	-- Chain Slam
		DefineAura(339181, IsBoss)	-- Chain Slam (Root)
		DefineAura(331209, IsBoss)	-- Hateful Gaze
		DefineAura(335295, IsBoss)	-- Shattering Chain
		-- Stone Legion Generals
		DefineAura(339690, IsBoss)	-- Crystalize
		DefineAura(334541, IsBoss)	-- Curse of Petrification
		DefineAura(334765, IsBoss)	-- Heart Rend
		DefineAura(334616, IsBoss)	-- Petrified
		DefineAura(334498, IsBoss)	-- Seismic Upheaval
		DefineAura(337643, IsBoss)	-- Unstable Footing
		DefineAura(342655, IsBoss)	-- Volatile Anima Infusion
		DefineAura(342698, IsBoss)	-- Volatile Anima Infection
		DefineAura(333377, IsBoss)	-- Wicked Mark
		-- Sire Denathrius
		DefineAura(326851, IsBoss)	-- Blood Price
		DefineAura(326699, IsBoss)	-- Burden of Sin
		DefineAura(327992, IsBoss)	-- Desolation
		DefineAura(329951, IsBoss)	-- Impale
		DefineAura(328276, IsBoss)	-- March of the Penitent
		DefineAura(327796, IsBoss)	-- Night Hunter
		DefineAura(335873, IsBoss)	-- Rancor
		DefineAura(329181, IsBoss)	-- Wracking Pain

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
