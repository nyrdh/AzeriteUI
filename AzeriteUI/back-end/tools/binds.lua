local LibBindTool = Wheel:Set("LibBindTool", 1)
if (not LibBindTool) then
	return
end

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibBindTool requires LibClientBuild to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibBindTool requires LibEvent to be loaded.")

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibBindTool requires LibMessage to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibBindTool requires LibFrame to be loaded.")

local LibSound = Wheel("LibSound")
assert(LibSound, "LibBindTool requires LibSound to be loaded.")

local LibTooltip = Wheel("LibTooltip")
assert(LibTooltip, "LibBindTool requires LibTooltip to be loaded.")

local LibSlash = Wheel("LibSlash")
assert(LibSlash, "LibBindTool requires LibSlash to be loaded.")

local LibFader = Wheel("LibFader")
assert(LibFader, "LibBindTool requires LibFader to be loaded.")

local LibColorTool = Wheel("LibColorTool")
assert(LibColorTool, "LibBindTool requires LibColorTool to be loaded.")

local LibFontTool = Wheel("LibFontTool")
assert(LibFontTool, "LibBindTool requires LibFontTool to be loaded.")

-- Embed functionality into this
LibEvent:Embed(LibBindTool)
LibMessage:Embed(LibBindTool)
LibFrame:Embed(LibBindTool)
LibSound:Embed(LibBindTool)
LibTooltip:Embed(LibBindTool)
LibSlash:Embed(LibBindTool)
LibFader:Embed(LibBindTool)
LibFontTool:Embed(LibBindTool)

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local math_floor = math.floor
local pairs = pairs
local print = print
local select = select
local setmetatable = setmetatable
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_join = string.join
local string_match = string.match
local type = type

-- WoW API
local GetCurrentBindingSet = GetCurrentBindingSet
local InCombatLockdown = InCombatLockdown
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local LoadBindings = LoadBindings
local AttemptToSaveBindings = AttemptToSaveBindings or SaveBindings 
local SetBinding = SetBinding

-- Private API
local Colors = LibColorTool:GetColorTable()

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()
local IsRetailShadowlands = LibClientBuild:IsRetailShadowlands()

-- Library registries
LibBindTool.embeds = LibBindTool.embeds or {}
LibBindTool.binds = LibBindTool.binds or {}

-- Speed!
local Binds = LibBindTool.binds

-- Copies of WoW constants (the originals are loaded through an addon, so not reliable as globals)
local ACCOUNT_BINDINGS = 1
local CHARACTER_BINDINGS = 2

-- Simplest and hackiest locale system to date.
local gameLocale = GetLocale()
local L = (function(tbl) 
	local L = tbl[gameLocale] or tbl.enUS
	for i in pairs(L) do 
		if (L[i] == true) then 
			L[i] = i
		end
	end 
	if (gameLocale ~= "enUS") then 
		for i,msg in pairs(tbl.enUS) do 
			if (not L[i]) then 
				L[i] = (msg == true) and i or msg
			end
		end
	end
	return L
end)({ 

	-- Entries set to the boolean 'true' will use the key as the value!
	-- When making new locales, do NOT replace the key, only the value.
	enUS = {

		-- This is shown in the frame, it is word-wrapped. 
		-- Try to keep the length fairly identical to enUS, 
		-- to make sure it fits properly inside the window. 
		["Hover your mouse over any actionbutton and press a key or a mouse button to bind it. Press the ESC key to clear the current actionbutton's keybinding."] = true,

		-- These are output to the chat frame. 
		["Keybinds cannot be changed while engaged in combat."] = true,
		["Keybind changes were discarded because you entered combat."] = true,
		["Keybind changes were saved."] = true,
		["Keybind changes were discarded."] = true,
		["No keybinds were changed."] = true,
		["No keybinds set."] = true,
		["%s is now unbound."] = true,
		["%s is now bound to %s"] = true
	}
})

-- BindFrame Template
----------------------------------------------------
local BindFrame = LibBindTool:CreateFrame("Frame")
local BindFrame_MT = { __index = BindFrame }

BindFrame.GetActionName = function(self)
	local actionName 
	local bindingAction = self.button.bindingAction
	if bindingAction then 
		actionName = _G["BINDING_NAME_"..bindingAction]
	end 
	return actionName
