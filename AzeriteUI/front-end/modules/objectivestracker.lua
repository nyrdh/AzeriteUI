local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local L = Wheel("LibLocale"):GetLocale(ADDON)
local Module = Core:NewModule("BlizzardObjectivesTracker", "LibMessage", "LibEvent", "LibFrame", "LibClientBuild", "LibBlizzard")

-- Lua API
local _G = _G
local math_min = math.min
local string_gsub = string.gsub
local string_match = string.match

-- WoW API
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local RegisterAttributeDriver = RegisterAttributeDriver
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local GetNumQuestLogEntries = GetNumQuestLogEntries
local GetNumQuestWatches = GetNumQuestWatches
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetQuestGreenRange = GetQuestGreenRange
local GetQuestIndexForWatch = GetQuestIndexForWatch
local GetQuestLogLeaderBoard = GetQuestLogLeaderBoard
local GetQuestLogSelection = GetQuestLogSelection
local GetQuestLogTitle = GetQuestLogTitle
local GetScreenHeight = GetScreenHeight
local IsQuestWatched = IsQuestWatched
local IsUnitOnQuest = IsUnitOnQuest

-- WoW Globals
local ObjectiveTrackerFrame = ObjectiveTrackerFrame
local ObjectiveTrackerFrameHeaderMenuMinimizeButton = ObjectiveTrackerFrame.HeaderMenu.MinimizeButton
local SCENARIO_CONTENT_TRACKER_MODULE = SCENARIO_CONTENT_TRACKER_MODULE
local QUEST_TRACKER_MODULE = QUEST_TRACKER_MODULE
local WORLD_QUEST_TRACKER_MODULE = WORLD_QUEST_TRACKER_MODULE
local DEFAULT_OBJECTIVE_TRACKER_MODULE = DEFAULT_OBJECTIVE_TRACKER_MODULE
local BONUS_OBJECTIVE_TRACKER_MODULE = BONUS_OBJECTIVE_TRACKER_MODULE
local SCENARIO_TRACKER_MODULE = SCENARIO_TRACKER_MODULE

-- Private API
local Colors = Private.Colors
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout

-- Constants for client version
local IsClassic = Module:IsClassic()
local IsRetail = Module:IsRetail()

-----------------------------------------------------------------
-- Utility
-----------------------------------------------------------------
-- Returns the correct difficulty color compared to the player
local GetQuestDifficultyColor = function(level, playerLevel)
	level = level - (playerLevel or UnitLevel("player"))
	if (level > 4) then
		return Colors.quest.red
	elseif (level > 2) then
		return Colors.quest.orange
	elseif (level >= -2) then
		return Colors.quest.yellow
	elseif (level >= -GetQuestGreenRange()) then
		return Colors.quest.green
	else
		return Colors.quest.gray
	end
end

-----------------------------------------------------------------
-- Anchor Template (Retail)
-----------------------------------------------------------------
local USE_OBJECTIVES_TRACKER_CODE_V2 = true
local BAGS_SHOWN, IMMERSION_SHOWN

local ObjectiveTracker = Module:CreateFrame("Frame", nil, "UICenter")

ObjectiveTracker.Disable = function(self)
	ObjectiveTrackerFrameHeaderMenuMinimizeButton:Hide()
end

ObjectiveTracker.Toggle = function(self)
	if (ObjectiveTrackerFrame:IsVisible()) then
		ObjectiveTrackerFrame:Hide()
	else
		ObjectiveTrackerFrame:Show()
	end
end

ObjectiveTracker.OnClick = function(self)
	if (ObjectiveTrackerFrame:IsVisible()) then
		ObjectiveTrackerFrame:Hide()
	else
		ObjectiveTrackerFrame:Show()
	end
end

