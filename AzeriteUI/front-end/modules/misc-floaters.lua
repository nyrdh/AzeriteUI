local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("BlizzardFloaterHUD", "LOW", "LibMessage", "LibEvent", "LibFrame", "LibTooltip", "LibDB", "LibBlizzard", "LibClientBuild", "LibSound")

-- Lua API
local _G = _G
local ipairs = ipairs
local table_remove = table.remove

-- WoW API
local GetGameMessageInfo = GetGameMessageInfo
local InCombatLockdown = InCombatLockdown

-- Private API
local GetConfig = Private.GetConfig
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout

-- Constants for client version
local IsClassic = Module:IsClassic()
local IsRetail = Module:IsRetail()

-- Local caches
local HolderCache, FrameCache = {}, {}

-- Pure meta methods
local mt = getmetatable(CreateFrame("Frame")).__index
local Frame_ClearAllPoints = mt.ClearAllPoints
local Frame_IsShown = mt.IsShown
local Frame_SetParent = mt.SetParent
local Frame_SetPoint = mt.SetPoint

local blackList = {
	msgTypes = {
		[LE_GAME_ERR_ABILITY_COOLDOWN] = true,
		[LE_GAME_ERR_SPELL_COOLDOWN] = true,
		[LE_GAME_ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS] = true,
		[LE_GAME_ERR_OUT_OF_SOUL_SHARDS] = true,
		[LE_GAME_ERR_OUT_OF_FOCUS] = true,
		[LE_GAME_ERR_OUT_OF_COMBO_POINTS] = true,
		[LE_GAME_ERR_OUT_OF_HEALTH] = true,
		[LE_GAME_ERR_OUT_OF_RAGE] = true,
		[LE_GAME_ERR_OUT_OF_RANGE] = true,
		[LE_GAME_ERR_OUT_OF_ENERGY] = true
	},
	[ ERR_ABILITY_COOLDOWN ] = true, 						-- Ability is not ready yet.
	[ ERR_ATTACK_CHARMED ] = true, 							-- Can't attack while charmed. 
	[ ERR_ATTACK_CONFUSED ] = true, 						-- Can't attack while confused.
	[ ERR_ATTACK_DEAD ] = true, 							-- Can't attack while dead. 
	[ ERR_ATTACK_FLEEING ] = true, 							-- Can't attack while fleeing. 
	[ ERR_ATTACK_PACIFIED ] = true, 						-- Can't attack while pacified. 
	[ ERR_ATTACK_STUNNED ] = true, 							-- Can't attack while stunned.
	[ ERR_AUTOFOLLOW_TOO_FAR ] = true, 						-- Target is too far away.
	[ ERR_BADATTACKFACING ] = true, 						-- You are facing the wrong way!
	[ ERR_BADATTACKPOS ] = true, 							-- You are too far away!
	[ ERR_CLIENT_LOCKED_OUT ] = true, 						-- You can't do that right now.
	[ ERR_ITEM_COOLDOWN ] = true, 							-- Item is not ready yet. 
	[ ERR_OUT_OF_ENERGY ] = true, 							-- Not enough energy
	[ ERR_OUT_OF_FOCUS ] = true, 							-- Not enough focus
	[ ERR_OUT_OF_HEALTH ] = true, 							-- Not enough health
	[ ERR_OUT_OF_MANA ] = true, 							-- Not enough mana
	[ ERR_OUT_OF_RAGE ] = true, 							-- Not enough rage
	[ ERR_OUT_OF_RANGE ] = true, 							-- Out of range.
	[ ERR_SPELL_COOLDOWN ] = true, 							-- Spell is not ready yet.
	[ ERR_SPELL_FAILED_ALREADY_AT_FULL_HEALTH ] = true, 	-- You are already at full health.
	[ ERR_SPELL_OUT_OF_RANGE ] = true, 						-- Out of range.
	[ ERR_USE_TOO_FAR ] = true, 							-- You are too far away.
	[ SPELL_FAILED_CANT_DO_THAT_RIGHT_NOW ] = true, 		-- You can't do that right now.
	[ SPELL_FAILED_CASTER_AURASTATE ] = true, 				-- You can't do that yet
	[ SPELL_FAILED_CASTER_DEAD ] = true, 					-- You are dead
	[ SPELL_FAILED_CASTER_DEAD_FEMALE ] = true, 			-- You are dead
	[ SPELL_FAILED_CHARMED ] = true, 						-- Can't do that while charmed
	[ SPELL_FAILED_CONFUSED ] = true, 						-- Can't do that while confused
	[ SPELL_FAILED_FLEEING ] = true, 						-- Can't do that while fleeing
	[ SPELL_FAILED_ITEM_NOT_READY ] = true, 				-- Item is not ready yet
	[ SPELL_FAILED_NO_COMBO_POINTS ] = true, 				-- That ability requires combo points
	[ SPELL_FAILED_NOT_BEHIND ] = true, 					-- You must be behind your target.
	[ SPELL_FAILED_NOT_INFRONT ] = true, 					-- You must be in front of your target.
	[ SPELL_FAILED_OUT_OF_RANGE ] = true, 					-- Out of range
	[ SPELL_FAILED_PACIFIED ] = true, 						-- Can't use that ability while pacified
	[ SPELL_FAILED_SPELL_IN_PROGRESS ] = true, 				-- Another action is in progress
	[ SPELL_FAILED_STUNNED ] = true, 						-- Can't do that while stunned
	[ SPELL_FAILED_UNIT_NOT_INFRONT ] = true, 				-- Target needs to be in front of you.
	[ SPELL_FAILED_UNIT_NOT_BEHIND ] = true, 				-- Target needs to be behind you.
}

