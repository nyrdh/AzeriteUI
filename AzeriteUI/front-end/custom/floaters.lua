local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end
Core:NewModule("FloaterHUD", "LibDurability").OnInit = function(self)
	local layout = Private.GetLayout(self:GetName())
	local widget = self:GetDurabilityWidget()
	widget:Place(unpack(layout.Place))
end
