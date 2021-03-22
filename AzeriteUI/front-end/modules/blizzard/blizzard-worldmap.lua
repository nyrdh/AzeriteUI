local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Blizzard WorldMap Styling
local Module = Core:NewModule("BlizzardWorldMap", "LibBlizzard")

Module.OnEnable = function(self)
	self:StyleUIWidget("WorldMap")
end 
