local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end

local L = Wheel("LibLocale"):GetLocale(ADDON)
local Module = Core:NewModule("BlizzardObjectivesTracker", "LibMessage", "LibEvent", "LibFrame", "LibBlizzard")

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
local IsQuestWatched = IsQuestWatched
local IsUnitOnQuest = IsUnitOnQuest

-- WoW Globals
local SCENARIO_CONTENT_TRACKER_MODULE = SCENARIO_CONTENT_TRACKER_MODULE
local QUEST_TRACKER_MODULE = QUEST_TRACKER_MODULE
local WORLD_QUEST_TRACKER_MODULE = WORLD_QUEST_TRACKER_MODULE
local DEFAULT_OBJECTIVE_TRACKER_MODULE = DEFAULT_OBJECTIVE_TRACKER_MODULE
local BONUS_OBJECTIVE_TRACKER_MODULE = BONUS_OBJECTIVE_TRACKER_MODULE
local SCENARIO_TRACKER_MODULE = SCENARIO_TRACKER_MODULE

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout
local IsAnyClassic = Private.IsAnyClassic
local IsClassic = Private.IsClassic
local IsTBC = Private.IsTBC
local IsWrath = Private.IsWrath
local IsRetail = Private.IsRetail

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
-- Frames
-----------------------------------------------------------------
local ObjectiveCover = Module:CreateFrame("Frame", nil, "UICenter")
ObjectiveCover:EnableMouse(true)
ObjectiveCover:Hide()

local ObjectiveAlphaDriver = Module:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
ObjectiveAlphaDriver.Update = function()

	-- The tracker addon might not be loaded.
	local tracker = QuestWatchFrame or ObjectiveTrackerFrame or WatchFrame

	-- Check for the visibility of addons conflicting with the visuals.
	local bags = Wheel("LibModule"):GetModule("Backpacker", true)
	local bagsVisible = bags and bags:IsVisible()
	local immersionVisible = ImmersionFrame and ImmersionFrame:IsShown()

	-- Fake-hide the tracker if something is covering its area. We don't like clutter.
	local shouldHide = (tracker) and ((immersionVisible) or (bagsVisible) or (not ObjectiveAlphaDriver:IsShown()))
	if (shouldHide) then
		tracker:SetIgnoreParentAlpha(false)
		tracker:SetAlpha(0)

		ObjectiveCover:SetFrameStrata(tracker:GetFrameStrata())
		ObjectiveCover:SetFrameLevel(tracker:GetFrameLevel() + 5)
		ObjectiveCover:ClearAllPoints()
		ObjectiveCover:SetAllPoints(tracker)
		ObjectiveCover:SetHitRectInsets(-40, -80, -40, 40)
		ObjectiveCover:Show()
	else
		-- The tracker addon might not be loaded.
		if (tracker) then
			tracker:SetIgnoreParentAlpha(false)
			tracker:SetAlpha(.9)
		end
		ObjectiveCover:Hide()
	end
end

-----------------------------------------------------------------
-- Classic
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

