local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("NamePlates", "LibEvent", "LibNamePlate", "LibDB", "LibFrame", "LibClientBuild", "LibForge")

-- WoW API
local GetQuestGreenRange = GetQuestGreenRange
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance 
local SetCVar = SetCVar
local SetNamePlateEnemyClickThrough = C_NamePlate.SetNamePlateEnemyClickThrough
local SetNamePlateEnemySize = C_NamePlate.SetNamePlateEnemySize
local SetNamePlateFriendlyClickThrough = C_NamePlate.SetNamePlateFriendlyClickThrough
local SetNamePlateFriendlySize = C_NamePlate.SetNamePlateFriendlySize
local SetNamePlateSelfClickThrough = C_NamePlate.SetNamePlateSelfClickThrough
local SetNamePlateSelfSize = C_NamePlate.SetNamePlateSelfSize

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetLayout = Private.GetLayout

-- Constants for client version
local IsClassic = Module:IsClassic()
local IsRetail = Module:IsRetail()

-- Local cache of the nameplates, for easy access to some methods
local Plates = {} 

-- Library Updates
-- *will be called by the library at certain times
-----------------------------------------------------------------
-- Called on PLAYER_ENTERING_WORLD by the library, 
-- but before the library calls its own updates.
Module.PreUpdateNamePlateOptions = function(self)

	if (IsRetail) then
		local _, instanceType = IsInInstance()
		if (instanceType == "none") then
			SetCVar("nameplateMaxDistance", 30)
		else
			SetCVar("nameplateMaxDistance", 45)
		end
	end

	-- If these are enabled the GameTooltip will become protected, 
	-- and all sort of taints and bugs will occur.
	-- This happens on specs that can dispel when hovering over nameplate auras.
	-- We create our own auras anyway, so we don't need these. 
	SetCVar("nameplateShowDebuffsOnFriendly", 0) 

end 

