local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("OptionsMenu", "HIGH", "LibMessage", "LibEvent", "LibDB", "LibFrame", "LibSound", "LibTooltip")
local MenuTable

-- Registries
Module.buttons = Module.buttons or {}
Module.menus = Module.menus or {}
Module.toggles = Module.toggles or {}
Module.siblings =  Module.siblings or {}
Module.windows = Module.windows or {}

-- Shortcuts
local Buttons = Module.buttons
local Menus = Module.menus
local Toggles = Module.toggles
local Siblings = Module.siblings
local Windows = Module.windows

-- Lua API
local _G = _G
local math_min = math.min
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetLayout = Private.GetLayout
local IsForcingSlackAuraFilterMode = Private.IsForcingSlackAuraFilterMode
local IsClassic = Private.IsClassic
local IsTBC = Private.IsTBC
local IsRetail = Private.IsRetail

-- Fixing Blizzard's shit.
-- They bugged out FrameXML\RestrictedFrames.lua in build 37623.
local BlizzardFuckedUp = Private.ClientBuild >= 37623 -- The culprit patch

-- Menu callback frames
local CallbackFrames = {}
local CallbackFrameOwners = {}

-- Localization
local L = Wheel("LibLocale"):GetLocale(ADDON)

-- Player Constants
local _,PlayerClass = UnitClass("player")

-- Number of buttons in total, for naming.
local NUM_BUTTONS = 0

-- Utility
--------------------------------------------------------------------------
local clean = function(source)
	if (source) then
		for i = #source,1,-1 do
			if (not source[i]) then
				table_remove(source, i)
			end
		end
		return source
	end
end

-- Define all templates, they are cross-references later on.
--------------------------------------------------------------------------
local Button = Module:CreateFrame("CheckButton", nil, "UICenter", "SecureHandlerClickTemplate")
local Button_MT = { __index = Button }

local Toggle = Module:CreateFrame("CheckButton", nil, "UICenter", "SecureHandlerClickTemplate")
local Toggle_MT = { __index = Toggle }

local Window = Module:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
local Window_MT = { __index = Window }

-- Secure script snippets
--------------------------------------------------------------------------
local secureSnippets = {
	menuToggle = [=[
		local window = self:GetFrameRef("OptionsMenu");
		if window:IsShown() then
			window:Hide();
		else
			local window2 = self:GetFrameRef("MicroMenu"); 
			if (window2 and window2:IsShown()) then 
				window2:Hide(); 
			end 
			window:Show();
			window:RegisterAutoHide(.75);
			window:AddToAutoHide(self);
			local autohideCounter = 1
			local autohideFrame = window:GetFrameRef("autohide"..autohideCounter);
			while autohideFrame do 
				window:AddToAutoHide(autohideFrame);
				autohideCounter = autohideCounter + 1;
				autohideFrame = window:GetFrameRef("autohide"..autohideCounter);
			end 
		end
	]=],
	bagToggle = [=[ 
		self:CallMethod("ToggleAllBags"); 
	]=],
	windowToggle = [=[
		-- Fake-disable buttons until Blizzard fix the restricted frames.
		if (self:GetAttribute("blizzardFuckedUp") == "1") and (self:GetAttribute("userDisabled") == "1") then
			return
		end
	
		local window = self:GetFrameRef("Window"); 
		if window:IsShown() then 
			window:Hide(); 
			window:CallMethod("OnHide");
		else 
			window:Show(); 
			window:CallMethod("OnShow");
			local counter = 1
			local sibling = window:GetFrameRef("Sibling"..counter);
			while sibling do 
				if sibling:IsShown() then 
					sibling:Hide(); 
					sibling:CallMethod("OnHide");
				end 
				counter = counter + 1;
				sibling = window:GetFrameRef("Sibling"..counter);
			end 
		end 
	]=],
	buttonClick = [=[
		local updateType = self:GetAttribute("updateType"); 
		if (updateType == "SET_VALUE") then 

			-- Fake-disable buttons until Blizzard fix the restricted frames.
			if (self:GetAttribute("blizzardFuckedUp") == "1") and (self:GetAttribute("userDisabled") == "1") then
				return
			end
		
			-- Figure out the window's attribute name for this button's attached setting
			local optionDB = self:GetAttribute("optionDB"); 
			local optionName = self:GetAttribute("optionName"); 
			local attributeName = "DB_"..optionDB.."_"..optionName; 

			-- retrieve the new value of the setting
			local window = self:GetFrameRef("Owner"); 
			local value = self:GetAttribute("optionArg1"); 

			-- store the new setting on the button
			self:SetAttribute("optionValue", value); 

			-- store the new setting on the window
			window:SetAttribute(attributeName, value); 

			-- Feed the new values into the lua db
			self:CallMethod("FeedToDB"); 

			-- Fire a secure settings update on whatever this setting is attached to
			local proxyUpdater = self:GetFrameRef("proxyUpdater"); 
			if proxyUpdater then 
				proxyUpdater:SetAttribute("change-"..optionName, value); 
			end 

			-- Fire lua post updates to menu buttons
			self:CallMethod("Update"); 

			-- Fire lua post updates to siblings, if any, 
			-- as this could be a multi-option.	
			local counter = 1
			local sibling = self:GetFrameRef("Sibling"..counter);
			while sibling do 

				local isSlave = sibling:GetAttribute("isSlave"); 
				if (isSlave) then
					local slaveDB = sibling:GetAttribute("slaveDB"); 
					local slaveKey = sibling:GetAttribute("slaveKey"); 
					local slaveAttributeName = "DB_"..slaveDB.."_"..slaveKey; 

					if (slaveAttributeName == attributeName) then
						local enable
						local slaveValue = window:GetAttribute(slaveAttributeName); 

						if (slaveValue) then
							local slaveEnableValues = sibling:GetAttribute("slaveEnableValues"); 
							if (slaveEnableValues) then
								slaveValue = tostring(slaveValue);

								for i = 1, select("#", strsplit(",", slaveEnableValues)) do
									local value = select(i, strsplit(",", slaveEnableValues))
									if (value == slaveValue) then
										enable = true
										break
									end
								end
							else
								enable = true;
							end
						end

						if (enable) then
							sibling:RunAttribute("UserEnable");
						else
							sibling:RunAttribute("UserDisable");
							sibling:CallMethod("Update");

							-- close child windows
							local window = sibling:GetFrameRef("Window");
							if (window) then
								window:Hide();
								window:CallMethod("OnHide");
							end
						end
					end
				else
					sibling:CallMethod("Update");
				end

				counter = counter + 1;
				sibling = self:GetFrameRef("Sibling"..counter);
			end 


		elseif (updateType == "GET_VALUE") then 

		elseif (updateType == "TOGGLE_VALUE") then 

			local isSlave = self:GetAttribute("isSlave"); 
			local isUserDisabled = (self:GetAttribute("blizzardFuckedUp") == "1") and (self:GetAttribute("userDisabled") == "1");
	
			-- Figure out the window's attribute name for this button's attached setting
			local optionDB = self:GetAttribute("optionDB"); 
			local optionName = self:GetAttribute("optionName"); 
			local attributeName = "DB_"..optionDB.."_"..optionName; 

			-- retrieve the old value of the setting
			local window = self:GetFrameRef("Owner"); 
			local value = not window:GetAttribute(attributeName); 

			-- store the new setting on the button
			self:SetAttribute("optionValue", not self:GetAttribute("optionValue")); 

			-- store the new setting on the window
			window:SetAttribute(attributeName, value); 

			-- Feed the new values into the lua db
			self:CallMethod("FeedToDB"); 

			-- Fire a secure settings update on whatever this setting is attached to
			local proxyUpdater = self:GetFrameRef("proxyUpdater"); 
			if proxyUpdater then 
				proxyUpdater:SetAttribute("change-"..optionName, self:GetAttribute("optionValue")); 
			end 

			if (isSlave) then
				local slaveDB = self:GetAttribute("slaveDB"); 
				local slaveKey = self:GetAttribute("slaveKey"); 
				local slaveAttributeName = "DB_"..slaveDB.."_"..slaveKey; 
				local slaveValue = window:GetAttribute(slaveAttributeName); 
				if (not slaveValue) then
					self:RunAttribute("UserDisable");
					-- close child windows
					local window = self:GetFrameRef("Window");
					if (window) then
						window:Hide();
						window:CallMethod("OnHide");
					end
				else
					self:RunAttribute("UserEnable");
				end
			end

			-- Fire lua post updates to siblings, if any, 
			-- as this could be a multi-option.	
			local counter = 1
			local sibling = self:GetFrameRef("Sibling"..counter);
			while sibling do 
				local isSlave = sibling:GetAttribute("isSlave"); 
				if (isSlave) then
					local slaveDB = sibling:GetAttribute("slaveDB"); 
					local slaveKey = sibling:GetAttribute("slaveKey"); 
					local slaveAttributeName = "DB_"..slaveDB.."_"..slaveKey; 

					if (slaveAttributeName == attributeName) then
						local enable
						local slaveValue = window:GetAttribute(slaveAttributeName); 

						if (slaveValue) then
							local slaveEnableValues = sibling:GetAttribute("slaveEnableValues"); 
							if (slaveEnableValues) then
								slaveValue = tostring(slaveValue);

								for i = 1, select("#", strsplit(",", slaveEnableValues)) do
									local value = select(i, strsplit(",", slaveEnableValues))
									if (value == slaveValue) then
										enable = true
										break
									end
								end
							else
								enable = true;
							end
						end

						if (enable) then
							sibling:RunAttribute("UserEnable");
						else
							sibling:RunAttribute("UserDisable");
							sibling:CallMethod("Update");

							-- close child windows
							local window = sibling:GetFrameRef("Window");
							if (window) then
								window:Hide();
								window:CallMethod("OnHide");
							end
						end
					end
				end
	
				counter = counter + 1;
				sibling = self:GetFrameRef("Sibling"..counter);
			end 

			-- Fire lua post updates to menu buttons
			self:CallMethod("Update"); 


		elseif (updateType == "TOGGLE_MODE") then 

			-- Bypass all secure methods and run it in pure lua
			self:CallMethod("ToggleMode"); 

			-- Fire lua post updates to menu buttons
			self:CallMethod("Update"); 

		else
			-- window


		end 
	]=]
}

