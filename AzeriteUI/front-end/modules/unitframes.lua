local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local UnitFrames = Core:NewModule("ModuleForge::UnitFrames", "LibDB", "LibMessage", "LibEvent", "LibFrame", "LibUnitFrame", "LibTime", "LibForge")

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetDefaults = Private.GetDefaults
local GetLayout = Private.GetLayout
local GetLayoutID = Private.GetLayoutID
local GetSchematic = Private.GetSchematic
local HasSchematic = Private.HasSchematic

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

UnitFrames.OnInit = function(self)
	if (not HasSchematic("ModuleForge::UnitFrames")) then
		return self:SetUserDisabled(true)
	end
	self.db = GetConfig(self:GetName())
	self.layoutID = GetLayoutID()
	self:SubForge(GetSchematic("ModuleForge::UnitFrames"), "OnInit")
end

UnitFrames.OnEnable = function(self)
	self:SubForge(GetSchematic("ModuleForge::UnitFrames"), "OnEnable")
end
