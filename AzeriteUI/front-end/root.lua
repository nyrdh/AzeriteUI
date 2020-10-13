local ADDON, Private = ...

-- Wooh! 
local Core = Wheel("LibModule"):NewModule(ADDON, "LibDB", "LibMessage", "LibEvent", "LibBlizzard", "LibFrame", "LibSlash", "LibAuraData", "LibAura", "LibClientBuild", "LibForge")

-- Tell the back-end what addon to look for before 
-- initializing this module and all its submodules. 
Core:SetAddon(ADDON) 

-- Tell the backend where our saved variables are found.
-- *it's important that we're doing this here, before any module configs are created.
Core:RegisterSavedVariablesGlobal(ADDON.."_DB")

-- Lua API
local _G = _G
local ipairs = ipairs
local string_find = string.find
local string_format = string.format
local string_lower = string.lower
local string_match = string.match
local tonumber = tonumber

-- WoW API
local EnableAddOn = EnableAddOn
local IsInInstance = IsInInstance
local IsInRaid = IsInRaid
local LoadAddOn = LoadAddOn
local ReloadUI = ReloadUI
local SetActionBarToggles = SetActionBarToggles

-- Private Addon API
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

	-- Add a command to clear the main chat frame
	self:RegisterChatCommand("clear", function() ChatFrame1:Clear() end)

	-- Add a command to manually update macro icons
	self:RegisterChatCommand("fix", fixMacroIcons)
	
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

	-- Classic Pet Happiness
	if (IsClassic) then
		local GetPetHappiness = GetPetHappiness
		local HasPetUI = HasPetUI

		-- Parent it to the pet frame, so its visibility and fading follows that automatically. 
		local happyContainer = CreateFrame("Frame", nil, self.frame)
		local happy = happyContainer:CreateFontString()
		happy:SetFontObject(Private.GetFont(12,true))
		happy:SetPoint("BOTTOM", self:GetFrame("UICenter"), "BOTTOM", 0, 10)
		happy.msg = "|cffffffff"..HAPPINESS..":|r %s |cff888888(%s)|r |cffffffff- "..STAT_DPS_SHORT..":|r %s"
		happy.msgShort = "|cffffffff"..HAPPINESS..":|r %s |cffffffff- "..STAT_DPS_SHORT..":|r %s"

		happy.Update = function(element)

			local happiness, damagePercentage, loyaltyRate = GetPetHappiness()
			local _, hunterPet = HasPetUI()
			if (not (happiness or hunterPet)) then
				return element:Hide()
			end

			-- Happy
			local level, damage
			if (happiness == 3) then
				level = "|cff20c000" .. PET_HAPPINESS3 .. "|r"
				damage = "|cff20c000" .. damagePercentage .. "|r"

			-- Content
			elseif (happiness == 2) then
				level = "|cfffe8a0e" .. PET_HAPPINESS2 .. "|r"
				damage = "|cfffe8a0e" .. damagePercentage .. "|r"

			-- Unhappy
			else
				level = "|cffff0303" .. PET_HAPPINESS1 .. "|r"
				damage = "|cffff0303" .. damagePercentage .. "|r"
			end

			if (loyaltyRate and (loyaltyRate > 0)) then 
				element:SetFormattedText(element.msg, level, loyaltyRate, damage)
			else 
				element:SetFormattedText(element.msgShort, level, damage)
			end 

			element:Show()
		end

		happyContainer:SetScript("OnEvent", function(self, event, ...) 
			happy:Update()
		end)

		happyContainer:RegisterEvent("PLAYER_ENTERING_WORLD")
		happyContainer:RegisterEvent("PET_UI_UPDATE")
		happyContainer:RegisterEvent("UNIT_HAPPINESS")
		happyContainer:RegisterUnitEvent("UNIT_PET", "player")
	end

	-- Workaround for the completely random bg popup taints in Classic 1.13.x.
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

	-- Attempt to hide the UI in the rune mini-game
	if (IsRetail) then

		local updateTrackingEvent, onTrackingEvent, checkForActiveGame, findActiveBuffID, restoreUI
		local isTracking, inGroup, inCombat, inInstance, stopReason, gameRunning
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

		-- Forcefully hide this in combat.
		RegisterAttributeDriver(exitButton, "state-visibility", "[combat]hide")

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
			-- This happens automatically in combat by the back-end now,
			-- we still need to show it when the game ends normally, though.
			if (not InCombatLockdown()) then 
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
					gameRunning = true
					self:AddDebugMessageFormatted(string_format("MiniGame Enabled: '%s'", buffName))
					visFrame:Hide()
					exitButton:Show()
					exitButton:SetAttribute("macrotext", "/cancelaura "..buffName)
				end
			else
				if (not visFrame:IsShown()) and (not InCombatLockdown()) then
					-- Only fire this debug message if a game was actually running.
					-- Had a lot of false positives at reloads and world entries without it.
					if (gameRunning) then
						gameRunning = nil
						self:AddDebugMessageFormatted("MiniGame Ended.")
					end
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
			border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
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