-- Called when certain bindable blizzard settings change, 
-- or when the VARIABLES_LOADED event fires. 
Module.PostUpdateNamePlateOptions = function(self, isInInstace)
	local layout = self.layout

	-- Make an extra call to the preupdate
	self:PreUpdateNamePlateOptions()

	if layout.SetConsoleVars then 
		for name,value in pairs(layout.SetConsoleVars) do 
			SetCVar(name, value or GetCVarDefault(name))
		end 
	end 

	-- Setting the base size involves changing the size of secure unit buttons,
	-- but since we're using our out of combat wrapper, we should be safe.
	-- Default size 110, 45
	-- Note: No freaking effect at all in classic. >:(
	SetNamePlateFriendlySize(unpack(layout.Size))
	SetNamePlateEnemySize(unpack(layout.Size))
	SetNamePlateSelfSize(unpack(layout.Size))

	--NamePlateDriverFrame.UpdateNamePlateOptions = function() end
end

-- Called after a nameplate is created.
-- This is where we create our own custom elements.
Module.PostCreateNamePlate = function(self, plate, baseFrame)
	local db = self.db
	local layout = self.layout

	-- If a forge exists, we leave it all to that.
	local forge = layout and layout.WidgetForge and layout.WidgetForge.NamePlate
	if (forge) then
		return self:Forge(plate, forge)
	end

	-- the old way

	plate:SetSize(unpack(layout.Size))
	plate.colors = Colors
	plate.layout = layout

	-- Health bar
	local health = plate:CreateStatusBar()
	health:Hide()
	health:SetSize(unpack(layout.HealthSize))
	health:SetPoint(unpack(layout.HealthPlace))
	health:SetStatusBarTexture(layout.HealthTexture)
	health:SetOrientation(layout.HealthBarOrientation)
	health:SetSmoothingFrequency(.1)
	health:SetSparkMap(layout.HealthSparkMap)
	health:SetTexCoord(unpack(layout.HealthTexCoord))
	health.absorbThreshold = layout.AbsorbThreshold
	health.threatFeedbackUnit = "player"
	health.colorThreat = layout.HealthColorThreat -- color non-friendly by threat
	health.colorTapped = layout.HealthColorTapped
	health.colorDisconnected = layout.HealthColorDisconnected
	health.colorClass = layout.HealthColorClass
	health.colorCivilian = layout.HealthColorCivilian
	health.colorReaction = layout.HealthColorReaction
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.colorPlayer = layout.HealthColorPlayer
	health.frequent = layout.HealthFrequent
	plate.Health = health

	local healthBg = health:CreateTexture()
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetTexture(layout.HealthBackdropTexture)
	healthBg:SetVertexColor(unpack(layout.HealthBackdropColor))
	plate.Health.Bg = healthBg

	local healthValue = health:CreateFontString()
	healthValue:Hide()
	healthValue:SetPoint(unpack(layout.HealthValuePlace))
	healthValue:SetDrawLayer(unpack(layout.HealthValueDrawLayer))
	healthValue:SetFontObject(layout.HealthValueFontObject)
	healthValue:SetTextColor(unpack(layout.HealthValueColor))
	healthValue:SetJustifyH(layout.HealthValueJustifyH)
	healthValue:SetJustifyV(layout.HealthValueJustifyV)
	healthValue.hidePlayer = layout.HealthValueHidePlayer
	healthValue.hideCasting = layout.HealthValueHideWhileCasting
	healthValue.showCombat = layout.HealthValueShowInCombat
	healthValue.showMouseover = layout.HealthValueShowOnMouseover
	healthValue.showTarget = layout.HealthValueShowOnTarget
	healthValue.showMaxValue = layout.HealthValueShowAtMax
	plate.Health.Value = healthValue

	local name = health:CreateFontString()
	name:Hide()
	name:SetPoint(unpack(layout.NamePlace))
	name:SetDrawLayer(unpack(layout.NameDrawLayer))
	name:SetJustifyH(layout.NameJustifyH)
	name:SetJustifyV(layout.NameJustifyV)
	name:SetFontObject(layout.NameFont)
	name:SetTextColor(unpack(layout.NameColor))
	name.showLevel = layout.NameShowLevel
	name.showLevelLast = layout.NameShowLevelLast
	name.hidePlayer = layout.NameHidePlayer
	name.showCombat = layout.NameShowInCombat
	name.showMouseover = layout.NameShowOnMouseover
	name.showTarget = layout.NameShowOnTarget
	plate.Name = name
	
	local cast = plate.Health:CreateStatusBar()
	cast:SetSize(unpack(layout.CastSize))
	cast:SetPoint(unpack(layout.CastPlace))
	cast:SetStatusBarTexture(layout.CastTexture)
	cast:SetOrientation(layout.CastOrientation)
	cast:SetTexCoord(unpack(layout.CastTexCoord))
	cast:SetSparkMap(layout.CastSparkMap)
	cast:SetSmoothingFrequency(.1)
	cast.timeToHold = layout.CastTimeToHoldFailed
	plate.Cast = cast
	plate.Cast.PostUpdate = layout.PostUpdateCast

	local castBg = cast:CreateTexture()
	castBg:SetPoint(unpack(layout.CastBackdropPlace))
	castBg:SetSize(unpack(layout.CastBackdropSize))
	castBg:SetDrawLayer(unpack(layout.CastBackdropDrawLayer))
	castBg:SetTexture(layout.CastBackdropTexture)
	castBg:SetVertexColor(unpack(layout.CastBackdropColor))
	plate.Cast.Bg = castBg

	local castName = cast:CreateFontString()
	castName:SetPoint(unpack(layout.CastNamePlace))
	castName:SetDrawLayer(unpack(layout.CastNameDrawLayer))
	castName:SetFontObject(layout.CastNameFont)
	castName:SetTextColor(unpack(layout.CastNameColor))
	castName:SetJustifyH(layout.CastNameJustifyH)
	castName:SetJustifyV(layout.CastNameJustifyV)
	cast.Name = castName

	local castShield = cast:CreateTexture()
	castShield:SetPoint(unpack(layout.CastShieldPlace))
	castShield:SetSize(unpack(layout.CastShieldSize))
	castShield:SetTexture(layout.CastShieldTexture) 
	castShield:SetDrawLayer(unpack(layout.CastShieldDrawLayer))
	castShield:SetVertexColor(unpack(layout.CastShieldColor))
	cast.Shield = castShield

	local threat = plate.Health:CreateTexture()
	threat:SetPoint(unpack(layout.ThreatPlace))
	threat:SetSize(unpack(layout.ThreatSize))
	threat:SetTexture(layout.ThreatTexture)
	threat:SetDrawLayer(unpack(layout.ThreatDrawLayer))
	threat:SetVertexColor(unpack(layout.ThreatColor))
	threat.hideSolo = layout.ThreatHideSolo
	threat.feedbackUnit = "player"
	plate.Threat = threat

	if (IsRetail) then
		local spellQueue = cast:CreateStatusBar()
		spellQueue:Hide()
		spellQueue:SetFrameLevel(cast:GetFrameLevel() + 1)
		spellQueue:Place(unpack(layout.CastBarSpellQueuePlace))
		spellQueue:SetSize(unpack(layout.CastBarSpellQueueSize))
		spellQueue:SetOrientation(layout.CastBarSpellQueueOrientation) 
		spellQueue:SetStatusBarTexture(layout.CastBarSpellQueueTexture) 
		spellQueue:SetTexCoord(unpack(layout.CastBarSpellQueueCastTexCoord))
		spellQueue:SetStatusBarColor(unpack(layout.CastBarSpellQueueColor)) 
		spellQueue:DisableSmoothing(true)
		cast.SpellQueue = spellQueue
	end

	-- Unit Classification (boss, elite, rare)
	local classification = health:CreateFrame("Frame")
	classification:SetPoint(unpack(layout.ClassificationPlace))
	classification:SetSize(unpack(layout.ClassificationSize))
	classification.hideOnFriendly = layout.ClassificationHideOnFriendly
	classification:SetIgnoreParentAlpha(true)
	plate.Classification = classification

	local boss = classification:CreateTexture()
	boss:SetPoint("CENTER", 0, 0)
	boss:SetSize(unpack(layout.ClassificationSize))
	boss:SetTexture(layout.ClassificationIndicatorBossTexture)
	boss:SetVertexColor(unpack(layout.ClassificationColor))
	plate.Classification.Boss = boss

	local elite = classification:CreateTexture()
	elite:SetPoint("CENTER", 0, 0)
	elite:SetSize(unpack(layout.ClassificationSize))
	elite:SetTexture(layout.ClassificationIndicatorEliteTexture)
	elite:SetVertexColor(unpack(layout.ClassificationColor))
	plate.Classification.Elite = elite

	local rare = classification:CreateTexture()
	rare:SetPoint("CENTER", 0, 0)
	rare:SetSize(unpack(layout.ClassificationSize))
	rare:SetTexture(layout.ClassificationIndicatorRareTexture)
	rare:SetVertexColor(unpack(layout.ClassificationColor))
	plate.Classification.Rare = rare

	local raidTarget = baseFrame:CreateTexture()
	raidTarget.point = layout.RaidTargetPoint
	raidTarget.anchor = plate[layout.RaidTargetAnchor] or plate
	raidTarget.relPoint = layout.RaidTargetRelPoint
	raidTarget.offsetX = layout.RaidTargetOffsetX
	raidTarget.offsetY = layout.RaidTargetOffsetY
	raidTarget:SetPoint(raidTarget.point, raidTarget.anchor, raidTarget.relPoint, raidTarget.offsetX, raidTarget.offsetY)
	raidTarget:SetSize(unpack(layout.RaidTargetSize))
	raidTarget:SetDrawLayer(unpack(layout.RaidTargetDrawLayer))
	raidTarget:SetTexture(layout.RaidTargetTexture)
	raidTarget:SetScale(plate:GetScale())
	plate.RaidTarget = raidTarget
	plate.RaidTarget.PostUpdate = layout.PostUpdateRaidTarget
	hooksecurefunc(plate, "SetScale", function(plate,scale) raidTarget:SetScale(scale) end)

	local auras = plate:CreateFrame("Frame")
	auras:SetSize(unpack(layout.AuraFrameSize))
	auras.point = layout.AuraPoint
	auras.anchor = plate[layout.AuraAnchor] or plate
	auras.relPoint = layout.AuraRelPoint
	auras.offsetX = layout.AuraOffsetX
	auras.offsetY = layout.AuraOffsetY
	auras.disableMouse = true
	auras:ClearAllPoints()
	auras:SetPoint(auras.point, auras.anchor, auras.relPoint, auras.offsetX, auras.offsetY)
	for property,value in pairs(layout.AuraProperties) do 
		auras[property] = value
	end
	plate.Auras = auras
	plate.Auras.PostCreateButton = layout.PostCreateAuraButton -- post creation styling
	plate.Auras.PostUpdateButton = layout.PostUpdateAuraButton -- post updates when something changes (even timers)
	plate.Auras.PostUpdate = layout.PostUpdateAura
	if (not db.enableAuras) then 
		plate:DisableElement("Auras")
	end 

	-- Add in Personal Resource Display for Retail
	if (IsRetail) then

		-- Power bar
		local power = plate:CreateStatusBar()
		power:Hide()
		power:SetSize(unpack(layout.PowerSize))
		power:SetPoint(unpack(layout.PowerPlace))
		power:SetStatusBarTexture(layout.PowerTexture)
		power:SetOrientation(layout.PowerBarOrientation)
		power:SetSmoothingFrequency(.1)
		power:SetSparkMap(layout.PowerSparkMap)
		power:SetTexCoord(unpack(layout.PowerTexCoord))
		power.frequent = layout.PowerFrequent
		plate.Power = power

		local powerBg = power:CreateTexture()
		powerBg:SetPoint(unpack(layout.PowerBackdropPlace))
		powerBg:SetSize(unpack(layout.PowerBackdropSize))
		powerBg:SetDrawLayer(unpack(layout.PowerBackdropDrawLayer))
		powerBg:SetTexture(layout.PowerBackdropTexture)
		powerBg:SetVertexColor(unpack(layout.PowerBackdropColor))
		plate.Power.Bg = powerBg

		-- Disable this as default, we only want it on the player.
		plate:DisableElement("Power")
	end

	-- Add preupdates. Usually only meaningful in Retail.
	plate.PreUpdate = layout.PreUpdate

	-- Add post updates. 
	plate.PostUpdate = layout.PostUpdate

	-- The library does this too, but isn't exposing it to us.
	Plates[plate] = baseFrame
end

Module.PostUpdateSettings = function(self)
	local db = self.db
	for plate, baseFrame in pairs(Plates) do 
		if (db.enableAuras) then 
			plate:EnableElement("Auras")
			plate.Auras:ForceUpdate()
			plate.RaidTarget:ForceUpdate()
		else 
			plate:DisableElement("Auras")
			plate.RaidTarget:ForceUpdate()
		end 
		plate:PostUpdate("ForceUpdate", plate.unit)
	end
end

Module.PostUpdateCVars = function(self, event, ...)
	if InCombatLockdown() then 
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "PostUpdateCVars")
	end 
	if (event == "PLAYER_REGEN_ENABLED") then 
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "PostUpdateCVars")
	end 
	local db = self.db
	SetNamePlateEnemyClickThrough(db.clickThroughEnemies)
	SetNamePlateFriendlyClickThrough(db.clickThroughFriends)
	SetNamePlateSelfClickThrough(db.clickThroughSelf)
