local LibNumbers = Wheel:Set("LibNumbers", 3)
if (not LibNumbers) then	
	return
end

-- Lua API
local math_floor = math.floor
local math_mod = math.fmod
local pairs = pairs
local string_format = string.format
local tonumber = tonumber
local tostring = tostring

-- Game locale constant
local gameLocale = GetLocale()

-- Library registries
LibNumbers.embeds = LibNumbers.embeds or {}

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
		if (value >= 1e8) then 							return string_format("%.2f亿", value/1e8)
		elseif (value >= 1e4) then 						return string_format("%.2f万", value/1e4)
		elseif (value > 0) then 						return tostring(math_floor(value))
		else 											return ""
		end 
	end

	short = function(value)
		value = tonumber(value)
		if (not value) then 
			return "" 
		end
		if (value >= 1e8) then							return ("%.2f亿"):format(value / 1e8):gsub("%.?0+([km])$", "%1")
		elseif (value >= 1e4) or (value <= -1e3) then	return ("%.2f万"):format(value / 1e4):gsub("%.?0+([km])$", "%1")
		elseif (value > 0) then 						return tostring(math_floor(value))
		else 											return ""
		end 
	end
end 

-- Number formatting
---------------------------------------------------------------------	
local prettify = function(value)
	value = tonumber(value) or 0
	if (value > 0) then 
		local valueString
		if (value >= 1e9) then
			local billions =  math_floor(value / 1e9)
			local millions =  math_floor((value - billions*1e9) / 1e6)
			local thousands = math_floor((value - billions*1e9 - millions*1e6) / 1e3)
			local remainder = math_mod(value, 1e3)
			valueString = string_format("%d %03d %03d %03d", billions, millions, thousands, remainder)
		elseif (value >= 1e6) then
			local millions =  math_floor(value / 1e6)
			local thousands = math_floor((value - millions*1e6) / 1e3)
			local remainder = math_mod(value, 1e3)
			valueString = string_format("%d %03d %03d", millions, thousands, remainder)
		elseif (value >= 1e3) then
			local thousands = math_floor(value / 1e3)
			local remainder = math_mod(value, 1e3)
			valueString = string_format("%d %03d", thousands, remainder)
		else
			return value..""
		end
		return valueString
	end
	return value..""
end

-- Public API
---------------------------------------------------------------------	
LibNumbers.GetNumberAbbreviationShort = function(self)
	return short
end

LibNumbers.GetNumberAbbreviationLong = function(self)
	return large
end

LibNumbers.GetNumberPrettified = function(self)
	return prettify
end

local embedMethods = {
	GetNumberAbbreviationShort = true,
	GetNumberAbbreviationLong = true,
	GetNumberPrettified = true
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
