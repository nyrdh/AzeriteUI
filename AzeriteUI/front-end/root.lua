local ADDON, Private = ...

-- Wooh! 
local Core = Wheel("LibModule"):NewModule(ADDON, "LibDB", "LibMessage", "LibEvent", "LibBlizzard", "LibFrame", "LibSlash", "LibSwitcher", "LibAuraData", "LibAura", "LibClientBuild")

-- Tell the back-end what addon to look for before 
-- initializing this module and all its submodules. 
Core:SetAddon(ADDON) 

-- Tell the backend where our saved variables are found.
-- *it's important that we're doing this here, before any module configs are created.
Core:RegisterSavedVariablesGlobal(ADDON.."_DB")

-- Make sure that duplicate UIs aren't loaded
Core:SetIncompatible(Core:GetInterfaceList())

-- Lua API
local _G = _G
local ipairs = ipairs
local string_find = string.find
local string_format = string.format
local string_lower = string.lower
local string_match = string.match
local tonumber = tonumber

-- WoW API
local BNGetFriendGameAccountInfo = BNGetFriendGameAccountInfo
local BNGetNumFriendGameAccounts = BNGetNumFriendGameAccounts
local BNGetNumFriends = BNGetNumFriends
local DisableAddOn = DisableAddOn
local EnableAddOn = EnableAddOn
local GetFriendInfo = C_FriendList.GetFriendInfo
local GetNumFriends = C_FriendList.GetNumFriends
local IsInGroup = IsInGroup
local IsInInstance = IsInInstance
local IsInRaid = IsInRaid
local LoadAddOn = LoadAddOn
local ReloadUI = ReloadUI
local SetActionBarToggles = SetActionBarToggles

-- Private Addon API
local GetAuraFilterFunc = Private.GetAuraFilterFunc
local GetConfig = Private.GetConfig
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout
local GetMedia = Private.GetMedia
local Colors = Private.Colors

-- Constants for client version
local IsClassic = Core:IsClassic()
local IsRetail = Core:IsRetail()

-- Addon localization
local L = Wheel("LibLocale"):GetLocale(ADDON)

local SECURE = {
	SecureCallback = [=[
		if name then 
			name = string.lower(name); 
		end 
		if (name == "change-enablehealermode") then 
			self:SetAttribute("enableHealerMode", value); 

			-- secure callbacks 
			local extraProxy; 
			local id = 0; 
			repeat
				id = id + 1
				extraProxy = self:GetFrameRef("ExtraProxy"..id)
				if extraProxy then 
					extraProxy:SetAttribute(name, value); 
				end
			until (not extraProxy) 

			-- Lua callbacks
			-- *Note that we're not actually listing is as a mode in the menu. 
			self:CallMethod("OnModeToggle", "healerMode"); 

		elseif (name == "change-aurafilter") then 
			self:SetAttribute("auraFilter", value); 
			self:CallMethod("UpdateAuraFilters"); 

		elseif (name == "change-aspectratio") then 
			self:SetAttribute("aspectRatio", value); 
			self:CallMethod("UpdateAspectRatio"); 

		elseif (name == "change-enabledebugconsole") then 
			self:SetAttribute("enableDebugConsole", value); 
			self:CallMethod("UpdateDebugConsole"); 
		end 
	]=]
}

local Minimap_ZoomInClick = function()
	if MinimapZoomIn:IsEnabled() then 
		MinimapZoomOut:Enable()
		Minimap:SetZoom(Minimap:GetZoom() + 1)
		if (Minimap:GetZoom() == (Minimap:GetZoomLevels() - 1)) then
			MinimapZoomIn:Disable()
		end
	end 
end

local Minimap_ZoomOutClick = function()
	if MinimapZoomOut:IsEnabled() then 
		MinimapZoomIn:Enable()
		Minimap:SetZoom(Minimap:GetZoom() - 1)
		if (Minimap:GetZoom() == 0) then
			MinimapZoomOut:Disable()
		end
	end 
end

local fixMinimap = function()
	local currentZoom = Minimap:GetZoom()
	local maxLevels = Minimap:GetZoomLevels()
	if currentZoom and maxLevels then 
		if maxLevels > currentZoom then 
			Minimap_ZoomInClick()
			Minimap_ZoomOutClick()
		else
			Minimap_ZoomOutClick()
			Minimap_ZoomInClick()
		end 
	end 
end

local alreadyFixed
local fixMacroIcons = function() 
	if InCombatLockdown() or alreadyFixed then 
		return 
	end
	--  Macro slot index to query. Slots 1 through 120 are general macros; 121 through 138 are per-character macros.
	local numAccountMacros, numCharacterMacros = GetNumMacros()
	for macroSlot = 1,138 do 
		local name, icon, body, isLocal = GetMacroInfo(macroSlot) 
		if body then 
			EditMacro(macroSlot, nil, nil, body)
			alreadyFixed = true
		end
	end
end

