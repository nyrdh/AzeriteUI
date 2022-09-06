local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end

local LibNumbers = Wheel("LibNumbers")
assert(LibNumbers, ADDON..":BlizzardTooltips requires LibNumbers to be loaded.")

local Module = Core:NewModule("BlizzardTooltips", "LibMessage", "LibEvent", "LibDB", "LibTooltipScanner", "LibPlayerData", "LibFrame")

-- Lua API
local math_abs = math.abs
local select = select
local string_format = string.format
local type = type
local unpack = unpack

-- WoW API
local GetDetailedItemLevelInfo = GetDetailedItemLevelInfo
local GetItemInfo = GetItemInfo
local GetMouseFocus = GetMouseFocus
local GetQuestGreenRange = GetQuestGreenRange
local GetScalingQuestGreenRange = GetScalingQuestGreenRange
local IsShiftKeyDown = IsShiftKeyDown
local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitEffectiveLevel = UnitEffectiveLevel
local UnitExists = UnitExists
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsPlayer = UnitIsPlayer
local UnitIsTapDenied = UnitIsTapDenied
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel
local UnitPlayerControlled = UnitPlayerControlled
local UnitQuestTrivialLevelRange = UnitQuestTrivialLevelRange or GetQuestGreenRange
local UnitQuestTrivialLevelRangeScaling = UnitQuestTrivialLevelRangeScaling or GetScalingQuestGreenRange
local UnitReaction = UnitReaction

-- WoW Objects
local GameTooltip = GameTooltip
local GetMouseFocus = GetMouseFocus
local HealthBar = GameTooltipStatusBar
local SharedTooltip_ClearInsertedFrames = SharedTooltip_ClearInsertedFrames or GameTooltip_ClearInsertedFrames -- last one is classic
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsFriend = UnitIsFriend
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitReaction = UnitReaction

-- Private API
local Colors = Private.Colors
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout
local GetMedia = Private.GetMedia
local IsAnyClassic = Private.IsAnyClassic
local IsClassic = Private.IsClassic
local IsTBC = Private.IsTBC
local IsWrath = Private.IsWrath
local IsRetail = Private.IsRetail

-- WoW Constants
local DEAD = DEAD
local ITEM_LEVEL_ABBR = ITEM_LEVEL_ABBR
local NOT_APPLICABLE = NOT_APPLICABLE

-- Blizzard textures we use
local BLANK = "|T"..GetMedia("blank")..":14:14:-2:1|t" -- 1:1
local BOSS_TEXTURE = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:14:14:-2:1|t" -- 1:1
local FFA_TEXTURE = "|TInterface\\TargetingFrame\\UI-PVP-FFA:14:10:-2:1:64:64:6:34:0:40|t" -- 4:3
local FACTION_ALLIANCE_TEXTURE = "|TInterface\\TargetingFrame\\UI-PVP-Alliance:14:10:-2:1:64:64:6:34:0:40|t" -- 4:3
local FACTION_NEUTRAL_TEXTURE = "|TInterface\\TargetingFrame\\UI-PVP-Neutral:14:10:-2:1:64:64:6:34:0:40|t" -- 4:3
local FACTION_HORDE_TEXTURE = "|TInterface\\TargetingFrame\\UI-PVP-Horde:14:14:-4:0:64:64:0:40:0:40|t" -- 1:1

-- Number Abbreviation
local short = LibNumbers:GetNumberAbbreviationShort()
local large = LibNumbers:GetNumberAbbreviationLong()

local Backdrops, Handled = {}, {}
local UIHider = CreateFrame("Frame"); UIHider:Hide()

local SmallTooltipBackdropTemplate = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = GetMedia("better-blizzard-border-small-alternate"),
	tile = false,
	tileEdge = false,
	tileSize = nil,
	edgeSize = 32,
	insets = { left = 25, right = 25, top = 25, bottom = 25 }
}

local HealthBarBackdropTemplate = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = GetMedia("aura_border"),
	tile = false,
	tileEdge = false,
	tileSize = nil,
	edgeSize = 8,
	insets = { left = 5, right = 5, top = 5, bottom = 5 }
}

