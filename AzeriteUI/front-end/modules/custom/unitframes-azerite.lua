--[[--

The purpose of this file is to create general but
addon specific styling methods for all the unitframes.

This file is loaded after other general user databases,
but prior to loading any of the module config files.
Meaning we can reference the general databases with certainty,
but any layout data will have to be passed as function arguments.

--]]--
local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end

-- Keep these local
local UnitStyles = {}

-- Lua API
local date = date
local ipairs = ipairs
local math_ceil = math.ceil
local math_floor = math.floor
local math_pi = math.pi
local select = select
local string_format = string.format
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_split = string.split
local tonumber = tonumber
local tostring = tostring
local unpack = unpack

-- WoW API
local GetCVarBool = GetCVarBool
local GetInventoryItemTexture = GetInventoryItemTexture
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local RegisterAttributeDriver = RegisterAttributeDriver
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsAFK = UnitIsAFK
local UnitIsPlayer = UnitIsPlayer
local UnitLevel = UnitLevel

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetDefaults = Private.GetDefaults
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout
local GetLayoutID = Private.GetLayoutID
local GetMedia = Private.GetMedia
local IsClassic = Private.IsClassic
local IsTBC = Private.IsTBC
local IsRetail = Private.IsRetail
local IsWinterVeil = Private.IsWinterVeil
local IsLoveFestival = Private.IsLoveFestival

-- WoW Textures
local EDGE_NORMAL_TEXTURE = [[Interface\Cooldown\edge]]
local BLING_TEXTURE = [[Interface\Cooldown\star4]]

-- Player data
local _,PlayerClass = UnitClass("player")
local _,PlayerLevel = UnitLevel("player")

-----------------------------------------------------------
-- Define Modules
-----------------------------------------------------------
-- Primary Units
local UnitFramePlayer = Core:NewModule("UnitFramePlayer", "LibDB", "LibMessage", "LibEvent", "LibUnitFrame", "LibFrame", "LibForge", "LibTime")
local UnitFramePlayerHUD = Core:NewModule("UnitFramePlayerHUD", "LibDB", "LibMessage", "LibEvent", "LibUnitFrame", "LibFrame", "LibForge")
local UnitFrameTarget = Core:NewModule("UnitFrameTarget", "LibMessage", "LibEvent", "LibUnitFrame", "LibSound", "LibForge")

-- Secondary Units
local UnitFramePet = Core:NewModule("UnitFramePet", "LibUnitFrame", "LibFrame", "LibForge")
local UnitFrameToT = Core:NewModule("UnitFrameToT", "LibUnitFrame", "LibForge")
local UnitFrameFocus = (IsRetail or IsTBC) and Core:NewModule("UnitFrameFocus", "LibMessage", "LibUnitFrame", "LibForge")

-- Grouped Units
local UnitFrameArena = (IsRetail or IsTBC) and Core:NewModule("UnitFrameArena", "LibDB", "LibMessage", "LibUnitFrame", "LibFrame", "LibForge")
local UnitFrameBoss = Core:NewModule("UnitFrameBoss", "LibUnitFrame", "LibMessage", "LibForge")
local UnitFrameParty = Core:NewModule("UnitFrameParty", "LibDB", "LibMessage", "LibFrame", "LibUnitFrame", "LibForge")
local UnitFrameRaid = Core:NewModule("UnitFrameRaid", "LibDB", "LibFrame", "LibUnitFrame", "LibBlizzard", "LibForge")

-----------------------------------------------------------
-- Secure Stuff
-----------------------------------------------------------
-- All secure code snippets
-- TODO: Move to stylesheet.
local SECURE = {

	-- Called on the group headers
	FrameTable_Create = [=[
		Frames = table.new();
	]=],
	FrameTable_InsertCurrentFrame = [=[
		local frame = self:GetFrameRef("CurrentFrame");
		table.insert(Frames, frame);
	]=],

	Player_SecureCallback = [=[
		if name then
			name = string.lower(name);
		end
		if (name == "change-enableplayermanaorb") then
			local owner = self:GetFrameRef("Owner");
			self:SetAttribute("enablePlayerManaOrb", value);
			if (value) then
				owner:CallMethod("EnableManaOrb");
			else
				owner:CallMethod("DisableManaOrb");
			end
		elseif (name == "change-enableauras") then
			local owner = self:GetFrameRef("Owner");
			self:SetAttribute("enableAuras", value);
			if (value) then
				owner:CallMethod("EnableAuras");
			else
				owner:CallMethod("DisableAuras");
			end
		end
	]=],

	Target_SecureCallback = [=[
		if name then
			name = string.lower(name);
		end
		if (name == "change-enableauras") then
			local owner = self:GetFrameRef("Owner");
			self:SetAttribute("enableAuras", value);
			if (value) then
				owner:CallMethod("EnableAuras");
			else
				owner:CallMethod("DisableAuras");
			end
		end
	]=],

	-- Called on the HUD callback frame
	HUD_SecureCallback = [=[
		if name then
			name = string.lower(name);
		end
		if (name == "change-enablecast") then
			local owner = self:GetFrameRef("Owner");
			self:SetAttribute("enableCast", value);
			self:CallMethod("UpdateCastBar");

		elseif (name == "change-enableclasspower") then
			local owner = self:GetFrameRef("Owner");
			self:SetAttribute("enableClassPower", value);
			local forceDisable = self:GetAttribute("forceDisableClassPower");

			if (forceDisable) or (not value) then
				owner:CallMethod("DisableElement", "ClassPower");
			else
				owner:CallMethod("EnableElement", "ClassPower");
				owner:CallMethod("UpdateAllElements");
			end
		end
	]=],

	-- Called on the party group header
	Party_OnAttribute = [=[
		if (name == "state-vis") then
			if (value == "show") then
				if (not self:IsShown()) then
					self:Show();
				end
			elseif (value == "hide") then
				if (self:IsShown()) then
					self:Hide();
				end
			end
		end
	]=],

	-- Called on the party callback frame
	Party_SecureCallback = [=[
		if name then
			name = string.lower(name);
		end
		if (name == "change-enablepartyframes") then
			self:SetAttribute("enablePartyFrames", value);
			local Owner = self:GetFrameRef("Owner");
			UnregisterAttributeDriver(Owner, "state-vis");
			if (value) then
				local visDriver = self:GetAttribute("visDriver"); -- get the correct visibility driver
				RegisterAttributeDriver(Owner, "state-vis", visDriver);
				Owner:RunAttribute("sortFrames"); -- Update the layout
			else
				RegisterAttributeDriver(Owner, "state-vis", "hide");
			end
		elseif (name == "change-enablehealermode") then

			local Owner = self:GetFrameRef("Owner");

			-- set flag for healer mode
			Owner:SetAttribute("useAlternateLayout", value);

			-- Update the layout
			Owner:RunAttribute("sortFrames");
		end
	]=],

	-- Called on the party frame group header
	Party_SortFrames = [=[
		local useAlternateLayout = self:GetAttribute("useAlternateLayout");

		local anchorPoint;
		local anchorFrame;
		local growthX;
		local growthY;

		if (not useAlternateLayout) then
			anchorPoint = "%s";
			anchorFrame = self;
			growthX = %.0f;
			growthY = %.0f;
		else
			anchorPoint = "%s";
			anchorFrame = self:GetFrameRef("HealerModeAnchor");
			growthX = %.0f;
			growthY = %.0f;
		end

		-- Iterate the frames
		for id,frame in ipairs(Frames) do
			frame:ClearAllPoints();
			frame:SetPoint(anchorPoint, anchorFrame, anchorPoint, growthX*(id-1), growthY*(id-1));
		end

	]=],

	-- Called on the raid frame group header
	Raid_OnAttribute = [=[
		if (name == "state-vis") then
			if (value == "show") then
				if (not self:IsShown()) then
					self:Show();
				end
			elseif (value == "hide") then
				if (self:IsShown()) then
					self:Hide();
				end
			end

		elseif (name == "state-layout") then
			local groupLayout = self:GetAttribute("groupLayout");
			if (groupLayout ~= value) then

				-- Store the new layout setting
				self:SetAttribute("groupLayout", value);

				-- Update the layout
				self:RunAttribute("sortFrames");
			end
		end
	]=],

	-- Called on the secure updater
	Raid_SecureCallback = [=[
		if name then
			name = string.lower(name);
		end
		if (name == "change-enableraidframes") then
			self:SetAttribute("enableRaidFrames", value); -- store the setting

			-- retrieve the raid header frame
			local Owner = self:GetFrameRef("Owner");
			Owner:SetAttribute("enableRaidFrames", value); -- store the setting on the header too

			UnregisterAttributeDriver(Owner, "state-vis"); -- kill off the old visibility driver
			if (value) then
				local visDriver = self:GetAttribute("visDriver"); -- get the correct visibility driver
				RegisterAttributeDriver(Owner, "state-vis", visDriver); -- apply it!
				Owner:RunAttribute("sortFrames"); -- Update the layout
			else
				RegisterAttributeDriver(Owner, "state-vis", "hide");
			end

		elseif (name == "change-enablehealermode") then
			self:SetAttribute("enableHealerMode", value); -- store the setting(?)
			local Owner = self:GetFrameRef("Owner"); -- retrieve the raid header frame
			Owner:SetAttribute("useAlternateLayout", value); -- set flag for healer mode
			Owner:RunAttribute("sortFrames"); -- Update the layout
		end
	]=],

	-- Called on the raid frame group header
	Raid_SortFrames = [=[
		local groupLayout = self:GetAttribute("groupLayout");
		local useAlternateLayout = self:GetAttribute("useAlternateLayout");

		local anchor;
		local colSize;
		local growthX;
		local growthY;
		local growthYHealerMode;
		local groupGrowthX;
		local groupGrowthY;
		local groupGrowthYHealerMode;
		local groupCols;
		local groupRows;
		local groupAnchor;
		local groupAnchorHealerMode;

		if (groupLayout == "normal") then
			colSize = %.0f;
			growthX = %.0f;
			growthY = %.0f;
			growthYHealerMode = %.0f;
			groupGrowthX = %.0f;
			groupGrowthY = %.0f;
			groupGrowthYHealerMode = %.0f;
			groupCols = %.0f;
			groupRows = %.0f;
			groupAnchor = "%s";
			groupAnchorHealerMode = "%s";

		elseif (groupLayout == "epic") then
			colSize = %.0f;
			growthX = %.0f;
			growthY = %.0f;
			growthYHealerMode = %.0f;
			groupGrowthX = %.0f;
			groupGrowthY = %.0f;
			groupGrowthYHealerMode = %.0f;
			groupCols = %.0f;
			groupRows = %.0f;
			groupAnchor = "%s";
			groupAnchorHealerMode = "%s";
		end

		-- This should never happen: it does!
		if (not colSize) then
			return
		end

		if useAlternateLayout then
			anchor = self:GetFrameRef("HealerModeAnchor");
			growthY = growthYHealerMode;
			groupAnchor = groupAnchorHealerMode;
			groupGrowthY = groupGrowthYHealerMode;
		else
			anchor = self;
		end

		-- Iterate the frames
		for id,frame in ipairs(Frames) do

			local groupID = floor((id-1)/colSize) + 1;
			local groupX = mod(groupID-1,groupCols) * groupGrowthX;
			local groupY = floor((groupID-1)/groupCols) * groupGrowthY;

			local modID = mod(id-1,colSize) + 1;
			local unitX = growthX*(modID-1) + groupX;
			local unitY = growthY*(modID-1) + groupY;

			frame:ClearAllPoints();
			frame:SetPoint(groupAnchor, anchor, groupAnchor, unitX, unitY);
		end

	]=]
}

-- Create a secure callback frame our menu system can use
-- to alter unitframe setting while engaged in combat.
-- TODO: Make this globally accessible to the entire addon,
-- and move all these little creation methods away from the modules.
local CreateSecureCallbackFrame = function(module, owner, db, script, ...)

	local OptionsMenu = Core:GetModule("OptionsMenu", true)
	if (not OptionsMenu) then
		return
	end

	local callbackFrame = OptionsMenu:CreateCallbackFrame(module)
	callbackFrame:SetFrameRef("Owner", owner)
	callbackFrame:AssignSettings(db)
	callbackFrame:AssignCallback(script)

	return callbackFrame
end

