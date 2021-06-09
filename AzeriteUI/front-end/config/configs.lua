local ADDON, Private = ...

local LibNumbers = Wheel("LibNumbers")
assert(LibNumbers, ADDON.." requires LibNumbers to be loaded.")

-- Lua API
local _G = _G
local math_ceil = math.ceil
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_pi = math.pi 
local math_sin = math.sin
local setmetatable = setmetatable
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_upper = string.upper
local tonumber = tonumber
local tostring = tostring
local unpack = unpack

-- WoW API
local UnitCanAttack = UnitCanAttack
local UnitClassification = UnitClassification
local UnitCreatureType = UnitCreatureType
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsEnemy = UnitIsEnemy
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel
local UnitPowerMax = UnitPowerMax

-- Addon localization
local L = Wheel("LibLocale"):GetLocale(ADDON)

-- Number Abbreviation
local short = LibNumbers:GetNumberAbbreviationShort()
local large = LibNumbers:GetNumberAbbreviationLong()

-- Private API
local Colors = Private.Colors
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia 
local GetAuraFilter = Private.GetAuraFilter
local IsClassic = Private.IsClassic
local IsTBC = Private.IsTBC
local IsRetail = Private.IsRetail

------------------------------------------------
-- Utility Functions
------------------------------------------------
-- Proper conversion constant.
local deg2rad = math_pi / 180
local degreesToRadians = function(degrees)
	return degrees*deg2rad
end 

------------------------------------------------
-- Module Callbacks
------------------------------------------------
-- Used for methods that need to create a backdrop on-the-fly
local GetBorder = function(self, edgeFile, edgeSize, bgFile, bgInsets, offsetX, offsetY)
	local border = self:CreateFrame("Frame")
	border:SetFrameLevel(self:GetFrameLevel()-1)
	border:SetPoint("TOPLEFT", -(offsetX or 6), (offsetY or 8))
	border:SetPoint("BOTTOMRIGHT", (offsetX or 6), -(offsetY or 8))
	border:SetBackdrop({
		["bgFile"] = bgFile or [[Interface\ChatFrame\ChatFrameBackground]],
		["edgeFile"] = edgeFile or GetMedia("tooltip_border_hex"),
		["edgeSize"] = 32, 
		["tile"] = false, 
		["insets"] = { 
			["top"] = bgInsets or 10.5, 
			["bottom"] = bgInsets or 10.5, 
			["left"] = bgInsets or 10.5, 
			["right"] = bgInsets or 10.5 
		}
	})
	border:SetBackdropBorderColor(1, 1, 1, 1)
	border:SetBackdropColor(.05, .05, .05, .85)
	return border
end

local Core_MenuButton_PostCreate = function(self, text, ...)
	local msg = self:CreateFontString()
	msg:SetPoint("CENTER", 0, 0)
	msg:SetFontObject(GetFont(14, false))
	msg:SetJustifyH("RIGHT")
	msg:SetJustifyV("TOP")
	msg:SetIndentedWordWrap(false)
	msg:SetWordWrap(false)
	msg:SetNonSpaceWrap(false)
	msg:SetTextColor(0,0,0)
	msg:SetShadowOffset(0, -.85)
	msg:SetShadowColor(1,1,1,.5)
	msg:SetText(text)
	self.Msg = msg

	local bg = self:CreateTexture()
	bg:SetDrawLayer("ARTWORK")
	bg:SetTexture(GetMedia("menu_button_disabled"))
	bg:SetVertexColor(.9, .9, .9)
	bg:SetSize(1024 *1/3 *.75, 256 *1/3 *.75)
	bg:SetPoint("CENTER", msg, "CENTER", 0, 0)
	self.NormalBackdrop = bg

	local pushed = self:CreateTexture()
	pushed:SetDrawLayer("ARTWORK")
	pushed:SetTexture(GetMedia("menu_button_pushed"))
	pushed:SetVertexColor(.9, .9, .9)
	pushed:SetSize(1024 *1/3 *.75, 256 *1/3 *.75)
	pushed:SetPoint("CENTER", msg, "CENTER", 0, 0)
	self.PushedBackdrop = pushed

	local arrowUp = self:CreateTexture()
	arrowUp:Hide()
	arrowUp:SetDrawLayer("OVERLAY")
	arrowUp:SetSize(20,20)
	arrowUp:SetTexture([[Interface\BUTTONS\Arrow-Down-Down]])
	arrowUp:SetDesaturated(true)
	arrowUp:SetTexCoord(0,1,1,1,0,0,1,0) 
	arrowUp:SetPoint("LEFT", 2, 1)
	self.ArrowUp = arrowUp

	local arrowDown = self:CreateTexture()
	arrowDown:Hide()
	arrowDown:SetDrawLayer("OVERLAY")
	arrowDown:SetSize(20,20)
	arrowDown:SetTexture([[Interface\BUTTONS\Arrow-Down-Down]])
	arrowDown:SetTexCoord(0,1,1,1,0,0,1,0) 
	arrowDown:SetPoint("LEFT", 2, -1)
	self.ArrowDown = arrowDown

	return self
end

local Core_MenuButton_PostUpdate = function(self)
	local isPushed = self.isDown or self.isChecked or self.windowIsShown
	local show = isPushed and self.PushedBackdrop or self.NormalBackdrop
	local hide = isPushed and self.NormalBackdrop or self.PushedBackdrop

	hide:SetAlpha(0)
	show:SetAlpha(1)

	if (isPushed) then
		self.ArrowDown:SetShown(self.hasWindow)
		self.ArrowUp:Hide()
		self.Msg:SetPoint("CENTER", 0, -2)
		if (self:IsMouseOver()) and (self:GetAttribute("userDisabled") ~= "1") then
			show:SetVertexColor(1, 1, 1)
		elseif (self.isChecked or self.windowIsShown) then 
			show:SetVertexColor(.9, .9, .9)
		else
			show:SetVertexColor(.75, .75, .75)
		end
	else
		self.ArrowDown:Hide()
		self.ArrowUp:SetShown(self.hasWindow)
		self.Msg:SetPoint("CENTER", 0, 0)
		if (self:IsMouseOver()) and (self:GetAttribute("userDisabled") ~= "1") then
			show:SetVertexColor(1, 1, 1)
		else
			show:SetVertexColor(.75, .75, .75)
		end
	end
end

local Minimap_Clock_OverrideValue = function(element, h, m, suffix)
	if (element.useStandardTime) then 
		element:SetFormattedText("%.0f:%02.0f |cff888888%s|r", h, m, string_match(suffix, "^."))
	else
		element:SetFormattedText("%02.0f:%02.0f", h, m)
	end
end 

local Minimap_Coordinates_OverrideValue = function(element, x, y)
	local xval = string_gsub(string_format("%.1f", x*100), "%.(.+)", "|cff888888.%1|r")
	local yval = string_gsub(string_format("%.1f", y*100), "%.(.+)", "|cff888888.%1|r")
	element:SetFormattedText("%s %s", xval, yval) 
end 

local Minimap_FrameRate_OverrideValue = function(element, fps)
	element:SetFormattedText("|cff888888%.0f %s|r", math_floor(fps), string_upper(string_match(FPS_ABBR, "^.")))
end 

local Minimap_Latency_OverrideValue = function(element, home, world)
	element:SetFormattedText("|cff888888%s|r %.0f - |cff888888%s|r %.0f", string_upper(string_match(HOME, "^.")), math_floor(home), string_upper(string_match(WORLD, "^.")), math_floor(world))
end 

local Minimap_RingFrame_SingleRing_ValueFunc = function(Value, Handler) 
	Value:ClearAllPoints()
	Value:SetPoint("BOTTOM", Handler.Toggle.Frame.Bg, "CENTER", 2, -2)
	Value:SetFontObject(GetFont(24, true)) 
end

local Minimap_RingFrame_OuterRing_ValueFunc = function(Value, Handler) 
	Value:ClearAllPoints()
	Value:SetPoint("TOP", Handler.Toggle.Frame.Bg, "CENTER", 1, -2)
	Value:SetFontObject(GetFont(16, true)) 
	Value.Description:Hide()
end

local Minimap_Performance_PlaceFunc = function(performanceFrame, Handler)
	performanceFrame:ClearAllPoints()
	performanceFrame:SetPoint("TOPLEFT", Handler.Latency, "TOPLEFT", 0, 0)
	performanceFrame:SetPoint("BOTTOMRIGHT", Handler.FrameRate, "BOTTOMRIGHT", 0, 0)
end

local Minimap_AP_OverrideValue = function(element, min, max, level)
	local value = element.Value or element:IsObjectType("FontString") and element 
	if value.showDeficit then 
		value:SetFormattedText(short(max - min))
	else 
		value:SetFormattedText(short(min))
	end
	local percent = value.Percent
	if percent then 
		if (max > 0) then 
			local percValue = math_floor(min/max*100)
			if (percValue > 0) then 
				-- removing the percentage sign
				percent:SetFormattedText("%.0f", percValue)
			else 
				percent:SetText("*") 
			end 
		else 
			percent:SetText("ap") 
		end 
	end 
	if element.colorValue then 
		local color = element._owner.colors.artifact
		value:SetTextColor(color[1], color[2], color[3])
		if percent then 
			percent:SetTextColor(color[1], color[2], color[3])
		end 
	end 
end 

local Minimap_Rep_OverrideValue = function(element, current, min, max, factionName, standingID, standingLabel, isFriend)
	local value = element.Value or element:IsObjectType("FontString") and element 
	local barMax = max - min 
	local barValue = current - min
	if value.showDeficit then 
		if (barMax - barValue > 0) then 
			value:SetFormattedText(short(barMax - barValue))
		else 
			value:SetText("100%")
		end 
	else 
		value:SetFormattedText(short(current - min))
	end
	local percent = value.Percent
	if percent then 
		if (max - min > 0) then 
			local percValue = math_floor((current - min)/(max - min)*100)
			if (percValue > 0) then 
				-- removing the percentage sign
				percent:SetFormattedText("%.0f", percValue)
			else 
				percent:SetText("*") 
			end 
		else 
			percent:SetText("*") 
		end 
	end 
	if element.colorValue then 
		local color = element._owner.colors[isFriend and "friendship" or "reaction"][standingID]
		if (color) then
			value:SetTextColor(color[1], color[2], color[3])
			if (percent) then 
				percent:SetTextColor(color[1], color[2], color[3])
			end 
		end
	end 
end

local Minimap_XP_OverrideValue = function(element, min, max, restedLeft, restedTimeLeft)
	local value = element.Value or element:IsObjectType("FontString") and element 
	if (value.showDeficit) then 
		value:SetFormattedText(short(max - min))
	else 
		value:SetFormattedText(short(min))
	end
	local percent = value.Percent
	if (percent) then 
		if (max > 0) then 
			local percValue = math_floor(min/max*100)
			if (percValue > 0) then 
				-- removing the percentage sign
				percent:SetFormattedText("%.0f", percValue)
			else 
				percent:SetText("*")
			end 
		else 
			percent:SetText("*")
		end 
	end 
	if (element.colorValue) then 
		local color
		if (restedLeft) then 
			local colors = element._owner.colors
			color = colors.restedValue or colors.rested or colors.xpValue or colors.xp
		else 
			local colors = element._owner.colors
			color = colors.xpValue or colors.xp
		end 
		value:SetTextColor(color[1], color[2], color[3])
		if (percent) then 
			percent:SetTextColor(color[1], color[2], color[3])
		end 
	end 
end 

-- Retail Personal Resource Display
local NamePlates_PreUpdate = function(plate, event, unit)
	if (plate.isYou) then
		plate.Health.Value:Hide()
	end
	if (plate.isYou) and (not plate.plateIsPRD) then
		local layout = plate.layout
		local cast = plate.Cast
		local spellQueue = cast.SpellQueue

		plate.Health:SetOrientation(layout.HealthBarOrientationPlayer)
		cast:SetOrientation(layout.CastOrientationPlayer)
		cast:Place(unpack(layout.CastPlacePlayer))

		if (spellQueue) then
			if (spellQueue.ForceUpdate) then
				spellQueue:ForceUpdate() -- in case a cast was running
			end
			spellQueue:Show()
			spellQueue.disableSpellQueue = nil
		end

		plate:EnableElement("Power")
		plate.plateIsPRD = true

	elseif (not plate.isYou) and (plate.plateIsPRD) then
		local layout = plate.layout
		local cast = plate.Cast
		local spellQueue = cast.SpellQueue

		plate.Health:SetOrientation(layout.HealthBarOrientation)
		cast:SetOrientation(layout.CastOrientation)
		cast:Place(unpack(layout.CastPlace))

		if (spellQueue) then
			spellQueue:Hide()
			cast.disableSpellQueue = true
		end

		plate:DisableElement("Power")
		plate.plateIsPRD = nil
	end
end

local NamePlates_Auras_PostCreateButton = function(element, button)
	local layout = element._owner.layout

	button.Icon:SetTexCoord(unpack(layout.AuraIconTexCoord))
	button.Icon:SetSize(unpack(layout.AuraIconSize))
	button.Icon:ClearAllPoints()
	button.Icon:SetPoint(unpack(layout.AuraIconPlace))

	button.Count:SetFontObject(layout.AuraCountFont)
	button.Count:SetJustifyH("CENTER")
	button.Count:SetJustifyV("MIDDLE")
	button.Count:ClearAllPoints()
	button.Count:SetPoint(unpack(layout.AuraCountPlace))
	button.Count:SetTextColor(unpack(layout.AuraCountColor))

	button.Time:SetFontObject(layout.AuraTimeFont)
	button.Time:ClearAllPoints()
	button.Time:SetPoint(unpack(layout.AuraTimePlace))

	local layer, level = button.Icon:GetDrawLayer()

	button.Darken = button.Darken or button:CreateTexture()
	button.Darken:SetDrawLayer(layer, level + 1)
	button.Darken:SetSize(button.Icon:GetSize())
	button.Darken:SetPoint("CENTER", 0, 0)
	button.Darken:SetColorTexture(0, 0, 0, .25)

	button.Overlay:SetFrameLevel(button:GetFrameLevel() + 10)
	button.Overlay:ClearAllPoints()
	button.Overlay:SetPoint("CENTER", 0, 0)
	button.Overlay:SetSize(button.Icon:GetSize())

	button.Border = button.Border or button.Overlay:CreateFrame("Frame")
	button.Border:SetFrameLevel(button.Overlay:GetFrameLevel() - 5)
	button.Border:ClearAllPoints()
	button.Border:SetPoint(unpack(layout.AuraBorderFramePlace))
	button.Border:SetSize(unpack(layout.AuraBorderFrameSize))
	button.Border:SetBackdrop(layout.AuraBorderBackdrop)
	button.Border:SetBackdropColor(unpack(layout.AuraBorderBackdropColor))
	button.Border:SetBackdropBorderColor(unpack(layout.AuraBorderBackdropBorderColor))
end

local NamePlates_Auras_PostUpdateButton = function(element, button)
	local colors = element._owner.colors
	local layout = element._owner.layout
	if UnitIsFriend("player", button.unit) then
		if button.isBuff then 
			local color = layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		else
			local color = colors.debuff[button.debuffType or "none"] or layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		end
	else 
		if button.isStealable then 
			local color = colors.power.ARCANE_CHARGES or layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		elseif button.isBuff then 
			local color = layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		else
			--local color = colors.debuff[button.debuffType or "none"] or layout.AuraBorderBackdropBorderColor
			local color = colors.debuff.none or layout.AuraBorderBackdropBorderColor
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			end 
		end
	end 
end

local NamePlates_CastBar_PostUpdate = function(cast, unit)

	-- Protected cast graphics
	if (cast.notInterruptible) and (not cast.isProtected) then

		-- Set it to the protected look 
		cast:SetSize(68, 9)
		cast:ClearAllPoints()
		cast:SetPoint("TOPLEFT", cast:GetParent():GetWidth()/2 - cast:GetWidth()/2, -26)
		cast:SetStatusBarTexture(GetMedia("cast_bar"))
		cast:SetTexCoord(0, 1, 0, 1)
		cast.Bg:SetSize(68, 9)
		cast.Bg:SetTexture(GetMedia("cast_bar"))
		cast.Bg:SetVertexColor(.15, .15, .15, 1)
		cast.isProtected = true

	elseif (not cast.notInterruptible) and (cast.isProtected) then

		-- Return to standard castbar styling and position 
		cast:SetSize(84, 14)
		cast:ClearAllPoints()
		cast:SetPoint("TOPLEFT", cast:GetParent():GetWidth()/2 - cast:GetWidth()/2, -20)
		cast:SetStatusBarTexture(GetMedia("nameplate_bar"))
		cast:SetTexCoord(14/256, 242/256, 14/64, 50/64)
		cast.Bg:SetSize(84*256/228, 14*64/36)
		cast.Bg:SetTexture(GetMedia("nameplate_backdrop"))
		cast.Bg:SetVertexColor(1, 1, 1, 1)
		cast.isProtected = nil 
	end

	-- Bar coloring
	if (cast.notInterruptible) then
		-- Color the bar appropriately
		if UnitIsPlayer(unit) then 
			if UnitIsEnemy(unit, "player") then 
				cast:SetStatusBarColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3]) 
			else 
				cast:SetStatusBarColor(Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3]) 
			end  
		elseif UnitCanAttack("player", unit) then 
			cast:SetStatusBarColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3]) 
		else 
			cast:SetStatusBarColor(Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3]) 
		end 
	else
		-- Standard bar coloring
		cast:SetStatusBarColor(Colors.cast[1], Colors.cast[2], Colors.cast[3]) 
	end

	-- Reposition cast name based on cast type.
	-- This must happen on every cast, as it depends on the cast name width, which changes.
	if (cast.isProtected) then
		cast.Name:ClearAllPoints()
		cast.Name:SetPoint("TOPLEFT", cast:GetWidth()/2 - cast.Name:GetStringWidth()/2, -20)
	else
		cast.Name:ClearAllPoints()
		cast.Name:SetPoint("TOPLEFT", cast:GetWidth()/2 - cast.Name:GetStringWidth()/2, -18)
	end

	-- Why did I need this again...?
	--local self = cast._owner
	--if (not self) then 
	--	return 
	--end 
	--unit = unit or self.unit
	--if (unit) then
	--	self:PostUpdate(unit)
	--end
end

local NamePlates_PostUpdate = function(self, event, unit, ...)
	local layout = self.layout
	local auras = self.Auras
	local cast = self.Cast
	local health = self.Health
	local healthVal = self.Health.Value
	local name = self.Name
	local raidicon = self.RaidTarget

	local showName = not(name.hidePlayer and self.isYou) 
		and ((name.showMouseover and self.isMouseOver) or (name.showTarget and self.isTarget))
		or ((self.unitCanAttack) and (name.showCombat and self.inCombat))

	local showHealthValue = (self.unitCanAttack) 
		and not(healthVal.hidePlayer and self.isYou) 
		and not(healthVal.hideCasting and (cast.casting or cast.channeling)) 
		and ((healthVal.showMouseover and self.isMouseOver) or (healthVal.showTarget and self.isTarget) or (healthVal.showCombat and self.inCombat)) 

	local num = auras.visibleAuras or 0
	local auraOffset = showName and layout.NameOffsetWhenShown or 0
	local raidiconOffset = auraOffset + ((num > 3) and (layout.AuraSize*2 + layout.AuraPadding) or (num > 0) and (layout.AuraSize) or 0)

	-- ForceUpdate() may not exist
	-- if this is called before initial Enable()
	if (showHealthValue) then
		healthVal:Show()
		if (health.ForceUpdate) then
			health:ForceUpdate()
		end
	else
		healthVal:Hide()
	end
	if (showName) then
		name:Show()
		if (name.ForceUpdate) then
			name:ForceUpdate()
		else
			self:EnableElement("Name") 
		end
	else
		name:Hide()
	end

	auras:ClearAllPoints()
	auras:SetPoint(auras.point, auras.anchor, auras.relPoint, auras.offsetX, auras.offsetY + auraOffset)

	raidicon:ClearAllPoints()
	raidicon:SetPoint(raidicon.point, raidicon.anchor, raidicon.relPoint, raidicon.offsetX, raidicon.offsetY + raidiconOffset)
end

local NamePlates_PostUpdate_ElementProxy = function(element, unit)
	local self = element._owner
	if (not self) then 
		return 
	end 
	unit = unit or self.unit
	if (unit) then
		self:PostUpdate(unit)
	end
end

local PlayerFrame_CastBarPostUpdate = function(element, unit)
	local self = element._owner
	local cast = self.Cast
	local health = self.Health

	local isPlayer = UnitIsPlayer(unit) -- and UnitIsEnemy(unit)
	local unitLevel = UnitLevel(unit)
	local unitClassification = (unitLevel and (unitLevel < 1)) and "worldboss" or UnitClassification(unit)
	local isBoss = unitClassification == "boss" or unitClassification == "worldboss"
	local isEliteOrRare = unitClassification == "rare" or unitClassification == "elite" or unitClassification == "rareelite"

	if ((unitLevel and unitLevel == 1) and (not UnitIsPlayer("player"))) then 
		health.Value:Hide()
		if (health.ValueAbsorb) then
			health.ValueAbsorb:Hide()
		end 
		cast.Value:Hide()
		cast.Name:Hide()
	elseif (cast.casting or cast.channeling) then 
		health.Value:Hide()
		if (health.ValueAbsorb) then
			health.ValueAbsorb:Hide()
		end 
		cast.Value:Show()
		cast.Name:Show()
	else 
		health.Value:Show()
		if (health.ValueAbsorb) then
			health.ValueAbsorb:Show()
		end 
		cast.Value:Hide()
		cast.Name:Hide()
	end 
end

local PlayerFrame_ExtraPowerOverrideColor = function(element, unit, min, max, powerType, powerID, disconnected, dead, tapped)
	local self = element._owner
	local layout = self.layout
	local r, g, b
	if disconnected then
		r, g, b = unpack(self.colors.disconnected)
	elseif dead then
		r, g, b = unpack(self.colors.dead)
	elseif tapped then
		r, g, b = unpack(self.colors.tapped)
	else
		if layout.ManaColorSuffix then 
			r, g, b = unpack(powerType and self.colors.power[powerType .. layout.ManaColorSuffix] or self.colors.power[powerType] or self.colors.power.UNUSED)
		else 
			r, g, b = unpack(powerType and self.colors.power[powerType] or self.colors.power.UNUSED)
		end 
	end
	element:SetStatusBarColor(r, g, b)
end 

local PlayerFrame_PowerOverrideColor = function(element, unit, min, max, powerType, powerID, disconnected, dead, tapped)
	local self = element._owner
	local layout = self.layout
	local r, g, b
	if disconnected then
		r, g, b = unpack(self.colors.disconnected)
	elseif dead then
		r, g, b = unpack(self.colors.dead)
	elseif tapped then
		r, g, b = unpack(self.colors.tapped)
	else
		if layout.PowerColorSuffix then 
			r, g, b = unpack(powerType and self.colors.power[powerType .. layout.PowerColorSuffix] or self.colors.power[powerType] or self.colors.power.UNUSED)
		else 
			r, g, b = unpack(powerType and self.colors.power[powerType] or self.colors.power.UNUSED)
		end 
	end
	element:SetStatusBarColor(r, g, b)
end 

local PlayerFrame_TexturesPostUpdate = function(self, overrideLevel)
	local layout = self.layout
	local playerLevel = overrideLevel or UnitLevel("player")
	if (playerLevel >= 60) then 
		self.Health:SetSize(unpack(layout.SeasonedHealthSize))
		self.Health:SetStatusBarTexture(layout.SeasonedHealthTexture)
		self.Health.Bg:SetTexture(layout.SeasonedHealthBackdropTexture)
		self.Health.Bg:SetVertexColor(unpack(layout.SeasonedHealthBackdropColor))
		self.Power.Fg:SetTexture(layout.SeasonedPowerForegroundTexture)
		self.Power.Fg:SetVertexColor(unpack(layout.SeasonedPowerForegroundColor))
		self.Cast:SetSize(unpack(layout.SeasonedCastSize))
		self.Cast:SetStatusBarTexture(layout.SeasonedCastTexture)
		self.Threat.health:SetTexture(layout.SeasonedHealthThreatTexture)

		if (self.ExtraPower) then
			self.ExtraPower.Fg:SetTexture(layout.SeasonedManaOrbTexture)
			self.ExtraPower.Fg:SetVertexColor(unpack(layout.SeasonedManaOrbColor)) 
		end 
	elseif (playerLevel >= layout.HardenedLevel) then 
		self.Health:SetSize(unpack(layout.HardenedHealthSize))
		self.Health:SetStatusBarTexture(layout.HardenedHealthTexture)
		self.Health.Bg:SetTexture(layout.HardenedHealthBackdropTexture)
		self.Health.Bg:SetVertexColor(unpack(layout.HardenedHealthBackdropColor))
		self.Power.Fg:SetTexture(layout.HardenedPowerForegroundTexture)
		self.Power.Fg:SetVertexColor(unpack(layout.HardenedPowerForegroundColor))
		self.Cast:SetSize(unpack(layout.HardenedCastSize))
		self.Cast:SetStatusBarTexture(layout.HardenedCastTexture)
		self.Threat.health:SetTexture(layout.HardenedHealthThreatTexture)

		if (self.ExtraPower) then 
			self.ExtraPower.Fg:SetTexture(layout.HardenedManaOrbTexture)
			self.ExtraPower.Fg:SetVertexColor(unpack(layout.HardenedManaOrbColor)) 
		end 
	else 
		self.Health:SetSize(unpack(layout.NoviceHealthSize))
		self.Health:SetStatusBarTexture(layout.NoviceHealthTexture)
		self.Health.Bg:SetTexture(layout.NoviceHealthBackdropTexture)
		self.Health.Bg:SetVertexColor(unpack(layout.NoviceHealthBackdropColor))
		self.Power.Fg:SetTexture(layout.NovicePowerForegroundTexture)
		self.Power.Fg:SetVertexColor(unpack(layout.NovicePowerForegroundColor))
		self.Cast:SetSize(unpack(layout.NoviceCastSize))
		self.Cast:SetStatusBarTexture(layout.NoviceCastTexture)
		self.Threat.health:SetTexture(layout.NoviceHealthThreatTexture)

		if (self.ExtraPower) then 
			self.ExtraPower.Fg:SetTexture(layout.NoviceManaOrbTexture)
			self.ExtraPower.Fg:SetVertexColor(unpack(layout.NoviceManaOrbColor)) 
		end
	end 
end 

