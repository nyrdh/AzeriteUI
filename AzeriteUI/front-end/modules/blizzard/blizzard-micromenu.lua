local ADDON,Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end
local Module = Core:NewModule("BlizzardMicroMenu", "LibEvent", "LibDB", "LibTooltip", "LibFrame")

-- Lua API
local _G = _G
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local string_format = string.format
local table_insert = table.insert

-- WoW API
local GetAvailableBandwidth = GetAvailableBandwidth
local GetBindingKey = GetBindingKey
local GetBindingText = GetBindingText
local GetCVarBool = GetCVarBool
local GetDownloadedPercentage = GetDownloadedPercentage
local GetFramerate = GetFramerate
local GetMovieDownloadProgress = GetMovieDownloadProgress
local GetNetStats = GetNetStats

-- Private API
local Colors = Private.Colors
local GetLayout = Private.GetLayout
local IsAnyClassic = Private.IsAnyClassic
local IsClassic = Private.IsClassic
local IsTBC = Private.IsTBC
local IsWrath = Private.IsWrath
local IsRetail = Private.IsRetail

-- All this shit needs to go!!
local BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]]
local buttonWidth, buttonHeight, buttonSpacing, sizeMod = 300,50,10, .75
local L = Wheel("LibLocale"):GetLocale(ADDON)
local Layout

local getBindingKeyForAction = function(action, useNotBound, useParentheses)
	local key = GetBindingKey(action)
	if key then
		key = GetBindingText(key)
	elseif useNotBound then
		key = NOT_BOUND
	end

	if key and useParentheses then
		return ("(%s)"):format(key)
	end

	return key
end

local formatBindingKeyIntoText = function(text, action, bindingAvailableFormat, keyStringFormat, useNotBound, useParentheses)
	local bindingKey = getBindingKeyForAction(action, useNotBound, useParentheses)

	if bindingKey then
		bindingAvailableFormat = bindingAvailableFormat or "%s %s"
		keyStringFormat = keyStringFormat or "%s"
		local keyString = keyStringFormat:format(bindingKey)
		return bindingAvailableFormat:format(text, keyString)
	end

	return text
end

local getMicroButtonTooltipText = function(text, action)
	return formatBindingKeyIntoText(text, action, "%s %s", NORMAL_FONT_COLOR_CODE.."(%s)"..FONT_COLOR_CODE_CLOSE)
end

local microButtons, microButtonTexts = {}, {}
if (IsClassic) then

	table_insert(microButtons, "CharacterMicroButton")
	table_insert(microButtons, "SpellbookMicroButton")
	table_insert(microButtons, "TalentMicroButton")
	table_insert(microButtons, "QuestLogMicroButton")
	table_insert(microButtons, "SocialsMicroButton")
	table_insert(microButtons, "WorldMapMicroButton")
	table_insert(microButtons, "MainMenuMicroButton")
	table_insert(microButtons, "HelpMicroButton")

	microButtonTexts.CharacterMicroButton = CHARACTER_BUTTON
	microButtonTexts.SpellbookMicroButton = SPELLBOOK_ABILITIES_BUTTON
	microButtonTexts.TalentMicroButton = TALENTS_BUTTON
	microButtonTexts.QuestLogMicroButton = QUESTLOG_BUTTON
	microButtonTexts.SocialsMicroButton = SOCIALS
	microButtonTexts.WorldMapMicroButton = WORLD_MAP
	microButtonTexts.MainMenuMicroButton = MAINMENU_BUTTON
	microButtonTexts.HelpMicroButton = HELP_BUTTON

elseif (IsTBC) then

	table_insert(microButtons, "CharacterMicroButton")
	table_insert(microButtons, "SpellbookMicroButton")
	table_insert(microButtons, "TalentMicroButton")
	table_insert(microButtons, "QuestLogMicroButton")
	table_insert(microButtons, "SocialsMicroButton")
	table_insert(microButtons, "LFGMicroButton")
	table_insert(microButtons, "WorldMapMicroButton")
	table_insert(microButtons, "MainMenuMicroButton")
	table_insert(microButtons, "HelpMicroButton")

	microButtonTexts.CharacterMicroButton = CHARACTER_BUTTON
	microButtonTexts.SpellbookMicroButton = SPELLBOOK_ABILITIES_BUTTON
	microButtonTexts.TalentMicroButton = TALENTS_BUTTON
	microButtonTexts.QuestLogMicroButton = QUESTLOG_BUTTON
	microButtonTexts.SocialsMicroButton = SOCIALS
	microButtonTexts.LFGMicroButton = DUNGEONS_BUTTON
	microButtonTexts.WorldMapMicroButton = WORLD_MAP
	microButtonTexts.MainMenuMicroButton = MAINMENU_BUTTON
	microButtonTexts.HelpMicroButton = HELP_BUTTON

