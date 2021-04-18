local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local UnitFrames = Core:NewModule("ModuleForge::UnitFrames", "LibDB", "LibMessage", "LibEvent", "LibFrame", "LibUnitFrame", "LibTime", "LibForge")

-- Lua API
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local string_format = string.format
local unpack = unpack

-- WoW API
local UnitPowerMax = UnitPowerMax

-- Player Class Constant
local PlayerClass = select(2, UnitClass("player"))

-- Power type constants
-- Sourced from BlizzardInterfaceCode/AddOns/Blizzard_APIDocumentation/UnitDocumentation.lua
local SPELL_POWER_CHI = Enum.PowerType.Chi or 12

-- Private API
local Colors = Private.Colors
local GetAuraFilter = Private.GetAuraFilter
local GetConfig = Private.GetConfig
local GetDefaults = Private.GetDefaults
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia
local GetLayout = Private.GetLayout
local GetLayoutID = Private.GetLayoutID
local GetSchematic = Private.GetSchematic
local HasSchematic = Private.HasSchematic
local IsClassic = Private.IsClassic
local IsRetail = Private.IsRetail
local IsWinterVeil = Private.IsWinterVeil
local IsLoveFestival = Private.IsLoveFestival

local SECURE = {
	MenuCallback = [=[
		if name then 
			name = string.lower(name); 
		end 
		
		-- Current theme prefix. Use caps.
		local prefix = "Legacy::"; 

		-- 'name' appears to be turned to lowercase by the restricted environment(?), 
		-- but we're doing it manually anyway, just to avoid problems. 
		if (name) then 
			name = string.lower(name); 
			name = name:gsub(string.lower(prefix),""); -- kill off theme prefix
		end 

		if (name == "change-enablepartyframes") then 
			self:SetAttribute(prefix.."EnablePartyFrames", value); 

			local PartyHeader = self:GetFrameRef("PartyHeader");
			PartyHeader:SetAttribute(prefix.."EnablePartyFrames", value); -- store the setting on the header too
			UnregisterAttributeDriver(PartyHeader, "state-vis"); 

			if (value) then 
				local visDriver = self:GetAttribute("visDriver"); -- get the correct visibility driver
				RegisterAttributeDriver(PartyHeader, "state-vis", "show"); 
			else 
				RegisterAttributeDriver(PartyHeader, "state-vis", "hide"); 
			end 
		
		elseif (name == "change-enableraidframes") then 
			self:SetAttribute(prefix.."EnableRaidFrames", value); -- store the setting

			local RaidHeader = self:GetFrameRef("RaidHeader"); 
			RaidHeader:SetAttribute(prefix.."EnableRaidFrames", value); -- store the setting on the header too
			UnregisterAttributeDriver(RaidHeader, "state-vis"); -- kill off the old visibility driver

			if (value) then 
				RegisterAttributeDriver(RaidHeader, "state-vis", "show"); 
			else 
				RegisterAttributeDriver(RaidHeader, "state-vis", "hide"); 
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
		end
	]=]
} 

-- Utility Functions
-----------------------------------------------------------
-- General aura button post creating forge
local Aura_PostCreate = function(element, button)
	if (element._owner:Forge(button, GetSchematic("WidgetForge::AuraButton::Large"))) then
		return 
	end
end

-- General aura border- and icon coloring.
local Aura_PostUpdate = function(element, button)
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

-- Create a secure callback frame our menu system can use
-- to alter unitframe setting while engaged in combat.
-- TODO: Make this globally accessible to the entire addon, 
-- and move all these little creation methods away from the modules.
local CreateSecureCallbackFrame = function(module, owner, db, script)

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

-- Module API
-----------------------------------------------------------
UnitFrames.GetDB = function(self, key)
	if (not self.layoutID) or (not self.db) then
		return
	end
	return self.db[self.layoutID.."::"..key]
end

UnitFrames.SetDB = function(self, key, value)
	if (not self.layoutID) or (not self.db) then
		return
	end
	self.db[self.layoutID.."::"..key] = value
end