local PlayerHUD_ClassPowerPostCreatePoint = function(element, id, point)
	point.case = point:CreateTexture()
	point.case:SetDrawLayer("BACKGROUND", -2)
	point.case:SetVertexColor(211/255, 200/255, 169/255)

	point.slotTexture:SetPoint("TOPLEFT", -1.5, 1.5)
	point.slotTexture:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
	point.slotTexture:SetVertexColor(130/255 *.3, 133/255 *.3, 130/255 *.3, 2/3)

	point:SetOrientation("UP") -- set the bars to grow from bottom to top.
	point:SetSparkTexture(GetMedia("blank")) -- this will be too tricky to rotate and map
end

local PlayerHUD_ClassPowerPostUpdate = function(element, unit, min, max, newMax, powerType)
	local style

	-- 5 points: 4 circles, 1 larger crystal
	if (powerType == "COMBO_POINTS") then 
		style = "ComboPoints"

	-- 5 points: 5 circles, center one larger
	elseif (powerType == "CHI") then
		style = (UnitPowerMax("player", Enum.PowerType.Chi) == 6) and "Runes" or "Chi"

	--5 points: 2 circles, 3 crystals, last crystal larger
	elseif (powerType == "HOLY_POWER") or (powerType == "SOUL_SHARDS") or (powerType == "SOUL_FRAGMENTS") then 
		style = "SoulShards"

	-- 4 points: 
	elseif (powerType == "ARCANE_CHARGES") then 
		style = "ArcaneCharges"
		
	-- 3 points: 
	elseif (powerType == "STAGGER") then 
		style = "Stagger"

	-- 6 points: 
	elseif (powerType == "RUNES") then 
		style = "Runes"
	end 
	
	if (style ~= element.powerStyle) then 
		
		if (style == "ComboPoints") then
			local point1, point2, point3, point4, point5 = element[1], element[2], element[3], element[4], element[5]

			point1:SetPoint("CENTER", -203,-137)
			point1:SetSize(13,13)
			point1:SetStatusBarTexture(GetMedia("point_crystal"))
			point1:GetStatusBarTexture():SetRotation(degreesToRadians(6))
			point1.slotTexture:SetTexture(GetMedia("point_crystal"))
			point1.slotTexture:SetRotation(degreesToRadians(6))
			point1.case:SetPoint("CENTER", 0, 0)
			point1.case:SetSize(58,58)
			point1.case:SetRotation(degreesToRadians(6))
			point1.case:SetTexture(GetMedia("point_plate"))

			point2:SetPoint("CENTER", -221,-111)
			point2:SetSize(13,13)
			point2:SetStatusBarTexture(GetMedia("point_crystal"))
			point2:GetStatusBarTexture():SetRotation(degreesToRadians(5))
			point2.slotTexture:SetTexture(GetMedia("point_crystal"))
			point2.slotTexture:SetRotation(degreesToRadians(5))
			point2.case:SetPoint("CENTER", 0, 0)
			point2.case:SetSize(60,60)
			point2.case:SetRotation(degreesToRadians(5))
			point2.case:SetTexture(GetMedia("point_plate"))

			point3:SetPoint("CENTER", -231,-79)
			point3:SetSize(13,13)
			point3:SetStatusBarTexture(GetMedia("point_crystal"))
			point3:GetStatusBarTexture():SetRotation(degreesToRadians(4))
			point3.slotTexture:SetTexture(GetMedia("point_crystal"))
			point3.slotTexture:SetRotation(degreesToRadians(4))
			point3.case:SetPoint("CENTER", 0,0)
			point3.case:SetSize(60,60)
			point3.case:SetRotation(degreesToRadians(4))
			point3.case:SetTexture(GetMedia("point_plate"))
		
			point4:SetPoint("CENTER", -225,-44)
			point4:SetSize(13,13)
			point4:SetStatusBarTexture(GetMedia("point_crystal"))
			point4:GetStatusBarTexture():SetRotation(degreesToRadians(3))
			point4.slotTexture:SetTexture(GetMedia("point_crystal"))
			point4.slotTexture:SetRotation(degreesToRadians(3))
			point4.case:SetPoint("CENTER", 0, 0)
			point4.case:SetSize(60,60)
			point4.case:SetRotation(0)
			point4.case:SetTexture(GetMedia("point_plate"))
		
			point5:SetPoint("CENTER", -203,-11)
			point5:SetSize(14,21)
			point5:SetStatusBarTexture(GetMedia("point_crystal"))
			point5:GetStatusBarTexture():SetRotation(degreesToRadians(1))
			point5.slotTexture:SetTexture(GetMedia("point_crystal"))
			point5.slotTexture:SetRotation(degreesToRadians(1))
			point5.case:SetRotation(degreesToRadians(1))
			point5.case:SetPoint("CENTER",0,0)
			point5.case:SetSize(82,96)
			point5.case:SetRotation(degreesToRadians(1))
			point5.case:SetTexture(GetMedia("point_diamond"))

		elseif (style == "Chi") then
			local point1, point2, point3, point4, point5 = element[1], element[2], element[3], element[4], element[5]

			point1:SetPoint("CENTER", -203,-137)
			point1:SetSize(13,13)
			point1:SetStatusBarTexture(GetMedia("point_crystal"))
			point1:GetStatusBarTexture():SetRotation(degreesToRadians(6))
			point1.slotTexture:SetTexture(GetMedia("point_crystal"))
			point1.slotTexture:SetRotation(degreesToRadians(6))
			point1.case:SetPoint("CENTER", 0, 0)
			point1.case:SetSize(58,58)
			point1.case:SetRotation(degreesToRadians(6))
			point1.case:SetTexture(GetMedia("point_plate"))

			point2:SetPoint("CENTER", -223,-109)
			point2:SetSize(13,13)
			point2:SetStatusBarTexture(GetMedia("point_crystal"))
			point2:GetStatusBarTexture():SetRotation(degreesToRadians(5))
			point2.slotTexture:SetTexture(GetMedia("point_crystal"))
			point2.slotTexture:SetRotation(degreesToRadians(5))
			point2.case:SetPoint("CENTER", 0, 0)
			point2.case:SetSize(60,60)
			point2.case:SetRotation(degreesToRadians(5))
			point2.case:SetTexture(GetMedia("point_plate"))

			point3:SetPoint("CENTER", -234,-73)
			point3:SetSize(39,40)
			point3:SetStatusBarTexture(GetMedia("point_hearth"))
			point3:GetStatusBarTexture():SetRotation(0)
			point3.slotTexture:SetTexture(GetMedia("point_hearth"))
			point3.slotTexture:SetRotation(0)
			point3.case:SetPoint("CENTER", 0,0)
			point3.case:SetSize(80,80)
			point3.case:SetRotation(0)
			point3.case:SetTexture(GetMedia("point_plate"))
		
			point4:SetPoint("CENTER", -221,-36)
			point4:SetSize(13,13)
			point4:SetStatusBarTexture(GetMedia("point_crystal"))
			point4:GetStatusBarTexture():SetRotation(0)
			point4.slotTexture:SetTexture(GetMedia("point_crystal"))
			point4.slotTexture:SetRotation(0)
			point4.case:SetPoint("CENTER", 0, 0)
			point4.case:SetSize(60,60)
			point4.case:SetRotation(0)
			point4.case:SetTexture(GetMedia("point_plate"))
		
			point5:SetPoint("CENTER", -203,-9)
			point5:SetSize(13,13)
			point5:SetStatusBarTexture(GetMedia("point_crystal"))
			point5:GetStatusBarTexture():SetRotation(0)
			point5.slotTexture:SetTexture(GetMedia("point_crystal"))
			point5.slotTexture:SetRotation(0)
			point5.case:SetPoint("CENTER",0, 0)
			point5.case:SetSize(60,60)
			point5.case:SetRotation(0)
			point5.case:SetTexture(GetMedia("point_plate"))

		elseif (style == "SoulShards") then 
			local point1, point2, point3, point4, point5 = element[1], element[2], element[3], element[4], element[5]

			point1:SetPoint("CENTER", -203,-137)
			point1:SetSize(12,12)
			point1:SetStatusBarTexture(GetMedia("point_crystal"))
			point1:GetStatusBarTexture():SetRotation(degreesToRadians(6))
			point1.slotTexture:SetTexture(GetMedia("point_crystal"))
			point1.slotTexture:SetRotation(degreesToRadians(6))
			point1.case:SetPoint("CENTER", 0, 0)
			point1.case:SetSize(54,54)
			point1.case:SetRotation(degreesToRadians(6))
			point1.case:SetTexture(GetMedia("point_plate"))

			point2:SetPoint("CENTER", -221,-111)
			point2:SetSize(13,13)
			point2:SetStatusBarTexture(GetMedia("point_crystal"))
			point2:GetStatusBarTexture():SetRotation(degreesToRadians(5))
			point2.slotTexture:SetTexture(GetMedia("point_crystal"))
			point2.slotTexture:SetRotation(degreesToRadians(5))
			point2.case:SetPoint("CENTER", 0, 0)
			point2.case:SetSize(60,60)
			point2.case:SetRotation(degreesToRadians(5))
			point2.case:SetTexture(GetMedia("point_plate"))

			point3:SetPoint("CENTER", -235,-80)
			point3:SetSize(11,15)
			point3:SetStatusBarTexture(GetMedia("point_crystal"))
			point3:GetStatusBarTexture():SetRotation(degreesToRadians(3))
			point3.slotTexture:SetTexture(GetMedia("point_crystal"))
			point3.slotTexture:SetRotation(degreesToRadians(3))
			point3.case:SetPoint("CENTER",0,0)
			point3.case:SetSize(65,60)
			point3.case:SetRotation(degreesToRadians(3))
			point3.case:SetTexture(GetMedia("point_diamond"))
		
			point4:SetPoint("CENTER", -227,-44)
			point4:SetSize(12,18)
			point4:SetStatusBarTexture(GetMedia("point_crystal"))
			point4:GetStatusBarTexture():SetRotation(degreesToRadians(3))
			point4.slotTexture:SetTexture(GetMedia("point_crystal"))
			point4.slotTexture:SetRotation(degreesToRadians(3))
			point4.case:SetPoint("CENTER",0,0)
			point4.case:SetSize(78,79)
			point4.case:SetRotation(degreesToRadians(3))
			point4.case:SetTexture(GetMedia("point_diamond"))
		
			point5:SetPoint("CENTER", -203,-11)
			point5:SetSize(14,21)
			point5:SetStatusBarTexture(GetMedia("point_crystal"))
			point5:GetStatusBarTexture():SetRotation(degreesToRadians(1))
			point5.slotTexture:SetTexture(GetMedia("point_crystal"))
			point5.slotTexture:SetRotation(degreesToRadians(1))
			point5.case:SetRotation(degreesToRadians(1))
			point5.case:SetPoint("CENTER",0,0)
			point5.case:SetSize(82,96)
			point5.case:SetRotation(degreesToRadians(1))
			point5.case:SetTexture(GetMedia("point_diamond"))


			-- 1.414213562
		elseif (style == "Stagger") then 
			local point1, point2, point3 = element[1], element[2], element[3]

			point1:SetPoint("CENTER", -223,-109)
			point1:SetSize(13,13)
			point1:SetStatusBarTexture(GetMedia("point_crystal"))
			point1:GetStatusBarTexture():SetRotation(degreesToRadians(5))
			point1.slotTexture:SetTexture(GetMedia("point_crystal"))
			point1.slotTexture:SetRotation(degreesToRadians(5))
			point1.case:SetPoint("CENTER", 0, 0)
			point1.case:SetSize(60,60)
			point1.case:SetRotation(degreesToRadians(5))
			point1.case:SetTexture(GetMedia("point_plate"))

			point2:SetPoint("CENTER", -234,-73)
			point2:SetSize(39,40)
			point2:SetStatusBarTexture(GetMedia("point_hearth"))
			point2:GetStatusBarTexture():SetRotation(0)
			point2.slotTexture:SetTexture(GetMedia("point_hearth"))
			point2.slotTexture:SetRotation(0)
			point2.case:SetPoint("CENTER", 0,0)
			point2.case:SetSize(80,80)
			point2.case:SetRotation(0)
			point2.case:SetTexture(GetMedia("point_plate"))
		
			point3:SetPoint("CENTER", -221,-36)
			point3:SetSize(13,13)
			point3:SetStatusBarTexture(GetMedia("point_crystal"))
			point3:GetStatusBarTexture():SetRotation(0)
			point3.slotTexture:SetTexture(GetMedia("point_crystal"))
			point3.slotTexture:SetRotation(0)
			point3.case:SetPoint("CENTER", 0, 0)
			point3.case:SetSize(60,60)
			point3.case:SetRotation(0)
			point3.case:SetTexture(GetMedia("point_plate"))

		elseif (style == "ArcaneCharges") then

			local point1, point2, point3, point4, point5 = element[1], element[2], element[3], element[4], element[5]

			point1:SetPoint("CENTER", -207,-139)
			point1:SetSize(13,13)
			point1:SetStatusBarTexture(GetMedia("point_crystal"))
			point1:GetStatusBarTexture():SetRotation(degreesToRadians(6))
			point1.slotTexture:SetTexture(GetMedia("point_crystal"))
			point1.slotTexture:SetRotation(degreesToRadians(6))
			point1.case:SetPoint("CENTER", 0, 0)
			point1.case:SetSize(58,58)
			point1.case:SetRotation(degreesToRadians(6))
			point1.case:SetTexture(GetMedia("point_plate"))

			point2:SetPoint("CENTER", -228,-111)
			point2:SetSize(13,13)
			point2:SetStatusBarTexture(GetMedia("point_crystal"))
			point2:GetStatusBarTexture():SetRotation(degreesToRadians(5))
			point2.slotTexture:SetTexture(GetMedia("point_crystal"))
			point2.slotTexture:SetRotation(degreesToRadians(5))
			point2.case:SetPoint("CENTER", 0, 0)
			point2.case:SetSize(60,60)
			point2.case:SetRotation(degreesToRadians(5))
			point2.case:SetTexture(GetMedia("point_plate"))

			point3:SetPoint("CENTER", -236,-76)
			point3:SetSize(13,13)
			point3:SetStatusBarTexture(GetMedia("point_crystal"))
			point3:GetStatusBarTexture():SetRotation(degreesToRadians(4))
			point3.slotTexture:SetTexture(GetMedia("point_crystal"))
			point3.slotTexture:SetRotation(degreesToRadians(4))
			point3.case:SetPoint("CENTER", 0,0)
			point3.case:SetSize(60,60)
			point3.case:SetRotation(degreesToRadians(4))
			point3.case:SetTexture(GetMedia("point_plate"))
		
			point4:SetPoint("CENTER", -213,-33)
			point4:SetSize(39*1.3,40*1.3)
			point4:SetStatusBarTexture(GetMedia("point_hearth"))
			point4:GetStatusBarTexture():SetRotation(0)
			point4.slotTexture:SetTexture(GetMedia("point_hearth"))
			point4.slotTexture:SetRotation(0)
			point4.case:SetPoint("CENTER", 0,0)
			point4.case:SetSize(80*1.3,80*1.3)
			point4.case:SetRotation(0)
			point4.case:SetTexture(GetMedia("point_plate"))


		elseif (style == "Runes") then 
			local point1, point2, point3, point4, point5, point6 = element[1], element[2], element[3], element[4], element[5], element[6]

			point1:SetPoint("CENTER", -203,-131)
			point1:SetSize(28,28)
			point1:SetStatusBarTexture(GetMedia("point_rune2"))
			point1:GetStatusBarTexture():SetRotation(0)
			point1.slotTexture:SetTexture(GetMedia("point_rune2"))
			point1.slotTexture:SetRotation(0)
			point1.case:SetPoint("CENTER", 0, 0)
			point1.case:SetSize(58,58)
			point1.case:SetRotation(0)
			point1.case:SetTexture(GetMedia("point_dk_block"))

			point2:SetPoint("CENTER", -227,-107)
			point2:SetSize(28,28)
			point2:SetStatusBarTexture(GetMedia("point_rune4"))
			point2:GetStatusBarTexture():SetRotation(0)
			point2.slotTexture:SetTexture(GetMedia("point_rune4"))
			point2.slotTexture:SetRotation(0)
			point2.case:SetPoint("CENTER", 0, 0)
			point2.case:SetSize(68,68)
			point2.case:SetRotation(0)
			point2.case:SetTexture(GetMedia("point_dk_block"))

			point3:SetPoint("CENTER", -253,-83)
			point3:SetSize(30,30)
			point3:SetStatusBarTexture(GetMedia("point_rune1"))
			point3:GetStatusBarTexture():SetRotation(0)
			point3.slotTexture:SetTexture(GetMedia("point_rune1"))
			point3.slotTexture:SetRotation(0)
			point3.case:SetPoint("CENTER", 0,0)
			point3.case:SetSize(74,74)
			point3.case:SetRotation(0)
			point3.case:SetTexture(GetMedia("point_dk_block"))
		
			point4:SetPoint("CENTER", -220,-64)
			point4:SetSize(28,28)
			point4:SetStatusBarTexture(GetMedia("point_rune3"))
			point4:GetStatusBarTexture():SetRotation(0)
			point4.slotTexture:SetTexture(GetMedia("point_rune3"))
			point4.slotTexture:SetRotation(0)
			point4.case:SetPoint("CENTER", 0, 0)
			point4.case:SetSize(68,68)
			point4.case:SetRotation(0)
			point4.case:SetTexture(GetMedia("point_dk_block"))

			point5:SetPoint("CENTER", -246,-38)
			point5:SetSize(32,32)
			point5:SetStatusBarTexture(GetMedia("point_rune2"))
			point5:GetStatusBarTexture():SetRotation(0)
			point5.slotTexture:SetTexture(GetMedia("point_rune2"))
			point5.slotTexture:SetRotation(0)
			point5.case:SetPoint("CENTER", 0, 0)
			point5.case:SetSize(78,78)
			point5.case:SetRotation(0)
			point5.case:SetTexture(GetMedia("point_dk_block"))

			point6:SetPoint("CENTER", -214,-10)
			point6:SetSize(40,40)
			point6:SetStatusBarTexture(GetMedia("point_rune1"))
			point6:GetStatusBarTexture():SetRotation(0)
			point6.slotTexture:SetTexture(GetMedia("point_rune1"))
			point6.slotTexture:SetRotation(0)
			point6.case:SetPoint("CENTER", 0, 0)
			point6.case:SetSize(98,98)
			point6.case:SetRotation(0)
			point6.case:SetTexture(GetMedia("point_dk_block"))

		end 

		element.powerStyle = style
	end 
end

local TargetFrame_CastBarPostUpdate = function(element, unit)
	local self = element._owner
	local layout = self.layout
	local cast = self.Cast
	local health = self.Health

	local isPlayer = UnitIsPlayer(unit) -- and UnitIsEnemy(unit)
	local unitLevel = UnitLevel(unit)
	local unitClassification = (unitLevel and (unitLevel < 1)) and "worldboss" or UnitClassification(unit)
	local isBoss = unitClassification == "boss" or unitClassification == "worldboss"
	local isEliteOrRare = unitClassification == "rare" or unitClassification == "elite" or unitClassification == "rareelite"

	if ((unitLevel and unitLevel == 1) and (not UnitIsPlayer("target"))) then 
		health.Value:Hide()
		if (health.ValueAbsorb) then
			health.ValueAbsorb:Hide()
		end 
		health.ValuePercent:Hide()
		cast.Value:Hide()
		cast.Name:Hide()
	elseif (cast.casting or cast.channeling) then 
		health.Value:Hide()
		if (health.ValueAbsorb) then
			health.ValueAbsorb:Hide()
		end 
		health.ValuePercent:Hide()
		cast.Value:Show()
		cast.Name:Show()
	else 
		-- This can get called at element creation,
		-- before our styling code has set this value.
		-- We simply assume it should be hidden when this happens.
		if (self.currentStyle) then
			health.Value:SetShown(self.layout[self.currentStyle.."HealthValueVisible"])
			if (health.ValueAbsorb) then
				health.ValueAbsorb:SetShown(self.layout[self.currentStyle.."HealthValueVisible"])
			end 
			health.ValuePercent:SetShown(self.layout[self.currentStyle.."HealthPercentVisible"])
		else
			health.Value:Hide()
			if (health.ValueAbsorb) then
				health.ValueAbsorb:Hide()
			end 
			health.ValuePercent:Hide()
		end
		cast.Value:Hide()
		cast.Name:Hide()
	end 
end

local TargetFrame_LevelVisibilityFilter = function(element, unit) 
	if UnitIsDeadOrGhost(unit) then 
		return true 
	else 
		return false
	end 
end

local TargetFrame_NamePostUpdate = function(self, event, ...)
	if (event == "GP_UNITFRAME_TOT_VISIBLE") then 
		self.totVisible = true
	elseif (event == "GP_UNITFRAME_TOT_INVISIBLE") then 
		self.totVisible = nil
	elseif (event == "GP_UNITFRAME_TOT_SHOWN") then 
		self.totShown = true
	elseif (event == "GP_UNITFRAME_TOT_HIDDEN") then
		self.totShown = nil
	end
	if (self.totShown and self.totVisible and (not self.Name.usingSmallWidth)) then 
		self.Name.maxChars = 30
		self.Name.usingSmallWidth = true
		self.Name:ForceUpdate()
		local Core = Wheel("LibModule"):GetModule(ADDON, true)
		if (Core) then 
			local UnitFrameTarget = Core:GetModule("UnitFrameTarget", true)
			if (UnitFrameTarget) then 
				UnitFrameTarget:AddDebugMessageFormatted("UnitFrameTarget changed name element width to small.")
			end
		end
	elseif (self.Name.usingSmallWidth) then
		self.Name.maxChars = 64
		self.Name.usingSmallWidth = nil
		self.Name:ForceUpdate()
		local Core = Wheel("LibModule"):GetModule(ADDON, true)
		if (Core) then 
			local UnitFrameTarget = Core:GetModule("UnitFrameTarget", true)
			if (UnitFrameTarget) then 
				UnitFrameTarget:AddDebugMessageFormatted("UnitFrameTarget changed name element width to full.")
			end
		end
	end 
end

local TargetFrame_PowerValueOverride = function(element, unit, min, max, powerType, powerID, disconnected, dead, tapped)
	local value = element.Value
	if (min == 0 or max == 0) and (not value.showAtZero) then
		value:SetText("")
	else
		value:SetFormattedText("%.0f", math_floor(min/max * 100))
	end 
end

local TargetFrame_PowerVisibilityFilter = function(element, unit) 
	if UnitIsDeadOrGhost(unit) then 
		return false 
	else 
		return true
	end 
end

local TargetFrame_TexturesPostUpdate = function(self)
	if (not UnitExists("target")) then 
		return
	end 
	local targetStyle

	-- Figure out if the various artwork and bar textures need to be updated
	-- We could put this into element post updates, 
	-- but to avoid needless checks we limit this to actual target updates. 
	local targetLevel = UnitLevel("target") or 0
	local classification = UnitClassification("target")
	local creatureType = UnitCreatureType("target")

	if UnitIsPlayer("target") then 
		if ((targetLevel < 1) or (targetLevel >= 60)) then 
			targetStyle = "Seasoned"
		elseif (targetLevel >= self.layout.HardenedLevel) then 
			targetStyle = "Hardened"
		else
			targetStyle = "Novice" 
		end 
	elseif ((classification == "worldboss") or (targetLevel < 1)) then 
		targetStyle = "Boss"
	elseif (targetLevel >= 60) then 
		targetStyle = "Seasoned"
	elseif (targetLevel >= self.layout.HardenedLevel) then 
		targetStyle = "Hardened"
	elseif (creatureType == "Critter") or (targetLevel == 1) then 
		targetStyle = "Critter"
	else
		targetStyle = "Novice" 
	end 

	-- Silently return if there was no change
	if (targetStyle == self.currentStyle) or (not targetStyle) then 
		return 
	end 

	-- Update aura layouts
	-- A little hardcoded for now.
	if (targetStyle == "Boss") then 
		if (self.currentStyle ~= "Boss") then
			self.Auras.maxVisible = 20
			self.Auras:SetSize(unpack(self.layout.AuraFrameSizeBoss))
			self.Auras:ForceUpdate()
		end
	else
		if (self.currentStyle == "Boss") then
			self.Auras.maxVisible = 14
			self.Auras:SetSize(unpack(self.layout.AuraFrameSize))
			self.Auras:ForceUpdate()
		end
	end

	-- Store the new style
	self.currentStyle = targetStyle

	self.Health:Place(unpack(self.layout[self.currentStyle.."HealthPlace"]))
	self.Health:SetSize(unpack(self.layout[self.currentStyle.."HealthSize"]))
	self.Health:SetStatusBarTexture(self.layout[self.currentStyle.."HealthTexture"])
	self.Health:SetSparkMap(self.layout[self.currentStyle.."HealthSparkMap"])

	self.Health.Bg:ClearAllPoints()
	self.Health.Bg:SetPoint(unpack(self.layout[self.currentStyle.."HealthBackdropPlace"]))
	self.Health.Bg:SetSize(unpack(self.layout[self.currentStyle.."HealthBackdropSize"]))
	self.Health.Bg:SetTexture(self.layout[self.currentStyle.."HealthBackdropTexture"])
	self.Health.Bg:SetVertexColor(unpack(self.layout[self.currentStyle.."HealthBackdropColor"]))

	self.Health.Value:SetShown(self.layout[self.currentStyle.."HealthValueVisible"])
	self.Health.ValuePercent:SetShown(self.layout[self.currentStyle.."HealthPercentVisible"])

	self.Threat.health:SetTexture(self.layout[self.currentStyle.."HealthThreatTexture"])
	self.Threat.health:ClearAllPoints()
	self.Threat.health:SetPoint(unpack(self.layout[self.currentStyle.."HealthThreatPlace"]))
	self.Threat.health:SetSize(unpack(self.layout[self.currentStyle.."HealthThreatSize"]))
	
	self.Cast:Place(unpack(self.layout[self.currentStyle.."CastPlace"]))
	self.Cast:SetSize(unpack(self.layout[self.currentStyle.."CastSize"]))
	self.Cast:SetStatusBarTexture(self.layout[self.currentStyle.."CastTexture"])
	self.Cast:SetSparkMap(self.layout[self.currentStyle.."CastSparkMap"])

	self.Portrait.Fg:SetTexture(self.layout[self.currentStyle.."PortraitForegroundTexture"])
	self.Portrait.Fg:SetVertexColor(unpack(self.layout[self.currentStyle.."PortraitForegroundColor"]))
	
end 

