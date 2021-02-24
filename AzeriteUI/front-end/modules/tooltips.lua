local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("Tooltips", "LibMessage", "LibEvent", "LibDB", "LibTooltip")

-- Lua API

-- WoW API

-- Private API
local Colors = Private.Colors
local GetLayout = Private.GetLayout

-- This will be called by the library upon creating new tooltips.
Module.PostCreateTooltip = function(self, tooltip)
	if (not self.layout) then 
		return
	end
	tooltip.PostCreateLinePair = self.layout.PostCreateLinePair
	tooltip.PostCreateBar = self.layout.PostCreateBar
	self.layout.PostCreateTooltip(tooltip)
end

-- Add some of our own stuff to our tooltips.
-- Making this a proxy of the standard post creation method.
Module.PostCreateCustomTips = function(self)
	self:ForAllTooltips(function(tooltip) 
		self:PostCreateTooltip(tooltip)
	end) 
end 

-- Set defalut values for all our tooltips
-- The modules can overwrite this by adding their own settings, 
-- this is just the fallbacks to have a consistent base look.
Module.StyleCustomTips = function(self)
	self:SetDefaultTooltipBackdrop(self.layout.TooltipBackdrop)
	self:SetDefaultTooltipBackdropColor(unpack(self.layout.TooltipBackdropColor)) 
	self:SetDefaultTooltipBackdropBorderColor(unpack(self.layout.TooltipBackdropBorderColor)) 

	-- Points the backdrop is offset outwards
	-- (left, right, top, bottom)
	self:SetDefaultTooltipBackdropOffset(10, 10, 10, 14)

	-- Points the bar is moved up towards the tooltip
	self:SetDefaultTooltipStatusBarOffset(3)

	-- Points the bar is shrunk inwards the left and right sides 
	self:SetDefaultTooltipStatusBarInset(6, 6) -- 4,4

	-- The height of the healthbar.
	-- The bar grows from top to bottom.
	self:SetDefaultTooltipStatusBarHeight(2) 
	self:SetDefaultTooltipStatusBarHeight(5, "health") 
	self:SetDefaultTooltipStatusBarHeight(2, "power") 

	-- Use our own texture for the bars
	self:SetDefaultTooltipStatusBarTexture(self.layout.TooltipStatusBarTexture)

	-- Set the default spacing between statusbars
	self:SetDefaultTooltipStatusBarSpacing(2)

	-- Default position of all tooltips.
	self:SetDefaultTooltipPosition(unpack(self.layout.TooltipPlace))

	-- Set the default colors for new tooltips
	self:SetDefaultTooltipColorTable(Colors)

	-- Post update tooltips already created
	-- with some important values
	self:PostCreateCustomTips()
end 

Module.OnEvent = function(self, event, ...)
	if (event == "PLAYER_LOGIN") then 
		self:PostCreateCustomTips()

	elseif (event == "GP_BAGS_SHOWN") then 

		local bags = Wheel("LibModule"):GetModule("Backpacker", true)
		if (bags) then
			local containerFrame = bags:GetCointainerFrame()
			if (containerFrame) then
				self:SetDefaultTooltipPosition("BOTTOMRIGHT", containerFrame, "BOTTOMLEFT", -20, 20)
			end
		end

	elseif (event == "GP_BAGS_HIDDEN") then 
	
		-- Default position of all tooltips.
		self:SetDefaultTooltipPosition(unpack(self.layout.TooltipPlace))
	end 
end 

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end
	self:StyleCustomTips()
	self:RegisterMessage("GP_BAGS_HIDDEN", "OnEvent")
	self:RegisterMessage("GP_BAGS_SHOWN", "OnEvent")
end 

Module.OnEnable = function(self)
	self:PostCreateCustomTips()
	self:RegisterEvent("PLAYER_LOGIN", "OnEvent")
end 