Module.StyleClassicLog = function(self)
	if not(IsClassic or IsTBC) then
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
	if not(IsClassic or IsTBC) then
		return
	end

	local tracker = QuestWatchFrame

	local layout = self.layout
	local scaffold = self:CreateFrame("Frame", nil, MinimapCluster)
	scaffold:SetWidth(layout.Width)
	scaffold:SetHeight(22)
	scaffold:Place(unpack(layout.Place))
	self.frame.holder = scaffold

	-- Create a dummy frame to cover the tracker
	-- to block mouse input when it's faded out.
	local mouseKiller = self:CreateFrame("Frame", nil, "UICenter")
	mouseKiller:SetParent(scaffold)
	mouseKiller:SetFrameLevel(tracker:GetFrameLevel() + 5)
	mouseKiller:SetAllPoints()
	mouseKiller:EnableMouse(true)
	mouseKiller:Hide()
	self.frame.cover = mouseKiller

	-- Minihack to fix mouseover fading (we still have this?)
	self.frame:ClearAllPoints()
	self.frame:SetAllPoints(tracker)

	-- Re-position after UIParent messes with it.
	hooksecurefunc(tracker, "SetPoint", function(_,_, anchor)
		if (anchor ~= scaffold) then
			self:UpdateClassicTrackerPosition()
		end
	end)

	-- Just in case some random addon messes with it.
	hooksecurefunc(tracker, "SetAllPoints", function()
		self:UpdateClassicTrackerPosition()
	end)

	-- Try to bypass the frame cache
	self:RegisterEvent("VARIABLES_LOADED", "UpdateClassicTrackerPosition")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateClassicTrackerPosition")

	local dummyLine = tracker:CreateFontString()
	dummyLine:SetFontObject(layout.FontObject)
	dummyLine:SetWidth(layout.Width)
	dummyLine:SetJustifyH("RIGHT")
	dummyLine:SetJustifyV("BOTTOM")
	dummyLine:SetIndentedWordWrap(false)
	dummyLine:SetWordWrap(true)
	dummyLine:SetNonSpaceWrap(false)
	dummyLine:SetSpacing(0)

	local title = QuestWatchQuestName
	title:ClearAllPoints()
	title:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", 0, 0)

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
						watchText:SetPoint("TOPRIGHT", title, "TOPRIGHT", 0, -4)
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
			tracker:SetHeight(top - bottom)
		end

	end)

end

Module.UpdateClassicTrackerPosition = function(self)
	if not(QuestWatchFrame and self.frame and self.frame.holder) then
		return
	end

	local layout = self.layout
	if (not layout) then
		return
	end

	local screenHeight = self:GetFrame("UICenter"):GetHeight()
	local maxHeight = screenHeight - (layout.SpaceBottom + layout.SpaceTop)
	local objectiveFrameHeight = math_min(maxHeight, layout.MaxHeight)

	QuestWatchFrame:SetParent(self.frame)
	QuestWatchFrame:SetScale(layout.Scale or 1)
	QuestWatchFrame:SetWidth(layout.Width / (layout.Scale or 1))
	QuestWatchFrame:SetHeight(objectiveFrameHeight / (layout.Scale or 1))
	QuestWatchFrame:SetClampedToScreen(false)
	QuestWatchFrame:SetAlpha(.9)
	QuestWatchFrame:ClearAllPoints()
	QuestWatchFrame:SetPoint("BOTTOMRIGHT", self.frame.holder, "BOTTOMRIGHT", 0, 0)
end

-----------------------------------------------------------------
-- Wrath
-----------------------------------------------------------------
Module.StyleWrathTracker = function(self)
	if (not IsWrath) then
		return
	end

	local tracker = WatchFrame

	local layout = self.layout
	local scaffold = self:CreateFrame("Frame", nil, MinimapCluster)
	scaffold:SetWidth(layout.Width)
	scaffold:SetHeight(22)
	scaffold:Place(unpack(layout.Place))
	scaffold:SetIgnoreParentScale(true)
	self.frame.holder = scaffold

	-- Create a dummy frame to cover the tracker
	-- to block mouse input when it's faded out.
	local mouseKiller = self:CreateFrame("Frame", nil, "UICenter")
	mouseKiller:SetParent(scaffold)
	mouseKiller:SetFrameLevel(tracker:GetFrameLevel() + 5)
	mouseKiller:SetAllPoints()
	mouseKiller:EnableMouse(true)
	mouseKiller:Hide()
	self.frame.cover = mouseKiller

	-- Minihack to fix mouseover fading (we still have this?)
	self.frame:ClearAllPoints()
	self.frame:SetAllPoints(tracker)

	-- Re-position after UIParent messes with it.
	hooksecurefunc(tracker, "SetPoint", function(_,_, anchor)
		if (anchor ~= scaffold) then
			self:UpdateWrathTrackerPosition()
		end
	end)

	-- Just in case some random addon messes with it.
	hooksecurefunc(tracker, "SetAllPoints", function()
		self:UpdateWrathTrackerPosition()
	end)

	-- Try to bypass the frame cache
	self:RegisterEvent("VARIABLES_LOADED", "UpdateWrathTrackerPosition")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateWrathTrackerPosition")

