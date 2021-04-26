local ADDON, Private = ...

local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:GetModule("ActionBarMain")