Core.IsModeEnabled = function(self, modeName)
	-- Not actually called by the menu, since we're not
	-- listing our healerMode as a mode, just a toggleValue. 
	-- We do however use our standard mode API so for other modules 
	-- to be able to easily query if this fake mode is enabled. 
	if (modeName == "healerMode") then 
		return self.db.enableHealerMode 

	-- This one IS a mode. 
	elseif (modeName == "enableDebugConsole") then
		local db = GetConfig(ADDON, "global")
		return db.enableDebugConsole -- self:GetDebugFrame():IsShown()
	end
end

Core.OnModeToggle = function(self, modeName)
	if (modeName == "healerMode") then 
		-- Gratz, we did nothing! 
		-- This fake mode isn't changed by Lua, as it needs to move secure frames. 
		-- We might add in Lua callbacks later though, and those will be called from here. 

	elseif (modeName == "loadConsole") then 
		self:LoadDebugConsole()

	elseif (modeName == "unloadConsole") then 
		self:UnloadDebugConsole()

	elseif (modeName == "enableDebugConsole") then 
		local db = GetConfig(ADDON, "global")
		db.enableDebugConsole = not db.enableDebugConsole
		self:UpdateDebugConsole()

	elseif (modeName == "reloadUI") then 
		ReloadUI()
	end
end

Core.GetPrefix = function(self)
	return ADDON
end

Core.GetSecureUpdater = function(self)
	if (not self.proxyUpdater) then 

		-- Create a secure proxy frame for the menu system. 
		local callbackFrame = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")

		-- Lua callback to proxy the setting to the chat window module. 
		callbackFrame.OnModeToggle = function(callbackFrame)
			for i,moduleName in ipairs({ "BlizzardChatFrames" }) do 
				local module = self:GetModule(moduleName, true)
				if module and not (module:IsIncompatible() or module:DependencyFailed()) then 
					if (module.OnModeToggle) then 
						module:OnModeToggle("healerMode")
					end
				end
			end 
		end

		callbackFrame.UpdateDebugConsole = function(callbackFrame)
			self:UpdateDebugConsole()
		end

		callbackFrame.UpdateAuraFilters = function(callbackFrame)
			self:UpdateAuraFilters()
		end

		callbackFrame.UpdateAspectRatio = function(callbackFrame)
			self:UpdateAspectRatio()
		end

		-- Register module db with the secure proxy.
		if db then 
			for key,value in pairs(db) do 
				callbackFrame:SetAttribute(key,value)
			end 
		end

		-- Now that attributes have been defined, attach the onattribute script.
		callbackFrame:SetAttribute("_onattributechanged", SECURE.SecureCallback)

		self.proxyUpdater = callbackFrame
	end

	-- Return the proxy updater to the module
	return self.proxyUpdater
end

Core.UpdateSecureUpdater = function(self)
	local proxyUpdater = self:GetSecureUpdater()

	local count = 0
	for i,moduleName in ipairs({ "UnitFrameParty", "UnitFrameRaid", "GroupTools" }) do 
		local module = self:GetModule(moduleName, true)
		if module then 
			count = count + 1
			local secureUpdater = module.GetSecureUpdater and module:GetSecureUpdater()
			if secureUpdater then 
				proxyUpdater:SetFrameRef("ExtraProxy"..count, secureUpdater)
			end
		end
	end
end

Core.UpdateDebugConsole = function(self)
	local db = GetConfig(ADDON, "global")
	if (db.enableDebugConsole) then 
		self:ShowDebugFrame()
	else
		self:HideDebugFrame()
	end
end

Core.UpdateAuraFilters = function(self)
	local db = self.db
	if (db.auraFilter == "spam") then
		self:SendMessage("GP_AURA_FILTER_MODE_CHANGED", "spam")
	
	elseif (db.auraFilter == "slack") then
		self:SendMessage("GP_AURA_FILTER_MODE_CHANGED", "slack")
	else
		-- strict filter is the fallback
		self:SendMessage("GP_AURA_FILTER_MODE_CHANGED", "strict")
	end
end

Core.UpdateAspectRatio = function(self)
	local db = GetConfig(ADDON, "global")
	if (db.aspectRatio == "wide") then
		self:SetAspectRatio(16/9, nil, false)
	elseif (db.aspectRatio == "ultrawide") then
		self:SetAspectRatio(21/9, nil, false)
	elseif (db.aspectRatio == "full") then
		self:SetAspectRatio(nil, nil, false)
	else
		-- Use 16:9 as the UI was designed for
		-- as the emergency fallback.
		self:SetAspectRatio(16/9, nil, false)
	end
end

Core.LoadDebugConsole = function(self)
	self.db.loadDebugConsole = true
	ReloadUI()
end

Core.UnloadDebugConsole = function(self)
	self.db.loadDebugConsole = false
	ReloadUI()
