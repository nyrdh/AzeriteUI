local ADDON = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end

local Module = Core:NewModule("BlizzardWorldMap", "LibEvent", "LibBlizzard", "LibClientBuild", "LibSecureHook")
Module:SetIncompatible("ClassicWorldMapEnhanced")
Module:SetIncompatible("Leatrix_Maps")

Module.OnEnable = function(self)
	self:StyleUIWidget("WorldMap")
end 