end

BindFrame.OnMouseUp = function(self, key) 
	LibBindTool:ProcessInput(key) 
end

BindFrame.OnMouseWheel = function(self, delta) 
	LibBindTool:ProcessInput((delta > 0) and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") 
end

BindFrame.OnEnter = function(self) 

	-- Start listening for keybind input
	local bindingFrame = LibBindTool:GetBindingFrame()
	bindingFrame:EnableKeyboard(true)

	-- Tell the LibBindTool that we have a current button
	bindingFrame.bindButton = self.button

	-- Retrieve the action
	local bindingAction = self.button.bindingAction
	local binds = { GetBindingKey(bindingAction) } 
	
	-- Show the tooltip
	local tooltip = LibBindTool:GetBindingsTooltip()
	tooltip:SetDefaultAnchor(self)
	tooltip:AddLine(self:GetActionName(), 1, .82, .1)

	if (#binds == 0) then 
		tooltip:AddLine(L["No keybinds set."], 1, 0, 0)
	else 
		tooltip:AddDoubleLine("Binding", "Key", .6, .6, .6, .6, .6, .6)
		for i = 1,#binds do
			tooltip:AddDoubleLine(i .. ":", LibBindTool:GetBindingName(binds[i]), 1, .82, 0, 0, 1, 0)
		end
	end 
	tooltip:Show()

	-- Color the backdrop
	self.bg:SetVertexColor(.4, .6, .9, 1)
end

BindFrame.OnLeave = function(self) 

	-- Stop lisetning for keyboard input
	local bindingFrame = LibBindTool:GetBindingFrame()
	bindingFrame:EnableKeyboard(false)

	-- Tell the LibBindTool we're no longer above this button
	bindingFrame.bindButton = nil

	-- Hide the tooltip
	LibBindTool:GetBindingsTooltip():Hide()

	-- Color the backdrop
	self.bg:SetVertexColor(.4, .6, .9, .75)
end

BindFrame.UpdateBinding = function(self)
	-- Update main bind text
	self.msg:SetText(self.button.GetBindingTextAbbreviated and self.button:GetBindingTextAbbreviated() or self.button:GetBindingText())
end

-- Utility Methods
----------------------------------------------------
-- Utility function for easy colored output messages
local Print = function(r, g, b, msg)
	if (type(r) == "string") then 
		print(r)
		return 
	end
	print(string_format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, msg))
end

-- BindButton Handling
----------------------------------------------------
-- Register a button with the bind system
LibBindTool.RegisterButtonForBinding = function(self, button, ...)

	if (not Binds[button]) then

		-- create overlay frame parented to our parent bind frame
		local bindFrame = setmetatable(LibBindTool:CreateFrame("Frame", nil, LibBindTool:GetBindingFrame()), BindFrame_MT)
		bindFrame:Hide()
		bindFrame:SetFrameStrata("DIALOG")
		bindFrame:SetFrameLevel(1)
		bindFrame:SetAllPoints(button)
		bindFrame:EnableKeyboard(false)
		bindFrame:EnableMouse(true)
		bindFrame:EnableMouseWheel(true)
		bindFrame.button = button

		-- Mouse input is connected to the frame the cursor is currently over, 
		-- so we prefer to register these for every single button. 
		bindFrame:SetScript("OnMouseUp", BindFrame.OnMouseUp)
		bindFrame:SetScript("OnMouseWheel", BindFrame.OnMouseWheel)

		-- Let our master binding frame know what buton we're currently over.
		bindFrame:SetScript("OnEnter", BindFrame.OnEnter)
		bindFrame:SetScript("OnLeave", BindFrame.OnLeave)

		-- create overlay texture
		local bg = bindFrame:CreateTexture()
		bg:SetDrawLayer("BACKGROUND", 1)
		bg:SetPoint("CENTER", 0, 0)
		bg:SetSize(button:GetWidth() or 2, button:GetHeight() or 2)
		bg:SetVertexColor(.4, .6, .9, .75)
		bindFrame.bg = bg

		-- create overlay text for key input
		local msg = bindFrame:CreateFontString()
		msg:SetDrawLayer("OVERLAY", 1)
		msg:SetPoint("CENTER", 0, 0)
		msg:SetFontObject(LibBindTool:GetFont(16, true))
		bindFrame.msg = msg

		Binds[button] = bindFrame
	end

	return Binds[button]
end

LibBindTool.GetBindingName = function(self, binding)
	local bindingName = ""
	if string_find(binding, "ALT%-") then
		binding = string_gsub(binding, "(ALT%-)", "") 
		bindingName = bindingName .. ALT_KEY_TEXT .. "+"
	end 
	if string_find(binding, "CTRL%-") then 
		binding = string_gsub(binding, "(CTRL%-)", "") 
		bindingName = bindingName .. CTRL_KEY_TEXT .. "+"
	end 
	if string_find(binding, "SHIFT%-") then 
		binding = string_gsub(binding, "(SHIFT%-)", "") 
		bindingName = bindingName .. SHIFT_KEY_TEXT .. "+"
	end 
	return bindingName .. (_G[binding.."_KEY_TEXT"] or _G["KEY_"..binding] or binding)
end

-- Figure out the correct binding key combination and its display name
LibBindTool.GetBinding = function(self, key)

	-- Mousebutton translations
	if (key == "LeftButton") then key = "BUTTON1" end
	if (key == "RightButton") then key = "BUTTON2" end
	if (key == "MiddleButton") then key = "BUTTON3" end
	if (key:find("Button%d")) then
		key = key:upper()
	end
	
	local alt = IsAltKeyDown() and "ALT-" or ""
	local ctrl = IsControlKeyDown() and "CTRL-" or ""
	local shift = IsShiftKeyDown() and "SHIFT-" or ""

	return alt..ctrl..shift..key
end

LibBindTool.ProcessInput = function(self, key)
	-- Pause the processing if we currently 
	-- have a dialog open awaiting a user choice, 
	local bindingFrame = LibBindTool:GetBindingFrame()
	if bindingFrame.lockdown then 
		return 
	end 

	-- Bail out if the mouse isn't above a registered button.
	local button = bindingFrame.bindButton
	if (not button) or (not Binds[button]) then 
		return 
	end

	-- Retrieve the action
	local bindFrame = Binds[button]
	local bindingAction = button.bindingAction
	local binds = { GetBindingKey(bindingAction) } 

	-- Clear the button's bindings
	if (key == "ESCAPE") and (#binds > 0) then
		for i = 1, #binds do 
			SetBinding(binds[i], nil)
		end

		Print(1, 0, 0, L["%s is now unbound."]:format(bindFrame:GetActionName()))

		-- Post update tooltips with changes
		if (LibBindTool:GetBindingsTooltip():IsShown()) then 
			bindFrame:OnEnter()
		end
		return 
	end

	-- Ignore modifiers until an actual key or mousebutton is pressed
	if (key == "LSHIFT") or (key == "RSHIFT")
	or (key == "LCTRL") or (key == "RCTRL")
	or (key == "LALT") or (key == "RALT")
	or (key == "UNKNOWN")
	then
		return 
	end

	-- Get the binding key and its display name
	local keybind = LibBindTool:GetBinding(key)
	local keybindName = LibBindTool:GetBindingName(keybind)

	-- Hidden defaults that some addons and UIs allow the user to change. 
	-- Leaving it here for my own reference. 
	--SetBinding("BUTTON1", "CAMERAORSELECTORMOVE")
	--SetBinding("BUTTON2", "TURNORACTION")
	--AttemptToSaveBindings(GetCurrentBindingSet())

	-- Don't allow people to bind these, let's follow blizz standards here. 
	if (keybind == "BUTTON1") or (keybind == "BUTTON2") then 
		return 
	end 

	-- If binds exist, we re-order it to be the last one. 
	if (#binds > 0) then 
		for i = 1,#binds do 
			
			-- We've found a match
			if (keybind == binds[i]) then 
				
				-- if the match is the first and only bind, or the last one registered, we change nothing 
				if (#binds == 1) or (i == #binds) then
					return 
				end  

				-- Clear all existing binds to be able to re-order
				for j = 1,#binds do
					SetBinding(binds[j], nil)
				end
		
				-- Re-apply all other existing binds, except the one we just pressed. 
				for j = 1,#binds do
					if (keybind ~= binds[j]) then 
						SetBinding(binds[j], bindingAction)
					end
				end
			end
		end
	end

	-- Changes were made
	LibBindTool.bindingsChanged = true

	-- Bind the keys we pressed to the button's action
	SetBinding(keybind, bindingAction)

	-- Display a message about the new bind
	Print(0, 1, 0, L["%s is now bound to %s"]:format(Binds[button]:GetActionName(), keybindName))

	-- Post update tooltips with changes
	if LibBindTool:GetBindingsTooltip():IsShown() then 
		bindFrame:OnEnter()
	end
end

LibBindTool.UpdateBindings = function(self)
	for button, bindFrame in pairs(Binds) do 
		bindFrame:UpdateBinding()
	end 
end

LibBindTool.UpdateButtons = function(self)
	for button, bindFrame in pairs(Binds) do 
		bindFrame:SetShown(button:IsVisible())
	end 
end 


-- Mode Toggling
----------------------------------------------------
LibBindTool.EnableBindMode = function(self)
	if InCombatLockdown() then 
		Print(1, 0, 0, L["Keybinds cannot be changed while engaged in combat."])
		return 
	end 

	self.bindActive = true
	self:SetObjectFadeOverride(true)
	self:SendMessage("GP_FORCED_ACTIONBAR_VISIBILITY_REQUESTED")

	self:GetBindingFrame():Show()
	self:UpdateButtons()
	self:SendMessage("GP_BIND_MODE_ENABLED")
end 

LibBindTool.DisableBindMode = function(self)
	self.bindActive = false
	self:SetObjectFadeOverride(false)
	self:SendMessage("GP_FORCED_ACTIONBAR_VISIBILITY_CANCELED")

	self.bindingsChanged = nil
	self:GetBindingFrame():Hide()
	self:SendMessage("GP_BIND_MODE_DISABLED")
end

LibBindTool.ApplyBindings = function(self)
	AttemptToSaveBindings(GetCurrentBindingSet())
	if self.bindingsChanged then 
		Print(.1, 1, .1, L["Keybind changes were saved."])
	else 
		Print(1, .82, 0, L["No keybinds were changed."])
	end 
	self:DisableBindMode()
end

LibBindTool.CancelBindings = function(self)
	-- Re-load the stored bindings to cancel any changes
	LoadBindings(GetCurrentBindingSet())

	-- Output a message depending on whether or not any changes were cancelled
	if (self.bindingsChanged) then 
		Print(1, 0, 0, L["Keybind changes were discarded."])
	else 
		Print(1, .82, 0, L["No keybinds were changed."])
	end 

	-- Close the windows and disable the bind mode
	self:DisableBindMode()

	-- Update the local bindings cache
	self:UpdateBindingsCache()
end 

-- Will be called when switching between general and character specific keybinds
LibBindTool.ChangeBindingSet = function(self)

	-- Check if current bindings have changed, show a warning dialog if so. 
	if self.bindingsChanged or (self.lockdown and (not self.acceptDiscard)) then 

		-- We don't get farther than this unless the 
		-- user clicks 'Accept' in the dialog below.
		local discardFrame = self:GetDiscardFrame()
		if (not discardFrame:IsShown()) then 
			discardFrame:Show()
		end
	else
		self.acceptDiscard = nil
		self.bindingsChanged = nil 

		-- Load the appropriate binding set
		if (self:GetBindingFrame().perCharacter:GetChecked()) then
			LoadBindings(CHARACTER_BINDINGS)
			AttemptToSaveBindings(CHARACTER_BINDINGS)
		else
			LoadBindings(ACCOUNT_BINDINGS)
			AttemptToSaveBindings(ACCOUNT_BINDINGS)
		end

		-- Update the local bindings cache
		self:UpdateBindingsCache()
	end 
end 

-- Update and reset the local cache of keybinds
LibBindTool.UpdateBindingsCache = function(self)

end

-- LibBindTool Frame Creation & Retrieval
----------------------------------------------------
LibBindTool.CreateButton = function(self, parent)
	local button = parent:CreateFrame("Button")

	local msg = button:CreateFontString()
	msg:SetPoint("CENTER", 0, 0)
	msg:SetFontObject(LibBindTool:GetFont(14, false))
	msg:SetJustifyH("RIGHT")
	msg:SetJustifyV("TOP")
	msg:SetIndentedWordWrap(false)
	msg:SetWordWrap(false)
	msg:SetNonSpaceWrap(false)
	button.Msg = msg

	local bg = button:CreateTexture()
	bg:SetDrawLayer("ARTWORK")
	bg:SetPoint("CENTER", msg, "CENTER", 0, 0)
	bg:SetVertexColor(.9, .9, .9)

	local pushed = button:CreateTexture()
	pushed:SetDrawLayer("ARTWORK")
	pushed:SetPoint("CENTER", msg, "CENTER", 0, 0)
	pushed:SetVertexColor(.9, .9, .9)

	local postUpdate = function(self)
		local isPushed = self.isDown or self.isChecked
		local show = isPushed and pushed or bg
		local hide = isPushed and bg or pushed

		hide:SetAlpha(0)
		show:SetAlpha(1)

		if (isPushed) then
			self.Msg:SetPoint("CENTER", 0, -2)
			if (self:IsMouseOver()) then
				show:SetVertexColor(1, 1, 1)
			elseif (self.isChecked) then 
				show:SetVertexColor(.9, .9, .9)
			else
				show:SetVertexColor(.75, .75, .75)
			end
		else
			self.Msg:SetPoint("CENTER", 0, 0)
			if (self:IsMouseOver()) then
				show:SetVertexColor(1, 1, 1)
			else
				show:SetVertexColor(.75, .75, .75)
			end
		end
	end

	button.SetNormalTexture = function(self, path) bg:SetTexture(path) end
	button.SetNormalTextureSize = function(self, ...) bg:SetSize(...) end
	button.SetPushedTexture = function(self, path) pushed:SetTexture(path) end
	button.SetPushedTextureSize = function(self, ...) pushed:SetSize(...) end

	button:HookScript("OnEnter", postUpdate)
	button:HookScript("OnLeave", postUpdate)
	button:HookScript("OnMouseDown", function(self) self.isDown = true; return postUpdate(self) end)
	button:HookScript("OnMouseUp", function(self) self.isDown = false; return postUpdate(self) end)
	button:HookScript("OnShow", function(self) self.isDown = false; return postUpdate(self) end)
	button:HookScript("OnHide", function(self) self.isDown = false; return postUpdate(self) end)

	return button
end

LibBindTool.CreateWindow = function(self)
	local frame = LibBindTool:CreateFrame("Frame", nil, "UICenter")
	frame:Hide()
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(99)
	frame:EnableMouse(false)
	frame:EnableKeyboard(false)
	frame:EnableMouseWheel(false)
	frame:SetSize(520,180)
	frame:Place("TOP", "UICenter", "TOP", 0, -100)

	local msg = frame:CreateFontString()
	msg:SetFontObject(LibBindTool:GetFont(14, true))
	msg:SetPoint("TOPLEFT", 40, -40)
	msg:SetSize(440,70)
	msg:SetJustifyH("LEFT")
	msg:SetJustifyV("TOP")
	msg:SetIndentedWordWrap(false)
	msg:SetWordWrap(true)
	msg:SetNonSpaceWrap(false)
	frame.msg = msg

	local cancel = LibBindTool:CreateButton(frame)
	cancel.Msg:SetText(CANCEL)
	cancel:SetSize(225, 38)
	cancel:SetPoint("BOTTOMLEFT", 20, 10)
	frame.CancelButton = cancel

	local apply = LibBindTool:CreateButton(frame)
	apply.Msg:SetText(APPLY)
	apply:SetSize(225, 38)
	apply:SetPoint("BOTTOMRIGHT", -20, 10)
	frame.ApplyButton = apply

	return frame
end 

LibBindTool.GetBindingFrame = function(self)
	if (not LibBindTool.bindingFrame) then 

		local frame = LibBindTool:CreateWindow() 
		frame:SetFrameLevel(96)
		frame:EnableKeyboard(false)
		frame:EnableMouse(false)
		frame:EnableMouseWheel(false)
		frame:SetScript("OnShow", function() 
			frame.msg:SetText(L["Hover your mouse over any actionbutton and press a key or a mouse button to bind it. Press the ESC key to clear the current actionbutton's keybinding."])
		end)

		frame.msg:ClearAllPoints()
		frame.msg:SetPoint("TOPLEFT", 40, -60)
		frame.msg:SetSize(440,50)

		local perCharacter = frame:CreateFrame("CheckButton", nil, "OptionsCheckButtonTemplate")
		perCharacter:SetSize(32,32)
		perCharacter:SetPoint("TOPLEFT", 34, -16)
		perCharacter:SetHitRectInsets(-10, -408, -10, -10)
		
		-- Update the discard confirm frame's text when the checkbox is toggled.
		-- The frame will however only be shown if changes were made prior to toggling it.
		perCharacter:SetScript("OnShow", function() perCharacter:SetChecked(GetCurrentBindingSet() == 2) end)
		perCharacter:SetScript("OnClick", function() 
			local discardFrame = LibBindTool:GetDiscardFrame()
			if (perCharacter:GetChecked()) then 
				discardFrame.msg:SetText(CONFIRM_LOSE_BINDING_CHANGES)
			else 
				discardFrame.msg:SetText(CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS)
			end 
			LibBindTool:ChangeBindingSet() 
		end) 
		
		perCharacter:SetScript("OnLeave", function() LibBindTool:GetBindingsTooltip():Hide() end)
		perCharacter:SetScript("OnEnter", function()
			local tooltip = LibBindTool:GetBindingsTooltip()
			tooltip:SetDefaultAnchor(perCharacter)
			tooltip:AddLine(CHARACTER_SPECIFIC_KEYBINDINGS, Colors.title[1], Colors.title[2], Colors.title[3])
			tooltip:AddLine(CHARACTER_SPECIFIC_KEYBINDING_TOOLTIP, Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], true)
			tooltip:Show()
		end)

		local perCharacterMsg = perCharacter:CreateFontString()
		perCharacterMsg:SetFontObject(LibBindTool:GetFont(14, true))
		perCharacterMsg:SetPoint("LEFT", perCharacter, "RIGHT", 10, 0)
		perCharacterMsg:SetJustifyH("CENTER")
		perCharacterMsg:SetJustifyV("TOP")
		perCharacterMsg:SetIndentedWordWrap(false)
		perCharacterMsg:SetWordWrap(true)
		perCharacterMsg:SetNonSpaceWrap(false)
		perCharacterMsg:SetText(CHARACTER_SPECIFIC_KEYBINDINGS)

		frame.perCharacter = perCharacter
		frame.perCharacter.msg = perCharacterMsg

		frame.CancelButton:SetScript("OnClick", function() LibBindTool:CancelBindings() end)
		frame.ApplyButton:SetScript("OnClick", function() LibBindTool:ApplyBindings() end)

		frame:SetScript("OnKeyUp", function(_, key) LibBindTool:ProcessInput(key) end)

		LibBindTool.bindingFrame = frame
	end 
	return LibBindTool.bindingFrame	
end
LibBindTool.GetKeybindFrame = LibBindTool.GetBindingFrame

LibBindTool.GetDiscardFrame = function(self)
	if (not LibBindTool.discardFrame) then

		local frame = LibBindTool:CreateWindow()
		frame:SetFrameLevel(99)
		frame:EnableMouse(true)
		frame:ClearAllPoints()
		frame:SetPoint("TOP", LibBindTool:GetBindingFrame(), "BOTTOM", 0, -20)

		frame.msg:ClearAllPoints()
		frame.msg:SetPoint("TOPLEFT", 110, -40)
		frame.msg:SetSize(370,50)

		local texture = frame:CreateTexture()
		texture:SetSize(60,60)
		texture:SetPoint("TOPLEFT", 40, -40)
		texture:SetTexture(STATICPOPUP_TEXTURE_ALERT)

		local mouseBlocker = frame:CreateFrame("Frame")
		mouseBlocker:SetAllPoints(LibBindTool:GetBindingFrame())
		mouseBlocker:EnableMouse(true)
		frame.mouseBlocker = mouseBlocker

		local blockTexture = mouseBlocker:CreateTexture()
		blockTexture:SetDrawLayer("OVERLAY", 1)
		blockTexture:SetAllPoints()
		blockTexture:SetColorTexture(0, 0, 0, .5)
		mouseBlocker.texture = blockTexture

		frame:SetScript("OnShow", function() LibBindTool.lockdown = true end)
		frame:SetScript("OnHide", function() LibBindTool.lockdown = nil end)

		frame.CancelButton:SetScript("OnClick", function() 
			LibBindTool.acceptDiscard = nil

			-- Revert the checkbox click on cancel
			local bindingFrame = LibBindTool:GetBindingFrame()
			bindingFrame.perCharacter:SetChecked(not bindingFrame.perCharacter:GetChecked())

			-- Hide this
			frame:Hide() 
		end)

		frame.ApplyButton.Msg:SetText(ACCEPT)
		frame.ApplyButton:SetScript("OnClick", function() 
			LibBindTool.acceptDiscard = true

			-- Continue changing the binding set
			LibBindTool:ChangeBindingSet() 

			-- Hide this
			frame:Hide() 
		end)

		LibBindTool.discardFrame = frame
	end 
	return LibBindTool.discardFrame
end 
LibBindTool.GetKeybindDiscardFrame = LibBindTool.GetDiscardFrame

-- Retrieve the current locale table.
-- Going to allow modules to do whatever they want here.
LibBindTool.GetKeybindLocales = function(self)
	return L
end

LibBindTool.GetBindingsTooltip = function(self)
	return LibBindTool:GetTooltip("GP_KeyBindingsTooltip") or LibBindTool:CreateTooltip("GP_KeyBindingsTooltip")
end

-- Menu Integration
----------------------------------------------------
-- Check if the bind mode is enabled
LibBindTool.IsBindModeEnabled = function(self)
	return LibBindTool:GetBindingFrame():IsShown()
end

-- Callback needed by the menu system to decide 
-- whether a given mode toggle button is active or not. 
LibBindTool.IsModeEnabled = function(self, modeName)
	if (modeName == "bindMode") then 
		return LibBindTool:IsBindModeEnabled()
	end
end

-- Callback needed by the menu system 
-- to switch between modes. 
LibBindTool.OnModeToggle = function(self, modeName)
	if (modeName == "bindMode") then 
		if (LibBindTool:IsBindModeEnabled()) then 
			LibBindTool:DisableBindMode()
		else
			LibBindTool:EnableBindMode() 
		end
	end 
end

-- LibBindTool Event & Chat Command Handling
----------------------------------------------------
LibBindTool.OnChatCommand = function(self, editBox, ...)
	if (self:GetBindingFrame():IsShown()) then 
		self:CancelBindings()
	else 
		self:EnableBindMode()
	end
end

LibBindTool.OnEvent = function(self, event, ...)
	if (event == "PLAYER_REGEN_DISABLED") then 
		if self.bindActive then 
			Print(1, 0, 0, L["Keybind changes were discarded because you entered combat."])
			return self:CancelBindings()
		end	
	elseif (event == "UPDATE_BINDINGS") or (event == "PLAYER_ENTERING_WORLD") then 
		-- Binds aren't fully loaded directly after login, 
		-- so we need to track the event for updated bindings as well.
		self:UpdateBindings()

	elseif (event == "GP_UPDATE_ACTIONBUTTON_COUNT") then 
		self:UpdateButtons()
	end
end

LibBindTool.Start = function(self)
	self:UnregisterAllEvents()
	self:UnregisterAllMessages()
	self:RegisterEvent("UPDATE_BINDINGS", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
	self:RegisterMessage("GP_UPDATE_ACTIONBUTTON_COUNT", "OnEvent")
end

LibBindTool:RegisterChatCommand("bind", "OnChatCommand", true) -- force flag set, in case of library upgrade 
LibBindTool:Start() -- start this!

-- For front-end overrides
----------------------------------------------------


local embedMethods = {
	GetKeybindFrame = true,
	GetKeybindDiscardFrame = true,
	GetKeybindLocales = true,
	RegisterButtonForBinding = true
}

LibBindTool.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibBindTool.embeds) do
	LibBindTool:Embed(target)
end
