local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("Tooltips", "LibMessage", "LibEvent", "LibDB", "LibNumbers", "LibTooltip")

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetLayout = Private.GetLayout
local GetMedia = Private.GetMedia

-- Number Abbreviation
local short = Module:GetNumberAbbreviationShort()
local large = Module:GetNumberAbbreviationLong()

local Tooltip_Bar_PostCreate = function(tooltip, bar)
	if bar.Value then 
		bar.Value:SetFontObject(Module.layout.TooltipFontBar)
	end
end

local Tooltip_StatusBar_PostUpdate = function(tooltip, bar, value, min, max, isRealValue)
	if (bar.barType == "health") then 
		if (isRealValue) then 
			bar.Value:SetText(large(value))
		else 
			if (value > 0) then 
				bar.Value:SetFormattedText("%.0f%%", value)
			else 
				bar.Value:SetText("")
			end
		end
		if (not bar.Value:IsShown()) then 
			bar.Value:Show()
		end
	else 
		if (bar.Value:IsShown()) then 
			bar.Value:Hide()
			bar.Value:SetText("")
		end
	end 
end 

local Tooltip_LinePair_PostCreate = function(tooltip, lineIndex, left, right)
	local layout = Module.layout
	local oldLeftObject = left:GetFontObject()
	local oldRightObject = right:GetFontObject()
	local leftObject = (lineIndex == 1) and layout.TooltipFontHeader or layout.TooltipFontNormal
	local rightObject = (lineIndex == 1) and layout.TooltipFontHeader or layout.TooltipFontNormal
	if (leftObject ~= oldLeftObject) then 
		left:SetFontObject(leftObject)
	end
	if (rightObject ~= oldRightObject) then 
		right:SetFontObject(rightObject)
	end
end

local Tooltip_PostCreate = function(tooltip)
	local layout = Module.layout
	if (not layout) then
		return
	end

	-- Going to enforce our smart scaling here.
	tooltip:SetCValue("autoCorrectScale", false)
	tooltip:SetIgnoreParentScale(true)
	tooltip:SetScale(768/1080)

	tooltip.colors = Colors
	tooltip.colorUnitClass = layout.TooltipSettingColorUnitClass 
	tooltip.colorUnitPetRarity = layout.TooltipSettingColorUnitPetRarity
	tooltip.colorUnitNameClass = layout.TooltipSettingColorUnitNameClass
	tooltip.colorUnitNameReaction = layout.TooltipSettingColorUnitNameReaction
	tooltip.colorHealthClass = layout.TooltipSettingColorHealthClass
	tooltip.colorHealthPetRarity = layout.TooltipSettingColorHealthPetRarity
	tooltip.colorHealthReaction = layout.TooltipSettingColorHealthReaction
	tooltip.colorHealthTapped = layout.TooltipSettingColorHealthTapped
	tooltip.colorPower = layout.TooltipSettingColorPower
	tooltip.colorPowerTapped = layout.TooltipSettingColorPowerTapped
	tooltip.showHealthBar = layout.TooltipSettingShowHealthBar
	tooltip.showPowerBar = layout.TooltipSettingShowPowerBar 
	tooltip.showLevelWithName = layout.TooltipSettingShowLevelWithName

	tooltip.PostCreateLinePair = Tooltip_LinePair_PostCreate
	tooltip.PostCreateBar = Tooltip_Bar_PostCreate
	tooltip.PostUpdateStatusBar = Tooltip_StatusBar_PostUpdate
end

-- This is called by the library back-end.
Module.PostCreateTooltip = function(self, tooltip)
	Tooltip_PostCreate(tooltip)
end

-- Add some of our own stuff to our tooltips.
-- Making this a proxy of the standard post creation method.
Module.PostCreateCustomTips = function(self)
	self:ForAllTooltips(Tooltip_PostCreate) 
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
	self:SetDefaultTooltipBackdropOffset(unpack(self.layout.TooltipBackdropOffsets))

	-- Points the bar is moved away from the tooltip
	self:SetDefaultTooltipStatusBarOffset(0)

	-- Points the bar is shrunk inwards the left and right sides 
	self:SetDefaultTooltipStatusBarInset(6, 6) -- 4,4

	-- The height of the healthbar.
	-- The bar grows from top to bottom.
	self:SetDefaultTooltipStatusBarHeight(4) 
	self:SetDefaultTooltipStatusBarHeight(4, "health") 
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

	elseif (event == "GP_BAGS_HIDDEN") or (event == "PLAYER_ENTERING_WORLD") then 
	
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
end 

Module.OnEnable = function(self)
	self:PostCreateCustomTips()
	self:RegisterEvent("PLAYER_LOGIN", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterMessage("GP_BAGS_HIDDEN", "OnEvent")
	self:RegisterMessage("GP_BAGS_SHOWN", "OnEvent")
end 