local SmallFrame_AlphaPostUpdate = function(self)
	local unit = self.unit
	if (not unit) then 
		return 
	end 

	local targetStyle

	-- Hide it when tot is the same as the target
	if self.hideWhenUnitIsPlayer and (UnitIsUnit(unit, "player")) then 
		targetStyle = "Hidden"

	elseif self.hideWhenUnitIsTarget and (UnitIsUnit(unit, "target")) then 
		targetStyle = "Hidden"

	elseif self.hideWhenTargetIsCritter then 
		local level = UnitLevel("target")
		if ((level and level == 1) and (not UnitIsPlayer("target"))) then 
			targetStyle = "Hidden"
		else 
			targetStyle = "Shown"
		end 
	else 
		targetStyle = "Shown"
	end 

	-- Silently return if there was no change
	if (targetStyle == self.alphaStyle) then 
		return 
	end 

	-- Store the new style
	self.alphaStyle = targetStyle

	-- Apply the new style
	if (targetStyle == "Shown") then 
		self:SetAlpha(1)
		self:SendMessage("GP_UNITFRAME_TOT_VISIBLE")
	elseif (targetStyle == "Hidden") then 
		self:SetAlpha(0)
		self:SendMessage("GP_UNITFRAME_TOT_INVISIBLE")
	end

	if self.TargetHighlight then 
		self.TargetHighlight:ForceUpdate()
	end
end

local SmallFrame_BarTextPostUpdate = function(element, unit)
	local self = element._owner
	local cast = self.Cast
	local healthValue = self.Health.ValuePercent
	if (UnitIsDeadOrGhost(unit)) then
		healthValue:SetText(DEAD)
		healthValue:Show()
	elseif (cast.casting or cast.channeling) then
		healthValue:Hide()
	else
		healthValue:Show()
	end
end

local TinyFrame_PowerBarPostUpdate = function(element, unit, min, max, powerType, powerID)
	if (min == 0) or (max == 0) then
		element:SetAlpha(0)
	else
		local _,class = UnitClass(unit)
		if (class == "DRUID") or (class == "PALADIN") or (class == "PRIEST") or (class == "SHAMAN") then
			if (min/max < .9) then
				element:SetAlpha(.75)
			else
				element:SetAlpha(0)
			end
		elseif (class == "MAGE") or (class == "WARLOCK") then
			if (min/max < .5) then
				element:SetAlpha(.75)
			else
				element:SetAlpha(0)
			end
		else
			-- The threshold for the "oom" message is .25
			if (min/max < .25) then
				element:SetAlpha(.75)
			else
				element:SetAlpha(0)
			end
		end
	end
end

local UnitFrame_Aura_PostCreateButton = function(element, button)
	local layout = element._owner.layout

	button.Icon:SetTexCoord(unpack(layout.AuraIconTexCoord))
	button.Icon:SetSize(unpack(layout.AuraIconSize))
	button.Icon:ClearAllPoints()
	button.Icon:SetPoint(unpack(layout.AuraIconPlace))

	button.Count:SetFontObject(layout.AuraCountFont)
	button.Count:SetJustifyH("CENTER")
	button.Count:SetJustifyV("MIDDLE")
	button.Count:ClearAllPoints()
	button.Count:SetPoint(unpack(layout.AuraCountPlace))
	if layout.AuraCountColor then 
		button.Count:SetTextColor(unpack(layout.AuraCountColor))
	end 

	button.Time:SetFontObject(layout.AuraTimeFont)
	button.Time:ClearAllPoints()
	button.Time:SetPoint(unpack(layout.AuraTimePlace))

	local layer, level = button.Icon:GetDrawLayer()

	button.Darken = button.Darken or button:CreateTexture()
	button.Darken:SetDrawLayer(layer, level + 1)
	button.Darken:SetSize(button.Icon:GetSize())
	button.Darken:SetPoint("CENTER", 0, 0)
	button.Darken:SetColorTexture(0, 0, 0, .25)

	button.Overlay:SetFrameLevel(button:GetFrameLevel() + 10)
	button.Overlay:ClearAllPoints()
	button.Overlay:SetPoint("CENTER", 0, 0)
	button.Overlay:SetSize(button.Icon:GetSize())

	button.Border = button.Border or button.Overlay:CreateFrame("Frame")
	button.Border:SetFrameLevel(button.Overlay:GetFrameLevel() - 5)
	button.Border:ClearAllPoints()
	button.Border:SetPoint(unpack(layout.AuraBorderFramePlace))
	button.Border:SetSize(unpack(layout.AuraBorderFrameSize))
	button.Border:SetBackdrop(layout.AuraBorderBackdrop)
	button.Border:SetBackdropColor(unpack(layout.AuraBorderBackdropColor))
	button.Border:SetBackdropBorderColor(unpack(layout.AuraBorderBackdropBorderColor))
end

local UnitFrame_Aura_PostUpdateButton = function(element, button)
	local unit = button.unit
	if (not unit) then
		return
	end

	-- Border
	if (element.isFriend) then
		if (button.isBuff) then 
			button.Border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
		else
			local color = Colors.debuff[button.debuffType or "none"]
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			else
				button.Border:SetBackdropBorderColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3])
			end 
		end
	else 
		if (button.isStealable) then 
			local color = Colors.power.ARCANE_CHARGES
			if (color) then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			else
				button.Border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
			end 
		elseif (button.isBuff) then 
			button.Border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
		else
			local color = Colors.debuff.none
			if (color) then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			else
				button.Border:SetBackdropBorderColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3])
			end 
		end
	end

	-- Icon
	local desaturate
	if (element.isYou) then
		-- Desature buffs on you cast by others
		if (button.isBuff) and (not button.isCastByPlayer) then 
			desaturate = true
		end
	elseif (element.isFriend) then
		-- Desature buffs on friends not cast by you
		if (button.isBuff) and (not button.isCastByPlayer) then 
			desaturate = true
		end
	else
		-- Desature debuffs not cast by you on attackable units
		if (not button.isBuff) and (not button.isCastByPlayer) then 
			desaturate = true
		end
	end

	if (desaturate) then
		button.Icon:SetDesaturated(true)
		button.Icon:SetVertexColor(.4, .4, .4)
	else
		button.Icon:SetDesaturated(false)
		button.Icon:SetVertexColor(1, 1, 1)
	end

end

------------------------------------------------------------------
-- UnitFrame Config Templates
------------------------------------------------------------------

-- Used for Pet, also the base for the variants below.
local Template_SmallFrame = {
	["AlphaPostUpdate"] = SmallFrame_AlphaPostUpdate,
	["CastBarColor"] = { 1, 1, 1, .15 },
	["CastBarNameColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
	["CastBarNameDrawLayer"] = { "OVERLAY", 1 }, 
	["CastBarNameFont"] = GetFont(12, true),
	["CastBarNameJustifyH"] = "CENTER", 
	["CastBarNameJustifyV"] = "MIDDLE",
	["CastBarNameParent"] = "Health",
	["CastBarNamePlace"] = { "CENTER", 0, 1 },
	["CastBarNameSize"] = { 92, 11 }, 
	["CastBarOrientation"] = "RIGHT", 
	["CastBarPlace"] = { "CENTER", 0, 0 },
	CastBarPostUpdate =	SmallFrame_BarTextPostUpdate,
	["CastBarSize"] = { 112, 11 },
	["CastBarSmoothingFrequency"] = .15,
	["CastBarSmoothingMode"] = "bezier-fast-in-slow-out", 
	["CastBarSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =   4/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 126/128, offset = -16/32 },
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =   4/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 126/128, offset = -16/32 },
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		}
	},
	["CastBarTexture"] = GetMedia("cast_bar"), 
	["FrameLevel"] = 20, 
	["HealthBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["HealthBackdropDrawLayer"] = { "BACKGROUND", -1 },
	["HealthBackdropPlace"] = { "CENTER", 1, -2 },
	["HealthBackdropSize"] = { 193,93 },
	["HealthBackdropTexture"] = GetMedia("cast_back"), 
	["HealthBarTexture"] = GetMedia("cast_bar"), 
	["HealthBarOrientation"] = "RIGHT", 
	["HealthBarPostUpdate"] = SmallFrame_BarTextPostUpdate, 
	["HealthBarSetFlippedHorizontally"] = false, 
	["HealthBarSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =   4/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =   4/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 126/128, offset = -16/32 },
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		}
	},
	["HealthFrequentUpdates"] = true, 
	["HealthPercentColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
	["HealthPercentDrawLayer"] = { "OVERLAY", 1 },
	["HealthPercentFont"] = GetFont(14, true),
	["HealthPercentJustifyH"] = "CENTER", 
	["HealthPercentJustifyV"] = "MIDDLE", 
	["HealthPercentPlace"] = { "CENTER", 0, 0 },
	["HealthPlace"] = { "CENTER", 0, 0 }, 
	["HealthSize"] = { 112, 11 },
	["HealthSmoothingFrequency"] = .2, 
	["HealthSmoothingMode"] = "bezier-fast-in-slow-out", 
	["Size"] = { 136, 47 },
	["TargetHighlightDrawLayer"] = { "BACKGROUND", 0 },
	["TargetHighlightParent"] = "Health", 
	["TargetHighlightPlace"] = { "CENTER", 1, -2 },
	["TargetHighlightSize"] = { 193,93 },
	["TargetHighlightShowFocus"] = true, TargetHighlightFocusColor = { 144/255, 195/255, 255/255, 1 }, 
	["TargetHighlightShowTarget"] = true, TargetHighlightTargetColor = { 255/255, 239/255, 169/255, 1 }, 
	["TargetHighlightTexture"] = GetMedia("cast_back_outline")
}

-- Really just a base for the reversed variant below.
local Template_SmallFrame_Auras = setmetatable({
	["Aura_PostCreateButton"] = UnitFrame_Aura_PostCreateButton,
	["Aura_PostUpdateButton"] = UnitFrame_Aura_PostUpdateButton,
	["AuraBorderBackdrop"] = { edgeFile = GetMedia("aura_border"), edgeSize = 16 },
	["AuraBorderBackdropColor"] = { 0, 0, 0, 0 },
	["AuraBorderBackdropBorderColor"] = { Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3 },
	["AuraBorderFramePlace"] = { "CENTER", 0, 0 }, 
	["AuraBorderFrameSize"] = { 44, 44 },
	["AuraCountColor"] = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	["AuraCountFont"] = GetFont(12, true),
	["AuraCountPlace"] = { "BOTTOMRIGHT", 9, -6 },
	["AuraFramePlace"] = { "LEFT", 149, -1 },
	["AuraFrameSize"] = { 200, 30 },
	["AuraIconPlace"] = { "CENTER", 0, 0 },
	["AuraIconSize"] = { 24, 24 },
	["AuraIconTexCoord"] = { 5/64, 59/64, 5/64, 59/64 },
	["AuraProperties"] = {
		["auraHeight"] = nil, 
		["auraSize"] = 30, 
		["auraWidth"] = nil, 
		["debuffsFirst"] = false, 
		["disableMouse"] = false, 
		["growthX"] = "RIGHT", 
		["growthY"] = "UP", 
		["maxVisible"] = 6, 
		["showDurations"] = true, 
		["showSpirals"] = false, 
		["showLongDurations"] = true,
		["spacingH"] = 4, 
		["spacingV"] = 4, 
		["tooltipAnchor"] = nil,
		["tooltipDefaultPosition"] = false, 
		["tooltipOffsetX"] = 8,
		["tooltipOffsetY"] = 16,
		["tooltipPoint"] = "BOTTOMLEFT",
		["tooltipRelPoint"] = "TOPLEFT"
	},
	["AuraTimeFont"] = GetFont(11, true),
	["AuraTimePlace"] = { "TOPLEFT", -6, 6 }
}, { __index = Template_SmallFrame })

-- Used for ToT.
local Template_SmallFrameReversed = setmetatable({
	["CastBarOrientation"] = "LEFT", 
	["CastBarSetFlippedHorizontally"] = true, 
	["HealthBarOrientation"] = "LEFT", 
	["HealthBarSetFlippedHorizontally"] = true 
}, { __index = Template_SmallFrame })

-- Used for Boss.
local Template_SmallFrameReversed_Auras = setmetatable({
	["AuraFramePlace"] = { "RIGHT", -149, -1 },
	["AuraProperties"] = {
		["auraHeight"] = nil, 
		["auraSize"] = 30, 
		["auraWidth"] = nil, 
		["debuffsFirst"] = false, 
		["disableMouse"] = false, 
		["customFilter"] = GetAuraFilter(), 
		["growthX"] = "LEFT", 
		["growthY"] = "DOWN", 
		["maxVisible"] = 6, 
		["showDurations"] = true, 
		["showSpirals"] = false, 
		["showLongDurations"] = true,
		["spacingH"] = 4, 
		["spacingV"] = 4, 
		["tooltipAnchor"] = nil,
		["tooltipDefaultPosition"] = false, 
		["tooltipOffsetX"] = -8,
		["tooltipOffsetY"] = -16,
		["tooltipPoint"] = "TOPRIGHT",
		["tooltipRelPoint"] = "BOTTOMRIGHT"
	},
	["CastBarOrientation"] = "LEFT", 
	["CastBarSetFlippedHorizontally"] = true, 
	["HealthBarOrientation"] = "LEFT", 
	["HealthBarSetFlippedHorizontally"] = true
}, { __index = Template_SmallFrame_Auras })