end
-- The contents of this method are all relatively new features
-- I haven't yet decided whether to put into modules or the back-end.
Core.ApplyExperimentalFeatures = function(self)

	-- Memory Cache of textures
	do
		for i,path in ipairs({
			"actionbutton-ants-small-glow-grid.tga",
			"icon_target_green.tga",
			"actionbutton-ants-small-glow.tga",
			"icon_target_red.tga",
			"actionbutton-ants-small-grid.tga",
			"menu_button_disabled.tga",
			"actionbutton-ants-small.tga",
			"menu_button_half.tga",
			"actionbutton-backdrop.tga",
			"menu_button_normal.tga",
			"actionbutton-border.tga",
			"menu_button_pushed.tga",
			"actionbutton_circular_mask.tga",
			"menu_button_smaller.tga",
			"actionbutton-glow.tga",
			"menu_button_tiny.tga",
			"actionbutton-glow-white.tga",
			"meter_bar.tga",
			"actionbutton-spellhighlight.tga",
			"meter_case.tga",
			"aura_border.tga",
			"minimap-bars-single.tga",
			"blank.tga",
			"minimap-bars-two-inner.tga",
			"Blip-Nandini-New-113_2.tga",
			"minimap-bars-two-outer.tga",
			"Blip-Nandini-New-830.tga",
			"minimap-border.tga",
			"border-glow-overlay.tga",
			"minimap_mask_circle.tga",
			"border-glow.tga",
			"minimap_mask_circle_transparent.tga",
			"cast_back_outline.tga",
			"minimap-onebar-backdrop.tga",
			"cast_back_spiked.tga",
			"minimap-twobars-backdrop.tga",
			"cast_back.tga",
			"nameplate_backdrop.tga",
			"cast_back_wooden.tga",
			"nameplate_bar.tga",
			"cast_bar.tga",
			"nameplate_glow.tga",
			"coins.tga",
			"orb_case_glow.tga",
			"config_button_bright.tga",
			"orb_case_hi.tga",
			"config_button_emotes.tga",
			"orb_case_low.tga",
			"config_button.tga",
			"party_mana.tga",
			"glow.tga",
			"party_portrait_back.tga",
			"group-finder-eye-blue.tga",
			"party_portrait_border.tga",
			"group-finder-eye-green.tga",
			"partyrole_dps.tga",
			"group-finder-eye-orange.tga",
			"partyrole_heal.tga",
			"group-finder-eye-purple.tga",
			"partyrole_tank.tga",
			"group-finder-eye-red.tga",
			"plus.tga",
			"grouprole-icons-dps.tga",
			"point_block.tga",
			"grouprole-icons-heal.tga",
			"point_crystal.tga",
			"grouprole-icons-tank.tga",
			"point_diamond.tga",
			"hp_boss_bar.tga",
			"point_dk_block.tga",
			"hp_boss_case_glow.tga",
			"point_gem.tga",
			"hp_boss_case.tga",
			"point_hearth.tga",
			"hp_cap_bar_highlight.tga",
			"point_plate.tga",
			"hp_cap_bar.tga",
			"point_rune1.tga",
			"hp_cap_case_glow.tga",
			"point_rune2.tga",
			"hp_cap_case.tga",
			"point_rune3.tga",
			"hp_critter_bar.tga",
			"point_rune4.tga",
			"hp_critter_case_glow.tga",
			"portrait_frame_glow.tga",
			"hp_critter_case.tga",
			"portrait_frame_hi.tga",
			"hp_low_case_glow.tga",
			"portrait_frame_lo.tga",
			"hp_low_case.tga",
			"power_crystal_back.tga",
			"hp_lowmid_bar.tga",
			"power_crystal_front.tga",
			"hp_mid_case_glow.tga",
			"power_crystal_glow.tga",
			"hp_mid_case.tga",
			"power_crystal_small_back.tga",
			"icon_badges_alliance.tga",
			"power_crystal_small_front.tga",
			"icon_badges_boss.tga",
			"pw_crystal_case_glow.tga",
			"icon_badges_horde.tga",
			"pw_crystal_case_low.tga",
			"icon_chat_bottom.tga",
			"pw_crystal_case.tga",
			"icon_chat_down.tga",
			"pw_orb_bar2.tga",
			"icon_chat_minus.tga",
			"pw_orb_bar3.tga",
			"icon_chat_plus.tga",
			"pw_orb_bar4.tga",
			"icon_chat_up.tga",
			"pw_orb_bar5.tga",
			"icon_chat_voice.tga",
			"pw_orb_bar.tga",
			"icon_chat_volume.tga",
			"raid_target_icons_small.tga",
			"icon_classification_boss.tga",
			"raid_target_icons.tga",
			"icon_classification_elite.tga",
			"raidtoolsbutton.tga",
			"icon_classification_generic.tga",
			"seasonal_winterveil_crystal.tga",
			"icon_classification_rare.tga",
			"seasonal_winterveil_orb.tga",
			"icon-combat.tga",
			"shade_circle.tga",
			"icon_exit_flight.tga",
			"statusbar_normal.tga",
			"icon-heart-blue.tga",
			"text_shade.tga",
			"icon-heart-green.tga",
			"tooltip_background.tga",
			"icon-heart-red.tga",
			"tooltip_border_blizzcompatible.tga",
			"icon_mail.tga",
			"tooltip_border_hex_large.tga",
			"icon_skull_dead.tga",
			"tooltip_border_hex.tga",
			"icon_skull.tga",
			"tooltip_border_small.tga",
			"icon_target_blue.tga",
			"tooltip_border.tga"
		}) do
			local media = GetMedia(path)
			if (media) then
				self:CreateTextureCache(media)
			end
		end
	end

	-- Attempt to hook the bag bar to the bags
	do
		-- Retrieve the first slot button and the backpack
		local firstSlot = CharacterBag0Slot
		local backpack = ContainerFrame1
		-- These should always exist, but Blizz do have a way of changing things,
		-- and I prefer having functionality not be applied in a future update 
		-- rather than having the UI break from nil bugs. 
		if (firstSlot and backpack) then 
			firstSlot:ClearAllPoints()
			firstSlot:SetPoint("TOPRIGHT", backpack, "BOTTOMRIGHT", -6, 0)
			local strata = backpack:GetFrameStrata()
			local level = backpack:GetFrameLevel()
			local slotSize = 30
			local previous
			for i = 0,3 do 
				-- Always check for existence, 
				-- because nothing is ever guaranteed. 
				local slot = _G["CharacterBag"..i.."Slot"]
				local tex = _G["CharacterBag"..i.."SlotNormalTexture"]
				if slot then 
					slot:SetParent(backpack)
					slot:SetSize(slotSize,slotSize) 
					slot:SetFrameStrata(strata)
					slot:SetFrameLevel(level)

					-- Remove that fugly outer border
					if tex then 
						tex:SetTexture("")
						tex:SetAlpha(0)
					end
					
					-- Re-anchor the slots to remove space
					if (i == 0) then
						slot:ClearAllPoints()
						slot:SetPoint("TOPRIGHT", backpack, "BOTTOMRIGHT", -6, 4)
					else 
						slot:ClearAllPoints()
						slot:SetPoint("RIGHT", previous, "LEFT", 0, 0)
					end
					previous = slot
				end 
			end 

			local keyring = KeyRingButton
			if (keyring) then 
				keyring:SetParent(backpack)
				keyring:SetHeight(slotSize) 
				keyring:SetFrameStrata(strata)
				keyring:SetFrameLevel(level)
				keyring:ClearAllPoints()
				keyring:SetPoint("RIGHT", previous, "LEFT", 0, 0)
				previous = keyring
			end
		end 
	end

	-- Attempt to hide the UI in the rune mini-game
	if (IsRetail) then

		local updateTrackingEvent, onTrackingEvent, checkForActiveGame, findActiveBuffID, restoreUI
		local isTracking, inGroup, inCombat, inInstance, stopReason
		local currentGUID
		local playerGUID = UnitGUID("player")
		local filter = "HELPFUL PLAYER CANCELABLE"

		local games = {

			-- Untangle
			[298047] = true, -- Arcane Leylock
			[298565] = true, -- Arcane Leylock
			[298654] = true, -- Arcane Leylock
			[298657] = true, -- Arcane Leylock
			[298659] = true, -- Arcane Leylock
			
			-- Puzzle 
			[298661] = true, -- Arcane Runelock
			[298663] = true, -- Arcane Runelock
			[298665] = true  -- Arcane Runelock
		}

		local exitButton = self:CreateFrame("Button", nil, "UIParent", "SecureActionButtonTemplate")
		exitButton:Hide()
		exitButton:SetFrameStrata("HIGH")
		exitButton:SetFrameLevel(100)
		exitButton:Place("TOPRIGHT", -40, -40)
		exitButton:SetSize(64, 64)
		exitButton:SetAttribute("type", "macro")
		exitButton.msg = exitButton:CreateFontString()
		exitButton.msg:SetFontObject(GameFontNormal)
		exitButton.msg:SetFont(GameFontNormal:GetFont(), 64, "OUTLINE")
		exitButton.msg:SetShadowColor(0,0,0,0)
		exitButton.msg:SetText("X")
		exitButton.msg:SetPoint("CENTER", 0, 0)
		exitButton.msg:SetTextColor(1, 0, 0)

		-- Search for an active minigame buffID
		findActiveBuffID = function()
			local buffID
			local buffName
			for i = 1, BUFF_MAX_DISPLAY do 
				local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = self:GetUnitBuff("player", i, filter)

				if (name) then 
					if (spellId and games[spellId]) then 
						buffID = i
						buffName = name
						break
					end 
				else 
					break
				end
			end
			return buffID, buffName
		end

		-- Show the user interface, hide the exitbutton
		restoreUI = function()
			local visFrame = self:GetFrame("UICenter"):GetParent()
			if (not visFrame:IsShown()) and (not InCombatLockdown()) then 
				visFrame:Show()
				exitButton:Hide()
			end
		end

		-- Toggle the interface based on the presence of puzzle/untangle auras
		checkForActiveGame = function()
			local visFrame = self:GetFrame("UICenter"):GetParent()
			local buffID, buffName = findActiveBuffID(self)
			if (buffID) then 
				if (visFrame:IsShown()) and (not InCombatLockdown()) then 
					self:AddDebugMessageFormatted(string_format("MiniGame Enabled: '%s'", buffName))
					visFrame:Hide()
					exitButton:Show()
					exitButton:SetAttribute("macrotext", "/cancelaura "..buffName)
				end
			else
				if (not visFrame:IsShown()) and (not InCombatLockdown()) then
					self:AddDebugMessageFormatted("MiniGame Ended.")
					restoreUI()
				end
			end
		end

		updateTrackingEvent = function(reason)
			if (inInstance or inGroup or inCombat) then
				if (isTracking) then

					-- Clear the tracking flag
					isTracking = nil

					-- Stop tracking
					self:UnregisterMessage("GP_UNIT_AURA", onTrackingEvent, true)

					-- Debug output the stop reason
					if (inInstance) then
						stopReason = "instance"
						self:AddDebugMessageFormatted("Disable MiniGame tracking: You're in an instance!")
					elseif (inGroup) then
						stopReason = "group"
						self:AddDebugMessageFormatted("Disable MiniGame tracking: You joined a group!")
					elseif (inCombat) then
						stopReason = "combat"
						self:AddDebugMessageFormatted("Disable MiniGame tracking: You entered combat!")
					end
				end

				-- Always attempt to show the UI,
				-- regardless of whether nor not we're already tracking.
				-- You could've joined a group in the middle of the game.
				restoreUI()

			else
				if (not isTracking) then
					
					-- Set the tracking flag
					isTracking = true

					-- Start tracking
					self:RegisterMessage("GP_UNIT_AURA", onTrackingEvent)

					-- Debug output the stop reason
					if (stopReason == "instance") then
						self:AddDebugMessageFormatted("Enable MiniGame tracking: You exited the instance!")
					elseif (stopReason == "group") then
						self:AddDebugMessageFormatted("Enable MiniGame tracking: You left your group!")
					elseif (stopReason == "combat") then
						self:AddDebugMessageFormatted("Enable MiniGame tracking: Your combat ended!")
					else
						self:AddDebugMessageFormatted("Enable MiniGame tracking!")
					end

					-- Clear the stop reason, only needed it for the above message
					stopReason = nil

					-- Only need to check this is we weren't previously tracking.
					-- The aura event itself will handle it otherwise.
					checkForActiveGame()
				end
			end
		end

		onTrackingEvent = function(self, event, ...)
			if (event == "PLAYER_ENTERING_WORLD") then

				-- Update flags
				inCombat = InCombatLockdown()
				inGroup = IsInRaid()
				inInstance = IsInInstance()

				-- Kill it all off in instances
				if (inInstance) then
					self:UnregisterEvent("GROUP_ROSTER_UPDATE", onTrackingEvent, true)
					self:UnregisterEvent("PLAYER_REGEN_DISABLED", onTrackingEvent, true)
					self:UnregisterEvent("PLAYER_REGEN_ENABLED", onTrackingEvent, true)
					self:UnregisterMessage("GP_UNIT_AURA", onTrackingEvent, true)
				else
					-- Always want these on out in the world
					self:RegisterEvent("GROUP_ROSTER_UPDATE", onTrackingEvent)
					self:RegisterEvent("PLAYER_REGEN_DISABLED", onTrackingEvent)
					self:RegisterEvent("PLAYER_REGEN_ENABLED", onTrackingEvent)
				end

				-- Start tracking auras?
				updateTrackingEvent()

			elseif (event == "GROUP_ROSTER_UPDATE") then

				-- Update raidgroup flag
				inGroup = IsInRaid()

				-- Start tracking auras?
				updateTrackingEvent()

			elseif (event == "PLAYER_REGEN_DISABLED") then

				-- Update combat flag
				inCombat = true

				-- Start tracking auras?
				updateTrackingEvent()

			elseif (event == "PLAYER_REGEN_ENABLED") then

				-- Update combat flag
				inCombat = nil

				-- Start tracking auras?
				updateTrackingEvent()

			elseif (event == "GP_UNIT_AURA") then
				local unit = ...
				if (unit ~= "player") then
					return
				end

				-- Check for active games.
				-- This should never happen if we're grouped or in combat,
				-- but better safe and sorry, so we check the flags here too.
				if (not inCombat) and (not inGroup) then
					checkForActiveGame()
				end
			end
		end
		self:RegisterEvent("PLAYER_ENTERING_WORLD", onTrackingEvent)

	end


	-- Register addon specific aura filters.
	-- These can be accessed by the other modules by calling 
	-- the relevant methods on the 'Core' module object. 
	do
		local auraFlags = Private.AuraFlags
		if auraFlags then 
			for spellID,flags in pairs(auraFlags) do 
				self:AddAuraUserFlags(spellID,flags)
			end 
		end
	end

	-- Add back retail like stop watch commands
	if (IsClassic) then
		local commands = {
			SLASH_STOPWATCH_PARAM_PLAY1 = "play",
			SLASH_STOPWATCH_PARAM_PLAY2 = "play",
			SLASH_STOPWATCH_PARAM_PAUSE1 = "pause",
			SLASH_STOPWATCH_PARAM_PAUSE2 = "pause",
			SLASH_STOPWATCH_PARAM_STOP1 = "stop",
			SLASH_STOPWATCH_PARAM_STOP2 = "clear",
			SLASH_STOPWATCH_PARAM_STOP3 = "reset",
			SLASH_STOPWATCH_PARAM_STOP4 = "stop",
			SLASH_STOPWATCH_PARAM_STOP5 = "clear",
			SLASH_STOPWATCH_PARAM_STOP6 = "reset"
		}

		-- try to match a command
		local matchCommand = function(param, text)
			local i, compare
			i = 1
			repeat
				compare = commands[param..i]
				if (compare and compare == text) then
					return true
				end
				i = i + 1
			until (not compare)
			return false
		end

		local stopWatch = function(_,msg)
			if (not IsAddOnLoaded("Blizzard_TimeManager")) then
				UIParentLoadAddOn("Blizzard_TimeManager")
			end
			if (StopwatchFrame) then
				local text = string_match(msg, "%s*([^%s]+)%s*")
				if (text) then
					text = string_lower(text)
		
					-- in any of the following cases, the stopwatch will be shown
					StopwatchFrame:Show()
		
					if (matchCommand("SLASH_STOPWATCH_PARAM_PLAY", text)) then
						Stopwatch_Play()
						return
					end
					if (matchCommand("SLASH_STOPWATCH_PARAM_PAUSE", text)) then
						Stopwatch_Pause()
						return
					end
					if (matchCommand("SLASH_STOPWATCH_PARAM_STOP", text)) then
						Stopwatch_Clear()
						return
					end
					-- try to match a countdown
					-- kinda ghetto, but hey, it's simple and it works =)
					local hour, minute, second = string_match(msg, "(%d+):(%d+):(%d+)")
					if (not hour) then
						minute, second = string_match(msg, "(%d+):(%d+)")
						if (not minute) then
							second = string_match(msg, "(%d+)")
						end
					end
					Stopwatch_StartCountdown(tonumber(hour), tonumber(minute), tonumber(second))
				else
					Stopwatch_Toggle()
				end
			end
		end
		self:RegisterChatCommand("stopwatch", stopWatch)
	end

	-- Add a command to clear the main chat frame
	self:RegisterChatCommand("clear", function() ChatFrame1:Clear() end)

	-- Add a command to manually update macro icons
	self:RegisterChatCommand("fix", fixMacroIcons)

	-- Workaround for the completely random bg popup taints in 1.13.3.
	-- Going with Tukz way of completely hiding the broken popup,
	-- instead of just modifying the button away as I initially did.
	-- No point adding more sources of taint to the tainted element.
	-- CHECK: Is this a retail problem too?
	if (IsClassic) then
		local battleground = self:CreateFrame("Frame", nil, "UICenter")
		battleground:SetSize(574, 40)
		battleground:Place("TOP", 0, -29)
		battleground:Hide()
		battleground.Text = battleground:CreateFontString(nil, "OVERLAY")
		battleground.Text:SetFontObject(GetFont(18,true))
		battleground.Text:SetText(L["You can now enter a new battleground, right-click the green eye on the minimap to enter or leave!"])
		battleground.Text:SetPoint("TOP")
		battleground.Text:SetJustifyH("CENTER")
		battleground.Text:SetWidth(battleground:GetWidth())
		battleground.Text:SetTextColor(1, 0, 0)

		local animation = battleground:CreateAnimationGroup()
		animation:SetLooping("BOUNCE")

		local fadeOut = animation:CreateAnimation("Alpha")
		fadeOut:SetFromAlpha(1)
		fadeOut:SetToAlpha(.3)
		fadeOut:SetDuration(.5)
		fadeOut:SetSmoothing("IN_OUT")

		self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", function() 
			for i = 1, MAX_BATTLEFIELD_QUEUES do
				local status, map, instanceID = GetBattlefieldStatus(i)
				
				if (status == "confirm") then
					StaticPopup_Hide("CONFIRM_BATTLEFIELD_ENTRY")
					
					battleground:Show()
					animation:Play()
					
					return
				end
			end
			battleground:Hide()
			animation:Stop()
		end)
	end

	-- Little trick to show the layout and dimensions
	-- of the Minimap blip icons on-screen in-game, 
	-- whenever blizzard decide to update those. 
	do
		-- Change this rather than comment/uncomment
		if (false) then
			-- By setting a single point, but not any sizes, 
			-- the texture is shown in its original size and dimensions!
			local f = UIParent:CreateTexture()
			f:SetTexture([[Interface\MiniMap\ObjectIconsAtlas.blp]])
			f:SetPoint("CENTER")

			-- Add a little backdrop for easy
			-- copy & paste from screenshots!
			local g = UIParent:CreateTexture()
			g:SetColorTexture(0,.7,0,.25)
			g:SetAllPoints(f)
		end
	end
	
	-- Temporary Weapon Enchants!
	do
		local tempEnchantButtons = {
			self:CreateFrame("Button", nil, "UICenter", "SecureActionButtonTemplate"),
			self:CreateFrame("Button", nil, "UICenter", "SecureActionButtonTemplate"),
			self:CreateFrame("Button", nil, "UICenter", "SecureActionButtonTemplate")
		}

		-- Style them
		for i,button in ipairs(tempEnchantButtons) do
			
			button:SetSize(30,30)
			button:Place("BOTTOMLEFT", "UICenter", "BOTTOMLEFT", 20, 115 + (40*(i-1)))
			button:SetAttribute("type", "cancelaura")
			button:SetAttribute("target-slot", i+15)
			button:RegisterForClicks("RightButtonUp")

			local border = button:CreateFrame("Frame")
			border:SetSize(30+10, 30+10)
			border:SetPoint("CENTER", 0, 0)
			border:SetBackdrop({ edgeFile = GetMedia("aura_border"), edgeSize = 12 })
			border:SetBackdropColor(0,0,0,0)
			border:SetBackdropBorderColor(Colors.ui.stone[1] *.3, Colors.ui.stone[2] *.3, Colors.ui.stone[3] *.3)
			button.Border = border

			local icon = button:CreateTexture()
			icon:SetDrawLayer("BACKGROUND")
			icon:ClearAllPoints()
			icon:SetPoint("CENTER",0,0)
			icon:SetSize(30-6, 30-6)
			icon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
			button.Icon = icon

			local count = border:CreateFontString()
			count:ClearAllPoints()
			count:SetPoint("BOTTOMRIGHT", 9, -6)
			count:SetFontObject(GetFont(12, true))
			count:SetTextColor(Colors.normal[1], Colors.normal[2], Colors.normal[3], .85)
			button.Count = count

			local time = border:CreateFontString()
			time:ClearAllPoints()
			time:SetPoint("TOPLEFT", -6, 6)
			time:SetFontObject(GetFont(11, true))
			time:SetTextColor(Colors.normal[1], Colors.normal[2], Colors.normal[3], .85)
			button.Time = time

			-- MainHand, OffHand, Ranged = 16,17,18
			button:SetID(i+15)
		end

		-- UNIT_INVENTORY_CHANGED
		local update = function()
			local hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID, hasOffHandEnchant, offHandExpiration, offHandCharges, offHandEnchantId, hasRangedEnchant, rangedEnchantExpiration, rangedCharges, rangedEnchantID = GetWeaponEnchantInfo()

			if (hasMainHandEnchant) then
				local button = tempEnchantButtons[1]
				button.Icon:SetTexture(GetInventoryItemTexture("player", button:GetID()))
				button:SetAlpha(1)
			else
				tempEnchantButtons[1]:SetAlpha(0)
			end

			if (hasOffHandEnchant) then
				local button = tempEnchantButtons[2]
				button.Icon:SetTexture(GetInventoryItemTexture("player", button:GetID()))
				button:SetAlpha(1)
			else
				tempEnchantButtons[2]:SetAlpha(0)
			end

			if (hasRangedEnchant) then
				local button = tempEnchantButtons[3]
				button.Icon:SetTexture(GetInventoryItemTexture("player", button:GetID()))
				button:SetAlpha(1)
			else
				tempEnchantButtons[3]:SetAlpha(0)
			end
		end

		self:RegisterEvent("PLAYER_ENTERING_WORLD", update)
		self:RegisterEvent("UNIT_INVENTORY_CHANGED", update)
	end