-- Returns the correct difficulty color compared to the player.
-- Using this as a tooltip method to access our custom colors.
-- *Sourced from /back-end/tooltip.lua
local GetDifficultyColorByLevel
if (IsClassic or IsTBC or IsWrath) then
	GetDifficultyColorByLevel = function(level, isScaling)
		local colors = Colors.quest
		local levelDiff = level - UnitLevel("player")
		if (isScaling) then
			if (levelDiff > 5) then
				return colors.red[1], colors.red[2], colors.red[3], colors.red.colorCode
			elseif (levelDiff > 3) then
				return colors.orange[1], colors.orange[2], colors.orange[3], colors.orange.colorCode
			elseif (levelDiff >= 0) then
				return colors.yellow[1], colors.yellow[2], colors.yellow[3], colors.yellow.colorCode
			elseif (-levelDiff <= GetScalingQuestGreenRange()) then
				return colors.green[1], colors.green[2], colors.green[3], colors.green.colorCode
			else
				return colors.gray[1], colors.gray[2], colors.gray[3], colors.gray.colorCode
			end
		else
			if (levelDiff > 5) then
				return colors.red[1], colors.red[2], colors.red[3], colors.red.colorCode
			elseif (levelDiff > 3) then
				return colors.orange[1], colors.orange[2], colors.orange[3], colors.orange.colorCode
			elseif (levelDiff >= -2) then
				return colors.yellow[1], colors.yellow[2], colors.yellow[3], colors.yellow.colorCode
			elseif (-levelDiff <= GetQuestGreenRange()) then
				return colors.green[1], colors.green[2], colors.green[3], colors.green.colorCode
			else
				return colors.gray[1], colors.gray[2], colors.gray[3], colors.gray.colorCode
			end
		end
	end
elseif (IsRetail) then
	GetDifficultyColorByLevel = function(level, isScaling)
		local colors = Colors.quest
		if (isScaling) then
			local levelDiff = level - UnitEffectiveLevel("player")
			if (levelDiff > 5) then
				return colors.red[1], colors.red[2], colors.red[3], colors.red.colorCode
			elseif (levelDiff > 3) then
				return colors.orange[1], colors.orange[2], colors.orange[3], colors.orange.colorCode
			elseif (levelDiff >= 0) then
				return colors.yellow[1], colors.yellow[2], colors.yellow[3], colors.yellow.colorCode
			elseif (-levelDiff <= -UnitQuestTrivialLevelRangeScaling("player")) then
				return colors.green[1], colors.green[2], colors.green[3], colors.green.colorCode
			else
				return colors.gray[1], colors.gray[2], colors.gray[3], colors.gray.colorCode
			end
		else
			local levelDiff = level - UnitLevel("player")
			if (levelDiff > 5) then
				return colors.red[1], colors.red[2], colors.red[3], colors.red.colorCode
			elseif (levelDiff > 3) then
				return colors.orange[1], colors.orange[2], colors.orange[3], colors.orange.colorCode
			elseif (levelDiff >= -4) then
				return colors.yellow[1], colors.yellow[2], colors.yellow[3], colors.yellow.colorCode
			elseif (-levelDiff <= -UnitQuestTrivialLevelRange("player")) then
				return colors.green[1], colors.green[2], colors.green[3], colors.green.colorCode
			else
				return colors.gray[1], colors.gray[2], colors.gray[3], colors.gray.colorCode
			end
		end
	end
end

-- Update the color of the tooltip's current unit
-- Returns the r, g, b value
local GetUnitHealthColor = function(unit, data)
	local r, g, b
	if data then
		if (data.isPet and data.petRarity) then
			r, g, b = unpack(Colors.quality[data.petRarity - 1])
		else
			if ((not UnitPlayerControlled(unit)) and UnitIsTapDenied(unit) and UnitCanAttack("player", unit)) then
				r, g, b = unpack(Colors.tapped)
			elseif (not UnitIsConnected(unit)) then
				r, g, b = unpack(Colors.disconnected)
			elseif (UnitIsDeadOrGhost(unit)) then
				r, g, b = unpack(Colors.dead)
			elseif (UnitIsPlayer(unit)) then
				local _, class = UnitClass(unit)
				if class then
					r, g, b = unpack(Colors.class[class])
				else
					r, g, b = unpack(Colors.disconnected)
				end
			elseif (UnitReaction(unit, "player")) then
				r, g, b = unpack(Colors.reaction[UnitReaction(unit, "player")])
			else
				r, g, b = 1, 1, 1
			end
		end
	else
		if ((not UnitPlayerControlled(unit)) and UnitIsTapDenied(unit) and UnitCanAttack("player", unit)) then
			r, g, b = unpack(Colors.tapped)
		elseif (not UnitIsConnected(unit)) then
			r, g, b = unpack(Colors.disconnected)
		elseif (UnitIsDeadOrGhost(unit)) then
			r, g, b = unpack(Colors.dead)
		elseif (UnitIsPlayer(unit)) then
			local _, class = UnitClass(unit)
			if class then
				r, g, b = unpack(Colors.class[class])
			else
				r, g, b = unpack(Colors.disconnected)
			end
		elseif (UnitReaction(unit, "player")) then
			r, g, b = unpack(Colors.reaction[UnitReaction(unit, "player")])
		else
			r, g, b = 1, 1, 1
		end
	end
	return r,g,b
