local LibFrame = Wheel("LibFrame")
assert(LibFrame, "ClassPower requires LibFrame to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "UnitAltPower requires LibClientBuild to be loaded.")

-- Lua API
local _G = _G
local setmetatable = setmetatable
local table_sort = table.sort

-- WoW API
local Enum = Enum
local GetComboPoints = GetComboPoints
local GetRuneCooldown = GetRuneCooldown
local GetSpecialization = GetSpecialization
local HasOverrideActionBar = HasOverrideActionBar
local HasTempShapeshiftActionBar = HasTempShapeshiftActionBar
local IsPlayerSpell = IsPlayerSpell
local IsPossessBarVisible = IsPossessBarVisible
local PlayerVehicleHasComboPoints = PlayerVehicleHasComboPoints
local UnitAffectingCombat = UnitAffectingCombat
local UnitAura = UnitAura
local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitHasVehiclePlayerFrameUI = UnitHasVehiclePlayerFrameUI
local UnitInVehicle = UnitInVehicle
local UnitIsFriend = UnitIsFriend
local UnitIsPlayer = UnitIsPlayer
local UnitLevel = UnitLevel
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerDisplayMod = UnitPowerDisplayMod
local UnitPowerType = UnitPowerType
local UnitStagger = UnitStagger

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsTBC = LibClientBuild:IsTBC()
local IsRetail = LibClientBuild:IsRetail()

-- WoW Constants
-- Sourced from BlizzardInterfaceCode/Interface/FrameXML/Constants.lua
local SHOW_SPEC_LEVEL = SHOW_SPEC_LEVEL or 10
local SPEC_WARLOCK_AFFLICTION = SPEC_WARLOCK_AFFLICTION or 1
local SPEC_WARLOCK_DEMONOLOGY = SPEC_WARLOCK_DEMONOLOGY or 2
local SPEC_WARLOCK_DESTRUCTION = SPEC_WARLOCK_DESTRUCTION or 3
local SPEC_PRIEST_SHADOW = SPEC_PRIEST_SHADOW or 3
local SPEC_MONK_MISTWEAVER = SPEC_MONK_MISTWEAVER or 2
local SPEC_MONK_BREWMASTER = SPEC_MONK_BREWMASTER or 1
local SPEC_MONK_WINDWALKER = SPEC_MONK_WINDWALKER or 3
local SPEC_PALADIN_HOLY = SPEC_PALADIN_HOLY or 2 -- we made this up
local SPEC_PALADIN_RETRIBUTION = SPEC_PALADIN_RETRIBUTION or 3
local SPEC_MAGE_ARCANE = SPEC_MAGE_ARCANE or 1
local SPEC_SHAMAN_RESTORATION = SPEC_SHAMAN_RESTORATION or 3
local SPEC_DEMONHUNTER_VENGEANCE = SPEC_DEMONHUNTER_VENGEANCE or 2 -- made this on up too

-- Sourced from BlizzardInterfaceCode/AddOns/Blizzard_APIDocumentation/UnitDocumentation.lua
local SPELL_POWER_HEALTH_COST = Enum.PowerType.HealthCost or -2
local SPELL_POWER_NONE= Enum.PowerType.None or -1
local SPELL_POWER_MANA = Enum.PowerType.Mana or 0
local SPELL_POWER_RAGE = Enum.PowerType.Rage or 1
local SPELL_POWER_FOCUS = Enum.PowerType.Focus or 2
local SPELL_POWER_ENERGY = Enum.PowerType.Energy or 3
local SPELL_POWER_COMBO_POINTS = Enum.PowerType.ComboPoints or 4
local SPELL_POWER_RUNES = Enum.PowerType.Runes or 5
local SPELL_POWER_RUNIC_POWER = Enum.PowerType.RunicPower or 6
local SPELL_POWER_SOUL_SHARDS = Enum.PowerType.SoulShards or 7
local SPELL_POWER_LUNAR_POWER = Enum.PowerType.LunarPower or 8
local SPELL_POWER_HOLY_POWER = Enum.PowerType.HolyPower or 9
local SPELL_POWER_ = Enum.PowerType.Alternate or 10
local SPELL_POWER_MAELSTROM_POWER = Enum.PowerType.Maelstrom or 11
local SPELL_POWER_CHI = Enum.PowerType.Chi or 12
local SPELL_POWER_INSANITY = Enum.PowerType.Insanity or 13
local SPELL_POWER_OBSOLETE = Enum.PowerType.Obsolete or 14
local SPELL_POWER_OBSOLETE2 = Enum.PowerType.Obsolete2 or 15
local SPELL_POWER_ARCANE_CHARGES = Enum.PowerType.ArcaneCharges or 16
local SPELL_POWER_FURY = Enum.PowerType.Fury or 17
local SPELL_POWER_PAIN = Enum.PowerType.Pain or 18

-- Sourced from BlizzardInterfaceCode/Interface/FrameXML/MonkStaggerBar.lua
-- percentages at which bar should change color
local STAGGER_YELLOW_TRANSITION = STAGGER_YELLOW_TRANSITION or .3
local STAGGER_RED_TRANSITION = STAGGER_RED_TRANSITION or .6

-- table indices of bar colors
local STAGGER_GREEN_INDEX = STAGGER_GREEN_INDEX or 1
local STAGGER_YELLOW_INDEX = STAGGER_YELLOW_INDEX or 2
local STAGGER_RED_INDEX = STAGGER_RED_INDEX or 3

-- Sourced from FrameXML/TargetFrame.lua
local MAX_COMBO_POINTS = MAX_COMBO_POINTS or 5

-- AuraIDs
local SOUL_FRAGMENTS_ID = 203981
local SOUL_FRAGMENTS_IDs = {
	[203981] = true
}

-- Class specific info
local _, PLAYERCLASS = UnitClass("player")

-- Declare core function names so we don't 
-- have to worry about the order we put them in.
local Proxy, ForceUpdate, Update, UpdatePowerType

-- Generic methods used by multiple powerTypes
local Generic = setmetatable({
	EnablePower = function(self)
		local element = self.ClassPower

		for i = 1, #element do 
			element[i]:SetMinMaxValues(0,1)
			element[i]:SetValue(0)
			element[i]:Hide()
		end 

		if (element.alphaNoCombat) or (element.alphaNoCombatRunes) then 
			self:RegisterEvent("PLAYER_REGEN_DISABLED", Proxy, true)
			self:RegisterEvent("PLAYER_REGEN_ENABLED", Proxy, true)
		end 
		--self:RegisterEvent("PLAYER_TARGET_CHANGED", Proxy, true)
		
	end,
	DisablePower = function(self)
		local element = self.ClassPower
		element.powerID = nil
		element.isEnabled = false
		element.max = 0
		element.maxDisplayed = nil
		element:Hide()

		for i = 1, #element do 
			element[i]:Hide()
			element[i]:SetMinMaxValues(0,1)
			element[i]:SetValue(0)
			element[i]:SetScript("OnUpdate", nil)
		end 

		self:UnregisterEvent("PLAYER_REGEN_DISABLED", Proxy)
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", Proxy)
		--self:UnregisterEvent("PLAYER_TARGET_CHANGED", Proxy)
	end, 
	UpdatePower = function(self, event, unit, ...)
		local element = self.ClassPower
		if (not element.isEnabled) then 
			element:Hide()
			return 
		end 

		local powerType = element.powerType
		local powerID = element.powerID 

		local min = UnitPower("player", powerID) or 0
		local max = UnitPowerMax("player", powerID) or 0

		local maxDisplayed = element.maxDisplayed or element.max or max


		for i = 1, maxDisplayed do 
			local point = element[i]
			if (point) then
				if (not point:IsShown()) then 
					point:Show()
				end 
				point:SetValue(min >= i and 1 or 0)
			end
		end 

		for i = maxDisplayed+1, #element do 
			element[i]:SetValue(0)
			if element[i]:IsShown() then 
				element[i]:Hide()
			end 
		end 

		return min, max, powerType
	end, 
	UpdateColor = function(element, unit, min, max, powerType)
		local self = element._owner
		local color = self.colors.power[powerType] 
		local colorMultiple = element.useAlternateColoring and self.colors.power[powerType.."_MULTIPLE"]
		local r, g, b = color[1], color[2], color[3]
		local maxDisplayed = element.maxDisplayed or element.max or max

		-- Class Color Overrides
		local _,unitClass = UnitClass(unit)
		if (element.colorClass and UnitIsPlayer(unit)) then
			color = unitClass and self.colors.class[unitClass]
			r, g, b = color[1], color[2], color[3]
		end 

		-- Decide on visibility
		-- Has the module chosen to hide all when empty?
		local hidden = element.hideWhenEmpty and (min == 0)
		if (not hidden) then
			-- Is the current power type one to keep visible?
			local keepShown = (powerType == "SOUL_FRAGMENTS") or ((powerType == "HOLY_POWER") and (GetSpecialization() == SPEC_PALADIN_HOLY)) 
			if (not keepShown) then
				hidden = (
					-- Has the module chosen to only show this with an active target?
					(element.hideWhenNoTarget and (not UnitExists("target"))) or 

					-- Has the module chosen to only show this with a hostile target?
					(element.hideWhenUnattackable and (not UnitCanAttack("player", "target")))
				)
			end
		end

		-- We decided to hide them all.
		if (hidden) then
			for i = 1, maxDisplayed do
				local point = element[i]
				if (point) then
					point:SetAlpha(0)
				end 
			end 
		end

		if (not hidden) then 
			-- In case there are more points active 
			-- then the currently allowed maximum. 
			-- Meant to give an easy system to handle 
			-- the Rogue Anticipation talent without 
			-- the need for the module to write extra code. 
			local overflow
			if min > maxDisplayed then 
				overflow = min % maxDisplayed
			end 
			for i = 1, maxDisplayed do
				local point = element[i]
				if (point) then

					-- upvalue to preserve the original colors for the next point
					local r, g, b = r, g, b 
					local multi = colorMultiple and colorMultiple[i]
					if (multi) then
						r, g, b = multi[1], multi[2], multi[3]
					end

					-- Handle overflow coloring
					if (overflow) then
						if (i > overflow) then
							-- tone down "old" points
							r, g, b = r*1/3, g*1/3, b*1/3 
						else 
							-- brighten the overflow points
							r = (1-r)*1/3 + r
							g = (1-g)*1/4 + g -- always brighten the green slightly less
							b = (1-b)*1/3 + b
						end 
					end 

					if (element.alphaNoCombat) then 
						point:SetStatusBarColor(r, g, b)
						if (point.bg) then 
							local mult = element.backdropMultiplier or 1/3
							point.bg:SetVertexColor(r*mult, g*mult, b*mult)
						end 
						local alpha = UnitAffectingCombat("player") and 1 or element.alphaNoCombat
						if (i > min) and (element.alphaEmpty) then
							point:SetAlpha(element.alphaEmpty * alpha)
						else 
							point:SetAlpha(alpha)
						end 
					else 
						point:SetStatusBarColor(r, g, b, 1)
						if (point.bg) then 
							local mult = element.backdropMultiplier or 1/3
							point.bg:SetVertexColor(r*mult, g*mult, b*mult)
						end 
						if (element.alphaEmpty) then 
							point:SetAlpha(min > i and element.alphaEmpty or 1)
						else 
							point:SetAlpha(1)
						end 
					end 
				end
			end
		end 
	end
}, { __index = LibFrame:CreateFrame("Frame") })
local Generic_MT = { __index = Generic }

-- Specific powerTypes
local ClassPower = {}
ClassPower.None = setmetatable({
	EnablePower = function(self)
		local element = self.ClassPower
		if (element) then
			for i = 1, #element do
				element[i]:SetMinMaxValues(0,1)
				element[i]:SetValue(0)
				element[i]:Hide()
			end
			element:Hide()
		end
	end, 
	DisablePower = function() end,
	UpdatePower = function() end,
	UpdateColor = function() end,
}, { __index = LibFrame:CreateFrame("Frame") })

ClassPower.ComboPoints = setmetatable({ 
	ShouldEnable = function(self)
		local element = self.ClassPower
		if (PLAYERCLASS == "DRUID") then 
			local powerType = UnitPowerType("player")
			if (powerType == SPELL_POWER_ENERGY) then 
				return true
			end 
		else 
			return true
		end 
	end,
	EnablePower = function(self)
		local element = self.ClassPower
		element.powerID = SPELL_POWER_COMBO_POINTS
		element.powerType = "COMBO_POINTS"
		element.maxDisplayed = element.maxComboPoints or MAX_COMBO_POINTS or 5

		if (PLAYERCLASS == "DRUID") then 
			element.isEnabled = element.ShouldEnable(self)
			self:RegisterEvent("SPELLS_CHANGED", Proxy, true)
		else 
			element.isEnabled = true
		end 

		self:RegisterEvent("UNIT_POWER_FREQUENT", Proxy)
		self:RegisterEvent("UNIT_MAXPOWER", Proxy)
	
		Generic.EnablePower(self)
	end,
	DisablePower = function(self)
		self:UnregisterEvent("SPELLS_CHANGED", Proxy)
		self:UnregisterEvent("UNIT_POWER_FREQUENT", Proxy)
		self:UnregisterEvent("UNIT_MAXPOWER", Proxy)

		Generic.DisablePower(self)
	end, 
	UpdatePower = function(self, event, unit, ...)
		local element = self.ClassPower
		local min, max

		if (PLAYERCLASS == "DRUID") then
			if (event == "SPELLS_CHANGED") or (event == "UNIT_DISPLAYPOWER") then 
				element.isEnabled = element.ShouldEnable(self)
			end 
		end
		min = UnitPower("player", element.powerID) or 0
		max = UnitPowerMax("player", element.powerID) or 0
		if (not element.isEnabled) then 
			element:Hide()
			return 
		end 

		local maxDisplayed = element.maxDisplayed or element.max or max

		for i = 1, maxDisplayed do 
			local point = element[i]
			if (point) then
				if (not point:IsShown()) then 
					point:Show()
				end 
				local value = min >= i and 1 or 0
				point:SetValue(value)
			end
		end 

		for i = maxDisplayed+1, #element do 
			element[i]:SetValue(0)
			if (element[i]:IsShown()) then 
				element[i]:Hide()
			end 
		end 

		return min, max, element.powerType
	end
}, Generic_MT)

-- Class resources only available in retail
if (IsRetail) then

	ClassPower.ArcaneCharges = setmetatable({ 
		EnablePower = function(self)
			local element = self.ClassPower
			element.powerID = SPELL_POWER_ARCANE_CHARGES
			element.powerType = "ARCANE_CHARGES"
			element.isEnabled = true
			element.maxDisplayed = 4

			self:RegisterEvent("UNIT_POWER_FREQUENT", Proxy)
			self:RegisterEvent("UNIT_MAXPOWER", Proxy)

			Generic.EnablePower(self)
		end,
		DisablePower = function(self)
			self:UnregisterEvent("UNIT_POWER_FREQUENT", Proxy)
			self:UnregisterEvent("UNIT_MAXPOWER", Proxy)

			Generic.DisablePower(self)
		end
	}, Generic_MT)

	ClassPower.Chi = setmetatable({ 
		EnablePower = function(self)
			local element = self.ClassPower
			element.powerID = SPELL_POWER_CHI
			element.powerType = "CHI"
			element.isEnabled = true
			element.maxDisplayed = UnitPowerMax("player", element.powerID) or element.maxComboPoints or 5

			self:RegisterEvent("UNIT_POWER_FREQUENT", Proxy)
			self:RegisterEvent("UNIT_MAXPOWER", Proxy)

			Generic.EnablePower(self)
		end,
		DisablePower = function(self)
			self:UnregisterEvent("UNIT_POWER_FREQUENT", Proxy)
			self:UnregisterEvent("UNIT_MAXPOWER", Proxy)

			Generic.DisablePower(self)
		end,
		UpdatePower = function(self)
			local element = self.ClassPower
			if (UnitPowerMax("player", element.powerID) == 6) then
				element.maxDisplayed =  6
			else
				element.maxDisplayed =  element.maxComboPoints or 5
			end
			return Generic.UpdatePower(self)
		end
	}, Generic_MT)

	ClassPower.HolyPower = setmetatable({ 
		EnablePower = function(self)
			local element = self.ClassPower
			element.powerID = SPELL_POWER_HOLY_POWER
			element.powerType = "HOLY_POWER"
			element.isEnabled = true
			element.maxDisplayed = element.maxComboPoints or 5

			self:RegisterEvent("UNIT_POWER_FREQUENT", Proxy)
			self:RegisterEvent("UNIT_MAXPOWER", Proxy)

			Generic.EnablePower(self)
		end,
		DisablePower = function(self)
			self:UnregisterEvent("UNIT_POWER_FREQUENT", Proxy)
			self:UnregisterEvent("UNIT_MAXPOWER", Proxy)

			Generic.DisablePower(self)
		end
	}, Generic_MT)

	ClassPower.Runes = setmetatable({ 

		EnablePower = function(self)
			local element = self.ClassPower
			element.powerID = SPELL_POWER_RUNES
			element.powerType = "RUNES"
			element.max = 6 -- no global value exists for this
			element.maxDisplayed = nil -- don't limit this by default
			element.runeOrder = { 1, 2, 3, 4, 5, 6 } -- starting with a numeric order
			element.isEnabled = true

			self:RegisterEvent("RUNE_POWER_UPDATE", Proxy, true)

			Generic.EnablePower(self)
		end,
		DisablePower = function(self)
			local element = self.ClassPower
			element.runeOrder = nil
			for i = 1, #element do 
				element[i]:SetScript("OnUpdate", nil)
			end 
			Generic.DisablePower(self)
		end, 
		SortByTimeAsc = function(runeAID, runeBID)
			local runeAStart, _, runeARuneReady = GetRuneCooldown(runeAID)
			local runeBStart, _, runeBRuneReady = GetRuneCooldown(runeBID)
			if (runeARuneReady ~= runeBRuneReady) then
				return runeARuneReady
			elseif (runeAStart ~= runeBStart) then
				return runeAStart < runeBStart
			else
				return runeAID < runeBID
			end
		end,
		SortByTimeDesc = function(runeAID, runeBID)
			local runeAStart, _, runeARuneReady = GetRuneCooldown(runeAID)
			local runeBStart, _, runeBRuneReady = GetRuneCooldown(runeBID)
			if (runeARuneReady ~= runeBRuneReady) then
				return runeBRuneReady
			elseif (runeAStart ~= runeBStart) then
				return runeAStart > runeBStart
			else
				return runeAID > runeBID
			end
		end,
		OnUpdateRune = function(rune, elapsed)
			rune.duration = rune.duration + elapsed
			rune:SetValue(rune.duration, true)
		end,
		UpdatePower = function(self, event, unit, ...)
			local element = self.ClassPower
			if (not element.isEnabled) then 
				element:Hide()
				return 
			end 

			if (element.runeSortOrder == "ASC") then
				table_sort(element.runeOrder, element.SortByTimeAsc)
				element.hasSortOrder = true

			elseif (element.runeSortOrder == "DESC") then
				table_sort(element.runeOrder, element.SortByTimeDesc)
				element.hasSortOrder = true

			elseif (element.hasSortOrder) then
				table_sort(element.runeOrder)
				element.hasSortOrder = false
			end

			local min = 0 -- available runes
			local max = UnitPowerMax("player", element.powerID) or 0 -- maximum available runes
			local maxDisplayed = element.max or max -- maximum displayed runes

			-- Update runes
			local runeID, rune, start, duration, runeReady
			for id = 1,#element.runeOrder do
				runeID = element.runeOrder[id]
				rune = element[id]

				if (not rune) then 
					break 
				end
				
				start, duration, runeReady = GetRuneCooldown(runeID)
				if (runeReady) then
					rune:SetScript("OnUpdate", nil)
					rune:SetMinMaxValues(0, 1)
					rune:SetValue(1, true)

					-- update count of available runes
					min = min + 1

				elseif (start) then
					rune.duration = GetTime() - start
					rune:SetMinMaxValues(0, duration, true)
					rune:SetValue(0, true)
					rune:SetScript("OnUpdate", element.OnUpdateRune)

				end
			end

			-- Make sure the runes are shown
			for i = 1, maxDisplayed do 
				local rune = element[i]
				if (rune) then
					if (not rune:IsShown()) then 
						rune:Show()
					end 
				end
			end 

			-- Hide additional points in the classpower element, if any
			for i = maxDisplayed + 1, #element do 
				local rune = element[i]
				if (rune) then
					rune:SetValue(0)
					if (rune:IsShown()) then 
						rune:Hide()
					end 
				end
			end 

			return min, max, element.powerType
		end, 
		UpdateColor = function(element, unit, min, max, powerType)
			local self = element._owner
			local color = self.colors.power[powerType]
			local r, g, b = color[1], color[2], color[3]
			local maxDisplayed = element.max or max

			-- Class Color Overrides
			if (element.colorClass and UnitIsPlayer(unit)) then
				local _, class = UnitClass(unit)
				color = class and self.colors.class[class]
				r, g, b = color[1], color[2], color[3]
			end 
			
			-- Ready ones fully opaque, charging ones toned down, everything even more without a hostile target
			if (UnitAffectingCombat("player") or UnitAffectingCombat("pet")) then 
				local chargingAlpha = element.alphaEmpty or .5
				local fullAlpha = 1
				for i = 1, maxDisplayed do
					local point = element[i]
					if (point) then
						point:SetStatusBarColor(r, g, b)
						point:SetAlpha(i > min and chargingAlpha or fullAlpha)
						if (point.bg) then 
							local mult = element.backdropMultiplier or 1/3
							point.bg:SetVertexColor(r*mult, g*mult, b*mult)
						end 
					end
				end

			-- All are toned down, charging/empty ones even more
			elseif (min < maxDisplayed) or (UnitExists("target") and not UnitIsFriend("player", "target")) then 
				local chargingAlpha = (element.alphaEmpty or .5)*(element.alphaNoCombatRunes or element.alphaNoCombat or .5)
				local fullAlpha = element.alphaNoCombatRunes or element.alphaNoCombat or .5
				for i = 1, maxDisplayed do
					local point = element[i]
					if (point) then 
						point:SetStatusBarColor(r, g, b)
						point:SetAlpha(i > min and chargingAlpha or fullAlpha)
						if (point.bg) then 
							local mult = element.backdropMultiplier or 1/3
							point.bg:SetVertexColor(r*mult, g*mult, b*mult)
						end 
					end
				end

			-- Hidden
			else
				for i = 1, maxDisplayed do
					local point = element[i]
					if (point) then
						point:SetStatusBarColor(r, g, b)
						point:SetAlpha(element.alphaWhenHiddenRunes or 0)
						if (point.bg) then 
							local mult = element.backdropMultiplier or 1/3
							point.bg:SetVertexColor(r*mult, g*mult, b*mult)
						end 
					end 
				end 
			end
		end
	}, Generic_MT)

	ClassPower.SoulFragments = setmetatable({ 
		EnablePower = function(self)
			local element = self.ClassPower
			element.powerType = "SOUL_FRAGMENTS"
			element.maxDisplayed = 5
			element.isEnabled = true

			self:RegisterEvent("UNIT_AURA", Proxy)

			Generic.EnablePower(self)
		end,
		DisablePower = function(self)
			self:UnregisterEvent("UNIT_AURA", Proxy)

			Generic.DisablePower(self)
		end,
		UpdatePower = function(self, event, unit, ...)
			local element = self.ClassPower
			if (not element.isEnabled) then 
				element:Hide()
				return 
			end 

			local powerType = element.powerType
			local min = 0
			local max = 5

			-- Scan buffs
			local id = 1
			while (true) do
				local name, _, count, _, _, _, _, _, _, spellID = UnitAura("player", id, "HELPFUL")
				if (not name) then 
					break 
				end
				if (spellID) and ((spellID == SOUL_FRAGMENTS_ID) or (SOUL_FRAGMENTS_IDs[spellID])) then
					min = count
				end
				id = id + 1
			end

			local maxDisplayed = element.maxDisplayed or element.max or max
			for i = 1, maxDisplayed do 
				local point = element[i]
				if (point) then
					if (not point:IsShown()) then 
						point:Show()
					end 
					point:SetValue(min >= i and 1 or 0)
				end
			end 

			for i = maxDisplayed + 1, #element do 
				element[i]:SetValue(0)
				if (element[i]:IsShown()) then 
					element[i]:Hide()
				end 
			end 

			return min, max, powerType
		end,
	}, Generic_MT)

	ClassPower.SoulShards = setmetatable({ 
		EnablePower = function(self)
			local element = self.ClassPower
			element.powerID = SPELL_POWER_SOUL_SHARDS
			element.powerType = "SOUL_SHARDS"
			element.maxDisplayed = element.maxComboPoints or 5
			element.isEnabled = true

			self:RegisterEvent("UNIT_POWER_FREQUENT", Proxy)
			self:RegisterEvent("UNIT_MAXPOWER", Proxy)

			Generic.EnablePower(self)
		end,
		DisablePower = function(self)
			self:UnregisterEvent("UNIT_POWER_FREQUENT", Proxy)
			self:UnregisterEvent("UNIT_MAXPOWER", Proxy)

			Generic.DisablePower(self)
		end,
		UpdatePower = function(self, event, unit, ...)
			local element = self.ClassPower
			if (not element.isEnabled) then 
				element:Hide()
				return 
			end 

			local powerType = element.powerType
			local powerID = element.powerID 

			local min = UnitPower("player", powerID, true) or 0
			local max = UnitPowerMax("player", powerID) or 0
			local mod = UnitPowerDisplayMod(powerID)

			-- mod should never be 0, but according to Blizz code it can actually happen
			min = mod == 0 and 0 or min / mod

			-- BUG: Destruction is supposed to show partial soulshards, but Affliction and Demonology should only show full ones
			if (GetSpecialization() ~= SPEC_WARLOCK_DESTRUCTION) then
				min = min - min % 1 -- because math operators are faster than functions
			end

			local numActive = min + 0.9
			local maxDisplayed = element.maxDisplayed or element.max or max
			
			for i = 1, maxDisplayed do 
				local point = element[i]
				if (point) then
					if (not point:IsShown()) then 
						point:Show()
					end 
					local value = (i > numActive) and 0 or (min - i + 1)
					point:SetValue(value)
				end
			end 

			for i = maxDisplayed+1, #element do 
				element[i]:SetValue(0)
				if (element[i]:IsShown()) then 
					element[i]:Hide()
				end 
			end 

			return min, max, powerType
		end
	}, Generic_MT)

	ClassPower.Stagger = setmetatable({ 
		EnablePower = function(self)
			local element = self.ClassPower
			element.powerType = "STAGGER"
			element.maxDisplayed = 3
			element.isEnabled = true

			self:RegisterEvent("UNIT_AURA", Proxy)

			Generic.EnablePower(self)
		end,
		DisablePower = function(self)
			self:UnregisterEvent("UNIT_AURA", Proxy)

			Generic.DisablePower(self)
		end, 
		UpdatePower = function(self, event, unit, ...)
			local element = self.ClassPower
			if (not element.isEnabled) then 
				element:Hide()
				return 
			end 

			local powerType = element.powerType
			local powerID = element.powerID 

			-- Blizzard code has nil checks for UnitStagger return
			local min = UnitStagger("player") or 0
			local max = UnitHealthMax("player") or 1
			local numPoints

			local perc = min / max
			if (perc >= STAGGER_RED_TRANSITION) then
				numPoints = 3
			elseif (perc > STAGGER_YELLOW_TRANSITION) then
				numPoints = 2
			elseif (perc > 0) then
				numPoints = 1
			else 
				numPoints = 0
			end

			local maxDisplayed = element.maxDisplayed or element.max or max

			for i = 1, maxDisplayed do 
				local point = element[i]
				if (point) then
					if (not point:IsShown()) then 
						point:Show()
					end 
					point:SetValue(numPoints >= i and 1 or 0)
				end
			end 

			for i = maxDisplayed + 1, #element do 
				element[i]:SetValue(0)
				if (element[i]:IsShown()) then 
					element[i]:Hide()
				end 
			end 		

			return min, max, powerType
		end,
		UpdateColor = function(element, unit, min, max, powerType)
			local self = element._owner

			local perc = min / max
			local color
			if (perc >= STAGGER_RED_TRANSITION) then
				color = self.colors.power[powerType][STAGGER_RED_INDEX]
			elseif (perc > STAGGER_YELLOW_TRANSITION) then
				color = self.colors.power[powerType][STAGGER_YELLOW_INDEX]
			else
				color = self.colors.power[powerType][STAGGER_GREEN_INDEX]
			end

			local r, g, b = color[1], color[2], color[3]
			local maxDisplayed = element.maxDisplayed or element.max or max

			-- Class Color Overrides
			if (element.colorClass and UnitIsPlayer(unit)) then
				local _, class = UnitClass(unit)
				color = class and self.colors.class[class]
				r, g, b = color[1], color[2], color[3]
			end 
			
			-- Has the module chosen to only show this with an active target,
			-- or has the module chosen to hide all when empty?
			if (element.hideWhenNoTarget and (not UnitExists("target")))
			or (element.hideWhenUnattackable and (not UnitCanAttack("player", "target"))) 
			or (element.hideWhenEmpty and (min == 0)) then 
				for i = 1, maxDisplayed do
					local point = element[i]
					if (point) then
						point:SetAlpha(0)
					end 
				end 
			else 
				-- In case there are more points active 
				-- then the currently allowed maximum. 
				-- Meant to give an easy system to handle 
				-- the Rogue Anticipation talent without 
				-- the need for the module to write extra code. 
				local overflow
				if (min > maxDisplayed) then 
					overflow = min % maxDisplayed
				end 
				for i = 1, maxDisplayed do
					local point = element[i]
					if (point) then

						-- upvalue to preserve the original colors for the next point
						local r, g, b = r, g, b 

						-- Handle overflow coloring
						if (overflow) then
							if (i > overflow) then
								-- tone down "old" points
								r, g, b = r*1/3, g*1/3, b*1/3 
							else 
								-- brighten the overflow points
								r = (1-r)*1/3 + r
								g = (1-g)*1/4 + g -- always brighten the green slightly less
								b = (1-b)*1/3 + b
							end 
						end 

						if (element.alphaNoCombat) then 
							point:SetStatusBarColor(r, g, b)
							if (point.bg) then 
								local mult = element.backdropMultiplier or 1/3
								point.bg:SetVertexColor(r*mult, g*mult, b*mult)
							end 
								local alpha = UnitAffectingCombat(unit) and 1 or element.alphaNoCombat
							if (i > min) and (element.alphaEmpty) then
								point:SetAlpha(element.alphaEmpty * alpha)
							else 
								point:SetAlpha(alpha)
							end 
						else 
							point:SetStatusBarColor(r, g, b, 1)
							if (point.bg) then 
								local mult = element.backdropMultiplier or 1/3
								point.bg:SetVertexColor(r*mult, g*mult, b*mult)
							end 
							if (element.alphaEmpty) then 
								point:SetAlpha(min > i and element.alphaEmpty or 1)
							else 
								point:SetAlpha(1)
							end 
						end 
					end 
				end
			end 
		end
	}, Generic_MT)

end

-- The general update method for all powerTypes
Update = function(self, event, unit, ...)
	local element = self.ClassPower

	-- Run the general preupdate
	if element.PreUpdate then 
		element:PreUpdate(unit)
	end 

	-- Store the old maximum value, if any
	local oldMax = element.max

	-- Run the current powerType's Update function
	local min, max, powerType = element.UpdatePower(self, event, unit, ...)

	-- Stop execution if element was disabled 
	-- during its own update cycle.
	if (not element.isEnabled) then 
		return 
	end 

	-- Post update element colors, allow modules to override
	local updateColor = element.OverrideColor or element.UpdateColor
	if updateColor then 
		updateColor(element, unit, min, max, powerType)
	end 

	if (element.hideFullyWhenEmpty) and (min == 0) then
		if (element:IsShown()) then
			element:Hide()
		end
	else
		if (not element:IsShown()) then 
			element:Show()
		end 
	end

	-- Run the general postupdate
	if (element.PostUpdate) then 
		return element:PostUpdate(unit, min, max, oldMax ~= max, powerType)
	end 
end 

-- This is where the current powerType is decided, 
-- where we check for and unregister conditional events
-- related to player specialization, talents or level.
-- This is also where we toggle the current element,
-- disable the old and enable the new. 
if (IsClassic or IsTBC) then
	UpdatePowerType = function(self, event, unit, ...)
		local element = self.ClassPower

		-- Should be safe to always check for unit even here, 
		-- our unitframe library should provide it if unitless events are registered properly.
		if (not unit) or (unit ~= self.unit) or (event == "UNIT_POWER_FREQUENT" and (...) ~= element.powerType) then 
			return 
		end 

		local newType 
		if ((PLAYERCLASS == "DRUID") or (PLAYERCLASS == "ROGUE")) and (not element.ignoreComboPoints) then 
			newType = "ComboPoints"
		else 
			newType = "None"
		end 

		local currentType = element._currentType

		-- Disable previous type if present and different
		if (currentType) and (currentType ~= newType) then 
			element.DisablePower(self)
		end 

		-- Set or change the powerType if there is a new or initial one
		if (not currentType) or (currentType ~= newType) then 

			-- Update type
			element._currentType = newType

			-- Change the meta
			setmetatable(element, { __index = ClassPower[newType] })

			-- Enable using new type
			element.EnablePower(self)
		end 

		-- Continue to the regular update method
		return Update(self, event, unit, ...)
	end 
end
if (IsRetail) then
	UpdatePowerType = function(self, event, unit, ...)
		local element = self.ClassPower

		-- Should be safe to always check for unit even here, 
		-- our unitframe library should provide it if unitless events are registered properly.
		if (not unit) or (unit ~= self.unit) or (event == "UNIT_POWER_FREQUENT" and (...) ~= element.powerType) then 
			return 
		end 

		local spec = GetSpecialization()
		local level = UnitLevel("player")

		if (event == "PLAYER_LEVEL_UP") then
			level = ...
			if ((PLAYERCLASS == "PALADIN") and (level >= PALADINPOWERBAR_SHOW_LEVEL)) or (PLAYERCLASS == "WARLOCK") and (level >= SHARDBAR_SHOW_LEVEL) then
				self:UnregisterEvent("PLAYER_LEVEL_UP", Proxy)
			end 
	
		elseif (event == "UPDATE_POSSESS_BAR") then
			element.hasPossessBar = IsPossessBarVisible()
	
		elseif (event == "UPDATE_OVERRIDE_ACTIONBAR") then 
			element.hasOverrideBar = HasOverrideActionBar() or HasTempShapeshiftActionBar() 
	
		elseif (event == "UNIT_ENTERING_VEHICLE")
			or (event == "UNIT_ENTERED_VEHICLE")
			or (event == "UNIT_EXITING_VEHICLE")
			or (event == "UNIT_EXITED_VEHICLE")
		then
			element.inVehicle = UnitInVehicle("player")
			element.hasVehicleUI = UnitHasVehiclePlayerFrameUI("player") and PlayerVehicleHasComboPoints()
		end 

		local newType 
		if (element.hasPossessBar or element.hasOverrideBar) or (element.inVehicle and (not element.hasVehicleUI)) then 
			newType = "None"
		elseif (element.hasVehicleUI) and (not element.ignoreComboPoints) then 
			newType = "ComboPoints"
		elseif (PLAYERCLASS == "DEATHKNIGHT") and (not element.ignoreRunes) then 
			newType = "Runes"
		elseif (PLAYERCLASS == "DRUID") and (not element.ignoreComboPoints) then 
			newType = "ComboPoints"
		elseif (PLAYERCLASS == "MAGE") and (spec == SPEC_MAGE_ARCANE) and (not element.ignoreArcaneCharges) then 
			newType = "ArcaneCharges"
		elseif (PLAYERCLASS == "MONK") and (spec == SPEC_MONK_WINDWALKER) and (not element.ignoreChi) then 
			newType = "Chi"
		elseif (PLAYERCLASS == "MONK") and (spec == SPEC_MONK_BREWMASTER) and (not element.ignoreStagger) then 
			newType = "Stagger"
		elseif ((PLAYERCLASS == "PALADIN") and (level >= PALADINPOWERBAR_SHOW_LEVEL)) and (not element.ignoreHolyPower) then
			newType = "HolyPower"
		elseif (PLAYERCLASS == "ROGUE") and (not element.ignoreComboPoints) then 
			newType = "ComboPoints"
		elseif ((PLAYERCLASS == "WARLOCK") and (level >= SHARDBAR_SHOW_LEVEL)) and (not element.ignoreSoulShards) then 
			newType = "SoulShards"
		elseif (PLAYERCLASS == "DEMONHUNTER") and (spec == SPEC_DEMONHUNTER_VENGEANCE) and (not element.ignoreSoulFragments) then 
			newType = "SoulFragments"
		--elseif (not element.ignoreComboPoints) then 
		--	newType = "ComboPoints"
		else 
			newType = "None"
		end 
	
		local currentType = element._currentType

		-- Disable previous type if present and different
		if (currentType) and (currentType ~= newType) then 
			element.DisablePower(self)
		end 

		-- Set or change the powerType if there is a new or initial one
		if (not currentType) or (currentType ~= newType) then 

			-- Update type
			element._currentType = newType

			-- Change the meta
			setmetatable(element, { __index = ClassPower[newType] })

			-- Enable using new type
			element.EnablePower(self)
		end 

		-- Continue to the regular update method
		return Update(self, event, unit, ...)
	end
end

Proxy = function(self, ...)
	return (self.ClassPower.Override or UpdatePowerType)(self, ...)
end 

ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local element = self.ClassPower
	if element then
		element._owner = self
		element.ForceUpdate = ForceUpdate

		-- Give points access to their owner element, 
		-- regardless of whether that element is their direct parent or not. 
		for i = 1,#element do
			element[i]._owner = element
		end

		self:RegisterEvent("UNIT_DISPLAYPOWER", Proxy)
		self:RegisterEvent("PLAYER_TARGET_CHANGED", Proxy, true)
		self:RegisterEvent("PLAYER_ENTERING_WORLD", Proxy, true)

		if (IsRetail) then
			local level = UnitLevel("player")
			if ((PLAYERCLASS == "PALADIN") and (level < PALADINPOWERBAR_SHOW_LEVEL)) or (PLAYERCLASS == "WARLOCK") and (level < SHARDBAR_SHOW_LEVEL) then
				self:RegisterEvent("PLAYER_LEVEL_UP", Proxy, true)
			end  

			-- We'll handle spec specific powers from here, 
			-- but will leave level checking to the sub-elements.
			if (PLAYERCLASS == "MONK") or (PLAYERCLASS == "MAGE") or (PLAYERCLASS == "PALADIN") or (PLAYERCLASS == "DEMONHUNTER") then 
				self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", Proxy, true) 
			end 
			if (PLAYERCLASS == "MONK") then
				self:RegisterEvent("PLAYER_TALENT_UPDATE", Proxy, true) 
			end

			-- All must check for vehicles
			-- *Also of importance that none 
			-- of the powerTypes remove this event.
			self:RegisterEvent("UNIT_ENTERED_VEHICLE", Proxy)
			self:RegisterEvent("UNIT_ENTERING_VEHICLE", Proxy)
			self:RegisterEvent("UNIT_EXITED_VEHICLE", Proxy)
			self:RegisterEvent("UNIT_EXITING_VEHICLE", Proxy)
			self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR", Proxy, true)
			self:RegisterEvent("UPDATE_POSSESS_BAR", Proxy, true)
		end

		return true
	end
end 

local Disable = function(self)
	local element = self.ClassPower
	if element then

		-- Disable the current powerType, if any
		if element._currentType then 
			element.DisablePower(self)
			element._currentType = nil
			element.powerType = nil
		end 

		-- Remove generic events
		self:UnregisterEvent("UNIT_DISPLAYPOWER", Proxy)
		self:UnregisterEvent("PLAYER_TARGET_CHANGED", Proxy)
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", Proxy)

		if (IsRetail) then
			self:UnregisterEvent("PLAYER_LEVEL_UP", Proxy)
			self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", Proxy)
			self:UnregisterEvent("UNIT_ENTERED_VEHICLE", Proxy)
			self:UnregisterEvent("UNIT_ENTERING_VEHICLE", Proxy)
			self:UnregisterEvent("UNIT_EXITED_VEHICLE", Proxy)
			self:UnregisterEvent("UNIT_EXITING_VEHICLE", Proxy)
			self:UnregisterEvent("UPDATE_OVERRIDE_ACTIONBAR", Proxy)
			self:UnregisterEvent("UPDATE_POSSESS_BAR", Proxy)
		end
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("ClassPower", Enable, Disable, Proxy, 58)
end 