end

-- We could add this into the back-end, leaving it here for now, though. 
Core.OnChatCommand = function(self, editBox, msg)
	local db = GetConfig(ADDON, "global")
	if (msg == "enable") or (msg == "on") then 
		db.enableDebugConsole = true

	elseif (msg == "disable") or (msg == "off") then 
		db.enableDebugConsole = false
	else
		db.enableDebugConsole = not db.enableDebugConsole
	end
	self:UpdateDebugConsole()
end

Core.OnInit = function(self)
	self:PurgeSavedSettingFromAllProfiles(ADDON, 
		"blockGroupInvites", 
		"allowGuildInvites", 
		"allowFriendInvites", 
		"blockCounter"
	)
	self.db = GetConfig(ADDON)
	self.layout = GetLayout(ADDON)

	-- Hide the entire UI from the start
	if self.layout.FadeInUI then 
		self:GetFrame("UICenter"):SetAlpha(0)
	end

	-- In case some other jokers have disabled these, we add them back to avoid a World of Bugs.
	-- RothUI used to remove the two first, and a lot of people missed his documentation on how to get them back. 
	-- I personally removed the objective's tracker for a while in DiabolicUI, which led to pain. Lots of pain.
	for _,v in ipairs({ "Blizzard_CUFProfiles", "Blizzard_CompactRaidFrames", "Blizzard_ObjectiveTracker" }) do
		EnableAddOn(v)
		LoadAddOn(v)
	end

	-- Force-initialize the secure callback system for the menu
	self:GetSecureUpdater()

	-- Let's just enforce this from now on.
	-- I need it to be there, it doesn't affect performance.
	local db = GetConfig(ADDON, "global")
	db.loadDebugConsole = true 

	-- Fire a startup message into the console.
	if (db.loadDebugConsole) then 

		-- Set the flag to tell the back-end we're in debug mode
		self:EnableDebugMode()

		-- Register a chat command for those that want to macro this
		self:RegisterChatCommand("debug", "OnChatCommand")
	
		-- Update initial console visibility
		self:UpdateDebugConsole()
		self:AddDebugMessageFormatted("Debug Mode is active.")
		self:AddDebugMessageFormatted("Type /debug to toggle console visibility!")

		-- Add in a chat command to quickly unload the console
		self:RegisterChatCommand("disableconsole", "UnloadDebugConsole")

	else
		-- Set the flag to tell the back-end we're in normal mode. 
		-- This isn't actually needed, since the back-end don't store settings. 
		-- Just leaving it here for weird semantic reasons that really don't make sense. 
		self:DisableDebugMode()

		-- Add in a chat command to quickly load the console
		self:RegisterChatCommand("enableconsole", "LoadDebugConsole")
	end
