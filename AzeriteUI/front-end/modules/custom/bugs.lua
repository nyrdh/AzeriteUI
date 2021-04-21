local ADDON, Private = ...

local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Blizzard PopUp Styling
local Module = Core:NewModule("Bugs", "LibEvent")