end

local GetTooltipUnit = function(tooltip)
	local _, unit = tooltip:GetUnit()
	if (not unit) then
		local focus = GetMouseFocus()
		if (focus) and (focus.GetAttribute) then
			unit = focus:GetAttribute("unit")
		end
	end
	if (not unit) and (UnitExists("mouseover")) then
		unit = "mouseover"
	end
	if (unit) and UnitIsUnit(unit, "mouseover") then
		unit = "mouseover"
	end
	return UnitExists(unit) and unit
end

-- Add or replace a line of text in the tooltip
local AddIndexedLine = function(tooltip, lineIndex, msg, r, g, b)
	r = r or Colors.offwhite[1]
	g = g or Colors.offwhite[2]
	b = b or Colors.offwhite[3]
	local line
	local numLines = tooltip:NumLines()
	if (lineIndex > numLines) then
		tooltip:AddLine(msg, r, g, b)
		line = _G[tooltip:GetName().."TextLeft"..(numLines + 1)]
	else
		line = _G[tooltip:GetName().."TextLeft"..lineIndex]
		line:SetText(msg)
		if (r and g and b) then
			line:SetTextColor(r, g, b)
		end
	end
	return lineIndex + 1
end

-------------------------------------------------------
-- Tooltip Template
-------------------------------------------------------
local Tooltip = Module:CreateFrame("Frame")
Tooltip:Hide()

Tooltip.Style = function(self)
	if (not self) or (self:IsForbidden()) then
		return
	end

	HealthBar:Hide()

	-- Oldschool backdrop killing.
	self:DisableDrawLayer("BACKGROUND")
	self:DisableDrawLayer("BORDER")

	-- Glorious 9.1.5 / 1.14.1 crap
	-- They decided to move the entire backdrop into its own hashed frame.
	-- We like this, because it makes it easier to kill. Kill. Kill. Kill. Kill.
	if (self.NineSlice) then
		self.NineSlice:SetParent(UIHider)
	end

	if (IsRetail) then

		-- Textures in the combat pet tooltips
		for _,texName in ipairs({
			"BorderTopLeft",
			"BorderTopRight",
			"BorderBottomRight",
			"BorderBottomLeft",
			"BorderTop",
			"BorderRight",
			"BorderBottom",
			"BorderLeft",
			"Background"
		}) do
			local region = self[texName]
			if (region) then
				region:SetTexture(nil)
				local drawLayer, subLevel = region:GetDrawLayer()
				if (drawLayer) then
					self:DisableDrawLayer(drawLayer)
				end
			end
		end

		-- This shit is in its own frame in 9.1.5 / 1.14.1
		if (self.NineSlice) then
			self.NineSlice:SetParent(Tooltip)
		else
			-- Region names sourced from SharedXML\NineSlice.lua
			-- *Majority of this, if not all, was moved into frame.NineSlice in 9.1.5 / 1.14.1
			for _,pieceName in ipairs({
				"TopLeftCorner",
				"TopRightCorner",
				"BottomLeftCorner",
				"BottomRightCorner",
				"TopEdge",
				"BottomEdge",
				"LeftEdge",
				"RightEdge",
				"Center"
			}) do
				local region = self[pieceName]
				if (region) then
					region:SetTexture(nil)
					local drawLayer, subLevel = region:GetDrawLayer()
					if (drawLayer) then
						self:DisableDrawLayer(drawLayer)
					end
				end
			end
		end
	end

	-- The GameTooltipTooltip is an embedded tooltip used to show item rewards
	-- from world quests, paragon reputation and similar. Don't add backdrops!
	--if (self ~= GameTooltipTooltip)  then
	if (self.IsEmbedded) then
		Tooltip.SetBackdrop(nil)
	else
		Tooltip.SetBackdrop(self, SmallTooltipBackdropTemplate)

		if (self == NarciGameTooltip) then
			Tooltip.SetBackdropOffsets(self, 18, 18, 18, 18)
		else
			Tooltip.SetBackdropOffsets(self, 25, 25, 25, 25)
		end

		Tooltip.SetBackdropColor(self, 0, 0, 0, .95)
		Tooltip.SetBackdropBorderColor(self, .35, .35, .35, 1)
	end

	self:SetIgnoreParentScale(true)
	self:SetScale(768/1080)

	-- I don't THINK this taints, but one never knows.
	-- We do this to easily avoid certain addons changing the scale.
	self.SetIgnoreParentScale = function() end
	self.SetScale = function() end

