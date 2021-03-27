local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Keybind Interface Styling
local Module = Core:NewModule("Bindings", "PLUGIN", "LibBindTool")

-- Private API
local GetLayout = Private.GetLayout

-- Addon localization
local L = Wheel("LibLocale"):GetLocale(ADDON)

-- Proxy the shit out of this
-- This is because we don't want anything locally registered to this module, 
-- we want the bind data to be globally registered in the back-end, 
-- to be able to gather all binds from even other addons using it.
Module.RegisterProxyMethods = function(self)
	local LibBindTool = Wheel("LibBindTool")
	for _,method in ipairs({ "IsBindModeEnabled", "IsModeEnabled", "OnModeToggle" }) do
		self[method] = function(_, ...) LibBindTool[method](LibBindTool, ...) end
	end
end

-- Replace library localization with our own, if it exists.
Module.RegisterLocales = function(self)
	local locales = self:GetKeybindLocales()
	for key,value in pairs(locales) do
		-- Don't trigger our locale library's metatable,
		-- as it creates all unknown locale entries on the fly.
		local locale = rawget(L,key)
		if (locale) then
			locales[key] = locale
		end
	end
end

-- Register the actionbuttons with the keybind handler
-- Todo: move this to the actionbar module instead. It belongs there. 
Module.RegisterActionButtons = function(self)
	if (Core:IsModuleAvailable("ActionBarMain")) then 
		local ActionBarMain = Core:GetModule("ActionBarMain", true)
		if (ActionBarMain) then 
			local layout = self.layout
			if (ActionBarMain.GetButtons) then
				for id,button in ActionBarMain:GetButtons() do 
					local bindFrame = self:RegisterButtonForBinding(button)
					local width, height = button:GetSize()
					bindFrame.bg:SetTexture(layout.BindButtonTexture)
					bindFrame.bg:SetSize(width + layout.BindButtonOffset, height + layout.BindButtonOffset)
				end
			end
			if (ActionBarMain.GetPetButtons) then
				for id,button in ActionBarMain:GetPetButtons() do 
					local bindFrame = self:RegisterButtonForBinding(button)
					local width, height = button:GetSize()
					bindFrame.bg:SetTexture(layout.BindButtonTexture)
					bindFrame.bg:SetSize(width + layout.BindButtonOffset, height + layout.BindButtonOffset)
				end
			end
		end 
	end
end

-- Style the keybind interface
Module.StyleKeybindInterface = function(self)
	local layout = self.layout
	if (not layout) then
		return
	end
	for _,frame in ipairs({ self:GetKeybindFrame(), self:GetKeybindDiscardFrame() }) do

		frame.ApplyButton:SetNormalTextureSize(unpack(layout.MenuButtonSize))
		frame.ApplyButton:SetNormalTexture(layout.MenuButtonNormalTexture)
		frame.ApplyButton.Msg:SetTextColor(unpack(layout.MenuButtonTextColor))
		frame.ApplyButton.Msg:SetShadowColor(unpack(layout.MenuButtonTextShadowColor))
		frame.ApplyButton.Msg:SetShadowOffset(unpack(layout.MenuButtonTextShadowOffset))

		frame.CancelButton:SetNormalTextureSize(unpack(layout.MenuButtonSize))
		frame.CancelButton:SetNormalTexture(layout.MenuButtonNormalTexture)
		frame.CancelButton.Msg:SetTextColor(unpack(layout.MenuButtonTextColor))
		frame.CancelButton.Msg:SetShadowColor(unpack(layout.MenuButtonTextShadowColor))
		frame.CancelButton.Msg:SetShadowOffset(unpack(layout.MenuButtonTextShadowOffset))

		if (layout.MenuWindowGetBorder) then
			frame.border = layout.MenuWindowGetBorder(frame)
		end
	end
end

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	self:StyleKeybindInterface()
	self:RegisterLocales()
	self:RegisterActionButtons()
	self:RegisterProxyMethods()
end