end

Module.UpdateWrathTrackerPosition = function(self)
	if not(WatchFrame and self.frame and self.frame.holder) then
		return
	end

	local layout = self.layout
	if (not layout) then
		return
	end

	local tracker = WatchFrame

	local screenHeight = self:GetFrame("UICenter"):GetHeight()
	local maxHeight = screenHeight - (layout.SpaceBottom + layout.SpaceTop)
	local objectiveFrameHeight = math_min(maxHeight, layout.MaxHeight)

	-- Make sure the scaffold is on the right coordinates, scale affects this.
	self.frame.holder:SetIgnoreParentScale(true)
	self.frame.holder:SetScale(self:GetFrame("UICenter"):GetEffectiveScale())

	tracker:SetParent(self.frame)
	tracker:SetScale(layout.Scale or 1)
	tracker:SetWidth(layout.Width / (layout.Scale or 1))
	tracker:SetHeight(objectiveFrameHeight / (layout.Scale or 1))
	tracker:SetClampedToScreen(false)
	tracker:SetAlpha(.9)
	tracker:ClearAllPoints()
	tracker:SetPoint("TOPRIGHT", self.frame.holder, "TOPRIGHT", 0, 0)
end

-----------------------------------------------------------------
-- Retail
-----------------------------------------------------------------
local UIHider = CreateFrame("Frame")
UIHider:Hide()

Module.StyleRetailTracker = function(self, ...)
	local frame = ObjectiveTrackerFrame.MODULES
	if (frame) then
		for i = 1, #frame do
			local modules = frame[i]
			if (modules) then
				local header = modules.Header
				local background = modules.Header.Background
				--background:SetAlpha(0) -- doesn't always fire
				--background:SetAtlas(nil)
				background:SetParent(UIHider)
			end
		end
	end
end

Module.UpdateTrackerSizeAndScale = function(self)
	if (not ObjectiveTrackerFrame) then
		return
	end
	local layout = self.layout

	-- We have limited room, let's find out how much!
	local UICenter = self:GetFrame("UICenter")
	local top = ObjectiveTrackerFrame:GetTop() or 0
	local screenHeight = UICenter:GetHeight() -- need to use our parenting frame's height instead.
	local maxHeight = screenHeight - (layout.SpaceBottom + layout.SpaceTop)
	local objectiveFrameHeight = math_min(maxHeight, layout.MaxHeight)
	local scale = tonumber(GetConfig(ADDON, "global").relativeScale) or 1

	-- Might need to hook all this to uiscaling changes.
	ObjectiveTrackerFrame:SetIgnoreParentScale(true)
	ObjectiveTrackerFrame:SetScale(768/1080 * (layout.Scale or 1) * scale)
	ObjectiveTrackerFrame:SetHeight(objectiveFrameHeight / (layout.Scale or 1) * scale)

end

Module.InitRetailTracker = function(self)
	local layout = self.layout

	if (ObjectiveTracker_Update) then
		hooksecurefunc("ObjectiveTracker_Update", function(...) self:StyleRetailTracker(...) end)
	end

	-- kills this shit off. We use our keybind instead.
	ObjectiveTrackerFrame.HeaderMenu.MinimizeButton:Hide()

	local ObjectiveFrameHolder = self:CreateFrame("Frame", "AzeriteUI_ObjectiveTracker", "UICenter")
	ObjectiveFrameHolder:SetSize(235,22) -- Blizzard default width
	ObjectiveFrameHolder:Place(unpack(layout.Place))

	-- Need to use the same anchor points as blizz, or there will be taint.
	-- Note that I am not yet certain we're using taint-free methods.
	ObjectiveTrackerFrame:ClearAllPoints()
	ObjectiveTrackerFrame:SetPoint("TOP", ObjectiveFrameHolder)

	-- This seems to prevent a lot of blizz crap from happening.
	ObjectiveTrackerFrame.IsUserPlaced = function() return true end

	-- Update scale and height.
	self:UpdateTrackerSizeAndScale()

	-- Add a keybind for toggling the tracker, thanks Tukz! (SHIFT-O)
	local toggleButton = self:CreateFrame("Button", "AzeriteUI_ObjectiveTrackerToggleButton", "UICenter", "SecureActionButtonTemplate")
	toggleButton:SetScript("OnClick", function()
		if (ObjectiveTrackerFrame:IsVisible()) then
			ObjectiveTrackerFrame:Hide()
		else
			ObjectiveTrackerFrame:Show()
		end
	end)
	SetOverrideBindingClick(toggleButton, true, "SHIFT-O", "AzeriteUI_ObjectiveTrackerToggleButton")