end

Tooltip.AdjustScale = function(self)
	local currentScale = self:GetScale()
	local UICenter = Module:GetFrame("UICenter")
	local targetScale = UICenter:GetEffectiveScale() / (self:GetParent() or WorldFrame):GetEffectiveScale()
	if (math_abs(currentScale - targetScale) > .05) then
		self:SetScale(targetScale)
	end
end

-- Hook into tooltip framelevel changes.
-- Might help with some of the conflicts
-- experienced with Silverdragon and Raider.IO
Tooltip.UpdateFrameLevel = function(self)
	local backdrop = Backdrops[self]
	if (not backdrop) then
		return
	end
	-- Assure we can always go one level below
	local level = self:GetFrameLevel()
	if (level < 2) then
		self:SetFrameLevel(2)
		backdrop:SetFrameLevel(1)
	else
		backdrop:SetFrameLevel(level-1)
	end
end

Tooltip.SetBackdrop = function(self, backdropInfo)
	local backdrop = Backdrops[self]
	if (backdropInfo) then
		if (not backdrop) then
			backdrop = CreateFrame("Frame", nil, self, BackdropTemplateMixin and "BackdropTemplate")
			backdrop:SetAllPoints()
			for _,handler in ipairs({
				"OnTooltipSetSpell",
				"OnTooltipSetItem",
				"OnTooltipSetUnit",
				"OnShow"
			}) do
				-- Not all tooltipframes has these.
				if (self:HasScript(handler)) then
					self:HookScript(handler, Tooltip.UpdateFrameLevel)
				end
			end
			hooksecurefunc(self, "SetFrameLevel", Tooltip.UpdateFrameLevel)
			hooksecurefunc(self, "Show", Tooltip.UpdateFrameLevel)
			Backdrops[self] = backdrop
		end
		backdrop:SetBackdrop(backdropInfo)
		Tooltip.UpdateFrameLevel(self) -- might be needed?
	elseif (backdrop) then
		backdrop:SetBackdrop(nil)
	end
end

Tooltip.SetBackdropOffsets = function(self, left, right, top, bottom)
	local backdrop = Backdrops[self]
	if (not backdrop) then
		return
	end
	backdrop:ClearAllPoints()
	backdrop:SetPoint("TOPLEFT", -left, top)
	backdrop:SetPoint("BOTTOMRIGHT", right, -bottom)
end

Tooltip.SetBackdropColor = function(self, ...)
	local backdrop = Backdrops[self]
	if (not backdrop) then
		return
	end
	backdrop:SetBackdropColor(...)
end

Tooltip.SetBackdropBorderColor = function(self, ...)
	local backdrop = Backdrops[self]
	if (not backdrop) then
		return
	end
	backdrop:SetBackdropBorderColor(...)
end

Tooltip.Place = function(...)
	if (not Tooltip.Anchor) then
		local anchor = Module:CreateFrame("Frame", nil, "UICenter")
		anchor:SetSize(2,2)
		anchor:SetFrameStrata("TOOLTIP")
		anchor:SetFrameLevel(20)
		Tooltip.Anchor = anchor
	end
	Tooltip.Anchor:Place(...)
end

Tooltip.SetDefaultAnchor = function(self, parent)
	if (self:IsForbidden()) then
		return
	end

	-- Mouseover tooltips
	if (false) then
		if (parent ~= UIParent) then
			local anchor = Tooltip.Anchor:GetPoint()
			self:ClearAllPoints()
			self:SetPoint(anchor, Tooltip.Anchor, anchor, 0, 0)
		else
			self:SetOwner(parent, "ANCHOR_CURSOR")
		end
	else
		local anchor = Tooltip.Anchor:GetPoint()
		self:ClearAllPoints()
		self:SetPoint(anchor, Tooltip.Anchor, anchor, 0, 0)
	end

end

Tooltip.OnCompareItemShow = function(self)
	local frameLevel = GameTooltip:GetFrameLevel()
	for i = 1, 2 do
		local tooltip = _G["ShoppingTooltip"..i]
		if (tooltip:IsShown()) then
			if (frameLevel == tooltip:GetFrameLevel()) then
				tooltip:SetFrameLevel(i+1)
			end
		end
	end
