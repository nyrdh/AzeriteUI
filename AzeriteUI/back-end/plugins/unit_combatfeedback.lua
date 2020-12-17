local LibNumbers = Wheel("LibNumbers")
assert(LibNumbers, "UnitCombatFeedback requires LibNumbers to be loaded.")

-- Lua API
local bit_band = bit.band
local math_cos = math.cos
local math_pi = math.pi
local math_random = math.random
local math_sin = math.sin
local next = next
local select = select
local table_insert = table.insert
local table_remove = table.remove
local table_wipe = table.wipe
local type = type

-- WoW API
local GetTime = GetTime

-- Number Abbreviation
local short = LibNumbers:GetNumberAbbreviationShort()
local large = LibNumbers:GetNumberAbbreviationLong()

local damage_format = "-%s"
local heal_format = "+%s"
local maxAlpha = .6

-- Sourced from FrameXML\CombatFeedback.lua
local COMBATFEEDBACK_FADEINTIME 	= COMBATFEEDBACK_FADEINTIME 	-- 0.2
local COMBATFEEDBACK_HOLDTIME 		= COMBATFEEDBACK_HOLDTIME 		-- 0.7
local COMBATFEEDBACK_FADEOUTTIME 	= COMBATFEEDBACK_FADEOUTTIME 	-- 0.3

local SCHOOL_MASK_NONE 				= SCHOOL_MASK_NONE 				-- 0x00
local SCHOOL_MASK_PHYSICAL 			= SCHOOL_MASK_PHYSICAL 			-- 0x01
local SCHOOL_MASK_HOLY 				= SCHOOL_MASK_HOLY 				-- 0x02
local SCHOOL_MASK_FIRE 				= SCHOOL_MASK_FIRE 				-- 0x04
local SCHOOL_MASK_NATURE 			= SCHOOL_MASK_NATURE 			-- 0x08
local SCHOOL_MASK_FROST 			= SCHOOL_MASK_FROST 			-- 0x10
local SCHOOL_MASK_SHADOW 			= SCHOOL_MASK_SHADOW 			-- 0x20
local SCHOOL_MASK_ARCANE 			= SCHOOL_MASK_ARCANE 			-- 0x40

-- Localized feedback texts.
local FeedbackText = {
	["INTERRUPT"]		= INTERRUPT,
	["MISS"]			= MISS,
	["RESIST"]			= RESIST,
	["DODGE"]			= DODGE,
	["PARRY"]			= PARRY,
	["BLOCK"]			= BLOCK,
	["EVADE"]			= EVADE,
	["IMMUNE"]			= IMMUNE,
	["DEFLECT"]			= DEFLECT,
	["ABSORB"]			= ABSORB,
	["REFLECT"]			= REFLECT,
	["BLOCK_REDUCED"]	= BLOCK_REDUCED
}

local OnUpdate = function(element, elapsed)
	element.elapsed = (element.elapsed or 0) + elapsed
	if (element.elapsed < .05) then
		return
	end
	element.elapsed = 0
	local feedbackText = element.feedbackText
	if (feedbackText:IsVisible()) then
		local elapsedTime = GetTime() - element.feedbackStartTime
		local fadeInTime = COMBATFEEDBACK_FADEINTIME
		if (elapsedTime < fadeInTime) then
			local alpha = (elapsedTime / fadeInTime)*maxAlpha
			feedbackText:SetAlpha(alpha)
			return
		end
		local holdTime = COMBATFEEDBACK_HOLDTIME
		if (elapsedTime < (fadeInTime + holdTime)) then
			feedbackText:SetAlpha(maxAlpha)
			return
		end
		local fadeOutTime = COMBATFEEDBACK_FADEOUTTIME
		if (elapsedTime < (fadeInTime + holdTime + fadeOutTime)) then
			local alpha = maxAlpha - ((elapsedTime - holdTime - fadeInTime) / fadeOutTime)*maxAlpha
			feedbackText:SetAlpha(alpha)
			return
		end
		feedbackText:Hide()
	end
