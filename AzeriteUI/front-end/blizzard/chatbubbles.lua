local ADDON = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end
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