-- Utility
----------------------------------------------------
local DisableTexture = function(texture, _, loop)
	if (loop) then
		return
	end
	texture:SetTexture(nil, true)
	texture:SetAlpha(0)
end

local ResetPoint = function(object, _, anchor) 
	local holder = object and HolderCache[object]
	if (holder) then 
		if (anchor ~= holder) then
			Frame_SetParent(object, holder)
			Frame_ClearAllPoints(object)
			Frame_SetPoint(object, "CENTER", holder, "CENTER", 0, 0)
		end
	end 
end

local GetHolder = function(object, ...)

	local holder = HolderCache[object]
	if (not holder) then
		holder = Module:CreateFrame("Frame", nil, "UICenter")
		holder:SetSize(2,2)
		holder:SetFrameStrata("LOW")
		HolderCache[object] = holder
	end

	if (select("#", ...) > 0) then
		holder:Place(...)
	end

	return holder
end

local CreatePointHook = function(object)
	-- Always do this.
	ResetPoint(object)

	-- Don't create multiple hooks
	if (not FrameCache[object]) then 
		hooksecurefunc(object, "SetPoint", ResetPoint)
		FrameCache[object] = true
	end
end 

-- Callbacks
----------------------------------------------------

local GroupLootContainer_PostUpdate = function(self)
	local lastIdx = nil
	local layout = Module.layout
	for i = 1, self.maxIndex do
		local frame = self.rollFrames[i]
		local prevFrame = self.rollFrames[i-1]
		if ( frame ) then
			frame:ClearAllPoints()
			if prevFrame and not (prevFrame == frame) then
				frame:SetPoint(layout.AlertFramesPosition, prevFrame, layout.AlertFramesAnchor, 0, layout.AlertFramesOffset)
			else
				frame:SetPoint(layout.AlertFramesPosition, self, layout.AlertFramesPosition, 0, 0)
			end
			lastIdx = i
		end
	end
	if (lastIdx) then
		self:SetHeight(self.reservedSize * lastIdx)
		self:Show()
	else
		self:Hide()
	end
end

local AlertSubSystem_AdjustAnchors = function(self, relativeAlert)
	if (self.alertFrame:IsShown()) then
		local layout = Module.layout
		self.alertFrame:ClearAllPoints()
		self.alertFrame:SetPoint(layout.AlertFramesPosition, relativeAlert, layout.AlertFramesAnchor, 0, layout.AlertFramesOffset)
		return self.alertFrame
	end
	return relativeAlert
end

local AlertSubSystem_AdjustAnchorsNonAlert = function(self, relativeAlert)
	if self.anchorFrame:IsShown() then
		local layout = Module.layout
		self.anchorFrame:ClearAllPoints()
		self.anchorFrame:SetPoint(layout.AlertFramesPosition, relativeAlert, layout.AlertFramesAnchor, 0, layout.AlertFramesOffset)
		return self.anchorFrame
	end
	return relativeAlert
end