end

local Update = function(self, event, unit, ...)
	if (not unit) or (unit ~= self.unit) then 
		return 
	end 
	local unitTarget, event, flagText, amount, schoolMask = ...
	if (unitTarget ~= unit) then
		return
	end

	local element = self.CombatFeedback
	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end

	local feedbackText = element.feedbackText
	local color, fontType, text, arg

	if (event == "IMMUNE") then
		fontType ="small"
		text = FeedbackText[event]

	elseif (event == "WOUND") then
		if (amount ~= 0) then

			if (flags == "CRITICAL") then
				fontType ="large"
				color = self.colors.feedback.CRITICAL

			elseif (flags == "CRUSHING") then
				fontType ="large"
				color = self.colors.feedback.CRUSHING

			elseif (flags == "GLANCING") then
				fontType ="small"
				color = self.colors.feedback.GLANCING
			else
				color = self.colors.feedback.DAMAGE
			end

			if (flags == "BLOCK_REDUCED") then
				text = COMBAT_TEXT_BLOCK_REDUCED:format(short(text))
			else
				text = damage_format
				arg = large(amount)
			end

		elseif (flags == "ABSORB") then
			fontType ="small"
			text = FeedbackText["ABSORB"]
			color = self.colors.feedback.ABSORB

		elseif (flags == "BLOCK") then
			fontType ="small"
			text = FeedbackText["BLOCK"]
			color = self.colors.feedback.BLOCK

		elseif (flags == "RESIST") then
			fontType ="small"
			text = FeedbackText["RESIST"]
			color = self.colors.feedback.RESIST

		else
			text = FeedbackText["MISS"]
			color = self.colors.feedback.MISS
		end

	elseif (event == "BLOCK") then
		fontType ="small"
		text = FeedbackText[event]
		color = self.colors.feedback.BLOCK

	elseif (event == "HEAL") then
		text = heal_format
		arg = large(amount)
		if (flags == "CRITICAL") then
			fontType ="large"
			color = self.colors.feedback.CRITHEAL
		else
			color = self.colors.feedback.HEAL
		end

	elseif (event == "ENERGIZE") then
		text = large(amount)
		if (flags == "CRITICAL") then
			fontType ="large"
			color = self.colors.feedback.CRITENERGIZE
		else
			color = self.colors.feedback.ENERGIZE
		end
	else
		text = FeedbackText[event]
		color = self.colors.feedback.STANDARD
	end

	element.feedbackStartTime = GetTime()

	if (text) then
		if (fontType ~= feedbackText.fontType) then
			local fontObject 
			if (fontType == "small") then
				fontObject = feedbackText.feedbackFontSmall

			elseif (fontType == "large") then
				fontObject = feedbackText.feedbackFontLarge
			end
			feedbackText:SetFontObject(fontObject or feedbackText.feedbackFont)
			feedbackText.fontType = fontType
		end
		feedbackText:SetFormattedText(text, arg)
		feedbackText:SetTextColor(color[1], color[2], color[3])
		feedbackText:SetAlpha(0)
		feedbackText:Show()
	end

	if (element.PostUpdate) then 
		return element:PostUpdate(unit)
	end 
end 

local Proxy = function(self, ...)
	return (self.CombatFeedback.Override or Update)(self, ...)
end 

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local element = self.CombatFeedback
	if (element) then
		element._owner = self
		element.ForceUpdate = ForceUpdate

		element.feedbackStartTime = GetTime()
		element:SetScript("OnUpdate", OnUpdate)
		element:Show()

		self:RegisterEvent("UNIT_COMBAT", Proxy, true)

		return true
	end
end 

local Disable = function(self)
	local element = self.CombatFeedback
	if (element) then
		element:Hide()
		element:SetScript("OnUpdate", nil)
		self:UnregisterEvent("UNIT_COMBAT", Proxy, true)
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("CombatFeedback", Enable, Disable, Proxy, 1)
end 
