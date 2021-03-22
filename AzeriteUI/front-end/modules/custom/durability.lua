local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Custom Durability Widget
local Module = Core:NewModule("Durability", "LibDurability")

Module.OnInit = function(self)
	local layout = Private.GetLayout(self:GetName())
	if (not layout) then
		return self:SetUserDisabled(true)
	end
	self:GetDurabilityWidget():Place(unpack(layout.Place))
end