-----------------------------------------------------------
-- Templates
-----------------------------------------------------------
-- Boss, Pet, ToT
local StyleSmallFrame = function(self, unit, id, layout, ...)

	self.colors = Colors
	self.layout = layout

	self:SetSize(unpack(layout.Size))
	self:SetFrameLevel(self:GetFrameLevel() + layout.FrameLevel)

	if (unit:match("^boss(%d+)")) then
		-- Todo: iterate on this for a grid layout
		local id = tonumber(id)
		if id then
			local place = { unpack(layout.Place) }
			local growthX = layout.GrowthX
			local growthY = layout.GrowthY

			if (growthX and growthY) then
				if (type(place[#place]) == "number") then
					place[#place - 1] = place[#place - 1] + growthX*(id-1)
					place[#place] = place[#place] + growthY*(id-1)
				else
					place[#place + 1] = growthX
					place[#place + 1] = growthY
				end
			end
			self:Place(unpack(place))
		else
			self:Place(unpack(layout.Place))
		end
	else
		self:Place(unpack(layout.Place))
	end

	-- Scaffolds
	-----------------------------------------------------------
	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())

	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 15)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 30)

	-- Health Bar
	-----------------------------------------------------------
	local health = content:CreateStatusBar()
	health:SetOrientation(layout.HealthBarOrientation or "RIGHT")
	health:SetFlippedHorizontally(layout.HealthBarSetFlippedHorizontally)
	health:SetSparkMap(layout.HealthBarSparkMap)
	health:SetStatusBarTexture(layout.HealthBarTexture)
	health:SetSize(unpack(layout.HealthSize))
	health:Place(unpack(layout.HealthPlace))
	health:SetSmoothingMode(layout.HealthSmoothingMode or "bezier-fast-in-slow-out")
	health:SetSmoothingFrequency(layout.HealthSmoothingFrequency or .5)
	health.threatFeedbackUnit = "player"
	health.colorThreat = layout.HealthColorThreat -- color non-friendly by threat
	health.colorTapped = layout.HealthColorTapped  -- color tap denied units
	health.colorDisconnected = layout.HealthColorDisconnected -- color disconnected units
	health.colorClass = layout.HealthColorClass -- color players by class
	health.colorPetAsPlayer = layout.HealthColorPetAsPlayer -- color your pet as you
	health.colorReaction = layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates
	self.Health = health
	self.Health.PostUpdate = layout.HealthBarPostUpdate

	local healthBg = health:CreateTexture()
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	healthBg:SetTexture(layout.HealthBackdropTexture)
	healthBg:SetVertexColor(unpack(layout.HealthBackdropColor))
	self.Health.Bg = healthBg

	-- Health Value
	local healthPerc = health:CreateFontString()
	healthPerc:SetPoint(unpack(layout.HealthPercentPlace))
	healthPerc:SetDrawLayer(unpack(layout.HealthPercentDrawLayer))
	healthPerc:SetJustifyH(layout.HealthPercentJustifyH)
	healthPerc:SetJustifyV(layout.HealthPercentJustifyV)
	healthPerc:SetFontObject(layout.HealthPercentFont)
	healthPerc:SetTextColor(unpack(layout.HealthPercentColor))
	self.Health.ValuePercent = healthPerc

	-- Cast Bar
	-----------------------------------------------------------
	if (layout.CastBarSize) then
		local cast = content:CreateStatusBar()
		cast:SetSize(unpack(layout.CastBarSize))
		cast:SetFrameLevel(health:GetFrameLevel() + 1)
		cast:Place(unpack(layout.CastBarPlace))
		cast:SetOrientation(layout.CastBarOrientation)
		cast:SetSmoothingMode(layout.CastBarSmoothingMode)
		cast:SetSmoothingFrequency(layout.CastBarSmoothingFrequency)
		cast:SetStatusBarColor(unpack(layout.CastBarColor))
		cast:SetStatusBarTexture(layout.CastBarTexture)
		cast:SetSparkMap(layout.CastBarSparkMap)
		self.Cast = cast
		self.Cast.PostUpdate = layout.CastBarPostUpdate

		-- A little hack here. Does it work better? NO!
		local toggleHealthValue = function()
			healthPerc:SetShown((not cast:IsShown()))
		end

		cast:HookScript("OnShow", toggleHealthValue)
		cast:HookScript("OnHide", toggleHealthValue)
	end

	-- Cast Name
	local name = (layout.CastBarNameParent and self[layout.CastBarNameParent] or overlay):CreateFontString()
	name:SetPoint(unpack(layout.CastBarNamePlace))
	name:SetFontObject(layout.CastBarNameFont)
	name:SetDrawLayer(unpack(layout.CastBarNameDrawLayer))
	name:SetJustifyH(layout.CastBarNameJustifyH)
	name:SetJustifyV(layout.CastBarNameJustifyV)
	name:SetTextColor(unpack(layout.CastBarNameColor))
	name:SetSize(unpack(layout.CastBarNameSize))
	self.Cast.Name = name

	-- Target Highlighting
	-----------------------------------------------------------
	local owner = layout.TargetHighlightParent and self[layout.TargetHighlightParent] or self
	local targetHighlightFrame = CreateFrame("Frame", nil, owner)
	targetHighlightFrame:SetAllPoints()
	targetHighlightFrame:SetIgnoreParentAlpha(true)

	local targetHighlight = targetHighlightFrame:CreateTexture()
	targetHighlight:SetDrawLayer(unpack(layout.TargetHighlightDrawLayer))
	targetHighlight:SetSize(unpack(layout.TargetHighlightSize))
	targetHighlight:SetPoint(unpack(layout.TargetHighlightPlace))
	targetHighlight:SetTexture(layout.TargetHighlightTexture)
	targetHighlight.showTarget = layout.TargetHighlightShowTarget
	targetHighlight.colorTarget = layout.TargetHighlightTargetColor
	self.TargetHighlight = targetHighlight

	-- Auras
	-----------------------------------------------------------
	if (layout.AuraProperties) then
		local auras = content:CreateFrame("Frame")
		auras:Place(unpack(layout.AuraFramePlace))
		auras:SetSize(unpack(layout.AuraFrameSize))
		for property,value in pairs(layout.AuraProperties) do
			auras[property] = value
		end
		self.Auras = auras
		self.Auras.PostCreateButton = layout.Aura_PostCreateButton -- post creation styling
		self.Auras.PostUpdateButton = layout.Aura_PostUpdateButton -- post updates when something changes (even timers)
	end

	-- Unit Name
	if layout.NamePlace then
		local name = overlay:CreateFontString()
		name:SetPoint(unpack(layout.NamePlace))
		name:SetDrawLayer(unpack(layout.NameDrawLayer))
		name:SetJustifyH(layout.NameJustifyH)
		name:SetJustifyV(layout.NameJustifyV)
		name:SetFontObject(layout.NameFont)
		name:SetTextColor(unpack(layout.NameColor))
		self.Name = name
	end

	if (unit == "targettarget") and (layout.HideWhenUnitIsPlayer or layout.HideWhenTargetIsCritter or layout.HideWhenUnitIsTarget) then
		self.hideWhenUnitIsPlayer = layout.HideWhenUnitIsPlayer
		self.hideWhenUnitIsTarget = layout.HideWhenUnitIsTarget
		self.hideWhenTargetIsCritter = layout.HideWhenTargetIsCritter
		self.PostUpdate = layout.AlphaPostUpdate,
		self:RegisterEvent("PLAYER_TARGET_CHANGED", layout.AlphaPostUpdate, true)
	end
end

-- Party
local StylePartyFrame = function(self, unit, id, layout, ...)

	self:SetSize(unpack(layout.Size))
	self:SetHitRectInsets(unpack(layout.HitRectInsets))

	-- Assign our own global custom colors
	self.colors = Colors
	self.layout = layout

	-- Scaffolds
	-----------------------------------------------------------
	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())

	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 15)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 30)

	-- Health Bar
	-----------------------------------------------------------
	local health = content:CreateStatusBar()
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:Place(unpack(layout.HealthPlace))
	health:SetSize(unpack(layout.HealthSize))
	health:SetOrientation(layout.HealthBarOrientation or "RIGHT")
	health:SetFlippedHorizontally(layout.HealthBarSetFlippedHorizontally)
	health:SetSparkMap(layout.HealthBarSparkMap)
	health:SetStatusBarTexture(layout.HealthBarTexture)
	health:SetSmartSmoothing(true)
	health.threatFeedbackUnit = "player"
	health.colorThreat = layout.HealthColorThreat -- color non-friendly by threat
	health.colorTapped = layout.HealthColorTapped  -- color tap denied units
	health.colorDisconnected = layout.HealthColorDisconnected -- color disconnected units
	health.colorClass = layout.HealthColorClass -- color players by class
	health.colorPetAsPlayer = layout.HealthColorPetAsPlayer -- color your pet as you
	health.colorReaction = layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates
	self.Health = health
	self.Health.PostUpdate = layout.HealthBarPostUpdate
	self.Health.OverrideValue = layout.HealthValueOverride

	local healthBg = health:CreateTexture()
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	healthBg:SetTexture(layout.HealthBackdropTexture)
	healthBg:SetVertexColor(unpack(layout.HealthBackdropColor))
	self.Health.Bg = healthBg

	-- Health Value
	local healthVal = health:CreateFontString()
	healthVal:SetPoint(unpack(layout.HealthValuePlace))
	healthVal:SetDrawLayer(unpack(layout.HealthValueDrawLayer))
	healthVal:SetJustifyH(layout.HealthValueJustifyH)
	healthVal:SetJustifyV(layout.HealthValueJustifyV)
	healthVal:SetFontObject(layout.HealthValueFont)
	healthVal:SetTextColor(unpack(layout.HealthValueColor))
	healthVal.showPercent = layout.HealthShowPercent
	healthVal.ShowAFK = layout.HealthShowAFK
	self.Health.Value = healthVal

	-- Power
	-----------------------------------------------------------
	local power = content:CreateStatusBar()
	power:SetFrameLevel(power:GetFrameLevel() + 5)
	power:SetSize(unpack(layout.PowerSize))
	power:Place(unpack(layout.PowerPlace))
	power:SetStatusBarTexture(layout.PowerBarTexture)
	power:SetOrientation(layout.PowerBarOrientation)
	power:SetSmoothingMode(layout.PowerBarSmoothingMode)
	power:SetSmoothingFrequency(layout.PowerBarSmoothingFrequency or .5)
	power:SetSparkMap(layout.PowerBarSparkMap)
	power.frequent = true
	power.exclusiveResource = "MANA"
	self.Power = power
	self.Power.PostUpdate = layout.PowerBarPostUpdate

	local powerBg = power:CreateTexture()
	powerBg:SetDrawLayer(unpack(layout.PowerBackgroundDrawLayer))
	powerBg:SetSize(unpack(layout.PowerBackgroundSize))
	powerBg:SetPoint(unpack(layout.PowerBackgroundPlace))
	powerBg:SetTexture(layout.PowerBackgroundTexture)
	powerBg:SetVertexColor(unpack(layout.PowerBackgroundColor))
	self.Power.Bg = powerBg

	-- Range
	-----------------------------------------------------------
	self.Range = { outsideAlpha = layout.RangeOutsideAlpha }

	-- Portrait
	-----------------------------------------------------------
	local portrait = backdrop:CreateFrame("PlayerModel")
	portrait:SetPoint(unpack(layout.PortraitPlace))
	portrait:SetSize(unpack(layout.PortraitSize))
	portrait:SetAlpha(layout.PortraitAlpha)
	portrait.distanceScale = layout.PortraitDistanceScale
	portrait.positionX = layout.PortraitPositionX
	portrait.positionY = layout.PortraitPositionY
	portrait.positionZ = layout.PortraitPositionZ
	portrait.rotation = layout.PortraitRotation -- in degrees
	portrait.showFallback2D = layout.PortraitShowFallback2D -- display 2D portraits when unit is out of range of 3D models
	self.Portrait = portrait

	-- To allow the backdrop and overlay to remain
	-- visible even with no visible player model,
	-- we add them to our backdrop and overlay frames,
	-- not to the portrait frame itself.
	local portraitBg = backdrop:CreateTexture()
	portraitBg:SetPoint(unpack(layout.PortraitBackgroundPlace))
	portraitBg:SetSize(unpack(layout.PortraitBackgroundSize))
	portraitBg:SetTexture(layout.PortraitBackgroundTexture)
	portraitBg:SetDrawLayer(unpack(layout.PortraitBackgroundDrawLayer))
	portraitBg:SetVertexColor(unpack(layout.PortraitBackgroundColor))
	self.Portrait.Bg = portraitBg

	local portraitShade = content:CreateTexture()
	portraitShade:SetPoint(unpack(layout.PortraitShadePlace))
	portraitShade:SetSize(unpack(layout.PortraitShadeSize))
	portraitShade:SetTexture(layout.PortraitShadeTexture)
	portraitShade:SetDrawLayer(unpack(layout.PortraitShadeDrawLayer))
	self.Portrait.Shade = portraitShade

	local portraitFg = content:CreateTexture()
	portraitFg:SetPoint(unpack(layout.PortraitForegroundPlace))
	portraitFg:SetSize(unpack(layout.PortraitForegroundSize))
	portraitFg:SetTexture(layout.PortraitForegroundTexture)
	portraitFg:SetDrawLayer(unpack(layout.PortraitForegroundDrawLayer))
	portraitFg:SetVertexColor(unpack(layout.PortraitForegroundColor))
	self.Portrait.Fg = portraitFg

	-- Cast Bar
	-----------------------------------------------------------
	local cast = content:CreateStatusBar()
	cast:SetSize(unpack(layout.CastBarSize))
	cast:SetFrameLevel(health:GetFrameLevel() + 1)
	cast:Place(unpack(layout.CastBarPlace))
	cast:SetOrientation(layout.CastBarOrientation) -- set the bar to grow towards the right.
	cast:SetSmoothingMode(layout.CastBarSmoothingMode) -- set the smoothing mode.
	cast:SetSmoothingFrequency(layout.CastBarSmoothingFrequency)
	cast:SetStatusBarColor(unpack(layout.CastBarColor)) -- the alpha won't be overwritten.
	cast:SetStatusBarTexture(layout.CastBarTexture)
	cast:SetSparkMap(layout.CastBarSparkMap) -- set the map the spark follows along the bar.
	self.Cast = cast
	self.Cast.PostUpdate = layout.CastBarPostUpdate

	-- Auras
	-----------------------------------------------------------
	local auras = content:CreateFrame("Frame")
	auras:Place(unpack(layout.AuraFramePlace))
	auras:SetSize(unpack(layout.AuraFrameSize))
	for property,value in pairs(layout.AuraProperties) do
		auras[property] = value
	end
	self.Auras = auras
	self.Auras.PostCreateButton = layout.Aura_PostCreateButton -- post creation styling
	self.Auras.PostUpdateButton = layout.Aura_PostUpdateButton -- post updates when something changes (even timers)

	-- Target Highlighting
	-----------------------------------------------------------
	local targetHighlightFrame = CreateFrame("Frame", nil, layout.TargetHighlightParent and self[layout.TargetHighlightParent] or self)
	targetHighlightFrame:SetAllPoints()
	targetHighlightFrame:SetIgnoreParentAlpha(true)

	local targetHighlight = targetHighlightFrame:CreateTexture()
	targetHighlight:SetDrawLayer(unpack(layout.TargetHighlightDrawLayer))
	targetHighlight:SetSize(unpack(layout.TargetHighlightSize))
	targetHighlight:SetPoint(unpack(layout.TargetHighlightPlace))
	targetHighlight:SetTexture(layout.TargetHighlightTexture)
	targetHighlight.showTarget = layout.TargetHighlightShowTarget
	targetHighlight.colorTarget = layout.TargetHighlightTargetColor
	self.TargetHighlight = targetHighlight

	-- Group Role
	-----------------------------------------------------------
	if layout.UseGroupRole then
		local groupRole = overlay:CreateFrame()
		groupRole:SetPoint(unpack(layout.GroupRolePlace))
		groupRole:SetSize(unpack(layout.GroupRoleSize))
		self.GroupRole = groupRole

		if layout.UseGroupRoleBackground then
			local groupRoleBg = groupRole:CreateTexture()
			groupRoleBg:SetDrawLayer(unpack(layout.GroupRoleBackgroundDrawLayer))
			groupRoleBg:SetTexture(layout.GroupRoleBackgroundTexture)
			groupRoleBg:SetVertexColor(unpack(layout.GroupRoleBackgroundColor))
			groupRoleBg:SetSize(unpack(layout.GroupRoleBackgroundSize))
			groupRoleBg:SetPoint(unpack(layout.GroupRoleBackgroundPlace))
			self.GroupRole.Bg = groupRoleBg
		end

		if layout.UseGroupRoleHealer then
			local roleHealer = groupRole:CreateTexture()
			roleHealer:SetPoint(unpack(layout.GroupRoleHealerPlace))
			roleHealer:SetSize(unpack(layout.GroupRoleHealerSize))
			roleHealer:SetDrawLayer(unpack(layout.GroupRoleHealerDrawLayer))
			roleHealer:SetTexture(layout.GroupRoleHealerTexture)
			self.GroupRole.Healer = roleHealer
		end

		if layout.UseGroupRoleTank then
			local roleTank = groupRole:CreateTexture()
			roleTank:SetPoint(unpack(layout.GroupRoleTankPlace))
			roleTank:SetSize(unpack(layout.GroupRoleTankSize))
			roleTank:SetDrawLayer(unpack(layout.GroupRoleTankDrawLayer))
			roleTank:SetTexture(layout.GroupRoleTankTexture)
			self.GroupRole.Tank = roleTank
		end

		if layout.UseGroupRoleDPS then
			local roleDPS = groupRole:CreateTexture()
			roleDPS:SetPoint(unpack(layout.GroupRoleDPSPlace))
			roleDPS:SetSize(unpack(layout.GroupRoleDPSSize))
			roleDPS:SetDrawLayer(unpack(layout.GroupRoleDPSDrawLayer))
			roleDPS:SetTexture(layout.GroupRoleDPSTexture)
			self.GroupRole.Damager = roleDPS
		end
	end

	-- Group Debuff (#1)
	-----------------------------------------------------------
	local groupAura = overlay:CreateFrame("Button")
	groupAura:SetFrameLevel(overlay:GetFrameLevel() - 4)
	groupAura:SetPoint(unpack(layout.GroupAuraPlace))
	groupAura:SetSize(unpack(layout.GroupAuraSize))
	groupAura.disableMouse = layout.GroupAuraButtonDisableMouse
	groupAura.tooltipDefaultPosition = layout.GroupAuraTooltipDefaultPosition
	groupAura.tooltipPoint = layout.GroupAuraTooltipPoint
	groupAura.tooltipAnchor = layout.GroupAuraTooltipAnchor
	groupAura.tooltipRelPoint = layout.GroupAuraTooltipRelPoint
	groupAura.tooltipOffsetX = layout.GroupAuraTooltipOffsetX
	groupAura.tooltipOffsetY = layout.GroupAuraTooltipOffsetY

	local groupAuraIcon = groupAura:CreateTexture()
	groupAuraIcon:SetPoint(unpack(layout.GroupAuraButtonIconPlace))
	groupAuraIcon:SetSize(unpack(layout.GroupAuraButtonIconSize))
	groupAuraIcon:SetTexCoord(unpack(layout.GroupAuraButtonIconTexCoord))
	groupAuraIcon:SetDrawLayer("ARTWORK", 1)
	groupAura.Icon = groupAuraIcon

	-- Frame to contain art overlays, texts, etc
	local groupAuraOverlay = groupAura:CreateFrame("Frame")
	groupAuraOverlay:SetFrameLevel(groupAura:GetFrameLevel() + 3)
	groupAuraOverlay:SetAllPoints(groupAura)
	groupAura.Overlay = groupAuraOverlay

	-- Cooldown frame
	local groupAuraCooldown = groupAura:CreateFrame("Cooldown", nil, "CooldownFrameTemplate")
	groupAuraCooldown:Hide()
	groupAuraCooldown:SetAllPoints(groupAura)
	groupAuraCooldown:SetFrameLevel(groupAura:GetFrameLevel() + 1)
	groupAuraCooldown:SetReverse(false)
	groupAuraCooldown:SetSwipeColor(0, 0, 0, .75)
	groupAuraCooldown:SetBlingTexture(BLING_TEXTURE, .3, .6, 1, .75)
	groupAuraCooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
	groupAuraCooldown:SetDrawSwipe(true)
	groupAuraCooldown:SetDrawBling(true)
	groupAuraCooldown:SetDrawEdge(false)
	groupAuraCooldown:SetHideCountdownNumbers(true)
	groupAura.Cooldown = groupAuraCooldown

	local groupAuraTime = overlay:CreateFontString()
	groupAuraTime:SetDrawLayer("ARTWORK", 1)
	groupAuraTime:SetPoint(unpack(layout.GroupAuraButtonTimePlace))
	groupAuraTime:SetFontObject(layout.GroupAuraButtonTimeFont)
	groupAuraTime:SetJustifyH("CENTER")
	groupAuraTime:SetJustifyV("MIDDLE")
	groupAuraTime:SetTextColor(unpack(layout.GroupAuraButtonTimeColor))
	groupAura.Time = groupAuraTime

	local groupAuraCount = overlay:CreateFontString()
	groupAuraCount:SetDrawLayer("OVERLAY", 1)
	groupAuraCount:SetPoint(unpack(layout.GroupAuraButtonCountPlace))
	groupAuraCount:SetFontObject(layout.GroupAuraButtonCountFont)
	groupAuraCount:SetJustifyH("CENTER")
	groupAuraCount:SetJustifyV("MIDDLE")
	groupAuraCount:SetTextColor(unpack(layout.GroupAuraButtonCountColor))
	groupAura.Count = groupAuraCount

	local groupAuraBorder = groupAura:CreateFrame("Frame")
	groupAuraBorder:SetFrameLevel(groupAura:GetFrameLevel() + 2)
	groupAuraBorder:SetPoint(unpack(layout.GroupAuraButtonBorderFramePlace))
	groupAuraBorder:SetSize(unpack(layout.GroupAuraButtonBorderFrameSize))
	groupAuraBorder:SetBackdrop(layout.GroupAuraButtonBorderBackdrop)
	groupAuraBorder:SetBackdropColor(unpack(layout.GroupAuraButtonBorderBackdropColor))
	groupAuraBorder:SetBackdropBorderColor(unpack(layout.GroupAuraButtonBorderBackdropBorderColor))
	groupAura.Border = groupAuraBorder

	self.GroupAura = groupAura
	self.GroupAura.PostUpdate = layout.GroupAuraPostUpdate

	-- Ready Check (#2)
	-----------------------------------------------------------
	local readyCheck = overlay:CreateTexture()
	readyCheck:SetPoint(unpack(layout.ReadyCheckPlace))
	readyCheck:SetSize(unpack(layout.ReadyCheckSize))
	readyCheck:SetDrawLayer(unpack(layout.ReadyCheckDrawLayer))
	self.ReadyCheck = readyCheck
	self.ReadyCheck.PostUpdate = layout.ReadyCheckPostUpdate

	-- Resurrection Indicator (#3)
	-----------------------------------------------------------
	local rezIndicator = overlay:CreateTexture()
	rezIndicator:SetPoint(unpack(layout.ResurrectIndicatorPlace))
	rezIndicator:SetSize(unpack(layout.ResurrectIndicatorSize))
	rezIndicator:SetDrawLayer(unpack(layout.ResurrectIndicatorDrawLayer))
	self.ResurrectIndicator = rezIndicator
	self.ResurrectIndicator.PostUpdate = layout.ResurrectIndicatorPostUpdate

	-- Unit Status (#4)
	-----------------------------------------------------------
	local unitStatus = overlay:CreateFontString()
	unitStatus:SetPoint(unpack(layout.UnitStatusPlace))
	unitStatus:SetDrawLayer(unpack(layout.UnitStatusDrawLayer))
	unitStatus:SetJustifyH(layout.UnitStatusJustifyH)
	unitStatus:SetJustifyV(layout.UnitStatusJustifyV)
	unitStatus:SetFontObject(layout.UnitStatusFont)
	unitStatus:SetTextColor(unpack(layout.UnitStatusColor))
	unitStatus.hideAFK = layout.UnitStatusHideAFK
	unitStatus.hideDead = layout.UnitStatusHideDead
	unitStatus.hideOffline = layout.UnitStatusHideOffline
	unitStatus.afkMsg = layout.UseUnitStatusMessageAFK
	unitStatus.deadMsg = layout.UseUnitStatusMessageDead
	unitStatus.offlineMsg = layout.UseUnitStatusMessageDC
	unitStatus.oomMsg = layout.UseUnitStatusMessageOOM
	self.UnitStatus = unitStatus
	self.UnitStatus.PostUpdate = layout.UnitStatusPostUpdate

end

-- Raid
local StyleRaidFrame = function(self, unit, id, layout, ...)

	self.layout = layout
	self.colors = Colors
	self:SetSize(unpack(layout.Size))
	self:SetHitRectInsets(unpack(layout.HitRectInsets))

	-- Scaffolds
	-----------------------------------------------------------
	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())

	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 10)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)

	-- Health Bar
	-----------------------------------------------------------
	local health = content:CreateStatusBar()
	health:SetOrientation(layout.HealthBarOrientation or "RIGHT")
	health:SetFlippedHorizontally(layout.HealthBarSetFlippedHorizontally)
	health:SetSparkMap(layout.HealthBarSparkMap) -- set the map the spark follows along the bar.
	health:SetStatusBarTexture(layout.HealthBarTexture)
	health:SetSize(unpack(layout.HealthSize))
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:Place(unpack(layout.HealthPlace))
	health:SetSmartSmoothing(true)
	health.threatFeedbackUnit = "player"
	health.colorThreat = layout.HealthColorThreat -- color non-friendly by threat
	health.colorTapped = layout.HealthColorTapped  -- color tap denied units
	health.colorDisconnected = layout.HealthColorDisconnected -- color disconnected units
	health.colorClass = layout.HealthColorClass -- color players by class
	health.colorPetAsPlayer = layout.HealthColorPetAsPlayer -- color your pet as you
	health.colorReaction = layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates
	self.Health = health
	self.Health.PostUpdate = layout.HealthBarPostUpdate

	local healthBg = health:CreateTexture()
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	healthBg:SetTexture(layout.HealthBackdropTexture)
	healthBg:SetVertexColor(unpack(layout.HealthBackdropColor))
	self.Health.Bg = healthBg

	-- Power
	-----------------------------------------------------------
	local power = overlay:CreateStatusBar()
	power:SetSize(unpack(layout.PowerSize))
	power:Place(unpack(layout.PowerPlace))
	power:SetStatusBarTexture(layout.PowerBarTexture)
	power:SetOrientation(layout.PowerBarOrientation)
	power:SetSmoothingMode(layout.PowerBarSmoothingMode)
	power:SetSmoothingFrequency(layout.PowerBarSmoothingFrequency or .5)
	power:SetSparkMap(layout.PowerBarSparkMap)
	power.frequent = true
	power.exclusiveResource = "MANA"
	self.Power = power
	self.Power.PostUpdate = layout.PowerBarPostUpdate

	local powerBg = power:CreateTexture()
	powerBg:SetDrawLayer(unpack(layout.PowerBackgroundDrawLayer))
	powerBg:SetSize(unpack(layout.PowerBackgroundSize))
	powerBg:SetPoint(unpack(layout.PowerBackgroundPlace))
	powerBg:SetTexture(layout.PowerBackgroundTexture)
	powerBg:SetVertexColor(unpack(layout.PowerBackgroundColor))
	self.Power.Bg = powerBg

	-- Cast Bar
	-----------------------------------------------------------
	local cast = content:CreateStatusBar()
	cast:SetSize(unpack(layout.CastBarSize))
	cast:SetFrameLevel(health:GetFrameLevel() + 1)
	cast:Place(unpack(layout.CastBarPlace))
	cast:SetOrientation(layout.CastBarOrientation) -- set the bar to grow towards the right.
	cast:SetSmoothingMode(layout.CastBarSmoothingMode) -- set the smoothing mode.
	cast:SetSmoothingFrequency(layout.CastBarSmoothingFrequency)
	cast:SetStatusBarColor(unpack(layout.CastBarColor)) -- the alpha won't be overwritten.
	cast:SetStatusBarTexture(layout.CastBarTexture)
	cast:SetSparkMap(layout.CastBarSparkMap) -- set the map the spark follows along the bar.
	self.Cast = cast
	self.Cast.PostUpdate = layout.CastBarPostUpdate

	-- Range
	-----------------------------------------------------------
	self.Range = { outsideAlpha = layout.RangeOutsideAlpha }

	-- Target Highlighting
	-----------------------------------------------------------
	local targetHighlightFrame = CreateFrame("Frame", nil, layout.TargetHighlightParent and self[layout.TargetHighlightParent] or self)
	targetHighlightFrame:SetAllPoints()
	targetHighlightFrame:SetIgnoreParentAlpha(true)

	local targetHighlight = targetHighlightFrame:CreateTexture()
	targetHighlight:SetDrawLayer(unpack(layout.TargetHighlightDrawLayer))
	targetHighlight:SetSize(unpack(layout.TargetHighlightSize))
	targetHighlight:SetPoint(unpack(layout.TargetHighlightPlace))
	targetHighlight:SetTexture(layout.TargetHighlightTexture)
	targetHighlight.showTarget = layout.TargetHighlightShowTarget
	targetHighlight.colorTarget = layout.TargetHighlightTargetColor
	self.TargetHighlight = targetHighlight

	-- Unit Name
	local name = overlay:CreateFontString()
	name:SetPoint(unpack(layout.NamePlace))
	name:SetDrawLayer(unpack(layout.NameDrawLayer))
	name:SetJustifyH(layout.NameJustifyH)
	name:SetJustifyV(layout.NameJustifyV)
	name:SetFontObject(layout.NameFont)
	name:SetTextColor(unpack(layout.NameColor))
	name.maxChars = layout.NameMaxChars
	name.useDots = layout.NameUseDots
	self.Name = name

	-- Raid Role
	local raidRole = overlay:CreateTexture()
	raidRole:SetPoint(layout.RaidRolePoint, self[layout.RaidRoleAnchor], unpack(layout.RaidRolePlace))
	raidRole:SetSize(unpack(layout.RaidRoleSize))
	raidRole:SetDrawLayer(unpack(layout.RaidRoleDrawLayer))
	raidRole.roleTextures = { RAIDTARGET = layout.RaidRoleRaidTargetTexture }
	self.RaidRole = raidRole

	-- Group Number
	local groupNumber = overlay:CreateFontString()
	groupNumber:SetPoint(unpack(layout.GroupNumberPlace))
	groupNumber:SetDrawLayer(unpack(layout.GroupNumberDrawLayer))
	groupNumber:SetJustifyH(layout.GroupNumberJustifyH)
	groupNumber:SetJustifyV(layout.GroupNumberJustifyV)
	groupNumber:SetFontObject(layout.GroupNumberFont)
	groupNumber:SetTextColor(unpack(layout.GroupNumberColor))
	self.GroupNumber = groupNumber

		-- Group Role
	-----------------------------------------------------------
	if layout.UseGroupRole then
		local groupRole = overlay:CreateFrame()
		groupRole:SetPoint(unpack(layout.GroupRolePlace))
		groupRole:SetSize(unpack(layout.GroupRoleSize))
		self.GroupRole = groupRole
		self.GroupRole.PostUpdate = layout.GroupRolePostUpdate

		if layout.UseGroupRoleBackground then
			local groupRoleBg = groupRole:CreateTexture()
			groupRoleBg:SetDrawLayer(unpack(layout.GroupRoleBackgroundDrawLayer))
			groupRoleBg:SetTexture(layout.GroupRoleBackgroundTexture)
			groupRoleBg:SetVertexColor(unpack(layout.GroupRoleBackgroundColor))
			groupRoleBg:SetSize(unpack(layout.GroupRoleBackgroundSize))
			groupRoleBg:SetPoint(unpack(layout.GroupRoleBackgroundPlace))
			self.GroupRole.Bg = groupRoleBg
		end

		if layout.UseGroupRoleHealer then
			local roleHealer = groupRole:CreateTexture()
			roleHealer:SetPoint(unpack(layout.GroupRoleHealerPlace))
			roleHealer:SetSize(unpack(layout.GroupRoleHealerSize))
			roleHealer:SetDrawLayer(unpack(layout.GroupRoleHealerDrawLayer))
			roleHealer:SetTexture(layout.GroupRoleHealerTexture)
			self.GroupRole.Healer = roleHealer
		end

		if layout.UseGroupRoleTank then
			local roleTank = groupRole:CreateTexture()
			roleTank:SetPoint(unpack(layout.GroupRoleTankPlace))
			roleTank:SetSize(unpack(layout.GroupRoleTankSize))
			roleTank:SetDrawLayer(unpack(layout.GroupRoleTankDrawLayer))
			roleTank:SetTexture(layout.GroupRoleTankTexture)
			self.GroupRole.Tank = roleTank
		end

		if layout.UseGroupRoleDPS then
			local roleDPS = groupRole:CreateTexture()
			roleDPS:SetPoint(unpack(layout.GroupRoleDPSPlace))
			roleDPS:SetSize(unpack(layout.GroupRoleDPSSize))
			roleDPS:SetDrawLayer(unpack(layout.GroupRoleDPSDrawLayer))
			roleDPS:SetTexture(layout.GroupRoleDPSTexture)
			self.GroupRole.Damager = roleDPS
		end
	end

	-- Group Debuff (#1)
	-----------------------------------------------------------
	local groupAura = overlay:CreateFrame("Button")
	groupAura:SetIgnoreParentAlpha(true)
	groupAura:SetFrameLevel(overlay:GetFrameLevel() + 1)
	groupAura:SetPoint(unpack(layout.GroupAuraPlace))
	groupAura:SetSize(unpack(layout.GroupAuraSize))
	groupAura.disableMouse = layout.GroupAuraButtonDisableMouse
	groupAura.tooltipDefaultPosition = layout.GroupAuraTooltipDefaultPosition
	groupAura.tooltipPoint = layout.GroupAuraTooltipPoint
	groupAura.tooltipAnchor = layout.GroupAuraTooltipAnchor
	groupAura.tooltipRelPoint = layout.GroupAuraTooltipRelPoint
	groupAura.tooltipOffsetX = layout.GroupAuraTooltipOffsetX
	groupAura.tooltipOffsetY = layout.GroupAuraTooltipOffsetY

	local groupAuraIcon = groupAura:CreateTexture()
	groupAuraIcon:SetPoint(unpack(layout.GroupAuraButtonIconPlace))
	groupAuraIcon:SetSize(unpack(layout.GroupAuraButtonIconSize))
	groupAuraIcon:SetTexCoord(unpack(layout.GroupAuraButtonIconTexCoord))
	groupAuraIcon:SetDrawLayer("ARTWORK", 1)
	groupAura.Icon = groupAuraIcon

	-- Frame to contain art overlays, texts, etc
	local groupAuraOverlay = groupAura:CreateFrame("Frame")
	groupAuraOverlay:SetFrameLevel(groupAura:GetFrameLevel() + 3)
	groupAuraOverlay:SetAllPoints(groupAura)
	groupAura.Overlay = groupAuraOverlay

	-- Cooldown frame
	local groupAuraCooldown = groupAura:CreateFrame("Cooldown", nil, "CooldownFrameTemplate")
	groupAuraCooldown:Hide()
	groupAuraCooldown:SetAllPoints(groupAura)
	groupAuraCooldown:SetFrameLevel(groupAura:GetFrameLevel() + 1)
	groupAuraCooldown:SetReverse(false)
	groupAuraCooldown:SetSwipeColor(0, 0, 0, .75)
	groupAuraCooldown:SetBlingTexture(BLING_TEXTURE, .3, .6, 1, .75)
	groupAuraCooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
	groupAuraCooldown:SetDrawSwipe(true)
	groupAuraCooldown:SetDrawBling(true)
	groupAuraCooldown:SetDrawEdge(false)
	groupAuraCooldown:SetHideCountdownNumbers(true)
	groupAura.Cooldown = groupAuraCooldown

	local groupAuraTime = overlay:CreateFontString()
	groupAuraTime:SetDrawLayer("ARTWORK", 1)
	groupAuraTime:SetPoint(unpack(layout.GroupAuraButtonTimePlace))
	groupAuraTime:SetFontObject(layout.GroupAuraButtonTimeFont)
	groupAuraTime:SetJustifyH("CENTER")
	groupAuraTime:SetJustifyV("MIDDLE")
	groupAuraTime:SetTextColor(unpack(layout.GroupAuraButtonTimeColor))
	groupAura.Time = groupAuraTime

	local groupAuraCount = overlay:CreateFontString()
	groupAuraCount:SetDrawLayer("OVERLAY", 1)
	groupAuraCount:SetPoint(unpack(layout.GroupAuraButtonCountPlace))
	groupAuraCount:SetFontObject(layout.GroupAuraButtonCountFont)
	groupAuraCount:SetJustifyH("CENTER")
	groupAuraCount:SetJustifyV("MIDDLE")
	groupAuraCount:SetTextColor(unpack(layout.GroupAuraButtonCountColor))
	groupAura.Count = groupAuraCount

	local groupAuraBorder = groupAura:CreateFrame("Frame")
	groupAuraBorder:SetFrameLevel(groupAura:GetFrameLevel() + 2)
	groupAuraBorder:SetPoint(unpack(layout.GroupAuraButtonBorderFramePlace))
	groupAuraBorder:SetSize(unpack(layout.GroupAuraButtonBorderFrameSize))
	groupAuraBorder:SetBackdrop(layout.GroupAuraButtonBorderBackdrop)
	groupAuraBorder:SetBackdropColor(unpack(layout.GroupAuraButtonBorderBackdropColor))
	groupAuraBorder:SetBackdropBorderColor(unpack(layout.GroupAuraButtonBorderBackdropBorderColor))
	groupAura.Border = groupAuraBorder
	self.GroupAura = groupAura
	self.GroupAura.PostUpdate = layout.GroupAuraPostUpdate

	-- Ready Check (#2)
	-----------------------------------------------------------
	local readyCheck = overlay:CreateTexture()
	readyCheck:SetPoint(unpack(layout.ReadyCheckPlace))
	readyCheck:SetSize(unpack(layout.ReadyCheckSize))
	readyCheck:SetDrawLayer(unpack(layout.ReadyCheckDrawLayer))
	self.ReadyCheck = readyCheck
	self.ReadyCheck.PostUpdate = layout.ReadyCheckPostUpdate

	-- Resurrection Indicator (#3)
	-----------------------------------------------------------
	local rezIndicator = overlay:CreateTexture()
	rezIndicator:SetPoint(unpack(layout.ResurrectIndicatorPlace))
	rezIndicator:SetSize(unpack(layout.ResurrectIndicatorSize))
	rezIndicator:SetDrawLayer(unpack(layout.ResurrectIndicatorDrawLayer))
	self.ResurrectIndicator = rezIndicator
	self.ResurrectIndicator.PostUpdate = layout.ResurrectIndicatorPostUpdate

	-- Unit Status (#4)
	local unitStatus = overlay:CreateFontString()
	unitStatus:SetPoint(unpack(layout.UnitStatusPlace))
	unitStatus:SetDrawLayer(unpack(layout.UnitStatusDrawLayer))
	unitStatus:SetJustifyH(layout.UnitStatusJustifyH)
	unitStatus:SetJustifyV(layout.UnitStatusJustifyV)
	unitStatus:SetFontObject(layout.UnitStatusFont)
	unitStatus:SetTextColor(unpack(layout.UnitStatusColor))
	unitStatus.hideAFK = layout.UnitStatusHideAFK
	unitStatus.hideDead = layout.UnitStatusHideDead
	unitStatus.hideOffline = layout.UnitStatusHideOffline
	unitStatus.afkMsg = layout.UseUnitStatusMessageAFK
	unitStatus.deadMsg = layout.UseUnitStatusMessageDead
	unitStatus.offlineMsg = layout.UseUnitStatusMessageDC
	unitStatus.oomMsg = layout.UseUnitStatusMessageOOM
	self.UnitStatus = unitStatus
	self.UnitStatus.PostUpdate = layout.UnitStatusPostUpdate

end

-----------------------------------------------------------
-- Singular Unit Styling
-----------------------------------------------------------
UnitStyles.StylePlayerFrame = function(self, unit, id, layout, ...)

	-- Frame
	-----------------------------------------------------------
	self.colors = Colors
	self.layout = layout
	self:SetSize(unpack(layout.Size))
	self:Place(unpack(layout.Place))
	self:SetHitRectInsets(unpack(layout.HitRectInsets))

	local topOffset, bottomOffset, leftOffset, rightOffset = unpack(layout.ExplorerHitRects)

	self.GetExplorerHitRects = function(self)
		return topOffset, bottomOffset, leftOffset, rightOffset
	end

	-- Scaffolds
	-----------------------------------------------------------
	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())

	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 10)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)

	-- Health Bar
	-----------------------------------------------------------
	local health = content:CreateStatusBar()
	health:SetOrientation(layout.HealthBarOrientation or "RIGHT")
	health:SetSparkMap(layout.HealthBarSparkMap)
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:Place(unpack(layout.HealthPlace))
	health:SetSmartSmoothing(true)
	health.colorThreat = layout.HealthColorThreat -- color non-friendly by threat
	health.colorTapped = layout.HealthColorTapped  -- color tap denied units
	health.colorDisconnected = layout.HealthColorDisconnected -- color disconnected units
	health.colorClass = layout.HealthColorClass -- color players by class
	health.colorReaction = layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates
	health.predictThreshold = .01
	self.Health = health
	self.Health.PostUpdate = layout.CastBarPostUpdate

	local healthBgHolder = health:CreateFrame("Frame")
	healthBgHolder:SetAllPoints()
	healthBgHolder:SetFrameLevel(health:GetFrameLevel()-2)

	local healthBg = healthBgHolder:CreateTexture()
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	self.Health.Bg = healthBg

	-- Health Value
	local healthValHolder = overlay:CreateFrame("Frame")
	healthValHolder:SetAllPoints(health)

	local healthVal = healthValHolder:CreateFontString()
	healthVal:SetPoint(unpack(layout.HealthValuePlace))
	healthVal:SetDrawLayer(unpack(layout.HealthValueDrawLayer))
	healthVal:SetJustifyH(layout.HealthValueJustifyH)
	healthVal:SetJustifyV(layout.HealthValueJustifyV)
	healthVal:SetFontObject(layout.HealthValueFont)
	healthVal:SetTextColor(unpack(layout.HealthValueColor))
	self.Health.Value = healthVal

	if (IsRetail) then
		local absorbVal = overlay:CreateFontString()
		if layout.HealthAbsorbValuePlaceFunction then
			absorbVal:SetPoint(layout.HealthAbsorbValuePlaceFunction(self))
		else
			absorbVal:SetPoint(unpack(layout.HealthAbsorbValuePlace))
		end
		absorbVal:SetDrawLayer(unpack(layout.HealthAbsorbValueDrawLayer))
		absorbVal:SetJustifyH(layout.HealthAbsorbValueJustifyH)
		absorbVal:SetJustifyV(layout.HealthAbsorbValueJustifyV)
		absorbVal:SetFontObject(layout.HealthAbsorbValueFont)
		absorbVal:SetTextColor(unpack(layout.HealthAbsorbValueColor))
		self.Health.ValueAbsorb = absorbVal
	end

	-- Combat Feedback
	-----------------------------------------------------------
	local feedback = overlay:CreateFrame("Frame")
	feedback:SetAllPoints(health)
	feedback:Hide()

	local feedbackText = feedback:CreateFontString()
	feedbackText:SetJustifyH(layout.CombatFeedbackJustifyH)
	feedbackText:SetJustifyV(layout.CombatFeedbackJustifyV)
	feedbackText:SetPoint(unpack(layout.CombatFeedbackPlace))
	feedbackText:SetFontObject(layout.CombatFeedbackFont)
	feedbackText.feedbackFont = layout.CombatFeedbackFont
	feedbackText.feedbackFontLarge = layout.CombatFeedbackFontLarge
	feedbackText.feedbackFontSmall = layout.CombatFeedbackFontSmall

	self.CombatFeedback = feedback
	self.CombatFeedback.feedbackText = feedbackText


	-- Power
	-----------------------------------------------------------
	local power = backdrop:CreateStatusBar()
	power:SetSize(unpack(layout.PowerSize))
	power:Place(unpack(layout.PowerPlace))
	power:SetStatusBarTexture(layout.PowerBarTexture)
	power:SetTexCoord(unpack(layout.PowerBarTexCoord))
	power:SetOrientation(layout.PowerBarOrientation or "RIGHT") -- set the bar to grow towards the top.
	power:SetSmoothingMode(layout.PowerBarSmoothingMode) -- set the smoothing mode.
	power:SetSmoothingFrequency(layout.PowerBarSmoothingFrequency or .5) -- set the duration of the smoothing.
	power:SetSparkMap(layout.PowerBarSparkMap) -- set the map the spark follows along the bar.
	power.frequent = true
	power.ignoredResource = layout.PowerIgnoredResource -- make the bar hide when MANA is the primary resource.
	self.Power = power
	self.Power.OverrideColor = layout.PowerOverrideColor

	local powerBg = power:CreateTexture()
	powerBg:SetDrawLayer(unpack(layout.PowerBackgroundDrawLayer))
	powerBg:SetSize(unpack(layout.PowerBackgroundSize))
	powerBg:SetPoint(unpack(layout.PowerBackgroundPlace))
	powerBg:SetTexture(layout.PowerBackgroundTexture)
	powerBg:SetVertexColor(unpack(layout.PowerBackgroundColor))
	self.Power.Bg = powerBg

	local powerFg = power:CreateTexture()
	powerFg:SetSize(unpack(layout.PowerForegroundSize))
	powerFg:SetPoint(unpack(layout.PowerForegroundPlace))
	powerFg:SetDrawLayer(unpack(layout.PowerForegroundDrawLayer))
	powerFg:SetTexture(layout.PowerForegroundTexture)
	self.Power.Fg = powerFg

	-- Power Value
	local powerVal = self.Power:CreateFontString()
	powerVal:SetPoint(unpack(layout.PowerValuePlace))
	powerVal:SetDrawLayer(unpack(layout.PowerValueDrawLayer))
	powerVal:SetJustifyH(layout.PowerValueJustifyH)
	powerVal:SetJustifyV(layout.PowerValueJustifyV)
	powerVal:SetFontObject(layout.PowerValueFont)
	powerVal:SetTextColor(unpack(layout.PowerValueColor))
	self.Power.Value = powerVal

	if (IsWinterVeil) then
		local winterVeilPower = power:CreateTexture()
		winterVeilPower:SetSize(unpack(layout.WinterVeilPowerSize))
		winterVeilPower:SetPoint(unpack(layout.WinterVeilPowerPlace))
		winterVeilPower:SetDrawLayer(unpack(layout.WinterVeilPowerDrawLayer))
		winterVeilPower:SetTexture(layout.WinterVeilPowerTexture)
		winterVeilPower:SetVertexColor(unpack(layout.WinterVeilPowerColor))
		self.Power.WinterVeil = winterVeilPower
	end

	-- Mana Orb
	-----------------------------------------------------------
	local extraPower = backdrop:CreateOrb()
	extraPower:SetStatusBarTexture(unpack(layout.ManaOrbTextures))
	extraPower:Place(unpack(layout.ManaPlace))
	extraPower:SetSize(unpack(layout.ManaSize))
	extraPower.frequent = true
	extraPower.exclusiveResource = layout.ManaExclusiveResource or "MANA"
	self.ExtraPower = extraPower
	self.ExtraPower.OverrideColor = layout.ManaOverridePowerColor

	local extraPowerBg = extraPower:CreateBackdropTexture()
	extraPowerBg:SetPoint(unpack(layout.ManaBackgroundPlace))
	extraPowerBg:SetSize(unpack(layout.ManaBackgroundSize))
	extraPowerBg:SetTexture(layout.ManaBackgroundTexture)
	extraPowerBg:SetDrawLayer(unpack(layout.ManaBackgroundDrawLayer))
	extraPowerBg:SetVertexColor(unpack(layout.ManaBackgroundColor))
	self.ExtraPower.bg = extraPowerBg

	local extraPowerShade = extraPower:CreateTexture()
	extraPowerShade:SetPoint(unpack(layout.ManaShadePlace))
	extraPowerShade:SetSize(unpack(layout.ManaShadeSize))
	extraPowerShade:SetTexture(layout.ManaShadeTexture)
	extraPowerShade:SetDrawLayer(unpack(layout.ManaShadeDrawLayer))
	extraPowerShade:SetVertexColor(unpack(layout.ManaShadeColor))
	self.ExtraPower.Shade = extraPowerShade

	local extraPowerFg = extraPower:CreateTexture()
	extraPowerFg:SetPoint(unpack(layout.ManaForegroundPlace))
	extraPowerFg:SetSize(unpack(layout.ManaForegroundSize))
	extraPowerFg:SetDrawLayer(unpack(layout.ManaForegroundDrawLayer))
	self.ExtraPower.Fg = extraPowerFg

	-- Mana Value
	local extraPowerVal = self.ExtraPower:CreateFontString()
	extraPowerVal:SetPoint(unpack(layout.ManaValuePlace))
	extraPowerVal:SetDrawLayer(unpack(layout.ManaValueDrawLayer))
	extraPowerVal:SetJustifyH(layout.ManaValueJustifyH)
	extraPowerVal:SetJustifyV(layout.ManaValueJustifyV)
	extraPowerVal:SetFontObject(layout.ManaValueFont)
	extraPowerVal:SetTextColor(unpack(layout.ManaValueColor))
	self.ExtraPower.Value = extraPowerVal

	if (IsWinterVeil) then
		local winterVeilMana = extraPower:CreateTexture()
		winterVeilMana:SetSize(unpack(layout.WinterVeilManaSize))
		winterVeilMana:SetPoint(unpack(layout.WinterVeilManaPlace))
		winterVeilMana:SetDrawLayer(unpack(layout.WinterVeilManaDrawLayer))
		winterVeilMana:SetTexture(layout.WinterVeilManaTexture)
		winterVeilMana:SetVertexColor(unpack(layout.WinterVeilManaColor))
		self.ExtraPower.WinterVeil = winterVeilMana
	end

	-- Threat
	-----------------------------------------------------------
	local threat = {
		fadeOut = layout.ThreatFadeOut,
		hideSolo = layout.ThreatHideSolo,

		IsObjectType = function() end,
		IsShown = function(element)
			return element.health:IsShown()
		end,
		Show = function(element)
			element.health:Show()
			element.power:Show()
			element.powerBg:Show()
			if (element.mana) then
				element.mana:Show()
			end
		end,
		Hide = function(element)
			element.health:Hide()
			element.power:Hide()
			element.powerBg:Hide()
			if (element.mana) then
				element.mana:Hide()
			end
		end,
		OverrideColor = function(element, unit, status, r, g, b)
			element.health:SetVertexColor(r, g, b)
			element.power:SetVertexColor(r, g, b)
			element.powerBg:SetVertexColor(r, g, b)
			if (element.mana) then
				element.mana:SetVertexColor(r, g, b)
			end
		end
	}

	local threatHealth = backdrop:CreateTexture()
	threatHealth:SetPoint(unpack(layout.ThreatHealthPlace))
	threatHealth:SetSize(unpack(layout.ThreatHealthSize))
	threatHealth:SetDrawLayer(unpack(layout.ThreatHealthDrawLayer))
	threatHealth:SetAlpha(layout.ThreatHealthAlpha)
	threatHealth._owner = self.Health
	threat.health = threatHealth

	local threatPowerFrame = backdrop:CreateFrame("Frame")
	threatPowerFrame:SetFrameLevel(backdrop:GetFrameLevel())
	threatPowerFrame:SetAllPoints(self.Power)
	threatPowerFrame:SetShown(self.Power:IsShown())

	-- Hook the power threat frame visibility to the power crystal
	--self.Power:HookScript("OnShow", function() threatPowerFrame:Show() end)
	--self.Power:HookScript("OnHide", function() threatPowerFrame:Hide() end)
	hooksecurefunc(self.Power, "Show", function() threatPowerFrame:Show() end)
	hooksecurefunc(self.Power, "Hide", function() threatPowerFrame:Hide() end)
	hooksecurefunc(self.Power, "SetShown", function(_,isShown) threatPowerFrame:SetShown(isShown) end)

	local threatPower = threatPowerFrame:CreateTexture()
	threatPower:SetPoint(unpack(layout.ThreatPowerPlace))
	threatPower:SetDrawLayer(unpack(layout.ThreatPowerDrawLayer))
	threatPower:SetSize(unpack(layout.ThreatPowerSize))
	threatPower:SetAlpha(layout.ThreatPowerAlpha)
	threatPower:SetTexture(layout.ThreatPowerTexture)
	threatPower._owner = self.Power
	threat.power = threatPower

	local threatPowerBg = threatPowerFrame:CreateTexture()
	threatPowerBg:SetPoint(unpack(layout.ThreatPowerBgPlace))
	threatPowerBg:SetDrawLayer(unpack(layout.ThreatPowerBgDrawLayer))
	threatPowerBg:SetSize(unpack(layout.ThreatPowerBgSize))
	threatPowerBg:SetAlpha(layout.ThreatPowerBgAlpha)
	threatPowerBg:SetTexture(layout.ThreatPowerBgTexture)
	threatPowerBg._owner = self.Power
	threat.powerBg = threatPowerBg

	local threatManaFrame = backdrop:CreateFrame("Frame")
	threatManaFrame:SetFrameLevel(backdrop:GetFrameLevel())
	threatManaFrame:SetAllPoints(self.ExtraPower)
	threatManaFrame:SetShown(self.ExtraPower:IsShown())

	-- Hook the mana threat frame visibility to the mana orb
	--self.ExtraPower:HookScript("OnShow", function() threatManaFrame:Show() end)
	--self.ExtraPower:HookScript("OnHide", function() threatManaFrame:Hide() end)
	hooksecurefunc(self.ExtraPower, "Show", function() threatManaFrame:Show() end)
	hooksecurefunc(self.ExtraPower, "Hide", function() threatManaFrame:Hide() end)
	hooksecurefunc(self.ExtraPower, "SetShown", function(_,isShown) threatManaFrame:SetShown(isShown) end)

	local threatMana = threatManaFrame:CreateTexture()
	threatMana:SetDrawLayer(unpack(layout.ThreatManaDrawLayer))
	threatMana:SetPoint(unpack(layout.ThreatManaPlace))
	threatMana:SetSize(unpack(layout.ThreatManaSize))
	threatMana:SetAlpha(layout.ThreatManaAlpha)
	threatMana:SetTexture(layout.ThreatManaTexture)
	threatMana._owner = self.ExtraPower
	threat.mana = threatMana

	self.Threat = threat

	-- Cast Bar
	-----------------------------------------------------------
	local cast = content:CreateStatusBar()
	cast:SetSize(unpack(layout.CastBarSize))
	cast:SetFrameLevel(health:GetFrameLevel() + 1)
	cast:Place(unpack(layout.CastBarPlace))
	cast:SetOrientation(layout.CastBarOrientation)
	cast:DisableSmoothing()
	cast:SetStatusBarColor(unpack(layout.CastBarColor))
	cast:SetSparkMap(layout.CastBarSparkMap)

	local name = (layout.CastBarNameParent and self[layout.CastBarNameParent] or overlay):CreateFontString()
	name:SetPoint(unpack(layout.CastBarNamePlace))
	name:SetFontObject(layout.CastBarNameFont)
	name:SetDrawLayer(unpack(layout.CastBarNameDrawLayer))
	name:SetJustifyH(layout.CastBarNameJustifyH)
	name:SetJustifyV(layout.CastBarNameJustifyV)
	name:SetTextColor(unpack(layout.CastBarNameColor))
	name:SetSize(unpack(layout.CastBarNameSize))
	cast.Name = name

	local value = (layout.CastBarValueParent and self[layout.CastBarValueParent] or overlay):CreateFontString()
	value:SetPoint(unpack(layout.CastBarValuePlace))
	value:SetFontObject(layout.CastBarValueFont)
	value:SetDrawLayer(unpack(layout.CastBarValueDrawLayer))
	value:SetJustifyH(layout.CastBarValueJustifyH)
	value:SetJustifyV(layout.CastBarValueJustifyV)
	value:SetTextColor(unpack(layout.CastBarValueColor))
	cast.Value = value

	self.Cast = cast
	self.Cast.PostUpdate = layout.CastBarPostUpdate

	-- Combat Indicator
	-----------------------------------------------------------
	local combat = overlay:CreateTexture()

	local prefix = "CombatIndicator"
	if (IsLoveFestival) then
		prefix = "Love"..prefix
	end
	combat:SetSize(unpack(layout[prefix.."Size"]))
	combat:SetPoint(unpack(layout[prefix.."Place"]))
	combat:SetTexture(layout[prefix.."Texture"])
	combat:SetDrawLayer(unpack(layout[prefix.."DrawLayer"]))
	self.Combat = combat

	-- Unit Classification (PvP Status)
	local classification = overlay:CreateFrame("Frame")
	classification:SetPoint(unpack(layout.ClassificationPlace))
	classification:SetSize(unpack(layout.ClassificationSize))
	classification.hideInCombat = true
	self.Classification = classification

	local alliance = classification:CreateTexture()
	alliance:SetPoint("CENTER", 0, 0)
	alliance:SetSize(unpack(layout.ClassificationSize))
	alliance:SetTexture(layout.ClassificationIndicatorAllianceTexture)
	alliance:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Alliance = alliance

	local horde = classification:CreateTexture()
	horde:SetPoint("CENTER", 0, 0)
	horde:SetSize(unpack(layout.ClassificationSize))
	horde:SetTexture(layout.ClassificationIndicatorHordeTexture)
	horde:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Horde = horde

	-- Auras
	-----------------------------------------------------------
	local auras = content:CreateFrame("Frame")
	auras:Place(unpack(layout.AuraFramePlace))
	auras:SetSize(unpack(layout.AuraFrameSize)) -- auras will be aligned in the available space, this size gives us 8x1 auras
	for property,value in pairs(layout.AuraProperties) do
		auras[property] = value
	end
	self.Auras = auras
	self.Auras.PostCreateButton = layout.Aura_PostCreateButton -- post creation styling
	self.Auras.PostUpdateButton = layout.Aura_PostUpdateButton -- post updates when something changes (even timers)

	-- Mana Value when Mana isn't visible
	local parent = self[layout.ManaTextParent or self.Power and "Power" or "Health"]
	local manaText = parent:CreateFontString()
	manaText:SetPoint(unpack(layout.ManaTextPlace))
	manaText:SetDrawLayer(unpack(layout.ManaTextDrawLayer))
	manaText:SetJustifyH(layout.ManaTextJustifyH)
	manaText:SetJustifyV(layout.ManaTextJustifyV)
	manaText:SetFontObject(layout.ManaTextFont)
	manaText:SetTextColor(unpack(layout.ManaTextColor))
	manaText.frequent = true
	self.ManaText = manaText
	self.ManaText.OverrideValue = layout.ManaTextOverride

	-- Classic Pet Happiness (Hardcoded)
	-----------------------------------------------------------
	if (IsClassic or IsTBC) then
		local happiness = overlay:CreateFontString()
		happiness:SetFontObject(GetFont(12,true))
		happiness:Place("BOTTOM", "UICenter", "BOTTOM", 0, 10)
		self.PetHappiness = happiness
	end

	-- Update textures according to player level
	self.PostUpdateTextures = layout.PostUpdateTextures
	self:PostUpdateTextures()
end

UnitStyles.StylePlayerHUDFrame = function(self, unit, id, layout, ...)

	self:SetSize(unpack(layout.Size))
	self:Place(unpack(layout.Place))

	-- We Don't want this clickable,
	-- it's in the middle of the screen!
	self.ignoreMouseOver = layout.IgnoreMouseOver

	-- Assign our own global custom colors
	self.colors = Colors
	self.layout = layout

	-- Scaffolds
	-----------------------------------------------------------
	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())

	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 10)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)

	-- Cast Bar
	local cast = backdrop:CreateStatusBar()
	cast:Place(unpack(layout.CastBarPlace))
	cast:SetSize(unpack(layout.CastBarSize))
	cast:SetStatusBarTexture(layout.CastBarTexture)
	cast:SetStatusBarColor(unpack(layout.CastBarColor))
	cast:SetOrientation(layout.CastBarOrientation) -- set the bar to grow towards the top.
	cast:DisableSmoothing(true) -- don't smoothe castbars, it'll make it inaccurate
	cast.timeToHold = layout.CastTimeToHoldFailed
	self.Cast = cast

	local castBg = cast:CreateTexture()
	castBg:SetPoint(unpack(layout.CastBarBackgroundPlace))
	castBg:SetSize(unpack(layout.CastBarBackgroundSize))
	castBg:SetTexture(layout.CastBarBackgroundTexture)
	castBg:SetDrawLayer(unpack(layout.CastBarBackgroundDrawLayer))
	castBg:SetVertexColor(unpack(layout.CastBarBackgroundColor))
	self.Cast.Bg = castBg

	local castValue = cast:CreateFontString()
	castValue:SetPoint(unpack(layout.CastBarValuePlace))
	castValue:SetFontObject(layout.CastBarValueFont)
	castValue:SetDrawLayer(unpack(layout.CastBarValueDrawLayer))
	castValue:SetJustifyH(layout.CastBarValueJustifyH)
	castValue:SetJustifyV(layout.CastBarValueJustifyV)
	castValue:SetTextColor(unpack(layout.CastBarValueColor))
	self.Cast.Value = castValue

	local castName = cast:CreateFontString()
	castName:SetPoint(unpack(layout.CastBarNamePlace))
	castName:SetFontObject(layout.CastBarNameFont)
	castName:SetDrawLayer(unpack(layout.CastBarNameDrawLayer))
	castName:SetJustifyH(layout.CastBarNameJustifyH)
	castName:SetJustifyV(layout.CastBarNameJustifyV)
	castName:SetTextColor(unpack(layout.CastBarNameColor))
	self.Cast.Name = castName

	local castShield = cast:CreateTexture()
	castShield:SetPoint(unpack(layout.CastBarShieldPlace))
	castShield:SetSize(unpack(layout.CastBarShieldSize))
	castShield:SetTexture(layout.CastBarShieldTexture)
	castShield:SetDrawLayer(unpack(layout.CastBarShieldDrawLayer))
	castShield:SetVertexColor(unpack(layout.CastBarShieldColor))
	self.Cast.Shield = castShield

	-- Not going to work this into the plugin, so we just hook it here.
	hooksecurefunc(self.Cast.Shield, "Show", function() self.Cast.Bg:Hide() end)
	hooksecurefunc(self.Cast.Shield, "Hide", function() self.Cast.Bg:Show() end)

	local spellQueue = content:CreateStatusBar()
	--spellQueue:SetFrameLevel(self.Cast:GetFrameLevel() + 1)
	spellQueue:Place(unpack(layout.CastBarSpellQueuePlace))
	spellQueue:SetSize(unpack(layout.CastBarSpellQueueSize))
	spellQueue:SetOrientation(layout.CastBarSpellQueueOrientation)
	spellQueue:SetStatusBarTexture(layout.CastBarSpellQueueTexture)
	spellQueue:SetStatusBarColor(unpack(layout.CastBarSpellQueueColor))
	spellQueue:DisableSmoothing(true)
	self.Cast.SpellQueue = spellQueue

	-- Class Power
	local classPower = backdrop:CreateFrame("Frame")
	classPower:Place(unpack(layout.ClassPowerPlace)) -- center it smack in the middle of the screen
	classPower:SetSize(unpack(layout.ClassPowerSize)) -- minimum size, this is really just an anchor

	-- Only show it on hostile targets
	classPower.hideWhenUnattackable = layout.ClassPowerHideWhenUnattackable

	-- Maximum points displayed regardless
	-- of max value and available point frames.
	-- This does not affect runes, which still require 6 frames.
	classPower.maxComboPoints = layout.ClassPowerMaxComboPoints

	-- Set the point alpha to 0 when no target is selected
	-- This does not affect runes
	classPower.hideWhenNoTarget = layout.ClassPowerHideWhenNoTarget

	-- Set all point alpha to 0 when we have no active points
	classPower.hideWhenEmpty = layout.ClassPowerHideWhenNoTarget -- This does not affect runes

	-- Alpha modifier of inactive/not ready points
	classPower.alphaEmpty = layout.ClassPowerAlphaWhenEmpty

	-- Alpha modifier when not engaged in combat
	-- This is applied on top of the inactive modifier above
	classPower.alphaNoCombat = layout.ClassPowerAlphaWhenOutOfCombat
	classPower.alphaNoCombatRunes = layout.ClassPowerAlphaWhenOutOfCombatRunes
	classPower.alphaWhenHiddenRunes = layout.ClassPowerAlphaWhenHiddenRunes

	-- Set to true to flip the classPower horizontally
	-- Intended to be used alongside actioncam
	classPower.flipSide = layout.ClassPowerReverseSides

	-- Sort order of the runes
	classPower.runeSortOrder = layout.ClassPowerRuneSortOrder

	-- We show all 6 runes in retail, but stick to 5 otherwise.
	local numPoints = (IsRetail) and 6 or (IsClassic or IsTBC) and 5
	for i = 1,numPoints do

		-- Main point object
		local point = classPower:CreateStatusBar() -- the widget require Wheel statusbars
		point:SetSmoothingFrequency(.25) -- keep bar transitions fairly fast
		point:SetMinMaxValues(0, 1)
		point:SetValue(1)

		-- Empty slot texture
		-- Make it slightly larger than the point textures,
		-- to give a nice darker edge around the points.
		point.slotTexture = point:CreateTexture()
		point.slotTexture:SetDrawLayer("BACKGROUND", -1)
		point.slotTexture:SetAllPoints(point)

		-- Overlay glow, aligned to the bar texture
		point.glow = point:CreateTexture()
		point.glow:SetDrawLayer("ARTWORK")
		point.glow:SetAllPoints(point:GetStatusBarTexture())

		layout.ClassPowerPostCreatePoint(classPower, i, point)

		classPower[i] = point
	end

	self.ClassPower = classPower
	self.ClassPower.PostUpdate = layout.ClassPowerPostUpdate
	self.ClassPower:PostUpdate()

	-- PlayerAltPower Bar
	if (IsRetail) then
		local cast = backdrop:CreateStatusBar()
		cast:Place(unpack(layout.PlayerAltPowerBarPlace))
		cast:SetSize(unpack(layout.PlayerAltPowerBarSize))
		cast:SetStatusBarTexture(layout.PlayerAltPowerBarTexture)
		cast:SetStatusBarColor(unpack(layout.PlayerAltPowerBarColor))
		cast:SetOrientation(layout.PlayerAltPowerBarOrientation) -- set the bar to grow towards the top.
		--cast:DisableSmoothing(true) -- don't smoothe castbars, it'll make it inaccurate
		cast:EnableMouse(true)
		self.AltPower = cast
		self.AltPower.OverrideValue = layout.PlayerAltPowerBarValueOverride

		local castBg = cast:CreateTexture()
		castBg:SetPoint(unpack(layout.PlayerAltPowerBarBackgroundPlace))
		castBg:SetSize(unpack(layout.PlayerAltPowerBarBackgroundSize))
		castBg:SetTexture(layout.PlayerAltPowerBarBackgroundTexture)
		castBg:SetDrawLayer(unpack(layout.PlayerAltPowerBarBackgroundDrawLayer))
		castBg:SetVertexColor(unpack(layout.PlayerAltPowerBarBackgroundColor))
		self.AltPower.Bg = castBg

		local castValue = cast:CreateFontString()
		castValue:SetPoint(unpack(layout.PlayerAltPowerBarValuePlace))
		castValue:SetFontObject(layout.PlayerAltPowerBarValueFont)
		castValue:SetDrawLayer(unpack(layout.PlayerAltPowerBarValueDrawLayer))
		castValue:SetJustifyH(layout.PlayerAltPowerBarValueJustifyH)
		castValue:SetJustifyV(layout.PlayerAltPowerBarValueJustifyV)
		castValue:SetTextColor(unpack(layout.PlayerAltPowerBarValueColor))
		self.AltPower.Value = castValue

		local castName = cast:CreateFontString()
		castName:SetPoint(unpack(layout.PlayerAltPowerBarNamePlace))
		castName:SetFontObject(layout.PlayerAltPowerBarNameFont)
		castName:SetDrawLayer(unpack(layout.PlayerAltPowerBarNameDrawLayer))
		castName:SetJustifyH(layout.PlayerAltPowerBarNameJustifyH)
		castName:SetJustifyV(layout.PlayerAltPowerBarNameJustifyV)
		castName:SetTextColor(unpack(layout.PlayerAltPowerBarNameColor))
		self.AltPower.Name = castName
	end