-- Local Functions
--------------------------------------------------------------------------
local ConfigWindow_OnShow = function(self) 
	local tooltip = Private:GetOptionsMenuTooltip()
	local button = Module:GetToggleButton()
	if (tooltip:IsShown() and (tooltip:GetOwner() == button)) then 
		tooltip:Hide()
	end 
end

local ConfigWindow_OnHide = function(self) 
	local tooltip = Private:GetOptionsMenuTooltip()
	local toggle = Module:GetToggleButton()
	if (toggle:IsMouseOver(0,0,0,0) and ((not tooltip:IsShown()) or (tooltip:GetOwner() ~= toggle))) then 
		toggle:OnEnter()
	end 
end

local SetOptionProxyUpdater = function(option)
	local proxyUpdater
	if (option.proxyModule) then 
		local proxyModule = Core:GetModule(option.proxyModule)
		if (proxyModule and proxyModule.GetSecureUpdater) then 
			proxyUpdater = proxyModule:GetSecureUpdater()
		end 
	elseif (option.useCore) then 
		proxyUpdater = Core:GetSecureUpdater()
	end 
	if (proxyUpdater) then
		option:SetFrameRef("proxyUpdater", proxyUpdater)
	end
end

-- Entry Button template
--------------------------------------------------------------------------
Button.OnEnable = function(self)
	self:SetAlpha(1)
	self:Update()
end 

Button.OnDisable = function(self)
	self:SetAlpha(.5)
	self:Update()
end 

Button.OnEnter = function(self)
	self:Update()
	if (self:IsReallyEnabled()) and (not self:IsWindowOpen()) then
		if ((self.isChecked) and (self.enabledTooltipText or self.tooltipText))
		or ((not self.isChecked) and (self.disabledTooltipText or self.tooltipText)) then

			local titleColor, normalColor = self.layout.MenuButtonTitleColor,  self.layout.MenuButtonNormalColor
			local tooltip = self:GetTooltip()
			tooltip:Hide()
			tooltip:SetSmartAnchor(self, 40, -(self.layout.MenuButtonSize[2]*self.layout.MenuButtonSizeMod - 2))

			if (self.isChecked) then
				tooltip:AddLine(self.enabledTooltipText or self.tooltipText, titleColor[1], titleColor[2], titleColor[3], false)
				if (self.enabledNewbieText or self.newbieText) then
					tooltip:AddLine(self.enabledNewbieText or self.newbieText, normalColor[1], normalColor[2], normalColor[3], true)
				end
			else
				tooltip:AddLine(self.disabledTooltipText or self.tooltipText, titleColor[1], titleColor[2], titleColor[3], false)
				if (self.disabledNewbieText or self.newbieText) then
					tooltip:AddLine(self.disabledNewbieText or self.newbieText, normalColor[1], normalColor[2], normalColor[3], true)
				end
			end

			tooltip:Show()
		end
	end
end

Button.PostClick = function(self)
	local tooltip = self:GetTooltip()
	if (tooltip:IsShown()) and (tooltip:GetOwner() == self) then
		self:OnEnter()
	end
end

Button.OnLeave = function(self)
	local tooltip = self:GetTooltip()
	tooltip:Hide()
	self:Update()
end

Button.GetTooltip = function(self)
	return Private:GetOptionsMenuTooltip()
end

Button.OnShow = function(self)
	self.isDown = false
	self:Update()
end 

Button.OnHide = function(self)
	self.isDown = false
	self:Update()
end 

Button.OnMouseDown = function(self)
	if (not self:IsReallyEnabled()) then
		return
	end
	self.isDown = true
	self:Update()
end 

Button.OnMouseUp = function(self)
	if (not self:IsReallyEnabled()) then
		return
	end
	self.isDown = false
	self:Update()
end 

Button.ToggleMode = function(self)
	local Module = self.proxyModule and Core:GetModule(self.proxyModule, true) or self.useCore and Core
	if Module and Module.OnModeToggle then 
		Module:OnModeToggle(self.modeName)
		self:Update()
	end
end

Button.IsReallyEnabled = function(self)
	if (BlizzardFuckedUp) then
		return (self:GetAttribute("userDisabled") ~= "1") and self:IsEnabled()
	else
		return self:IsEnabled()
	end
end

Button.HasWindow = function(self)
	return self.hasWindow
end

Button.IsWindowOpen = function(self)
	return self.windowIsShown
end

Button.Update = function(self)
	local layout = self.layout

	if (self.updateType == "GET_VALUE") then 
		-- nothing to do here

	elseif (self.updateType == "SET_VALUE") then 
		local db = GetConfig(self.optionDB, self.optionProfile)
		local option = db[self.optionName]
		local checked = option == self.optionArg1

		if (self:IsReallyEnabled()) then
			if (checked) then 
				self.Msg:SetText(self.enabledTitle or L["Enabled"])
				self.isChecked = true
			else
				self.Msg:SetText(self.disabledTitle or L["Disabled"])
				self.isChecked = false
			end 
		else
			self.Msg:SetText(self.title or self.disabledTitle or L["Disabled"])
			self.isChecked = false
		end

	elseif (self.updateType == "TOGGLE_VALUE") then 
		local db = GetConfig(self.optionDB, self.optionProfile)
		local option = db[self.optionName]

		if (self:IsReallyEnabled()) then
			if (option) then 
				self.Msg:SetText(self.enabledTitle or L["Disable"])
				self.isChecked = true
			else 
				self.Msg:SetText(self.disabledTitle or L["Enable"])
				self.isChecked = false
			end 
		else
			self.Msg:SetText(self.title or self.disabledTitle or L["Enable"])
			self.isChecked = false
		end

	elseif (self.updateType == "TOGGLE_MODE") then
		local Module = self.proxyModule and Core:GetModule(self.proxyModule, true) or self.useCore and Core
		if Module then 
			if (self:IsReallyEnabled()) then
				if (Module:IsModeEnabled(self.modeName)) then 
					self.Msg:SetText(self.enabledTitle or L["Disable"])
					self.isChecked = true
				else 
					self.Msg:SetText(self.disabledTitle or L["Enable"])
					self.isChecked = false
				end 
			else
				self.Msg:SetText(self.title or self.disabledTitle or L["Enable"])
				self.isChecked = false
			end
		end 
	end 
	
	-- Add pure styling updates here. Don't offer arguments.
	if (layout.MenuButton_PostUpdate) then
		layout.MenuButton_PostUpdate(self)
	end
end

Button.FeedToDB = function(self)
	if (self.updateType == "SET_VALUE") then 
		GetConfig(self.optionDB, self.optionProfile)[self.optionName] = self:GetAttribute("optionValue")

	elseif (self.updateType == "TOGGLE_VALUE") then 
		GetConfig(self.optionDB, self.optionProfile)[self.optionName] = self:GetAttribute("optionValue")
	end 
end 

Button.CreateWindow = function(self, level)
	local layout = self.layout

	local window = Module:CreateConfigWindowLevel(level, self)
	window:ClearAllPoints()
	if (Module:GetConfigWindow().reverseOrder) then
		window:SetPoint("TOP", self, "TOP", 0, layout.MenuButtonSpacing) 
		window:SetPoint("RIGHT", self, "LEFT", -layout.MenuButtonSpacing*2, 0)
	else
		window:SetPoint("BOTTOM", self, "BOTTOM", 0, -layout.MenuButtonSpacing) 
		window:SetPoint("RIGHT", self, "LEFT", -layout.MenuButtonSpacing*2, 0)
	end

	if layout.MenuWindow_CreateBorder then 
		window.Border = layout.MenuWindow_CreateBorder(window)
	end 

	window.OnHide = Window.OnHide
	window.OnShow = Window.OnShow
	window.hasButton = self

	self:SetAttribute("_onclick", secureSnippets.windowToggle)
	self:SetFrameRef("Window", window)
	self.hasWindow = window

	Module:AddFrameToAutoHide(window)

	local owner = self:GetParent()
	if (not owner.windows) then 
		owner.numWindows = 0
		owner.windows = {}
	end 

	owner.numWindows = owner.numWindows + 1
	owner.windows[owner.numWindows] = window
	owner:UpdateSiblings()
	
	return window
end

Button.SetAsSlave = function(self, slaveDB, slaveKey, slaveEnableValues)
	self.slaveDB = slaveDB
	self.slaveKey = slaveKey
	self.slaveEnableValues = slaveEnableValues
	self.isSlave = true
	self:SetAttribute("slaveDB", slaveDB)
	self:SetAttribute("slaveKey", slaveKey)
	self:SetAttribute("slaveEnableValues", slaveEnableValues)
	self:SetAttribute("isSlave", true)