ObjectiveTracker.SetDefaultPosition = function(self)
	local layout = Module.layout

	local ObjectiveFrameHolder = Module:CreateFrame("Frame", "AzeriteUI_ObjectiveTracker", "UICenter")
	ObjectiveFrameHolder:SetSize(layout.WidthV2, 22)
	ObjectiveFrameHolder:Place(unpack(layout.PlaceV2))

	ObjectiveTrackerFrame:ClearAllPoints()
	ObjectiveTrackerFrame:SetPoint("TOP", ObjectiveFrameHolder)

	local uiCenter = Module:GetFrame("UICenter")
	local top = ObjectiveTrackerFrame:GetTop() or 0
	local screenHeight = uiCenter:GetHeight() -- need to use our parenting frame's height instead.
	local maxHeight = screenHeight - (layout.SpaceBottom + layout.SpaceTop)
	local objectiveFrameHeight = math_min(maxHeight, layout.MaxHeight)
	local newScale = (layout.Scale or 1) / ((UIParent:GetScale() or 1)/(uiCenter:GetScale() or 1))

	if (layout.Scale) then 
		ObjectiveTrackerFrame:SetScale(newScale)
		ObjectiveTrackerFrame:SetHeight(objectiveFrameHeight / newScale)
	else
		ObjectiveTrackerFrame:SetScale(1)
		ObjectiveTrackerFrame:SetHeight(objectiveFrameHeight)
	end	

	ObjectiveTrackerFrame.IsUserPlaced = function() return true end

end

ObjectiveTracker.Style = function()
	local frame = ObjectiveTrackerFrame.MODULES
	if (frame) then
		for i = 1, #frame do
			local modules = frame[i]
			if (modules) then
				local header = modules.Header
				local background = modules.Header.Background
				background:SetAtlas(nil)
			end
		end
	end
end

ObjectiveTracker.AddHooks = function(self)
	hooksecurefunc("ObjectiveTracker_Update", self.Style)
end

ObjectiveTracker.Enable = function(self)
	self:AddHooks()
	self:Disable()
	self:SetDefaultPosition()
	
	-- Add a keybind for toggling (SHIFT-O)
	self.ToggleButton = Module:CreateFrame("Button", "AzeriteUI_ObjectiveTrackerToggleButton", "UICenter", "SecureActionButtonTemplate")
	self.ToggleButton:SetScript("OnClick", self.Toggle)

	SetOverrideBindingClick(self.ToggleButton, true, "SHIFT-O", "AzeriteUI_ObjectiveTrackerToggleButton")
end


local ObjectiveCover = ObjectiveTracker:CreateFrame("Frame")
ObjectiveCover:SetAllPoints()
ObjectiveCover:EnableMouse(true)
ObjectiveCover:Hide()

local ObjectiveAlphaDriver = Module:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")

ObjectiveAlphaDriver.Update = function(this)
	local tracker = QuestWatchFrame or ObjectiveTrackerFrame
	local hiddenBydriver = tracker and (not this:IsShown())

	local shouldHide = IMMERSION_SHOWN or BAGS_SHOWN or (hiddenBydriver and tracker)
	if (shouldHide) then
		tracker:SetIgnoreParentAlpha(false)
		ObjectiveTracker:SetAlpha(0)
		
		ObjectiveCover:SetFrameStrata(tracker:GetFrameStrata())
		ObjectiveCover:SetFrameLevel(tracker:GetFrameLevel() + 5)
		ObjectiveCover:ClearAllPoints()
		ObjectiveCover:SetAllPoints(tracker)
		ObjectiveCover:SetHitRectInsets(-40, -80, -40, 40)
		ObjectiveCover:Show()
	else
		if (tracker) then
			tracker:SetIgnoreParentAlpha(false)
		end
		ObjectiveTracker:SetAlpha(.9)
		ObjectiveCover:Hide()
	end
end

-----------------------------------------------------------------
-- Callbacks
-----------------------------------------------------------------
local QuestLogTitleButton_OnEnter = function(self)
	self.Text:SetTextColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3])
	_G[self:GetName().."Tag"]:SetTextColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3])
end

local QuestLogTitleButton_OnLeave = function(self)
	self.Text:SetTextColor(self.r, self.g, self.b)
	_G[self:GetName().."Tag"]:SetTextColor(self.r, self.g, self.b)
end