end

Tooltip.SetUnitColor = function(unit)
	local unitReaction = unit and UnitReaction(unit, "player")
	local unitIsPlayer = unit and UnitIsPlayer(unit)
	local color
	if (unitIsPlayer) then
		local _,class = UnitClass(unit)
		color = class and Colors.class[class]
	elseif (unitReaction) then
		color = Colors.reaction[unitReaction]
	end
	if (color) then
		HealthBar:SetStatusBarColor(color[1], color[2], color[3])
	end
end

Tooltip.ResetColor = function(self)
	Tooltip.SetBackdropColor(self, 0, 0, 0, .95)
	Tooltip.SetBackdropBorderColor(self, .35, .35, .35, 1)
	--HealthBar:SetStatusBarColor(0, .7, 0) -- this sometimes overwrite the current coloring(?)
	HealthBar.Text:Hide()
end

Tooltip.OnTooltipSetUnit = function(self)
	if (self:IsForbidden()) then
		return
	end
	local unit = GetTooltipUnit(self)
	if (not unit) then
		self:Hide()
		return
	end
	local data = Module:GetTooltipDataForUnit(unit)
	if (not data) then
		tooltip:Hide()
		return
	end

	GameTooltip_ClearMoney(self)
	SharedTooltip_ClearInsertedFrames(self)
	self:SetPadding(0,0,0,0)
	self:ClearLines()

	local lineIndex = 1
	local tooltipName = self:GetName()

	-- name
	local displayName = data.name
	if (data.isPlayer) then
		if (data.showPvPFactionWithName) then
			if (data.isFFA) then
				displayName = FFA_TEXTURE .. " " .. displayName
			elseif (data.isPVP and data.englishFaction) then
				if (data.englishFaction == "Horde") then
					displayName = FACTION_HORDE_TEXTURE .. " " .. displayName
				elseif (data.englishFaction == "Alliance") then
					displayName = FACTION_ALLIANCE_TEXTURE .. " " .. displayName
				elseif (data.englishFaction == "Neutral") then
					-- They changed this to their new atlas garbage in Legion,
					-- so for the sake of simplicty we'll just use the FFA PvP icon instead. Works.
					displayName = FFA_TEXTURE .. " " .. displayName
				end
			end
		end
		if (data.pvpRankName) then
			displayName = displayName .. Colors.quest.gray.colorCode.. " (" .. data.pvpRankName .. ")|r"
		end

	else
		if (data.isBoss) then
			displayName = BOSS_TEXTURE .. " " .. displayName
		elseif (data.classification == "rare") or (data.classification == "rareelite") then
			displayName = displayName .. Colors.quality[3].colorCode .. " (" .. ITEM_QUALITY3_DESC .. ")|r"
		elseif (data.classification == "elite") then
			displayName = displayName .. Colors.title.colorCode .. " (" .. ELITE .. ")|r"
		end
	end

	local levelText
	if (data.effectiveLevel and (data.effectiveLevel > 0)) then
		local r, g, b, colorCode = GetDifficultyColorByLevel(data.effectiveLevel)
		levelText = colorCode .. data.effectiveLevel .. "|r"
	end

	if (data.isPlayer) and (not levelText) then
		displayName = BOSS_TEXTURE .. " " .. displayName
	end

	local r, g, b = GetUnitHealthColor(unit,data)
	if (levelText) then
		lineIndex = AddIndexedLine(self, lineIndex, levelText .. Colors.quest.gray.colorCode .. ": |r" .. displayName, r, g, b)
	else
		lineIndex = AddIndexedLine(self, lineIndex, displayName, r, g, b)
	end

	-- Players
	if (data.isPlayer) then
		if (data.isDead) then
			lineIndex = AddIndexedLine(self, lineIndex, data.isGhost and DEAD or CORPSE, Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
		else
			if (data.guild) then
				lineIndex = AddIndexedLine(self, lineIndex, "<"..data.guild..">", Colors.title[1], Colors.title[2], Colors.title[3])
			end

			local levelLine

			if (data.raceDisplayName) then
				levelLine = (levelLine and levelLine.." " or "") .. data.raceDisplayName
			end

			if (data.classDisplayName and data.class) then
				levelLine = (levelLine and levelLine.." " or "") .. data.classDisplayName
			end

			if (levelLine) then
				lineIndex = AddIndexedLine(self, lineIndex, levelLine, Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
			end

			-- player faction (Horde/Alliance/Neutral)
			if (data.localizedFaction) then
				lineIndex = AddIndexedLine(self, lineIndex, data.localizedFaction)
			end
		end

	-- All other NPCs
	else
		if (data.isDead) then
			lineIndex = AddIndexedLine(self, lineIndex, data.isGhost and DEAD or CORPSE, Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
			if (data.isSkinnable) then
				lineIndex = AddIndexedLine(self, lineIndex, data.skinnableMsg, data.skinnableColor[1], data.skinnableColor[2], data.skinnableColor[3])
			end
		else
			-- titles
			if (data.title) then
				lineIndex = AddIndexedLine(self, lineIndex, "<"..data.title..">", Colors.normal[1], Colors.normal[2], Colors.normal[3])
			end

			if (data.city) then
				lineIndex = AddIndexedLine(self, lineIndex, data.city, Colors.title[1], Colors.title[2], Colors.title[3])
			end

			-- Beast etc
			if (data.creatureFamily) then
				lineIndex = AddIndexedLine(self, lineIndex, data.creatureFamily, Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])

			-- Humanoid, Crab, etc
			elseif (data.creatureType) then
				lineIndex = AddIndexedLine(self, lineIndex, data.creatureType, Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
			end

			-- Player faction (Horde/Alliance/Neutral)
			if (data.localizedFaction) then
				lineIndex = AddIndexedLine(self, lineIndex, data.localizedFaction)
			end

			-- Definitely important in classic!
			if (data.isCivilian) then
				lineIndex = AddIndexedLine(self, lineIndex, PVP_RANK_CIVILIAN, data.civilianColor[1], data.civilianColor[2], data.civilianColor[3])
			end
		end

		-- Add quest objectives
		if (data.objectives) then
			for objectiveID, objectiveData in ipairs(data.objectives) do

				-- Do a first iteration to figure out if we have completes.
				local notComplete
				for questObjectiveID, questObjectiveData in ipairs(objectiveData.questObjectives) do
					local objectiveType = questObjectiveData.objectiveType
					if (objectiveType == "incomplete") or (objectiveType == "failed") then
						notComplete = true
						break
					end
				end

				-- Only show incompletes.
				if (notComplete) then

					lineIndex = AddIndexedLine(self, lineIndex, BLANK) -- this ends up at the end(..?)
					lineIndex = AddIndexedLine(self, lineIndex, objectiveData.questTitle, Colors.title[1], Colors.title[2], Colors.title[3])

					for objectiveID, questObjectiveData in ipairs(objectiveData.questObjectives) do
						local objectiveType = questObjectiveData.objectiveType
						if (objectiveType == "incomplete") then
							lineIndex = AddIndexedLine(self, lineIndex, questObjectiveData.objectiveText, Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3])
						elseif (objectiveType == "complete") then
							lineIndex = AddIndexedLine(self, lineIndex, questObjectiveData.objectiveText, Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
						elseif (objectiveType == "failed") then
							lineIndex = AddIndexedLine(self, lineIndex, questObjectiveData.objectiveText, Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3])
						else
							-- Fallback for unknowns.
							lineIndex = AddIndexedLine(self, lineIndex, questObjectiveData.objectiveText, Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
						end
					end

				end

			end
		end

	end

	-- Add player realm names.
	if (data.realm) then
		lineIndex = AddIndexedLine(self, lineIndex, " ")
		lineIndex = AddIndexedLine(self, lineIndex, FRIENDS_LIST_REALM..data.realm, Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3])
	end

	Tooltip.SetHealthValue(HealthBar, unit)
end

Tooltip.OnTooltipSetItem = function(self)
	if (self:IsForbidden()) then
		return
	end
	-- Recolor items with our own item colors
	local _,link = self:GetItem()
	if (link) then
		local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
		itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID,
		isCraftingReagent = GetItemInfo(link)
		if (itemName) and (itemRarity) then
			local line = _G[self:GetName().."TextLeft1"]
			if (line) then
				local color = Colors.quality[itemRarity]
				line:SetTextColor(color[1], color[2], color[3])
			end
		end
	end
end

Tooltip.OnTooltipSetSpell = function(self)

end

-- This is amongst other times called
-- when a tooltip changes contents while shown.
-- Like when hovering from a unit, to an object.
Tooltip.OnTooltipCleared = function(self)
	if (HealthBar:IsShown()) then
		HealthBar:Hide()
	end
end

Tooltip.SetHealthValue = function(self, unit)
	if (UnitIsDeadOrGhost(unit)) then
		if (self:IsShown()) then
			self:Hide()
		end
	else
		local msg
		local min,max = UnitHealth(unit), UnitHealthMax(unit)
		if (min and max) then
			if (min == max) then
				msg = string_format("%s", large(min))
			else
				msg = string_format("%s / %s", short(min), short(max))
			end
		else
			msg = NOT_APPLICABLE
		end
		self.Text:SetText(msg)
		if (not self.Text:IsShown()) then
			self.Text:Show()
		end
		if (not self:IsShown()) then
			self:Show()
		end
	end
end

Tooltip.OnValueChanged = function(self)
	local unit = select(2, self:GetParent():GetUnit())
	if (not unit) then
		local GMF = GetMouseFocus()
		if (GMF and GMF.GetAttribute and GMF:GetAttribute("unit")) then
			unit = GMF:GetAttribute("unit")
		end
	end
	if (not unit) then
		if (HealthBar:IsShown()) then
			HealthBar:Hide()
		end
		return
	end
	Tooltip.SetHealthValue(HealthBar, unit)
end

Module.StyleHealthBar = function(self)
	HealthBar:SetScript("OnValueChanged", Tooltip.OnValueChanged)
	HealthBar:SetStatusBarTexture(GetMedia("statusbar-normal"))
	HealthBar:ClearAllPoints()
	HealthBar:SetPoint("BOTTOMLEFT", HealthBar:GetParent(), "BOTTOMLEFT", 6, -4)
	HealthBar:SetPoint("BOTTOMRIGHT", HealthBar:GetParent(), "BOTTOMRIGHT", -6, -4)
	HealthBar:SetHeight(4)

	HealthBar:HookScript("OnShow", function(self)
		local tooltip = self:GetParent()
		if (tooltip) then
			if (tooltip == NarciGameTooltip) then
				Tooltip.SetBackdropOffsets(tooltip, 18, 18, 18, 24)
			else
				Tooltip.SetBackdropOffsets(tooltip, 25, 25, 25, 31)
			end
		end
	end)

	HealthBar:HookScript("OnHide", function(self)
		local tooltip = self:GetParent()
		if (tooltip) then
			if (tooltip == NarciGameTooltip) then
				Tooltip.SetBackdropOffsets(tooltip, 18, 18, 18, 18)
			else
				Tooltip.SetBackdropOffsets(tooltip, 25, 25, 25, 25)
			end
		end
	end)

	HealthBar.Text = HealthBar:CreateFontString(nil, "OVERLAY")
	HealthBar.Text:SetFontObject(GetFont(13,true))
	HealthBar.Text:SetTextColor(Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3])
	HealthBar.Text:SetPoint("CENTER", HealthBar, "CENTER", 0, 0)
end

Module.StyleTooltips = function(self, event, ...)

	-- Only want this on the first run.
	if (event == "PLAYER_ENTERING_WORLD") then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", "StyleTooltips")
	end

	-- Force creation of money lines.
	if (not GameTooltip.hasMoney) then
		SetTooltipMoney(GameTooltip, 1, nil, "", "")
		SetTooltipMoney(GameTooltip, 1, nil, "", "")
		GameTooltip_ClearMoney(GameTooltip)
	end

	GameTooltipHeaderText:SetFontObject(GetFont(15))
	GameTooltipTextSmall:SetFontObject(GetFont(13))
	GameTooltipText:SetFontObject(GetFont(13))

	for _,tooltip in pairs({

		-- Regular tooltips
		GameTooltip,
		EmbeddedItemTooltip,
		FriendsTooltip,
		ItemRefTooltip,
		ItemRefShoppingTooltip1,
		ItemRefShoppingTooltip2,
		ShoppingTooltip1,
		ShoppingTooltip2,
		QuickKeybindTooltip,

		-- Only in Retail
		QuestScrollFrame and QuestScrollFrame.StoryTooltip,
		QuestScrollFrame and QuestScrollFrame.CampaignTooltip,

		-- Battle Pet Tooltips
		-- *Might have to separate these out.
		BattlePetTooltip,
		PetBattlePrimaryAbilityTooltip,
		PetBattlePrimaryUnitTooltip,
		FloatingBattlePetTooltip,
		FloatingPetBattleAbilityTooltip,

		-- Addons
		NarciGameTooltip

	}) do
		Tooltip.Style(tooltip)
	end
end

Module.SetTooltipHooks = function(self)

	if (_G.GameTooltip_SetBackdropStyle) then
		-- Blizzard removed this in 1.14.1, changed it to the same as retail below.
		hooksecurefunc("GameTooltip_SetBackdropStyle", Tooltip.Style)
	elseif (_G.SharedTooltip_SetBackdropStyle) then
		hooksecurefunc("SharedTooltip_SetBackdropStyle", Tooltip.Style)
	end

	hooksecurefunc("GameTooltip_SetDefaultAnchor", Tooltip.SetDefaultAnchor)
	hooksecurefunc("GameTooltip_ShowCompareItem", Tooltip.OnCompareItemShow)
	hooksecurefunc("GameTooltip_UnitColor", Tooltip.SetUnitColor)
	hooksecurefunc("GameTooltip_ClearMoney", Tooltip.ResetColor)

	-- 2021-04-02: Workaround for the weird paragon faction reward tooltip width in 9.0.5.
	-- 2021-04-03: When hovering over, out and back over a bonus objective reward,
	--             most the text except level requirement will disappear on re-entering.
	--             Seems to be because of self.Tooltip:Show(), so we're trying something else.
	-- 2021-04-05: This fix ONLY works for embedded tooltips on the worldmap. Not the rep frame. Not the quest log. Fuck.
	if (EmbeddedItemTooltip_UpdateSize) then
		Tooltip.UpdateSize = function(self)
			local itemTooltipExtraBorderHeight = 22
			if (self.Tooltip:IsShown()) then
				-- Figure out the actual width of the embedded tooltip,
				-- as blizzard since 9.0.5 for some reason makes it super wide.
				local realWidth,lineID = 0,1
				while (self["TextLeft"..lineID]) do
					realWidth = math.max(realWidth, self["TextLeft"..lineID]:GetWidth())
					lineID = lineID + 1
				end
				lineID = 1
				while (self.Tooltip["TextLeft"..lineID]) do
					realWidth = math.max(realWidth, self.Tooltip["TextLeft"..lineID]:GetWidth())
					lineID = lineID + 1
				end

				local width = realWidth + 20*4 + self.Icon:GetWidth()
				local height = math.max(self.Tooltip:GetHeight() - itemTooltipExtraBorderHeight, self.Icon:GetHeight())

				self:SetSize(width, height)

			elseif (self.FollowerTooltip:IsShown()) then
				self:SetSize(self.FollowerTooltip:GetSize())
			end

			-- Don't do this, it fucks it up.
			--GameTooltip_CalculatePadding(self:GetParent())
		end
		hooksecurefunc("EmbeddedItemTooltip_UpdateSize", Tooltip.UpdateSize)
	end

	GameTooltip:HookScript("OnTooltipCleared", Tooltip.OnTooltipCleared)
	GameTooltip:HookScript("OnTooltipSetSpell", Tooltip.OnTooltipSetSpell)
	GameTooltip:HookScript("OnTooltipSetItem", Tooltip.OnTooltipSetItem)

	-- Rather then attempt to hook into totalRP3's information system,
	-- we just choose to NOT modify unit tooltips when the addon is enabled.
	-- People using it want this info, not ours.
	if (not self:IsAddOnEnabled("totalRP3")) then
		GameTooltip:HookScript("OnTooltipSetUnit", Tooltip.OnTooltipSetUnit)
	end
end

Module.OnEvent = function(self, event, ...)
	if (event == "GP_BAGS_SHOWN") then
		local bags = Wheel("LibModule"):GetModule("Backpacker", true)
		if (bags) then
			local containerFrame = bags:GetCointainerFrame()
			if (containerFrame) then
				Tooltip.Place("BOTTOMRIGHT", containerFrame, "BOTTOMLEFT", -20, 20)
			end
		end
	elseif (event == "GP_BAGS_HIDDEN") or (event == "PLAYER_ENTERING_WORLD") then
		Tooltip.Place(unpack(GetLayout("Tooltips").TooltipPlace))
	end
end

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end
	-- Place our anchor.
	-- This also triggers the anchor creation,
	-- well in advance of any method that needs it.
	Tooltip.Place(unpack(GetLayout("Tooltips").TooltipPlace))
end

Module.OnEnable = function(self)
	self:SetTooltipHooks()
	self:StyleHealthBar()
	self:StyleTooltips()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "StyleTooltips")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterMessage("GP_BAGS_HIDDEN", "OnEvent")
	self:RegisterMessage("GP_BAGS_SHOWN", "OnEvent")
end