end

-- Toggle Button template
--------------------------------------------------------------------------
Toggle.OnEnter = function(self)
	if (not self.leftButtonTooltip) and (not self.rightButtonTooltip) and (not self.middleButtonTooltip) then 
		return 
	end
	local tooltip = Private:GetOptionsMenuTooltip()
	local window = Module:GetConfigWindow()
	if window:IsShown() then 
		if (tooltip:IsShown() and (tooltip:GetOwner() == self)) then 
			tooltip:Hide()
		end 
		return 
	end 
	local r,g,b = Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3]
	tooltip:SetDefaultAnchor(self)

	if (self.leftButtonTooltip) then
		tooltip:AddLine(self.leftButtonTooltip, r,g,b, false)
	end
	if (self.middleButtonTooltip) then
		tooltip:AddLine(self.middleButtonTooltip, r,g,b, false)
	end
	if (self.rightButtonTooltip) then
		tooltip:AddLine(self.rightButtonTooltip, r,g,b, false)
	end

	tooltip:Show()
end

Toggle.OnLeave = function(self)
	local tooltip = Private:GetOptionsMenuTooltip()
	tooltip:Hide() 
end

-- Container template
--------------------------------------------------------------------------
Window.AddButton = function(self, text, updateType, optionDB, optionProfile, optionName, ...)
	local layout = self.layout

	NUM_BUTTONS = NUM_BUTTONS + 1
	
	local option = setmetatable(self:CreateFrame("CheckButton", ADDON.."_ConfigMenu_OptionsButton"..NUM_BUTTONS, "SecureHandlerClickTemplate"), Button_MT)
	option:SetSize(layout.MenuButtonSize[1]*layout.MenuButtonSizeMod, layout.MenuButtonSize[2]*layout.MenuButtonSizeMod)
	option:ClearAllPoints()

	if (Module:GetConfigWindow().reverseOrder) then
		option:SetPoint("TOPRIGHT", -layout.MenuButtonSpacing, -(layout.MenuButtonSpacing + (layout.MenuButtonSize[2]*layout.MenuButtonSizeMod + layout.MenuButtonSpacing)*(self.numButtons)))
	else
		option:SetPoint("BOTTOMRIGHT", -layout.MenuButtonSpacing, layout.MenuButtonSpacing + (layout.MenuButtonSize[2]*layout.MenuButtonSizeMod + layout.MenuButtonSpacing)*(self.numButtons))
	end 

	option:HookScript("OnEnable", Button.OnEnable)
	option:HookScript("OnDisable", Button.OnDisable)
	option:HookScript("OnShow", Button.OnShow)
	option:HookScript("OnHide", Button.OnHide)
	option:HookScript("OnMouseDown", Button.OnMouseDown)
	option:HookScript("OnMouseUp", Button.OnMouseUp)
	option:HookScript("OnEnter", Button.OnEnter)
	option:HookScript("OnLeave", Button.OnLeave)
	option:SetScript("PostClick", Button.PostClick)

	option:SetAttribute("updateType", updateType)
	option:SetAttribute("optionDB", optionDB)
	option:SetAttribute("optionProfile", optionProfile)
	option:SetAttribute("optionName", optionName)

	option:SetAttribute("blizzardFuckedUp", BlizzardFuckedUp and "1")
	option:SetAttribute("UserDisable", [=[
		if (self:GetAttribute("blizzardFuckedUp") == "1") then
			self:SetAttribute("userDisabled", "1"); 
			self:CallMethod("OnDisable");
		else
			self:Disable();
		end
	]=])
	option:SetAttribute("UserEnable", [=[
		if (self:GetAttribute("blizzardFuckedUp") == "1") then
			self:SetAttribute("userDisabled", "0"); 
			self:CallMethod("OnEnable");
		else
			self:Enable();
		end
	]=])

	option:SetFrameRef("Owner", self)

	for i = 1, select("#", ...) do 
		local value = select(i, ...)
		option:SetAttribute("optionArg"..i, value)
		option["optionArg"..i] = value
	end 

	option.layout = layout
	option.updateType = updateType
	option.optionDB = optionDB
	option.optionProfile = optionProfile
	option.optionName = optionName
	option:SetAttribute("_onclick", secureSnippets.buttonClick)

	if (not Module.optionCallbacks) then 
		Module.optionCallbacks = {}
	end 

	Module.optionCallbacks[option] = self

	if (layout.MenuButton_PostCreate) then 
		layout.MenuButton_PostCreate(option, text, updateType, optionDB, optionProfile, optionName, ...)
	end

	self.numButtons = self.numButtons + 1
	self.buttons[self.numButtons] = option

	self:PostUpdateSize()
	self:UpdateSiblings()

	return option
end 

Window.ParseOptionsTable = function(self, tbl, parentLevel)
	local level = (parentLevel or 1) + 1
	for id,data in ipairs(tbl) do
		local button = self:AddButton(data.title, data.type, data.configDB, data.configProfile, data.configKey, data.optionArgs and unpack(data.optionArgs))
		
		button.title = data.title
		button.enabledTitle = data.enabledTitle
		button.disabledTitle = data.disabledTitle
		button.proxyModule = data.proxyModule
		button.useCore = data.useCore
		button.modeName = data.modeName
		button.hasWindow = data.hasWindow
		button.tooltipText = data.tooltipText
		button.enabledTooltipText = data.enabledTooltipText
		button.disabledTooltipText = data.disabledTooltipText
		button.newbieText = data.newbieText
		button.enabledNewbieText = data.enabledNewbieText
		button.disabledNewbieText = data.disabledNewbieText

		if data.isSlave then 
			button:SetAsSlave(data.slaveDB, data.slaveKey, data.slaveEnableValues)
		end 

		if data.hasWindow then 
			local window = button:CreateWindow(level)
			if data.buttons then 
				window:ParseOptionsTable(data.buttons)
			end 
		end
	end
end

Window.UpdateSiblings = function(self)
	for id,button in ipairs(self.buttons) do 
		local siblingCount = 0
		for i = 1, self.numButtons do 
			if (i ~= id) then 
				siblingCount = siblingCount + 1
				button:SetFrameRef("Sibling"..siblingCount, self.buttons[i])
			end 
		end 
	end
	if self.windows then 
		for id,button in ipairs(self.windows) do 
			local siblingCount = 0
			for i = 1, self.numWindows do 
				if (i ~= id) then 
					siblingCount = siblingCount + 1
					button:SetFrameRef("Sibling"..siblingCount, self.windows[i])
				end 
			end 
		end
	end 
end

Window.OnHide = function(self)
	local button = self:GetParent()
	button.windowIsShown = nil

	local tooltip = button:GetTooltip()
	if (button:IsMouseOver(0,0,0,0) and ((not tooltip:IsShown()) or (tooltip:GetOwner() ~= button))) then 
		button:OnEnter() -- this fires off the update
		return
	end 

	button:Update()
end

Window.OnShow = function(self)
	local button = self:GetParent()
	button.windowIsShown = true

	local tooltip = button:GetTooltip()
	if (tooltip:IsShown() and tooltip:GetOwner() == button) then
		tooltip:Hide() -- this fires off the update
		return
	end

	button:Update()
end

Window.PostUpdateSize = function(self)
	local layout = self.layout
	local numButtons = self.numButtons
	self:SetSize(layout.MenuButtonSize[1]*layout.MenuButtonSizeMod + layout.MenuButtonSpacing*2, layout.MenuButtonSize[2]*layout.MenuButtonSizeMod*numButtons + layout.MenuButtonSpacing*(numButtons+1))
end

-- Module API
--------------------------------------------------------------------------
Module.AddFrameToAutoHide = function(self, frame)
	local window = self:GetConfigWindow()
	local hiders = self:GetAutoHideReferences()

	local id = 1 -- targeted id for this autohider
	for frameRef,parent in pairs(hiders) do 
		id = id + 1 -- increase id by 1 for every other frame found
	end 

	-- create a new autohide frame
	local autohideParent = CreateFrame("Frame", nil, window, "SecureHandlerStateTemplate")
	autohideParent:ClearAllPoints()
	autohideParent:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 6)
	autohideParent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, -6)

	-- Add it to our registry
	hiders["autohide"..id] = autohideParent
end