UnitFrames.SpawnUnitFrames = function(self)
	for _,queuedEntry in ipairs({ 
		-- "unit", [UnitForge::]"ID"

		-- Left Side
		{ "player", "Player" }, 
		{ "pet", "Pet" }, 
		{ "focus", "Focus" }, 
		--{ "focustarget", "Focus" }, 

		-- Centered
		{ "player", "PlayerHUD" }, 
		{ "vehicle", "PlayerInVehicle" }, 
		-- { "target", "PlayerInVehicleTarget" },

		-- Right Side
		{ "target", "Target" },
		{ "targettarget", "ToT" },

		-- Party (2-5 Players)
		{ "party1", "Party" }, { "party2", "Party" }, { "party3", "Party" }, { "party4", "Party" },

		-- Testing
		--{ "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" },
		--{ "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" },
		--{ "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" },
		--{ "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" },
		--{ "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" },
		--{ "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" },
		--{ "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" },
		--{ "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" }, { "player", "Raid" },

		-- Raid (6-40 Players)
		{ "raid1",  "Raid" }, { "raid2",  "Raid" }, { "raid3",  "Raid" }, { "raid4",  "Raid" }, { "raid5",  "Raid" },
		{ "raid6",  "Raid" }, { "raid7",  "Raid" }, { "raid8",  "Raid" }, { "raid9",  "Raid" }, { "raid10", "Raid" },
		{ "raid11", "Raid" }, { "raid12", "Raid" }, { "raid13", "Raid" }, { "raid14", "Raid" }, { "raid15", "Raid" },
		{ "raid16", "Raid" }, { "raid17", "Raid" }, { "raid18", "Raid" }, { "raid19", "Raid" }, { "raid20", "Raid" },
		{ "raid21", "Raid" }, { "raid22", "Raid" }, { "raid23", "Raid" }, { "raid24", "Raid" }, { "raid25", "Raid" },
		{ "raid26", "Raid" }, { "raid27", "Raid" }, { "raid28", "Raid" }, { "raid29", "Raid" }, { "raid30", "Raid" },
		{ "raid31", "Raid" }, { "raid32", "Raid" }, { "raid33", "Raid" }, { "raid34", "Raid" }, { "raid35", "Raid" },
		{ "raid36", "Raid" }, { "raid37", "Raid" }, { "raid38", "Raid" }, { "raid39", "Raid" }, { "raid40", "Raid" },

		-- Boss
		{ "boss1", "Boss" }, { "boss2", "Boss" }, { "boss3", "Boss" }, { "boss4", "Boss" }, { "boss5", "Boss" }

	}) do 
		local unit,schematicID = unpack(queuedEntry)
		if (HasSchematic("UnitForge::"..schematicID)) then
			local parent
			if (schematicID == "Party") then
				parent = self.partyHeader
			elseif (schematicID == "Raid") then
				parent = self.raidHeader
			end	
			local frame = self:SpawnUnitFrame(unit, parent or "UICenter", function(self, unit)
				self:Forge(GetSchematic("UnitForge::"..schematicID))
			end)
			self.Frames[frame] = unit
			if (not frame.ignoreExplorerMode) then
				self.ExplorerModeFrameAnchors[#self.ExplorerModeFrameAnchors + 1] = frame
			end
		end
	end
end

UnitFrames.GetExplorerModeFrameAnchors = function(self)
	return unpack(self.ExplorerModeFrameAnchors)
end

-- Module Core
-----------------------------------------------------------
UnitFrames.OnEvent = function(self, event, ...)
	if (event == "GP_AURA_FILTER_MODE_CHANGED") then 
		for frame,unit in pairs(self.Frames) do
			local auras = frame.Auras
			if (auras) then
				local filterMode = ...
				auras.enableSlackMode = filterMode == "slack" or filterMode == "spam"
				auras.enableSpamMode = filterMode == "spam"
				auras:ForceUpdate()
			end
		end
	end
end

UnitFrames.OnInit = function(self)
	local theme = GetLayoutID()
	if (theme ~= "Legacy") then
		return self:SetUserDisabled(true)
	end

	self.db = GetConfig(self:GetName())
	self.layoutID = theme
	self.Frames = {}
	self.ExplorerModeFrameAnchors = {}

	-- Header frame for 2-5 player group frames
	self.partyHeader = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.partyHeader:SetAttribute("_onattributechanged", SECURE.Party_OnAttribute)
	self.partyHeader:SetShown(self:GetDB("EnablepartyFrames"))

	-- Header frame for 6-40 player group frames
	self.raidHeader = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.raidHeader:SetAttribute("_onattributechanged", SECURE.Raid_OnAttribute)
	self.raidHeader:SetShown(self:GetDB("EnableRaidFrames"))

	-- Menu callback frame.
	self.frame = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	self.frame:SetFrameRef("PartyHeader", self.partyHeader)
	self.frame:SetFrameRef("RaidHeader", self.raidHeader)

	self:SpawnUnitFrames()

	-- Create secure proxy updaters for the menu system
	local proxy = CreateSecureCallbackFrame(self, self.frame, self.db, SECURE.MenuCallback)
	proxy:SetFrameRef("PartyHeader", self.partyHeader)
	proxy:SetFrameRef("RaidHeader", self.raidHeader)
end

UnitFrames.OnEnable = function(self)
	self:RegisterMessage("GP_AURA_FILTER_MODE_CHANGED", "OnEvent")
end