local QuestLog_Update = function(self)
	local numEntries, numQuests = GetNumQuestLogEntries()

	local questIndex, questLogTitle, questTitleTag, questNumGroupMates, questNormalText, questHighlight, questCheck
	local questLogTitleText, level, questTag, isHeader, isCollapsed, isComplete, color
	local numPartyMembers, partyMembersOnQuest, tempWidth, textWidth

	for i = 1,QUESTS_DISPLAYED do
		questIndex = i + FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
		questLogTitle = _G["QuestLogTitle"..i]
		questTitleTag = _G["QuestLogTitle"..i.."Tag"]
		questNumGroupMates = _G["QuestLogTitle"..i.."GroupMates"]
		questCheck = _G["QuestLogTitle"..i.."Check"]
		questNormalText = _G["QuestLogTitle"..i.."NormalText"]
		questHighlight = _G["QuestLogTitle"..i.."Highlight"]

		if (questIndex <= numEntries) then
			local questLogTitleText, level, questTag, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling = GetQuestLogTitle(questIndex)

			if (not isHeader) then 
				local msg = " "..questLogTitleText
				if (level) then 
					msg = "[" .. level .. "]" .. msg
				end 
				questLogTitle:SetText(msg)

				--Set Dummy text to get text width *SUPER HACK*
				QuestLogDummyText:SetText(msg)

				-- If not a header see if any nearby group mates are on this quest
				partyMembersOnQuest = 0
				for j=1, GetNumSubgroupMembers() do
					if (IsUnitOnQuest(questIndex, "party"..j) ) then
						partyMembersOnQuest = partyMembersOnQuest + 1
					end
				end
				if ( partyMembersOnQuest > 0 ) then
					questNumGroupMates:SetText("["..partyMembersOnQuest.."]")
				else
					questNumGroupMates:SetText("")
				end
			end

			-- Set the quest tag
			if ( isComplete and isComplete < 0 ) then
				questTag = FAILED
			elseif ( isComplete and isComplete > 0 ) then
				questTag = COMPLETE
			end
			if ( questTag ) then
				questTitleTag:SetText("("..questTag..")")
				-- Shrink text to accomdate quest tags without wrapping
				tempWidth = 275 - 15 - questTitleTag:GetWidth()
				
				if ( QuestLogDummyText:GetWidth() > tempWidth ) then
					textWidth = tempWidth
				else
					textWidth = QuestLogDummyText:GetWidth()
				end
				
				questNormalText:SetWidth(tempWidth)
				
				-- If there's quest tag position check accordingly
				questCheck:Hide()
				if ( IsQuestWatched(questIndex) ) then
					if ( questNormalText:GetWidth() + 24 < 275 ) then
						questCheck:SetPoint("LEFT", questLogTitle, "LEFT", textWidth+24, 0)
					else
						questCheck:SetPoint("LEFT", questLogTitle, "LEFT", textWidth+10, 0)
					end
					questCheck:Show()
				end
			else
				questTitleTag:SetText("")
				-- Reset to max text width
				if ( questNormalText:GetWidth() > 275 ) then
					questNormalText:SetWidth(260);
				end

				-- Show check if quest is being watched
				questCheck:Hide()
				if (IsQuestWatched(questIndex)) then
					if (questNormalText:GetWidth() + 24 < 275) then
						questCheck:SetPoint("LEFT", questLogTitle, "LEFT", QuestLogDummyText:GetWidth()+24, 0)
					else
						questCheck:SetPoint("LEFT", questNormalText, "LEFT", questNormalText:GetWidth(), 0)
					end
					questCheck:Show()
				end
			end

			-- Color the quest title and highlight according to the difficulty level
			local playerLevel = UnitLevel("player")
			if ( isHeader ) then
				color = Colors.offwhite
			else
				color = GetQuestDifficultyColor(level, playerLevel)
			end

			local r, g, b = color[1], color[2], color[3]
			if (QuestLogFrame.selectedButtonID and GetQuestLogSelection() == questIndex) then
				r, g, b = Colors.highlight[1], Colors.highlight[2], Colors.highlight[3]
			end

			questLogTitle.r, questLogTitle.g, questLogTitle.b = r, g, b
			questLogTitle:SetNormalFontObject(GetFont(12))
			questTitleTag:SetTextColor(r, g, b)
			questLogTitle.Text:SetTextColor(r, g, b)
			questNumGroupMates:SetTextColor(r, g, b)

		end
	end
end

-----------------------------------------------------------------
-- Styling
-----------------------------------------------------------------
Module.StyleClassicLog = function(self)
	if (not IsClassic) then
		return
	end
	-- Just hook the global functions as far as possible
	hooksecurefunc("QuestLog_Update", QuestLog_Update)
	hooksecurefunc("QuestLogTitleButton_OnEnter", QuestLogTitleButton_OnEnter)
	-- These are defined directly in FrameXML
	local i = 1 
	while (_G["QuestLogTitle"..i]) do 
		_G["QuestLogTitle"..i]:HookScript("OnLeave", QuestLogTitleButton_OnLeave)
		i = i + 1
	end