Module.AddOptionsToMenuButton = function(self)
	if (not self.addedToMenuButton) then 
		self.addedToMenuButton = true

		local leftIcon = "|TInterface\\TutorialFrame\\UI-TUTORIAL-FRAME:20:15:0:0:512:512:1:76:218:318|t "
		local middleIcon = "|TInterface\\TutorialFrame\\UI-TUTORIAL-FRAME:20:15:0:0:512:512:1:76:118:218|t "
		local rightIcon = "|TInterface\\TutorialFrame\\UI-TUTORIAL-FRAME:20:15:0:0:512:512:1:76:321:421|t "

		local toggleButton = self:GetToggleButton()

		-- Toggle backpack (Left)
		toggleButton.leftButtonTooltip = leftIcon .. BACKPACK_TOOLTIP
		toggleButton:SetAttribute("leftclick", secureSnippets.bagToggle)
		toggleButton.ToggleAllBags = function() ToggleAllBags() end

		-- Toggle addon menu (Middle)
		local menuWindow = self:GetConfigWindow()
		toggleButton.middleButtonTooltip = middleIcon .. OPTIONS_MENU
		toggleButton:SetFrameRef("OptionsMenu", menuWindow)
		toggleButton:SetAttribute("middleclick", secureSnippets.menuToggle)
		for reference,frame in pairs(self:GetAutoHideReferences()) do 
			menuWindow:SetFrameRef(reference,frame)
		end 

		-- Toggle micro menu (Right)
		local microModule = Core:GetModule("BlizzardMicroMenu", true)
		if (microModule) then
			local microMenu = microModule:GetConfigWindow()
			toggleButton.rightButtonTooltip = rightIcon .. L["Game Panels"]
			toggleButton:SetFrameRef("MicroMenu", microMenu)
			toggleButton:SetAttribute("rightclick", [[
				local window = self:GetFrameRef("MicroMenu");
				if window:IsShown() then
					window:Hide();
				else
					local window2 = self:GetFrameRef("OptionsMenu"); 
					if (window2 and window2:IsShown()) then 
						window2:Hide(); 
					end 
					window:Show();
					window:RegisterAutoHide(.75);
					window:AddToAutoHide(self);
					local autohideCounter = 1
					local autohideFrame = window:GetFrameRef("autohide"..autohideCounter);
					while autohideFrame do 
						window:AddToAutoHide(autohideFrame);
						autohideCounter = autohideCounter + 1;
						autohideFrame = window:GetFrameRef("autohide"..autohideCounter);
					end 
				end
			]])
			for reference,frame in pairs(microModule:GetAutoHideReferences()) do 
				microMenu:SetFrameRef(reference,frame)
			end 
		end

	end
end 

Module.AddOptionsToMenuWindow = function(self)
	if (self.addedToMenuWindow) then 
		return 
	end 
	self:GetConfigWindow():ParseOptionsTable(MenuTable, 1)
	self.addedToMenuWindow = true
end

Module.CreateConfigWindowLevel = function(self, level, parent)
	local layout = self.layout
	local frameLevel = 10 + (level-1)*5
	local name = level == 1 and ADDON.."_ConfigMenu"
	local window = setmetatable(self:CreateFrame("Frame", name, parent or "UICenter", "SecureHandlerAttributeTemplate"), Window_MT)
	window:Hide()
	window:EnableMouse(true)
	window:SetFrameStrata("DIALOG")
	window:SetFrameLevel(frameLevel)
	window.layout = layout
	window.numButtons = 0
	window.buttons = {}

	if (level > 1) then 
		self:AddFrameToAutoHide(window)
	end 

	return window, name
end

Module.UpdateBindings = function(self)
	local toggleButton = self:GetToggleButton()
	if (toggleButton) then
		ClearOverrideBindings(toggleButton) 
		local bindingAction = "AZERITEUI_OPTIONS_MENU"
		for keyNumber = 1, select("#", GetBindingKey(bindingAction)) do 
			local key = select(keyNumber, GetBindingKey(bindingAction)) 
			if (key and (key ~= "")) then
				SetOverrideBindingClick(toggleButton, false, key, toggleButton:GetName(), "MiddleButton") 
			end
		end
	end
end

Module.GetToggleButton = function(self)
	if (not self.ToggleButton) then 
		local layout = self.layout
		local toggleButton = self:CreateFrame("CheckButton", ADDON.."_ConfigMenu_ToggleButton", "UICenter", "SecureHandlerClickTemplate")
		toggleButton.layout = layout
		toggleButton.OnEnter = Toggle.OnEnter
		toggleButton.OnLeave = Toggle.OnLeave
		toggleButton:SetFrameStrata("DIALOG")
		toggleButton:SetFrameLevel(50)
		toggleButton:SetSize(unpack(layout.MenuToggleButtonSize))
		toggleButton:Place(unpack(layout.MenuToggleButtonPlace))
		toggleButton:RegisterForClicks("AnyUp")
		toggleButton:SetScript("OnEnter", Toggle.OnEnter)
		toggleButton:SetScript("OnLeave", Toggle.OnLeave) 
		toggleButton:SetAttribute("_onclick", [[
			if (button == "LeftButton") then
				local leftclick = self:GetAttribute("leftclick");
				if leftclick then
					self:RunAttribute("leftclick", button);
				end
			elseif (button == "RightButton") then 
				-- 8.2.0: this isn't working as of now. 
				local rightclick = self:GetAttribute("rightclick");
				if rightclick then
					self:RunAttribute("rightclick", button);
				end
			elseif (button == "MiddleButton") then
				local middleclick = self:GetAttribute("middleclick");
				if middleclick then
					self:RunAttribute("middleclick", button);
				end
			end
		]])
		toggleButton.Icon = toggleButton:CreateTexture()
		toggleButton.Icon:SetTexture(layout.MenuToggleButtonIcon)
		toggleButton.Icon:SetSize(unpack(layout.MenuToggleButtonIconSize))
		toggleButton.Icon:ClearAllPoints()
		toggleButton.Icon:SetPoint(unpack(layout.MenuToggleButtonIconPlace))
		toggleButton.Icon:SetVertexColor(unpack(layout.MenuToggleButtonIconColor))

		self.ToggleButton = toggleButton

		self:RegisterEvent("UPDATE_BINDINGS", "UpdateBindings")
		self:UpdateBindings()
	end 
	return self.ToggleButton
end

Module.GetConfigWindow = function(self)
	if (not self.ConfigWindow) then 
		local layout = self.layout

		-- create main window 
		local window = self:CreateConfigWindowLevel(1)
		window:Place(unpack(layout.MenuPlace))
		window:SetSize(unpack(layout.MenuSize))
		window:EnableMouse(true)
		window:SetScript("OnShow", ConfigWindow_OnShow)
		window:SetScript("OnHide", ConfigWindow_OnHide)
		window.layout = self.layout
		window.reverseOrder = (window:GetPoint()):find("TOP")

		if (layout.MenuWindow_CreateBorder) then 
			window.Border = layout.MenuWindow_CreateBorder(window)
		end 

		self.ConfigWindow = window
	end 
	return self.ConfigWindow
end

Module.GetAutoHideReferences = function(self)
	if (not self.AutoHideReferences) then 
		self.AutoHideReferences = {}
	end 
	return self.AutoHideReferences
end

Module.PostUpdateOptions = function(self, event, ...)
	if (event) then 
		self:UnregisterEvent(event, "PostUpdateOptions")
	end
	if (self.optionCallbacks) then 
		for option,window in pairs(self.optionCallbacks) do 
			if (option.updateType == "SET_VALUE") then
				local db = GetConfig(option.optionDB, option.optionProfile)
				local value = db[option.optionName]
				
				SetOptionProxyUpdater(option)

				option:SetAttribute("optionValue", value)
				option:Update()

			elseif (option.updateType == "TOGGLE_VALUE") then
				local db = GetConfig(option.optionDB, option.optionProfile)
				local value = db[option.optionName]

				SetOptionProxyUpdater(option)

				option:SetAttribute("optionValue", value)
				option:Update()

			elseif (option.updateType == "TOGGLE_MODE") then
				SetOptionProxyUpdater(option)

			end 
			if (option.isSlave) then 
				local attributeName = "DB_"..option.slaveDB.."_"..option.slaveKey
				local db = GetConfig(option.slaveDB, option.slaveDBProfile)
				local value = db[option.slaveKey]

				window:SetAttribute(attributeName, value)

				local enable
				if (value) then
					local slaveEnableValues = option:GetAttribute("slaveEnableValues")
					if (slaveEnableValues) then
						local slaveValue = tostring(value)

						for i = 1, select("#", strsplit(",", slaveEnableValues)) do
							local j = select(i, strsplit(",", slaveEnableValues))
							if (j == slaveValue) then
								enable = true
								break
							end
						end
					else
						enable = true
					end
				end

				if (enable) then 
					if (BlizzardFuckedUp) then
						option:SetAttribute("userDisabled", "0")
						option:OnEnable()
					else
						option:Enable()
					end
				else
					if (BlizzardFuckedUp) then
						option:SetAttribute("userDisabled", "1")
						option:OnDisable()
					else
						option:Disable()
					end
				end 

				option:Update()
			end 
		end 
	end 
end 

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end
	self:CreateMenuTable()
	self:AddOptionsToMenuWindow()
end 

Module.OnEnable = function(self)
	self:AddOptionsToMenuButton()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "PostUpdateOptions")
end 

-- Create secure callback frames used by the menu system
-- to interact with our secure buttons.
local CallbackFrame = CreateFrame("Frame", nil, WorldFrame, "SecureHandlerAttributeTemplate")
local CallbackFrame_MT = { __index = CallbackFrame }

CallbackFrame.AssignProxyMethods = function(self, ...)
	local module = CallbackFrameOwners[self]
	for i = 1, select("#", ...) do
		local method = select(i, ...)
		self[method] = function() module[method](module) end
	end
end

CallbackFrame.AssignAttributes = function(self, ...)
	local numValues = (select("#", ...) or 0)
	local i = 1
	while (i < numValues) do
		local name, value = select(i, ...)
		if (name) then
			self:SetAttribute(name, value)
		end
		i = i + 2
	end
end

CallbackFrame.AssignSettings = function(self, db)
	if (not db) then
		return
	end
	for key,value in pairs(db) do 
		self:SetAttribute(key,value)
	end