local AlertSubSystem_AdjustQueuedAnchors = function(self, relativeAlert)
	for alertFrame in self.alertFramePool:EnumerateActive() do
		local layout = Module.layout
		alertFrame:ClearAllPoints()
		alertFrame:SetPoint(layout.AlertFramesPosition, relativeAlert, layout.AlertFramesAnchor, 0, layout.AlertFramesOffset)
		relativeAlert = alertFrame
	end
	return relativeAlert
end

local AlertSubSystem_AdjustPosition = function(alertFrame, subSystem)
	if (subSystem.alertFramePool) then --queued alert system
		subSystem.AdjustAnchors = AlertSubSystem_AdjustQueuedAnchors
	elseif (not subSystem.anchorFrame) then --simple alert system
		subSystem.AdjustAnchors = AlertSubSystem_AdjustAnchors
	elseif (subSystem.anchorFrame) then --anchor frame system
		subSystem.AdjustAnchors = AlertSubSystem_AdjustAnchorsNonAlert
	end
end

local AlertFrame_PostUpdateAnchors = function()
	local layout = Module.layout
	local holder
	if (TalkingHeadFrame and Frame_IsShown(TalkingHeadFrame)) then 
		holder = GetHolder(AlertFrame, unpack(layout.AlertFramesPlaceTalkingHead))
	else 
		holder = GetHolder(AlertFrame, unpack(layout.AlertFramesPlace))
	end
	AlertFrame:ClearAllPoints()
	AlertFrame:SetAllPoints(holder)
	GroupLootContainer:ClearAllPoints()
	GroupLootContainer:SetPoint(layout.AlertFramesPosition, holder, layout.AlertFramesAnchor, 0, layout.AlertFramesOffset)
	if (GroupLootContainer:IsShown()) then
		GroupLootContainer_PostUpdate(GroupLootContainer)
	end
end

-- Updates
----------------------------------------------------
Module.UpdateAlertFrames = function(self)
	if (self.db.enableAlerts) then 
		self:EnableUIWidget("Alerts")
		self:HandleAlertFrames()
	else
		self:DisableUIWidget("Alerts")
	end
end

Module.UpdateTalkingHead = function(self, event, ...)
	if (event == "ADDON_LOADED") then
		local addon = ...
		if (addon ~= "Blizzard_TalkingHeadUI") then
			return
		end
		self:UnregisterEvent("ADDON_LOADED", "UpdateTalkingHead")
	end 
	local frame = TalkingHeadFrame
	if (self.db.enableTalkingHead) then 
		if (frame) then 
			self:EnableUIWidget("TalkingHead")
			self:HandleTalkingHeadFrame()
		else
			-- If the head hasn't been loaded yet, we queue the event.
			return self:RegisterEvent("ADDON_LOADED", "UpdateTalkingHead")
		end
	else
		if (frame) then 
			self:DisableUIWidget("TalkingHead")
		else
			-- If no frame is found, the addon hasn't been loaded yet,
			-- and it should have been enough to just prevent blizzard from showing it.
			UIParent:UnregisterEvent("TALKINGHEAD_REQUESTED")
			-- Since other addons might load it contrary to our settings, though,
			-- we register our addon listener to take control of it when it's loaded.
			return self:RegisterEvent("ADDON_LOADED", "UpdateTalkingHead")
		end
	end
end

Module.UpdateAnnouncements = function(self, event, ...)
	if (self.db.enableAnnouncements) then
		self:EnableUIWidget("Banners")
		self:EnableUIWidget("BossBanners")
		self:EnableUIWidget("LevelUpDisplay")
	else
		self:DisableUIWidget("Banners")
		self:DisableUIWidget("BossBanners")
		self:DisableUIWidget("LevelUpDisplay")
	end
end

Module.UpdateWarnings = function(self, event, ...)
	if (self.db.enableRaidBossEmotes) then
		self:EnableUIWidget("RaidBossEmotes")
	else
		self:DisableUIWidget("RaidBossEmotes")
	end
	if (self.db.enableRaidWarnings) then
		self:EnableUIWidget("RaidWarnings")
	else
		self:DisableUIWidget("RaidWarnings")
	end
end