end

UnitStyles.StyleTargetFrame = function(self, unit, id, layout, ...)
	self.layout = layout
	self.colors = Colors

	self:SetSize(unpack(layout.Size))
	self:Place(unpack(layout.Place))
	self:SetHitRectInsets(unpack(layout.HitRectInsets))

	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())

	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 10)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 20)

	-- Health
	local health = content:CreateStatusBar()
	health:SetOrientation(layout.HealthBarOrientation or "RIGHT")
	health:SetFlippedHorizontally(layout.HealthBarSetFlippedHorizontally)
	health:SetFrameLevel(health:GetFrameLevel() + 2)
	health:Place(unpack(layout.HealthPlace))
	health:SetSmartSmoothing(true)
	health.threatFeedbackUnit = "player"
	health.colorThreat = layout.HealthColorThreat -- color non-friendly by threat
	health.colorTapped = layout.HealthColorTapped  -- color tap denied units
	health.colorDisconnected = layout.HealthColorDisconnected -- color disconnected units
	health.colorClass = layout.HealthColorClass -- color players by class
	health.colorReaction = layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorHealth = layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates
	self.Health = health
	self.Health.PostUpdate = layout.CastBarPostUpdate

	local healthBgHolder = health:CreateFrame("Frame")
	healthBgHolder:SetAllPoints()
	healthBgHolder:SetFrameLevel(health:GetFrameLevel()-2)

	local healthBg = healthBgHolder:CreateTexture()
	healthBg:SetDrawLayer(unpack(layout.HealthBackdropDrawLayer))
	healthBg:SetSize(unpack(layout.HealthBackdropSize))
	healthBg:SetPoint(unpack(layout.HealthBackdropPlace))
	healthBg:SetTexture(layout.HealthBackdropTexture)
	healthBg:SetTexCoord(unpack(layout.HealthBackdropTexCoord))
	self.Health.Bg = healthBg

	if (IsRetail) then
		local absorbVal = overlay:CreateFontString()
		if layout.HealthAbsorbValuePlaceFunction then
			absorbVal:SetPoint(layout.HealthAbsorbValuePlaceFunction(self))
		else
			absorbVal:SetPoint(unpack(layout.HealthAbsorbValuePlace))
		end
		absorbVal:SetDrawLayer(unpack(layout.HealthAbsorbValueDrawLayer))
		absorbVal:SetJustifyH(layout.HealthAbsorbValueJustifyH)
		absorbVal:SetJustifyV(layout.HealthAbsorbValueJustifyV)
		absorbVal:SetFontObject(layout.HealthAbsorbValueFont)
		absorbVal:SetTextColor(unpack(layout.HealthAbsorbValueColor))
		self.Health.ValueAbsorb = absorbVal
	end

	-- Power
	local power = overlay:CreateStatusBar()
	power:SetSize(unpack(layout.PowerSize))
	power:Place(unpack(layout.PowerPlace))
	power:SetStatusBarTexture(layout.PowerBarTexture)
	power:SetTexCoord(unpack(layout.PowerBarTexCoord))
	power:SetOrientation(layout.PowerBarOrientation or "RIGHT") -- set the bar to grow towards the top.
	power:SetSmoothingMode(layout.PowerBarSmoothingMode) -- set the smoothing mode.
	power:SetSmoothingFrequency(layout.PowerBarSmoothingFrequency or .5) -- set the duration of the smoothing.
	power:SetFlippedHorizontally(layout.PowerBarSetFlippedHorizontally)
	power:SetSparkTexture(layout.PowerBarSparkTexture)
	power.ignoredResource = layout.PowerIgnoredResource -- make the bar hide when MANA is the primary resource.
	power.showAlternate = layout.PowerShowAlternate -- use this bar for alt power as well
	power.hideWhenEmpty = layout.PowerHideWhenEmpty -- hide the bar when it's empty
	power.hideWhenDead = layout.PowerHideWhenDead -- hide the bar when the unit is dead
	power.visibilityFilter = layout.PowerVisibilityFilter -- Use filters to decide what units to show for
	power:SetAlpha(.75)
	self.Power = power

	local powerBg = power:CreateTexture()
	powerBg:SetDrawLayer(unpack(layout.PowerBackgroundDrawLayer))
	powerBg:SetSize(unpack(layout.PowerBackgroundSize))
	powerBg:SetPoint(unpack(layout.PowerBackgroundPlace))
	powerBg:SetTexture(layout.PowerBackgroundTexture)
	powerBg:SetVertexColor(unpack(layout.PowerBackgroundColor))
	powerBg:SetTexCoord(unpack(layout.PowerBackgroundTexCoord))
	powerBg:SetIgnoreParentAlpha(true)
	self.Power.Bg = powerBg

	local powerVal = self.Power:CreateFontString()
	powerVal:SetPoint(unpack(layout.PowerValuePlace))
	powerVal:SetDrawLayer(unpack(layout.PowerValueDrawLayer))
	powerVal:SetJustifyH(layout.PowerValueJustifyH)
	powerVal:SetJustifyV(layout.PowerValueJustifyV)
	powerVal:SetFontObject(layout.PowerValueFont)
	powerVal:SetTextColor(unpack(layout.PowerValueColor))
	self.Power.Value = powerVal
	self.Power.OverrideValue = layout.PowerValueOverride

	-- Cast Bar
	local cast = content:CreateStatusBar()
	cast:SetSize(unpack(layout.CastBarSize))
	cast:SetFrameLevel(health:GetFrameLevel() + 1)
	cast:Place(unpack(layout.CastBarPlace))
	cast:SetOrientation(layout.CastBarOrientation)
	cast:SetFlippedHorizontally(layout.CastBarSetFlippedHorizontally)
	cast:SetSmoothingMode(layout.CastBarSmoothingMode)
	cast:SetSmoothingFrequency(layout.CastBarSmoothingFrequency)
	cast:SetStatusBarColor(unpack(layout.CastBarColor))
	cast:SetSparkMap(layout.CastBarSparkMap) -- set the map the spark follows along the bar.
	self.Cast = cast
	self.Cast.PostUpdate = layout.CastBarPostUpdate

	local name = health:CreateFontString()
	name:SetPoint(unpack(layout.CastBarNamePlace))
	name:SetFontObject(layout.CastBarNameFont)
	name:SetDrawLayer(unpack(layout.CastBarNameDrawLayer))
	name:SetJustifyH(layout.CastBarNameJustifyH)
	name:SetJustifyV(layout.CastBarNameJustifyV)
	name:SetTextColor(unpack(layout.CastBarNameColor))
	name:SetSize(unpack(layout.CastBarNameSize))
	cast.Name = name

	local value = health:CreateFontString()
	value:SetPoint(unpack(layout.CastBarValuePlace))
	value:SetFontObject(layout.CastBarValueFont)
	value:SetDrawLayer(unpack(layout.CastBarValueDrawLayer))
	value:SetJustifyH(layout.CastBarValueJustifyH)
	value:SetJustifyV(layout.CastBarValueJustifyV)
	value:SetTextColor(unpack(layout.CastBarValueColor))
	cast.Value = value

	-- Portrait
	local portrait = backdrop:CreateFrame("PlayerModel")
	portrait:SetPoint(unpack(layout.PortraitPlace))
	portrait:SetSize(unpack(layout.PortraitSize))
	portrait:SetAlpha(layout.PortraitAlpha)
	portrait.distanceScale = layout.PortraitDistanceScale
	portrait.positionX = layout.PortraitPositionX
	portrait.positionY = layout.PortraitPositionY
	portrait.positionZ = layout.PortraitPositionZ
	portrait.rotation = layout.PortraitRotation -- in degrees
	portrait.showFallback2D = layout.PortraitShowFallback2D -- display 2D portraits when unit is out of range of 3D models
	self.Portrait = portrait

	-- To allow the backdrop and overlay to remain
	-- visible even with no visible player model,
	-- we add them to our backdrop and overlay frames,
	-- not to the portrait frame itself.
	local portraitBg = backdrop:CreateTexture()
	portraitBg:SetPoint(unpack(layout.PortraitBackgroundPlace))
	portraitBg:SetSize(unpack(layout.PortraitBackgroundSize))
	portraitBg:SetTexture(layout.PortraitBackgroundTexture)
	portraitBg:SetDrawLayer(unpack(layout.PortraitBackgroundDrawLayer))
	portraitBg:SetVertexColor(unpack(layout.PortraitBackgroundColor)) -- keep this dark
	self.Portrait.Bg = portraitBg

	local portraitShade = content:CreateTexture()
	portraitShade:SetPoint(unpack(layout.PortraitShadePlace))
	portraitShade:SetSize(unpack(layout.PortraitShadeSize))
	portraitShade:SetTexture(layout.PortraitShadeTexture)
	portraitShade:SetDrawLayer(unpack(layout.PortraitShadeDrawLayer))
	self.Portrait.Shade = portraitShade

	local portraitFg = content:CreateTexture()
	portraitFg:SetPoint(unpack(layout.PortraitForegroundPlace))
	portraitFg:SetSize(unpack(layout.PortraitForegroundSize))
	portraitFg:SetDrawLayer(unpack(layout.PortraitForegroundDrawLayer))
	self.Portrait.Fg = portraitFg

	-- Threat
	-----------------------------------------------------------
	local threat = {
		fadeOut = layout.ThreatFadeOut,
		feedbackUnit = "player",
		hideSolo = layout.ThreatHideSolo,

		IsObjectType = function() end,
		IsShown = function(element)
			return element.health:IsShown()
		end,
		Show = function(element)
			element.health:Show()
			element.portrait:Show()
		end,
		Hide = function(element)
			element.health:Hide()
			element.portrait:Hide()
		end,
		OverrideColor = function(element, unit, status, r, g, b)
			element.health:SetVertexColor(r, g, b)
			element.portrait:SetVertexColor(r, g, b)
		end
	}

	local healthThreatHolder = backdrop:CreateFrame("Frame")
	healthThreatHolder:SetAllPoints(health)

	local threatHealth = healthThreatHolder:CreateTexture()
	threatHealth:SetDrawLayer(unpack(layout.ThreatHealthDrawLayer))
	threatHealth:SetAlpha(layout.ThreatHealthAlpha)
	threatHealth:SetTexCoord(unpack(layout.ThreatHealthTexCoord))
	threatHealth._owner = self.Health
	threat.health = threatHealth

	local threatPortraitFrame = backdrop:CreateFrame("Frame")
	threatPortraitFrame:SetFrameLevel(backdrop:GetFrameLevel())
	threatPortraitFrame:SetAllPoints(self.Portrait)

	-- Hook the power visibility to the power crystal
	self.Portrait:HookScript("OnShow", function() threatPortraitFrame:Show() end)
	self.Portrait:HookScript("OnHide", function() threatPortraitFrame:Hide() end)

	local threatPortrait = threatPortraitFrame:CreateTexture()
	threatPortrait:SetPoint(unpack(layout.ThreatPortraitPlace))
	threatPortrait:SetSize(unpack(layout.ThreatPortraitSize))
	threatPortrait:SetTexture(layout.ThreatPortraitTexture)
	threatPortrait:SetDrawLayer(unpack(layout.ThreatPortraitDrawLayer))
	threatPortrait:SetAlpha(layout.ThreatPortraitAlpha)
	threatPortrait._owner = self.Power
	threat.portrait = threatPortrait

	self.Threat = threat

	-- Unit Level
	-- level text
	local level = overlay:CreateFontString()
	level:SetPoint(unpack(layout.LevelPlace))
	level:SetDrawLayer(unpack(layout.LevelDrawLayer))
	level:SetJustifyH(layout.LevelJustifyH)
	level:SetJustifyV(layout.LevelJustifyV)
	level:SetFontObject(layout.LevelFont)
	self.Level = level

	-- Hide the level of capped (or higher) players and NPcs
	-- Doesn't affect high/unreadable level (??) creatures, as they will still get a skull.
	level.hideCapped = layout.LevelHideCapped

	-- Hide the level of level 1's
	level.hideFloored = layout.LevelHideFloored

	-- Set the default level coloring when nothing special is happening
	level.defaultColor = layout.LevelColor
	level.alpha = layout.LevelAlpha

	-- Use a custom method to decide visibility
	level.visibilityFilter = layout.LevelVisibilityFilter

	-- Badge backdrop
	local levelBadge = overlay:CreateTexture()
	levelBadge:SetPoint("CENTER", level, "CENTER", 0, 1)
	levelBadge:SetSize(unpack(layout.LevelBadgeSize))
	levelBadge:SetDrawLayer(unpack(layout.LevelBadgeDrawLayer))
	levelBadge:SetTexture(layout.LevelBadgeTexture)
	levelBadge:SetVertexColor(unpack(layout.LevelBadgeColor))
	level.Badge = levelBadge

	-- Skull texture for bosses, high level (and dead units if the below isn't provided)
	local skull = overlay:CreateTexture()
	skull:Hide()
	skull:SetPoint("CENTER", level, "CENTER", 0, 0)
	skull:SetSize(unpack(layout.LevelSkullSize))
	skull:SetDrawLayer(unpack(layout.LevelSkullDrawLayer))
	skull:SetTexture(layout.LevelSkullTexture)
	skull:SetVertexColor(unpack(layout.LevelSkullColor))
	level.Skull = skull

	-- Skull texture for dead units only
	local dead = overlay:CreateTexture()
	dead:Hide()
	dead:SetPoint("CENTER", level, "CENTER", 0, 0)
	dead:SetSize(unpack(layout.LevelDeadSkullSize))
	dead:SetDrawLayer(unpack(layout.LevelDeadSkullDrawLayer))
	dead:SetTexture(layout.LevelDeadSkullTexture)
	dead:SetVertexColor(unpack(layout.LevelDeadSkullColor))
	level.Dead = dead

	-- Unit Classification (boss, elite, rare)
	local classification = overlay:CreateFrame("Frame")
	classification:SetPoint(unpack(layout.ClassificationPlace))
	classification:SetSize(unpack(layout.ClassificationSize))
	self.Classification = classification

	local boss = classification:CreateTexture()
	boss:SetPoint("CENTER", 0, 0)
	boss:SetSize(unpack(layout.ClassificationSize))
	boss:SetTexture(layout.ClassificationIndicatorBossTexture)
	boss:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Boss = boss

	local elite = classification:CreateTexture()
	elite:SetPoint("CENTER", 0, 0)
	elite:SetSize(unpack(layout.ClassificationSize))
	elite:SetTexture(layout.ClassificationIndicatorEliteTexture)
	elite:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Elite = elite

	local rare = classification:CreateTexture()
	rare:SetPoint("CENTER", 0, 0)
	rare:SetSize(unpack(layout.ClassificationSize))
	rare:SetTexture(layout.ClassificationIndicatorRareTexture)
	rare:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Rare = rare

	local alliance = classification:CreateTexture()
	alliance:SetPoint("CENTER", 0, 0)
	alliance:SetSize(unpack(layout.ClassificationSize))
	alliance:SetTexture(layout.ClassificationIndicatorAllianceTexture)
	alliance:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Alliance = alliance

	local horde = classification:CreateTexture()
	horde:SetPoint("CENTER", 0, 0)
	horde:SetSize(unpack(layout.ClassificationSize))
	horde:SetTexture(layout.ClassificationIndicatorHordeTexture)
	horde:SetVertexColor(unpack(layout.ClassificationColor))
	self.Classification.Horde = horde

	-- Targeting
	-- Indicates who your target is targeting
	self.Targeted = {}

	local prefix = "TargetIndicator"
	if (IsLoveFestival) then
		prefix = "Love"..prefix
	end

	local friend = overlay:CreateTexture()
	friend:SetPoint(unpack(layout[prefix.."YouByFriendPlace"]))
	friend:SetSize(unpack(layout[prefix.."YouByFriendSize"]))
	friend:SetTexture(layout[prefix.."YouByFriendTexture"])
	friend:SetVertexColor(unpack(layout[prefix.."YouByFriendColor"]))
	self.Targeted.YouByFriend = friend

	local enemy = overlay:CreateTexture()
	enemy:SetPoint(unpack(layout[prefix.."YouByEnemyPlace"]))
	enemy:SetSize(unpack(layout[prefix.."YouByEnemySize"]))
	enemy:SetTexture(layout[prefix.."YouByEnemyTexture"])
	enemy:SetVertexColor(unpack(layout[prefix.."YouByEnemyColor"]))
	self.Targeted.YouByEnemy = enemy

	local pet = overlay:CreateTexture()
	pet:SetPoint(unpack(layout[prefix.."PetByEnemyPlace"]))
	pet:SetSize(unpack(layout[prefix.."PetByEnemySize"]))
	pet:SetTexture(layout[prefix.."PetByEnemyTexture"])
	pet:SetVertexColor(unpack(layout[prefix.."PetByEnemyColor"]))
	self.Targeted.PetByEnemy = pet

	-- Auras
	local auras = content:CreateFrame("Frame")
	auras:Place(unpack(layout.AuraFramePlace))
	auras:SetSize(unpack(layout.AuraFrameSize))
	for property,value in pairs(layout.AuraProperties) do
		auras[property] = value
	end
	self.Auras = auras
	self.Auras.PostCreateButton = layout.Aura_PostCreateButton -- post creation styling
	self.Auras.PostUpdateButton = layout.Aura_PostUpdateButton -- post updates when something changes (even timers)

	-- Unit Name
	local name = overlay:CreateFontString()
	name:SetPoint(unpack(layout.NamePlace))
	name:SetDrawLayer(unpack(layout.NameDrawLayer))
	name:SetJustifyH(layout.NameJustifyH)
	name:SetJustifyV(layout.NameJustifyV)
	name:SetFontObject(layout.NameFont)
	name:SetTextColor(unpack(layout.NameColor))
	name.showLevel = true
	name.showLevelLast = false
	self.Name = name

	-- Health Value
	local healthValHolder = overlay:CreateFrame("Frame")
	healthValHolder:SetAllPoints(health)

	local healthVal = healthValHolder:CreateFontString()
	healthVal:SetPoint(unpack(layout.HealthValuePlace))
	healthVal:SetDrawLayer(unpack(layout.HealthValueDrawLayer))
	healthVal:SetJustifyH(layout.HealthValueJustifyH)
	healthVal:SetJustifyV(layout.HealthValueJustifyV)
	healthVal:SetFontObject(layout.HealthValueFont)
	healthVal:SetTextColor(unpack(layout.HealthValueColor))
	self.Health.Value = healthVal

	-- Health Percentage
	local healthPerc = health:CreateFontString()
	healthPerc:SetPoint(unpack(layout.HealthPercentPlace))
	healthPerc:SetDrawLayer(unpack(layout.HealthPercentDrawLayer))
	healthPerc:SetJustifyH(layout.HealthPercentJustifyH)
	healthPerc:SetJustifyV(layout.HealthPercentJustifyV)
	healthPerc:SetFontObject(layout.HealthPercentFont)
	healthPerc:SetTextColor(unpack(layout.HealthPercentColor))
	self.Health.ValuePercent = healthPerc

	local feedback = overlay:CreateFrame("Frame")
	feedback:SetAllPoints(health)
	feedback:Hide()

	local feedbackText = feedback:CreateFontString()
	feedbackText:SetJustifyH(layout.CombatFeedbackJustifyH)
	feedbackText:SetJustifyV(layout.CombatFeedbackJustifyV)
	feedbackText:SetPoint(unpack(layout.CombatFeedbackPlace))
	feedbackText:SetFontObject(layout.CombatFeedbackFont)
	feedbackText.feedbackFont = layout.CombatFeedbackFont
	feedbackText.feedbackFontLarge = layout.CombatFeedbackFontLarge
	feedbackText.feedbackFontSmall = layout.CombatFeedbackFontSmall

	self.CombatFeedback = feedback
	self.CombatFeedback.feedbackText = feedbackText

	-- Update textures according to player level
	self.PostUpdateTextures = layout.PostUpdateTextures
	self:PostUpdateTextures()

	if (layout.NamePostUpdateBecauseOfToT) then
		self:RegisterMessage("GP_UNITFRAME_TOT_VISIBLE", layout.NamePostUpdateBecauseOfToT)
		self:RegisterMessage("GP_UNITFRAME_TOT_INVISIBLE", layout.NamePostUpdateBecauseOfToT)
		self:RegisterMessage("GP_UNITFRAME_TOT_SHOWN", layout.NamePostUpdateBecauseOfToT)
		self:RegisterMessage("GP_UNITFRAME_TOT_HIDDEN", layout.NamePostUpdateBecauseOfToT)
	end
end

UnitStyles.StyleToTFrame = function(self, unit, id, layout, ...)
	return StyleSmallFrame(self, unit, id, layout, ...)
end

UnitStyles.StyleFocusFrame = function(self, unit, id, layout, ...)
	return StyleSmallFrame(self, unit, id, layout, ...)
end

UnitStyles.StylePetFrame = function(self, unit, id, layout, ...)
	return StyleSmallFrame(self, unit, id, layout, ...)
end

-----------------------------------------------------------
-- Grouped Unit Styling
-----------------------------------------------------------
-- Dummy counters for testing purposes only
local fakeBossId, fakePartyId, fakeRaidId = 0, 0, 0, 0

UnitStyles.StyleBossFrames = function(self, unit, id, layout, ...)
	if (not id) then
		fakeBossId = fakeBossId + 1
		id = fakeBossId
	end
	return StyleSmallFrame(self, unit, id, layout, ...)
end

UnitStyles.StylePartyFrames = function(self, unit, id, layout, ...)
	if (not id) then
		fakePartyId = fakePartyId + 1
		id = fakePartyId
	end
	return StylePartyFrame(self, unit, id, layout, ...)
end

UnitStyles.StyleRaidFrames = function(self, unit, id, layout, ...)
	if (not id) then
		fakeRaidId = fakeRaidId + 1
		id = fakeRaidId
	end
	return StyleRaidFrame(self, unit, id, layout, ...)
end

-----------------------------------------------------------
-----------------------------------------------------------
-- Modules
-----------------------------------------------------------
-----------------------------------------------------------

-----------------------------------------------------------
-- Player
-----------------------------------------------------------
UnitFramePlayer.OnInit = function(self)
	local theme = GetLayoutID()
	if (theme ~= "Azerite") then
		return self:SetUserDisabled(true)
	end

	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	-- How this is called:
	-- local frame = self:SpawnUnitFrame(unit, parent, styleFunc, ...) -- styleFunc(frame, unit, id, ...)
	self.frame = self:SpawnUnitFrame("player", "UICenter", UnitStyles.StylePlayerFrame, self.layout, self)
	self:SpawnTempEnchantFrames()

	-- Apply the aura filter
	local auras = self.frame.Auras
	if (auras) then
		--local filterMode = Core.db.auraFilter
		--auras.enableSlackMode = filterMode == "slack" or filterMode == "spam"
		--auras.enableSpamMode = filterMode == "spam"
		local auraFilterLevel = Core.db.auraFilterLevel
		auras.enableSlackMode = Private.IsForcingSlackAuraFilterMode() or (auraFilterLevel == 1) or (auraFilterLevel == 2)
		auras.enableSpamMode = (auraFilterLevel == 2)
		if (self.db.enableAuras) then
			auras:ForceUpdate()
		end
	end

	self.frame.EnableManaOrb = function()
		if (self.frame.ExtraPower) and (self.frame.Power) then
			self.frame.Power.ignoredResource = self.layout.PowerIgnoredResource
			self.frame.Power:ForceUpdate()
			self.frame:EnableElement("ExtraPower")
			self.frame.ExtraPower:ForceUpdate()
		end
	end

	self.frame.DisableManaOrb = function()
		if (self.frame.ExtraPower) and (self.frame.Power) then
			self.frame.Power.ignoredResource = nil
			self.frame.Power:ForceUpdate()
			self.frame:DisableElement("ExtraPower")
		end
	end

	if (not self.db.enablePlayerManaOrb) then
		self.frame:DisableManaOrb()
	end

	self.frame.EnableAuras = function()
		if (self.frame.Auras) then
			self.frame:EnableElement("Auras")
			self.frame.Auras:ForceUpdate()
		end
	end

	self.frame.DisableAuras = function()
		if (self.frame.Auras) then
			self.frame:DisableElement("Auras")
		end
	end

	if (not self.db.enableAuras) then
		self.frame:DisableAuras()
	end

	-- Create a secure proxy updater for the menu system
	local callbackFrame = CreateSecureCallbackFrame(self, self.frame, self.db, SECURE.Player_SecureCallback)
end

UnitFramePlayer.OnEnable = function(self)
	if (not self.frame) then
		return
	end
	self:RegisterEvent("PLAYER_ALIVE", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("DISABLE_XP_GAIN", "OnEvent")
	self:RegisterEvent("ENABLE_XP_GAIN", "OnEvent")
	self:RegisterEvent("PLAYER_LEVEL_UP", "OnEvent")
	self:RegisterEvent("PLAYER_XP_UPDATE", "OnEvent")
	self:RegisterMessage("GP_AURA_FILTER_MODE_CHANGED", "OnEvent")
end

UnitFramePlayer.OnEvent = function(self, event, ...)
	if (not self.frame) then
		return
	end
	if (event == "PLAYER_ENTERING_WORLD") then
		if (self.db.enablePlayerManaOrb) then
			self.frame:EnableManaOrb()
		else
			self.frame:DisableManaOrb()
		end
		if (self.db.enableAuras) then
			self.frame:EnableAuras()
		else
			self.frame:DisableAuras()
		end
	elseif (event == "PLAYER_LEVEL_UP") then
		local level = ...
		if (level and (level ~= PlayerLevel)) then
			PlayerLevel = level
		else
			local level = UnitLevel("player")
			if (level ~= PlayerLevel) then
				PlayerLevel = level
			end
		end
	elseif (event == "GP_AURA_FILTER_MODE_CHANGED") then
		local auras = self.frame.Auras
		if (auras) then
			local filterMode = ...
			auras.enableSlackMode = filterMode == "slack" or filterMode == "spam"
			auras.enableSpamMode = filterMode == "spam"
			if (self.db.enableAuras) then
				auras:ForceUpdate()
			end
		end
	end
	if (self.frame.PostUpdateTextures) then
		self.frame:PostUpdateTextures(PlayerLevel)
	end
end

local DAY, HOUR, MINUTE = 86400, 3600, 60
local formatTime = function(time)
	if (time > DAY) then -- more than a day
		return "%.0f%s", math_ceil(time / DAY), "d"
	elseif (time > HOUR) then -- more than an hour
		return "%.0f%s", math_ceil(time / HOUR), "h"
	elseif (time > MINUTE) then -- more than a minute
		return "%.0f%s", math_ceil(time / MINUTE), "m"
	elseif (time > 5) then
		return "%.0f", math_ceil(time)
	elseif (time > .9) then
		return "|cffff8800%.0f|r", math_ceil(time)
	elseif (time > .05) then
		return "|cffff0000%.0f|r", time*10 - time*10%1
	else
		return ""
	end
end

-- Temporary Weapon Enchants!
-- These exist in both Retail and Classic
UnitFramePlayer.SpawnTempEnchantFrames = function(self)

	self.tempEnchantButtons = {
		self.frame:CreateFrame("Button", nil, "SecureActionButtonTemplate"),
		self.frame:CreateFrame("Button", nil, "SecureActionButtonTemplate"),
		self.frame:CreateFrame("Button", nil, "SecureActionButtonTemplate")
	}

	-- Style them
	for i,button in ipairs(self.tempEnchantButtons) do

		button:SetSize(30,30)
		button:Place("BOTTOMLEFT", "UICenter", "BOTTOMLEFT", 20, 115 + (40*(i-1)))
		button:SetAttribute("type", "cancelaura")
		button:SetAttribute("target-slot", i+15)
		button:RegisterForClicks("RightButtonUp")

		local border = button:CreateFrame("Frame")
		border:SetSize(30+10, 30+10)
		border:SetPoint("CENTER", 0, 0)
		border:SetBackdrop({ edgeFile = GetMedia("aura_border"), edgeSize = 12 })
		border:SetBackdropColor(0,0,0,0)
		border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
		button.Border = border

		local icon = button:CreateTexture()
		icon:SetDrawLayer("BACKGROUND")
		icon:ClearAllPoints()
		icon:SetPoint("CENTER",0,0)
		icon:SetSize(30-6, 30-6)
		icon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
		button.Icon = icon

		local count = border:CreateFontString()
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", 9, -6)
		count:SetFontObject(GetFont(12, true))
		count:SetTextColor(Colors.normal[1], Colors.normal[2], Colors.normal[3], .85)
		button.Count = count

		local time = border:CreateFontString()
		time:ClearAllPoints()
		time:SetPoint("BOTTOM", 0, -3)
		time:SetFontObject(GetFont(11, true))
		time:SetTextColor(Colors.normal[1], Colors.normal[2], Colors.normal[3], .85)
		button.Time = time

		-- MainHand, OffHand, Ranged = 16,17,18
		button:SetID(i+15)

		button.OnEnter = function(self)
			if (GameTooltip:IsForbidden()) then
				return
			end
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			--GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
			GameTooltip:SetInventoryItem("player", self:GetID())
		end

		button.OnLeave = function(self)
			if (GameTooltip:IsForbidden()) then
				return
			end
			GameTooltip:Hide()
		end

		button.OnUpdate = function(self)
			if (GameTooltip:IsForbidden()) then
				return
			end
			if (GameTooltip:IsOwned(self)) then
				self:OnEnter()
			end
		end

		button:SetScript("OnEnter", button.OnEnter)
		button:SetScript("OnLeave", button.OnLeave)
		button:SetScript("OnUpdate", button.OnUpdate)

	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateTempEnchantFrames")
	self:RegisterEvent("UNIT_INVENTORY_CHANGED", "UpdateTempEnchantFrames")

	local updateFrame = CreateFrame("Frame", nil, self.frame)
	updateFrame:SetScript("OnUpdate", function(this, elapsed)
		this.elapsed = (this.elapsed or 0) - elapsed
		if (this.elapsed < 0) then
			this.elapsed = 0.1
			self:UpdateTempEnchantFrames()
		end
	end)

end

UnitFramePlayer.UpdateTempEnchantFrames = function(self)
	local hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID, hasOffHandEnchant, offHandExpiration, offHandCharges, offHandEnchantId, hasRangedEnchant, rangedEnchantExpiration, rangedCharges, rangedEnchantID = GetWeaponEnchantInfo()

	if (hasMainHandEnchant) then
		local button = self.tempEnchantButtons[1]
		button.Icon:SetTexture(GetInventoryItemTexture("player", button:GetID()))
		button:SetAlpha(1)

		if (mainHandExpiration) then
			self.tempEnchantButtons[1].Time:SetFormattedText(formatTime(mainHandExpiration/1000))
		else
			self.tempEnchantButtons[1].Time:SetText("")
		end

	else
		self.tempEnchantButtons[1]:SetAlpha(0)
		self.tempEnchantButtons[1].Time:SetText("")
	end

	if (hasOffHandEnchant) then
		local button = self.tempEnchantButtons[2]
		button.Icon:SetTexture(GetInventoryItemTexture("player", button:GetID()))
		button:SetAlpha(1)

		if (offHandExpiration) then
			self.tempEnchantButtons[2].Time:SetFormattedText(formatTime(offHandExpiration/1000))
		else
			self.tempEnchantButtons[2].Time:SetText("")
		end

	else
		self.tempEnchantButtons[2]:SetAlpha(0)
		self.tempEnchantButtons[2].Time:SetText("")
	end

	if (hasRangedEnchant) then
		local button = self.tempEnchantButtons[3]
		button.Icon:SetTexture(GetInventoryItemTexture("player", button:GetID()))
		button:SetAlpha(1)

		if (rangedEnchantExpiration) then
			self.tempEnchantButtons[3].Time:SetFormattedText(formatTime(rangedEnchantExpiration/1000))
		else
			self.tempEnchantButtons[3].Time:SetText("")
		end

	else
		self.tempEnchantButtons[3]:SetAlpha(0)
		self.tempEnchantButtons[3].Time:SetText("")
	end
end

UnitFramePlayerHUD.OnInit = function(self)
	local theme = GetLayoutID()
	if (theme ~= "Azerite") then
		return self:SetUserDisabled(true)
	end

	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	self.frame = self:SpawnUnitFrame("player", "UICenter", function(frame, unit, id, _, ...)
		return UnitStyles.StylePlayerHUDFrame(frame, unit, id, self.layout, ...)
	end)

	-- Create a secure proxy updater for the menu system
	local callbackFrame = CreateSecureCallbackFrame(self, self.frame, self.db, SECURE.HUD_SecureCallback)
	callbackFrame.UpdateCastBar = function() self:UpdateCastBarVisibility(self:GetCastBarVisibility()) end
	callbackFrame:SetAttribute("forceDisableClassPower", self:IsAddOnEnabled("SimpleClassPower"))
end

UnitFramePlayerHUD.OnEnable = function(self)
	if (not self.frame) then
		return
	end

	-- Handle castbar visibility
	self:RegisterEvent("CVAR_UPDATE", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
	self:RegisterMessage("GP_CVAR_CHANGED", "OnEvent")
	self:UpdateCastBarVisibility(self:GetCastBarVisibility())

	-- Handle classpower visibility
	-- *Why is this failing? 2022-05-05 issue #8
	if (self.frame.ClassPower) then
		if (not self.db.enableClassPower) or (self:IsAddOnEnabled("SimpleClassPower")) then
			self.frame:DisableElement("ClassPower")
		end
	end
end

UnitFramePlayerHUD.OnEvent = function(self, event, ...)
	if (not self.frame) then
		return
	end

	local shouldEnable
	if (event == "GP_CVAR_CHANGED") then
		local arg1, arg2 = ...
		if (not arg) or (string_lower(arg1) ~= string_lower("nameplateShowSelf")) then
			return
		end
		shouldEnable = ((self.db.enableCast) and ((arg2 == "0") or (arg2 == 0) or (not arg2)))

	elseif (event == "CVAR_UPDATE") then
		local arg1, arg2 = ...

		-- Bail out for irrelevant cvar changes.
		if (arg1 ~= "DISPLAY_PERSONAL_RESOURCE") then
			return
		end

		-- Check for event args, as the real CVar isn't updated yet.
		shouldEnable = ((arg2 == "0") and (self.db.enableCast))

	else

		-- Shouldn't in theory be needing this down here, yet...
		if (event == "PLAYER_ENTERING_WORLD") then
			if (self:IsAddOnEnabled("SimpleClassPower")) then
				self.frame:DisableElement("ClassPower")
			end
		end

		-- Use the standard check for other events.
		shouldEnable = self:GetCastBarVisibility()
	end

	-- Toggle the element.
	self:UpdateCastBarVisibility(shouldEnable)
end

UnitFramePlayerHUD.GetCastBarVisibility = function(self)
	if (not self.db.enableCast) then
		return false
	elseif (not GetCVarBool("nameplateShowSelf")) and (self.db.enableCast) then
		return true
	end
end

UnitFramePlayerHUD.UpdateCastBarVisibility = function(self, shouldEnable)
	if (not self.frame) or (not self.frame.Cast) then
		return
	end
	-- Only react to explicit booleans, not nil.
	if (shouldEnable == true) then
		self.frame:EnableElement("Cast")
		self.frame.Cast:ForceUpdate()
	elseif (shouldEnable == false) then
		self.frame:DisableElement("Cast")
	end
end

-----------------------------------------------------------
-- Target
-----------------------------------------------------------
UnitFrameTarget.OnInit = function(self)
	local theme = GetLayoutID()
	if (theme ~= "Azerite") then
		return self:SetUserDisabled(true)
	end

	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	-- How this is called:
	-- local frame = self:SpawnUnitFrame(unit, parent, styleFunc, ...) -- styleFunc(frame, unit, id, ...)
	self.frame = self:SpawnUnitFrame("target", "UICenter", UnitStyles.StyleTargetFrame, self.layout, self)

	-- Apply the aura filter
	local auras = self.frame.Auras
	if (auras) then
		--local filterMode = Core.db.auraFilter
		--auras.enableSlackMode = filterMode == "slack" or filterMode == "spam"
		--auras.enableSpamMode = filterMode == "spam"
		local auraFilterLevel = Core.db.auraFilterLevel
		auras.enableSlackMode = Private.IsForcingSlackAuraFilterMode() or (auraFilterLevel == 1) or (auraFilterLevel == 2)
		auras.enableSpamMode = (auraFilterLevel == 2)
		if (self.db.enableAuras) then
			auras:ForceUpdate()
		end
	end

	self.frame.EnableAuras = function()
		if (self.frame.Auras) then
			self.frame:EnableElement("Auras")
			self.frame.Auras:ForceUpdate()
		end
	end

	self.frame.DisableAuras = function()
		if (self.frame.Auras) then
			self.frame:DisableElement("Auras")
		end
	end

	if (not self.db.enableAuras) then
		self.frame:DisableAuras()
	end

	-- Create a secure proxy updater for the menu system
	local callbackFrame = CreateSecureCallbackFrame(self, self.frame, self.db, SECURE.Target_SecureCallback)

end

UnitFrameTarget.OnEnable = function(self)
	if (not self.frame) then
		return
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
	self:RegisterMessage("GP_AURA_FILTER_MODE_CHANGED", "OnEvent")
end

UnitFrameTarget.OnEvent = function(self, event, ...)
	if (not self.frame) then
		return
	end
	if (event == "PLAYER_TARGET_CHANGED") then
		if (UnitExists("target")) then
			if (self.frame.PostUpdateTextures) then
				self.frame:PostUpdateTextures()
			end
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		if (self.db.enableAuras) then
			self.frame:EnableAuras()
		else
			self.frame:DisableAuras()
		end
	elseif (event == "GP_AURA_FILTER_MODE_CHANGED") then
		local auras = self.frame.Auras
		if (auras) then
			local filterMode = ...
			auras.enableSlackMode = filterMode == "slack" or filterMode == "spam" or nil
			auras.enableSpamMode = filterMode == "spam" or nil
			auras:ForceUpdate()
		end
	end
end

-----------------------------------------------------------
-- Focus
-----------------------------------------------------------
if (UnitFrameFocus) then
	UnitFrameFocus.OnInit = function(self)
		local theme = GetLayoutID()
		if (theme ~= "Azerite") then
			return self:SetUserDisabled(true)
		end

		self.layout = GetLayout(self:GetName())
		if (not self.layout) then
			return self:SetUserDisabled(true)
		end

		-- How this is called:
		-- local frame = self:SpawnUnitFrame(unit, parent, styleFunc, ...) -- styleFunc(frame, unit, id, ...)
		self.frame = self:SpawnUnitFrame("focus", "UICenter", UnitStyles.StyleFocusFrame, self.layout, self)
	end
end

-----------------------------------------------------------
-- Pet
-----------------------------------------------------------
UnitFramePet.OnInit = function(self)
	local theme = GetLayoutID()
	if (theme ~= "Azerite") then
		return self:SetUserDisabled(true)
	end

	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	-- How this is called:
	-- local frame = self:SpawnUnitFrame(unit, parent, styleFunc, ...) -- styleFunc(frame, unit, id, ...)
	self.frame = self:SpawnUnitFrame("pet", "UICenter", UnitStyles.StylePetFrame, self.layout, self)
end

-----------------------------------------------------------
-- Target of Target
-----------------------------------------------------------
UnitFrameToT.OnInit = function(self)
	local theme = GetLayoutID()
	if (theme ~= "Azerite") then
		return self:SetUserDisabled(true)
	end

	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	-- How this is called:
	-- local frame = self:SpawnUnitFrame(unit, parent, styleFunc, ...) -- styleFunc(frame, unit, id, ...)
	self.frame = self:SpawnUnitFrame("targettarget", "UICenter", UnitStyles.StyleToTFrame, self.layout, self)

	-- Our frame is sometimes hidden when the unit exists,
	-- so we're using this system to let other modules piggyback on this one's decisions.
	self.frame:HookScript("OnShow", function(self) self:SendMessage("GP_UNITFRAME_TOT_SHOWN") end)
	self.frame:HookScript("OnHide", function(self) self:SendMessage("GP_UNITFRAME_TOT_HIDDEN") end)
end

-----------------------------------------------------------
-- Party
-----------------------------------------------------------
UnitFrameParty.OnInit = function(self)
	local theme = GetLayoutID()
	if (theme ~= "Azerite") then
		return self:SetUserDisabled(true)
	end

	local dev --= true

	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	self.frame = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.frame:SetSize(unpack(self.layout.Size))
	self.frame:Place(unpack(self.layout.Place))

	self.frame.healerAnchor = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.frame.healerAnchor:SetSize(unpack(self.layout.Size))
	self.frame.healerAnchor:Place(unpack(self.layout.AlternatePlace))
	self.frame:SetFrameRef("HealerModeAnchor", self.frame.healerAnchor)

	self.frame:Execute(SECURE.FrameTable_Create)
	self.frame:SetAttribute("useAlternateLayout", GetConfig(ADDON).enableHealerMode)
	self.frame:SetAttribute("sortFrames", SECURE.Party_SortFrames:format(
		self.layout.GroupAnchor,
		self.layout.GrowthX,
		self.layout.GrowthY,
		self.layout.AlternateGroupAnchor,
		self.layout.AlternateGrowthX,
		self.layout.AlternateGrowthY
	))
	self.frame:SetAttribute("_onattributechanged", SECURE.Party_OnAttribute)

	-- Hide it in raids of 6 or more players
	-- Use an attribute driver to do it so the normal unitframe visibility handler can remain unchanged
	self.frame:SetAttribute("visDriver", dev and "[@player,exists]show;hide" or "[@raid6,exists]hide;[group]show;hide")
	RegisterAttributeDriver(self.frame, "state-vis", self.db.enablePartyFrames and self.frame:GetAttribute("visDriver") or "hide")

	local style = function(frame, unit, id, _, ...)
		return UnitStyles.StylePartyFrames(frame, unit, id, self.layout, ...)
	end
	for i = 1,4 do
		local frame = self:SpawnUnitFrame(dev and "player" or "party"..i, self.frame, style)

		-- Reference the frame in Lua
		self.frame[tostring(i)] = frame

		-- Reference the frame in the secure environment
		self.frame:SetFrameRef("CurrentFrame", frame)
		self.frame:Execute(SECURE.FrameTable_InsertCurrentFrame)
	end

	self.frame:Execute(self.frame:GetAttribute("sortFrames"))

	-- Create a secure proxy updater for the menu system
	CreateSecureCallbackFrame(self, self.frame, self.db, SECURE.Party_SecureCallback:format(visDriver))
end

-----------------------------------------------------------
-- Raid
-----------------------------------------------------------
UnitFrameRaid.OnInit = function(self)
	local theme = GetLayoutID()
	if (theme ~= "Azerite") then
		return self:SetUserDisabled(true)
	end

	local dev --= true

	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	self.frame = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.frame:SetSize(1,1)
	self.frame:Place(unpack(self.layout.Place))
	self.frame.healerAnchor = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.frame.healerAnchor:SetSize(1,1)
	self.frame.healerAnchor:Place(unpack(self.layout.AlternatePlace))
	self.frame:SetFrameRef("HealerModeAnchor", self.frame.healerAnchor)
	self.frame:Execute(SECURE.FrameTable_Create)
	self.frame:SetAttribute("useAlternateLayout", GetConfig(ADDON).enableHealerMode)
	self.frame:SetAttribute("enableRaidFrames", self.db.enableRaidFrames)
	self.frame:SetAttribute("sortFrames", SECURE.Raid_SortFrames:format(
		self.layout.GroupSizeNormal,
		self.layout.GrowthXNormal,
		self.layout.GrowthYNormal,
		self.layout.GrowthYNormalHealerMode,
		self.layout.GroupGrowthXNormal,
		self.layout.GroupGrowthYNormal,
		self.layout.GroupGrowthYNormalHealerMode,
		self.layout.GroupColsNormal,
		self.layout.GroupRowsNormal,
		self.layout.GroupAnchorNormal,
		self.layout.GroupAnchorNormalHealerMode,

		self.layout.GroupSizeEpic,
		self.layout.GrowthXEpic,
		self.layout.GrowthYEpic,
		self.layout.GrowthYEpicHealerMode,
		self.layout.GroupGrowthXEpic,
		self.layout.GroupGrowthYEpic,
		self.layout.GroupGrowthYEpicHealerMode,
		self.layout.GroupColsEpic,
		self.layout.GroupRowsEpic,
		self.layout.GroupAnchorEpic,
		self.layout.GroupAnchorEpicHealerMode
	))
	self.frame:SetAttribute("_onattributechanged", SECURE.Raid_OnAttribute)

	-- Only show it in raids, not parties.
	-- Use an attribute driver to do it so the normal unitframe visibility handler can remain unchanged
	self.frame:SetAttribute("visDriver", dev and "[@player,exists]show;hide" or "[group:raid]show;hide")
	RegisterAttributeDriver(self.frame, "state-vis", self.db.enableRaidFrames and self.frame:GetAttribute("visDriver") or "hide")

	local style = function(frame, unit, id, _, ...)
		return UnitStyles.StyleRaidFrames(frame, unit, id, self.layout, ...)
	end
	for i = 1,40 do
		local frame = self:SpawnUnitFrame(dev and "player" or "raid"..i, self.frame, style)
		self.frame[tostring(i)] = frame
		self.frame:SetFrameRef("CurrentFrame", frame)
		self.frame:Execute(SECURE.FrameTable_InsertCurrentFrame)
	end

	-- Register the layout driver
	RegisterAttributeDriver(self.frame, "state-layout", dev and "[@target,exists]epic;normal" or "[@raid26,exists]epic;normal")

	-- Do an initial sorting, for visibility.
	self.frame:Execute(self.frame:GetAttribute("sortFrames"))

	-- Create a secure proxy updater for the menu system
	CreateSecureCallbackFrame(self, self.frame, self.db, SECURE.Raid_SecureCallback)
end

-----------------------------------------------------------
-- Boss
-----------------------------------------------------------
-- These don't really exist in classic, right?
UnitFrameBoss.OnInit = function(self)
	local theme = GetLayoutID()
	if (theme ~= "Azerite") then
		return self:SetUserDisabled(true)
	end

	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	self.frame = {}

	local style = function(frame, unit, id, _, ...)
		return UnitStyles.StyleBossFrames(frame, unit, id, self.layout, ...)
	end
	for i = 1,5 do
		self.frame[tostring(i)] = self:SpawnUnitFrame("boss"..i, "UICenter", style)
	end
end
