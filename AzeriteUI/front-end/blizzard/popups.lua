local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end
Core:NewModule("BlizzardPopupStyling", "LibBlizzard").OnInit = function(self)
	local layout = Private.GetLayout(self:GetName())
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