end 

Core.OnEnable = function(self)

	-- Disable most of the BlizzardUI, to give room for our own!
	------------------------------------------------------------------------------------
	for widget,state in pairs(self.layout.DisableUIWidgets) do 
		if (state) then 
			self:DisableUIWidget(widget)
		end 
	end 

	-- Disable complete interface options menu pages we don't need
	------------------------------------------------------------------------------------
	local updateBarToggles
	for id,page in pairs(self.layout.DisableUIMenuPages) do 
		if (page.ID == 5) or (page.Name == "InterfaceOptionsActionBarsPanel") then 
			updateBarToggles = true 
		end 
		self:DisableUIMenuPage(page.ID, page.Name)
	end 

	-- Disable single interface options we don't need
	------------------------------------------------------------------------------------
	for id,option in pairs(self.layout.DisableUIMenuOptions) do 
		self:DisableUIMenuOption(option.Shrink, option.Name)
	end 

	-- Working around Blizzard bugs and issues I've discovered
	------------------------------------------------------------------------------------
	-- In theory this shouldn't have any effect since we're not using the Blizzard bars. 
	-- But by removing the menu panels above we're preventing the blizzard UI from calling it, 
	-- and for some reason it is required to be called at least once, 
	-- or the game won't fire off the events that tell the UI that the player has an active pet out. 
	-- In other words: without it both the pet bar and pet unitframe will fail after a /reload
	if updateBarToggles then 
		SetActionBarToggles(nil, nil, nil, nil, nil)
	end

	-- Experimental stuff we move to relevant modules once done
	------------------------------------------------------------------------------------
	self:ApplyExperimentalFeatures()

	-- Apply startup smoothness and sweetness
	------------------------------------------------------------------------------------
	if self.layout.FadeInUI or self.layout.ShowWelcomeMessage then 
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
		if self.layout.FadeInUI then 
			self:RegisterEvent("PLAYER_LEAVING_WORLD", "OnEvent")
		end
	end 

	-- Make sure frame references to secure frames are in place for the menu
	------------------------------------------------------------------------------------
	self:UpdateSecureUpdater()

	-- Listen for when the user closes the debugframe directly
	------------------------------------------------------------------------------------
	self:RegisterMessage("GP_DEBUG_FRAME_CLOSED", "OnEvent")
