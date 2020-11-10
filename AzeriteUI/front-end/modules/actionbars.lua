local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("ActionBarMain", "LibEvent", "LibMessage", "LibDB", "LibFrame", "LibSound", "LibTooltip", "LibSecureButton", "LibWidgetContainer", "LibPlayerData", "LibClientBuild", "LibForge", "LibInputMethod")

Module.OnInit = function(self)
	-- Deprecated settings keep piling up in this one.
	self:PurgeSavedSettingFromAllProfiles(self:GetName(), "editMode", "buttonsPrimary", "buttonsComplimentary", "enableComplimentary", "enableStance", "enablePet", "showBinds", "showCooldown", "showCooldownCount", "showNames", "visibilityPrimary", "visibilityComplimentary", "visibilityStance", "visibilityPet")

	-- Retrieve the module's settings.
	self.db = Private.GetConfig(self:GetName())

	-- Forge the schematic.
	self:SubForge(Private.GetSchematic("ModuleForge::ActionBars"), "OnInit")
end 

Module.OnEnable = function(self)
	self:SubForge(Private.GetSchematic("ModuleForge::ActionBars"), "OnEnable")
end