end

Module.StyleClassicTracker = function(self)
	if (not IsClassic) then
		return
	end
	local layout = self.layout
	local scaffold = self:CreateFrame("Frame", nil, "UICenter")
	scaffold:SetWidth(layout.Width)
	scaffold:SetHeight(22)
	scaffold:Place(unpack(layout.Place))
	
	QuestWatchFrame:SetParent(self.frame)
	QuestWatchFrame:ClearAllPoints()
	QuestWatchFrame:SetPoint("BOTTOMRIGHT", scaffold, "BOTTOMRIGHT")

	-- Create a dummy frame to cover the tracker  
	-- to block mouse input when it's faded out. 
	local mouseKiller = self:CreateFrame("Frame", nil, "UICenter")
	mouseKiller:SetParent(scaffold)
	mouseKiller:SetFrameLevel(QuestWatchFrame:GetFrameLevel() + 5)
	mouseKiller:SetAllPoints()
	mouseKiller:EnableMouse(true)
	mouseKiller:Hide()

	-- Minihack to fix mouseover fading
	self.frame:ClearAllPoints()
	self.frame:SetAllPoints(QuestWatchFrame)
	self.frame.holder = scaffold
	self.frame.cover = mouseKiller

	-- GetScreenHeight() -- this is relative to uiscale: screenHeight * uiScale = 768
	local top = QuestWatchFrame:GetTop() or 0
	local bottom = QuestWatchFrame:GetBottom() or 0
	local screenHeight = self:GetFrame("UICenter"):GetHeight() -- need to use our parenting frame's height instead.
	local maxHeight = screenHeight - (layout.SpaceBottom + layout.SpaceTop)
	local objectiveFrameHeight = math_min(maxHeight, layout.MaxHeight)

	QuestWatchFrame:SetScale(layout.Scale or 1)
	QuestWatchFrame:SetWidth(layout.Width / (layout.Scale or 1))
	QuestWatchFrame:SetHeight(objectiveFrameHeight / (layout.Scale or 1))
	QuestWatchFrame:SetClampedToScreen(false)
	QuestWatchFrame:SetAlpha(.9)

	local QuestWatchFrame_SetPosition = function(_,_, parent)
		if (parent ~= scaffold) then
			QuestWatchFrame:ClearAllPoints()
			QuestWatchFrame:SetPoint("BOTTOMRIGHT", scaffold, "BOTTOMRIGHT")
		end
	end
	hooksecurefunc(QuestWatchFrame,"SetPoint", QuestWatchFrame_SetPosition)

	local dummyLine = QuestWatchFrame:CreateFontString()
	dummyLine:SetFontObject(layout.FontObject)
	dummyLine:SetWidth(layout.Width)
	dummyLine:SetJustifyH("RIGHT")
	dummyLine:SetJustifyV("BOTTOM") 
	dummyLine:SetIndentedWordWrap(false)
	dummyLine:SetWordWrap(true)
	dummyLine:SetNonSpaceWrap(false)
	dummyLine:SetSpacing(0)

	QuestWatchQuestName:ClearAllPoints()
	QuestWatchQuestName:SetPoint("TOPRIGHT", QuestWatchFrame, "TOPRIGHT", 0, 0)

	-- Hook line styling
	hooksecurefunc("QuestWatch_Update", function() 
		local questIndex
		local numObjectives
		local watchText
		local watchTextIndex = 1
		local objectivesCompleted
		local text, type, finished

		for i = 1, GetNumQuestWatches() do
			questIndex = GetQuestIndexForWatch(i)
			if (questIndex) then
				numObjectives = GetNumQuestLeaderBoards(questIndex)
				if (numObjectives > 0) then
					-- Set quest title
					watchText = _G["QuestWatchLine"..watchTextIndex]
					watchText.isTitle = true

					-- Kill trailing nonsense
					text = watchText:GetText() or ""
					text = string_gsub(text, "%.$", "") 
					text = string_gsub(text, "%?$", "") 
					text = string_gsub(text, "%!$", "") 
					watchText:SetText(text)
					
					-- Align the quest title better
					if (watchTextIndex == 1) then
						watchText:ClearAllPoints()
						watchText:SetPoint("TOPRIGHT", QuestWatchQuestName, "TOPRIGHT", 0, -4)
					else
						watchText:ClearAllPoints()
						watchText:SetPoint("TOPRIGHT", _G["QuestWatchLine"..(watchTextIndex - 1)], "BOTTOMRIGHT", 0, -10)
					end
					watchTextIndex = watchTextIndex + 1

					-- Style the objectives
					objectivesCompleted = 0
					for j = 1, numObjectives do

						-- Set Objective text
						text, type, finished = GetQuestLogLeaderBoard(j, questIndex)
						watchText = _G["QuestWatchLine"..watchTextIndex]
						watchText.isTitle = nil

						-- Kill trailing nonsense
						text = string_gsub(text, "%.$", "") 
						text = string_gsub(text, "%?$", "") 
						text = string_gsub(text, "%!$", "") 

						local objectiveText, minCount, maxCount = string_match(text, "(.+): (%d+)/(%d+)")
						if (objectiveText and minCount and maxCount) then 
							minCount = tonumber(minCount)
							maxCount = tonumber(maxCount)
							if (minCount and maxCount) then 
								if (minCount == maxCount) then 
									text = Colors.quest.green.colorCode .. minCount .. "/" .. maxCount .. "|r " .. objectiveText
								elseif (maxCount > 0) and (minCount/maxCount >= 2/3 ) then 
									text = Colors.quest.yellow.colorCode .. minCount .. "/" .. maxCount .. "|r " .. objectiveText
								elseif (maxCount > 0) and (minCount/maxCount >= 1/3 ) then 
									text = Colors.quest.orange.colorCode .. minCount .. "/" .. maxCount .. "|r " .. objectiveText
								else 
									text = Colors.quest.red.colorCode .. minCount .. "/" .. maxCount .. "|r " .. objectiveText
								end 
							end 
						end 
						watchText:SetText(text)

						-- Color the objectives
						if (finished) then
							watchText:SetTextColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3])
							objectivesCompleted = objectivesCompleted + 1
						else
							watchText:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
						end

						watchText:ClearAllPoints()
						watchText:SetPoint("TOPRIGHT", "QuestWatchLine"..(watchTextIndex - 1), "BOTTOMRIGHT", 0, -4)

						--watchText:Show()

						watchTextIndex = watchTextIndex + 1
					end

					-- Brighten the quest title if all the quest objectives were met
					watchText = _G["QuestWatchLine"..(watchTextIndex - numObjectives - 1)]
					if ( objectivesCompleted == numObjectives ) then
						watchText:SetTextColor(Colors.title[1], Colors.title[2], Colors.title[3])
					else
						watchText:SetTextColor(Colors.title[1]*.75, Colors.title[2]*.75, Colors.title[3]*.75)
					end

				end 
			end 
		end 

		local top, bottom

		local lineID = 1
		local line = _G["QuestWatchLine"..lineID]
		top = line:GetTop()

		while line do 
			if (line:IsShown()) then 
				line:SetShadowOffset(0,0)
				line:SetShadowColor(0,0,0,0)
				line:SetFontObject(line.isTitle and layout.FontObjectTitle or layout.FontObject)
				local _,size = line:GetFont()
				local spacing = size*.2 - size*.2%1

				line:SetJustifyH("RIGHT")
				line:SetJustifyV("BOTTOM") 
				line:SetIndentedWordWrap(false)
				line:SetWordWrap(true)
				line:SetNonSpaceWrap(false)
				line:SetSpacing(spacing)

				dummyLine:SetFontObject(line:GetFontObject())
				dummyLine:SetText(line:GetText() or "")
				dummyLine:SetSpacing(spacing)

				line:SetWidth(layout.Width)
				line:SetHeight(dummyLine:GetHeight())

				bottom = line:GetBottom()
			end 

			lineID = lineID + 1
			line = _G["QuestWatchLine"..lineID]
		end

		-- Avoid a nil bug that sometimes can happen with no objectives tracked, 
		-- in weird circumstances I have been unable to reproduce. 
		if (top and bottom) then 
			QuestWatchFrame:SetHeight(top - bottom)
		end

	end)