end

-----------------------------------------------------------------
-- Startup
-----------------------------------------------------------------
-- This creates a driver frames that toggles
-- the displayed alpha of the tracker,
-- and also covers it with a mouse enabled overlay.
-- The driver frame does NOT toggle the actual tracker.
Module.InitAlphaDriver = function(self)

	if (not ObjectiveAlphaDriver.isHooked) then
		--ObjectiveAlphaDriver:HookScript("OnShow", ObjectiveAlphaDriver.Update)
		--ObjectiveAlphaDriver:HookScript("OnHide", ObjectiveAlphaDriver.Update)
		ObjectiveAlphaDriver:SetAttribute("_onattributechanged", [=[
			if (name == "state-vis") then
				if (value == "show") then
					self:Show();
					self:CallMethod("Update");

				elseif (value == "hide") then
					self:Hide();
					self:CallMethod("Update");
				end
			end
		]=])
	end

	if (ObjectiveAlphaDriver.isHooked) then
		UnregisterAttributeDriver(ObjectiveAlphaDriver, "state-vis")
	end
	local driver = "hide;show"
	if (IsRetail or IsWrath) then
		if (self.layout.HideInVehicles) then
			driver = "[overridebar][possessbar][shapeshift][vehicleui]"  .. driver
		end
	end
	if (IsRetail or IsTBC or IsWrath) then
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
			self:StyleRetailTracker()
		end

	elseif (event == "PLAYER_ENTERING_WORLD") then

		if (self.queueImmersionHook) then
			local frame = ImmersionFrame
			if (frame) then
				frame:HookScript("OnShow", ObjectiveAlphaDriver.Update)
				frame:HookScript("OnHide", ObjectiveAlphaDriver.Update)
				self.queueImmersionHook = nil
			end
		end

		ObjectiveAlphaDriver:Update()

		if (IsRetail) then
			self:StyleRetailTracker()
		end

	elseif (event == "GP_BAGS_HIDDEN") then
		ObjectiveAlphaDriver:Update()

	elseif (event == "GP_BAGS_SHOWN") then
		ObjectiveAlphaDriver:Update()

	elseif (event == "GP_RELATIVE_SCALE_UPDATED") then
		self:UpdateTrackerSizeAndScale()
	end
end

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	if (self:IsAddOnEnabled("Immersion")) then
		self.queueImmersionHook = true
	end

	if (IsClassic or IsTBC) then
		self.frame = self:CreateFrame("Frame", nil, "UICenter")
		self.frame:SetFrameStrata("LOW")
		self:StyleClassicLog()
		self:StyleClassicTracker()
	end

	if (IsWrath) then
		self.frame = self:CreateFrame("Frame", nil, "UICenter")
		self.frame:SetFrameStrata("LOW")
		self:StyleWrathTracker()
	end

	if (IsRetail) then
		if (ObjectiveTrackerFrame) then
			self:InitRetailTracker()
			self:StyleRetailTracker()
		else
			self:RegisterEvent("ADDON_LOADED", "OnEvent")
		end
	end

	self:InitAlphaDriver()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterMessage("GP_BAGS_HIDDEN", "OnEvent")
	self:RegisterMessage("GP_BAGS_SHOWN", "OnEvent")
	self:RegisterMessage("GP_RELATIVE_SCALE_UPDATED", "OnEvent")

end