Core.SetTheme = function(self, editBox, theme)
	-- Do a minimum amount of control here, 
	-- as this is connected to saved settings.
	-- We don't want crazy results saved.
	local new 
	if (theme == "console") or (theme == "blakmane") or (theme == "blakmaneui") or (theme == "azerite") or ((theme == "azeriteui")) or (theme == "az") or (theme == "azui") then
		new = "Azerite"
	elseif (theme == "legacy") or (theme == "goldpaw") or (theme == "goldpawui")  or (theme == "gui") then
		new = "Legacy"
	end
	-- Only apply the setting and force a reload upon actual changes.
	if (new) and (new ~= self.db.theme) then
		self.db.theme = new
		ReloadUI()
	end
end

Core.OnInit = function(self)
	self:PurgeSavedSettingFromAllProfiles(ADDON, 
		"blockGroupInvites", 
		"allowGuildInvites", 
		"allowFriendInvites", 
		"blockCounter"
	)
	self.db = GetConfig(ADDON)
	
	-- This sets the fallback layouts used when 
	-- the requested module isn't found in the current.
	--Private.SetFallbackLayout("Generic")
	
	-- This sets the current layout. 
	-- This will be moved to a user setting when implemented.
	Private.SetLayout(self.db.theme)

	-- Mini theme switcher. Sticking to the "go" command.
	self:RegisterChatCommand("go", "SetTheme")

	self.layout = GetLayout(ADDON)

	-- In case some other jokers have disabled these, we add them back to avoid a World of Bugs.
	-- RothUI used to remove the two first, and a lot of people missed his documentation on how to get them back. 
	-- I personally removed the objective's tracker for a while in DiabolicUI, which led to pain. Lots of pain.
	for _,v in ipairs({ "Blizzard_CUFProfiles", "Blizzard_CompactRaidFrames", "Blizzard_ObjectiveTracker" }) do
		EnableAddOn(v)
		LoadAddOn(v)
	end

	local OptionsMenu = Core:GetModule("OptionsMenu", true)
	if (OptionsMenu) then
		local callbackFrame = OptionsMenu:CreateCallbackFrame(self)
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
		callbackFrame:AssignProxyMethods("UpdateAspectRatio", "UpdateAuraFilters", "UpdateDebugConsole")
		callbackFrame:AssignSettings(self.db)
		callbackFrame:AssignCallback(SECURE.SecureCallback)
	end

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
	local layout = self.layout
	if (layout and layout.Forge and layout.Forge.OnEnable) then
		self:Forge("Module", self, layout.Forge.OnEnable)
	end

	-- Experimental stuff we move to relevant modules once done
	------------------------------------------------------------------------------------
	self:ApplyExperimentalFeatures()

	-- Make sure frame references to secure frames are in place for the menu
	------------------------------------------------------------------------------------
	self:UpdateSecureUpdater()
	self:UpdateAspectRatio()

	-- Listen for when the user closes the debugframe directly
	------------------------------------------------------------------------------------
	self:RegisterMessage("GP_DEBUG_FRAME_CLOSED", "OnEvent") 

	-- Various logon updates
	------------------------------------------------------------------------------------
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
end 

Core.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then 
		self:UpdateAspectRatio()

	elseif (event == "GP_DEBUG_FRAME_CLOSED") then 
		-- This fires from the module back-end when 
		-- the debug console was manually closed by the user.
		-- We need to update our saved setting here.
		GetConfig(ADDON, "global").enableDebugConsole = false
	end 
end 
