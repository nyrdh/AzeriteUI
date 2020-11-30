local LibNumbers = Wheel:Set("LibNumbers", -1)
if (not LibNumbers) then	
	return
end

-- Lua API
local _G = _G
local assert = assert
local date = date
local debugstack = debugstack
local error = error
local pairs = pairs
local select = select
local string_format = string.format
local string_gsub = string.gsub
local string_join = string.join
local string_match = string.match
local tonumber = tonumber
local tostring = tostring
local type = type

-- Game locale constant
local gameLocale = GetLocale()

-- Library registries
LibNumbers.embeds = LibNumbers.embeds or {}

-- Utility functions
---------------------------------------------------------------------	
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

-- Number abbreviations
---------------------------------------------------------------------	
local large = function(value)
	value = tonumber(value)
	if (not value) then 
		return "" 
	end
	if (value >= 1e8) then 		return string_format("%.0fm", value/1e6) 	-- 100m, 1000m, 2300m, etc
	elseif (value >= 1e6) then 	return string_format("%.1fm", value/1e6) 	-- 1.0m - 99.9m 
	elseif (value >= 1e5) then 	return string_format("%.0fk", value/1e3) 	-- 100k - 999k
	elseif (value >= 1e3) then 	return string_format("%.1fk", value/1e3) 	-- 1.0k - 99.9k
	elseif (value > 0) then 	return tostring(math_floor(value))			-- 1 - 999
	else 						return ""
	end 
end 

local short = function(value)
	value = tonumber(value)
	if (not value) then 
		return "" 
	end
	if (value >= 1e9) then							return ("%.1fb"):format(value / 1e9):gsub("%.?0+([kmb])$", "%1")
	elseif (value >= 1e6) then 						return ("%.1fm"):format(value / 1e6):gsub("%.?0+([kmb])$", "%1")
	elseif (value >= 1e3) or (value <= -1e3) then 	return ("%.1fk"):format(value / 1e3):gsub("%.?0+([kmb])$", "%1")
	elseif (value > 0) then							return tostring(math_floor(value))
	else 											return ""
	end	
end

-- zhCN exceptions
if (gameLocale == "zhCN") then 
	large = function(value)
		value = tonumber(value)
		if (not value) then 
			return "" 
		end
		if (value >= 1e8) then 							return string_format("%.1f亿", value/1e8)
		elseif (value >= 1e4) then 						return string_format("%.1f万", value/1e4)
		elseif (value > 0) then 						return tostring(math_floor(value))
		else 											return ""
		end 
	end

	short = function(value)
		value = tonumber(value)
		if (not value) then 
			return "" 
		end
		if (value >= 1e8) then							return ("%.1f亿"):format(value / 1e8):gsub("%.?0+([km])$", "%1")
		elseif (value >= 1e4) or (value <= -1e3) then	return ("%.1f万"):format(value / 1e4):gsub("%.?0+([km])$", "%1")
		elseif (value > 0) then 						return tostring(math_floor(value))
		else 											return ""
		end 
	end
end 

LibNumbers.GetNumberAbbreviationShort = function(self)
	return short
end

LibNumbers.GetNumberAbbreviationLong = function(self)
	return large
end

local embedMethods = {
	GetNumberAbbreviationShort = true,
	GetNumberAbbreviationLong = true
}

LibNumbers.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibNumbers.embeds) do
	LibNumbers:Embed(target)
end