elseif (IsWrath) then

	table_insert(microButtons, "CharacterMicroButton")
	table_insert(microButtons, "SpellbookMicroButton")
	table_insert(microButtons, "TalentMicroButton")
	table_insert(microButtons, "AchievementMicroButton")
	table_insert(microButtons, "QuestLogMicroButton")
	table_insert(microButtons, "SocialsMicroButton")
	table_insert(microButtons, "PVPMicroButton")
	table_insert(microButtons, "LFGMicroButton")
	table_insert(microButtons, "MainMenuMicroButton")
	table_insert(microButtons, "HelpMicroButton")

	microButtonTexts.CharacterMicroButton = CHARACTER_BUTTON
	microButtonTexts.SpellbookMicroButton = SPELLBOOK_ABILITIES_BUTTON
	microButtonTexts.TalentMicroButton = TALENTS_BUTTON
	microButtonTexts.AchievementMicroButton = ACHIEVEMENT_BUTTON
	microButtonTexts.QuestLogMicroButton = QUESTLOG_BUTTON
	microButtonTexts.SocialsMicroButton = SOCIALS
	microButtonTexts.PVPMicroButton = PLAYER_V_PLAYER
	microButtonTexts.LFGMicroButton = DUNGEONS_BUTTON
	microButtonTexts.MainMenuMicroButton = MAINMENU_BUTTON
	microButtonTexts.HelpMicroButton = HELP_BUTTON

else

	table_insert(microButtons, "CharacterMicroButton")
	table_insert(microButtons, "SpellbookMicroButton")
	table_insert(microButtons, "TalentMicroButton")
	table_insert(microButtons, "AchievementMicroButton")
	table_insert(microButtons, "QuestLogMicroButton")
	table_insert(microButtons, "GuildMicroButton")
	table_insert(microButtons, "LFDMicroButton")
	table_insert(microButtons, "CollectionsMicroButton")
	table_insert(microButtons, "EJMicroButton")
	table_insert(microButtons, "StoreMicroButton")
	table_insert(microButtons, "MainMenuMicroButton")

	microButtonTexts.CharacterMicroButton = CHARACTER_BUTTON
	microButtonTexts.SpellbookMicroButton = SPELLBOOK_ABILITIES_BUTTON
	microButtonTexts.TalentMicroButton = TALENTS_BUTTON
	microButtonTexts.AchievementMicroButton = ACHIEVEMENT_BUTTON
	microButtonTexts.QuestLogMicroButton = QUESTLOG_BUTTON
	microButtonTexts.GuildMicroButton = LOOKINGFORGUILD
	microButtonTexts.LFDMicroButton = DUNGEONS_BUTTON
	microButtonTexts.CollectionsMicroButton = COLLECTIONS
	microButtonTexts.EJMicroButton = ADVENTURE_JOURNAL or ENCOUNTER_JOURNAL
	microButtonTexts.StoreMicroButton = BLIZZARD_STORE
	microButtonTexts.MainMenuMicroButton = MAINMENU_BUTTON

end

local PrepareTooltip = function(self)
	local tooltip = Private:GetOptionsMenuTooltip()
	tooltip:Hide()
	tooltip:SetSmartAnchor(self, 40, -(Layout.MenuButtonSize[2]*Layout.MenuButtonSizeMod - 2))
	return tooltip
end