end

Module.StyleRetailTracker = function(self)
	if (not IsRetail) then
		return
	end
	if (ObjectiveTracker_Update) then 
		hooksecurefunc("ObjectiveTracker_Update", ObjectiveTracker.Style)
	end
end

Module.InitRetailTracker = function(self)
	if (USE_OBJECTIVES_TRACKER_CODE_V2) then 
		return self:InitTracker()
	end

	if (not IsRetail) then
		return
	end
	if (not ObjectiveTrackerFrame) then 
		return self:RegisterEvent("ADDON_LOADED", "OnEvent")
	end

	local layout = self.layout
	local ObjectiveFrameHolder = self:CreateFrame("Frame", nil, "UICenter")
	ObjectiveFrameHolder:SetWidth(layout.Width)
	ObjectiveFrameHolder:SetHeight(22)
	ObjectiveFrameHolder:Place(unpack(layout.Place))
	self.ObjectiveFrameHolder = ObjectiveFrameHolder

	-- Create a dummy frame to cover the tracker  
	-- to block mouse input when it's faded out. 
	local ObjectiveFrameCover = self:CreateFrame("Frame", nil, "UICenter")
	ObjectiveFrameCover:SetParent(self.ObjectiveFrameHolder)
	ObjectiveFrameCover:SetAllPoints()
	ObjectiveFrameCover:EnableMouse(true)
	ObjectiveFrameCover:Hide()
	self.ObjectiveFrameCover = ObjectiveFrameCover

	-- Minihack to fix mouseover fading
	self.frame.holder = self.ObjectiveFrameHolder
	self.frame.cover = self.ObjectiveFrameCover

	-- GetScreenHeight() -- this is relative to uiscale: screenHeight * uiScale = 768
	local top = ObjectiveTrackerFrame:GetTop() or 0
	local screenHeight = self:GetFrame("UICenter"):GetHeight() -- need to use our parenting frame's height instead.
	local maxHeight = screenHeight - (layout.SpaceBottom + layout.SpaceTop)
	local objectiveFrameHeight = math_min(maxHeight, layout.MaxHeight)

	if (layout.Scale) then 
		ObjectiveTrackerFrame:SetScale(layout.Scale)
		ObjectiveTrackerFrame:SetWidth(layout.Width / layout.Scale)
		ObjectiveTrackerFrame:SetHeight(objectiveFrameHeight / layout.Scale)
	else
		ObjectiveTrackerFrame:SetScale(1)
		ObjectiveTrackerFrame:SetWidth(layout.Width)
		ObjectiveTrackerFrame:SetHeight(objectiveFrameHeight)
	end	

	hooksecurefunc(ObjectiveTrackerFrame,"SetPoint", function(_, ...) self:PositionRetailTracker() end)
	hooksecurefunc(ObjectiveTrackerFrame,"SetAllPoints", function(_, ...) self:PositionRetailTracker() end)

	self:PositionRetailTracker()
	self:StyleRetailTracker()
