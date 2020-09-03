local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Blizzard Bag Styling
Core:NewModule("BlizzardBagButtons", "LibBlizzard").OnEnable = function(self)
	self:StyleUIWidget("BagButtons")
end 

-- Blizzard Chat Bubble Styling
Core:NewModule("ChatBubbles", "LibChatBubble").OnEnable = function(self)
	-- Enable styling
	self:EnableBubbleStyling()

	-- Kill off any existing post updates,
	-- we don't need them.
	self:SetBubblePostCreateFunc()
	self:SetBubblePostCreateFunc()

	-- Keep them visible in the world
	self:SetBubbleVisibleInWorld(true)

	-- Keep them visible in combat in the world.
	-- They are styled and unintrusive.
	self:SetBubbleCombatHideInWorld(false)

	-- Keep them visible in instances,
	-- we need them for monster and boss dialog
	-- before boss encounters or in scenarios.
	self:SetBubbleVisibleInInstances(true)

	-- Hide them during combat in instances,
	-- they are unstyled and horribad as hell.
	self:SetBubbleCombatHideInInstances(true)
end 

-- Blizzard PopUp Styling
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

-- Blizzard WorldMap Styling
Core:NewModule("BlizzardWorldMap", "LibBlizzard").OnEnable = function(self)
	self:StyleUIWidget("WorldMap")
end 

-- Custom Durability Widget
Core:NewModule("FloaterHUD", "LibDurability").OnInit = function(self)
	self:GetDurabilityWidget():Place(unpack(Private.GetLayout(self:GetName()).Place))
end