local microButtonScripts = {}
if (IsClassic or IsTBC or IsWrath) then
	microButtonScripts.CharacterMicroButton_OnEnter = function(self)
		self.tooltipText = getMicroButtonTooltipText(CHARACTER_BUTTON, "TOGGLECHARACTER0")
		local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
		local tooltip = PrepareTooltip(self)
		tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], false)
		tooltip:AddLine(self.newbieText or NEWBIE_TOOLTIP_CHARACTER, normalColor[1], normalColor[2], normalColor[3], true)
		tooltip:Show()
	end
	microButtonScripts.SpellbookMicroButton_OnEnter = function(self)
		self.tooltipText = getMicroButtonTooltipText(SPELLBOOK_ABILITIES_BUTTON, "TOGGLESPELLBOOK")
		local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
		local tooltip = PrepareTooltip(self)
		tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], false)
		tooltip:AddLine(self.newbieText or NEWBIE_TOOLTIP_SPELLBOOK, normalColor[1], normalColor[2], normalColor[3], true)
		tooltip:Show()
	end
	microButtonScripts.MainMenuMicroButton_OnEnter = function(self)
		local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
		local tooltip = PrepareTooltip(self)
		tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], false)
		tooltip:AddLine(self.newbieText, normalColor[1], normalColor[2], normalColor[3], true)
		tooltip:Show()
	end
	microButtonScripts.MicroButton_OnEnter = function(self)
		if (self:IsEnabled() or self.minLevel or self.disabledTooltip or self.factionGroup) then

			local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
			local tooltip = PrepareTooltip(self)

			if self.tooltipText then
				tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], false)
				tooltip:AddLine(self.newbieText, normalColor[1], normalColor[2], normalColor[3], true)
			else
				tooltip:AddLine(self.newbieText, titleColor[1], titleColor[2], titleColor[3], true)
			end

			if (not self:IsEnabled()) then
				if (self.factionGroup == "Neutral") then
					tooltip:AddLine(FEATURE_NOT_AVAILBLE_PANDAREN, Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3], true)

				elseif ( self.minLevel ) then
					tooltip:AddLine(string_format(FEATURE_BECOMES_AVAILABLE_AT_LEVEL, self.minLevel), Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3], true)

				elseif ( self.disabledTooltip ) then
					tooltip:AddLine(self.disabledTooltip, Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3], true)
				end
			end

			tooltip:Show()
		end
	end
	microButtonScripts.MicroButton_OnLeave = function(button)
		local tooltip = Private:GetOptionsMenuTooltip()
		tooltip:Hide()
	end
end

if (IsRetail) then
	microButtonScripts.CharacterMicroButton_OnEnter = function(self)
		self.tooltipText = getMicroButtonTooltipText(CHARACTER_BUTTON, "TOGGLECHARACTER0")
		local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
		local tooltip = PrepareTooltip(self)
		tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], false)
		tooltip:AddLine(self.newbieText or NEWBIE_TOOLTIP_CHARACTER, normalColor[1], normalColor[2], normalColor[3], true)
		tooltip:Show()
	end
	microButtonScripts.SpellbookMicroButton_OnEnter = function(self)
		self.tooltipText = getMicroButtonTooltipText(SPELLBOOK_ABILITIES_BUTTON, "TOGGLESPELLBOOK")
		local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
		local tooltip = PrepareTooltip(self)
		tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], false)
		tooltip:AddLine(self.newbieText or NEWBIE_TOOLTIP_SPELLBOOK, normalColor[1], normalColor[2], normalColor[3], true)
		tooltip:Show()
	end
	microButtonScripts.CollectionsMicroButton_OnEnter = function(self)
		self.tooltipText = getMicroButtonTooltipText(COLLECTIONS, "TOGGLECOLLECTIONS")
		local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
		local tooltip = PrepareTooltip(self)
		tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], false)
		tooltip:AddLine(self.newbieText or NEWBIE_TOOLTIP_MOUNTS_AND_PETS, normalColor[1], normalColor[2], normalColor[3], true)
		tooltip:Show()
	end
	microButtonScripts.MainMenuMicroButton_OnEnter = function(self)
		local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
		local tooltip = PrepareTooltip(self)
		tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], false)
		tooltip:AddLine(self.newbieText, normalColor[1], normalColor[2], normalColor[3], true)
		tooltip:Show()
	end
	microButtonScripts.MicroButton_OnEnter = function(self)
		if (self:IsEnabled() or self.minLevel or self.disabledTooltip or self.factionGroup) then

			local titleColor, normalColor = Layout.MenuButtonTitleColor, Layout.MenuButtonNormalColor
			local tooltip = PrepareTooltip(self)

			if self.tooltipText then
				tooltip:AddLine(self.tooltipText, titleColor[1], titleColor[2], titleColor[3], false)
				tooltip:AddLine(self.newbieText, normalColor[1], normalColor[2], normalColor[3], true)
			else
				tooltip:AddLine(self.newbieText, titleColor[1], titleColor[2], titleColor[3], true)
			end

			if (not self:IsEnabled()) then
				if (self.factionGroup == "Neutral") then
					tooltip:AddLine(FEATURE_NOT_AVAILBLE_PANDAREN, Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3], true)

				elseif ( self.minLevel ) then
					tooltip:AddLine(string_format(FEATURE_BECOMES_AVAILABLE_AT_LEVEL, self.minLevel), Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3], true)

				elseif ( self.disabledTooltip ) then
					tooltip:AddLine(self.disabledTooltip, Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3], true)
				end
			end

			tooltip:Show()
		end
	end
	microButtonScripts.MicroButton_OnLeave = function(button)
		local tooltip = Private:GetOptionsMenuTooltip()
		tooltip:Hide()
	end
