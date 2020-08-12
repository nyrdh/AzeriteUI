local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "UnitName requires LibClientBuild to be loaded.")

-- Lua API
local string_len = string.len
local string_split = string.split

-- WoW API
local GetQuestGreenRange = GetQuestGreenRange
local GetScalingQuestGreenRange = GetScalingQuestGreenRange
local UnitClassification = UnitClassification
local UnitEffectiveLevel = UnitEffectiveLevel or UnitLevel -- cheap fix
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitQuestTrivialLevelRange = UnitQuestTrivialLevelRange or GetQuestGreenRange
local UnitQuestTrivialLevelRangeScaling = UnitQuestTrivialLevelRangeScaling or GetScalingQuestGreenRange

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

local utf8sub = function(str, i, dots)
	if not str then return end
	local bytes = str:len()
	if bytes <= i then
		return str
	else
		local len, pos = 0, 1
		while pos <= bytes do
			len = len + 1
			local c = str:byte(pos)
			if c > 0 and c <= 127 then
				pos = pos + 1
			elseif c >= 192 and c <= 223 then
				pos = pos + 2
			elseif c >= 224 and c <= 239 then
				pos = pos + 3
			elseif c >= 240 and c <= 247 then
				pos = pos + 4
			end
			if len == i then break end
		end
		if len == i and pos <= bytes then
			return str:sub(1, pos - 1)..(dots and "..." or "")
		else
			return str
		end
	end
end

-- Returns the correct difficulty color compared to the player.
-- Using this as a tooltip method to access our custom colors.
-- *Sourced from /back-end/tooltip.lua
local GetDifficultyColorByLevel
if (IsClassic) then
	GetDifficultyColorByLevel = function(self, level, isScaling)
		local colors = self.colors.quest
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
	GetDifficultyColorByLevel = function(self, level, isScaling)
		local colors = self.colors.quest
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

local Update = function(self, event, unit)
	if (not unit) or (unit ~= self.unit) then 
		return 
	end 

	local element = self.Name
	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end

	-- Retrieve data
	local name = UnitName(unit)
	if (not name) then 
		element:SetText("")
		return
	end

	local nameLength = string_len(name)
	local levelText, levelTextLength, showLevel

	if (element.showLevel) then
		local level = UnitEffectiveLevel(unit)
		if (level and level > 0) then 
			local r, g, b, colorCode = GetDifficultyColorByLevel(self, level)
			levelText = colorCode .. level .. "|r"
			levelTextLength = level >= 100 and 5 or level >= 10 and 4 or 3
			showLevel = true
		end 
	end

	local fullLength = (showLevel) and (nameLength + levelTextLength) or (nameLength)
	if (element.maxChars) and (fullLength > element.maxChars) then 
		local maxChars = (showLevel) and (element.maxChars - levelTextLength) or (element.maxChars)
		if (element.useSmartName) then
			local nameTable = { string_split(" ", name) }
			if (#nameTable > 1) then
				if string_len(nameTable[#nameTable]) < maxChars then
					name = nameTable[#nameTable]
				else
					name = utf8sub(name, maxChars, element.useDots)
				end
			end
		else
			name = utf8sub(name, maxChars, element.useDots)
		end
	end 

	if (showLevel) then
		if (element.showLevelLast) then 
			name = name .. " |cff888888:|r" .. levelText
		else 
			name = levelText .. "|cff888888:|r " .. name
		end
	end

	element:SetText(name)

	if (element.PostUpdate) then 
		return element:PostUpdate(unit)
	end 
end 

local Proxy = function(self, ...)
	return (self.Name.Override or Update)(self, ...)
end 

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local element = self.Name
	if element then
		element._owner = self
		element.ForceUpdate = ForceUpdate

		if (self.unit == "player") or (self.unit == "pet") then 
			self:RegisterEvent("PLAYER_LEVEL_UP", Proxy, true)
		end 

		self:RegisterEvent("UNIT_NAME_UPDATE", Proxy)
		self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", Proxy)
		self:RegisterEvent("UNIT_FACTION", Proxy)
		self:RegisterEvent("UNIT_LEVEL", Proxy)
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA", Proxy, true)

		return true
	end
end 

local Disable = function(self)
	local element = self.Name
	if element then
		element:Hide()

		self:UnregisterEvent("PLAYER_LEVEL_UP", Proxy)
		self:UnregisterEvent("UNIT_NAME_UPDATE", Proxy)
		self:UnregisterEvent("UNIT_CLASSIFICATION_CHANGED", Proxy)
		self:UnregisterEvent("UNIT_FACTION", Proxy)
		self:UnregisterEvent("UNIT_LEVEL", Proxy)
		self:UnregisterEvent("ZONE_CHANGED_NEW_AREA", Proxy)
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("Name", Enable, Disable, Proxy, 13)
end 