end

Module.PositionRetailTracker = function(self, event, ...)
	if (USE_OBJECTIVES_TRACKER_CODE_V2) then
		return
	end

	if (InCombatLockdown()) then
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	end
	if (not ObjectiveTrackerFrame) then
		return
	end
	-- This sometimes happen on login, not on reloads.
	if (not self.ObjectiveFrameHolder) then
		return self:InitRetailTracker()
	end

	-- Possible taints: SetWidth, SetParent
	local _,anchor = ObjectiveTrackerFrame:GetPoint()
	if (anchor ~= self.ObjectiveFrameHolder) then
		ObjectiveTrackerFrame:SetIgnoreParentAlpha(false) -- something is altering this on first login
		ObjectiveTrackerFrame:SetClampedToScreen(false)
		ObjectiveTrackerFrame:SetMovable(true)
		ObjectiveTrackerFrame:SetUserPlaced(true)
		ObjectiveTrackerFrame:SetAlpha(.9)
		ObjectiveTrackerFrame:SetParent(self.frame)
		ObjectiveTrackerFrame:ClearAllPoints()
		ObjectiveTrackerFrame:SetPoint("TOP", self.ObjectiveFrameHolder, "TOP")
	
		self.frame:ClearAllPoints()
		self.frame:SetAllPoints(ObjectiveTrackerFrame)
		self.ObjectiveFrameCover:SetFrameLevel(ObjectiveTrackerFrame:GetFrameLevel() + 5)
		self.ObjectiveFrameHolder:Place(unpack(self.layout.Place))
	end
end

-----------------------------------------------------------------
-- New Version (Retail)
-----------------------------------------------------------------
Module.InitTracker = function(self)
	if (not ObjectiveTrackerFrame) then 
		return self:RegisterEvent("ADDON_LOADED", "OnEvent")
	end
	ObjectiveTracker:Enable()
end

