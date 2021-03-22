local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("ModuleForge::ExtraBars", "LibDB", "LibForge")

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
	if (not Private.HasSchematic("ModuleForge::ExtraBars")) then
		return self:SetUserDisabled(true)
	end
	self.layoutID = Private.GetLayoutID()
	self:SubForge(Private.GetSchematic("ModuleForge::ExtraBars"), "OnInit")
end 

Module.OnEnable = function(self)
	self:SubForge(Private.GetSchematic("ModuleForge::ExtraBars"), "OnEnable")
end


