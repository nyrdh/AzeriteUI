local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Blizzard Bag Button Styling
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

-- Blizzard Chat Font Styling
Core:NewModule("BlizzardFonts", "LibEvent").OnInit = function(self)

	-- Lua API
	local ipairs = ipairs

	-- WoW API
	local InCombatLockdown = InCombatLockdown
	local IsAddOnLoaded = IsAddOnLoaded
	local hooksecurefunc = hooksecurefunc

	-- Chat window chat heights
	if (CHAT_FONT_HEIGHTS) then 
		for i = #CHAT_FONT_HEIGHTS, 1, -1 do  
			CHAT_FONT_HEIGHTS[i] = nil
		end 
		for i,v in ipairs({ 14, 16, 18, 20, 22, 24, 28, 32 }) do 
			CHAT_FONT_HEIGHTS[i] = v
		end
	end 

	self.UpdateDisplayedMessages = function(self, event, ...)
		if (InCombatLockdown()) then 
			self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateDisplayedMessages")
			return 
		elseif (event == "PLAYER_REGEN_ENABLED") then 
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", "UpdateDisplayedMessages")
		end
		-- Important that we do NOT replace the table down here, 
		-- as that appears to sometimes taint the UIDropDowns.
		-- Todo: check if it taints after having been in combat, then opening guild controls.
		if (COMBAT_TEXT_FLOAT_MODE == "1") then
			COMBAT_TEXT_SCROLL_FUNCTION = CombatText_StandardScroll
			COMBAT_TEXT_LOCATIONS.startX = 0
			COMBAT_TEXT_LOCATIONS.startY = 259 * COMBAT_TEXT_Y_SCALE
			COMBAT_TEXT_LOCATIONS.endX = 0
			COMBAT_TEXT_LOCATIONS.endY = 389 * COMBAT_TEXT_Y_SCALE

		elseif (COMBAT_TEXT_FLOAT_MODE == "2") then
			COMBAT_TEXT_SCROLL_FUNCTION = CombatText_StandardScroll
			COMBAT_TEXT_LOCATIONS.startX = 0
			COMBAT_TEXT_LOCATIONS.startY = 389 * COMBAT_TEXT_Y_SCALE
			COMBAT_TEXT_LOCATIONS.endX = 0
			COMBAT_TEXT_LOCATIONS.endY =  259 * COMBAT_TEXT_Y_SCALE
		else
			COMBAT_TEXT_SCROLL_FUNCTION = CombatText_FountainScroll
			COMBAT_TEXT_LOCATIONS.startX = 0
			COMBAT_TEXT_LOCATIONS.startY = 389 * COMBAT_TEXT_Y_SCALE
			COMBAT_TEXT_LOCATIONS.endX = 0
			COMBAT_TEXT_LOCATIONS.endY = 609 * COMBAT_TEXT_Y_SCALE
		end
		CombatText_ClearAnimationList()
	end

	self.SetCombatText = function(self)
		if (InCombatLockdown()) then 
			self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
			return 
		end 

		-- Various globals controlling the FCT
		NUM_COMBAT_TEXT_LINES = 10 -- 20
		COMBAT_TEXT_CRIT_MAXHEIGHT = 70 -- 60
		COMBAT_TEXT_CRIT_MINHEIGHT = 35 -- 30
		--COMBAT_TEXT_CRIT_SCALE_TIME = 0.05
		--COMBAT_TEXT_CRIT_SHRINKTIME = 0.2
		COMBAT_TEXT_FADEOUT_TIME = .75 -- 1.3 -- got a taint message on this. Combat taint?
		COMBAT_TEXT_HEIGHT = 25 -- 25
		--COMBAT_TEXT_LOW_HEALTH_THRESHOLD = 0.2
		--COMBAT_TEXT_LOW_MANA_THRESHOLD = 0.2
		--COMBAT_TEXT_MAX_OFFSET = 130
		--COMBAT_TEXT_SCROLLSPEED = 1.3 -- 1.9 -- got a taint message on this. Combat taint?
		COMBAT_TEXT_SPACING = 2 * COMBAT_TEXT_Y_SCALE --10
		--COMBAT_TEXT_STAGGER_RANGE = 20
		--COMBAT_TEXT_X_ADJUSTMENT = 80

		-- Hooking changes to text positions after blizz setting changes, 
		-- to show the text in positions that work well with our UI. 
		hooksecurefunc("CombatText_UpdateDisplayedMessages", function() self:UpdateDisplayedMessages() end)
	end 

	self.OnEvent = function(self, event, ...)
		if (event == "ADDON_LOADED") then 
			local addon = ...
			if (addon == "Blizzard_CombatText") then 
				self:UnregisterEvent("ADDON_LOADED", "OnEvent")
				self:SetCombatText()
			end 
	
		elseif (event == "PLAYER_REGEN_ENABLED") then 
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
			self:SetCombatText()
		end
	end

	-- Note: This whole damn thing taints in Classic, or is it from somewhere else?
	-- After disabling it, the same guildcontrol taint still occurred, just with no named source. Weird. 
	if (IsAddOnLoaded("Blizzard_CombatText")) then
		self:SetCombatText()
	else
		self:RegisterEvent("ADDON_LOADED", "OnEvent")
	end

