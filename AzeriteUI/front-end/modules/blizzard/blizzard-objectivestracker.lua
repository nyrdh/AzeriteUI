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
local GetScreenHeight = GetScreenHeight
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
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout
local IsClassic = Private.IsClassic
local IsTBC = Private.IsTBC
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
	local tracker = QuestWatchFrame or ObjectiveTrackerFrame

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
-- Classic
-----------------------------------------------------------------
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
	local layout = self.layout
	local scaffold = self:CreateFrame("Frame", nil, MinimapCluster) -- "UICenter"
	scaffold:SetWidth(layout.Width)
	scaffold:SetHeight(22)
	scaffold:Place(unpack(layout.Place))
	
	QuestWatchFrame:SetMovable(true)
	QuestWatchFrame:SetUserPlaced(true)
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

-- 
-- 3/30 17:43:34.063  Global variable OBJECTIVE_TRACKER_UPDATE_REASON tainted by AzeriteUI - -- Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_ObjectiveTracker.lua:1345
-- 3/30 17:43:34.063      ObjectiveTracker_Update()
-- 3/30 17:43:34.063      Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_BonusObjectiveTracker.lua:917 callback()
-- 3/30 17:43:34.063      Interface\SharedXML\C_TimerAugment.lua:16
-- 3/30 17:43:34.063  Execution tainted by AzeriteUI while reading OBJECTIVE_TRACKER_UPDATE_REASON - -- Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_ObjectiveTracker.lua:1368
-- 3/30 17:43:34.063      ObjectiveTracker_Update()
-- 3/30 17:43:34.063      Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_BonusObjectiveTracker.lua:917 callback()
-- 3/30 17:43:34.063      Interface\SharedXML\C_TimerAugment.lua:16
-- 3/30 17:43:34.063  An action was blocked because of taint from AzeriteUI - UseQuestLogSpecialItem()
-- 3/30 17:43:34.063      Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_ObjectiveTrackerShared.lua:95
-- 3/30 17:44:04.016  Execution tainted by AzeriteUI while reading text - Interface\FrameXML\QuestUtils.lua:454 QuestUtils_AddQuestRewardsToTooltip()
-- 3/30 17:44:04.016      Interface\FrameXML\GameTooltip.lua:197 GameTooltip_AddQuestRewardsToTooltip()
-- 3/30 17:44:04.016      Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_BonusObjectiveTracker.lua:504 BonusObjectiveTracker_ShowRewardsTooltip()
-- 3/30 17:44:04.016      Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_BonusObjectiveTracker.lua:140
-- 3/30 17:44:04.016  An action was blocked because of taint from AzeriteUI - UseQuestLogSpecialItem()
-- 3/30 17:44:04.016      Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_ObjectiveTrackerShared.lua:95
-- 3/30 17:44:06.812  Execution tainted by AzeriteUI while reading text - Interface\FrameXML\QuestUtils.lua:454 QuestUtils_AddQuestRewardsToTooltip()
-- 3/30 17:44:06.812      Interface\FrameXML\GameTooltip.lua:197 GameTooltip_AddQuestRewardsToTooltip()
-- 3/30 17:44:06.812      Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_BonusObjectiveTracker.lua:504 BonusObjectiveTracker_ShowRewardsTooltip()
-- 3/30 17:44:06.812      Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_BonusObjectiveTracker.lua:140
-- 3/30 17:44:06.812  An action was blocked because of taint from AzeriteUI - UseQuestLogSpecialItem()
-- 3/30 17:44:06.812      Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_ObjectiveTrackerShared.lua:95
-- 
local secured = {}
Module.SecureItemButton = function(self, ...)
	--if InCombatLockdown() then 
	--	return 
	--end

	local block = ...
	if (not block) then 
		return
	end

	-- These are used for the quest rewards tooltip, 
	-- which is what apparently is tainted by the global variable 'text'
	-- being used somewhere no searches of mine have yet discovered.
	-- Trying to avoid calling these in combat for now, to see if that helps.
	-- The alternative is to rewrite the entire script handler, 
	-- create one not referencing any secure items at all, 
	-- and even replace the tooltips with ours. Might be best?
	if (not secured[block]) then
		block:SetScript("OnEnter", function(block) 
			if (not InCombatLockdown()) then
				BonusObjectiveTracker_OnBlockEnter(block)
			end
		end)

		-- For reasons unknown, setting OnEnter appears to clear out OnLeave?
		block:SetScript("OnLeave", BonusObjectiveTracker_OnBlockLeave)

		-- Don't do this again.
		secured[block] = true
	end

	-- These are the item button tooltips.
	-- Not strictly certain if I need to hide these too. 
	-- Taint tracking with no clear reference points isn't exactly an exact science.
	-- The below is probably NOT caused by the listed addon, 
	-- as the method listed is called by the same scripts we're trying to untaint below.
	-- 
	-- 4/21 10:48:29.010  An action was blocked because of taint from MapShrinker - UseQuestLogSpecialItem()
	-- 4/21 10:48:29.010      Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_ObjectiveTrackerShared.lua:95
	-- 4/21 10:48:33.892  An action was blocked because of taint from MapShrinker - UseQuestLogSpecialItem()
	-- 4/21 10:48:33.892      Interface\AddOns\Blizzard_ObjectiveTracker\Blizzard_ObjectiveTrackerShared.lua:95
	-- 
	local item = block.itemButton
	if (not item) then 
		return 
	end
	if (not secured[item]) then
		item:SetScript("OnEnter", function(item) 
			if (not InCombatLockdown()) then
				QuestObjectiveItem_OnEnter(item)
			end
		end)
		secured[item] = true
	end

end

Module.InitRetailTracker = function(self)
	local layout = self.layout

	if (ObjectiveTracker_Update) then
		hooksecurefunc("ObjectiveTracker_Update", function(...) self:StyleRetailTracker(...) end)
	end

	-- Let's attempt to work around the quest item taints.
	if (QuestObjectiveSetupBlockButton_Item) then
		hooksecurefunc("QuestObjectiveSetupBlockButton_Item", function(...) self:SecureItemButton(...) end)
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

	-- We have limited room, let's find out how much!
	local UICenter = self:GetFrame("UICenter")
	local top = ObjectiveTrackerFrame:GetTop() or 0
	local screenHeight = UICenter:GetHeight() -- need to use our parenting frame's height instead.
	local maxHeight = screenHeight - (layout.SpaceBottom + layout.SpaceTop)
	local objectiveFrameHeight = math_min(maxHeight, layout.MaxHeight)
	--local newScale = (layout.Scale or 1) / ((UIParent:GetScale() or 1)/(UICenter:GetScale() or 1))

	-- Might need to hook all this to uiscaling changes.
	ObjectiveTrackerFrame:SetIgnoreParentScale(true)
	--if (layout.Scale) then 
		ObjectiveTrackerFrame:SetScale(768/1080 * (layout.Scale or 1))
		--ObjectiveTrackerFrame:SetScale(newScale)
		ObjectiveTrackerFrame:SetHeight(objectiveFrameHeight / (layout.Scale or 1))
	--else
		--ObjectiveTrackerFrame:SetScale(768/1080)
		--ObjectiveTrackerFrame:SetScale(1)
		--ObjectiveTrackerFrame:SetHeight(objectiveFrameHeight)
	--end	

	-- This seems to prevent a lot of blizz crap from happening.
	ObjectiveTrackerFrame.IsUserPlaced = function() return true end
	
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
end 