-----------------------------------------------------------------
-- Startup
-----------------------------------------------------------------
-- This creates a driver frames that toggles 
-- the displayed alpha of the tracker,
-- and also covers it with a mouse enabled overlay. 
-- The driver frame does NOT toggle the actual tracker. 
Module.InitAlphaDriver = function(self)

	if (ObjectiveAlphaDriver.isHooked) then
		return
	end

	ObjectiveAlphaDriver:HookScript("OnShow", ObjectiveAlphaDriver.Update)
	ObjectiveAlphaDriver:HookScript("OnHide", ObjectiveAlphaDriver.Update)
	ObjectiveAlphaDriver:SetAttribute("_onattributechanged", [=[
		if (name == "state-vis") then
			if (value == "show") then 
				if (not self:IsShown()) then 
					self:Show(); 
				end 
			elseif (value == "hide") then 
				if (self:IsShown()) then 
					self:Hide(); 
				end 
			end 
		end
	]=])

	local driver = "hide;show"
	if (IsRetail) then 
		if (self.layout.HideInVehicles) then
			driver = "[overridebar][possessbar][shapeshift][vehicleui]"  .. driver
		end 
		if (self.layout.HideInArena) then 
			driver = "[@arena1,exists][@arena2,exists][@arena3,exists][@arena4,exists][@arena5,exists]" .. driver
		end
	end
	if (self.layout.HideInBossFights) then
		driver = "[@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists]" .. driver
	end 
	if (self.layout.HideInCombat) then
		driver = "[combat]" .. driver
	end 
	RegisterAttributeDriver(ObjectiveAlphaDriver, "state-vis", driver)

	ObjectiveAlphaDriver.isHooked = true
end

Module.OnEvent = function(self, event, ...)
	if (event == "ADDON_LOADED") then
		local addon = ...
		if (addon == "Blizzard_ObjectiveTracker") then 
			self:UnregisterEvent("ADDON_LOADED", "OnEvent")
			self:InitRetailTracker()
		end

	elseif (event == "VARIABLES_LOADED") then
		self:PositionRetailTracker()

	elseif (event == "PLAYER_REGEN_ENABLED") then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		self:PositionRetailTracker()

	elseif (event == "PLAYER_ENTERING_WORLD") then 
		local needUpdate

		if (self.queueImmersionHook) then
			local frame = ImmersionFrame
			if (frame) then
				self.queueImmersionHook = nil
				frame:HookScript("OnShow", function() 
					IMMERSION_SHOWN = true 
					if (ObjectiveAlphaDriver) then
						ObjectiveAlphaDriver:Update()
					end
				end)
				frame:HookScript("OnHide", function() 
					IMMERSION_SHOWN = nil 
					if (ObjectiveAlphaDriver) then
						ObjectiveAlphaDriver:Update()
					end
				end)
			end
		end

		local frame = ImmersionFrame
		if (frame) then
			IMMERSION_SHOWN = frame:IsShown()
			needUpdate = true
		end

		local bags = Wheel("LibModule"):GetModule("Backpacker", true)
		if (bags) then
			BAGS_SHOWN = bags:IsVisible()
			needUpdate = true
		end

		if (needUpdate) then 
			if (ObjectiveAlphaDriver) then
				ObjectiveAlphaDriver:Update()
			end
		end

	elseif (event == "GP_BAGS_HIDDEN") then
		BAGS_SHOWN = nil
		if (ObjectiveAlphaDriver) then
			ObjectiveAlphaDriver:Update()
		end

	elseif (event == "GP_BAGS_SHOWN") then
		BAGS_SHOWN = true
		if (ObjectiveAlphaDriver) then
			ObjectiveAlphaDriver:Update()
		end

	end 
end

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	if (IsClassic) then
		self.frame = self:CreateFrame("Frame", nil, "UICenter")
		self.frame:SetFrameStrata("LOW")
		self:StyleClassicLog()
		self:StyleClassicTracker()
	end

	if (IsRetail) then
		self:InitRetailTracker()
	end

	if (self:IsAddOnEnabled("Immersion")) then
		self.queueImmersionHook = true
	end

	self:RegisterEvent("VARIABLES_LOADED", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterMessage("GP_BAGS_HIDDEN", "OnEvent")
	self:RegisterMessage("GP_BAGS_SHOWN", "OnEvent")
end 

Module.OnEnable = function(self)
	self:InitAlphaDriver()
end