Module.UpdateObjectivesTracker = function(self, event, ...)
	if (InCombatLockdown()) then
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateObjectivesTracker")
		return
	end
	if (event == "PLAYER_REGEN_ENABLED") then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "UpdateObjectivesTracker")
	end
	local BlizzardObjectivesTracker = Core:GetModule("BlizzardObjectivesTracker", true)
	if (BlizzardObjectivesTracker) and not(BlizzardObjectivesTracker:IsIncompatible() or BlizzardObjectivesTracker:DependencyFailed()) then
		local frame = BlizzardObjectivesTracker.frame
		if (frame) then
			if (self.db.enableObjectivesTracker) then
				if (not frame:IsShown()) then
					frame:Show()
					self:SendMessage("GP_BLIZZARD_TRACKER_SHOWN")
				end
			else
				if (frame:IsShown()) then
					frame:Hide()
					if (frame.cover) then
						frame.cover:Hide()
					end
					self:SendMessage("GP_BLIZZARD_TRACKER_HIDDEN")
				end
			end
		end
	end
end

-- Setup
----------------------------------------------------
Module.HandleAlertFrames = function(self)
	local layout = self.layout
	local alertFrame = AlertFrame
	local lootFrame = GroupLootContainer

	GetHolder(alertFrame, unpack(layout.AlertFramesPlace)):SetSize(unpack(layout.AlertFramesSize))

	lootFrame.ignoreFramePositionManager = true
	alertFrame.ignoreFramePositionManager = true

	UIPARENT_MANAGED_FRAME_POSITIONS["GroupLootContainer"] = nil

	for _,subSystem in ipairs(alertFrame.alertFrameSubSystems) do
		AlertSubSystem_AdjustPosition(alertFrame, subSystem)
	end

	-- Only ever do this once
	if (not FrameCache[alertFrame]) then 
		hooksecurefunc(alertFrame, "AddAlertFrameSubSystem", AlertSubSystem_AdjustPosition) -- catch stuff made by other addons too.
		hooksecurefunc(alertFrame, "UpdateAnchors", AlertFrame_PostUpdateAnchors)
		hooksecurefunc("GroupLootContainer_Update", GroupLootContainer_PostUpdate)
		FrameCache[alertFrame] = true
	end
end

Module.HandleBelowMinimapWidgets = function(self)

	local tcHolder = self:CreateFrame("Frame", nil, "UICenter")
	tcHolder:SetPoint("TOP", 0, 0)
	tcHolder:SetSize(10, 58)

	local tcContainer = UIWidgetTopCenterContainerFrame
	tcContainer:SetParent(tcHolder)
	tcContainer:ClearAllPoints()
	tcContainer:SetPoint("TOP", tcHolder)

	hooksecurefunc(tcContainer, "SetPoint", function(self, _, anchor)
		if (anchor) and (anchor ~= tcHolder) then
			self:SetParent(tcHolder)
			self:ClearAllPoints()
			self:SetPoint("TOP", tcHolder)
		end
	end)

	local layoutID = Private.GetLayoutID()

	local bmHolder = self:CreateFrame("Frame", nil, "UICenter")
	bmHolder:SetSize(128, 40)

	-- Not sure where I can test this.
	-- Hellfire Peninsula Capture Bars maybe?
	if (layoutID == "Azerite") then
		bmHolder:Place("BOTTOM", "Minimap", "TOP", 4, 60)
	elseif (layoutID == "Legacy") then
		bmHolder:Place("TOP", "Minimap", "BOTTOM", 4, -60)
	end

	-- Note: Hide quest tracker when this is visible!
	local bmContainer = UIWidgetBelowMinimapContainerFrame
	bmContainer:ClearAllPoints()
	bmContainer:SetPoint("BOTTOM", bmHolder, "BOTTOM")

	hooksecurefunc(bmContainer, "SetPoint", function(self, _, anchor)
		if (anchor) and (anchor ~= bmHolder) then
			local point = (layoutID == "Azerite") and "BOTTOM" or "TOP" 
			self:SetParent(bmHolder)
			self:ClearAllPoints()
			self:SetPoint(point, bmHolder, point)
		end
	end)
end

Module.HandleErrorFrame = function(self)
	local frame = UIErrorsFrame
	frame:SetFrameStrata("LOW")
	frame:SetHeight(20)
	frame:SetAlpha(.75)
	frame:UnregisterEvent("UI_ERROR_MESSAGE")
	frame:UnregisterEvent("UI_INFO_MESSAGE")
	frame:SetFontObject(GetFont(16,true))
	frame:SetShadowColor(0,0,0,.5)
	self.UIErrorsFrame = frame

	self:RegisterEvent("UI_ERROR_MESSAGE", "OnEvent")
	self:RegisterEvent("UI_INFO_MESSAGE", "OnEvent")