end 

Core.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then 
		if self.layout.FadeInUI then 
			self.frame = self.frame or CreateFrame("Frame")
			self.frame.alpha = 0
			self.frame.elapsed = 0
			self.frame.totalDelay = 0
			self.frame.totalElapsed = 0
			self.frame.fadeDuration = self.layout.FadeInSpeed or 1.5
			self.frame.delayDuration = self.layout.FadeInDelay or 1.5
			self.frame:SetScript("OnUpdate", function(self, elapsed) 
				self.elapsed = self.elapsed + elapsed
				if (self.elapsed < 1/60) then 
					return 
				end 
				fixMacroIcons()
				if self.fading then 
					self.totalElapsed = self.totalElapsed + self.elapsed
					self.alpha = self.totalElapsed / self.fadeDuration
					if (self.alpha >= 1) then 
						Core:GetFrame("UICenter"):SetAlpha(1)
						self.alpha = 0
						self.elapsed = 0
						self.totalDelay = 0
						self.totalElapsed = 0
						self.fading = nil
						self:SetScript("OnUpdate", nil)
						fixMinimap()
						fixMacroIcons()
						return 
					else 
						Core:GetFrame("UICenter"):SetAlpha(self.alpha)
					end 
				else
					self.totalDelay = self.totalDelay + self.elapsed
					if self.totalDelay >= self.delayDuration then 
						self.fading = true 
					end
				end 
				self.elapsed = 0
			end)
		end
		self:UpdateAspectRatio()

	elseif (event == "PLAYER_LEAVING_WORLD") then
		if self.layout.FadeInUI then 
			if self.frame then 
				self.frame:SetScript("OnUpdate", nil)
				self.alpha = 0
				self.elapsed = 0
				self.totalDelay = 0
				self.totalElapsed = 0
				self.fading = nil
			end
			self:GetFrame("UICenter"):SetAlpha(0)
		end
	elseif (event == "GP_DEBUG_FRAME_CLOSED") then 
		-- This fires from the module back-end when 
		-- the debug console was manually closed by the user.
		-- We need to update our saved setting here.
		local db = GetConfig(ADDON, "global")
		db.enableDebugConsole = false
	end 
end 
