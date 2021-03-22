local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("BlizzardBagButtons", "LibBlizzard")

Module.OnEnable = function(self)
	-- Blizzard Bag Button Styling
	-- Attaches the bag selection buttons 
	-- to the bottom of the backpack.
	self:StyleUIWidget("BagButtons")
end 
