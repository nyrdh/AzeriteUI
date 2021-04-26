local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("ActionBarMain", "LibDB", "LibForge")

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

Module.UpdateCVars = function(self)
	-- Don't show Blizzard numbers on cooldowns.
	SetCVar("countdownForCooldowns", "0") 
end

Module.OnInit = function(self)
	if (not Private.HasSchematic("ModuleForge::ActionBars")) then
		return self:SetUserDisabled(true)
	end
	self.db = Private.GetConfig("ModuleForge::ActionBars")
	self.layoutID = Private.GetLayoutID()
	self:SubForge(Private.GetSchematic("ModuleForge::ActionBars"), "OnInit")
	
end 

Module.OnEnable = function(self)
	self:SubForge(Private.GetSchematic("ModuleForge::ActionBars"), "OnEnable")
	self:UpdateCVars()
	self:RegisterEvent("VARIABLES_LOADED", "UpdateCVars")
end
