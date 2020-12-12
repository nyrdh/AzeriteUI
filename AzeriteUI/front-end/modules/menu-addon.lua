local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("OptionsMenu", "HIGH", "LibMessage", "LibEvent", "LibDB", "LibFrame", "LibSound", "LibTooltip", "LibClientBuild")
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

-- Constants for client version
local IsClassic = Module:IsClassic()
local IsRetail = Module:IsRetail()

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
							sibling:Enable()
						else
							sibling:Disable()
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

			local isSlave = self:GetAttribute("isSlave"); 
			if (isSlave) then
				local slaveDB = self:GetAttribute("slaveDB"); 
				local slaveKey = self:GetAttribute("slaveKey"); 
				local slaveAttributeName = "DB_"..slaveDB.."_"..slaveKey; 
				local slaveValue = window:GetAttribute(slaveAttributeName); 
				if (not slaveValue) then
					self:Disable()
					-- close child windows
					local window = self:GetFrameRef("Window");
					if (window) then
						window:Hide();
						window:CallMethod("OnHide");
					end
				else
					self:Enable()
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
							sibling:Enable()
						else
							sibling:Disable()
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

Button.OnShow = function(self)
	self.isDown = false
	self:Update()
end 

Button.OnHide = function(self)
	self.isDown = false
	self:Update()
end 

Button.OnMouseDown = function(self)
	self.isDown = true
	self:Update()
end 

Button.OnMouseUp = function(self)
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

Button.Update = function(self)
	local layout = self.layout

	if (self.updateType == "GET_VALUE") then 
		-- nothing to do here

	elseif (self.updateType == "SET_VALUE") then 
		local db = GetConfig(self.optionDB, self.optionProfile)
		local option = db[self.optionName]
		local checked = option == self.optionArg1

		if (self:IsEnabled()) then
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

		if (self:IsEnabled()) then
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
			if (self:IsEnabled()) then
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

	self:SetAttribute("_onclick", secureSnippets.windowToggle)
	self:SetFrameRef("Window", window)

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
		tooltip:AddLine(self.leftButtonTooltip, r,g,b, true)
	end
	if (self.middleButtonTooltip) then
		tooltip:AddLine(self.middleButtonTooltip, r,g,b, true)
	end
	if (self.rightButtonTooltip) then
		tooltip:AddLine(self.rightButtonTooltip, r,g,b, true)
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
	option:HookScript("OnEnter", Button.Update)
	option:HookScript("OnLeave", Button.Update)

	option:SetAttribute("updateType", updateType)
	option:SetAttribute("optionDB", optionDB)
	option:SetAttribute("optionProfile", optionProfile)
	option:SetAttribute("optionName", optionName)

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

	--if (updateType == "SET_VALUE") or (updateType == "GET_VALUE") or (updateType == "TOGGLE_VALUE") or (updateType == "TOGGLE_MODE") then 
		option:SetAttribute("_onclick", secureSnippets.buttonClick)
	--end

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
	self:GetParent().windowIsShown = nil
	self:GetParent():Update()
end

Window.OnShow = function(self)
	self:GetParent().windowIsShown = true
	self:GetParent():Update()
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
					option:Enable()
				else
					option:Disable()
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

Module.ShouldHaveMenu = function(self, module)
	return module and not(module:IsUserDisabled() or module:IsIncompatible() or module:DependencyFailed())
