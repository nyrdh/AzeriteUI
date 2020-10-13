local LibBlizzard = Wheel:Set("LibBlizzard", 58)
if (not LibBlizzard) then 
	return
end

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibBlizzard requires LibEvent to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibBlizzard requires LibClientBuild to be loaded.")

local LibHook = Wheel("LibHook")
assert(LibHook, "LibBlizzard requires LibHook to be loaded.")

local LibSecureHook = Wheel("LibSecureHook")
assert(LibSecureHook, "LibBlizzard requires LibSecureHook to be loaded.")

LibEvent:Embed(LibBlizzard)
LibHook:Embed(LibBlizzard)
LibSecureHook:Embed(LibBlizzard)

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local pairs = pairs
local select = select
local string_format = string.format
local string_join = string.join
local string_match = string.match
local type = type
local unpack = unpack

-- WoW API
local CreateFrame = CreateFrame
local FCF_GetCurrentChatFrame = FCF_GetCurrentChatFrame
local InCombatLockdown = InCombatLockdown
local IsAddOnLoaded = IsAddOnLoaded
local RegisterStateDriver = RegisterStateDriver
local SetCVar = SetCVar
local SetUIPanelAttribute = SetUIPanelAttribute
local TargetofTarget_Update = TargetofTarget_Update

-- WoW Objects
local UIParent = UIParent

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()
local IsRetailShadowlands = LibClientBuild:IsRetailShadowlands()

LibBlizzard.embeds = LibBlizzard.embeds or {}
LibBlizzard.queue = LibBlizzard.queue or {}
LibBlizzard.enableQueue = LibBlizzard.enableQueue or {}
LibBlizzard.stylingQueue = LibBlizzard.stylingQueue or {}

-- Frame to securely hide items
if (not LibBlizzard.frame) then
	local frame = CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
	frame:Hide()
	frame:SetPoint("TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", 0, 0)
	frame.children = {}
	RegisterAttributeDriver(frame, "state-visibility", "hide")

	-- Attach it to our library
	LibBlizzard.frame = frame
end

local UIHider = LibBlizzard.frame
local UIWidgetsDisable = {} -- Disable methods
local UIWidgetsEnable = {} -- Enable methods
local UIWidgetStyling = {} -- Styling methods
local UIWidgetDependency = {} -- Dependencies, applies to all

-- Utility Functions
-----------------------------------------------------------------
-- Syntax check 
local check = function(value, num, ...)
	assert(type(num) == "number", ("Bad argument #%.0f to '%s': %s expected, got %s"):format(2, "Check", "number", type(num)))
	for i = 1,select("#", ...) do
		if type(value) == select(i, ...) then 
			return 
		end
	end
	local types = string_join(", ", ...)
	local name = string_match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
	error(string_format("Bad argument #%.0f to '%s': %s expected, got %s", num, name, types, type(value)), 3)
end

-- Proxy function to retrieve the actual frame whether 
-- the input is a frame or a global frame name 
local getFrame = function(baseName)
	if (type(baseName) == "string") then
		return _G[baseName]
	else
		return baseName
	end
end

-- Kill off an existing frame in a secure, taint free way
-- @usage kill(object, [keepEvents], [silent])
-- @param object <table, string> frame, fontstring or texture to hide
-- @param keepEvents <boolean, nil> 'true' to leave a frame's events untouched
-- @param silent <boolean, nil> 'true' to return 'false' instead of producing an error for non existing objects
local kill = function(object, keepEvents, silent)
	check(object, 1, "string", "table")
	check(keepEvents, 2, "boolean", "nil")
	if (type(object) == "string") then
		if (silent and (not _G[object])) then
			return false
		end
		assert(_G[object], ("Bad argument #%.0f to '%s'. No object named '%s' exists."):format(1, "Kill", object))
		object = _G[object]
	end
	if (not UIHider[object]) then
		UIHider[object] = {
			parent = object:GetParent(),
			isshown = object:IsShown(),
			point = { object:GetPoint() }
		}
	end
	object:SetParent(UIHider)
	if (object.UnregisterAllEvents and (not keepEvents)) then
		object:UnregisterAllEvents()
	end
	return true
end

local killUnitFrame = function(baseName, keepParent, keepEvents, keepVisible)
	local frame = getFrame(baseName)
	if (frame) then
		if (not keepParent) then
			if (keepEvents) then
				kill(frame, true, true)
			else
				kill(frame, false, true)
			end
		end
		if (not keepVisible) then
			frame:Hide()
		end
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", -400, 500)

		local health = frame.healthbar
		if (health) then
			health:UnregisterAllEvents()
		end

		local power = frame.manabar
		if (power) then
			power:UnregisterAllEvents()
		end

		local spell = frame.spellbar
		if (spell) then
			spell:UnregisterAllEvents()
		end

		local altpowerbar = frame.powerBarAlt
		if (altpowerbar) then
			altpowerbar:UnregisterAllEvents()
		end
	end
end