end 

Module.HandleQuestTimerFrame = function(self)
	GetHolder(QuestTimerFrame, unpack(self.layout.QuestTimerFramePlace))
	CreatePointHook(QuestTimerFrame)
end

Module.HandleTalkingHeadFrame = function(self)
	local db = self.db
	local layout = self.layout
	local frame = TalkingHeadFrame

	-- Prevent blizzard from moving this one around
	frame.ignoreFramePositionManager = true
	--frame:SetScale(.8) -- shrink it, it's too big.

	GetHolder(frame, unpack(layout.TalkingHeadFramePlace))
	CreatePointHook(frame)

	-- Iterate through all alert subsystems in order to find the one created for TalkingHeadFrame, and then remove it.
	-- We do this to prevent alerts from anchoring to this frame when it is shown.
	local AlertFrame = _G.AlertFrame
	for index, alertFrameSubSystem in ipairs(AlertFrame.alertFrameSubSystems) do
		if (alertFrameSubSystem.anchorFrame and (alertFrameSubSystem.anchorFrame == frame)) then
			table_remove(AlertFrame.alertFrameSubSystems, index)
		end
	end
	-- Only ever do this once
	if (not FrameCache[frame]) then 
		frame:HookScript("OnShow", AlertFrame_PostUpdateAnchors)
		frame:HookScript("OnHide", AlertFrame_PostUpdateAnchors)
		FrameCache[frame] = true
	end
end

Module.HandleArcheologyDigsiteProgressBar = function(self)
	local layout = self.layout
	local bar = ArcheologyDigsiteProgressBar
	if (bar) then
		GetHolder(ArcheologyDigsiteProgressBar, unpack(layout.ArcheologyDigsiteProgressBarPlace))
		CreatePointHook(ArcheologyDigsiteProgressBar)

		UIPARENT_MANAGED_FRAME_POSITIONS.ArcheologyDigsiteProgressBar = nil
	end
end

Module.HandleVehicleSeatIndicator = function(self)
	local layout = self.layout

	if (self:IsAddOnEnabled("Mappy")) then 
		VehicleSeatIndicator.Mappy_DidHook = true -- set the flag indicating its already been set up for Mappy
		VehicleSeatIndicator.Mappy_SetPoint = function() end -- kill the IsVisible reference Mappy makes
		VehicleSeatIndicator.Mappy_HookedSetPoint = function() end -- kill this too
		VehicleSeatIndicator.SetPoint = nil -- return the SetPoint method to its original metamethod
		VehicleSeatIndicator.ClearAllPoints = nil -- return the SetPoint method to its original metamethod
	end 
	
	GetHolder(VehicleSeatIndicator, unpack(layout.VehicleSeatIndicatorPlace))
	CreatePointHook(VehicleSeatIndicator)

	-- This will prevent the vehicle seat indictaor frame size from affecting other blizzard anchors,
	-- it will also prevent the blizzard frame manager from moving it at all.
	VehicleSeatIndicator.IsShown = function() return false end
end

Module.HandleWarningFrames = function(self)
	local fontSize = 20
	local frameWidth = 600

	-- The RaidWarnings have a tendency to look really weird,
	-- as the SetTextHeight method scales the text after it already
	-- has been turned into a bitmap and turned into a texture.
	-- So I'm just going to turn it off. Completely.
	for _,frameName in ipairs({"RaidWarningFrame", "RaidBossEmoteFrame"}) do
		local frame = _G[frameName]
		frame:SetAlpha(.85)
		frame:SetHeight(85) -- 512,70
		frame.timings.RAID_NOTICE_MIN_HEIGHT = fontSize
		frame.timings.RAID_NOTICE_MAX_HEIGHT = fontSize
		frame.timings.RAID_NOTICE_SCALE_UP_TIME = 0
		frame.timings.RAID_NOTICE_SCALE_DOWN_TIME = 0

		local slot1 = _G[frameName.."Slot1"]
		slot1:SetFontObject(GetFont(fontSize,true,true))
		slot1:SetShadowColor(0,0,0,.5)
		slot1:SetWidth(frameWidth) -- 800
		slot1.SetTextHeight = function() end

		local slot2 = _G[frameName.."Slot2"]
		slot2:SetFontObject(GetFont(fontSize,true,true))
		slot2:SetShadowColor(0,0,0,.5)
		slot2:SetWidth(frameWidth) -- 800
		slot2.SetTextHeight = function() end
	end

	-- Just a little in-game test for dev purposes!
	-- /run RaidNotice_AddMessage(RaidWarningFrame, "Testing how texts will be displayed with my changes! Testing how texts will be displayed with my changes!", ChatTypeInfo["RAID_WARNING"])
	-- /run RaidNotice_AddMessage(RaidBossEmoteFrame, "Testing how texts will be displayed with my changes! Testing how texts will be displayed with my changes!", ChatTypeInfo["RAID_WARNING"])