end

CallbackFrame.AssignCallback = function(self, script)
	self:SetAttribute("_onattributechanged", script)
end

Module.CreateCallbackFrame = function(self, module)
	if (CallbackFrames[module]) then
		return
	end

	local callbackFrame = setmetatable(self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate"), CallbackFrame_MT)
	callbackFrame:SetFrameRef("UICenter", self:GetFrame("UICenter"))

	CallbackFrames[module] = callbackFrame
	CallbackFrameOwners[callbackFrame] = module

	module.GetSecureUpdater = function() 
		return callbackFrame 
	end

	return callbackFrame
end

-- Menu options are here! Here! Here!!!
Module.CreateMenuTable = function(self)
	local theme = Private.GetLayoutID()
	local IsLegacy = theme == "Legacy"
	local IsAzerite = theme == "Azerite"

	MenuTable = {}

	-- Let's color enabled/disabled entries entirely, 
	-- instead of making them longer by adding the text.
	local L_ENABLED = "|cff007700%s|r"
	local L_DISABLED = "|cffaa0000%s|r"

	-- Debug Mode
	local DebugMenu = {
		title = L["Debug Mode"], type = nil, hasWindow = true, 
		tooltipText = L["Debug Mode"],
		newbieText = L["Various minor tools that may or may not help you in a time of crisis. Usually only useful to the developer of the user interface."],
		buttons = {}
	}
	if self:GetOwner():IsDebugModeEnabled() then 
		table_insert(DebugMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Debug Console"]),
			disabledTitle = L_DISABLED:format(L["Debug Console"]),
			tooltipText = L["Debug Console"],
			newbieText = L["The debug console is a read-only used by the user interface to show status messages and debug output. Unless you are actively developing new features yourself and intentionally sends thing to the console, you do not need to enable this."],
			type = "TOGGLE_MODE", hasWindow = false, 
			configDB = ADDON, configProfile = "global", modeName = "enableDebugConsole", 
			proxyModule = nil, useCore = true
		})
	else
		table_insert(DebugMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Load Console"]),
			disabledTitle = L_DISABLED:format(L["Load Console"]),
			type = "TOGGLE_MODE", hasWindow = false, 
			configDB = ADDON, configProfile = "global", modeName = "loadConsole", 
			proxyModule = nil, useCore = true
		})
	end

	table_insert(DebugMenu.buttons, {
		enabledTitle = L_ENABLED:format(L["Reload UI"]),
		disabledTitle = L_DISABLED:format(L["Reload UI"]),
		tooltipText = L["Reload UI"],
		newbieText = L["Reloads the user interface. This can be helpful if taints occur, blocking things like quest buttons or bag items from being used."],
		type = "TOGGLE_MODE", hasWindow = false, 
		configDB = ADDON, configProfile = "global", modeName = "reloadUI", 
		proxyModule = nil, useCore = true
	})
	table_insert(MenuTable, DebugMenu)

	-- Aspect Ratio Options
	table_insert(MenuTable, {
		title = L["Aspect Ratio"], type = nil, hasWindow = true, 
		tooltipText = L["Aspect Ratio"],
		newbieText = L["Here you can set how much width of the screen our custom user interface elements will take up. This is mostly useful for users with ultrawide screens, as it allows them to place the frames closer to the center of the screen, making the game easier to play.|n|n|cffcc0000This does NOT apply to Blizzard windows like the character frame, spellbook and similar, and currently that is not something that can easily be implemented!|r"],
		buttons = {
			{
				enabledTitle = L_ENABLED:format(L["Widescreen (16:9)"]),
				disabledTitle = L["Widescreen (16:9)"],
				tooltipText = L["Widescreen (16:9)"],
				newbieText = L["Limits the user interface to a regular 16:9 widescreen ratio. This is how the user interface was designed and intended to be, and thus the default setting."],
				type = "SET_VALUE", 
				configDB = ADDON, configProfile = "global", configKey = "aspectRatio", optionArgs = { "wide" }, 
				proxyModule = nil, useCore = true
			},
			{
				enabledTitle = L_ENABLED:format(L["Ultrawide (21:9)"]),
				disabledTitle = L["Ultrawide (21:9)"],
				tooltipText = L["Ultrawide (21:9)"],
				newbieText = L["Limits the user interface to a 21:9 ultrawide ratio.|n|n|cffcc0000This setting only holds meaning if you have a screen wider than this, and wish to lock the width of our user interface to a 21:9 ratio.|r"],
				type = "SET_VALUE", 
				configDB = ADDON, configProfile = "global", configKey = "aspectRatio", optionArgs = { "ultrawide" }, 
				proxyModule = nil, useCore = true
			},
			{
				enabledTitle = L_ENABLED:format(L["Unlimited"]),
				disabledTitle = L["Unlimited"],
				tooltipText = L["Unlimited"],
				newbieText = L["Uses the full width of the screen, moving elements anchored to the sides of the screen all the way out.|n|n|cffcc0000This setting only holds meaning if you have a screen width a wider ratio than regular 16:9 widescreen.|r"],
				type = "SET_VALUE", 
				configDB = ADDON, configProfile = "global", configKey = "aspectRatio", optionArgs = { "full" }, 
				proxyModule = nil, useCore = true
			}
		}
	})

	-- Aura Filter Options
	-- *only added for select classes
	table_insert(MenuTable, {
		title = L["Aura Filters"], type = nil, hasWindow = true, 
		tooltipText = L["Aura Filters"], 
		newbieText = L["There are very many auras displayed in this game, and we have very limited space to show them in our user interface. So we filter and sort our auras to better use the space we have, and display what matters the most."],

		buttons = clean({
			(not IsForcingSlackAuraFilterMode()) and {
				enabledTitle = L_ENABLED:format(L["Strict"]),
				disabledTitle = L["Strict"],
				tooltipText = L["Strict"],
				newbieText = L["The Strict filter follows strict rules for what to show and what to hide. It will by default show important debuffs, boss debuffs, time based auras from the environment of NPCs, as well as any whitelisted auras for your class."],
				type = "SET_VALUE", 
				configDB = ADDON, configKey = "auraFilterLevel", optionArgs = { 0 }, 
				proxyModule = nil, useCore = true
			} or false,
			{
				enabledTitle = L_ENABLED:format(L["Slack"]),
				disabledTitle = L["Slack"],
				tooltipText = L["Slack"],
				newbieText = L["The Slack filter shows everything from the Strict filter, and also adds a lot of shorter auras or auras with stacks."],
				type = "SET_VALUE", 
				configDB = ADDON, configKey = "auraFilterLevel", optionArgs = { 1 }, 
				proxyModule = nil, useCore = true
			},
			{
				enabledTitle = L_ENABLED:format(L["Spam"]),
				disabledTitle = L["Spam"],
				tooltipText = L["Spam"],
				newbieText = L["The Spam filter shows all that the other filters show, but also adds auras with a very long duration when not currently engaged in combat."],
				type = "SET_VALUE", 
				configDB = ADDON, configKey = "auraFilterLevel", optionArgs = { 2 }, 
				proxyModule = nil, useCore = true
			}
		})
	})
	
	-- Actionbars
	if (Core:IsModuleAvailable("ActionBarMain")) then 
		local ActionBarMenu = {
			title = L["ActionBars"], type = nil, hasWindow = true, 
			tooltipText = ACTIONBARS_LABEL,
			newbieText = ACTIONBARS_SUBTEXT,
			buttons = {}
		}

		if (IsAzerite) then
			table_insert(ActionBarMenu.buttons, {
				title = L["More Buttons"], type = nil, hasWindow = true, 
				buttons = {
					{
						title = L["Extra Buttons Visibility"], type = nil, hasWindow = true, 
						isSlave = true, slaveDB = "ModuleForge::ActionBars", slaveKey = "Azerite::extraButtonsCount", slaveEnableValues = "5,11,17",
						buttons = {
							{
								enabledTitle = L_ENABLED:format(L["MouseOver"]),
								disabledTitle = L["MouseOver"],
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "Azerite::extraButtonsVisibility", optionArgs = { "hover" }, 
								proxyModule = "ActionBarMain"
							},
							{
								enabledTitle = L_ENABLED:format(L["MouseOver + Combat"]),
								disabledTitle = L["MouseOver + Combat"],
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "Azerite::extraButtonsVisibility", optionArgs = { "combat" }, 
								proxyModule = "ActionBarMain"
							},
							{
								enabledTitle = L_ENABLED:format(L["Always Visible"]),
								disabledTitle = L["Always Visible"],
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "Azerite::extraButtonsVisibility", optionArgs = { "always" }, 
								proxyModule = "ActionBarMain"
							}
						}
					},
					{
						enabledTitle = L_ENABLED:format( L["No Extra Buttons"]),
						disabledTitle =  L["No Extra Buttons"],
						type = "SET_VALUE", 
						configDB = "ModuleForge::ActionBars", configKey = "Azerite::extraButtonsCount", optionArgs = { 0 }, 
						proxyModule = "ActionBarMain"
					},
					{
						enabledTitle = L_ENABLED:format(L["+%.0f Buttons"]:format(5)),
						disabledTitle = L["+%.0f Buttons"]:format(5),
						type = "SET_VALUE", 
						configDB = "ModuleForge::ActionBars", configKey = "Azerite::extraButtonsCount", optionArgs = { 5 }, 
						proxyModule = "ActionBarMain"
					},
					{
						enabledTitle = L_ENABLED:format(L["+%.0f Buttons"]:format(11)),
						disabledTitle = L["+%.0f Buttons"]:format(11),
						type = "SET_VALUE", 
						configDB = "ModuleForge::ActionBars", configKey = "Azerite::extraButtonsCount", optionArgs = { 11 }, 
						proxyModule = "ActionBarMain"
					},
					{
						enabledTitle = L_ENABLED:format(L["+%.0f Buttons"]:format(17)),
						disabledTitle = L["+%.0f Buttons"]:format(17),
						type = "SET_VALUE", 
						configDB = "ModuleForge::ActionBars", configKey = "Azerite::extraButtonsCount", optionArgs = { 17 }, 
						proxyModule = "ActionBarMain"
					}
				}
			})
			
			table_insert(ActionBarMenu.buttons, {
				title = L["Pet Bar"], type = nil, hasWindow = true, 
				buttons = {
					{
						title = L["Pet Bar Visibility"], type = nil, hasWindow = true, 
						isSlave = true, slaveDB = "ModuleForge::ActionBars", slaveKey = "Azerite::petBarEnabled",
						buttons = {
							{
								enabledTitle = L_ENABLED:format(L["MouseOver"]),
								disabledTitle = L["MouseOver"],
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "Azerite::petBarVisibility", optionArgs = { "hover" }, 
								proxyModule = "ActionBarMain"
							},
							{
								enabledTitle = L_ENABLED:format(L["MouseOver + Combat"]),
								disabledTitle = L["MouseOver + Combat"],
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "Azerite::petBarVisibility", optionArgs = { "combat" }, 
								proxyModule = "ActionBarMain"
							},
							{
								enabledTitle = L_ENABLED:format(L["Always Visible"]),
								disabledTitle = L["Always Visible"],
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "Azerite::petBarVisibility", optionArgs = { "always" }, 
								proxyModule = "ActionBarMain"
							}
						}
					},
					{
						enabledTitle = L["Enabled"],
						disabledTitle = L["Disabled"],
						tooltipText = L["Pet Bar"],
						enabledNewbieText = L["Click to disable the Pet Action Bar."],
						disabledNewbieText = L["Click to enable the Pet Action Bar."],
						type = "TOGGLE_VALUE", hasWindow = false, 
						configDB = "ModuleForge::ActionBars", configKey = "Azerite::petBarEnabled", 
						proxyModule = "ActionBarMain"
					}
				},
			})

		elseif (IsLegacy) then

			table_insert(ActionBarMenu.buttons, {
				title = L["Extra Bars"], type = nil, hasWindow = true, 
				buttons = {
					{
						enabledTitle = L_ENABLED:format(L["Secondary Bar"]),
						disabledTitle = L_DISABLED:format(L["Secondary Bar"]),
						type = "TOGGLE_VALUE", hasWindow = false, 
						configDB = "ModuleForge::ActionBars", configKey = "Legacy::enableSecondaryBar", 
						proxyModule = "ActionBarMain"
					},
					{
						enabledTitle = L_ENABLED:format(L["Side Bar One"]),
						disabledTitle = L_DISABLED:format(L["Side Bar One"]),
						type = "TOGGLE_VALUE", hasWindow = false, 
						configDB = "ModuleForge::ActionBars", configKey = "Legacy::enableSideBarRight", 
						proxyModule = "ActionBarMain"
					},
					{
						enabledTitle = L_ENABLED:format(L["Side Bar Two"]),
						disabledTitle = L_DISABLED:format(L["Side Bar Two"]),
						type = "TOGGLE_VALUE", hasWindow = false, 
						configDB = "ModuleForge::ActionBars", configKey = "Legacy::enableSideBarLeft", 
						proxyModule = "ActionBarMain"
					}
				},
			})

			table_insert(ActionBarMenu.buttons, {
				title = L["Pet Bar"], type = nil, hasWindow = true, 
				buttons = {
					{
						enabledTitle = L["Enabled"],
						disabledTitle = L["Disabled"],
						tooltipText = L["Pet Bar"],
						enabledNewbieText = L["Click to disable the Pet Action Bar."],
						disabledNewbieText = L["Click to enable the Pet Action Bar."],
						type = "TOGGLE_VALUE", hasWindow = false, 
						configDB = "ModuleForge::ActionBars", configKey = "Legacy::enablePetBar", 
						proxyModule = "ActionBarMain"
					}
				},
			})

		end

		if (IsRetail) then
			-- All these options are for 9.0.1 gamepads.
			local bindMenu = { 
				title = KEY_BINDINGS, type = nil, hasWindow = true, 
				buttons = {
					{
						title = L["Display Priority"], type = nil, hasWindow = true, 
						buttons = {
							{
								enabledTitle = L_ENABLED:format(L["GamePad First"]),
								disabledTitle = L["GamePad First"],
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "keybindDisplayPriority", optionArgs = { "gamepad" }, 
								proxyModule = "ActionBarMain"
							},
							{
								enabledTitle = L_ENABLED:format(L["Keyboard First"]),
								disabledTitle = L["Keyboard First"],
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "keybindDisplayPriority", optionArgs = { "keyboard" }, 
								proxyModule = "ActionBarMain"
							},
							{
								enabledTitle = L_ENABLED:format(DEFAULT),
								disabledTitle = DEFAULT,
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "keybindDisplayPriority", optionArgs = { "default" }, 
								proxyModule = "ActionBarMain"
							}
						}
					},
					{
						title = L["GamePad Type"], type = nil, hasWindow = true,
						--isSlave = true, slaveDB = "ModuleForge::ActionBars", slaveKey = "gamePadType",
						buttons = {
							{
								enabledTitle = L_ENABLED:format(L["Xbox"]),
								disabledTitle = L["Xbox"],
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "gamePadType", optionArgs = { "xbox" }, 
								proxyModule = "ActionBarMain"
							},
							{
								enabledTitle = L_ENABLED:format(L["Xbox (Reversed)"]),
								disabledTitle = L["Xbox (Reversed)"],
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "gamePadType", optionArgs = { "xbox-reversed" }, 
								proxyModule = "ActionBarMain"
							},
							{
								enabledTitle = L_ENABLED:format(L["Playstation"]),
								disabledTitle = L["Playstation"],
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "gamePadType", optionArgs = { "playstation" }, 
								proxyModule = "ActionBarMain"
							},
							{
								enabledTitle = L_ENABLED:format(DEFAULT),
								disabledTitle = DEFAULT,
								type = "SET_VALUE", 
								configDB = "ModuleForge::ActionBars", configKey = "gamePadType", optionArgs = { "default" }, 
								proxyModule = "ActionBarMain"
							}
						}
					}
				} 
			}

			if (Core:IsModuleAvailable("Bindings")) then 
				table_insert(bindMenu.buttons, {
					enabledTitle = L_ENABLED:format(L["Bind Mode"]),
					disabledTitle = L_DISABLED:format(L["Bind Mode"]),
					type = "TOGGLE_MODE", hasWindow = false, 
					proxyModule = "Bindings", modeName = "bindMode"
				})
			end 
			table_insert(ActionBarMenu.buttons, bindMenu)
		else
			-- Just add the bind mode option and nothing else for classic.
			if (Core:IsModuleAvailable("Bindings")) then 
				table_insert(ActionBarMenu.buttons, {
					enabledTitle = L_ENABLED:format(L["Bind Mode"]),
					disabledTitle = L_DISABLED:format(L["Bind Mode"]),
					type = "TOGGLE_MODE", hasWindow = false, 
					proxyModule = "Bindings", modeName = "bindMode"
				})
			end 
		end

		table_insert(ActionBarMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Cast on Down"]),
			disabledTitle = L_DISABLED:format(L["Cast on Down"]),
			tooltipText = ACTION_BUTTON_USE_KEY_DOWN,
			newbieText = OPTION_TOOLTIP_ACTION_BUTTON_USE_KEY_DOWN,
			type = "TOGGLE_VALUE", hasWindow = false, 
			configDB = "ModuleForge::ActionBars", configKey = "castOnDown", 
			proxyModule = "ActionBarMain"
		})

		table_insert(ActionBarMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Button Lock"]),
			disabledTitle = L_DISABLED:format(L["Button Lock"]),
			tooltipText = LOCK_ACTIONBAR_TEXT,
			type = "TOGGLE_VALUE", hasWindow = false, 
			configDB = "ModuleForge::ActionBars", configKey = "buttonLock", 
			proxyModule = "ActionBarMain"
		})
		table_insert(MenuTable, ActionBarMenu)
	end

	-- ChatFrames
	if (Core:IsModuleAvailable("BlizzardChatFrames")) then 
		-- Always show chat filter choices. Except when they're not there, like right now. /doh
		local ChatFrameMenuDisabled = {
			title = L["Chat Windows"], type = nil, hasWindow = true, 
			buttons = {
				{
					title = L["Chat Filters"], type = nil, hasWindow = true, 
					buttons = {
						{
							enabledTitle = L_ENABLED:format(L["Chat Styling"]),
							disabledTitle = L_DISABLED:format(L["Chat Styling"]),
							tooltipText = L["Chat Styling"],
							newbieText = L["This is a chat filter that reformats a lot of the game chat output to a much nicer format. This includes when you receive loot, earn currency or gold, when somebody gets and achievement, and so on.|n|nNote that this filter does not add or remove anything, it simply makes it easier on the eyes."],
							type = "TOGGLE_VALUE", 
							configDB = "ChatFilters", configKey = "enableChatStyling", 
							proxyModule = "ChatFilters"
						},
						{
							enabledTitle = L_ENABLED:format(L["Hide Monster Messages"]),
							disabledTitle = L_DISABLED:format(L["Hide Monster Messages"]),
							tooltipText = L["Hide Monster Messages"],
							newbieText = L["This filter hides most things NPCs or monsters say from that chat. Monster emotes and whispers are moved to the same place mid-screen as boss emotes and whispers are displayed.|n|nThis does not affect what is visible in chat bubbles above their heads, which is where we wish this kind of information to be available."],
							type = "TOGGLE_VALUE", 
							configDB = "ChatFilters", configKey = "enableMonsterFilter", 
							proxyModule = "ChatFilters"
						},
						{
							enabledTitle = L_ENABLED:format(L["Hide Boss Messages"]),
							disabledTitle = L_DISABLED:format(L["Hide Boss Messages"]),
							tooltipText = L["Hide Boss Messages"],
							newbieText = L["This filter hides most things boss monsters say from that chat. |n|nThis does not affect what is visible mid-screen during raid fights, nor what you'll see in chat bubbles above their heads, which is where we wish this kind of information to be available."],
							type = "TOGGLE_VALUE", 
							configDB = "ChatFilters", configKey = "enableBossFilter", 
							proxyModule = "ChatFilters"
						},
						{
							enabledTitle = L_ENABLED:format(L["Hide Spam"]),
							disabledTitle = L_DISABLED:format(L["Hide Spam"]),
							tooltipText = L["Hide Spam"],
							newbieText = L["This filter hides a lot of messages related to group members in raids and especially battlegrounds, such as who joins, leaves, who loots something and so on.|n|nThe idea here is free up the chat and allow you to see what people are actually saying, and not just the constant spam of people coming and going."],
							type = "TOGGLE_VALUE", 
							configDB = "ChatFilters", configKey = "enableSpamFilter", 
							proxyModule = "ChatFilters"
						}
					}
				}
			}
		}

		local ChatFrameMenu = {
			title = L["Chat Windows"], type = nil, hasWindow = true, 
			buttons = {}
		}

		-- Only apply these when no conflicting addon is loaded.
		if (Core:IsModuleAvailable("BlizzardChatFrames")) then 
			table_insert(ChatFrameMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Chat Outline"]),
				disabledTitle = L_DISABLED:format(L["Chat Outline"]),
				tooltipText = L["Chat Outline"],
				newbieText = L["Toggles outlined text in the chat windows.|n|nWe recommend leaving it on as the chat can be really hard to read in certain situations otherwise."],
				type = "TOGGLE_VALUE", 
				configDB = "BlizzardChatFrames", configKey = "enableChatOutline", 
				proxyModule = "BlizzardChatFrames"
			})
		end
		table_insert(MenuTable, ChatFrameMenu)
	end

	-- Nameplates
	if (Core:IsModuleAvailable("NamePlates")) then 
		local NamePlateMenu = { title = L["NamePlates"], type = nil, hasWindow = true, buttons = {} }

		-- Personal Resource Display settings.
		if (IsRetail) then
			table_insert(NamePlateMenu.buttons, {
				title = L["PRD"], type = nil, hasWindow = true, 
				tooltipText = DISPLAY_PERSONAL_RESOURCE,
				newbieText = L["This controls the visibility options of the Personal Resource Display, your personal nameplate located beneath your character."],
				buttons = {
					{
						enabledTitle = L["Enabled"],
						disabledTitle = L["Disabled"],
						tooltipText = DISPLAY_PERSONAL_RESOURCE,
						enabledNewbieText = L["Click to disable the Personal Resource Display."],
						disabledNewbieText = L["Click to enable the Personal Resource Display."],
						type = "TOGGLE_VALUE", 
						configDB = "NamePlates", configKey = "nameplateShowSelf", 
						proxyModule = "NamePlates"
					},
					{
						enabledTitle = L_ENABLED:format(L["Show Always"]),
						disabledTitle = L["Show Always"],
						type = "TOGGLE_VALUE", 
						configDB = "NamePlates", configKey = "NameplatePersonalShowAlways", 
						isSlave = true, slaveDB = "NamePlates", slaveKey = "nameplateShowSelf",
						proxyModule = "NamePlates"
					},
					{
						enabledTitle = L_ENABLED:format(L["Show In Combat"]),
						disabledTitle = L["Show In Combat"],
						type = "TOGGLE_VALUE", 
						configDB = "NamePlates", configKey = "NameplatePersonalShowInCombat", 
						isSlave = true, slaveDB = "NamePlates", slaveKey = "nameplateShowSelf",
						proxyModule = "NamePlates"
					},
					{
						enabledTitle = L_ENABLED:format(L["Show With Target"]),
						disabledTitle = L["Show With Target"],
						type = "TOGGLE_VALUE", 
						configDB = "NamePlates", configKey = "NameplatePersonalShowWithTarget", 
						isSlave = true, slaveDB = "NamePlates", slaveKey = "nameplateShowSelf",
						proxyModule = "NamePlates"
					}
				}
			})
		end
		
		-- Click-through settings
		table_insert(NamePlateMenu.buttons, {
			title = MAKE_UNINTERACTABLE, type = nil, hasWindow = true, 
			tooltipText = L["Click-Through NamePlates"],
			newbieText = L["Here you can choose whether NamePlates should react to mouse events and mouse clicks as normal, or set them to be click-trhough, meaning you can see them but not interact with them.|n|nIf you wish to be able to click on a nameplate to select that unit as your target, then you should NOT use click-through NamePlates."],
			buttons = {
				{
					enabledTitle = L_ENABLED:format(L["Enemies"]),
					disabledTitle = L_DISABLED:format(L["Enemies"]),
					type = "TOGGLE_VALUE", 
					configDB = "NamePlates", configKey = "clickThroughEnemies", 
					proxyModule = "NamePlates"
				},
				{
					enabledTitle = L_ENABLED:format(L["Friends"]),
					disabledTitle = L_DISABLED:format(L["Friends"]),
					type = "TOGGLE_VALUE", 
					configDB = "NamePlates", configKey = "clickThroughFriends", 
					proxyModule = "NamePlates"
				}
			}
		})

		-- Toggle nameplate auras
		table_insert(NamePlateMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Auras"]),
			disabledTitle = L_DISABLED:format(L["Auras"]),
			type = "TOGGLE_VALUE", 
			configDB = "NamePlates", configKey = "enableAuras", 
			proxyModule = "NamePlates"
		})
		
		table_insert(MenuTable, NamePlateMenu)

	end 

	-- Unitframes
	local hasUnits
	local UnitFrameMenu = {
		title = L["UnitFrames"], type = nil, hasWindow = true, 
		buttons = {}
	}

	-- Group Frames
	if (IsAzerite) then
		if (Core:IsModuleAvailable("UnitFrameParty")) then 
			hasUnits = true
			table_insert(UnitFrameMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Party Frames"]),
				disabledTitle = L_DISABLED:format(L["Party Frames"]),
				type = "TOGGLE_VALUE", 
				configDB = "UnitFrameParty", configKey = "enablePartyFrames", 
				proxyModule = "UnitFrameParty"
			})
		end

		if (Core:IsModuleAvailable("UnitFrameRaid")) then 
			hasUnits = true
			table_insert(UnitFrameMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Raid Frames"]),
				disabledTitle = L_DISABLED:format(L["Raid Frames"]),
				type = "TOGGLE_VALUE", 
				configDB = "UnitFrameRaid", configKey = "enableRaidFrames", 
				proxyModule = "UnitFrameRaid"
			})
		end
	elseif (IsLegacy) then
		if (Core:IsModuleAvailable("ModuleForge::UnitFrames")) then 
			hasUnits = true
			table_insert(UnitFrameMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Party Frames"]),
				disabledTitle = L_DISABLED:format(L["Party Frames"]),
				type = "TOGGLE_VALUE", 
				configDB = "ModuleForge::UnitFrames", configKey = "Legacy::EnablePartyFrames", 
				proxyModule = "ModuleForge::UnitFrames"
			})
		end

		if (Core:IsModuleAvailable("ModuleForge::UnitFrames")) then 
			hasUnits = true
			table_insert(UnitFrameMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Raid Frames"]),
				disabledTitle = L_DISABLED:format(L["Raid Frames"]),
				type = "TOGGLE_VALUE", 
				configDB = "ModuleForge::UnitFrames", configKey = "Legacy::EnableRaidFrames", 
				proxyModule = "ModuleForge::UnitFrames"
			})
		end
	end

	if (IsAzerite) then
		if (Core:IsModuleAvailable("UnitFramePlayer")) then 
			hasUnits = true

			-- Player options
			local PlayerMenu = {
				title = PLAYER, type = nil, hasWindow = true, 
				buttons = {}
			}
			
			-- Player Auras
			table_insert(PlayerMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Auras"]),
				disabledTitle = L_DISABLED:format(L["Auras"]),
				type = "TOGGLE_VALUE", 
				configDB = "UnitFramePlayer", configKey = "enableAuras", 
				proxyModule = "UnitFramePlayer"
			})

			-- Mana orb
			if (PlayerClass == "DRUID") or (PlayerClass == "HUNTER") 
			or (PlayerClass == "PALADIN") or (PlayerClass == "SHAMAN")
			or (PlayerClass == "MAGE") or (PlayerClass == "PRIEST") or (PlayerClass == "WARLOCK") then
				hasUnits = true
				table_insert(PlayerMenu.buttons, {
					enabledTitle = L_ENABLED:format(L["Use Mana Orb"]),
					disabledTitle = L_DISABLED:format(L["Use Mana Orb"]),
					type = "TOGGLE_VALUE", 
					configDB = "UnitFramePlayer", configKey = "enablePlayerManaOrb", 
					proxyModule = "UnitFramePlayer"
				})
			end

			table_insert(UnitFrameMenu.buttons, PlayerMenu)
		end

		-- Target options
		if (Core:IsModuleAvailable("UnitFrameTarget")) then 
			hasUnits = true

			-- Target options
			local TargetMenu = {
				title = TARGET, type = nil, hasWindow = true, 
				buttons = {}
			}
			
			-- Target Auras
			table_insert(TargetMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Auras"]),
				disabledTitle = L_DISABLED:format(L["Auras"]),
				type = "TOGGLE_VALUE", 
				configDB = "UnitFrameTarget", configKey = "enableAuras", 
				proxyModule = "UnitFrameTarget"
			})

			table_insert(UnitFrameMenu.buttons, TargetMenu)
		end
	end
	if (hasUnits) then
		table_insert(MenuTable, UnitFrameMenu)
	end

	-- HUD
	if (Core:IsModuleAvailable("UnitFramePlayerHUD")) then 
		local HUDMenu = {
			title = L["HUD"], type = nil, hasWindow = true, 
			tooltipText = L["HUD"],
			newbieText = L["A head-up display, also known as a HUD, is any transparent display that presents data without requiring users to look away from their usual viewpoints. In our user interface, we use this to label elements appearing in the middle of the screen, then disappearing."],
			buttons = clean({
				IsAzerite and {
					enabledTitle = L_ENABLED:format(L["CastBar"]),
					disabledTitle = L_DISABLED:format(L["CastBar"]),
					tooltipText = L["CastBar"],
					newbieText = L["Toggles your own castbar, which appears in the bottom center part of the screen, beneath your character and above your actionbars."],
					type = "TOGGLE_VALUE", 
					configDB = "UnitFramePlayerHUD", configKey = "enableCast", 
					proxyModule = "UnitFramePlayerHUD"
				} or false
			})
		}
		-- Only insert this entry if SimpleClassPower isn't loaded. 
		if (IsAzerite) then
			if (not self:IsAddOnEnabled("SimpleClassPower")) then 
				table_insert(HUDMenu.buttons, {
					enabledTitle = L_ENABLED:format(L["ClassPower"]),
					disabledTitle = L_DISABLED:format(L["ClassPower"]),
					tooltipText = L["ClassPower"],
					newbieText = L["Toggles the point based resource systems unique to your own class."],
					type = "TOGGLE_VALUE", 
					configDB = "UnitFramePlayerHUD", configKey = "enableClassPower", 
					proxyModule = "UnitFramePlayerHUD"
				})
			end
		end

		if (IsRetail) then
			-- Talking Head
			table_insert(HUDMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["TalkingHead"]),
				disabledTitle = L_DISABLED:format(L["TalkingHead"]),
				tooltipText = L["TalkingHead"],
				newbieText = L["Toggles the TalkingHead frame. This is the frame you'll see appear in the top center part of the screen, with a portrait and a text. This will usually occur when reaching certain world quest areas, or when a forced quest from your faction leader appears."],
				type = "TOGGLE_VALUE", 
				configDB = "BlizzardFloaterHUD", configKey = "enableTalkingHead", 
				proxyModule = "BlizzardFloaterHUD"
			})
		end

		-- Objectives Tracker
		if (Core:IsModuleAvailable("BlizzardObjectivesTracker")) then 
			table_insert(HUDMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Objectives Tracker"]),
				disabledTitle = L_DISABLED:format(L["Objectives Tracker"]),
				tooltipText = L["Objectives Tracker"],
				newbieText = L["The Objectives Tracker shows your quests, quest item buttons, world quests, campaign quests, mythic affixes, Torghast powers and so on.|n|nAnnoying as hell, but best left on unless you're very, very pro."],
				type = "TOGGLE_VALUE", 
				configDB = "BlizzardFloaterHUD", configKey = "enableObjectivesTracker", 
				proxyModule = "BlizzardFloaterHUD"
			})
		end
			
		-- RaidWarning
		table_insert(HUDMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Raid Warnings"]),
			disabledTitle = L_DISABLED:format(L["Raid Warnings"]),
			tooltipText = L["Raid Warnings"],
			newbieText = L["Raid Warnings are important raid messages appearing in the top center part of the screen. This is where messages sent by your raid leader and raid officers appear. It is recommended to leave these on for the most part.|n|nThe exception is when you get into WoW Classic battlegrounds where everybody is promoted, and some jokers keep spamming. Then it is good to disable."],
			type = "TOGGLE_VALUE", 
			configDB = "BlizzardFloaterHUD", configKey = "enableRaidWarnings", 
			proxyModule = "BlizzardFloaterHUD"
		})

		-- RaidWarning
		table_insert(HUDMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Monster Emotes"]),
			disabledTitle = L_DISABLED:format(L["Monster Emotes"]),
			tooltipText = L["Monster Emotes"],
			newbieText = L["Toggles the display of boss- and moster emotes. If you're a skilled player, it is not recommended to turn these on, as some world quests and most boss encounters send important messages here.|n|nSupport wheel users relying on Dumb Boss Mods can do whatever they please, it's not like they're looking at anything else than bars anyway."],
			type = "TOGGLE_VALUE", 
			configDB = "BlizzardFloaterHUD", configKey = "enableRaidBossEmotes", 
			proxyModule = "BlizzardFloaterHUD"
		})

		if (IsRetail) then
			-- LevelUpDisplay
			table_insert(HUDMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Kills, Levels, Loot"]),
				disabledTitle = L_DISABLED:format(L["Kills, Levels, Loot"]),
				tooltipText = L["Kills, Levels, Loot"],
				newbieText = L["This includes most mid-screen announcements like when you gain a level, you receive certain types of loot, and any banner shown when you complete a scenario, kill a boss and so forth."],
				type = "TOGGLE_VALUE", 
				configDB = "BlizzardFloaterHUD", configKey = "enableAnnouncements", 
				proxyModule = "BlizzardFloaterHUD"
			})

			-- Alerts
			table_insert(HUDMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Alerts"]),
				disabledTitle = L_DISABLED:format(L["Alerts"]),
				tooltipText = L["Alerts"],
				newbieText = L["Toggles the display of alert frames. These include the achievement popups, as well as multiple types of currency loot in some expansion content like the Legion zones."],
				type = "TOGGLE_VALUE", 
				configDB = "BlizzardFloaterHUD", configKey = "enableAlerts", 
				proxyModule = "BlizzardFloaterHUD"
			})
		end

		table_insert(MenuTable, HUDMenu)
	end

	-- Explorer Mode
	if (IsAzerite or IsLegacy) then
		if (Core:IsModuleAvailable("ExplorerMode")) then 
			if (IsAzerite) then
				table_insert(MenuTable, {
					title = L["Explorer Mode"], type = nil, hasWindow = true, 
					buttons = {
						{
							title = L["Chat Positioning"],
							enabledTitle = L_ENABLED:format(L["Chat Positioning"]),
							disabledTitle = L_DISABLED:format(L["Chat Positioning"]),
							type = "TOGGLE_VALUE", 
							configDB = "ExplorerMode", configKey = "enableExplorerChat", 
							isSlave = true, slaveDB = "ExplorerMode", slaveKey = "enableExplorer",
							proxyModule = "ExplorerMode"
						},
						{
							enabledTitle = L_ENABLED:format(L["Player Fading"]),
							disabledTitle = L_DISABLED:format(L["Player Fading"]),
							type = "TOGGLE_VALUE", 
							configDB = "ExplorerMode", configKey = "enableExplorer", 
							proxyModule = "ExplorerMode"
						}--[[,
						{
							enabledTitle = L_ENABLED:format(L["Tracker Fading"]),
							disabledTitle = L_DISABLED:format(L["Tracker Fading"]),
							type = "TOGGLE_VALUE", 
							configDB = "ExplorerMode", configKey = "enableTrackerFading", 
							proxyModule = "ExplorerMode"
						}]]
					}
				})

			elseif (IsLegacy) then
				table_insert(MenuTable, {
					enabledTitle = L_ENABLED:format(L["Explorer Mode"]),
					disabledTitle = L_DISABLED:format(L["Explorer Mode"]),
					type = "TOGGLE_VALUE", 
					configDB = "ExplorerMode", configKey = "enableExplorer", 
					proxyModule = "ExplorerMode"
				})
			end
		end 
	end 

	-- Healer Layout
	if (IsAzerite) then
		table_insert(MenuTable, {
			enabledTitle = L_ENABLED:format(L["Healer Mode"]),
			disabledTitle = L_DISABLED:format(L["Healer Mode"]),
			type = "TOGGLE_VALUE", 
			configDB = ADDON, configKey = "enableHealerMode", 
			proxyModule = nil, useCore = true, modeName = "healerMode"
		})
	end

end
