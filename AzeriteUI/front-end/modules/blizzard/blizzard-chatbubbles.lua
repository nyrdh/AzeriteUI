local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Blizzard Chat Bubble Styling
local Module = Core:NewModule("ChatBubbles", "LibChatBubble")

Module.OnEnable = function(self)

	-- Enable styling
	self:EnableBubbleStyling()

	-- Kill off any existing post updates,
	-- we don't need them.
	self:SetBubblePostCreateFunc()
	self:SetBubblePostCreateFunc()

	local layout = Private.GetLayout("BlizzardFonts")
	if (layout) then
		-- Set Blizzard Chat Bubble Font
		-- This applies to bubbles when the UI is disabled, or in instances.
		self:SetBlizzardBubbleFontObject(layout.BlizzChatBubbleFont)

		-- Set OUR bubble font. Does not affect blizzard bubbles.
		self:SetBubbleFontObject(layout.ChatBubbleFont)
	end

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