-- Used for Raid and Party frames.
local Template_TinyFrame = {
	["Size"] = { 130, 30 },

	["RangeOutsideAlpha"] = .6, -- was .35, but that's too hard to see

	["HealthPlace"] = { "BOTTOM", 0, 0 }, 
	["HealthSize"] = { 80, 14 },  -- health size
	["HealthBarTexture"] = GetMedia("cast_bar"), 
	["HealthBarOrientation"] = "RIGHT", -- bar orientation
	["HealthBarSetFlippedHorizontally"] = false, 
	["HealthBarSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		}
	},
	["HealthSmoothingMode"] = "bezier-fast-in-slow-out", -- smoothing method
	["HealthSmoothingFrequency"] = .2, -- speed of the smoothing method
	["HealthFrequentUpdates"] = true, -- listen to frequent health events for more accurate updates
	["HealthBackdropPlace"] = { "CENTER", 1, -2 },
	["HealthBackdropSize"] = { 140,90 },
	["HealthBackdropTexture"] = GetMedia("cast_back"), 
	["HealthBackdropDrawLayer"] = { "BACKGROUND", -1 },
	["HealthBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 

	["CastBarPlace"] = { "BOTTOM", 0, 0 },
	["CastBarSize"] = { 80, 14 },
	["CastBarOrientation"] = "RIGHT", 
	["CastBarSmoothingMode"] = "bezier-fast-in-slow-out", 
	["CastBarSmoothingFrequency"] = .15,
	["CastBarSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		}
	},
	["CastBarTexture"] = GetMedia("cast_bar"), 
	["CastBarColor"] = { 1, 1, 1, .15 },

	["TargetHighlightParent"] = "Health", 
	["TargetHighlightPlace"] = { "CENTER", 1, -2 },
	["TargetHighlightSize"] = { 140, 90 },
	["TargetHighlightTexture"] = GetMedia("cast_back_outline"), 
	["TargetHighlightDrawLayer"] = { "BACKGROUND", 0 },
	["TargetHighlightShowTarget"] = true, TargetHighlightTargetColor = { 255/255, 229/255, 109/255, 1 }, 
	["TargetHighlightShowFocus"] = true, TargetHighlightFocusColor = { 44/255, 165/255, 255/255, 1 }, 
}

------------------------------------------------
-- Module Layouts
------------------------------------------------
-- The purpose of this is to supply all the front-end modules
-- with static layout data used during the setup phase.
-- 
-- I advice tinkerers to be careful when changing these,
-- as most modules assume that other modules have the settings I gave them.
-- This means that if you change something like let's say the position
-- of the minimap, you'll also have to change a variety of other things
-- like which way tooltips grow, where the default position of all tooltips are,
-- where the integrated MBB button is placed, and so on. 
-- Not all of those can be changed through the layout, some things are in the modules.
local RegisterLayout = Private.RegisterLayout
local RegisterLayoutVariation = Private.RegisterLayoutVariation
local RegisterSchematic = Private.RegisterSchematic

-- Options menu
RegisterLayout("OptionsMenu", "Azerite", {
	["MenuBorderBackdropBorderColor"] = { 1, 1, 1, 1 },
	["MenuBorderBackdropColor"] = { .05, .05, .05, .85 },
	["MenuButton_PostCreate"] = Core_MenuButton_PostCreate, 
	["MenuButton_PostUpdate"] = Core_MenuButton_PostUpdate,
	["MenuButtonNormalColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3] }, 
	["MenuButtonSize"] = { 300, 50 },
	["MenuButtonSizeMod"] = .75, 
	["MenuButtonSpacing"] = 8, 
	["MenuPlace"] = { "BOTTOMRIGHT", -41, 32 },
	["MenuSize"] = { 320 -10, 70 }, 
	["MenuButtonTitleColor"] = { Colors.title[1], Colors.title[2], Colors.title[3] },
	["MenuToggleButtonSize"] = { 48, 48 }, 
	["MenuToggleButtonPlace"] = { "BOTTOMRIGHT", -4, 4 },
	["MenuToggleButtonIcon"] = GetMedia("config_button"),
	["MenuToggleButtonIconPlace"] = { "CENTER", 0, 0 },
	["MenuToggleButtonIconSize"] = { 96, 96 },
	["MenuToggleButtonIconColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["MenuWindow_CreateBorder"] = function(self) return GetBorder(self) end
})

-- Blizzard Chat Frames
RegisterLayout("BlizzardChatFrames", "Azerite", {
	["AlternateChatFramePlace"] = { "TOPLEFT", 85, -64 },
	["AlternateChatFrameSize"] = { 499, 176 }, 
	["AlternateClampRectInsets"] = { -54, -54, -64, -350 },
	["ButtonFrameWidth"] = 48, ScrollBarWidth = 32, 
	["ButtonTextureChatEmotes"] = GetMedia("config_button_emotes"),
	["ButtonTextureColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["ButtonTextureMinimizeButton"] = GetMedia("icon_chat_minus"),
	["ButtonTextureNormal"] = GetMedia("point_block"),
	["ButtonTextureScrollUpButton"] = GetMedia("icon_chat_up"), 
	["ButtonTextureScrollDownButton"] = GetMedia("icon_chat_down"), 
	["ButtonTextureScrollToBottomButton"] = GetMedia("icon_chat_bottom"), 
	["ButtonTextureSize"] = { 64, 64 },
	["ChatFadeTime"] = 5, 
	["ChatIndentedWordWrap"] = false, 
	["ChatVisibleTime"] = 15, 
	["DefaultChatFramePlace"] = { "BOTTOMLEFT", 85, 350 }, 
	["DefaultChatFramePlaceFaded"] = { "BOTTOMLEFT", 85, 64 }, 
	["DefaultChatFrameSize"] = { 499, 176 }, 
	["DefaultClampRectInsets"] = { -54, -54, -310, -350 },
	["DefaultClampRectInsetsFaded"] = { -54, -54, -310, -64 },
	["EditBoxHeight"] = 45, 
	["EditBoxOffsetH"] = 15
})
RegisterLayoutVariation("BlizzardChatFrames", "Legacy", "Azerite", {
	["AlternateChatFramePlace"] = false,
	["AlternateChatFrameSize"] = false, 
	["AlternateClampRectInsets"] = false, 
	["DefaultChatFramePlace"] = { "BOTTOMLEFT", 70, 54 },
	["DefaultChatFrameSize"] = { 420, 160 }, -- way too large to fit down there; 419, 196
	["DefaultClampRectInsets"] = { -54, -54, -54, -54 },
	["DefaultChatFramePlaceFaded"] = false, 
	["DefaultClampRectInsetsFaded"] = false
})

-- Blizzard Floaters
RegisterLayout("BlizzardFloaterHUD", "Azerite", {
	["AlertFramesAnchor"] = "BOTTOM",
	["AlertFramesOffset"] = -10,
	["AlertFramesPlace"] = { "TOP", "UICenter", "TOP", 0, -40 },
	["AlertFramesPlaceTalkingHead"] = { "TOP", "UICenter", "TOP", 0, -240 },
	["AlertFramesPosition"] = "TOP",
	["AlertFramesSize"] = { 180, 20 },
	["ErrorFrameStrata"] = "LOW",
	["ExtraActionButtonBorderColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 },
	["ExtraActionButtonBorderDrawLayer"] = { "BORDER", 1 },
	["ExtraActionButtonBorderPlace"] = { "CENTER", 0, 0 },
	["ExtraActionButtonBorderSize"] = { 64/(122/256), 64/(122/256) },
	["ExtraActionButtonBorderTexture"] = GetMedia("actionbutton-border"),
	["ExtraActionButtonCooldownBlingColor"] = { 0, 0, 0 , 0 },
	["ExtraActionButtonCooldownBlingTexture"] = GetMedia("blank"),
	["ExtraActionButtonCooldownPlace"] = { "CENTER", 0, 0 },
	["ExtraActionButtonCooldownSize"] = { 44, 44 },
	["ExtraActionButtonCooldownSwipeColor"] = { 0, 0, 0, .75 },
	["ExtraActionButtonCooldownSwipeTexture"] = GetMedia("actionbutton-mask-circular"),
	["ExtraActionButtonCount"] = GetFont(18, true),
	["ExtraActionButtonCountJustifyH"] = "CENTER",
	["ExtraActionButtonCountJustifyV"] = "BOTTOM",
	["ExtraActionButtonCountPlace"] = { "BOTTOMRIGHT", -3, 3 },
	["ExtraActionButtonIconSize"] = { 44, 44 },
	["ExtraActionButtonIconMaskTexture"] = GetMedia("actionbutton-mask-circular"),  
	["ExtraActionButtonIconPlace"] = { "CENTER", 0, 0 },
	["ExtraActionButtonKeybindColor"] = { Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3], .75 },
	["ExtraActionButtonKeybindFont"] = GetFont(15, true),
	["ExtraActionButtonKeybindPlace"] = { "TOPLEFT", 5, -5 },
	["ExtraActionButtonKeybindJustifyH"] = "CENTER",
	["ExtraActionButtonKeybindJustifyV"] = "BOTTOM",
	["ExtraActionButtonKeybindShadowColor"] = { 0, 0, 0, 1 },
	["ExtraActionButtonKeybindShadowOffset"] = { 0, 0 },
	["ExtraActionButtonPlace"] = { "CENTER", 0, 0 },
	["ExtraActionButtonShowCooldownBling"] = true,
	["ExtraActionButtonShowCooldownSwipe"] = true,
	["ExtraActionButtonSize"] = { 64, 64 },
	["QuestTimerFramePlace"] = { "CENTER", UIParent, "CENTER", 0, 220 },
	["TalkingHeadFramePlace"] = { "TOP", "UICenter", "TOP", 0, -(60 + 40) },
	["ArcheologyDigsiteProgressBarPlace"] = { "BOTTOM", "UICenter", "BOTTOM", 0, 390 },

	["VehicleSeatIndicatorPlace"] = { "CENTER", "UICenter", "BOTTOMRIGHT", -480, 210 },
	["ZoneAbilityButtonBorderColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 },
	["ZoneAbilityButtonBorderDrawLayer"] = { "BORDER", 1 },
	["ZoneAbilityButtonBorderPlace"] = { "CENTER", 0, 0 },
	["ZoneAbilityButtonBorderSize"] = { 64/(122/256), 64/(122/256) },
	["ZoneAbilityButtonBorderTexture"] = GetMedia("actionbutton-border"),
	["ZoneAbilityButtonCooldownBlingColor"] = { 0, 0, 0 , 0 },
	["ZoneAbilityButtonCooldownBlingTexture"] = GetMedia("blank"),
	["ZoneAbilityButtonCooldownPlace"] = { "CENTER", 0, 0 },
	["ZoneAbilityButtonCooldownSize"] = { 44, 44 },
	["ZoneAbilityButtonCooldownSwipeColor"] = { 0, 0, 0, .75 },
	["ZoneAbilityButtonCooldownSwipeTexture"] = GetMedia("actionbutton-mask-circular"),
	["ZoneAbilityButtonCount"] = GetFont(18, true),
	["ZoneAbilityButtonCountPlace"] = { "BOTTOMRIGHT", -3, 3 },
	["ZoneAbilityButtonCountJustifyH"] = "CENTER",
	["ZoneAbilityButtonCountJustifyV"] = "BOTTOM",
	["ZoneAbilityButtonIconMaskTexture"] = GetMedia("actionbutton-mask-circular"),
	["ZoneAbilityButtonIconPlace"] = { "CENTER", 0, 0 },
	["ZoneAbilityButtonIconSize"] = { 44, 44 },
	["ZoneAbilityButtonPlace"] = { "CENTER", 0, 0 },
	["ZoneAbilityButtonShowCooldownSwipe"] = true,
	["ZoneAbilityButtonShowCooldownBling"] = true,
	["ZoneAbilityButtonSize"] = { 64, 64 }
})
RegisterLayoutVariation("BlizzardFloaterHUD", "Legacy", "Azerite", {
	["VehicleSeatIndicatorPlace"] = { "CENTER", "UICenter", "BOTTOMRIGHT", -130, 80 }, 
	["ArcheologyDigsiteProgressBarPlace"] = { "BOTTOM", "UICenter", "BOTTOM", 0, 390 },
})

-- Blizzard font replacements
RegisterLayout("BlizzardFonts", "Azerite", {
	["BlizzChatBubbleFont"] = GetFont(13, true, false),
	["ChatBubbleFont"] = GetFont(16, true, true),
	["ChatFont"] = GetFont(15, true, true)
})

-- Blizzard Game Menu (Esc)
RegisterLayout("BlizzardGameMenu", "Azerite", {
	["MenuButton_PostCreate"] = Core_MenuButton_PostCreate,
	["MenuButton_PostUpdate"] = Core_MenuButton_PostUpdate,
	["MenuButtonSize"] = { 300, 50 },
	["MenuButtonSizeMod"] = .75, 
	["MenuButtonSpacing"] = 8
})

-- Blizzard MicroMenu
RegisterLayout("BlizzardMicroMenu", "Azerite", {
	["ButtonFont"] = GetFont(14, false),
	["ButtonFontColor"] = { 0, 0, 0 }, 
	["ButtonFontShadowColor"] = { 1, 1, 1, .5 },
	["ButtonFontShadowOffset"] = { 0, -.85 },
	["ConfigWindowBackdrop"] = {
		["bgFile"] = [[Interface\ChatFrame\ChatFrameBackground]],
		["edgeFile"] = GetMedia("tooltip_border"), edgeSize = 23, 
		["insets"] = { top = 17.25, bottom = 17.25, left = 17.25, right = 17.25 }
	},
	["MenuButton_PostCreate"] = Core_MenuButton_PostCreate,
	["MenuButton_PostUpdate"] = Core_MenuButton_PostUpdate, 
	["MenuButtonNormalColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3] }, 
	["MenuButtonSize"] = { 300, 50 },
	["MenuButtonSizeMod"] = .75, 
	["MenuButtonSpacing"] = 8, 
	["MenuButtonTitleColor"] = { Colors.title[1], Colors.title[2], Colors.title[3] },
	["MenuWindow_CreateBorder"] = function(self) return GetBorder(self) end
})

-- Blizzard Timers (mirror, quest)
RegisterLayout("BlizzardTimers", "Azerite", {
	["MirrorAnchor"] = Wheel("LibFrame"):GetFrame(),
	["MirrorAnchorOffsetX"] = 0,
	["MirrorAnchorOffsetY"] = -370, 
	["MirrorAnchorPoint"] = "TOP",
	["MirrorBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["MirrorBackdropDrawLayer"] = { "BACKGROUND", -5 },
	["MirrorBackdropPlace"] = { "CENTER", 1, -2 }, 
	["MirrorBackdropSize"] = { 193,93 }, 
	["MirrorBackdropTexture"] = GetMedia("cast_back"),
	["MirrorBarColor"] = { Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3] }, 
	["MirrorBarPlace"] = { "CENTER", 0, 0 },
	["MirrorBarSize"] = { 111, 12 }, 
	["MirrorBarSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		}
	},
	["MirrorBarTexture"] = GetMedia("cast_bar"), 
	["MirrorBarValueColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .7 },
	["MirrorBarValueFont"] = GetFont(14, true),
	["MirrorBarValuePlace"] = { "CENTER", 0, 0 }, 
	["MirrorBlankTexture"] = GetMedia("blank"), 
	["MirrorGrowth"] = -50, 
	["MirrorSize"] = { 111, 14 }
})

-- Blizzard Objectives Tracker
RegisterLayout("BlizzardObjectivesTracker", "Azerite", (IsClassic or IsTBC) and {
	["FontObject"] = GetFont(13, true),
	["FontObjectTitle"] = GetFont(15, true),
	["HideInBossFights"] = true,
	["HideInCombat"] = false,
	["MaxHeight"] = 400,
	["Place"] = { "BOTTOMRIGHT", -60, 380 },
	["Scale"] = 1.0, 
	["SpaceBottom"] = 380, 
	["SpaceTop"] = 260, 
	["Width"] = 255 -- 280 is classic default
} or (IsRetail) and {
	["Place"] = { "TOPRIGHT", -60, -280 },
	["Width"] = 235, -- 235 default
	["Scale"] = 1.1, 
	["SpaceTop"] = 260, 
	["SpaceBottom"] = 380, 
	["MaxHeight"] = 340, -- need room for totems and stuff.
	["HideInCombat"] = false, 
	["HideInBossFights"] = true, 
	["HideInVehicles"] = false,
	["HideInArena"] = true
})
RegisterLayoutVariation("BlizzardObjectivesTracker", "Legacy", "Azerite", (IsClassic or IsTBC) and {
	["FontObject"] = GetFont(13, true),
	["FontObjectTitle"] = GetFont(15, true),
	["HideInBossFights"] = true,
	["HideInCombat"] = false,
	["MaxHeight"] = 1080 - (60 + 380),
	["Place"] = { "BOTTOMRIGHT", -60, 60 },
	["Scale"] = 1.0, 
	["SpaceBottom"] = 380, 
	["SpaceTop"] = 260, 
	["Width"] = 255 -- 280 is classic default
} or (IsRetail) and {
	["Place"] = { "TOPRIGHT", -60, -420 },
	["Width"] = 220, -- 235 default
	["Scale"] = 1.1, 
	["SpaceTop"] = 420, 
	["SpaceBottom"] = 220, 
	["MaxHeight"] = 1080 - (60 + 380),
	["HideInCombat"] = false, 
	["HideInBossFights"] = true, 
	["HideInVehicles"] = false,
	["HideInArena"] = true
})

-- Blizzard Popup Styling
RegisterLayout("BlizzardPopupStyling", "Azerite", {
	["EditBoxBackdrop"] = {
		["bgFile"] = [[Interface\ChatFrame\ChatFrameBackground]], tile = false, 
		["edgeFile"] = [[Interface\ChatFrame\ChatFrameBackground]], edgeSize = 1,
		["insets"] = { left = -6, right = -6, top = 0, bottom = 0 }
	},
	["EditBoxBackdropColor"] = { 0, 0, 0, 0 },
	["EditBoxBackdropBorderColor"] = { .15, .1, .05, 1 },
	["EditBoxInsets"] = { 6, 6, 0, 0 },
	["PopupBackdrop"] = {
		bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
		edgeFile = GetMedia("better-blizzard-border-small-alternate"),
		tile = false, 
		tileEdge = false, 
		tileSize = nil,
		edgeSize = 32,
		insets = { left = 25, right = 25, top = 25, bottom = 25 } 
	},
	["PopupBackdropOffsets"] = { 25, 25, 25, 25 },
	["PopupBackdropColor"] = { 0, 0, 0, .85 },
	["PopupBorderColor"] = { .25, .25, .25, 1 },

	-- This is the thin border around the buttons.
	["ButtonBorder"] = { 
		edgeFile = GetMedia("rounded-border-small"), 
		edgeSize = 24,
	},
	["ButtonBorderOffsets"] = { 20, 20, 20, 20 },
	["ButtonBorderColor"] = { .15, .15, .15, 1 },
	["ButtonBorderColorHover"] = { .25, .25, .25, 1 },

	-- This is a rounded backdrop fitting inside the button, 
	-- where both this backdrop and its border are part of the button's background only.
	["ButtonBackdrop"] = { 
		bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
		edgeFile = GetMedia("rounded-backdrop-small"), 
		edgeSize = 24,
		insets = { left = 24, right = 24, top = 24, bottom = 24 }
	},
	["ButtonBackdropOffsets"] = { 20, 20, 20, 20 },
	["ButtonBackdropColor"] = { .15, .15, .15, .1 },
	["ButtonBackdropColorHover"] = { .35, .35, .35, .1 },

	["PopupVerticalOffset"] = 32
})

-- Blizzard Tooltips
RegisterLayout("BlizzardTooltips", "Azerite", {
	["TooltipBackdrop"] = {
		["bgFile"] = [[Interface\Tooltips\UI-Tooltip-Background]], tile = false,
		["edgeFile"] = GetMedia("better-blizzard-border-small-alternate"), edgeSize = 32, 
		["insets"] = { left = 25, right = 25, top = 25, bottom = 25 }
	},
	["TooltipBackdropBorderColor"] = { 1, 1, 1, 1 },
	["TooltipBackdropColor"] = { .05, .05, .05, .85 },
	["TooltipStatusBarTexture"] = GetMedia("statusbar-dark")
})

-- Blizzard World Map
RegisterLayout("BlizzardWorldMap", "Azerite", {})
RegisterLayoutVariation("BlizzardWorldMap", "Legacy", "Azerite", {})

-- ActionBars
RegisterLayout("ActionBarMain", "Azerite", {
	["ExitButtonPlace"] = { "CENTER", "Minimap", "CENTER", -math_cos(45*deg2rad) * (213/2 + 10), math_sin(45*deg2rad) * (213/2 + 10) }, 
	["ExitButtonSize"] = { 32, 32 },
	["ExitButtonTexturePath"] = GetMedia("icon_exit_flight"),
	["ExitButtonTexturePlace"] = { "CENTER", 0, 0 }, 
	["ExitButtonTextureSize"] = { 80, 80 }
})

-- Bind Mode
RegisterLayout("Bindings", "Azerite", {
	["BindButtonOffset"] = 8, 
	["BindButtonTexture"] = GetMedia("actionbutton-mask-circular"),
	["MenuButtonNormalTexture"] = GetMedia("menu_button_disabled"),
	["MenuButtonPushedTexture"] = GetMedia("menu_button_pushed"),
	["MenuButtonSize"] = { 256, 64 },
	["MenuButtonTextColor"] = { 0, 0, 0 },
	["MenuButtonTextShadowColor"] = { 1, 1, 1, .5 },
	["MenuButtonTextShadowOffset"] = { 0, -.85 },
	["MenuWindowGetBorder"] = function(self) return GetBorder(self) end
})

-- Chat Filters
RegisterLayout("ChatFilters", "Azerite", {
	["GoldCoinTexture"] = "|T"..GetMedia("coins")..":16:16:-2:0:64:64:0:32:0:32|t",
	["SilverCoinTexture"] = "|T"..GetMedia("coins")..":16:16:-2:0:64:64:32:64:0:32|t",
	["CopperCoinTexture"] = "|T"..GetMedia("coins")..":16:16:-2:0:64:64:0:32:32:64|t" 

})

-- Floaters. Durability only currently. 
RegisterLayout("Durability", "Azerite", {
	["Place"] = { "CENTER", "UICenter", "BOTTOMRIGHT", -360, 190 }
})

-- Group Leader Tools
RegisterLayout("GroupTools", "Azerite", (IsClassic or IsTBC) and {
	["ConvertButtonPlace"] = { "TOP", 0, -360 + 140 }, 
	["ConvertButtonSize"] = { 300*.75, 50*.75 },
	["ConvertButtonTextColor"] = { 0, 0, 0 }, 
	["ConvertButtonTextFont"] = GetFont(14, false), 
	["ConvertButtonTextShadowColor"] = { 1, 1, 1, .5 }, 
	["ConvertButtonTextShadowOffset"] = { 0, -.85 }, 
	["ConvertButtonTextureNormal"] = GetMedia("menu_button_disabled"), 
	["ConvertButtonTextureSize"] = { 1024 *1/3 *.75, 256 *1/3 *.75 },
	["MemberCountNumberColor"] = { Colors.title[1], Colors.title[2], Colors.title[3] },
	["MemberCountNumberFont"] = GetFont(14, true),
	["MemberCountNumberJustifyH"] = "CENTER",
	["MemberCountNumberJustifyV"] = "MIDDLE", 
	["MemberCountNumberPlace"] = { "TOP", 0, -20 }, 
	["MenuAlternatePlace"] = { "BOTTOMLEFT", "UICenter", "BOTTOMLEFT", 22, 350 },
	["MenuPlace"] = { "TOPLEFT", "UICenter", "TOPLEFT", 22, -42 },
	["MenuSize"] = { 300*.75 +30, 410 - 140 }, 
	["MenuToggleButtonSize"] = { 48, 48 }, 
	["MenuToggleButtonPlace"] = { "TOPLEFT", "UICenter", "TOPLEFT", -18, -40 }, 
	["MenuToggleButtonAlternatePlace"] = { "BOTTOMLEFT", "UICenter", "BOTTOMLEFT", -18, 348 }, 
	["MenuToggleButtonIcon"] = GetMedia("raidtoolsbutton"), 
	["MenuToggleButtonIconPlace"] = { "CENTER", 0, 0 }, 
	["MenuToggleButtonIconSize"] = { 64*.75, 128*.75 }, 
	["MenuToggleButtonIconColor"] = { 1, 1, 1 }, 
	["MenuWindow_CreateBorder"] = function(self) return GetBorder(self, GetMedia("tooltip_border"), 23, nil, nil, 23, 23) end,
	["RaidRoleRaidTargetTexture"] = GetMedia("raid_target_icons"),
	["RaidTargetIcon1Place"] = { "TOP", -80, -140 + 86 },
	["RaidTargetIcon2Place"] = { "TOP", -28, -140 + 86 },
	["RaidTargetIcon3Place"] = { "TOP",  28, -140 + 86 },
	["RaidTargetIcon4Place"] = { "TOP",  80, -140 + 86 },
	["RaidTargetIcon5Place"] = { "TOP", -80, -190 + 86 },
	["RaidTargetIcon6Place"] = { "TOP", -28, -190 + 86 },
	["RaidTargetIcon7Place"] = { "TOP",  28, -190 + 86 },
	["RaidTargetIcon8Place"] = { "TOP",  80, -190 + 86 },
	["RaidTargetIconsSize"] = { 48, 48 }, 
	["ReadyCheckButtonPlace"] = { "TOP", -30, -310 + 140 }, 
	["ReadyCheckButtonSize"] = { 300*.75 - 80, 50*.75 },
	["ReadyCheckButtonTextColor"] = { 0, 0, 0 }, 
	["ReadyCheckButtonTextFont"] = GetFont(14, false), 
	["ReadyCheckButtonTextShadowColor"] = { 1, 1, 1, .5 }, 
	["ReadyCheckButtonTextShadowOffset"] = { 0, -.85 }, 
	["ReadyCheckButtonTextureNormal"] = GetMedia("menu_button_smaller"), 
	["ReadyCheckButtonTextureSize"] = { 1024 *1/3 *.75, 256 *1/3 *.75 },


} or IsRetail and {
	["ConvertButtonPlace"] = { "TOP", 0, -360 }, 
	["ConvertButtonSize"] = { 300*.75, 50*.75 },
	["ConvertButtonTextColor"] = { 0, 0, 0 }, 
	["ConvertButtonTextFont"] = GetFont(14, false), 
	["ConvertButtonTextShadowColor"] = { 1, 1, 1, .5 }, 
	["ConvertButtonTextShadowOffset"] = { 0, -.85 }, 
	["ConvertButtonTextureNormal"] = GetMedia("menu_button_disabled"), 
	["ConvertButtonTextureSize"] = { 1024 *1/3 *.75, 256 *1/3 *.75 },
	["MemberCountNumberColor"] = { Colors.title[1], Colors.title[2], Colors.title[3] },
	["MemberCountNumberFont"] = GetFont(14, true),
	["MemberCountNumberJustifyH"] = "CENTER",
	["MemberCountNumberJustifyV"] = "MIDDLE", 
	["MemberCountNumberPlace"] = { "TOP", 0, -20 }, 
	["MenuAlternatePlace"] = { "BOTTOMLEFT", "UICenter", "BOTTOMLEFT", 22, 350 },
	["MenuPlace"] = { "TOPLEFT", "UICenter", "TOPLEFT", 22, -42 },
	["MenuSize"] = { 300*.75 +30, 410 }, 
	["MenuToggleButtonSize"] = { 48, 48 }, 
	["MenuToggleButtonPlace"] = { "TOPLEFT", "UICenter", "TOPLEFT", -18, -40 }, 
	["MenuToggleButtonAlternatePlace"] = { "BOTTOMLEFT", "UICenter", "BOTTOMLEFT", -18, 348 }, 
	["MenuToggleButtonIcon"] = GetMedia("raidtoolsbutton"), 
	["MenuToggleButtonIconPlace"] = { "CENTER", 0, 0 }, 
	["MenuToggleButtonIconSize"] = { 64*.75, 128*.75 }, 
	["MenuToggleButtonIconColor"] = { 1, 1, 1 }, 
	["MenuWindow_CreateBorder"] = function(self) return GetBorder(self, GetMedia("tooltip_border"), 23, nil, nil, 23, 23) end,
	["RaidRoleRaidTargetTexture"] = GetMedia("raid_target_icons"),
	["RaidTargetIcon1Place"] = { "TOP", -80, -140 },
	["RaidTargetIcon2Place"] = { "TOP", -28, -140 },
	["RaidTargetIcon3Place"] = { "TOP",  28, -140 },
	["RaidTargetIcon4Place"] = { "TOP",  80, -140 },
	["RaidTargetIcon5Place"] = { "TOP", -80, -190 },
	["RaidTargetIcon6Place"] = { "TOP", -28, -190 },
	["RaidTargetIcon7Place"] = { "TOP",  28, -190 },
	["RaidTargetIcon8Place"] = { "TOP",  80, -190 },
	["RaidTargetIconsSize"] = { 48, 48 }, 
	["ReadyCheckButtonPlace"] = { "TOP", -30, -310 }, 
	["ReadyCheckButtonSize"] = { 300*.75 - 80, 50*.75 },
	["ReadyCheckButtonTextColor"] = { 0, 0, 0 }, 
	["ReadyCheckButtonTextFont"] = GetFont(14, false), 
	["ReadyCheckButtonTextShadowColor"] = { 1, 1, 1, .5 }, 
	["ReadyCheckButtonTextShadowOffset"] = { 0, -.85 }, 
	["ReadyCheckButtonTextureNormal"] = GetMedia("menu_button_smaller"), 
	["ReadyCheckButtonTextureSize"] = { 1024 *1/3 *.75, 256 *1/3 *.75 },


	["RoleCountTankPlace"] = { "TOP", -70, -100 }, 
	["RoleCountTankFont"] = GetFont(14, true),
	["RoleCountTankColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3] },
	["RoleCountTankTexturePlace"] = { "TOP", -70, -44 },
	["RoleCountTankTextureSize"] = { 64, 64 },
	["RoleCountTankTexture"] = GetMedia("grouprole-icons-tank"),
	
	["RoleCountHealerPlace"] = { "TOP", 0, -100 }, 
	["RoleCountHealerFont"] = GetFont(14, true),
	["RoleCountHealerColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3] },
	["RoleCountHealerTexturePlace"] = { "TOP", 0, -44 },
	["RoleCountHealerTextureSize"] = { 64, 64 },
	["RoleCountHealerTexture"] = GetMedia("grouprole-icons-heal"),

	["RoleCountDPSPlace"] = { "TOP", 70, -100 }, 
	["RoleCountDPSFont"] = GetFont(14, true),
	["RoleCountDPSColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3] },
	["RoleCountDPSTexturePlace"] = { "TOP", 70, -44 },
	["RoleCountDPSTextureSize"] = { 64, 64 },
	["RoleCountDPSTexture"] = GetMedia("grouprole-icons-dps"),

	["RolePollButtonPlace"] = { "TOP", 0, -260 }, 
	["RolePollButtonSize"] = { 300*.75, 50*.75 },
	["RolePollButtonTextFont"] = GetFont(14, false), 
	["RolePollButtonTextColor"] = { 0, 0, 0 }, 
	["RolePollButtonTextShadowColor"] = { 1, 1, 1, .5 }, 
	["RolePollButtonTextShadowOffset"] = { 0, -.85 }, 
	["RolePollButtonTextureSize"] = { 1024 *1/3 *.75, 256 *1/3 *.75 },
	["RolePollButtonTextureNormal"] = GetMedia("menu_button_disabled"), 

	["WorldMarkerFlagPlace"] = { "TOP", 88, -310 }, 
	["WorldMarkerFlagSize"] = { 70*.75, 50*.75 },
	["WorldMarkerFlagContentSize"] = { 32, 32 }, 
	["WorldMarkerFlagBackdropSize"] = { 512 *1/3 *.75, 256 *1/3 *.75 },
	["WorldMarkerFlagBackdropTexture"] = GetMedia("menu_button_tiny"), 

})

-- Minimap
RegisterLayout("Minimap", "Azerite", {
	["AP_OverrideValue"] = Minimap_AP_OverrideValue,
	["BattleGroundEyeColor"] = { .90, .95, 1 }, 
	["BattleGroundEyePlace"] = { "CENTER", math_cos(45*deg2rad) * (213/2 + 10), math_sin(45*deg2rad) * (213/2 + 10) }, 
	["BattleGroundEyeSize"] = { 64, 64 }, 
	["BattleGroundEyeTexture"] = GetMedia("group-finder-eye-green"),
	["BlipTextures"] = 
		(IsClassic or IsTBC) and 
			setmetatable({
			}, { __index = function(t,k) return GetMedia("Blip-Nandini-New-113_2") end }) or
		(IsRetail) and 
			setmetatable({
				["8.3.0"] = GetMedia("Blip-Nandini-Extended-830"),
				["8.3.7"] = GetMedia("Blip-Nandini-Extended-830"), 
				["9.0.1"] = GetMedia("Blip-Nandini-Extended-901"),
				["9.0.2"] = GetMedia("Blip-Nandini-Extended-902"),
				["9.0.5"] = GetMedia("Blip-Nandini-Extended-905")
			}, { __index = function(t,k) return [[Interface\Minimap\ObjectIconsAtlas.blp]] end }),
	["BlobAlpha"] = { 0, 96, 0, 0 }, -- blobInside, blobOutside, ringOutside, ringInside
	["Clock_OverrideValue"] = Minimap_Clock_OverrideValue,
	["ClockColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3] },
	["ClockFont"] = GetFont(15, true),
	["ClockPlace"] = { "BOTTOMRIGHT", -(13 + 213), -8 },
	["CompassColor"] = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .75 }, 
	["CompassFont"] = GetFont(12, true), 
	["CompassRadiusInset"] = 10, -- move the text 10 points closer to the center of the map
	["CompassTexts"] = { L["N"] }, -- only setting the North tag text, as we don't want a full compass ( order is NESW )
	["CoordinateColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 }, 
	["CoordinateFont"] = GetFont(12, true), 
	["CoordinatePlace"] = { "BOTTOM", 3, 23 },
	["Coordinates_OverrideValue"] = Minimap_Coordinates_OverrideValue,
	["FrameRate_OverrideValue"] = Minimap_FrameRate_OverrideValue,
	["FrameRateColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .5 },
	["FrameRateFont"] = GetFont(12, true), 
	["FrameRatePlaceFunc"] = function(Handler) return "BOTTOM", Handler.Clock, "TOP", 0, 6 end, 
	["GroupFinderEyeColor"] = { .90, .95, 1 }, 
	["GroupFinderEyePlace"] = { "CENTER", math_cos(45*deg2rad) * (213/2 + 10), math_sin(45*deg2rad) * (213/2 + 10) }, 
	["GroupFinderEyeSize"] = { 64, 64 }, 
	["GroupFinderEyeTexture"] = GetMedia("group-finder-eye-green"),
	["GroupFinderQueueStatusPlace"] = { "BOTTOMRIGHT", _G.QueueStatusMinimapButton, "TOPLEFT", 0, 0 },
	["InnerRingBackdropMultiplier"] = 1, 
	["InnerRingBarTexture"] = GetMedia("minimap-bars-two-inner"),
	["InnerRingClockwise"] = true, 
	["InnerRingColorPower"] = true,
	["InnerRingColorStanding"] = true,
	["InnerRingColorValue"] = true,
	["InnerRingColorXP"] = true,
	["InnerRingDegreeOffset"] = 90*3 - 21,
	["InnerRingDegreeSpan"] = 360 - 21*2, 
	["InnerRingPlace"] = { "CENTER", 0, 2 }, 
	["InnerRingShowSpark"] = true, 
	["InnerRingSize"] = { 208, 208 }, 
	["InnerRingSparkBlendMode"] = "ADD",
	["InnerRingSparkFlash"] = { nil, nil, 1, 1 }, 
	["InnerRingSparkInset"] = 46 * 208/256,  
	["InnerRingSparkMultiplier"] = 1, 
	["InnerRingSparkOffset"] = -1/10,
	["InnerRingSparkSize"] = { 6, 27 * 208/256 },
	["InnerRingValueFont"] = GetFont(15, true),
	["InnerRingValuePercentFont"] = GetFont(15, true), 
	["Latency_OverrideValue"] = Minimap_Latency_OverrideValue,
	["LatencyColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .5 },
	["LatencyFont"] = GetFont(12, true), 
	["LatencyPlaceFunc"] = function(Handler) return "BOTTOMRIGHT", Handler.Zone, "TOPRIGHT", 0, 6 end, 
	["MailPlace"] = Wheel("LibModule"):IsAddOnEnabled("MBB") and { "BOTTOMRIGHT", -(31 + 213 + 40), 35 } or { "BOTTOMRIGHT", -(31 + 213), 35 },
	["MailSize"] = { 43, 32 },
	["MailTexture"] = GetMedia("icon_mail"),
	["MailTextureDrawLayer"] = { "ARTWORK", 1 },
	["MailTexturePlace"] = { "CENTER", 0, 0 }, 
	["MailTextureRotation"] = 15*deg2rad,
	["MailTextureSize"] = { 66, 66 },
	["MapBackdropColor"] = { 0, 0, 0, .75 }, 
	["MapBackdropTexture"] = GetMedia("minimap_mask_circle"),
	["MapBorderColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["MapBorderPlace"] = { "CENTER", 0, 0 }, 
	["MapBorderSize"] = { 419, 419 }, 
	["MapBorderTexture"] = GetMedia("minimap-border"),
	["MapOverlayColor"] = { 0, 0, 0, .15 },
	["MapOverlayTexture"] = GetMedia("minimap_mask_circle"),
	["MaskTexture"] = GetMedia("minimap_mask_circle_transparent"),
	["MBBPlace"] = { "BOTTOMRIGHT", -(31 + 213), 35 },
	["MBBSize"] = { 32, 32 },
	["MBBTexture"] = GetMedia("plus"),
	["OuterRingBackdropMultiplier"] = 1, 
	["OuterRingClockwise"] = true, 
	["OuterRingColorPower"] = true,
	["OuterRingColorStanding"] = true,
	["OuterRingColorValue"] = true,
	["OuterRingColorXP"] = true,
	["OuterRingDegreeOffset"] = 90*3 - 14,
	["OuterRingDegreeSpan"] = 360 - 14*2, 
	["OuterRingPlace"] = { "CENTER", 0, 2 }, 
	["OuterRingSize"] = { 208, 208 }, 
	["OuterRingShowSpark"] = true, 
	["OuterRingSparkBlendMode"] = "ADD",
	["OuterRingSparkFlash"] = { nil, nil, 1, 1 }, 
	["OuterRingSparkOffset"] = -1/10, 
	["OuterRingSparkMultiplier"] = 1, 
	["OuterRingValueFont"] = GetFont(15, true),
	["OuterRingValuePlace"] = { "CENTER", 0, -9 },
	["OuterRingValueJustifyH"] = "CENTER",
	["OuterRingValueJustifyV"] = "MIDDLE",
	["OuterRingValueShowDeficit"] = true, 
	["OuterRingValueDescriptionColor"] = { Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3] }, 
	["OuterRingValueDescriptionFont"] = GetFont(12, true),
	["OuterRingValueDescriptionJustifyH"] = "CENTER", 
	["OuterRingValueDescriptionJustifyV"] = "MIDDLE", 
	["OuterRingValueDescriptionPlace"] = { "CENTER", 0, -(15/2 + 2) }, 
	["OuterRingValueDescriptionWidth"] = 100, 
	["OuterRingValuePercentFont"] = GetFont(16, true),
	["PerformanceFramePlaceAdvancedFunc"] = Minimap_Performance_PlaceFunc,
	["Place"] = { "BOTTOMRIGHT", "UICenter", "BOTTOMRIGHT", -58, 59 }, 
	["Rep_OverrideValue"] = Minimap_Rep_OverrideValue,
	["RingFrameBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["RingFrameBackdropDoubleTexture"] = GetMedia("minimap-twobars-backdrop"), 
	["RingFrameBackdropDrawLayer"] = { "BACKGROUND", 1 }, 
	["RingFrameBackdropPlace"] = { "CENTER", 0, 0 },
	["RingFrameBackdropSize"] = { 413, 413 }, 
	["RingFrameBackdropTexture"] = GetMedia("minimap-onebar-backdrop"), 
	["RingFrameOuterRingSparkInset"] = { 15 * 208/256 }, 
	["RingFrameOuterRingSparkSize"] = { 6,20 * 208/256 }, 
	["RingFrameOuterRingTexture"] = GetMedia("minimap-bars-two-outer"), 
	["RingFrameOuterRingValueFunc"] = Minimap_RingFrame_OuterRing_ValueFunc,
	["RingFrameSingleRingSparkInset"] = { 22 * 208/256 }, 
	["RingFrameSingleRingSparkSize"] = { 6,34 * 208/256 }, 
	["RingFrameSingleRingValueFunc"] = Minimap_RingFrame_SingleRing_ValueFunc,
	["RingFrameSingleRingTexture"] = GetMedia("minimap-bars-single"), 
	["Size"] = { 213, 213 }, 
	["ToggleBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["ToggleBackdropTexture"] = GetMedia("point_plate"), 
	["ToggleBackdropSize"] = { 100, 100 },
	["ToggleSize"] = { 56, 56 }, 
	["TrackingButtonBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["TrackingButtonBackdropSize"] = { 100, 100 },
	["TrackingButtonBackdropTexture"] = GetMedia("point_plate"), 
	["TrackingButtonIconBgSize"] = { 32, 32 },
	["TrackingButtonIconBgTexture"] = GetMedia("hp_critter_case_glow"),
	["TrackingButtonIconMask"] = GetMedia("hp_critter_case_glow"), -- actionbutton-mask-circular
	["TrackingButtonIconSize"] = { 28, 28 },
	["TrackingButtonPlace"] = { "CENTER", math_cos(45*deg2rad) * (213/2 + 10), math_sin(45*deg2rad) * (213/2 + 10) }, 
	["TrackingButtonPlaceAlternate"] = { "CENTER", math_cos(22.*deg2rad) * (213/2 + 10), math_sin(22.5*deg2rad) * (213/2 + 10) }, 
	["TrackingButtonSize"] = { 56, 56 }, 
	["XP_OverrideValue"] = Minimap_XP_OverrideValue,
	["ZonePlaceFunc"] = function(Handler) return "BOTTOMRIGHT", Handler.Clock, "BOTTOMLEFT", -8, 0 end,
	["ZoneFont"] = GetFont(15, true),
	["UseBars"] = true, -- copout
})
RegisterLayoutVariation("Minimap", "Legacy", "Azerite", {
	["Size"] = { 210, 210 }, 
	--Place = { "TOPRIGHT", "UICenter", "TOPRIGHT", -50, -56 }, 
	["Place"] = { "TOPRIGHT", "UICenter", "TOPRIGHT", -60, -70 }, 

	-- Border icon positions
	["BattleGroundEyePlace"] = { "CENTER", math_cos(45*deg2rad) * (196/2 + 10), math_sin(45*deg2rad) * (196/2 + 10) }, 
	["GroupFinderEyePlace"] = { "CENTER", math_cos(45*deg2rad) * (196/2 + 10), math_sin(45*deg2rad) * (196/2 + 10) }, 
	["TrackingButtonPlace"] = { "CENTER", math_cos(45*deg2rad) * (196/2 + 10), math_sin(45*deg2rad) * (196/2 + 10) }, 
	["TrackingButtonPlaceAlternate"] = { "CENTER", math_cos(22.5*deg2rad) * (196/2 + 10), math_sin(22.5*deg2rad) * (196/2 + 10) }, 

	-- Element positions
	--MBBPlace = { "TOPRIGHT", 24, 20 },
	["MBBPlace"] = { "BOTTOMLEFT", -24, -20 },
	["ClockPlace"] = { "BOTTOM", 1, 18 },
	["CoordinatePlace"] = { "TOP", 4, -22 },
	["GroupFinderQueueStatusPlace"] = { "TOPRIGHT", _G.QueueStatusMinimapButton, "BOTTOMLEFT", 0, 0 },

	--MailPlace = { "BOTTOMRIGHT", "UICenter", "BOTTOMRIGHT", -64, 12 },
	["MailPlace"] = { "BOTTOMRIGHT", "UICenter", "BOTTOMRIGHT", -24, 12 },

	-- Element position functions
	["ZonePlaceFunc"] = function(Handler) return "TOP", Handler, "BOTTOM", 0, -36 end,
	["PerformanceFramePlaceFunc"] = function(Handler) return "TOP", Handler.Zone, "BOTTOM", 0, -6	end,
	["LatencyPlaceFunc"] = function(Handler) return "TOPLEFT", Handler.PerformanceFrame, "TOPLEFT", 0, 0 end, 
	["FrameRatePlaceFunc"] = function(Handler) return "LEFT", Handler.Latency, "RIGHT", 6, 0 end, 

	["FrameRate_OverrideValue"] = function(element, fps) element:SetFormattedText("%.0f|cff888888%s|r", math_floor(fps), FPS_ABBR) end,
	["Latency_OverrideValue"] = function(element, home, world) element:SetFormattedText("%.0f|cff888888%s|r", math_floor(world), MILLISECONDS_ABBR) end,
	["Performance_PostUpdate"] = function(element)
		local self = element._owner
	
		local latency = self.Latency
		local framerate = self.FrameRate
	
		local fsize = framerate:GetStringWidth()
		local lsize = latency:GetStringWidth()
	
		if (fsize and lsize) then 
			local performanceFrame = latency:GetParent()
			performanceFrame:SetSize(fsize + 6 + lsize, math_ceil(math_max(framerate:GetHeight(), latency:GetHeight())))
		end 
	end,

	["ClockFont"] = GetFont(14, true),
	["LatencyFont"] = GetFont(12, true), 
	["ZoneFont"] = GetFont(14, true),
	["ZoneAlpha"] = .75,

	["ClockColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
	["CoordinateColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
	["FrameRateColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
	["LatencyColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },

	["ClockFrameInOverlay"] = true,
	["CoordFrameInOverlay"] = true, 
	["CompassRadiusInset"] = 2, -- move the text 2 points closer to the center of the map
	["MapBorderSize"] = { 256, 256 }, 
	["MapBorderTexture"] = GetMedia("minimap-border-legacy"),
	["PerformanceFramePlaceAdvancedFunc"] = false,

	["UseBars"] = true,

	["RingFrameBackdropSize"] = { 410, 410 }, 
	["RingFrameOuterRingSparkInset"] = { 15 * 205/256 }, 
	["RingFrameOuterRingSparkSize"] = { 6,20 * 205/256 }, 
	["RingFrameSingleRingSparkInset"] = { 22 * 205/256 }, 
	["RingFrameSingleRingSparkSize"] = { 6,34 * 205/256 }, 

	["InnerRingSize"] = { 205, 205 }, 
	["InnerRingSparkInset"] = 46 * 205/256,  
	["InnerRingSparkSize"] = { 6, 27 * 205/256 },
	["InnerRingValueFont"] = GetFont(14, true),
	["InnerRingValuePercentFont"] = GetFont(14, true), 

	["OuterRingSize"] = { 205, 205 }, 
	["OuterRingValuePlace"] = { "CENTER", 0, -9 },
	["OuterRingValueJustifyH"] = "CENTER",
	["OuterRingValueJustifyV"] = "MIDDLE",
	["OuterRingValueDescriptionFont"] = GetFont(12, true),
	["OuterRingValuePercentFont"] = GetFont(12, true),

	["ToggleBackdropSize"] = { 85, 85 },
	["ToggleSize"] = { 48, 48 }, 

})

-- NamePlates
RegisterLayout("NamePlates", "Azerite", {
	["PostCreateAuraButton"] = NamePlates_Auras_PostCreateButton,
	["PostUpdateAuraButton"] = NamePlates_Auras_PostUpdateButton,
	["AuraAnchor"] = "Health", 
	["AuraBorderBackdrop"] = { edgeFile = GetMedia("aura_border"), edgeSize = 12 },
	["AuraBorderBackdropBorderColor"] = { Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3 },
	["AuraBorderBackdropColor"] = { 0, 0, 0, 0 },
	["AuraBorderFramePlace"] = { "CENTER", 0, 0 }, 
	["AuraBorderFrameSize"] = { 30 + 10, 30 + 10 },
	["AuraCountColor"] = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	["AuraCountFont"] = GetFont(12, true),
	["AuraCountPlace"] = { "BOTTOMRIGHT", 9, -6 },
	["AuraFramePlace"] = { "TOPLEFT", (84 - (30*3 + 4*2))/2, 30*2 + 4 + 10 },
	["AuraFrameSize"] = { 30*3 + 4*2, 30*2 + 4  }, 
	["AuraIconPlace"] = { "CENTER", 0, 0 },
	["AuraIconSize"] = { 30 - 6, 30 - 6 },
	["AuraIconTexCoord"] = { 5/64, 59/64, 5/64, 59/64 }, -- aura icon tex coords
	["AuraOffsetX"] = (84 - (30*3 + 4*2))/2, 
	["AuraOffsetY"] = 10 + 4 - 10,
	["AuraSize"] = 30, AuraPadding = 4,
	["AuraPoint"] = "BOTTOMLEFT", 
	["AuraProperties"] = {
		["growthX"] = "LEFT", 
		["growthY"] = "UP", 
		["spacingH"] = 4, 
		["spacingV"] = 4, 
		["auraSize"] = 30, 
		["maxVisible"] = 6, 
		["filter"] = "PLAYER", 
		["customFilter"] = GetAuraFilter("nameplate"),
		["debuffsFirst"] = true, 
		["disableMouse"] = true, 
		["showSpirals"] = false, 
		["showDurations"] = true, 
		["showLongDurations"] = true,
		["tooltipDefaultPosition"] = false, 
		["tooltipPoint"] = "BOTTOMLEFT",
		["tooltipAnchor"] = nil,
		["tooltipRelPoint"] = "TOPLEFT",
		["tooltipOffsetX"] = -8,
		["tooltipOffsetY"] = -16
	},
	["AuraRelPoint"] = "TOPLEFT",
	["AuraTimeFont"] = GetFont(11, true),
	["AuraTimePlace"] = { "TOPLEFT", -6, 6 },
	["CastBackdropColor"] = { 1, 1, 1, 1 },
	["CastBackdropDrawLayer"] = { "BACKGROUND", 0 },
	["CastBackdropPlace"] = { "CENTER", 0, 0 },
	["CastBackdropSize"] = { 84*256/(256-28), 14*64/(64-28) },
	["CastBackdropTexture"] = GetMedia("nameplate_backdrop"),
	["CastBarSpellQueuePlace"] = { "CENTER", 0, 0 }, 
	["CastBarSpellQueueSize"] = { 84, 14 },
	["CastBarSpellQueueTexture"] = GetMedia("nameplate_bar"), 
	["CastBarSpellQueueCastTexCoord"] = { 14/256,(256-14)/256,14/64,(64-14)/64 },
	["CastBarSpellQueueColor"] = { 1, 1, 1, .5 },
	["CastBarSpellQueueOrientation"] = "LEFT",
	["CastBarSpellQueueSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		}
	},
	["CastColor"] = { Colors.cast[1], Colors.cast[2], Colors.cast[3], 1 },
	["CastNameColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["CastNameDrawLayer"] = { "OVERLAY", 1 }, 
	["CastNameFont"] = GetFont(12, true),
	["CastNameJustifyH"] = "CENTER", 
	["CastNameJustifyV"] = "MIDDLE",
	["CastNamePlace"] = { "TOP", 0, -18 },
	["CastOrientation"] = "LEFT", 
	["CastOrientationPlayer"] = "RIGHT", 
	["CastPlace"] = { "TOP", 0, -20 },
	["CastPlacePlayer"] = { "TOP", 0, -(2 + 18 + 18) },
	["CastShieldColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["CastShieldDrawLayer"] = { "BACKGROUND", -5 },
	["CastShieldPlace"] = { "CENTER", 0, -1 }, 
	["CastShieldSize"] = { 124, 69 },
	["CastShieldTexture"] = GetMedia("cast_back_spiked"),
	["CastSize"] = { 84, 14 }, 
	["CastSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/256, offset = -16/32 }, 
			{ ["keyPercent"] =   4/256, offset = -16/32 }, 
			{ ["keyPercent"] =  19/256, offset =   0/32 }, 
			{ ["keyPercent"] = 236/256, offset =   0/32 }, 
			{ ["keyPercent"] = 256/256, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/256, offset = -16/32 }, 
			{ ["keyPercent"] =   4/256, offset = -16/32 }, 
			{ ["keyPercent"] =  19/256, offset =   0/32 }, 
			{ ["keyPercent"] = 236/256, offset =   0/32 }, 
			{ ["keyPercent"] = 256/256, offset = -16/32 }
		}
	},
	["CastTexture"] = GetMedia("nameplate_bar"),
	["CastTexCoord"] = { 14/256,(256-14)/256,14/64,(64-14)/64 },
	["CastTimeToHoldFailed"] = .5, 
	["HealthBackdropColor"] = { 1, 1, 1, 1 },
	["HealthBackdropDrawLayer"] = { "BACKGROUND", -2 },
	["HealthBackdropPlace"] = { "CENTER", 0, 0 },
	["HealthBackdropSize"] = { 84*256/(256-28), 14*64/(64-28) },
	["HealthBackdropTexture"] = GetMedia("nameplate_backdrop"),
	["HealthBarOrientation"] = "LEFT", 
	["HealthBarOrientationPlayer"] = "RIGHT", 
	["HealthColorCivilian"] = true, 
	["HealthColorClass"] = true, 
	["HealthColorDisconnected"] = true,
	["HealthColorHealth"] = true,
	["HealthColorPlayer"] = true, 
	["HealthColorReaction"] = true,
	["HealthColorTapped"] = true,
	["HealthColorThreat"] = true,
	["HealthFrequent"] = true,
	["HealthPlace"] = { "TOP", 0, -2 },
	["HealthSize"] = { 84, 14 }, 
	["HealthSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/256, offset = -16/32 }, 
			{ ["keyPercent"] =   4/256, offset = -16/32 }, 
			{ ["keyPercent"] =  19/256, offset =   0/32 }, 
			{ ["keyPercent"] = 236/256, offset =   0/32 }, 
			{ ["keyPercent"] = 256/256, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/256, offset = -16/32 }, 
			{ ["keyPercent"] =   4/256, offset = -16/32 }, 
			{ ["keyPercent"] =  19/256, offset =   0/32 }, 
			{ ["keyPercent"] = 236/256, offset =   0/32 }, 
			{ ["keyPercent"] = 256/256, offset = -16/32 }
		}
	},
	["HealthTexCoord"] = { 14/256,(256-14)/256,14/64,(64-14)/64 },
	["HealthTexture"] = GetMedia("nameplate_bar"),

	["HealthValuePlace"] = { "TOP", 0, -18 },
	["HealthValueDrawLayer"] = { "OVERLAY", 1 },
	["HealthValueFontObject"] = GetFont(12,true),
	["HealthValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["HealthValueJustifyH"] = "CENTER",
	["HealthValueJustifyV"] = "MIDDLE",
	["HealthValueHidePlayer"] = true,
	["HealthValueHideWhileCasting"] = true,
	["HealthValueShowInCombat"] = false,
	["HealthValueShowOnMouseover"] = true,
	["HealthValueShowOnTarget"] = true,
	["HealthValueShowAtMax"] = true,

	["NameColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["NameDrawLayer"] = { "ARTWORK", 1 },
	["NameFont"] = GetFont(12,true),
	["NameJustifyH"] = "CENTER",
	["NameJustifyV"] = "MIDDLE",
	["NamePlace"] = { "TOP", 0, 16 },
	["NameOffsetWhenShown"] = 12 + 4,
	["NameShowLevel"] = nil,
	["NameShowLevelLast"] = nil,
	["NameHidePlayer"] = true,
	["NameShowInCombat"] = true,
	["NameShowOnMouseover"] = true,
	["NameShowOnTarget"] = true,

	["ClassificationPlace"] = { "RIGHT", 18, -1 },
	["ClassificationSize"] = { 40, 40 },
	["ClassificationColor"] = { 1, 1, 1, 1 },
	["ClassificationHideOnFriendly"] = true,
	["ClassificationIndicatorBossTexture"] = GetMedia("icon_badges_boss"),
	["ClassificationIndicatorEliteTexture"] = GetMedia("icon_classification_elite"),
	["ClassificationIndicatorRareTexture"] = GetMedia("icon_classification_rare"),

	["PreUpdate"] = IsRetail and NamePlates_PreUpdate,
	["PostUpdate"] = NamePlates_PostUpdate,
	["PostUpdateAura"] = NamePlates_PostUpdate_ElementProxy,
	["PostUpdateCast"] = NamePlates_CastBar_PostUpdate,
	["PostUpdateRaidTarget"] = NamePlates_PostUpdate_ElementProxy,

	["PowerBackdropColor"] = { 1, 1, 1, 1 },
	["PowerBackdropDrawLayer"] = { "BACKGROUND", -2 },
	["PowerBackdropPlace"] = { "CENTER", 0, 0 },
	["PowerBackdropSize"] = { 84*256/(256-28), 14*64/(64-28) },
	["PowerBackdropTexture"] = GetMedia("nameplate_backdrop"),
	["PowerBarOrientation"] = "RIGHT", 
	["PowerFrequent"] = true,
	["PowerPlace"] = { "TOP", 0, -20 },
	["PowerSize"] = { 84, 14 }, 
	["PowerSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/256, offset = -16/32 }, 
			{ ["keyPercent"] =   4/256, offset = -16/32 }, 
			{ ["keyPercent"] =  19/256, offset =   0/32 }, 
			{ ["keyPercent"] = 236/256, offset =   0/32 }, 
			{ ["keyPercent"] = 256/256, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/256, offset = -16/32 }, 
			{ ["keyPercent"] =   4/256, offset = -16/32 }, 
			{ ["keyPercent"] =  19/256, offset =   0/32 }, 
			{ ["keyPercent"] = 236/256, offset =   0/32 }, 
			{ ["keyPercent"] = 256/256, offset = -16/32 }
		}
	},
	["PowerTexCoord"] = { 14/256,(256-14)/256,14/64,(64-14)/64 },
	["PowerTexture"] = GetMedia("nameplate_bar"),

	["RaidTargetDrawLayer"] = { "ARTWORK", 0 },
	["RaidTargetPoint"] = "BOTTOM",
	["RaidTargetRelPoint"] = "TOP",
	["RaidTargetOffsetX"] = 0,
	["RaidTargetOffsetY"] = 6,
	--RaidTargetPlace = { "TOP", 0, 20+ 44 -6 }, -- no auras
	--RaidTargetPlace_AuraRow = { "TOP", 0, 20+ 80 -6 }, -- auras, 1 row
	--RaidTargetPlace_AuraRows = { "TOP", 0, 20+ 112 -6 }, -- auras, 2 rows
	["RaidTargetSize"] = { 64, 64 },
	["RaidTargetTexture"] = GetMedia("raid_target_icons"),
	["SetConsoleVars"] = {
		-- Because we want friendly NPC nameplates
		-- We're toning them down a lot as it is, 
		-- but we still prefer to have them visible, 
		-- and not the fugly super sized names we get otherwise.
		--nameplateShowFriendlyNPCs = 1, -- Don't enforce this

		-- Insets at the top and bottom of the screen 
		-- which the target nameplate will be kept away from. 
		-- Used to avoid the target plate being overlapped 
		-- by the target frame or actionbars and keep it in view.
		["nameplateLargeTopInset"] = .125, -- default .1
		["nameplateOtherTopInset"] = .125, -- default .08
		["nameplateLargeBottomInset"] = .02, -- default .15
		["nameplateOtherBottomInset"] = .02, -- default .1
		["nameplateClassResourceTopInset"] = 0,
		["clampTargetNameplateToScreen"] = 1, -- new CVar July 14th 2020. Wohoo! Thanks torhaala for telling me! :)
	
		-- Nameplate scale
		["nameplateMinScale"] = .85, -- .8
		["nameplateMaxScale"] = 1, 
		["nameplateLargerScale"] = 1, -- Scale modifier for large plates, used for important monsters
		["nameplateGlobalScale"] = 1,
		["NamePlateHorizontalScale"] = 1,
		["NamePlateVerticalScale"] = 1,
	
		-- The minimum distance from the camera plates will reach their minimum scale and alpha
		["nameplateMinScaleDistance"] = 20, -- 10
		
		-- The maximum distance from the camera where plates will still have max scale and alpha
		["nameplateMaxScaleDistance"] = 20, -- 10
	
		-- Show nameplates above heads or at the base (0 or 2,
		["nameplateOtherAtBase"] = 0,
	
		-- Scale and Alpha of the selected nameplate (current target,
		["nameplateSelectedScale"] = 1.2, -- default 1.2
	
		-- The max distance to show nameplates.
		["nameplateMaxDistance"] = false, -- 20 is classic upper limit, 60 is BfA default
	
		-- The max distance to show the target nameplate when the target is behind the camera.
		["nameplateTargetBehindMaxDistance"] = 15 -- default 15
	},
	["Size"] = { 80, 32 },

	["UseTargetHighlight"] = true,
	["TargetHighlightDrawLayer"] = { "OVERLAY", 0 },
	["TargetHighlightParent"] = "Health", 
	["TargetHighlightPlace"] = { "CENTER", 0, 0 },
	--TargetHighlightSize = { 84, 14 },
	["TargetHighlightSize"] = { 84 * 256/(256-(14*2)) *1.05, 1.2* 64/(64-(14*2)) * 14 }, -- math. sux.
	["TargetHighlightShowFocus"] = true, TargetHighlightFocusColor = { 144/255, 195/255, 255/255, 1 }, 
	["TargetHighlightShowTarget"] = true, TargetHighlightTargetColor = { 255/255, 239/255, 169/255, 1 }, 
	["TargetHighlightTexture"] = GetMedia("nameplate_outline"),

	["ThreatColor"] = { 1, 1, 1, 1 },
	["ThreatDrawLayer"] = { "BACKGROUND", -3 },
	["ThreatHideSolo"] = false, 
	["ThreatPlace"] = { "CENTER", 0, 0 },
	["ThreatSize"] = { 84*256/(256-28), 14*64/(64-28) },
	["ThreatTexture"] = GetMedia("nameplate_glow"),

})

-- Custom Tooltips
RegisterLayout("Tooltips", "Azerite", {
	["TooltipBackdrop"] = {
		["bgFile"] = [[Interface\Tooltips\UI-Tooltip-Background]], tile = false,
		["edgeFile"] = GetMedia("better-blizzard-border-small-alternate"), edgeSize = 32, 
		["insets"] = { left = 25, right = 25, top = 25, bottom = 25 }
	},
	["TooltipBackdropOffsets"] = { 25, 25, 25, 25 },
	["TooltipBackdropBorderColor"] = { .35, .35, .35, 1 },
	["TooltipBackdropColor"] = { 0, 0, 0, .95 },
	["TooltipFontHeader"] = GetFont(15, true),
	["TooltipFontNormal"] = GetFont(13, true),
	["TooltipFontBar"] = GetFont(13, true),
	["TooltipPlace"] = { "BOTTOMRIGHT", "UICenter", "BOTTOMRIGHT", -319, 166 }, 
	["TooltipSettingColorHealthClass"] = true, -- color health bars by player class
	["TooltipSettingColorHealthReaction"] = true, -- color health bars by NPC standing 
	["TooltipSettingColorHealthPetRarity"] = true, -- color health by combat pet rarity
	["TooltipSettingColorHealthTapped"] = true, -- color health bars if unit is tap denied
	["TooltipSettingColorPower"] = true, -- color power bars by power type
	["TooltipSettingColorPowerTapped"] = true, -- color power bars if unit is tap denied
	["TooltipSettingColorUnitClass"] = true, -- color the unit class on the info line
	["TooltipSettingColorUnitNameClass"] = true, -- color unit names by player class
	["TooltipSettingColorUnitNameReaction"] = true, -- color unit names by NPC standing
	["TooltipSettingColorUnitPetRarity"] = true, -- color unit names by combat pet rarity
	["TooltipSettingShowHealthBar"] = true, -- unit health bars.
	["TooltipSettingShowLevelWithName"] = true, -- integrates unit levels into the unit name
	["TooltipSettingShowPowerBar"] = false, -- unit powerbars. 
	["TooltipStatusBarTexture"] = GetMedia("statusbar-normal")
})

------------------------------------------------
-- Unit Frame Layouts
------------------------------------------------
-- Player
RegisterLayout("UnitFramePlayer", "Azerite", { 
	["Aura_PostCreateButton"] = UnitFrame_Aura_PostCreateButton,
	["Aura_PostUpdateButton"] = UnitFrame_Aura_PostUpdateButton,
	["AuraBorderBackdrop"] = { edgeFile = GetMedia("aura_border"), edgeSize = 16 },
	["AuraBorderBackdropColor"] = { 0, 0, 0, 0 },
	["AuraBorderBackdropBorderColor"] = { Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3 },
	["AuraBorderFramePlace"] = { "CENTER", 0, 0 }, 
	["AuraBorderFrameSize"] = { 40 + 14, 40 + 14 },
	["AuraCountColor"] = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	["AuraCountFont"] = GetFont(14, true),
	["AuraCountPlace"] = { "BOTTOMRIGHT", 9, -6 },
	["AuraFramePlace"] = { "BOTTOMLEFT", 27 + 10, 27 + 24 + 40 },
	["AuraFrameSize"] = { 40*8 + 6*7, 40*2 + 6 },
	["AuraIconPlace"] = { "CENTER", 0, 0 },
	["AuraIconSize"] = { 40 - 6, 40 - 6 },
	["AuraIconTexCoord"] = { 5/64, 59/64, 5/64, 59/64 },
	["AuraProperties"] = {
		["auraHeight"] = nil, 
		["auraSize"] = 40, 
		["auraWidth"] = nil, 
		["customSort"] = false,
		["debuffsFirst"] = true, 
		["disableMouse"] = false, 
		["customFilter"] = GetAuraFilter("player"),
		["growthX"] = "RIGHT", 
		["growthY"] = "UP", 
		["maxBuffs"] = nil, 
		["maxDebuffs"] = nil, 
		["maxVisible"] = 16, 
		["showDurations"] = true, 
		["showSpirals"] = false, 
		["showLongDurations"] = true,
		["spacingH"] = 6, 
		["spacingV"] = 6, 
		["tooltipAnchor"] = nil,
		["tooltipDefaultPosition"] = false, 
		["tooltipOffsetX"] = 8,
		["tooltipOffsetY"] = 16,
		["tooltipPoint"] = "BOTTOMLEFT",
		["tooltipRelPoint"] = "TOPLEFT"
	},
	["AuraTimeFont"] = GetFont(14, true),
	["AuraTimePlace"] = { "TOPLEFT", -6, 6 },
	["CastBarColor"] = { 1, 1, 1, .25 }, 
	["CastBarNameColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["CastBarNameDrawLayer"] = { "OVERLAY", 1 }, 
	["CastBarNameFont"] = GetFont(16, true),
	["CastBarNameJustifyH"] = "LEFT", 
	["CastBarNameJustifyV"] = "MIDDLE",
	["CastBarNameParent"] = "Health",
	["CastBarNamePlace"] = { "LEFT", 27, 4 },
	["CastBarNameSize"] = { 250, 40 }, 
	["CastBarOrientation"] = "RIGHT",
	["CastBarPlace"] = { "BOTTOMLEFT", 27, 27 },
	["CastBarPostUpdate"] = PlayerFrame_CastBarPostUpdate,
	["CastBarSize"] = { 385, 40 },
	["CastBarSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["CastBarValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["CastBarValueDrawLayer"] = { "OVERLAY", 1 },
	["CastBarValueFont"] = GetFont(18, true),
	["CastBarValueParent"] = "Health",
	["CastBarValuePlace"] = { "RIGHT", -27, 4 },
	["CastBarValueJustifyH"] = "CENTER",
	["CastBarValueJustifyV"] = "MIDDLE",
	["ClassificationColor"] = { 1, 1, 1 },
	["ClassificationIndicatorAllianceTexture"] = GetMedia("icon_badges_alliance"),
	["ClassificationIndicatorHordeTexture"] = GetMedia("icon_badges_horde"),
	ClassificationPlace ={ "BOTTOMLEFT", -(41 + 80/2), (22 - 80/2) },
	["ClassificationSize"] = { 84, 84 },
	["CombatIndicatorColor"] = { Colors.ui[1] *.75, Colors.ui[2] *.75, Colors.ui[3] *.75 }, 
	["CombatIndicatorDrawLayer"] = {"OVERLAY", -2 },
	["CombatIndicatorPlace"] = { "BOTTOMLEFT", -(41 + 80/2), (22 - 80/2) },
	["CombatIndicatorSize"] = { 80,80 },
	["CombatIndicatorTexture"] = GetMedia("icon-combat"),

	["CombatFeedbackFont"] = GetFont(20, true),
	["CombatFeedbackFontSmall"] = GetFont(18, true),
	["CombatFeedbackFontLarge"] = GetFont(24, true),
	["CombatFeedbackJustifyH"] = "CENTER", 
	["CombatFeedbackJustifyV"] = "MIDDLE", 
	["CombatFeedbackPlace"] = { "CENTER", 0, 5 },

	["ExplorerHitRects"] = { 60, 0, -140, 0 },
	["HardenedCastSize"] = { 385, 37 },
	["HardenedCastTexture"] = GetMedia("hp_lowmid_bar"),
	["HardenedHealthBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["HardenedHealthBackdropTexture"] = GetMedia("hp_mid_case"),
	["HardenedHealthSize"] = { 385, 37 },
	["HardenedHealthSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["HardenedHealthTexture"] = GetMedia("hp_lowmid_bar"),
	["HardenedHealthThreatTexture"] = GetMedia("hp_mid_case_glow"),
	["HardenedLevel"] = (IsClassic or IsTBC) and 40 or 30,
	["HardenedManaOrbColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["HardenedManaOrbTexture"] = GetMedia("orb_case_hi"),
	["HardenedPowerForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["HardenedPowerForegroundTexture"] = GetMedia("pw_crystal_case"),
	["HealthAbsorbValuePlaceFunction"] = function(self) return "LEFT", self.Health.Value, "RIGHT", 13, 0 end, 
	["HealthAbsorbValueDrawLayer"] = { "OVERLAY", 1 }, 
	["HealthAbsorbValueFont"] = GetFont(18, true),
	["HealthAbsorbValueJustifyH"] = "CENTER", 
	["HealthAbsorbValueJustifyV"] = "MIDDLE",
	["HealthAbsorbValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["HealthBackdropDrawLayer"] = { "BACKGROUND", -1 },
	["HealthBackdropPlace"] = { "CENTER", 1, -.5 },
	["HealthBackdropSize"] = { 716, 188 },
	["HealthBarOrientation"] = "RIGHT", 
	["HealthBarSetFlippedHorizontally"] = false, 
	["HealthBarSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["HealthColorClass"] = false, -- color players by class 
	["HealthColorDisconnected"] = false, -- color disconnected units
	["HealthColorHealth"] = true, -- color anything else in the default health color
	["HealthColorReaction"] = false, -- color NPCs by their reaction standing with us
	["HealthColorTapped"] = false, -- color tap denied units 
	["HealthFrequentUpdates"] = true, -- listen to frequent health events for more accurate updates
	["HealthPlace"] = { "BOTTOMLEFT", 27, 27 },
	["HealthSmoothingMode"] = "bezier-fast-in-slow-out", 
	["HealthSmoothingFrequency"] = 3,
	["HealthValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["HealthValueDrawLayer"] = { "OVERLAY", 1 },
	["HealthValueFont"] = GetFont(18, true),
	["HealthValueJustifyH"] = "LEFT", 
	["HealthValueJustifyV"] = "MIDDLE", 
	["HealthValuePlace"] = { "LEFT", 27, 4 },
	["HitRectInsets"] = { 0, 0, 0, 6 }, 
	["LoveCombatIndicatorColor"] = { Colors.ui[1] *.75, Colors.ui[2] *.75, Colors.ui[3] *.75 }, 
	["LoveCombatIndicatorDrawLayer"] = {"OVERLAY", -2 },
	["LoveCombatIndicatorPlace"] = { "BOTTOMLEFT", -(41 + 48/2 -4), (22 - 48/2 +4) },
	["LoveCombatIndicatorSize"] = { 48,48 },
	["LoveCombatIndicatorTexture"] = GetMedia("icon-heart-red"),
	["ManaBackgroundColor"] = { 22/255, 26/255, 22/255, .82 },
	["ManaBackgroundDrawLayer"] = { "BACKGROUND", -2 }, 
	["ManaBackgroundPlace"] = { "CENTER", 0, 0 }, 
	["ManaBackgroundSize"] = { 113, 113 }, 
	["ManaBackgroundTexture"] = GetMedia("pw_orb_bar3"),
	["ManaColorSuffix"] = "_ORB", 
	["ManaExclusiveResource"] = "MANA", 
	["ManaForegroundDrawLayer"] = { "BORDER", 1 },
	["ManaForegroundPlace"] = { "CENTER", 0, 0 }, 
	["ManaForegroundSize"] = { 188, 188 }, 
	["ManaOrbTextures"] = { GetMedia("pw_orb_bar4"), GetMedia("pw_orb_bar3"), GetMedia("pw_orb_bar3") },
	["ManaOverridePowerColor"] = PlayerFrame_ExtraPowerOverrideColor,
	["ManaPlace"] = { "BOTTOMLEFT", -97 +5, 22 + 5 }, 
	["ManaShadeColor"] = { 1, 1, 1, 1 }, 
	["ManaShadeDrawLayer"] = { "BORDER", -1 }, 
	["ManaShadePlace"] = { "CENTER", 0, 0 }, 
	["ManaShadeSize"] = { 127, 127 }, 
	["ManaShadeTexture"] = GetMedia("shade_circle"), 
	["ManaSize"] = { 103, 103 },
	["ManaTextColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["ManaTextDrawLayer"] = { "OVERLAY", 1 },
	["ManaTextFont"] = GetFont(14, true),
	["ManaTextJustifyH"] = "CENTER", 
	["ManaTextJustifyV"] = "MIDDLE", 
	["ManaTextOverride"] = function(element, unit, min, max)
		if (not min) or (not max) or (min == 0) or (max == 0) or (min == max) then
			element:SetText("")
		else
			local perc = min/max
			if (perc < .25) then
				element:SetTextColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3], .85)
			else 
				element:SetTextColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5)
			end 
			element:SetFormattedText("%.0f", math_floor(min/max * 100))
		end 
	end,
	["ManaTextParent"] = "Power", 
	["ManaTextPlace"] = { "CENTER", 1, -32 },
	["ManaValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .4 },
	["ManaValueDrawLayer"] = { "OVERLAY", 1 },
	["ManaValueFont"] = GetFont(18, true),
	["ManaValueJustifyH"] = "CENTER", 
	["ManaValueJustifyV"] = "MIDDLE", 
	["ManaValuePlace"] = { "CENTER", 3, 0 },
	["NoviceCastSize"] = { 385, 37 },
	["NoviceCastTexture"] = GetMedia("hp_lowmid_bar"),
	["NoviceHealthBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["NoviceHealthBackdropTexture"] = GetMedia("hp_low_case"),
	["NoviceHealthSize"] = { 385, 37 },
	["NoviceHealthSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["NoviceHealthTexture"] = GetMedia("hp_lowmid_bar"),
	["NoviceHealthThreatTexture"] = GetMedia("hp_low_case_glow"),
	["NoviceManaOrbColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["NoviceManaOrbTexture"] = GetMedia("orb_case_low"),
	["NovicePowerForegroundTexture"] = GetMedia("pw_crystal_case_low"),
	["NovicePowerForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["Place"] = { "BOTTOMLEFT", 167, 100 },
	["PostUpdateTextures"] = PlayerFrame_TexturesPostUpdate,
	["PowerOverrideColor"] = PlayerFrame_PowerOverrideColor, 
	["PowerBackgroundColor"] = { 1, 1, 1, .95 },
	["PowerBackgroundDrawLayer"] = { "BACKGROUND", -2 },
	["PowerBackgroundPlace"] = { "CENTER", 0, 0 },
	["PowerBackgroundSize"] = { 120/(206-50)*255, 140/(219-37)*255 },
	["PowerBackgroundTexture"] = GetMedia("power_crystal_back"),
	["PowerBarOrientation"] = "UP",
	["PowerBarSmoothingFrequency"] = .45,
	["PowerBarSmoothingMode"] = "bezier-fast-in-slow-out",
	["PowerBarSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/256, offset =  -65/256 }, 
			{ ["keyPercent"] =  72/256, offset =    0/256 }, 
			{ ["keyPercent"] = 116/256, offset =  -16/256 }, 
			{ ["keyPercent"] = 128/256, offset =  -28/256 }, 
			{ ["keyPercent"] = 256/256, offset =  -84/256 }, 
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/256, offset =  -47/256 }, 
			{ ["keyPercent"] =  84/256, offset =    0/256 }, 
			{ ["keyPercent"] = 135/256, offset =  -24/256 }, 
			{ ["keyPercent"] = 142/256, offset =  -32/256 }, 
			{ ["keyPercent"] = 225/256, offset =  -79/256 }, 
			{ ["keyPercent"] = 256/256, offset = -168/256 }, 
		}
	},
	["PowerBarTexCoord"] = { 50/255, 206/255, 37/255, 219/255 },
	["PowerBarTexture"] = GetMedia("power_crystal_front"),
	["PowerColorSuffix"] = "_CRYSTAL", 
	["PowerForegroundPlace"] = { "BOTTOM", 7, -51 }, 
	["PowerForegroundSize"] = { 198,98 }, 
	["PowerForegroundTexture"] = GetMedia("pw_crystal_case"), 
	["PowerForegroundDrawLayer"] = { "ARTWORK", 1 },
	["PowerIgnoredResource"] = "MANA",
	["PowerPlace"] = { "BOTTOMLEFT", -101, 38 },
	["PowerSize"] = { 120, 140 },
	["PowerType"] = "StatusBar",
	["PowerValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .4 },
	["PowerValueDrawLayer"] = { "OVERLAY", 1 },
	["PowerValueFont"] = GetFont(18, true),
	["PowerValueJustifyH"] = "CENTER", 
	["PowerValueJustifyV"] = "MIDDLE", 
	["PowerValuePlace"] = { "CENTER", 0, -16 },
	["SeasonedCastSize"] = { 385, 40 },
	["SeasonedCastTexture"] = GetMedia("hp_cap_bar_highlight"),
	["SeasonedHealthBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["SeasonedHealthBackdropTexture"] = GetMedia("hp_cap_case"),
	["SeasonedHealthSize"] = { 385, 40 },
	["SeasonedHealthSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["SeasonedHealthTexture"] = GetMedia("hp_cap_bar"),
	["SeasonedHealthThreatTexture"] = GetMedia("hp_cap_case_glow"),
	["SeasonedManaOrbColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["SeasonedManaOrbTexture"] = GetMedia("orb_case_hi"),
	["SeasonedPowerForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["SeasonedPowerForegroundTexture"] = GetMedia("pw_crystal_case"),
	["Size"] = { 439, 93 },
	["ThreatColorPostUpdate"] = PlayerFrame_Threat_UpdateColor,
	["ThreatFadeOut"] = 3,
	["ThreatHealthAlpha"] = .5,
	["ThreatHealthDrawLayer"] = { "BACKGROUND", -2 },
	["ThreatHealthPlace"] = { "CENTER", 1, 0 },
	["ThreatHealthSize"] = { 716, 188 },
	["ThreadHide"] = PlayerFrame_Threat_Hide,
	["ThreatHideSolo"] = true, -- only set to false when testing
	["ThreatIsShown"] = PlayerFrame_Threat_IsShown,
	["ThreatManaAlpha"] = .5,
	["ThreatManaPlace"] = { "CENTER", 0, 0 },
	["ThreatManaDrawLayer"] = { "BACKGROUND", -2 },
	["ThreatManaSize"] = { 188, 188 },
	["ThreatManaTexture"] = GetMedia("orb_case_glow"),
	["ThreatPowerAlpha"] = .5,
	["ThreatPowerBgAlpha"] = .5,
	["ThreatPowerBgPlace"] = { "BOTTOM", 7, -51 },
	["ThreatPowerBgDrawLayer"] = { "BACKGROUND", -3 },
	["ThreatPowerBgSize"] = { 198,98 },
	["ThreatPowerBgTexture"] = GetMedia("pw_crystal_case_glow"),
	["ThreatPowerDrawLayer"] = { "BACKGROUND", -2 },
	["ThreatPowerPlace"] = { "CENTER", 0, 1 }, 
	["ThreatPowerSize"] = { 120/157*256, 140/183*256 },
	["ThreatPowerTexture"] = GetMedia("power_crystal_glow"),
	["ThreatShow"] = PlayerFrame_Threat_Show,
	["WinterVeilManaColor"] = { 1, 1, 1 },
	["WinterVeilManaDrawLayer"] = { "OVERLAY", 0 },
	["WinterVeilManaPlace"] = { "CENTER", 0, 0 },
	["WinterVeilManaSize"] = { 188, 188 },
	["WinterVeilManaTexture"] = GetMedia("seasonal_winterveil_orb"),
	["WinterVeilPowerColor"] = { 1, 1, 1 }, 
	["WinterVeilPowerDrawLayer"] = { "OVERLAY", 0 },
	["WinterVeilPowerPlace"] = { "CENTER", -2, 24 },
	["WinterVeilPowerTexture"] = GetMedia("seasonal_winterveil_crystal"), 
	["WinterVeilPowerSize"] = { 120 / ((255-50*2)/255), 140 / ((255-37*2)/255) }
})

-- PlayerHUD (combo points and castbar)
RegisterLayout("UnitFramePlayerHUD", "Azerite", {
	["CastBarColor"] = { 70/255, 255/255, 131/255, .69 },
	["CastBarOrientation"] = "RIGHT",
	["CastTimeToHoldFailed"] = .5,
	["CastBarBackgroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["CastBarBackgroundDrawLayer"] = { "BACKGROUND", 1 },
	["CastBarBackgroundPlace"] = { "CENTER", 1, -1 }, 
	["CastBarBackgroundSize"] = { 193,93 },
	["CastBarBackgroundTexture"] = GetMedia("cast_back"), 
	["CastBarValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["CastBarValueDrawLayer"] = { "OVERLAY", 1 },
	["CastBarValueFont"] = GetFont(14, true),
	["CastBarValueJustifyH"] = "CENTER",
	["CastBarValueJustifyV"] = "MIDDLE",
	["CastBarValuePlace"] = { "CENTER", 0, 0 },
	["CastBarNameColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["CastBarNameDrawLayer"] = { "OVERLAY", 1 },
	["CastBarNameFont"] = GetFont(15, true),
	["CastBarNameJustifyH"] = "CENTER",
	["CastBarNameJustifyV"] = "MIDDLE",
	["CastBarNamePlace"] = { "TOP", 0, -(12 + 14) },
	["CastBarPlace"] = { "BOTTOM", "UICenter", "BOTTOM", 0, 290 },
	["CastBarSize"] = { 112, 11 },
	["CastBarShieldColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["CastBarShieldDrawLayer"] = { "BACKGROUND", 1 }, 
	["CastBarShieldPlace"] = { "CENTER", 1, -2 }, 
	["CastBarShieldSize"] = { 193, 93 },
	["CastBarShieldTexture"] = GetMedia("cast_back_spiked"), 
	["CastBarSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		}
	},
	["CastBarSpellQueuePlace"] = { "BOTTOM", "UICenter", "BOTTOM", 0, 290 }, 
	["CastBarSpellQueueSize"] = { 112, 11 },
	["CastBarSpellQueueTexture"] = GetMedia("cast_bar"), 
	["CastBarSpellQueueColor"] = { 1, 1, 1, .5 },
	["CastBarSpellQueueOrientation"] = "LEFT",
	["CastBarSpellQueueSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 }, 
			{ ["keyPercent"] =  10/128, offset =   0/32 }, 
			{ ["keyPercent"] = 119/128, offset =   0/32 }, 
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		}
	},
	["CastBarTexture"] = GetMedia("cast_bar"), 
	["ClassPowerAlphaWhenEmpty"] = .25, -- .5 
	["ClassPowerAlphaWhenOutOfCombat"] = 1,
	["ClassPowerAlphaWhenOutOfCombatRunes"] = .75, -- .5,  
	["ClassPowerAlphaWhenHiddenRunes"] = 0, -- .10, -- this is when runes are full and you're out of combat, etc
	["ClassPowerHideWhenNoTarget"] = true, 
	["ClassPowerHideWhenUnattackable"] = true, 
	["ClassPowerMaxComboPoints"] = 5, 
	["ClassPowerPlace"] = { "CENTER", "UICenter", "CENTER", 0, 0 }, 
	["ClassPowerPostCreatePoint"] = PlayerHUD_ClassPowerPostCreatePoint,
	["ClassPowerPostUpdate"] = PlayerHUD_ClassPowerPostUpdate,
	["ClassPowerReverseSides"] = false,
	["ClassPowerRuneSortOrder"] = "ASC",
	["ClassPowerSize"] = { 2,2 },
	["IgnoreMouseOver"] = true,
	["Place"] = { "BOTTOMLEFT", 75, 127 },
	["PlayerAltPowerBarBackgroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["PlayerAltPowerBarBackgroundDrawLayer"] = { "BACKGROUND", 1 },
	["PlayerAltPowerBarBackgroundPlace"] = { "CENTER", 1, -2 },
	["PlayerAltPowerBarBackgroundSize"] = { 193,93 },
	["PlayerAltPowerBarBackgroundTexture"] = GetMedia("cast_back"),
	["PlayerAltPowerBarColor"] = { Colors.power.ALTERNATE[1], Colors.power.ALTERNATE[2], Colors.power.ALTERNATE[3], .69 },
	["PlayerAltPowerBarNameColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["PlayerAltPowerBarNameDrawLayer"] = { "OVERLAY", 1 },
	["PlayerAltPowerBarNameFont"] = GetFont(15, true),
	["PlayerAltPowerBarNameJustifyH"] = "CENTER",
	["PlayerAltPowerBarNameJustifyV"] = "MIDDLE",
	["PlayerAltPowerBarNamePlace"] = { "TOP", 0, -(12 + 14) },
	["PlayerAltPowerBarOrientation"] = "RIGHT",
	["PlayerAltPowerBarPlace"] = { "BOTTOM", "UICenter", "BOTTOM", 0, 340 },
	["PlayerAltPowerBarSize"] = { 112, 11 },
	["PlayerAltPowerBarSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 },
			{ ["keyPercent"] =  10/128, offset =   0/32 },
			{ ["keyPercent"] = 119/128, offset =   0/32 },
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		},
		["bottom"] = {
			{ ["keyPercent"] =   0/128, offset = -16/32 },
			{ ["keyPercent"] =  10/128, offset =   0/32 },
			{ ["keyPercent"] = 119/128, offset =   0/32 },
			{ ["keyPercent"] = 128/128, offset = -16/32 }
		}
	},
	["PlayerAltPowerBarTexture"] = GetMedia("cast_bar"),
	["PlayerAltPowerBarValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["PlayerAltPowerBarValueDrawLayer"] = { "OVERLAY", 1 },
	["PlayerAltPowerBarValueFont"] = GetFont(14, true),
	["PlayerAltPowerBarValueJustifyH"] = "CENTER",
	["PlayerAltPowerBarValueJustifyV"] = "MIDDLE",
	["PlayerAltPowerBarValuePlace"] = { "CENTER", 0, 0 },
	["Size"] = { 103, 103 }
})

-- Target
RegisterLayout("UnitFrameTarget", "Azerite", { 
	["Aura_PostCreateButton"] = UnitFrame_Aura_PostCreateButton,
	["Aura_PostUpdateButton"] = UnitFrame_Aura_PostUpdateButton,
	["AuraBorderBackdrop"] = { edgeFile = GetMedia("aura_border"), edgeSize = 16 },
	["AuraBorderBackdropColor"] = { 0, 0, 0, 0 },
	["AuraBorderBackdropBorderColor"] = { Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3 }, 
	["AuraBorderFramePlace"] = { "CENTER", 0, 0 }, 
	["AuraBorderFrameSize"] = { 40 + 14, 40 + 14 },
	["AuraCountColor"] = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	["AuraCountFont"] = GetFont(14, true),
	["AuraCountPlace"] = { "BOTTOMRIGHT", 9, -6 },
	["AuraFramePlace"] = { "TOPRIGHT", -(27 + 10), -(27 + 40 + 20) },
	["AuraFrameSize"] = { 40*7 + 6*6, 40*2 + 6 },
	["AuraFrameSizeBoss"] = { 40*10 + 6*9, 40*2 + 6 },
	["AuraIconPlace"] = { "CENTER", 0, 0 },
	["AuraIconSize"] = { 40 - 6, 40 - 6 },
	["AuraIconTexCoord"] = { 5/64, 59/64, 5/64, 59/64 }, 
	["AuraProperties"] = {
		["auraHeight"] = nil, 
		["auraSize"] = 40, 
		["auraWidth"] = nil, 
		["customSort"] = false,
		["debuffsFirst"] = true, 
		["disableMouse"] = false, 
		["customFilter"] = GetAuraFilter("target"),
		["growthX"] = "LEFT", 
		["growthY"] = "DOWN", 
		["maxBuffs"] = nil, 
		["maxDebuffs"] = nil, 
		["maxVisible"] = 14, -- classic max is 16(?)
		["showDurations"] = true, 
		["showLongDurations"] = true,
		["showSpirals"] = false, 
		["spacingH"] = 6, 
		["spacingV"] = 6, 
		["tooltipAnchor"] = nil,
		["tooltipDefaultPosition"] = false, 
		["tooltipOffsetX"] = -8,
		["tooltipOffsetY"] = -16,
		["tooltipPoint"] = "TOPRIGHT",
		["tooltipRelPoint"] = "BOTTOMRIGHT"
	},
	["AuraTimeFont"] = GetFont(14, true),
	["AuraTimePlace"] = { "TOPLEFT", -6, 6 }, 
	["BossCastPlace"] = { "TOPRIGHT", -27, -27 }, 
	["BossCastSize"] = { 533, 40 },
	["BossCastSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =    0/1024, offset = -24/64 }, 
			{ ["keyPercent"] =   13/1024, offset =   0/64 }, 
			{ ["keyPercent"] = 1018/1024, offset =   0/64 }, 
			{ ["keyPercent"] = 1024/1024, offset = -10/64 }
		},
		["bottom"] = {
			{ ["keyPercent"] =    0/1024, offset = -39/64 }, 
			{ ["keyPercent"] =   13/1024, offset = -16/64 }, 
			{ ["keyPercent"] =  949/1024, offset = -16/64 }, 
			{ ["keyPercent"] =  977/1024, offset =  -1/64 }, 
			{ ["keyPercent"] =  984/1024, offset =  -2/64 }, 
			{ ["keyPercent"] = 1024/1024, offset = -52/64 }
		}
	},
	["BossCastTexture"] = GetMedia("hp_boss_bar"),
	["BossHealthBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["BossHealthBackdropPlace"] = { "CENTER", -.5, 1 }, 
	["BossHealthBackdropSize"] = { 694, 190 }, 
	["BossHealthBackdropTexture"] = GetMedia("hp_boss_case"),
	["BossHealthPercentVisible"] = true, 
	["BossHealthPlace"] = { "TOPRIGHT", -27, -27 }, 
	["BossHealthSize"] = { 533, 40 },
	["BossHealthSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =    0/1024, offset = -24/64 }, 
			{ ["keyPercent"] =   13/1024, offset =   0/64 }, 
			{ ["keyPercent"] = 1018/1024, offset =   0/64 }, 
			{ ["keyPercent"] = 1024/1024, offset = -10/64 }
		},
		["bottom"] = {
			{ ["keyPercent"] =    0/1024, offset = -39/64 }, 
			{ ["keyPercent"] =   13/1024, offset = -16/64 }, 
			{ ["keyPercent"] =  949/1024, offset = -16/64 }, 
			{ ["keyPercent"] =  977/1024, offset =  -1/64 }, 
			{ ["keyPercent"] =  984/1024, offset =  -2/64 }, 
			{ ["keyPercent"] = 1024/1024, offset = -52/64 }
		}
	},
	["BossHealthTexture"] = GetMedia("hp_boss_bar"),
	["BossHealthThreatPlace"] = { "CENTER", -.5, 1 },
	["BossHealthThreatSize"] = { 694, 190 },
	["BossHealthThreatTexture"] = GetMedia("hp_boss_case_glow"),
	["BossHealthValueVisible"] = true, 
	["BossPortraitForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["BossPortraitForegroundTexture"] = GetMedia("portrait_frame_hi"),
	["BossPowerForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["BossPowerForegroundTexture"] = GetMedia("pw_crystal_case"),
	["CastBarColor"] = { 1, 1, 1, .25 }, 
	["CastBarNameColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["CastBarNameDrawLayer"] = { "OVERLAY", 1 }, 
	["CastBarNameFont"] = GetFont(16, true),
	["CastBarNameJustifyH"] = "RIGHT", 
	["CastBarNameJustifyV"] = "MIDDLE",
	["CastBarNamePlace"] = { "RIGHT", -27, 4 },
	["CastBarNameSize"] = { 250, 40 }, 
	["CastBarOrientation"] = "LEFT", 
	["CastBarPlace"] = { "BOTTOMLEFT", 27, 27 },
	["CastBarPostUpdate"] = TargetFrame_CastBarPostUpdate,
	["CastBarSetFlippedHorizontally"] = true, 
	["CastBarSmoothingMode"] = "bezier-fast-in-slow-out", 
	["CastBarSmoothingFrequency"] = .15,
	["CastBarSize"] = { 385, 40 },
	["CastBarSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["CastBarValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["CastBarValueDrawLayer"] = { "OVERLAY", 1 },
	["CastBarValueFont"] = GetFont(18, true),
	["CastBarValueJustifyH"] = "CENTER",
	["CastBarValueJustifyV"] = "MIDDLE",
	["CastBarValuePlace"] = { "LEFT", 27, 4 },

	["CombatFeedbackFont"] = GetFont(20, true),
	["CombatFeedbackFontSmall"] = GetFont(18, true),
	["CombatFeedbackFontLarge"] = GetFont(24, true),
	["CombatFeedbackJustifyH"] = "CENTER", 
	["CombatFeedbackJustifyV"] = "MIDDLE", 
	["CombatFeedbackPlace"] = { "CENTER", 0, 3 },

	["ClassificationColor"] = { 1, 1, 1 },
	["ClassificationIndicatorAllianceTexture"] = GetMedia("icon_badges_alliance"),
	["ClassificationIndicatorBossTexture"] = GetMedia("icon_badges_boss"),
	["ClassificationIndicatorEliteTexture"] = GetMedia("icon_classification_elite"),
	["ClassificationIndicatorHordeTexture"] = GetMedia("icon_badges_horde"),
	["ClassificationIndicatorRareTexture"] = GetMedia("icon_classification_rare"),
	["ClassificationPlace"] = { "BOTTOMRIGHT", 72, -43 },
	["ClassificationSize"] = { 84, 84 },
	["CritterCastPlace"] = { "TOPRIGHT", -24, -24 },
	["CritterCastSize"] = { 40, 36 },
	["CritterCastSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =  0/64, offset = -30/64 }, 
			{ ["keyPercent"] = 14/64, offset =  -1/64 }, 
			{ ["keyPercent"] = 49/64, offset =  -1/64 }, 
			{ ["keyPercent"] = 64/64, offset = -34/64 }
		},
		["bottom"] = {
			{ ["keyPercent"] =  0/64, offset = -30/64 }, 
			{ ["keyPercent"] = 15/64, offset =   0/64 }, 
			{ ["keyPercent"] = 32/64, offset =  -1/64 }, 
			{ ["keyPercent"] = 50/64, offset =  -4/64 }, 
			{ ["keyPercent"] = 64/64, offset = -27/64 }
		}
	},
	["CritterCastTexture"] = GetMedia("hp_critter_bar"),
	["CritterHealthBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["CritterHealthBackdropPlace"] = { "CENTER", 0, 1 }, 
	["CritterHealthBackdropSize"] = { 98,96 }, 
	["CritterHealthBackdropTexture"] = GetMedia("hp_critter_case"),
	["CritterHealthPercentVisible"] = false, 
	["CritterHealthPlace"] = { "TOPRIGHT", -24, -24 }, 
	["CritterHealthSize"] = { 40, 36 },
	["CritterHealthSparkMap"] = {
		["top"] = {
			{ ["keyPercent"] =  0/64, offset = -30/64 }, 
			{ ["keyPercent"] = 14/64, offset =  -1/64 }, 
			{ ["keyPercent"] = 49/64, offset =  -1/64 }, 
			{ ["keyPercent"] = 64/64, offset = -34/64 }
		},
		["bottom"] = {
			{ ["keyPercent"] =  0/64, offset = -30/64 }, 
			{ ["keyPercent"] = 15/64, offset =   0/64 }, 
			{ ["keyPercent"] = 32/64, offset =  -1/64 }, 
			{ ["keyPercent"] = 50/64, offset =  -4/64 }, 
			{ ["keyPercent"] = 64/64, offset = -27/64 }
		}
	},
	["CritterHealthTexture"] = GetMedia("hp_critter_bar"),
	["CritterHealthThreatPlace"] = { "CENTER", 0, 0 },
	["CritterHealthThreatSize"] = { 98,96 },
	["CritterHealthThreatTexture"] = GetMedia("hp_critter_case_glow"),
	["CritterHealthValueVisible"] = false, 
	["CritterPortraitForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["CritterPortraitForegroundTexture"] = GetMedia("portrait_frame_lo"),
	["CritterPowerForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["CritterPowerForegroundTexture"] = GetMedia("pw_crystal_case_low"),
	["HardenedCastPlace"] = { "TOPRIGHT", -27, -27 }, 
	["HardenedCastSize"] = { 385, 37 },
	["HardenedCastSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["HardenedCastTexture"] = GetMedia("hp_lowmid_bar"),
	["HardenedHealthBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["HardenedHealthBackdropPlace"] = { "CENTER", -2, -1 }, 
	["HardenedHealthBackdropSize"] = { 716, 188 }, 
	["HardenedHealthBackdropTexture"] = GetMedia("hp_mid_case"),
	["HardenedHealthPercentVisible"] = true, 
	["HardenedHealthPlace"] = { "TOPRIGHT", -27, -27 }, 
	["HardenedHealthSize"] = { 385, 37 },
	["HardenedHealthSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["HardenedHealthTexture"] = GetMedia("hp_lowmid_bar"),
	["HardenedHealthThreatPlace"] = { "CENTER", 0, 1 },
	["HardenedHealthThreatSize"] = { 716, 188 },
	["HardenedHealthThreatTexture"] = GetMedia("hp_mid_case_glow"),
	["HardenedHealthValueVisible"] = true,
	["HardenedLevel"] = (IsClassic or IsTBC) and 40 or 30,
	["HardenedPortraitForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["HardenedPortraitForegroundTexture"] = GetMedia("portrait_frame_hi"),
	["HardenedPowerForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["HardenedPowerForegroundTexture"] = GetMedia("pw_crystal_case"),
	["HealthAbsorbValuePlaceFunction"] = function(self) return "RIGHT", self.Health.Value, "LEFT", -13, 0 end, 
	["HealthAbsorbValueDrawLayer"] = { "OVERLAY", 1 }, 
	["HealthAbsorbValueFont"] = GetFont(18, true),
	["HealthAbsorbValueJustifyH"] = "CENTER", 
	["HealthAbsorbValueJustifyV"] = "MIDDLE",
	["HealthAbsorbValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["HealthBackdropDrawLayer"] = { "BACKGROUND", -1 },
	["HealthBackdropPlace"] = { "CENTER", 1, -.5 },
	["HealthBackdropSize"] = { 716, 188 },
	["HealthBackdropTexCoord"] = { 1, 0, 0, 1 }, 
	["HealthBarOrientation"] = "LEFT",
	["HealthBarSetFlippedHorizontally"] = true, 
	["HealthColorClass"] = true, -- color players by class 
	["HealthColorDisconnected"] = true, -- color disconnected units
	["HealthColorHealth"] = false, -- color anything else in the default health color
	["HealthColorReaction"] = true, -- color NPCs by their reaction standing with us
	["HealthColorTapped"] = true, -- color tap denied units 
	["HealthColorThreat"] = true, -- threat coloring on non-friendly health bars
	["HealthFrequentUpdates"] = true, -- listen to frequent health events for more accurate updates
	["HealthPercentColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["HealthPercentDrawLayer"] = { "OVERLAY", 1 },
	["HealthPercentFont"] = GetFont(18, true),
	["HealthPercentJustifyH"] = "LEFT",
	["HealthPercentJustifyV"] = "MIDDLE",
	["HealthPercentPlace"] = { "LEFT", 27, 4 },
	["HealthPlace"] = { "TOPRIGHT", 27, 27 },
	["HealthSmoothingFrequency"] = .2, -- speed of the smoothing method
	["HealthSmoothingMode"] = "bezier-fast-in-slow-out", 
	["HealthValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["HealthValueFont"] = GetFont(18, true),
	["HealthValueDrawLayer"] = { "OVERLAY", 1 },
	["HealthValueJustifyH"] = "RIGHT", 
	["HealthValueJustifyV"] = "MIDDLE", 
	["HealthValuePlace"] = { "RIGHT", -27, 4 },
	["HitRectInsets"] = { 0, -80, -30, 0 }, 
	["LevelAlpha"] = .7,
	["LevelBadgeColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["LevelBadgeDrawLayer"] = { "BACKGROUND", 1 },
	["LevelBadgeSize"] = { 86, 86 }, 
	["LevelBadgeTexture"] = GetMedia("point_plate"),
	["LevelColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3] },
	["LevelDeadSkullColor"] = { 1, 1, 1, 1 }, 
	["LevelDeadSkullDrawLayer"] = { "BORDER", 2 }, 
	["LevelDeadSkullSize"] = { 64, 64 }, 
	["LevelDeadSkullTexture"] = GetMedia("icon_skull_dead"),
	["LevelDrawLayer"] = { "BORDER", 1 },
	["LevelFont"] = GetFont(13, true),
	["LevelHideCapped"] = true, 
	["LevelHideFloored"] = true, 
	["LevelJustifyH"] = "CENTER",
	["LevelJustifyV"] = "MIDDLE", 
	["LevelPlace"] = { "CENTER", 298, -15 }, 
	["LevelSkullColor"] = { 1, 1, 1, 1 }, 
	["LevelSkullDrawLayer"] = { "BORDER", 2 }, 
	["LevelSkullSize"] = { 64, 64 }, 
	["LevelSkullTexture"] = GetMedia("icon_skull"),
	["LevelVisibilityFilter"] = TargetFrame_LevelVisibilityFilter,
	["LoveTargetIndicatorPetByEnemyColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["LoveTargetIndicatorPetByEnemyPlace"] = { "TOPRIGHT", -10 + 50/2 + 4, 12 + 50/2 -4 },
	["LoveTargetIndicatorPetByEnemySize"] = { 48,48 },
	["LoveTargetIndicatorPetByEnemyTexture"] = GetMedia("icon-heart-blue"),
	["LoveTargetIndicatorYouByEnemyColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["LoveTargetIndicatorYouByEnemyPlace"] = { "TOPRIGHT", -10 + 50/2 + 4, 12 + 50/2 -4 },
	["LoveTargetIndicatorYouByEnemySize"] = { 48,48 },
	["LoveTargetIndicatorYouByEnemyTexture"] = GetMedia("icon-heart-red"),
	["LoveTargetIndicatorYouByFriendColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["LoveTargetIndicatorYouByFriendPlace"] = { "TOPRIGHT", -10 + 50/2 + 4, 12 + 50/2 -4 },
	["LoveTargetIndicatorYouByFriendSize"] = { 48,48 },
	["LoveTargetIndicatorYouByFriendTexture"] = GetMedia("icon-heart-green"),
	["NameColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	["NameDrawLayer"] = { "OVERLAY", 1 }, 
	["NameFont"] = GetFont(18, true),
	["NameJustifyH"] = "RIGHT", 
	["NameJustifyV"] = "TOP",
	["NamePlace"] = { "TOPRIGHT", -40, 18 },
	["NamePostUpdateBecauseOfToT"] = TargetFrame_NamePostUpdate,
	["NameSize"] = { 250, 18 },
	["NoviceCastPlace"] = { "TOPRIGHT", -27, -27 }, 
	["NoviceCastSize"] = { 385, 37 },
	["NoviceCastSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["NoviceCastTexture"] = GetMedia("hp_lowmid_bar"),
	["NoviceHealthBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["NoviceHealthBackdropPlace"] = { "CENTER", -1, -.5 }, 
	["NoviceHealthBackdropSize"] = { 716, 188 }, 
	["NoviceHealthBackdropTexture"] = GetMedia("hp_low_case"),
	["NoviceHealthPercentVisible"] = true, 
	["NoviceHealthPlace"] = { "TOPRIGHT", -27, -27 }, 
	["NoviceHealthSize"] = { 385, 37 },
	["NoviceHealthSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["NoviceHealthTexture"] = GetMedia("hp_lowmid_bar"),
	["NoviceHealthThreatPlace"] = { "CENTER", 0, 1 },
	["NoviceHealthThreatSize"] = { 716, 188 },
	["NoviceHealthThreatTexture"] = GetMedia("hp_low_case_glow"),
	["NoviceHealthValueVisible"] = true,
	["NovicePortraitForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["NovicePortraitForegroundTexture"] = GetMedia("portrait_frame_lo"),
	["NovicePowerForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["NovicePowerForegroundTexture"] = GetMedia("pw_crystal_case_low"),
	["Place"] = { "TOPRIGHT", -153, -79 },
	["PortraitAlpha"] = .85, 
	["PortraitBackgroundColor"] = { .5, .5, .5 }, 
	["PortraitBackgroundDrawLayer"] = { "BACKGROUND", 0 }, 
	["PortraitBackgroundPlace"] = { "TOPRIGHT", 116, 55 },
	["PortraitBackgroundSize"] = { 173, 173 },
	["PortraitBackgroundTexture"] = GetMedia("party_portrait_back"), 
	["PortraitDistanceScale"] = 1,
	["PortraitForegroundDrawLayer"] = { "BACKGROUND", 0 },
	["PortraitForegroundPlace"] = { "TOPRIGHT", 123, 61 },
	["PortraitForegroundSize"] = { 187, 187 },
	["PortraitPlace"] = { "TOPRIGHT", 73, 8 },
	["PortraitPositionX"] = 0,
	["PortraitPositionY"] = 0,
	["PortraitPositionZ"] = 0,
	["PortraitRotation"] = 0, 
	["PortraitShowFallback2D"] = true, 
	["PortraitShadeDrawLayer"] = { "BACKGROUND", -1 },
	["PortraitShadePlace"] = { "TOPRIGHT", 83, 21 },
	["PortraitShadeSize"] = { 107, 107 }, 
	["PortraitShadeTexture"] = GetMedia("shade_circle"),
	["PortraitSize"] = { 85, 85 }, 
	["PostUpdateTextures"] = TargetFrame_TexturesPostUpdate,
	["PowerBackgroundColor"] = { 1, 1, 1, .85 },
	["PowerBackgroundDrawLayer"] = { "BACKGROUND", -2 },
	["PowerBackgroundPlace"] = { "CENTER", 0, 0 },
	["PowerBackgroundSize"] = { 68 +12, 68 +12 },
	["PowerBackgroundTexCoord"] = { 0, 1, 0, 1 },
	["PowerBackgroundTexture"] = GetMedia("power_crystal_small_back"),
	["PowerBarOrientation"] = "UP",
	["PowerBarSetFlippedHorizontally"] = false, 
	["PowerBarSmoothingFrequency"] = .5,
	["PowerBarSmoothingMode"] = "bezier-fast-in-slow-out",
	["PowerBarSparkTexture"] = GetMedia("blank"),
	["PowerBarTexCoord"] = { 0, 1, 0, 1 },
	["PowerBarTexture"] = GetMedia("power_crystal_small_front"),
	["PowerColorSuffix"] = "_CRYSTAL", 
	["PowerHideWhenDead"] = true,  
	["PowerHideWhenEmpty"] = true,
	["PowerIgnoredResource"] = nil,
	PowerPlace ={ "CENTER", 439/2 + 79 +2, -6+ 93/2 -62 + 4 +6 }, 
	["PowerSize"] = { 68 +12, 68 +12 },
	["PowerShowAlternate"] = true, 
	["PowerValueColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
	["PowerValueDrawLayer"] = { "OVERLAY", 1 },
	["PowerValueFont"] = GetFont(14, true),
	["PowerValueJustifyH"] = "CENTER", 
	["PowerValueJustifyV"] = "MIDDLE", 
	["PowerValuePlace"] = { "CENTER", 0, -5 },
	["PowerValueOverride"] = TargetFrame_PowerValueOverride,
	["PowerVisibilityFilter"] = TargetFrame_PowerVisibilityFilter,
	["SeasonedCastPlace"] = { "TOPRIGHT", -27, -27 }, 
	["SeasonedCastSize"] = { 385, 40 },
	["SeasonedCastSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["SeasonedCastTexture"] = GetMedia("hp_cap_bar"),
	["SeasonedHealthBackdropColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["SeasonedHealthBackdropPlace"] = { "CENTER", -2, 0 }, 
	["SeasonedHealthBackdropSize"] = { 716, 188 },
	["SeasonedHealthBackdropTexture"] = GetMedia("hp_cap_case"),
	["SeasonedHealthPercentVisible"] = true, 
	["SeasonedHealthPlace"] = { "TOPRIGHT", -27, -27 }, 
	["SeasonedHealthSize"] = { 385, 40 },
	["SeasonedHealthSparkMap"] = {
		{ ["keyPercent"] =   0/512, ["topOffset"] = -24/64, ["bottomOffset"] = -39/64 }, 
		{ ["keyPercent"] =   9/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 460/512, ["topOffset"] =   0/64, ["bottomOffset"] = -16/64 }, 
		{ ["keyPercent"] = 478/512, ["topOffset"] =   0/64, ["bottomOffset"] =   0/64 }, 
		{ ["keyPercent"] = 483/512, ["topOffset"] =   0/64, ["bottomOffset"] =  -3/64 }, 
		{ ["keyPercent"] = 507/512, ["topOffset"] =   0/64, ["bottomOffset"] = -46/64 }, 
		{ ["keyPercent"] = 512/512, ["topOffset"] = -11/64, ["bottomOffset"] = -54/64 }  
	},
	["SeasonedHealthTexture"] = GetMedia("hp_cap_bar"),
	["SeasonedHealthThreatPlace"] = { "CENTER", 0, 1 },
	["SeasonedHealthThreatSize"] = { 716, 188 },
	["SeasonedHealthThreatTexture"] = GetMedia("hp_cap_case_glow"),
	["SeasonedHealthValueVisible"] = true, 
	["SeasonedPortraitForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
	["SeasonedPortraitForegroundTexture"] = GetMedia("portrait_frame_hi"),
	["SeasonedPowerForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["SeasonedPowerForegroundTexture"] = GetMedia("pw_crystal_case"),
	["Size"] = { 439, 93 },
	["TargetIndicatorPetByEnemyColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["TargetIndicatorPetByEnemyPlace"] = { "TOPRIGHT", -10 + 96/2, 12 + 48/2 },
	["TargetIndicatorPetByEnemySize"] = { 96, 48 },
	["TargetIndicatorPetByEnemyTexture"] = GetMedia("icon_target_blue"),
	["TargetIndicatorYouByEnemyColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["TargetIndicatorYouByEnemyPlace"] = { "TOPRIGHT", -10 + 96/2, 12 + 48/2 },
	["TargetIndicatorYouByEnemySize"] = { 96, 48 },
	["TargetIndicatorYouByEnemyTexture"] = GetMedia("icon_target_red"),
	["TargetIndicatorYouByFriendColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] },
	["TargetIndicatorYouByFriendPlace"] = { "TOPRIGHT", -10 + 96/2, 12 + 48/2 },
	["TargetIndicatorYouByFriendSize"] = { 96, 48 },
	["TargetIndicatorYouByFriendTexture"] = GetMedia("icon_target_green"),
	["ThreatFadeOut"] = 3,
	["ThreatHealthAlpha"] = .5,
	["ThreatHealthDrawLayer"] = { "BACKGROUND", -2 },
	["ThreatHealthTexCoord"] = { 1,0,0,1 },
	["ThreatHideSolo"] = true, -- only set to false when testing
	["ThreatPortraitAlpha"] = .5,
	["ThreatPortraitDrawLayer"] = { "BACKGROUND", -2 },
	["ThreatPortraitPlace"] = { "CENTER", -1, 2 + 1 },
	["ThreatPortraitSize"] = { 187, 187 },
	["ThreatPortraitTexture"] = GetMedia("portrait_frame_glow")
})

------------------------------------------------
-- Template Unit Frame Layouts
------------------------------------------------
-- Boss 
RegisterLayout("UnitFrameBoss", "Azerite", setmetatable({
	["GrowthX"] = 0, -- Horizontal growth per new unit
	["GrowthY"] = -97, -- Vertical growth per new unit
	["NameColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	["NameDrawLayer"] = { "OVERLAY", 1 },
	["NameFont"] = GetFont(14, true),
	["NameJustifyH"] = "CENTER",
	["NameJustifyV"] = "TOP", 
	["NamePlace"] = { "BOTTOMRIGHT", -12, 52 }, 
	["HealthColorClass"] = false, -- color players by class 
	["HealthColorDisconnected"] = false, -- color disconnected units
	["HealthColorHealth"] = true, -- color anything else in the default health color
	["HealthColorPetAsPlayer"] = false, -- color your pet as you 
	["HealthColorReaction"] = true, -- color NPCs by their reaction standing with us
	["HealthColorTapped"] = false, -- color tap denied units 
	["HealthColorThreat"] = true, -- threat coloring on non-friendly health bars
	["Place"] = { "TOPRIGHT", "UICenter", "RIGHT", -64, 261 } -- Position of the initial frame
}, { __index = Template_SmallFrameReversed_Auras }))

-- 2-5 player groups
RegisterLayout("UnitFrameParty", "Azerite", setmetatable({

	["HitRectInsets"] = { 0, 0, 0, -10 },

	["AlternateGroupAnchor"] = "BOTTOMLEFT", 
	["AlternateGrowthX"] = 140, -- Horizontal growth per new unit
	["AlternateGrowthY"] = 0, -- Vertical growth per new unit
	["AlternatePlace"] = { "BOTTOMLEFT", "UICenter", "BOTTOMLEFT", 56, 360 + 10 }, -- Position of the healermode frame
	["Aura_PostCreateButton"] = UnitFrame_Aura_PostCreateButton,
	["Aura_PostUpdateButton"] = UnitFrame_Aura_PostUpdateButton,
	
	["Place"] = { "TOPLEFT", "UICenter", "TOPLEFT", 50, -42 }, -- Position of the initial frame
	["GroupAnchor"] = "TOPLEFT", 
	["GrowthX"] = 130, -- Horizontal growth per new unit
	["GrowthY"] = 0, -- Vertical growth per new unit
	
	["HealthColorTapped"] = false, -- color tap denied units 
	["HealthColorDisconnected"] = true, -- color disconnected units
	["HealthColorClass"] = true, -- color players by class
	["HealthColorPetAsPlayer"] = true, -- color your pet as you 
	["HealthColorReaction"] = true, -- color NPCs by their reaction standing with us
	["HealthColorHealth"] = true, -- color anything else in the default health color
	["HealthValuePlace"] = { "CENTER", 0, 0 },
	["HealthValueDrawLayer"] = { "OVERLAY", 1 },
	["HealthValueJustifyH"] = "CENTER", 
	["HealthValueJustifyV"] = "MIDDLE", 
	["HealthValueFont"] = GetFont(13, true),
	["HealthValueColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
	["HealthShowAFK"] = true, 
	["HealthShowPercent"] = true, 

	["PowerBackgroundColor"] = { 0, 0, 0, .75 },
	["PowerBackgroundDrawLayer"] = { "BACKGROUND", -2 },
	["PowerBackgroundSize"] = { 74, 3 },
	["PowerBackgroundPlace"] = { "CENTER", 0, 0 },
	["PowerBackgroundTexture"] = [[Interface\ChatFrame\ChatFrameBackground]], -- GetMedia("statusbar-dark"),
	["PowerBarOrientation"] = "RIGHT",
	["PowerBarSmoothingFrequency"] = .45,
	["PowerBarSmoothingMode"] = "bezier-fast-in-slow-out",
	["PowerBarTexCoord"] = nil, --{ 14/256,(256-14)/256,14/64,(64-14)/64 },
	["PowerBarTexture"] = [[Interface\ChatFrame\ChatFrameBackground]], --GetMedia("statusbar-dark"),
	["PowerPlace"] = { "BOTTOM", 0, -1.5 },
	["PowerSize"] = { 72, 1 },
	["PowerBarPostUpdate"] = TinyFrame_PowerBarPostUpdate,

	["PortraitPlace"] = { "BOTTOM", 0, 22 },
	["PortraitSize"] = { 70, 73 }, 
	["PortraitAlpha"] = .85, 
	["PortraitDistanceScale"] = 1,
	["PortraitPositionX"] = 0,
	["PortraitPositionY"] = 0,
	["PortraitPositionZ"] = 0,
	["PortraitRotation"] = 0, -- in degrees
	["PortraitShowFallback2D"] = true, -- display 2D portraits when unit is out of range of 3D models
	["PortraitBackgroundPlace"] = { "BOTTOM", 0, -6 }, 
	["PortraitBackgroundSize"] = { 130, 130 },
	["PortraitBackgroundTexture"] = GetMedia("party_portrait_back"), 
	["PortraitBackgroundDrawLayer"] = { "BACKGROUND", 0 }, 
	["PortraitBackgroundColor"] = { .5, .5, .5 }, 
	["PortraitShadePlace"] = { "BOTTOM", 0, 16 },
	["PortraitShadeSize"] = { 86, 86 }, 
	["PortraitShadeTexture"] = GetMedia("shade_circle"),
	["PortraitShadeDrawLayer"] = { "BACKGROUND", -1 },
	["PortraitForegroundPlace"] = { "BOTTOM", 0, -38 },
	["PortraitForegroundSize"] = { 194, 194 },
	["PortraitForegroundTexture"] = GetMedia("party_portrait_border"), 
	["PortraitForegroundDrawLayer"] = { "BACKGROUND", 0 },
	["PortraitForegroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 
		
	["AuraProperties"] = {
		["growthX"] = "RIGHT", 
		["growthY"] = "DOWN", 
		["spacingH"] = 4, 
		["spacingV"] = 4, 
		["auraSize"] = 30,  
		["maxVisible"] = 6, 
		["filter"] = "PLAYER",
		["customFilter"] = GetAuraFilter("party"), 
		["debuffsFirst"] = false, 
		["disableMouse"] = false, 
		["showSpirals"] = false, 
		["showDurations"] = true, 
		["showLongDurations"] = true,
		["tooltipDefaultPosition"] = false, 
		["tooltipPoint"] = "TOPLEFT",
		["tooltipAnchor"] = nil,
		["tooltipRelPoint"] = "BOTTOMLEFT",
		["tooltipOffsetX"] = 8,
		["tooltipOffsetY"] = -16
	},
	["AuraFrameSize"] = { 30*3 + 2*5, 30*2 + 5  }, 
	["AuraFramePlace"] = { "BOTTOM", 0, -(30*2 + 5 + 16) },
	["AuraIconPlace"] = { "CENTER", 0, 0 },
	["AuraIconSize"] = { 30 - 6, 30 - 6 },
	["AuraIconTexCoord"] = { 5/64, 59/64, 5/64, 59/64 }, -- aura icon tex coords
	["AuraCountPlace"] = { "BOTTOMRIGHT", 9, -6 },
	["AuraCountFont"] = GetFont(12, true),
	["AuraCountColor"] = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	["AuraTimePlace"] = { "TOPLEFT", -6, 6 },
	["AuraTimeFont"] = GetFont(11, true),
	["AuraBorderFramePlace"] = { "CENTER", 0, 0 }, 
	["AuraBorderFrameSize"] = { 30 + 10, 30 + 10 },
	["AuraBorderBackdrop"] = { edgeFile = GetMedia("aura_border"), edgeSize = 12 },
	["AuraBorderBackdropColor"] = { 0, 0, 0, 0 },
	["AuraBorderBackdropBorderColor"] = { Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3 },
	["Size"] = { 130, 130 }, 

	["UseGroupRole"] = IsRetail, 
	["GroupRolePlace"] = { "TOP", 0, 0 }, 
	["GroupRoleSize"] = { 40, 40 }, 

	["UseGroupRoleBackground"] = true, 
		["GroupRoleBackgroundPlace"] = { "CENTER", 0, 0 }, 
		["GroupRoleBackgroundSize"] = { 77, 77 }, 
		["GroupRoleBackgroundDrawLayer"] = { "BACKGROUND", 1 }, 
		["GroupRoleBackgroundTexture"] = GetMedia("point_plate"),
		["GroupRoleBackgroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 

	["UseGroupRoleHealer"] = true, 
		["GroupRoleHealerPlace"] = { "CENTER", 0, 0 }, 
		["GroupRoleHealerSize"] = { 34, 34 },
		["GroupRoleHealerTexture"] = GetMedia("grouprole-icons-heal"),
		["GroupRoleHealerDrawLayer"] = { "ARTWORK", 1 },

	["UseGroupRoleTank"] = true, 
		["GroupRoleTankPlace"] = { "CENTER", 0, 0 }, 
		["GroupRoleTankSize"] = { 34, 34 },
		["GroupRoleTankTexture"] = GetMedia("grouprole-icons-tank"),
		["GroupRoleTankDrawLayer"] = { "ARTWORK", 1 },

	["UseGroupRoleDPS"] = true, 
		["GroupRoleDPSPlace"] = { "CENTER", 0, 0 }, 
		["GroupRoleDPSSize"] = { 34, 34 },
		["GroupRoleDPSTexture"] = GetMedia("grouprole-icons-dps"),
		["GroupRoleDPSDrawLayer"] = { "ARTWORK", 1 },


	-- Prio #1
	["GroupAuraSize"] = { 36, 36 },
	["GroupAuraPlace"] = { "BOTTOM", 0, -12 }, 
	["GroupAuraButtonIconPlace"] = { "CENTER", 0, 0 },
	["GroupAuraButtonIconSize"] = { 36 - 6, 36 - 6 },
	["GroupAuraButtonIconTexCoord"] = { 5/64, 59/64, 5/64, 59/64 }, -- aura icon tex coords
	["GroupAuraButtonCountPlace"] = { "BOTTOMRIGHT", 9, -6 },
	["GroupAuraButtonCountFont"] = GetFont(12, true),
	["GroupAuraButtonCountColor"] = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	["GroupAuraButtonTimePlace"] = { "CENTER", 0, 0 },
	["GroupAuraButtonTimeFont"] = GetFont(11, true),
	["GroupAuraButtonTimeColor"] = { 250/255, 250/255, 250/255, .85 },
	["GroupAuraButtonBorderFramePlace"] = { "CENTER", 0, 0 }, 
	["GroupAuraButtonBorderFrameSize"] = { 36 + 16, 36 + 16 },
	["GroupAuraButtonBorderBackdrop"] = { edgeFile = GetMedia("aura_border"), edgeSize = 16 },
	["GroupAuraButtonBorderBackdropColor"] = { 0, 0, 0, 0 },
	["GroupAuraButtonBorderBackdropBorderColor"] = { Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3 },
	["GroupAuraButtonDisableMouse"] = true, 
	["GroupAuraTooltipDefaultPosition"] = nil, 
	["GroupAuraPostUpdate"] = function(element, unit)
		local self = element._owner 

		local rz = self.ResurrectIndicator
		local rc = self.ReadyCheck
		local us = self.UnitStatus
		local hv = self.Health.Value

		if element:IsShown() then 
			-- Hide all lower priority elements
			rc:Hide()
			rz:Hide()
			us:Hide()
			hv:Hide()

			-- Colorize the border
			if (element.filter == "HARMFUL") then 
				local color = element.debuffType and Colors.debuff[element.debuffType]
				if color then 
					element.Border:SetBackdropBorderColor(color[1], color[2], color[3])
				else
					element.Border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
				end
			else
				element.Border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
			end

		else 
			-- Display lower priority elements as needed 
			if rc.status then 
				rc:Show()
				rz:Hide()
				us:Hide()
				hv:Hide()
			elseif rz.status then 
				rc:Hide()
				rz:Show()
				us:Hide()
				hv:Hide()
			elseif us.status then 
				rc:Hide()
				rz:Hide()
				us:Show()
				hv:Hide()
			else
				hv:Show()
			end 
		end 
	end, 

	-- Prio #2
	["ReadyCheckPlace"] = { "CENTER", 0, -7 }, 
	["ReadyCheckSize"] = { 32, 32 }, 
	["ReadyCheckDrawLayer"] = { "OVERLAY", 7 },
	["ReadyCheckPostUpdate"] = function(element, unit, status) 
		local self = element._owner

		local rd = self.GroupAura
		local rz = self.ResurrectIndicator
		local us = self.UnitStatus
		local hv = self.Health.Value

		if element:IsShown() then 
			hv:Hide()

			-- Hide if a higher priority element is visible
			if rd:IsShown() then 
				return element:Hide()
			end 
			-- Hide all lower priority elements
			rz:Hide()
			us:Hide()
		else 
			-- Show lower priority elements if no higher is visible
			if (not rd:IsShown()) then 
				if (rz.status) then 
					rz:Show()
					us:Hide()
					hv:Hide()
				elseif (us.status) then 
					rz:Hide()
					us:Show()
					hv:Hide()
				else 
					hv:Show()
				end 
			else 
				hv:Show()
			end 
		end 
	end,
	
	-- Prio #3
	["ResurrectIndicatorPlace"] = { "CENTER", 0, -7 }, 
	["ResurrectIndicatorSize"] = { 32, 32 }, 
	["ResurrectIndicatorDrawLayer"] = { "OVERLAY", 1 },
	["ResurrectIndicatorPostUpdate"] = function(element, unit, incomingResurrect) 
		local self = element._owner

		local rc = self.ReadyCheck
		local rd = self.GroupAura
		local us = self.UnitStatus
		local hv = self.Health.Value

		if element:IsShown() then 
			hv:Hide()

			-- Hide if a higher priority element is visible
			if (rd:IsShown() or rc.status) then 
				return element:Hide()
			end 
			-- Hide lower priority element
			us:Hide()
		else
			-- Show lower priority elements if no higher is visible
			if (not rd:IsShown()) and (not rc.status) then 
				if (us.status) then 
					us:Show()
					hv:Hide()
				else
					hv:Show()
				end 
			end
		end 
	end,

	-- Prio #4
	["UnitStatusPlace"] = { "CENTER", 0, -(7 + 100/2) },
	["UnitStatusDrawLayer"] = { "ARTWORK", 2 },
	["UnitStatusJustifyH"] = "CENTER",
	["UnitStatusJustifyV"] = "MIDDLE",
	["UnitStatusFont"] = GetFont(12, true),
	["UnitStatusColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	["UseUnitStatusMessageOOM"] = L["oom"],
	["UnitStatusHideAFK"] = true, 
	["UnitStatusHideOffline"] = true, 
	["UnitStatusHideDead"] = true, 
	["UnitStatusPostUpdate"] = function(element, unit) 
		local self = element._owner

		local rc = self.ReadyCheck
		local rd = self.GroupAura
		local rz = self.ResurrectIndicator
		local hv = self.Health.Value

		if element:IsShown() then 
			-- Hide if a higher priority element is visible
			if (rd:IsShown() or rc.status or rz.status) then 
				element:Hide()
			end 
			hv:Hide()
		else
			hv:Show()
		end 
	end,
	
}, { __index = Template_TinyFrame }))

-- Player Pet
RegisterLayout("UnitFramePet", "Azerite", setmetatable({
	["HealthColorClass"] = false, -- color players by class 
	["HealthColorDisconnected"] = false, -- color disconnected units
	["HealthColorHealth"] = true, -- color anything else in the default health color
	["HealthColorPetAsPlayer"] = false, -- color your pet as you 
	["HealthColorReaction"] = false, -- color NPCs by their reaction standing with us
	["HealthColorTapped"] = false, -- color tap denied units 
	["HealthFrequentUpdates"] = true, 
	["Place"] = { "LEFT", "UICenter", "BOTTOMLEFT", 362, 125 }
}, { __index = Template_SmallFrame }))

-- Focus
if (IsRetail or IsTBC) then
	RegisterLayout("UnitFrameFocus", "Azerite", setmetatable({
		["AuraProperties"] = {
			["growthX"] = "RIGHT", 
			["growthY"] = "UP", 
			["spacingH"] = 4, 
			["spacingV"] = 4, 
			["auraSize"] = 30, 
			["customFilter"] = GetAuraFilter("focus"), 
			["debuffsFirst"] = false, 
			["disableMouse"] = false, 
			["showSpirals"] = false, 
			["showDurations"] = true, 
			["showLongDurations"] = false,
			["tooltipDefaultPosition"] = false, 
			["tooltipPoint"] = "BOTTOMLEFT",
			["tooltipAnchor"] = nil,
			["tooltipRelPoint"] = "TOPLEFT",
			["tooltipOffsetX"] = 8,
			["tooltipOffsetY"] = 16
		},
		["HealthColorClass"] = true, -- color players by class 
		["HealthColorDisconnected"] = true, -- color disconnected units
		["HealthColorHealth"] = false, -- color anything else in the default health color
		["HealthColorPetAsPlayer"] = true, -- color your pet as you 
		["HealthColorReaction"] = true, -- color NPCs by their reaction standing with us
		["HealthColorTapped"] = true, -- color tap denied units 
		["HealthColorThreat"] = true, -- threat coloring on non-friendly health bars
		["HealthFrequentUpdates"] = true, 
		["HideWhenUnitIsPlayer"] = false, -- hide the frame when the unit is the player, or the target
		["HideWhenTargetIsCritter"] = false, -- hide the frame when unit is a critter 
		["NamePlace"] = { "BOTTOMLEFT", 12, 46 }, 
		["NameDrawLayer"] = { "OVERLAY", 1 },
		["NameJustifyH"] = "LEFT",
		["NameJustifyV"] = "TOP",
		["NameFont"] = GetFont(14, true),
		["NameColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
		["NameSize"] = nil,
		["Place"] = { "RIGHT", "UICenter", "BOTTOMLEFT", 332, 270 }, -- collides with 2nd row of player auras.
		--Place = { "RIGHT", "UICenter", "BOTTOMLEFT", 332, 270 + 50 }
	}, { __index = Template_SmallFrame_Auras }))
end

-- 6-40 player groups
RegisterLayout("UnitFrameRaid", "Azerite", setmetatable({

	["TargetHighlightSize"] = { 132, 85 },
	["HitRectInsets"] = { 0, 0, 0, -10 },
	["Size"] = { 103, 28 }, 
	["Place"] = { "TOPLEFT", "UICenter", "TOPLEFT", 64, -42 }, -- Position of the initial frame
	["AlternatePlace"] = { "BOTTOMLEFT", "UICenter", "BOTTOMLEFT", 64, 350 }, -- Position of the initial frame

	["GroupSizeNormal"] = 5,
	["GrowthXNormal"] = 0, -- Horizontal growth per new unit within a group
	["GrowthYNormal"] = -38 - 4, -- Vertical growth per new unit within a group
	["GrowthYNormalHealerMode"] = 42, -- Vertical growth per new unit within a group
	["GroupGrowthXNormal"] = 110, 
	["GroupGrowthYNormal"] = -240,
	["GroupGrowthYNormalHealerMode"] = 240,
	["GroupColsNormal"] = 5, 
	["GroupRowsNormal"] = 1, 
	["GroupAnchorNormal"] = "TOPLEFT", 
	["GroupAnchorNormalHealerMode"] = "BOTTOMLEFT", 
	["GroupSizeEpic"] = 8,
	["GrowthXEpic"] = 0, 
	["GrowthYEpic"] = -42,
	["GrowthYEpicHealerMode"] = 42,
	["GroupGrowthXEpic"] = 110, 
	["GroupGrowthYEpic"] = -378,
	["GroupGrowthYEpicHealerMode"] = 378,
	["GroupColsEpic"] = 5, 
	["GroupRowsEpic"] = 1, 
	["GroupAnchorEpic"] = "TOPLEFT", 
	["GroupAnchorEpicHealerMode"] = "BOTTOMLEFT", 

	["GroupNumberColor"] = { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
	["GroupNumberDrawLayer"] = { "ARTWORK", 1 },
	["GroupNumberFont"] = GetFont(11,true),
	["GroupNumberJustifyH"] = "RIGHT",
	["GroupNumberJustifyV"] = "BOTTOM",
	["GroupNumberPlace"] = { "BOTTOMLEFT", 2, -6 },

	["HealthSize"] = { 75, 13 }, 
	["HealthBackdropSize"] = { 132, 85 },
	["HealthColorTapped"] = false, -- color tap denied units 
	["HealthColorDisconnected"] = true, -- color disconnected units
	["HealthColorClass"] = true, -- color players by class
	["HealthColorPetAsPlayer"] = true, -- color your pet as you 
	["HealthColorReaction"] = true, -- color NPCs by their reaction standing with us
	["HealthColorHealth"] = true, -- color anything else in the default health color

	["PowerBackgroundColor"] = { 0, 0, 0, .75 },
	["PowerBackgroundDrawLayer"] = { "BACKGROUND", -2 },
	["PowerBackgroundSize"] = { 68, 3 },
	["PowerBackgroundPlace"] = { "CENTER", 0, 0 },
	["PowerBackgroundTexture"] = [[Interface\ChatFrame\ChatFrameBackground]], -- GetMedia("statusbar-dark"),
	["PowerBarOrientation"] = "RIGHT",
	["PowerBarSmoothingFrequency"] = .45,
	["PowerBarSmoothingMode"] = "bezier-fast-in-slow-out",
	["PowerBarTexCoord"] = nil, --{ 14/256,(256-14)/256,14/64,(64-14)/64 },
	["PowerBarTexture"] = [[Interface\ChatFrame\ChatFrameBackground]], --GetMedia("statusbar-dark"),
	["PowerPlace"] = { "BOTTOM", 0, -.5 },
	["PowerSize"] = { 66, 1 },
	["PowerBarPostUpdate"] = TinyFrame_PowerBarPostUpdate,

	["NamePlace"] = { "TOP", 0, 1 - 2 }, 
	["NameDrawLayer"] = { "ARTWORK", 1 },
	["NameJustifyH"] = "CENTER",
	["NameJustifyV"] = "TOP",
	["NameFont"] = GetFont(11, true),
	["NameColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	["NameMaxChars"] = 8, 
	["NameUseDots"] = false, 

	["RaidRolePoint"] = "RIGHT", RaidRoleAnchor = "Name", RaidRolePlace = { "LEFT", -1, 1 }, 
	["RaidRoleSize"] = { 16, 16 }, 
	["RaidRoleDrawLayer"] = { "ARTWORK", 3 },
	["RaidRoleRaidTargetTexture"] = GetMedia("raid_target_icons_small"),
	
	["UseGroupRole"] = IsRetail, 
	["GroupRolePlace"] = { "RIGHT", 10, -8 }, 
	["GroupRoleSize"] = { 28, 28 }, 

	["UseGroupRoleBackground"] = true, 
		["GroupRoleBackgroundPlace"] = { "CENTER", 0, 0 }, 
		["GroupRoleBackgroundSize"] = { 54, 54 }, 
		["GroupRoleBackgroundDrawLayer"] = { "BACKGROUND", 1 }, 
		["GroupRoleBackgroundTexture"] = GetMedia("point_plate"),
		["GroupRoleBackgroundColor"] = { Colors.ui[1], Colors.ui[2], Colors.ui[3] }, 

	["UseGroupRoleHealer"] = true, 
		["GroupRoleHealerPlace"] = { "CENTER", 0, 0 }, 
		["GroupRoleHealerSize"] = { 24, 24 },
		["GroupRoleHealerTexture"] = GetMedia("grouprole-icons-heal"),
		["GroupRoleHealerDrawLayer"] = { "ARTWORK", 1 },

	["UseGroupRoleTank"] = true, 
		["GroupRoleTankPlace"] = { "CENTER", 0, 0 }, 
		["GroupRoleTankSize"] = { 24, 24 },
		["GroupRoleTankTexture"] = GetMedia("grouprole-icons-tank"),
		["GroupRoleTankDrawLayer"] = { "ARTWORK", 1 },

	["UseGroupRoleDPS"] = false, 
		["GroupRoleDPSPlace"] = { "CENTER", 0, 0 }, 
		["GroupRoleDPSSize"] = { 24, 24 },
		["GroupRoleDPSTexture"] = GetMedia("grouprole-icons-dps"),
		["GroupRoleDPSDrawLayer"] = { "ARTWORK", 1 },

	["GroupRolePostUpdate"] = function(element, unit, groupRole)
		if groupRole then 
			if groupRole == "DAMAGER" then 
				element.Bg:Hide()
			else 
				element.Bg:Show()
			end 
		end 
	end, 

	-- Prio #1
	["GroupAuraSize"] = { 24, 24 },
	["GroupAuraPlace"] = { "BOTTOM", 0, -8 }, 
	["GroupAuraButtonIconPlace"] = { "CENTER", 0, 0 },
	["GroupAuraButtonIconSize"] = { 18, 18 },
	["GroupAuraButtonIconTexCoord"] = { 5/64, 59/64, 5/64, 59/64 }, -- aura icon tex coords
	["GroupAuraButtonCountPlace"] = { "BOTTOMRIGHT", 9, -6 },
	["GroupAuraButtonCountFont"] = GetFont(12, true),
	["GroupAuraButtonCountColor"] = { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
	["GroupAuraButtonTimePlace"] = { "CENTER", 0, 0 },
	["GroupAuraButtonTimeFont"] = GetFont(11, true),
	["GroupAuraButtonTimeColor"] = { 250/255, 250/255, 250/255, .85 },
	["GroupAuraButtonBorderFramePlace"] = { "CENTER", 0, 0 }, 
	["GroupAuraButtonBorderFrameSize"] = { 36, 36 },
	["GroupAuraButtonBorderBackdrop"] = { edgeFile = GetMedia("aura_border"), edgeSize = 12 },
	["GroupAuraButtonBorderBackdropColor"] = { 0, 0, 0, 0 },
	["GroupAuraButtonBorderBackdropBorderColor"] = { Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3 },
	["GroupAuraButtonDisableMouse"] = true, 
	["GroupAuraTooltipDefaultPosition"] = nil, 
	["GroupAuraPostUpdate"] = function(element, unit)
		local self = element._owner 

		local rz = self.ResurrectIndicator
		local rc = self.ReadyCheck
		local us = self.UnitStatus

		if element:IsShown() then 
			-- Hide all lower priority elements
			rc:Hide()
			rz:Hide()
			us:Hide()

			-- Colorize the border
			if (element.filter == "HARMFUL") then 
				local color = element.debuffType and Colors.debuff[element.debuffType]
				if color then 
					element.Border:SetBackdropBorderColor(color[1], color[2], color[3])
				else
					element.Border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
				end
			else
				element.Border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
			end
	
		else 
			-- Display lower priority elements as needed 
			if rc.status then 
				rc:Show()
				rz:Hide()
				us:Hide()
			elseif rz.status then 
				rc:Hide()
				rz:Show()
				us:Hide()
			elseif us.status then 
				rc:Hide()
				rz:Hide()
				us:Show()
			end 
		end 
	end, 

	-- Prio #2
	["ReadyCheckPlace"] = { "CENTER", 0, -7 }, 
	["ReadyCheckSize"] = { 32, 32 }, 
	["ReadyCheckDrawLayer"] = { "OVERLAY", 7 },
	["ReadyCheckPostUpdate"] = function(element, unit, status) 
		local self = element._owner

		local rd = self.GroupAura
		local rz = self.ResurrectIndicator
		local us = self.UnitStatus

		if element:IsShown() then 
			-- Hide if a higher priority element is visible
			if rd:IsShown() then 
				return element:Hide()
			end 
			-- Hide all lower priority elements
			rz:Hide()
			us:Hide()
		else 
			-- Show lower priority elements if no higher is visible
			if (not rd:IsShown()) then 
				if (rz.status) then 
					rz:Show()
					us:Hide()
				elseif (us.status) then 
					rz:Hide()
					us:Show()
				end 
			end 
		end 
	end,

	-- Prio #3
	["ResurrectIndicatorPlace"] = { "CENTER", 0, -7 }, 
	["ResurrectIndicatorSize"] = { 32, 32 }, 
	["ResurrectIndicatorDrawLayer"] = { "OVERLAY", 1 },
	["ResurrectIndicatorPostUpdate"] = function(element, unit, incomingResurrect) 
		local self = element._owner

		local rc = self.ReadyCheck
		local rd = self.GroupAura
		local us = self.UnitStatus

		if element:IsShown() then 
			-- Hide if a higher priority element is visible
			if (rd:IsShown() or rc.status) then 
				return element:Hide()
			end 
			-- Hide lower priority element
			us:Hide()
		else
			-- Show lower priority elements if no higher is visible
			if (not rd:IsShown()) and (not rc.status) then 
				if (us.status) then 
					us:Show()
				end 
			end
		end 
	end,

	-- Prio #4
	["UnitStatusPlace"] = { "CENTER", 0, -7 },
	["UnitStatusDrawLayer"] = { "ARTWORK", 2 },
	["UnitStatusJustifyH"] = "CENTER",
	["UnitStatusJustifyV"] = "MIDDLE",
	["UnitStatusFont"] = GetFont(12, true),
	["UnitStatusColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	["UseUnitStatusMessageOOM"] = L["oom"],
	["UnitStatusPostUpdate"] = function(element, unit) 
		local self = element._owner
		local rc = self.ReadyCheck
		local rd = self.GroupAura
		local rz = self.ResurrectIndicator
		if element:IsShown() then 
			-- Hide if a higher priority element is visible
			if (rd:IsShown() or rc.status or rz.status) then 
				element:Hide()
			end 
		end 
	end,

}, { __index = Template_TinyFrame }))

-- Target of Target
RegisterLayout("UnitFrameToT", "Azerite", setmetatable({
	["HealthColorClass"] = true, -- color players by class 
	["HealthColorDisconnected"] = true, -- color disconnected units
	["HealthColorHealth"] = false, -- color anything else in the default health color
	["HealthColorPetAsPlayer"] = true, -- color your pet as you 
	["HealthColorReaction"] = true, -- color NPCs by their reaction standing with us
	["HealthColorTapped"] = true, -- color tap denied units 
	["HealthColorThreat"] = true, -- threat coloring on non-friendly health bars
	["HealthFrequentUpdates"] = true, 
	["HideWhenTargetIsCritter"] = true, -- hide the frame when unit is a critter
	["HideWhenUnitIsPlayer"] = true, -- hide the frame when the unit is the player
	["HideWhenUnitIsTarget"] = true, -- hide the frame when the unit matches our target
	["NameColor"] = { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .75 },
	["NameDrawLayer"] = { "OVERLAY", 1 },
	["NameFont"] = GetFont(14, true),
	["NameJustifyH"] = "RIGHT",
	["NameJustifyV"] = "TOP", 
	["NamePlace"] = { "BOTTOMRIGHT", -12, 48 }, 
	["Place"] = { "RIGHT", "UICenter", "TOPRIGHT", -492, -90 }
}, { __index = Template_SmallFrameReversed }))

------------------------------------------------
-- Lease & Lend
-- *Elements we copy between themes
--  with none or very few changes.
------------------------------------------------
-- No changes
RegisterLayoutVariation("BlizzardFonts", "Legacy", "Azerite", {})
RegisterLayoutVariation("BlizzardGameMenu", "Legacy", "Azerite", {})
RegisterLayoutVariation("BlizzardMicroMenu", "Legacy", "Azerite", {})
RegisterLayoutVariation("BlizzardPopupStyling", "Legacy", "Azerite", {})
RegisterLayoutVariation("BlizzardTimers", "Legacy", "Azerite", {})
RegisterLayoutVariation("BlizzardTooltips", "Legacy", "Azerite", {})
RegisterLayoutVariation("BlizzardWorldMap", "Legacy", "Azerite", {})
RegisterLayoutVariation("ChatFilters", "Legacy", "Azerite", {})
RegisterLayoutVariation("GroupTools", "Legacy", "Azerite", {})
RegisterLayoutVariation("NamePlates", "Legacy", "Azerite", {})

-- Few changes
RegisterLayoutVariation("Bindings", "Legacy", "Azerite", { BindButtonTexture = GetMedia("actionbutton-mask-square") })
RegisterLayoutVariation("Durability", "Legacy", "Azerite", { 	["Place"] = { "CENTER", "UICenter", "BOTTOMRIGHT", -360, 190 } })
RegisterLayoutVariation("Tooltips", "Legacy", "Azerite", { TooltipPlace = { "BOTTOMRIGHT", "UICenter", "BOTTOMRIGHT", -54, 66 } })
RegisterLayoutVariation("OptionsMenu", "Legacy", "Azerite", { MenuPlace = { "TOPRIGHT", -41, -32 }, MenuToggleButtonPlace = { "TOPRIGHT", -4, -4 } })