end

local ConfigWindow_OnShow = function(self)
	local button = Module:GetToggleButton()
	if (button) then
		local tooltip = Private:GetOptionsMenuTooltip()
		if (tooltip:IsShown() and (tooltip:GetOwner() == button)) then
			tooltip:Hide()
		end
	end
end

local ConfigWindow_OnHide = function(self)
	local button = Module:GetToggleButton()
	if (button) then
		local tooltip = Private:GetOptionsMenuTooltip()
		if (button:IsMouseOver(0,0,0,0) and ((not tooltip:IsShown()) or (tooltip:GetOwner() ~= button))) then
			button:GetScript("OnEnter")(button)
		end
	end
end

-- Avoid direct usage of 'self' here since this
-- is used as a callback from global methods too!
Module.UpdateMicroButtons = function()
	if InCombatLockdown() then
		Module:AddDebugMessageFormatted("Attempted to adjust MicroMenu in combat, queueing up the action for combat end.")
		return Module:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	end

	local buttons = Module:GetConfigButtons()
	local window = Module:GetConfigWindow()

	local strata = window:GetFrameStrata()
	local level = window:GetFrameLevel()
	local numVisible = 0
	for id,microButton in ipairs(buttons) do
		if (microButton and microButton:IsShown()) then
			microButton:SetParent(window)
			microButton:SetFrameStrata(strata)
			microButton:SetFrameLevel(level + 1)
			microButton:SetSize(buttonWidth*sizeMod, buttonHeight*sizeMod)
			microButton:ClearAllPoints()
			if (Module:GetConfigWindow().reverseOrder) then
				microButton:SetPoint("TOP", window, "TOP", 0, -(buttonSpacing + buttonHeight*sizeMod*numVisible + buttonSpacing*numVisible))
			else
				microButton:SetPoint("BOTTOM", window, "BOTTOM", 0, buttonSpacing + buttonHeight*sizeMod*numVisible + buttonSpacing*numVisible)
			end
			numVisible = numVisible + 1
		end
	end

	-- Resize window to fit the buttons
	window:SetSize(buttonWidth*sizeMod + buttonSpacing*2, buttonHeight*sizeMod*numVisible + buttonSpacing*(numVisible+1))
end

Module.UpdatePerformanceBar = function(self)
	if MainMenuBarPerformanceBar then
		MainMenuBarPerformanceBar:SetTexture(nil)
		MainMenuBarPerformanceBar:SetVertexColor(0,0,0,0)
		MainMenuBarPerformanceBar:Hide()
	end
end

Module.GetConfigWindow = function(self)
	if (not self.ConfigWindow) then

		local configWindow = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
		configWindow:Hide()
		configWindow:SetFrameStrata("DIALOG")
		configWindow:SetFrameLevel(1000)
		configWindow:Place(unpack(GetLayout("OptionsMenu").MenuPlace))
		configWindow:EnableMouse(true)
		configWindow:SetScript("OnShow", ConfigWindow_OnShow)
		configWindow:SetScript("OnHide", ConfigWindow_OnHide)
		configWindow.reverseOrder = (configWindow:GetPoint()):find("TOP")

		-- This can be called before OnInit
		local layout = GetLayout(self:GetName())
		if layout and layout.MenuWindow_CreateBorder then
			layout.MenuWindow_CreateBorder(configWindow)
		end

		self.ConfigWindow = configWindow
	end
	return self.ConfigWindow
