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

	-- Set OUR bubble font. Does not affect blizzard bubbles.
	self:SetBubbleFontObject(Private.GetLayout("BlizzardFonts").ChatBubbleFont)

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

-- Chat Filters
Core:NewModule("ChatFilters", "LibChatTool").OnInit = function(self)
	self.db = Private.GetConfig(self:GetName())

	self.UpdateChatFilters = function(self)
		self:SetChatFilterEnabled("Styling", self.db.enableChatStyling)
		self:SetChatFilterEnabled("Spam", self.db.enableSpamFilter)
		self:SetChatFilterEnabled("Boss", self.db.enableBossFilter)
		self:SetChatFilterEnabled("Monster", self.db.enableMonsterFilter)
	end

	self.OnEnable = function(self)
		self:UpdateChatFilters()
	end

	self:SetChatFilterMoneyTextures(
		string.format([[|T%s:16:16:-2:0:64:64:%d:%d:%d:%d|t]], Private.GetMedia("coins"), 0,32,0,32),
		string.format([[|T%s:16:16:-2:0:64:64:%d:%d:%d:%d|t]], Private.GetMedia("coins"), 32,64,0,32),
		string.format([[|T%s:16:16:-2:0:64:64:%d:%d:%d:%d|t]], Private.GetMedia("coins"), 0,32,32,64) 
	)

	local OptionsMenu = Core:GetModule("OptionsMenu", true)
	if (OptionsMenu) then
		local callbackFrame = OptionsMenu:CreateCallbackFrame(self)
		callbackFrame:AssignProxyMethods("UpdateChatFilters")
		callbackFrame:AssignSettings(self.db)
		callbackFrame:AssignCallback([=[
			if name then 
				name = string.lower(name); 
			end 
			if (name == "change-enablechatstyling") then
				self:SetAttribute("enableChatStyling", value); 
				self:CallMethod("UpdateChatFilters"); 

			elseif (name == "change-enablemonsterfilter") then
				self:SetAttribute("enableMonsterFilter", value); 
				self:CallMethod("UpdateChatFilters"); 

			elseif (name == "change-enablebossfilter") then
				self:SetAttribute("enableBossFilter", value); 
				self:CallMethod("UpdateChatFilters"); 

			elseif (name == "change-enablespamfilter") then
				self:SetAttribute("enableSpamFilter", value); 
				self:CallMethod("UpdateChatFilters"); 
			end 
		]=])
	end

end

-- Keybind Interface Styling
Core:NewModule("Bindings", "PLUGIN", "LibBindTool").OnInit = function(self)

	-- Replace library localization with our own, if it exists.
	local L = Wheel("LibLocale"):GetLocale(ADDON)
	local locales = self:GetKeybindLocales()
	for key,value in pairs(locales) do
		-- Don't trigger our locale library's metatable,
		-- as it creates all unknown locale entries on the fly.
		local locale = rawget(L,key)
		if (locale) then
			locales[key] = locale
		end
	end

	-- Style the keybind interface
	local layout = Private.GetLayout(self:GetName())
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

	-- Register the actionbuttons with the keybind handler
	local ActionBarMain = Core:GetModule("ActionBarMain", true)
	if ActionBarMain then 
		for id,button in ActionBarMain:GetButtons() do 
			local bindFrame = self:RegisterButtonForBinding(button)
			local width, height = button:GetSize()
			bindFrame.bg:SetTexture(layout.BindButtonTexture)
			bindFrame.bg:SetSize(width + layout.BindButtonOffset, height + layout.BindButtonOffset)
	
		end
		for id,button in ActionBarMain:GetPetButtons() do 
			local bindFrame = self:RegisterButtonForBinding(button)
			local width, height = button:GetSize()
			bindFrame.bg:SetTexture(layout.BindButtonTexture)
			bindFrame.bg:SetSize(width + layout.BindButtonOffset, height + layout.BindButtonOffset)
		end
	end 
end
