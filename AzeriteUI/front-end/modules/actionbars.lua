local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("ActionBarMain", "LibEvent", "LibMessage", "LibDB", "LibFrame", "LibSound", "LibTooltip", "LibSecureButton", "LibWidgetContainer", "LibPlayerData", "LibClientBuild", "LibForge", "LibInputMethod")

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetDefaults = Private.GetDefaults
local GetLayout = Private.GetLayout
local GetLayoutID = Private.GetLayoutID
local GetSchematic = Private.GetSchematic

Module.GetDB = function(self, key)
	if (not self.layoutID) or (not self.db) then
		return
	end
	return self.db[self.layoutID.."::"..key]
end

Module.SetDB = function(self, key, value)
	if (not self.layoutID) or (not self.db) then
		return
	end
	self.db[self.layoutID.."::"..key] = value
end


Module.OnInit = function(self)
	-- Deprecated settings keep piling up in this one.
	self:PurgeSavedSettingFromAllProfiles(self:GetName(), "editMode", "buttonsPrimary", "buttonsComplimentary", "enableComplimentary", "enableStance", "enablePet", "showBinds", "showCooldown", "showCooldownCount", "showNames", "visibilityPrimary", "visibilityComplimentary", "visibilityStance", "visibilityPet")

	self.db = (GetLayoutID() == "Azerite") and GetConfig(self:GetName()) or GetConfig("ModuleForge::ActionBars")
	self.layoutID = GetLayoutID()
	self:SubForge(GetSchematic("ModuleForge::ActionBars"), "OnInit")
end 

Module.OnEnable = function(self)
	self:SubForge(GetSchematic("ModuleForge::ActionBars"), "OnEnable")
end


