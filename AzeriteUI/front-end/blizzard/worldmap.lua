local ADDON = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end
Core:NewModule("BlizzardWorldMap", "LibEvent", "LibBlizzard", "LibClientBuild", "LibSecureHook").OnEnable = function(self)
	self:StyleUIWidget("WorldMap")
end 