end

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
		buttons = {}
	}
	if self:GetOwner():IsDebugModeEnabled() then 
		table_insert(DebugMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Debug Console"]),
			disabledTitle = L_DISABLED:format(L["Debug Console"]),
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
		type = "TOGGLE_MODE", hasWindow = false, 
		configDB = ADDON, configProfile = "global", modeName = "reloadUI", 
		proxyModule = nil, useCore = true
	})
	table_insert(MenuTable, DebugMenu)

	-- Aspect Ratio Options
	table_insert(MenuTable, {
		title = L["Aspect Ratio"], type = nil, hasWindow = true, 
		buttons = {
			{
				enabledTitle = L_ENABLED:format(L["Widescreen (16:9)"]),
				disabledTitle = L["Widescreen (16:9)"],
				type = "SET_VALUE", 
				configDB = ADDON, configProfile = "global", configKey = "aspectRatio", optionArgs = { "wide" }, 
				proxyModule = nil, useCore = true
			},
			{
				enabledTitle = L_ENABLED:format(L["Ultrawide (21:9)"]),
				disabledTitle = L["Ultrawide (21:9)"],
				type = "SET_VALUE", 
				configDB = ADDON, configProfile = "global", configKey = "aspectRatio", optionArgs = { "ultrawide" }, 
				proxyModule = nil, useCore = true
			},
			{
				enabledTitle = L_ENABLED:format(L["Unlimited"]),
				disabledTitle = L["Unlimited"],
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
		buttons = clean({
			(not IsForcingSlackAuraFilterMode()) and {
				enabledTitle = L_ENABLED:format(L["Strict"]),
				disabledTitle = L["Strict"],
				type = "SET_VALUE", 
				configDB = ADDON, configKey = "auraFilterLevel", optionArgs = { 0 }, 
				proxyModule = nil, useCore = true
			} or false,
			{
				enabledTitle = L_ENABLED:format(L["Slack"]),
				disabledTitle = L["Slack"],
				type = "SET_VALUE", 
				configDB = ADDON, configKey = "auraFilterLevel", optionArgs = { 1 }, 
				proxyModule = nil, useCore = true
			},
			{
				enabledTitle = L_ENABLED:format(L["Spam"]),
				disabledTitle = L["Spam"],
				type = "SET_VALUE", 
				configDB = ADDON, configKey = "auraFilterLevel", optionArgs = { 2 }, 
				proxyModule = nil, useCore = true
			}
		})
	})
	
	-- Actionbars
	local ActionBarMain = Core:GetModule("ActionBarMain", true)
	if (self:ShouldHaveMenu(ActionBarMain)) then 

		local ActionBarMenu = {
			title = L["ActionBars"], type = nil, hasWindow = true, 
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

			local Bindings = Core:GetModule("Bindings", true)
			if (self:ShouldHaveMenu(Bindings)) then 
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
			local Bindings = Core:GetModule("Bindings", true)
			if (self:ShouldHaveMenu(Bindings)) then 
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
			type = "TOGGLE_VALUE", hasWindow = false, 
			configDB = "ModuleForge::ActionBars", configKey = "castOnDown", 
			proxyModule = "ActionBarMain"
		})

		table_insert(ActionBarMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Button Lock"]),
			disabledTitle = L_DISABLED:format(L["Button Lock"]),
			type = "TOGGLE_VALUE", hasWindow = false, 
			configDB = "ModuleForge::ActionBars", configKey = "buttonLock", 
			proxyModule = "ActionBarMain"
		})
		table_insert(MenuTable, ActionBarMenu)
	end

	-- ChatFrames
	-- Always show chat filter choices.
	local ChatFrameMenu = {
		title = L["Chat Windows"], type = nil, hasWindow = true, 
		buttons = {
			{
				title = L["Chat Filters"], type = nil, hasWindow = true, 
				buttons = {
					{
						enabledTitle = L_ENABLED:format(L["Chat Styling"]),
						disabledTitle = L_DISABLED:format(L["Chat Styling"]),
						type = "TOGGLE_VALUE", 
						configDB = "ChatFilters", configKey = "enableChatStyling", 
						proxyModule = "ChatFilters"
					},
					{
						enabledTitle = L_ENABLED:format(L["Hide Monster Messages"]),
						disabledTitle = L_DISABLED:format(L["Hide Monster Messages"]),
						type = "TOGGLE_VALUE", 
						configDB = "ChatFilters", configKey = "enableMonsterFilter", 
						proxyModule = "ChatFilters"
					},
					{
						enabledTitle = L_ENABLED:format(L["Hide Boss Messages"]),
						disabledTitle = L_DISABLED:format(L["Hide Boss Messages"]),
						type = "TOGGLE_VALUE", 
						configDB = "ChatFilters", configKey = "enableBossFilter", 
						proxyModule = "ChatFilters"
					},
					{
						enabledTitle = L_ENABLED:format(L["Hide Spam"]),
						disabledTitle = L_DISABLED:format(L["Hide Spam"]),
						type = "TOGGLE_VALUE", 
						configDB = "ChatFilters", configKey = "enableSpamFilter", 
						proxyModule = "ChatFilters"
					}
				}
			}
		}
	}
	-- Only apply these when no conflicting addon is loaded.
	local BlizzardChatFrames = Core:GetModule("BlizzardChatFrames", true)
	if (self:ShouldHaveMenu(BlizzardChatFrames)) then 
		table_insert(ChatFrameMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Chat Outline"]),
			disabledTitle = L_DISABLED:format(L["Chat Outline"]),
			type = "TOGGLE_VALUE", 
			configDB = "BlizzardChatFrames", configKey = "enableChatOutline", 
			proxyModule = "BlizzardChatFrames"
		})
	end
	table_insert(MenuTable, ChatFrameMenu)

	-- Nameplates
	local NamePlates = Core:GetModule("NamePlates", true)
	if (self:ShouldHaveMenu(NamePlates)) then 
		
		table_insert(MenuTable, {
			title = L["NamePlates"], type = nil, hasWindow = true, 
			buttons = clean({
				-- Disable player auras
				IsAzerite and {
					enabledTitle = L_ENABLED:format(L["Auras"]),
					disabledTitle = L_DISABLED:format(L["Auras"]),
					type = "TOGGLE_VALUE", 
					configDB = "NamePlates", configKey = "enableAuras", 
					proxyModule = "NamePlates"
				} or false,
				-- Click-through settings
				{
					title = MAKE_UNINTERACTABLE, type = nil, hasWindow = true, 
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
				}
			})
		})

	end 

	-- Unitframes
	local hasUnits
	local UnitFrameMenu = {
		title = L["UnitFrames"], type = nil, hasWindow = true, 
		buttons = {
			-- Player options
		}
	}

	if (IsAzerite) then
		local UnitFrameParty = Core:GetModule("UnitFrameParty", true)
		if (self:ShouldHaveMenu(UnitFrameParty)) then 
			hasUnits = true
			table_insert(UnitFrameMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Party Frames"]),
				disabledTitle = L_DISABLED:format(L["Party Frames"]),
				type = "TOGGLE_VALUE", 
				configDB = "UnitFrameParty", configKey = "enablePartyFrames", 
				proxyModule = "UnitFrameParty"
			})
		end

		local UnitFrameRaid = Core:GetModule("UnitFrameRaid", true)
		if (self:ShouldHaveMenu(UnitFrameRaid)) then 
			hasUnits = true
			table_insert(UnitFrameMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Raid Frames"]),
				disabledTitle = L_DISABLED:format(L["Raid Frames"]),
				type = "TOGGLE_VALUE", 
				configDB = "UnitFrameRaid", configKey = "enableRaidFrames", 
				proxyModule = "UnitFrameRaid"
			})
		end
	end

	if (IsAzerite) then
		local UnitFramePlayer = Core:GetModule("UnitFramePlayer", true)
		if (self:ShouldHaveMenu(UnitFramePlayer)) then 
			if (PlayerClass == "DRUID") or (PlayerClass == "HUNTER") 
			or (PlayerClass == "PALADIN") or (PlayerClass == "SHAMAN")
			or (PlayerClass == "MAGE") or (PlayerClass == "PRIEST") or (PlayerClass == "WARLOCK") then
				hasUnits = true
				table_insert(UnitFrameMenu.buttons, {
					enabledTitle = L_ENABLED:format(L["Use Mana Orb"]),
					disabledTitle = L_DISABLED:format(L["Use Mana Orb"]),
					type = "TOGGLE_VALUE", 
					configDB = "UnitFramePlayer", configKey = "enablePlayerManaOrb", 
					proxyModule = "UnitFramePlayer"
				})
			end
		end
	end
	if (hasUnits) then
		table_insert(MenuTable, UnitFrameMenu)
	end

	-- HUD
	local UnitFramePlayerHUD = Core:GetModule("UnitFramePlayerHUD", true)
	if (self:ShouldHaveMenu(UnitFramePlayerHUD)) then 
		local HUDMenu = {
			title = L["HUD"], type = nil, hasWindow = true, 
			buttons = clean({
				IsAzerite and {
					enabledTitle = L_ENABLED:format(L["CastBar"]),
					disabledTitle = L_DISABLED:format(L["CastBar"]),
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
				type = "TOGGLE_VALUE", 
				configDB = "BlizzardFloaterHUD", configKey = "enableTalkingHead", 
				proxyModule = "BlizzardFloaterHUD"
			})
		end

		-- Objectives Tracker
		local BlizzardObjectivesTracker = Core:GetModule("BlizzardObjectivesTracker", true)
		if (self:ShouldHaveMenu(BlizzardObjectivesTracker)) then 
			table_insert(HUDMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Objectives Tracker"]),
				disabledTitle = L_DISABLED:format(L["Objectives Tracker"]),
				type = "TOGGLE_VALUE", 
				configDB = "BlizzardFloaterHUD", configKey = "enableObjectivesTracker", 
				proxyModule = "BlizzardFloaterHUD"
			})
		end
			
		-- RaidWarning
		table_insert(HUDMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Raid Warnings"]),
			disabledTitle = L_DISABLED:format(L["Raid Warnings"]),
			type = "TOGGLE_VALUE", 
			configDB = "BlizzardFloaterHUD", configKey = "enableRaidWarnings", 
			proxyModule = "BlizzardFloaterHUD"
		})

		-- RaidWarning
		table_insert(HUDMenu.buttons, {
			enabledTitle = L_ENABLED:format(L["Monster Emotes"]),
			disabledTitle = L_DISABLED:format(L["Monster Emotes"]),
			type = "TOGGLE_VALUE", 
			configDB = "BlizzardFloaterHUD", configKey = "enableRaidBossEmotes", 
			proxyModule = "BlizzardFloaterHUD"
		})

		if (IsRetail) then
			-- LevelUpDisplay
			table_insert(HUDMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Kills, Levels, Loot"]),
				disabledTitle = L_DISABLED:format(L["Kills, Levels, Loot"]),
				type = "TOGGLE_VALUE", 
				configDB = "BlizzardFloaterHUD", configKey = "enableAnnouncements", 
				proxyModule = "BlizzardFloaterHUD"
			})

			-- Alerts
			table_insert(HUDMenu.buttons, {
				enabledTitle = L_ENABLED:format(L["Alerts"]),
				disabledTitle = L_DISABLED:format(L["Alerts"]),
				type = "TOGGLE_VALUE", 
				configDB = "BlizzardFloaterHUD", configKey = "enableAlerts", 
				proxyModule = "BlizzardFloaterHUD"
			})
		end

		table_insert(MenuTable, HUDMenu)
	end

	-- Explorer Mode
	if (IsAzerite or IsLegacy) then
		local ExplorerMode = Core:GetModule("ExplorerMode", true)
		if (self:ShouldHaveMenu(ExplorerMode)) then 
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
						},
						{
							enabledTitle = L_ENABLED:format(L["Tracker Fading"]),
							disabledTitle = L_DISABLED:format(L["Tracker Fading"]),
							type = "TOGGLE_VALUE", 
							configDB = "ExplorerMode", configKey = "enableTrackerFading", 
							proxyModule = "ExplorerMode"
						}
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
