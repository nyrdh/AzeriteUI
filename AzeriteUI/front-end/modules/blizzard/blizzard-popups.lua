local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Blizzard PopUp Styling
local Module = Core:NewModule("BlizzardPopupStyling", "LibBlizzard")

Module.OnInit = function(self)

	local layout = Private.GetLayout(self:GetName())
	if (not layout) then
		return self:SetUserDisabled(true)
	end

	self:StyleUIWidget("PopUps", 
		layout.PopupBackdrop, 
		layout.PopupBackdropOffsets,
		layout.PopupBackdropColor,
		layout.PopupBackdropBorderColor,
		layout.PopupButtonBackdrop, 
		layout.PopupButtonBackdropOffsets,
		layout.PopupButtonBackdropColor,
		layout.PopupButtonBackdropBorderColor,
		layout.PopupButtonBackdropHoverColor,
		layout.PopupButtonBackdropHoverBorderColor,
		layout.EditBoxBackdrop,
		layout.EditBoxBackdropColor,
		layout.EditBoxBackdropBorderColor,
		layout.EditBoxInsets,
		layout.PopupVerticalOffset
	)
	
end