end

Module.GetToggleButton = function(self)
	local optionsModule = Core:GetModule("OptionsMenu")
	return optionsModule and optionsModule:GetToggleButton()
end

Module.GetConfigButtons = function(self)
	if (not self.ConfigButtons) then
		self.ConfigButtons = {}
	end
	return self.ConfigButtons
end

Module.GetAutoHideReferences = function(self)
	if (not self.AutoHideReferences) then
		self.AutoHideReferences = {}
	end
	return self.AutoHideReferences
end

Module.AddOptionsToMenuWindow = function(self)
	if (not self.addedToMenuWindow) then
		self.addedToMenuWindow = true

		-- Frame to hide items with
		local UIHider = CreateFrame("Frame")
		UIHider:Hide()

		local buttons = self:GetConfigButtons()
		local window = self:GetConfigWindow()
		local hiders = self:GetAutoHideReferences()

		for id,buttonName in ipairs(microButtons) do

			local microButton = _G[buttonName]
			if microButton then

				buttons[#buttons + 1] = microButton

				local normal = microButton:GetNormalTexture()
				if normal then
					microButton:SetNormalTexture("")
					normal:SetAlpha(0)
					normal:SetSize(.0001, .0001)
				end

				local pushed = microButton:GetPushedTexture()
				if pushed then
					microButton:SetPushedTexture("")
					pushed:SetTexture(nil)
					pushed:SetAlpha(0)
					pushed:SetSize(.0001, .0001)
				end

				local highlight = microButton:GetNormalTexture()
				if highlight then
					microButton:SetHighlightTexture("")
					highlight:SetAlpha(0)
					highlight:SetSize(.0001, .0001)
				end

				local disabled = microButton:GetDisabledTexture()
				if disabled then
					microButton:SetNormalTexture("")
					disabled:SetAlpha(0)
					disabled:SetSize(.0001, .0001)
				end

				local flash = _G[buttonName.."Flash"]
				if flash then
					flash:SetTexture(nil)
					flash:SetAlpha(0)
					flash:SetSize(.0001, .0001)
				end

				microButton:SetScript("OnUpdate", nil)
				microButton:SetScript("OnEnter", microButtonScripts[buttonName.."_OnEnter"] or microButtonScripts.MicroButton_OnEnter)
				microButton:SetScript("OnLeave", microButtonScripts.MicroButton_OnLeave)
				microButton:SetSize(Layout.MenuButtonSize[1]*Layout.MenuButtonSizeMod, Layout.MenuButtonSize[2]*Layout.MenuButtonSizeMod)
				microButton:SetHitRectInsets(0, 0, 0, 0)

				if Layout.MenuButton_PostCreate then
					Layout.MenuButton_PostCreate(microButton, microButtonTexts[buttonName])
				end

				if Layout.MenuButton_PostUpdate then
					local PostUpdate = Layout.MenuButton_PostUpdate
					microButton:HookScript("OnEnter", PostUpdate)
					microButton:HookScript("OnLeave", PostUpdate)
					microButton:HookScript("OnMouseDown", function(self) self.isDown = true; return PostUpdate(self) end)
					microButton:HookScript("OnMouseUp", function(self) self.isDown = false; return PostUpdate(self) end)
					microButton:HookScript("OnShow", function(self) self.isDown = false; return PostUpdate(self) end)
					microButton:HookScript("OnHide", function(self) self.isDown = false; return PostUpdate(self) end)
					PostUpdate(microButton)
				else
					microButton:HookScript("OnMouseDown", function(self) self.isDown = true end)
					microButton:HookScript("OnMouseUp", function(self) self.isDown = false end)
					microButton:HookScript("OnShow", function(self) self.isDown = false end)
					microButton:HookScript("OnHide", function(self) self.isDown = false end)
				end

				-- Add a frame the secure autohider can track,
				-- and anchor it to the micro button
				local autohideParent = CreateFrame("Frame", nil, window, "SecureHandlerAttributeTemplate")
				autohideParent:SetPoint("TOPLEFT", microButton, "TOPLEFT", -6, 6)
				autohideParent:SetPoint("BOTTOMRIGHT", microButton, "BOTTOMRIGHT", 6, -6)

				-- Add the frame to the list of secure autohiders
				hiders["autohide"..id] = autohideParent
			end

		end

		for id,object in ipairs({
				MicroButtonPortrait,
				GuildMicroButtonTabard,
				PVPMicroButtonTexture,
				MainMenuBarPerformanceBar,
				MainMenuBarDownload })
			do
			if object then
				if (object.SetTexture) then
					object:SetTexture(nil)
					object:SetVertexColor(0,0,0,0)
				end
				object:SetParent(UIHider)
			end
		end
		for id,method in ipairs({
				"MoveMicroButtons",
				"UpdateMicroButtons",
				"UpdateMicroButtonsParent" })
			do
			if _G[method] then
				hooksecurefunc(method, Module.UpdateMicroButtons)
			end
		end

		self:UpdateMicroButtons()
	end
end

Module.OnEvent = function(self, event, ...)
	if (event == "PLAYER_REGEN_ENABLED") then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		self:UpdateMicroButtons()
	end
end

Module.HandleBartenderMicroBar = function(self)
	self:AddDebugMessageFormatted("[Bartender4 - MicroMenu] bar loaded, handling incompatible elements.")
	local MicroMenuMod = Bartender4:GetModule("MicroMenu")
	if MicroMenuMod.bar then
		MicroMenuMod.bar.UpdateButtonLayout = function() end
		self:AddDebugMessageFormatted("[Bartender4 - MicroMenu] handling, updating MicroButtons.")
		self:UpdateMicroButtons()
	end
end

Module.HandleBartender = function(self)
	--MainMenuBarBackpackButton
	self:AddDebugMessageFormatted("[Bartender4] loaded, handling incompatible elements.")
	local Bartender4 = Bartender4
	local MicroMenuMod = Bartender4:GetModule("MicroMenu", true)
	if MicroMenuMod then
		self:AddDebugMessageFormatted("[MicroMenu] module detected.")
		MicroMenuMod.MicroMenuBarShow = function() end
		MicroMenuMod.BlizzardBarShow = function() end
		MicroMenuMod.UpdateButtonLayout = function() end
		if MicroMenuMod.bar then
			self:AddDebugMessageFormatted("[Bartender4 - MicroMenu] bar detected.")
			self:HandleBartenderMicroBar()
		else
			self:AddDebugMessageFormatted("[Bartender4 - MicroMenu] bar not yet created, adding handle action to queue.")
			hooksecurefunc(MicroMenuMod, "OnEnable", function()
				self:HandleBartenderMicroBar()
			end)
		end
	end
end

Module.ListenForBartender = function(self, event, addon)
	if (addon == "Bartender4") then
		self:HandleBartender()
		self:UnregisterEvent("ADDON_LOADED", "ListenForBartender")
	end
end

Module.OnInit = function(self)
	Layout = GetLayout(self:GetName())
	self.layout = Layout
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	local tooltip = Private:GetOptionsMenuTooltip()
	tooltip:SetMinimumWidth(40)
	tooltip:SetMaximumWidth(260)

	local HideAlerts = function()
		if (HelpTip) then
			HelpTip:HideAllSystem("MicroButtons")
		end
	end

	if (MainMenuMicroButton_ShowAlert) then
		hooksecurefunc("MainMenuMicroButton_ShowAlert", HideAlerts)
	end

	if (self:IsAddOnEnabled("Bartender4")) then
		self:AddDebugMessageFormatted("[Bartender4] detected.")
		if (IsAddOnLoaded("Bartender4")) then
			self:HandleBartender()
		else
			self:AddDebugMessageFormatted("[Bartender4] not yet loaded, adding handle action to queue.")
			self:RegisterEvent("ADDON_LOADED", "ListenForBartender")
		end
	end
	self:AddOptionsToMenuWindow()
end

Module.OnEnable = function(self)
	self:UpdatePerformanceBar()
end