end

Module.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then 
		self:PostUpdateCVars()
	end 
end

Module.OnInit = function(self)
	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	local OptionsMenu = Core:GetModule("OptionsMenu", true)
	if (OptionsMenu) then
		local callbackFrame = OptionsMenu:CreateCallbackFrame(self)
		callbackFrame:AssignProxyMethods("PostUpdateSettings", "PostUpdateCVars")
		callbackFrame:AssignSettings(self.db)
		callbackFrame:AssignCallback([=[
			if name then 
				name = string.lower(name); 
			end 
			if (name == "change-enableauras") then 
				self:SetAttribute("enableAuras", value); 
				self:CallMethod("PostUpdateSettings"); 

			elseif (name == "change-clickthroughenemies") then
				self:SetAttribute("clickThroughEnemies", value); 
				self:CallMethod("PostUpdateCVars"); 

			elseif (name == "change-clickthroughfriends") then 
				self:SetAttribute("clickThroughFriends", value); 
				self:CallMethod("PostUpdateCVars"); 

			elseif (name == "change-clickthroughself") then 
				self:SetAttribute("clickThroughSelf", value); 
				self:CallMethod("PostUpdateCVars"); 

			end 
		]=])
	end
end 

Module.OnEnable = function(self)
	self:StartNamePlateEngine()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end 