-- Widget Pool
-----------------------------------------------------------------
-- ActionBars (Classic)
UIWidgetsDisable["ActionBars"] = IsClassic and function(self)

	for _,object in pairs({
		"MainMenuBarVehicleLeaveButton",
		"MainMenuExpBar",
		"PetActionBarFrame",
		"ReputationWatchBar",
		"StanceBarFrame",
		"TutorialFrameAlertButton1",
		"TutorialFrameAlertButton2",
		"TutorialFrameAlertButton3",
		"TutorialFrameAlertButton4",
		"TutorialFrameAlertButton5",
		"TutorialFrameAlertButton6",
		"TutorialFrameAlertButton7",
		"TutorialFrameAlertButton8",
		"TutorialFrameAlertButton9",
		"TutorialFrameAlertButton10",
	}) do 
		if (_G[object]) then 
			_G[object]:UnregisterAllEvents()
		else 
			if (self.AddDebugMessageFormatted) then
				self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			end
		end
	end 
	for _,object in pairs({
		"FramerateLabel",
		"FramerateText",
		"MainMenuBarArtFrame",
		"MainMenuBarOverlayFrame",
		"MainMenuExpBar",
		"MainMenuBarVehicleLeaveButton",
		"MultiBarBottomLeft",
		"MultiBarBottomRight",
		"MultiBarLeft",
		"MultiBarRight",
		"PetActionBarFrame",
		"ReputationWatchBar",
		"StanceBarFrame",
		"StreamingIcon"
	}) do 
		if (_G[object]) then 
			_G[object]:SetParent(UIHider)
		else 
			if (self.AddDebugMessageFormatted) then
				self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			end
		end
	end 
	for _,object in pairs({
		"MainMenuBarArtFrame",
		"PetActionBarFrame",
		"StanceBarFrame"
	}) do 
		if (_G[object]) then 
			_G[object]:Hide()
		else 
			if (self.AddDebugMessageFormatted) then
				self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			end
		end
	end 
	for _,object in pairs({
		"ActionButton", 
		"MultiBarBottomLeftButton", 
		"MultiBarBottomRightButton", 
		"MultiBarRightButton",
		"MultiBarLeftButton"
	}) do 
		for i = 1,NUM_ACTIONBAR_BUTTONS do
			local button = _G[object..i]
			button:Hide()
			button:UnregisterAllEvents()
			button:SetAttribute("statehidden", true)
		end
	end 

	MainMenuBar:EnableMouse(false)
	MainMenuBar:SetAlpha(0)
	MainMenuBar:UnregisterEvent("DISPLAY_SIZE_CHANGED")
	MainMenuBar:UnregisterEvent("UI_SCALE_CHANGED")
	MainMenuBar.slideOut:GetAnimations():SetOffset(0,0)

	-- Gets rid of the loot anims
	MainMenuBarBackpackButton:UnregisterEvent("ITEM_PUSH") 
	for slot = 0,3 do
		_G["CharacterBag"..slot.."Slot"]:UnregisterEvent("ITEM_PUSH") 
	end

	UIPARENT_MANAGED_FRAME_POSITIONS["MainMenuBar"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["StanceBarFrame"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["PETACTIONBAR_YPOS"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["MultiCastActionBarFrame"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["MULTICASTACTIONBAR_YPOS"] = nil

	--UIWidgetsDisable["ActionBarsMainBar"](self)
	--UIWidgetsDisable["ActionBarsBagBarAnims"](self)
end

-- ActionBars (Retail)
or IsRetail and function(self)
	for _,object in pairs({
		"CollectionsMicroButtonAlert",
		"EJMicroButtonAlert",
		"LFDMicroButtonAlert",
		"MainMenuBarVehicleLeaveButton",
		"OverrideActionBar",
		"PetActionBarFrame",
		"StanceBarFrame",
		"TalentMicroButtonAlert",
		"TutorialFrameAlertButton"
	}) do 
		if (_G[object]) then 
			_G[object]:UnregisterAllEvents()
		else 
			if (self.AddDebugMessageFormatted) then
				self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			end
		end
	end 
	for _,object in pairs({
		"CollectionsMicroButtonAlert",
		"EJMicroButtonAlert",
		"FramerateLabel",
		"FramerateText",
		"LFDMicroButtonAlert",
		"MainMenuBarArtFrame",
		"MainMenuBarVehicleLeaveButton",
		"MicroButtonAndBagsBar",
		"MultiBarBottomLeft",
		"MultiBarBottomRight",
		"MultiBarLeft",
		"MultiBarRight",
		"OverrideActionBar",
		"PetActionBarFrame",
		"PossessBarFrame",
		"StanceBarFrame",
		"StreamingIcon",
		"TalentMicroButtonAlert"
	}) do 
		if (_G[object]) then 
			_G[object]:SetParent(UIHider)
		else 
			if (self.AddDebugMessageFormatted) then
				self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			end
		end
	end 
	for _,object in pairs({
		"CollectionsMicroButtonAlert",
		"EJMicroButtonAlert",
		"LFDMicroButtonAlert",
		"MainMenuBarArtFrame",
		"MicroButtonAndBagsBar",
		"OverrideActionBar",
		"PetActionBarFrame",
		"PossessBarFrame",
		"StanceBarFrame",
		"StatusTrackingBarManager",
		"TutorialFrameAlertButton"
	}) do 
		if (_G[object]) then 
			_G[object]:Hide()
		else 
			if (self.AddDebugMessageFormatted) then
				self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			end
		end
	end 
	for _,object in pairs({
		"ActionButton", 
		"MultiBarBottomLeftButton", 
		"MultiBarBottomRightButton", 
		"MultiBarRightButton",
		"MultiBarLeftButton"
	}) do 
		for i = 1,NUM_ACTIONBAR_BUTTONS do
			local button = _G[object..i]
			button:Hide()
			button:UnregisterAllEvents()
			button:SetAttribute("statehidden", true)
		end
	end 
	for i = 1,6 do
		local button = _G["OverrideActionBarButton"..i]
		button:UnregisterAllEvents()
		button:SetAttribute("statehidden", true)

		-- Just in case it's still there, covering stuff. 
		-- This has happened in some rare cases. Hiding won't work. 
		button:EnableMouse(false) 
	end
	if PlayerTalentFrame then
		PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	elseif TalentFrame_LoadUI then
		hooksecurefunc("TalentFrame_LoadUI", function() PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED") end)
	end

	MainMenuBar:EnableMouse(false)
	MainMenuBar:SetAlpha(0)
	MainMenuBar:UnregisterEvent("DISPLAY_SIZE_CHANGED")
	MainMenuBar:UnregisterEvent("UI_SCALE_CHANGED")
	MainMenuBar.slideOut:GetAnimations():SetOffset(0,0)

	-- If I'm not hiding this, it will become visible (though transparent)
	-- and cover our own custom vehicle/possess action bar. 
	OverrideActionBar:EnableMouse(false)
	OverrideActionBar:SetAlpha(0)
	OverrideActionBar.slideOut:GetAnimations():SetOffset(0,0)

	-- Gets rid of the loot anims
	MainMenuBarBackpackButton:UnregisterEvent("ITEM_PUSH") 
	for slot = 0,3 do
		_G["CharacterBag"..slot.."Slot"]:UnregisterEvent("ITEM_PUSH") 
	end

	UIPARENT_MANAGED_FRAME_POSITIONS["MainMenuBar"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["StanceBarFrame"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["PossessBarFrame"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["PETACTIONBAR_YPOS"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["MultiCastActionBarFrame"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["MULTICASTACTIONBAR_YPOS"] = nil
end

UIWidgetsDisable["Alerts"] = function(self)
	if (not AlertFrame) then
		return
	end
	AlertFrame:UnregisterAllEvents()
	AlertFrame:SetScript("OnEvent", nil)
	AlertFrame:SetParent(UIHider)
end 

UIWidgetsEnable["Alerts"] = function(self)
	if (not AlertFrame) then
		return
	end
	if (AlertFrame:GetParent() ~= UIParent) then 
		AlertFrame:SetParent(UIParent)
		AlertFrame:SetScript("OnEvent", AlertFrame.OnEvent)
		AlertFrame:OnLoad()
	end
end 

UIWidgetsDisable["Auras"] = function(self)
	BuffFrame:SetScript("OnLoad", nil)
	BuffFrame:SetScript("OnUpdate", nil)
	BuffFrame:SetScript("OnEvent", nil)
	BuffFrame:SetParent(UIHider)
	BuffFrame:UnregisterAllEvents()
	if (TemporaryEnchantFrame) then 
		TemporaryEnchantFrame:SetScript("OnUpdate", nil)
		TemporaryEnchantFrame:SetParent(UIHider)
	end 
end 

UIWidgetsDisable["BuffTimer"] = function(self)
	if (not PlayerBuffTimerManager) then
		return
	end
	PlayerBuffTimerManager:SetParent(UIHider)
	PlayerBuffTimerManager:SetScript("OnEvent", nil)
	PlayerBuffTimerManager:UnregisterAllEvents()
end

UIWidgetsDisable["CastBars"] = function(self)
	-- player's castbar
	CastingBarFrame:SetScript("OnEvent", nil)
	CastingBarFrame:SetScript("OnUpdate", nil)
	CastingBarFrame:SetParent(UIHider)
	CastingBarFrame:UnregisterAllEvents()
	
	-- player's pet's castbar
	PetCastingBarFrame:SetScript("OnEvent", nil)
	PetCastingBarFrame:SetScript("OnUpdate", nil)
	PetCastingBarFrame:SetParent(UIHider)
	PetCastingBarFrame:UnregisterAllEvents()
end 

UIWidgetDependency["CaptureBar"] = "Blizzard_UIWidgets"
UIWidgetsDisable["CaptureBar"] = function(self)
	if (not UIWidgetBelowMinimapContainerFrame) then
		return
	end
	UIWidgetBelowMinimapContainerFrame:SetParent(UIHider)
	UIWidgetBelowMinimapContainerFrame:SetScript("OnEvent", nil)
	UIWidgetBelowMinimapContainerFrame:UnregisterAllEvents()
end

UIWidgetsDisable["Chat"] = function(self)
	if (not QuickJoinToastButton) then
		return
	end

	-- This was called FriendsMicroButton pre-Legion
	local killQuickToast = function(self, event, ...)
		QuickJoinToastButton:UnregisterAllEvents()
		QuickJoinToastButton:Hide()
		QuickJoinToastButton:SetAlpha(0)
		QuickJoinToastButton:EnableMouse(false)
		QuickJoinToastButton:SetParent(UIHider)
	end 
	killQuickToast()

	-- This pops back up on zoning sometimes, so keep removing it
	LibBlizzard:RegisterEvent("PLAYER_ENTERING_WORLD", killQuickToast)
end 

UIWidgetsDisable["Durability"] = function(self)
	DurabilityFrame:UnregisterAllEvents()
	DurabilityFrame:SetScript("OnShow", nil)
	DurabilityFrame:SetScript("OnHide", nil)

	-- Will this taint? 
	-- This is to prevent the durability frame size 
	-- affecting other anchors
	DurabilityFrame:SetParent(UIHider)
	DurabilityFrame:Hide()
	DurabilityFrame.IsShown = function() return false end
end

UIWidgetsDisable["LevelUpDisplay"] = function(self)
	if (not LevelUpDisplay) then
		return
	end
	LevelUpDisplay:SetScript("OnEvent", nil)
	LevelUpDisplay:UnregisterAllEvents()
	LevelUpDisplay:StopBanner()
	LevelUpDisplay:SetParent(UIHider)
end
UIWidgetsEnable["LevelUpDisplay"] = function(self)
	if (not LevelUpDisplay) then
		return
	end
	LevelUpDisplay:SetParent(UIParent)
	LevelUpDisplay:SetScript("OnEvent", LevelUpDisplay_OnEvent)
	LevelUpDisplay_OnLoad(LevelUpDisplay)
end

UIWidgetDependency["Banners"] = "Blizzard_ObjectiveTracker"
UIWidgetsDisable["Banners"] = function(self)
	local frame = ObjectiveTrackerBonusBannerFrame
	if (frame) then
		--frame.PlayBanner = nil
		--frame.StopBanner = nil
		ObjectiveTrackerBonusBannerFrame_StopBanner(frame)
		frame:SetParent(UIHider)
	end
end
UIWidgetsEnable["Banners"] = function(self)
	local frame = ObjectiveTrackerBonusBannerFrame
	if (frame) then
		frame:SetParent(UIParent)
		ObjectiveTrackerBonusBannerFrame_OnLoad(frame)
	end
end

UIWidgetsDisable["BossBanners"] = function(self)
	local frame = BossBanner
	BossBanner_Stop(frame)	
	--frame.PlayBanner = nil
	--frame.StopBanner = nil
	frame:UnregisterAllEvents()
	frame:SetScript("OnEvent", nil)
	frame:SetScript("OnUpdate", nil)
	frame:SetParent(UIHider)
end
UIWidgetsEnable["BossBanners"] = function(self)
	local frame = BossBanner
	frame:SetScript("OnEvent", BossBanner_OnEvent)
	frame:SetScript("OnUpdate", BossBanner_OnUpdate)
	BossBanner_OnLoad(frame)
end

UIWidgetsDisable["Minimap"] = function(self)

	for _,object in pairs({
		"GameTimeFrame",
		"GarrisonLandingPageMinimapButton"
	}) do 
		if (_G[object]) then 
			_G[object]:UnregisterAllEvents()
		else
			-- Spammy, it's too many expansion differences(?)
			--if (self.AddDebugMessageFormatted) then
			--	self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			--end
		end 
	end 
	for _,object in pairs({
		"GameTimeFrame",
		"GarrisonLandingPageMinimapButton",
		"GuildInstanceDifficulty",
		"MiniMapInstanceDifficulty",
		"MinimapBorder",
		"MinimapBorderTop",
		"MinimapCluster",
		"MiniMapMailBorder",
		"MiniMapMailFrame",
		"MinimapBackdrop", 
		"MinimapNorthTag",
		"MiniMapTracking",
		"MiniMapTrackingButton",
		"MiniMapTrackingFrame",
		"MiniMapWorldMapButton",
		"MinimapZoomIn",
		"MinimapZoomOut",
		"MinimapZoneTextButton"
	}) do 
		if (_G[object]) then 
			_G[object]:SetParent(UIHider)
		else
			--if (self.AddDebugMessageFormatted) then
			--	self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			--end
		end 
	end 

	-- Ugly hack to keep the keybind functioning
	if (GarrisonLandingPageMinimapButton) then
		GarrisonLandingPageMinimapButton:Show()
		GarrisonLandingPageMinimapButton.Hide = GarrisonLandingPageMinimapButton.Show
	end

	-- Can't really be destroyed safely, just hiding it instead.
	if (QueueStatusMinimapButton) then
		QueueStatusMinimapButton:SetHighlightTexture("") 
		QueueStatusMinimapButtonBorder:SetAlpha(0)
		QueueStatusMinimapButtonBorder:SetTexture(nil)
		QueueStatusMinimapButton.Highlight:SetAlpha(0)
		QueueStatusMinimapButton.Highlight:SetTexture(nil)
	end

	-- Classic Battleground Queue Button
	-- Killing fully now prevents it from being remade(?)
	if (MiniMapBattlefieldFrame) then 
		MiniMapBattlefieldIcon:SetAlpha(0)
		MiniMapBattlefieldIcon:SetTexture(nil)
		MiniMapBattlefieldBorder:SetAlpha(0)
		MiniMapBattlefieldBorder:SetTexture(nil)
		BattlegroundShine:SetAlpha(0)
		BattlegroundShine:SetTexture(nil)
	end

	-- Can we do this?
	self:DisableUIWidget("MinimapClock")
end

UIWidgetDependency["MinimapClock"] = "Blizzard_TimeManager"
UIWidgetsDisable["MinimapClock"] = function(self)
	if TimeManagerClockButton then 
		TimeManagerClockButton:SetParent(UIHider)
		TimeManagerClockButton:UnregisterAllEvents()
	end 
end

UIWidgetsDisable["MirrorTimer"] = function(self)
	for i = 1,MIRRORTIMER_NUMTIMERS do
		local timer = _G["MirrorTimer"..i]
		timer:SetScript("OnEvent", nil)
		timer:SetScript("OnUpdate", nil)
		timer:SetParent(UIHider)
		timer:UnregisterAllEvents()
	end
end 

UIWidgetDependency["ObjectiveTracker"] = "Blizzard_ObjectiveTracker"
UIWidgetsDisable["ObjectiveTracker"] = function(self)

	if (ObjectiveTrackerFrame) then
		ObjectiveTrackerFrame:UnregisterAllEvents()
		ObjectiveTrackerFrame:SetScript("OnLoad", nil)
		ObjectiveTrackerFrame:SetScript("OnEvent", nil)
		ObjectiveTrackerFrame:SetScript("OnUpdate", nil)
		ObjectiveTrackerFrame:SetScript("OnSizeChanged", nil)
		ObjectiveTrackerFrame:SetParent(UIHider)
	end

	if (ObjectiveTrackerBlocksFrame) then
		ObjectiveTrackerBlocksFrame:UnregisterAllEvents()
		ObjectiveTrackerBlocksFrame:SetScript("OnLoad", nil)
		ObjectiveTrackerBlocksFrame:SetScript("OnEvent", nil)
		ObjectiveTrackerBlocksFrame:SetScript("OnUpdate", nil)
		ObjectiveTrackerBlocksFrame:SetScript("OnSizeChanged", nil)
		ObjectiveTrackerBlocksFrame:SetParent(UIHider)
	end

	-- Will this kill the keystoned mythic spam errors?
	if (ScenarioBlocksFrame) then
		ScenarioBlocksFrame:UnregisterAllEvents()
		ScenarioBlocksFrame:SetScript("OnLoad", nil)
		ScenarioBlocksFrame:SetScript("OnEvent", nil)
		ScenarioBlocksFrame:SetScript("OnUpdate", nil)
		ScenarioBlocksFrame:SetScript("OnSizeChanged", nil)
		ScenarioBlocksFrame:SetParent(UIHider)
	end
end

UIWidgetDependency["OrderHall"] = "Blizzard_OrderHallUI"
UIWidgetsDisable["OrderHall"] = function(self)
	if (not OrderHallCommandBar) then
		return
	end
	OrderHallCommandBar:SetScript("OnLoad", nil)
	OrderHallCommandBar:SetScript("OnShow", nil)
	OrderHallCommandBar:SetScript("OnHide", nil)
	OrderHallCommandBar:SetScript("OnEvent", nil)
	OrderHallCommandBar:SetParent(UIHider)
	OrderHallCommandBar:UnregisterAllEvents()
end

UIWidgetsDisable["PlayerPowerBarAlt"] = function(self)
	if (not PlayerPowerBarAlt) then
		return
	end
	PlayerPowerBarAlt.ignoreFramePositionManager = true
	PlayerPowerBarAlt:UnregisterAllEvents()
	PlayerPowerBarAlt:SetParent(UIHider)
end

UIWidgetsDisable["QuestTimerFrame"] = function(self)
	if (not QuestTimerFrame) then
		return
	end
	QuestTimerFrame:SetScript("OnLoad", nil)
	QuestTimerFrame:SetScript("OnEvent", nil)
	QuestTimerFrame:SetScript("OnUpdate", nil)
	QuestTimerFrame:SetScript("OnShow", nil)
	QuestTimerFrame:SetScript("OnHide", nil)
	QuestTimerFrame:SetParent(UIHider)
	QuestTimerFrame:Hide()
	QuestTimerFrame.numTimers = 0
	QuestTimerFrame.updating = nil
	for i = 1,MAX_QUESTS do
		_G["QuestTimer"..i]:Hide()
	end
end

UIWidgetsDisable["QuestWatchFrame"] = function(self)
	if (not QuestWatchFrame) then
		return
	end
	QuestWatchFrame:SetParent(UIHider)
	local frame = TalkingHeadFrame
end

UIWidgetsDisable["RaidBossEmotes"] = function(self)
	RaidBossEmoteFrame:SetParent(UIHider)
	RaidBossEmoteFrame:Hide()
end
UIWidgetsEnable["RaidBossEmotes"] = function(self)
	RaidBossEmoteFrame:SetParent(UIParent)
	RaidBossEmoteFrame:Show()
end

UIWidgetsDisable["RaidWarnings"] = function(self)
	RaidWarningFrame:SetParent(UIHider)
	RaidWarningFrame:Hide()
	RaidBossEmoteFrame:SetPoint("TOP", UIErrorsFrame, "BOTTOM", 0, 0)
end
UIWidgetsEnable["RaidWarnings"] = function(self)
	RaidWarningFrame:SetParent(UIParent)
	RaidWarningFrame:Show()
	RaidBossEmoteFrame:SetPoint("TOP", RaidWarningFrame, "BOTTOM", 0, 0)
end

UIWidgetDependency["TalkingHead"] = "Blizzard_TalkingHeadUI"
UIWidgetsDisable["TalkingHead"] = function(self)
	local frame = TalkingHeadFrame
	if (not frame) then
		return
	end
	frame:UnregisterEvent("TALKINGHEAD_REQUESTED")
	frame:UnregisterEvent("TALKINGHEAD_CLOSE")
	frame:UnregisterEvent("SOUNDKIT_FINISHED")
	frame:UnregisterEvent("LOADING_SCREEN_ENABLED")
	frame:Hide()
end

UIWidgetsEnable["TalkingHead"] = function(self)
	local frame = TalkingHeadFrame
	if (not frame) then
		return
	end
	-- The frame is loaded, so we re-register any needed events,
	-- just in case this is a manual user called re-enabling.
	-- Or in case another addon has disabled it.
	frame:RegisterEvent("TALKINGHEAD_REQUESTED")
	frame:RegisterEvent("TALKINGHEAD_CLOSE")
	frame:RegisterEvent("SOUNDKIT_FINISHED")
	frame:RegisterEvent("LOADING_SCREEN_ENABLED")
end

UIWidgetsDisable["TimerTracker"] = function(self)
	if (not TimerTracker) then
		return
	end
	TimerTracker:SetScript("OnEvent", nil)
	TimerTracker:SetScript("OnUpdate", nil)
	TimerTracker:UnregisterAllEvents()
	if (TimerTracker.timerList) then
		for _, bar in pairs(TimerTracker.timerList) do
			bar:SetScript("OnEvent", nil)
			bar:SetScript("OnUpdate", nil)
			bar:SetParent(UIHider)
			bar:UnregisterAllEvents()
		end
	end
end

UIWidgetsDisable["TotemFrame"] = function(self)
	if (not TotemFrame) then
		return
	end
	TotemFrame:UnregisterAllEvents()
	TotemFrame:SetScript("OnEvent", nil)
	TotemFrame:SetScript("OnShow", nil)
	TotemFrame:SetScript("OnHide", nil)
end

UIWidgetsDisable["Tutorials"] = function(self)
	TutorialFrame:UnregisterAllEvents()
	TutorialFrame:Hide()
	TutorialFrame.Show = TutorialFrame.Hide
end

UIWidgetsDisable["UnitFramePlayer"] = function(self)
	killUnitFrame("PlayerFrame")

	-- A lot of blizz modules relies on PlayerFrame.unit
	-- This includes the aura frame and several others. 
	_G.PlayerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	-- User placed frames don't animate
	_G.PlayerFrame:SetUserPlaced(true)
	_G.PlayerFrame:SetDontSavePosition(true)
end

UIWidgetsDisable["UnitFramePet"] = function(self)
	if (IsClassic) then
		killUnitFrame("PetFrame")
	else
		-- The retail totem bar relies on this
		-- appearing as blizzard intended.
		-- We need both events and visiblity intact.
		killUnitFrame("PetFrame", false, true, true)
	end
end

UIWidgetsDisable["UnitFrameTarget"] = function(self)
	killUnitFrame("TargetFrame")
	killUnitFrame("ComboFrame")
end

UIWidgetsDisable["UnitFrameToT"] = function(self)
	killUnitFrame("TargetFrameToT")
	TargetofTarget_Update(TargetFrameToT)
end

UIWidgetsDisable["UnitFrameFocus"] = function(self)
	killUnitFrame("FocusFrame")
	killUnitFrame("TargetofFocusFrame")
end 

UIWidgetsDisable["UnitFrameParty"] = function(self)
	for i = 1,5 do
		killUnitFrame(("PartyMemberFrame%.0f"):format(i))
	end

	-- Kill off the party background
	_G.PartyMemberBackground:SetParent(UIHider)
	_G.PartyMemberBackground:Hide()
	_G.PartyMemberBackground:SetAlpha(0)

	--hooksecurefunc("CompactPartyFrame_Generate", function() 
	--	killUnitFrame(_G.CompactPartyFrame)
	--	for i=1, _G.MEMBERS_PER_RAID_GROUP do
	--		killUnitFrame(_G["CompactPartyFrameMember" .. i])
	--	end	
	--end)
end

UIWidgetsDisable["UnitFrameRaid"] = function(self)
	-- dropdowns cause taint through the blizz compact unit frames, so we disable them
	-- http://www.wowinterface.com/forums/showpost.php?p=261589&postcount=5
	if (CompactUnitFrameProfiles) then
		CompactUnitFrameProfiles:UnregisterAllEvents()
	end

	if (CompactRaidFrameManager) and (CompactRaidFrameManager:GetParent() ~= UIHider) then
		CompactRaidFrameManager:SetParent(UIHider)
	end

	UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")
end

UIWidgetsDisable["UnitFrameBoss"] = function(self)
	for i = 1,MAX_BOSS_FRAMES do
		killUnitFrame(("Boss%.0fTargetFrame"):format(i))
	end
end

UIWidgetsDisable["UnitFrameArena"] = function(self)
	for i = 1,5 do
		killUnitFrame(("ArenaEnemyFrame%.0f"):format(i))
	end
	if (Arena_LoadUI) then
		Arena_LoadUI = function() end
	end
	if (IsRetail) then
		SetCVar("showArenaEnemyFrames", "0", "SHOW_ARENA_ENEMY_FRAMES_TEXT")
	end
end

UIWidgetsDisable["ZoneText"] = function(self)
	local ZoneTextFrame = _G.ZoneTextFrame
	local SubZoneTextFrame = _G.SubZoneTextFrame
	local AutoFollowStatus = _G.AutoFollowStatus

	ZoneTextFrame:SetParent(UIHider)
	ZoneTextFrame:UnregisterAllEvents()
	ZoneTextFrame:SetScript("OnUpdate", nil)
	-- ZoneTextFrame:Hide()
	
	SubZoneTextFrame:SetParent(UIHider)
	SubZoneTextFrame:UnregisterAllEvents()
	SubZoneTextFrame:SetScript("OnUpdate", nil)
	-- SubZoneTextFrame:Hide()
	
	AutoFollowStatus:SetParent(UIHider)
	AutoFollowStatus:UnregisterAllEvents()
	AutoFollowStatus:SetScript("OnUpdate", nil)
	-- AutoFollowStatus:Hide()
end 

-- Widget Styling Pool
-----------------------------------------------------------------
UIWidgetStyling["BagButtons"] = function(self, ...)
	-- Attempt to hook the bag bar to the bags
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

UIWidgetStyling["GameMenu"] = function(self, ...)

end

UIWidgetStyling["ObjectiveTracker"] = IsClassic and function(self, ...)




end

or IsRetail and function(self, ...)



end

UIWidgetStyling["PopUps"] = function(self, ...)

	-- Retrieve styling data
	local frameBackdrop, 
	      frameBackdropOffsets,
	      frameBackdropColor, 
	      frameBackdropBorderColor, 
	      buttonBackdrop, 
	      buttonBackdropOffsets,
	      buttonBackdropColor, 
	      buttonBackdropBorderColor, 
	      buttonBackdropHoverColor, 
		  buttonBackdropHoverBorderColor, 
		  editBoxBackdrop,
		  editBoxBackdropColor,
		  editBoxBackdropBorderColor,
		  editBoxInsets,
	      anchorOffsetV = ...

	-- Custom backdrop frames
	local Backdrops = {}
	local GetBackdrop = function(popup)
		local backdrop = Backdrops[popup]
		if (not backdrop) then
			backdrop = CreateFrame("Frame", nil, popup, BackdropTemplateMixin and "BackdropTemplate")
			backdrop:SetFrameLevel(popup:GetFrameLevel())
			Backdrops[popup] = backdrop
		end	
		return backdrop
	end

	local SetAnchors
	SetAnchors = function(self, event)
		-- Not strictly certain if moving them in combat would taint them, 
		-- but knowing the blizzard UI, I'm not willing to take that chance.
		if (InCombatLockdown()) then 
			self:RegisterEvent("PLAYER_REGEN_ENABLED", SetAnchors)
			return

		elseif (event == "PLAYER_REGEN_ENABLED") then
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", SetAnchors)
		end 

		local previous
		for i = 1, STATICPOPUP_NUMDIALOGS do
			local popup = _G["StaticPopup"..i]
			local point, anchor, rpoint, x, y = popup:GetPoint()
			if (anchor == previous) then
				-- We only change the offsets values, not the anchor points, 
				-- since experience tells me that this is a safer way to avoid potential taint!
				popup:ClearAllPoints()
				popup:SetPoint(point, anchor, rpoint, 0, -(anchorOffsetV or 6))
			end
			previous = popup
		end
	end
	SetAnchors()
	
	-- Clear out the old
	local Clear = function(popup)

		local name = popup:GetName()
		if (not name) then
			return
		end

		-- Remove 8.x backdrops
		if (popup.SetBackdrop) then
			popup:SetBackdrop(nil)
			popup:SetBackdropColor(0,0,0,0)
			popup:SetBackdropBorderColor(0,0,0,0)
		end

		-- Remove 9.x backdrops
		if (popup.Border) then 
			popup.Border:SetAlpha(0)
		end

		-- Remove button artwork
		for _,buttonName in pairs({ "Button1", "Button2", "Button3", "Button4", "ExtraButton" }) do
			local button = _G[name..buttonName]
			if (button) then
				button:GetNormalTexture():SetVertexColor(0, 0, 0, 0)
				button:GetHighlightTexture():SetVertexColor(0, 0, 0, 0)
				button:GetPushedTexture():SetVertexColor(0, 0, 0, 0)
				button:GetDisabledTexture():SetVertexColor(0, 0, 0, 0)
				if (button.SetBackdrop) then
					button:SetBackdrop(nil)
					button:SetBackdropColor(0,0,0,0)
					button:SetBackdropBorderColor(0,0,0.0)
				end
			end
		end

		-- Remove editbox artwork
		local editbox = _G[name .. "EditBox"]
		if (editbox) then
			for _,texName in pairs({ "EditBoxLeft", "EditBoxMid", "EditBoxRight" }) do
				local tex = _G[name..texName]
				if (tex) then
					tex:SetTexture(nil)
					tex:SetAlpha(0)
				end
			end
			if (editbox.SetBackdrop) then
				editbox:SetBackdrop(nil)
				editbox:SetBackdropColor(0, 0, 0, 0)
				editbox:SetBackdropBorderColor(0, 0, 0, 0)
			end
			editbox:SetTextInsets(6, 6, 0, 0)
		end

		-- Remaining frames:
		-- "$parentMoneyFrame" - "SmallMoneyFrameTemplate"
		-- "$parentMoneyInputFrame" - "MoneyInputFrameTemplate"
		-- "$parentItemFrame"

	end

	local OnShow = function(popup)

		local name = popup:GetName()
		if (not name) then
			return
		end

		-- Clear the blizzard content
		Clear(popup)

		-- User styled backdrops
		local backdrop = GetBackdrop(popup)
		backdrop:SetBackdrop(frameBackdrop)
		backdrop:SetBackdropColor(unpack(frameBackdropColor))
		backdrop:SetBackdropBorderColor(unpack(frameBackdropBorderColor))
		backdrop:SetPoint("TOPLEFT", -frameBackdropOffsets[1], frameBackdropOffsets[3])
		backdrop:SetPoint("BOTTOMRIGHT", frameBackdropOffsets[2], -frameBackdropOffsets[4])

		-- User styled buttons
		for _,buttonName in pairs({ "Button1", "Button2", "Button3", "Button4", "ExtraButton" }) do
			local button = _G[name..buttonName]
			if (button) then
				local border = GetBackdrop(button)
				border:SetFrameLevel(button:GetFrameLevel() - 1)
				border:SetPoint("TOPLEFT", -buttonBackdropOffsets[1], buttonBackdropOffsets[3])
				border:SetPoint("BOTTOMRIGHT", buttonBackdropOffsets[2], -buttonBackdropOffsets[4])
				border:SetBackdrop(buttonBackdrop)
				border:SetBackdropColor(unpack(buttonBackdropColor))
				border:SetBackdropBorderColor(unpack(buttonBackdropBorderColor))
				button:HookScript("OnEnter", function() 
					border:SetBackdropColor(unpack(buttonBackdropHoverColor))
					border:SetBackdropBorderColor(unpack(buttonBackdropHoverBorderColor))
				end)
				button:HookScript("OnLeave", function() 
					border:SetBackdropColor(unpack(buttonBackdropColor))
					border:SetBackdropBorderColor(unpack(buttonBackdropBorderColor))
				end)
			end
		end

		-- User styled editbox
		local editbox = _G[name.."EditBox"]
		if (editbox) then
			if (editbox.SetBackdrop) then
				editbox:SetBackdrop(editBoxBackdrop)
				editbox:SetBackdropColor(unpack(editBoxBackdropColor))
				editbox:SetBackdropBorderColor(unpack(editBoxBackdropBorderColor))
			end
			editbox:SetTextInsets(unpack(editBoxInsets))
		end
	end
	
	local Hooked = {}
	for i = 1, STATICPOPUP_NUMDIALOGS do 
		local popup = _G["StaticPopup"..i]
		if (popup) and (not Hooked[popup]) then
			self:SetHook(popup, "OnShow", function() OnShow(popup) end, "GP_POPUP"..i.."_ONSHOW")
			Hooked[popup] = true
		end
	end

	-- The popups are re-anchored by blizzard, so we need to re-adjust them when they do.
	self:SetSecureHook("StaticPopup_SetUpPosition", SetAnchors, "GP_POPUP_SET_ANCHORS")
end

UIWidgetDependency["WorldMap"] = "Blizzard_WorldMap"
UIWidgetStyling["WorldMap"] = IsClassic and function(self, ...)
	local Canvas = WorldMapFrame
	Canvas.BlackoutFrame:Hide()
	Canvas:SetIgnoreParentScale(false)
	Canvas:RefreshDetailLayers()

	-- Contains the actual map. 
	local Container = WorldMapFrame.ScrollContainer
	Container.GetCanvasScale = function(self)
		return self:GetScale()
	end

	local Saturate = Saturate
	Container.NormalizeUIPosition = function(self, x, y)
		return Saturate(self:NormalizeHorizontalSize(x / self:GetCanvasScale() - self.Child:GetLeft())),
		       Saturate(self:NormalizeVerticalSize(self.Child:GetTop() - y / self:GetCanvasScale()))
	end

	Container.GetCursorPosition = function(self)
		local currentX, currentY = GetCursorPosition()
		local scale = UIParent:GetScale()
		if not(currentX and currentY and scale) then 
			return 0,0
		end 
		local scaledX, scaledY = currentX/scale, currentY/scale
		return scaledX, scaledY
	end

	Container.GetNormalizedCursorPosition = function(self)
		local x,y = self:GetCursorPosition()
		return self:NormalizeUIPosition(x,y)
	end

	local frame = CreateFrame("Frame")
	frame.elapsed = 0
	frame.stopAlpha = .9
	frame.moveAlpha = .65
	frame.stepIn = .05
	frame.stepOut = .05
	frame.throttle = .02
	frame:SetScript("OnEvent", function(selv, event) 
		if (event == "PLAYER_STARTED_MOVING") then 
			frame.alpha = Canvas:GetAlpha()
			frame:SetScript("OnUpdate", frame.Starting)

		elseif (event == "PLAYER_STOPPED_MOVING") or (event == "PLAYER_ENTERING_WORLD") then 
			frame.alpha = Canvas:GetAlpha()
			frame:SetScript("OnUpdate", frame.Stopping)
		end
	end)

	frame.Stopping = function(self, elapsed) 
		self.elapsed = self.elapsed + elapsed
		if (self.elapsed < frame.throttle) then
			return 
		end 
		if (frame.alpha + frame.stepIn < frame.stopAlpha) then 
			frame.alpha = frame.alpha + frame.stepIn
		else 
			frame.alpha = frame.stopAlpha
			frame:SetScript("OnUpdate", nil)
		end 
		Canvas:SetAlpha(frame.alpha)
	end

	frame.Starting = function(self, elapsed) 
		self.elapsed = self.elapsed + elapsed
		if (self.elapsed < frame.throttle) then
			return 
		end 
		if (frame.alpha - frame.stepOut > frame.moveAlpha) then 
			frame.alpha = frame.alpha - frame.stepOut
		else 
			frame.alpha = frame.moveAlpha
			frame:SetScript("OnUpdate", nil)
		end 
		Canvas:SetAlpha(frame.alpha)
	end

	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_STARTED_MOVING")
	frame:RegisterEvent("PLAYER_STOPPED_MOVING")
end 

or IsRetail and function(self, ...)

	local WorldMapFrame = WorldMapFrame

	local SetLargeWorldMap, SetSmallWorldMap
	local SynchronizeDisplayState
	local UpdateMaximizedSize, UpdateMaximizedSize
	local WorldMapOnShow

	local smallerMapScale, mapSized = .8

	SetLargeWorldMap = function(self)
		WorldMapFrame:SetParent(UIParent)
		WorldMapFrame:SetScale(1)
		WorldMapFrame.ScrollContainer.Child:SetScale(smallerMapScale)
	
		if (WorldMapFrame:GetAttribute("UIPanelLayout-area") ~= "center") then
			SetUIPanelAttribute(WorldMapFrame, "area", "center");
		end
	
		if (WorldMapFrame:GetAttribute("UIPanelLayout-allowOtherPanels") ~= true) then
			SetUIPanelAttribute(WorldMapFrame, "allowOtherPanels", true)
		end
	
		WorldMapFrame:OnFrameSizeChanged()
		if (WorldMapFrame:GetMapID()) then
			WorldMapFrame.NavBar:Refresh()
		end
	end
	
	UpdateMaximizedSize = function(self)
		local width, height = WorldMapFrame:GetSize()
		local magicNumber = (1 - smallerMapScale) * 100
		WorldMapFrame:SetSize((width * smallerMapScale) - (magicNumber + 2), (height * smallerMapScale) - 2)
	end
	
	SynchronizeDisplayState = function(self)
		if (WorldMapFrame:IsMaximized()) then
			WorldMapFrame:ClearAllPoints()
			WorldMapFrame:SetPoint("CENTER", UIParent)
		end
	end
	
	SetSmallWorldMap = function(self)
		if (not WorldMapFrame:IsMaximized()) then
			WorldMapFrame:ClearAllPoints()
			WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -94)
		end
	end
	
	WorldMapOnShow = function(self, event, ...)
		if (mapSized) then
			return
		end
	
		-- Don't do this in combat, there are secure elements here.
		if (InCombatLockdown()) then
			self:RegisterEvent("PLAYER_REGEN_ENABLED", WorldMapOnShow)
			return
	
		-- Only ever need this event once.
		elseif (event == "PLAYER_REGEN_ENABLED") then
			self:UnregisterEvent(event, WorldMapOnShow)
		end
	
		if (WorldMapFrame:IsMaximized()) then
			WorldMapFrame:UpdateMaximizedSize()
			SetLargeWorldMap()
		else
			SetSmallWorldMap()
		end
	
		-- Never again!
		mapSized = true
	end
	
	WorldMapFrame.BlackoutFrame.Blackout:SetTexture(nil)
	WorldMapFrame.BlackoutFrame:EnableMouse(false)

	self:SetSecureHook(WorldMapFrame, "Maximize", SetLargeWorldMap, "GP_SET_LARGE_WORLDMAP")
	self:SetSecureHook(WorldMapFrame, "Minimize", SetSmallWorldMap, "GP_SET_SMALL_WORLDMAP")
	self:SetSecureHook(WorldMapFrame, "SynchronizeDisplayState", SynchronizeDisplayState, "GP_SYNC_DISPLAYSTATE_WORLDMAP")
	self:SetSecureHook(WorldMapFrame, "UpdateMaximizedSize", UpdateMaximizedSize, "GP_UPDATE_MAXIMIZED_WORLDMAP")

	WorldMapFrame:HookScript("OnShow", function() WorldMapOnShow(self) end)
end

-- Library Event Handling
-----------------------------------------------------------------
LibBlizzard.OnEvent = function(self, event, ...)
	local arg1 = ...
	if (event == "ADDON_LOADED") then
		local found, hasQueued

		-- Iterate widgets queued for disabling after their loading 
		for widgetName,widgetData in pairs(self.queue) do 
			if (widgetData.addonName == arg1) then 
				UIWidgetsDisable[widgetName](self, unpack(widgetData.args))
				self.queue[widgetName] = nil
				found = true
			else 
				hasQueued = true
			end 
			-- Definitely not the fastest way, but sufficient for our purpose
			if (found) and (hasQueued) then
				break
			end
		end 

		-- Iterate widgets queued for enabling after their loading 
		for widgetName,widgetData in pairs(self.enableQueue) do 
			if (widgetData.addonName == arg1) then 
				UIWidgetsEnable[widgetName](self, unpack(widgetData.args))
				self.enableQueue[widgetName] = nil
				found = true
			else 
				hasQueued = true
			end 
			-- Definitely not the fastest way, but sufficient for our purpose
			if (found) and (hasQueued) then
				break
			end
		end 
		
		-- Iterate widgets queued for styling after their loading
		for widgetName, widgetData in pairs(self.stylingQueue) do 
			if (widgetData.addonName == arg1) then 
				UIWidgetStyling[widgetName](self, unpack(widgetData.args))
				self.stylingQueue[widgetName] = nil
				found = true
			else 
				hasQueued = true
			end 
			if (found) and (hasQueued) then
				break
			end
		end 

		-- Nothing queued, kill off this event
		if (not hasQueued) then 
			if self:IsEventRegistered("ADDON_LOADED", "OnEvent") then 
				self:UnregisterEvent("ADDON_LOADED", "OnEvent")
			end 
		end 
	end 
end 

-- Library Public API
-----------------------------------------------------------------
LibBlizzard.EnableUIWidget = function(self, name, ...)
	-- Just silently fail for widgets that don't exist.
	-- Makes it much simpler during development, 
	-- and much easier in the future to upgrade.
	if (not UIWidgetsEnable[name]) then 
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The UI widget '%s' does not have an Enable method."):format(name))
		end
		return 
	end 
	local dependency = UIWidgetDependency[name]
	if (dependency) then 
		if (not IsAddOnLoaded(dependency)) then 
			LibBlizzard.enableQueue[name] = { addonName = dependency, args = { ... } }
			if (not LibBlizzard:IsEventRegistered("ADDON_LOADED", "OnEvent")) then 
				LibBlizzard:RegisterEvent("ADDON_LOADED", "OnEvent")
			end 
			return 
		end 
	end 
	UIWidgetsEnable[name](LibBlizzard, ...)
end

LibBlizzard.DisableUIWidget = function(self, name, ...)
	-- Just silently fail for widgets that don't exist.
	-- Makes it much simpler during development, 
	-- and much easier in the future to upgrade.
	if (not UIWidgetsDisable[name]) then 
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The UI widget '%s' does not exist."):format(name))
		end
		return 
	end 
	local dependency = UIWidgetDependency[name]
	if (dependency) then 
		if (not IsAddOnLoaded(dependency)) then 
			LibBlizzard.queue[name] = { addonName = dependency, args = { ... } }
			if (not LibBlizzard:IsEventRegistered("ADDON_LOADED", "OnEvent")) then 
				LibBlizzard:RegisterEvent("ADDON_LOADED", "OnEvent")
			end 
			return 
		end 
	end 
	UIWidgetsDisable[name](LibBlizzard, ...)
end

LibBlizzard.StyleUIWidget = function(self, name, ...)
	-- Just silently fail for widgets that don't exist.
	-- Makes it much simpler during development, 
	-- and much easier in the future to upgrade.
	if (not UIWidgetStyling[name]) then 
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The UI widget '%s' does not exist."):format(name))
		end
		return 
	end 
	local dependency = UIWidgetDependency[name]
	if (dependency) then 
		if (not IsAddOnLoaded(dependency)) then 
			LibBlizzard.stylingQueue[name] = { addonName = dependency, args = { ... } }
			if (not LibBlizzard:IsEventRegistered("ADDON_LOADED", "OnEvent")) then 
				LibBlizzard:RegisterEvent("ADDON_LOADED", "OnEvent")
			end 
			return 
		end 
	end 
	UIWidgetStyling[name](LibBlizzard, ...)
end

LibBlizzard.DisableUIMenuOption = function(self, option_shrink, option_name)
	local option = _G[option_name]
	if not(option) or not(option.IsObjectType) or not(option:IsObjectType("Frame")) then
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The menu option '%s' does not exist."):format(option_name))
		end
		return
	end
	option:SetParent(UIHider)
	if option.UnregisterAllEvents then
		option:UnregisterAllEvents()
	end
	if option_shrink then
		option:SetHeight(0.00001)
		-- Needed for the options to shrink properly.
		-- Will mess up alignment for indented options, 
		-- so only use this when the following options is
		-- horizontally aligned with the removed one.
		if (option_shrink == true) then
			option:SetScale(0.00001) 
		end
	end
	option.cvar = ""
	option.uvar = ""
	option.value = nil
	option.oldValue = nil
	option.defaultValue = nil
	option.setFunc = function() end
end

LibBlizzard.DisableUIMenuPage = function(self, panel_id, panel_name)
	local button,window
	-- remove an entire blizzard options panel, 
	-- and disable its automatic cancel/okay functionality
	-- this is needed, or the option will be reset when the menu closes
	-- it is also a major source of taint related to the Compact group frames!
	if (panel_id) then
		local category = _G["InterfaceOptionsFrameCategoriesButton" .. panel_id]
		if category then
			category:SetScale(0.00001)
			category:SetAlpha(0)
			button = true
		end
	end
	if (panel_name) then
		local panel = _G[panel_name]
		if panel then
			panel:SetParent(UIHider)
			if panel.UnregisterAllEvents then
				panel:UnregisterAllEvents()
			end
			panel.cancel = function() end
			panel.okay = function() end
			panel.refresh = function() end
			window = true
		end
	end
	-- By removing the menu panels above we're preventing the blizzard UI from calling it, 
	-- and for some reason it is required to be called at least once, 
	-- or the game won't fire off the events that tell the UI that the player has an active pet out. 
	-- In other words: without it both the pet bar and pet unitframe will fail after a /reload
	if (panel_id == 5) or (panel_name == "InterfaceOptionsActionBarsPanel") then 
		SetActionBarToggles(nil, nil, nil, nil, nil)
	end 
	if (panel_id and not button) then
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The panel button with id '%.0f' does not exist."):format(panel_id))
		end
	end 
	if (panel_name and not window) then
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The menu panel named '%s' does not exist."):format(panel_name))
		end
	end 
end

-- Module embedding
local embedMethods = {
	DisableUIMenuOption = true,
	DisableUIMenuPage = true,
	DisableUIWidget = true,
	EnableUIWidget = true,
	StyleUIWidget = true
}

LibBlizzard.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibBlizzard.embeds) do
	LibBlizzard:Embed(target)
end