end

-- Blizzard PopUp Styling
Core:NewModule("BlizzardPopupStyling", "LibBlizzard").OnInit = function(self)
	local layout = Private.GetLayout(self:GetName())
	if (not layout) then
		return self:SetUserDisabled(true)
	end
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
	local layout = Private.GetLayout(self:GetName())
	if (not layout) then
		return self:SetUserDisabled(true)
	end
	self:GetDurabilityWidget():Place(unpack(layout.Place))
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

-- Explorer Mode
Core:NewModule("ExplorerMode", "PLUGIN", "LibMessage", "LibEvent", "LibDB", "LibFader").OnInit = function(self)
	self:PurgeSavedSettingFromAllProfiles(self:GetName(), 
		"enableExplorerInstances",
		"enablePlayerFading",
		"enableTrackerFadingInstances",
		"useFadingInInstance", 
		"useFadingInvehicles"
	)
	self.db = Private.GetConfig(self:GetName())

	
	self.cacheDB = {} -- Create a cache so we only ever update changed values
	self.UpdateSettings = function(self)
		local db = self.db
		local cache = self.cacheDB
	
		self:SetAttachExplorerFrame("ActionBarMain", db.enableExplorer)
		self:SetAttachExplorerFrame("UnitFramePlayer", db.enableExplorer)
		self:SetAttachExplorerFrame("UnitFramePet", db.enableExplorer)
		self:SetAttachExplorerFrame("BlizzardObjectivesTracker", db.enableTrackerFading)
	
		if (db.enableExplorer) and (not cache.enableExplorer) then
			self:SendMessage("GP_EXPLORER_MODE_ENABLED")
			cache.enableExplorer = true
	
		elseif (not db.enableExplorer) and ((cache.enableExplorer) or (cache.enableExplorer == nil)) then
			self:SendMessage("GP_EXPLORER_MODE_DISABLED")
			cache.enableExplorer = false
		end 
	
		if (db.enableTrackerFading) and (not cache.enableTrackerFading) then
			self:SendMessage("GP_TRACKER_EXPLORER_MODE_ENABLED")
			cache.enableTrackerFading = true
	
		elseif (not db.enableTrackerFading) and ((cache.enableTrackerFading) or (cache.enableTrackerFading == nil)) then
			self:SendMessage("GP_TRACKER_EXPLORER_MODE_DISABLED")
			cache.enableTrackerFading = false
		end 
	
		if (db.enableExplorerChat) and (not cache.enableExplorerChat) then
			self:SendMessage("GP_EXPLORER_CHAT_ENABLED")
			cache.enableExplorerChat = true
	
		elseif (not db.enableExplorerChat) and ((cache.enableExplorerChat) or (cache.enableExplorerChat == nil)) then
			self:SendMessage("GP_EXPLORER_CHAT_DISABLED")
			cache.enableExplorerChat = false
		end
	end
	
	self.SetAttachExplorerFrame = function(self, moduleName, isAttached)
		local module = Core:GetModule(moduleName, true)
		if (module) and not(module:IsIncompatible() or module:DependencyFailed()) then 
			local method = isAttached and "RegisterObjectFade" or "UnregisterObjectFade"
			if (module.GetExplorerModeFrameAnchors) then
				for _,frame in ipairs({ module:GetExplorerModeFrameAnchors() }) do
					self[method](self, frame)
				end
			else
				local frame = module:GetFrame()
				if (frame) then 
					self[method](self, frame)
				end
			end
		end 
	end 
	
	self.OnEnable = self.UpdateSettings

	local OptionsMenu = Core:GetModule("OptionsMenu", true)
	if (OptionsMenu) then
		local callbackFrame = OptionsMenu:CreateCallbackFrame(self)
		callbackFrame:AssignProxyMethods("UpdateSettings")
		callbackFrame:AssignSettings(self.db)
		callbackFrame:AssignCallback([=[
			if (not name) then
				return 
			end 
			name = string.lower(name); 
			if (name == "change-enableexplorer") then 
				self:SetAttribute("enableExplorer", value); 
				self:CallMethod("UpdateSettings"); 

			elseif (name == "change-enabletrackerfading") then 
				self:SetAttribute("enableTrackerFading", value); 
				self:CallMethod("UpdateSettings"); 

			elseif (name == "change-enableexplorerchat") then
				self:SetAttribute("enableExplorerChat", value); 
				self:CallMethod("UpdateSettings"); 
			end 
		]=])
	end

end 

-- Keybind Interface Styling
Core:NewModule("Bindings", "PLUGIN", "LibBindTool").OnInit = function(self)

	-- Proxy the shit out of this
	local LibBindTool = Wheel("LibBindTool")
	for _,method in ipairs({ "IsBindModeEnabled", "IsModeEnabled", "OnModeToggle" }) do
		self[method] = function(_, ...) LibBindTool[method](LibBindTool, ...) end
	end

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
	if (not layout) then
		return self:SetUserDisabled(true)
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