end

-- Startup & Init
----------------------------------------------------
Module.OnEvent = function(self, event, ...)
	if (event == "UI_ERROR_MESSAGE") then 
		local messageType, msg = ...
		if (not msg) or (blackList.msgTypes[messageType]) or (blackList[msg]) then 
			return 
		end 
		self.UIErrorsFrame:AddMessage(msg, 1, 0, 0, 1)

		-- Play an error sound if the appropriate cvars allows it.
		if (GetCVarBool("Sound_EnableDialog")) and (GetCVarBool("Sound_EnableErrorSpeech")) then
			self:PlayVocalErrorByMessageType(messageType)
		end

	elseif (event == "UI_INFO_MESSAGE") then 
		local messageType, msg = ...
		if (not msg) then 
			return 
		end 
		self.UIErrorsFrame:AddMessage(msg, 1, .82, 0, 1)
	end
end

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	self.db = GetConfig(self:GetName())
	self.db.enableBGSanityFilter = nil

	local OptionsMenu = Core:GetModule("OptionsMenu", true)
	if (OptionsMenu) then
		local callbackFrame = OptionsMenu:CreateCallbackFrame(self)
		callbackFrame:AssignProxyMethods("UpdateAlertFrames", "UpdateAnnouncements", "UpdateObjectivesTracker", "UpdateTalkingHead", "UpdateWarnings")
		callbackFrame:AssignSettings(self.db)
		callbackFrame:AssignCallback([=[
			if (name) then 
				name = string.lower(name); 
				if (name == "change-enabletalkinghead") then 
					self:SetAttribute("enableTalkingHead", value); 
					self:CallMethod("UpdateTalkingHead"); 

				elseif (name == "change-enablealerts") then 
					self:SetAttribute("enableAlerts", value); 
					self:CallMethod("UpdateAlertFrames"); 

				elseif (name == "change-enableannouncements") then 
					self:SetAttribute("enableAnnouncements", value); 
					self:CallMethod("UpdateAnnouncements"); 

				elseif (name == "change-enableraidwarnings") then 
					self:SetAttribute("enableRaidWarnings", value); 
					self:CallMethod("UpdateWarnings"); 

				elseif (name == "change-enableraidbossemotes") then 
					self:SetAttribute("enableRaidBossEmotes", value); 
					self:CallMethod("UpdateWarnings"); 

				elseif (name == "change-enableobjectivestracker") then 
					self:SetAttribute("enableObjectivesTracker", value); 
					self:CallMethod("UpdateObjectivesTracker"); 
				end 
			end 
		]=])
	end

end 

Module.OnEnable = function(self)
	self:HandleErrorFrame()
	self:HandleWarningFrames()
	if (IsClassic) then
		self:HandleQuestTimerFrame()
	end
	if (IsRetail) then
		if (IsAddOnLoaded("Blizzard_ArchaeologyUI")) then
			self:HandleArcheologyDigsiteProgressBar()
		else
			local fix
			fix = function(self, event, addon) 
				if (addon == "Blizzard_ArchaeologyUI") then
					self:UnregisterEvent("ADDON_LOADED", fix)	
					self:HandleArcheologyDigsiteProgressBar()
				end
			end
			self:RegisterEvent("ADDON_LOADED", fix)
		end
		self:HandleBelowMinimapWidgets()
		self:HandleVehicleSeatIndicator()
		self:UpdateAlertFrames()
		self:UpdateAnnouncements()
		self:UpdateTalkingHead()
		self:UpdateWarnings()
		self:UpdateObjectivesTracker()
	end
end
