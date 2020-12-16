local LibTime = Wheel:Set("LibTime", 7)
if (not LibTime) then	
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
local string_join = string.join
local string_match = string.match
local tonumber = tonumber
local type = type

-- WoW API
local GetGameTime = _G.GetGameTime

-- WoW Strings
local S_AM = TIMEMANAGER_AM
local S_PM = TIMEMANAGER_PM

-- Library registries
LibTime.embeds = LibTime.embeds or {}

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

local dateInRange = function(day1, month1, year1, day2, month2, year2)
	local currentDay = tonumber(date("%d"))
	local currentMonth = tonumber(date("%m"))
	local currentYear = tonumber(date("%Y")) -- full 4 digit year

	-- First check the year range
	if (currentYear >= year1) and (currentYear <= year2) then

		-- If the current year is between the two requested, 
		-- we are most definitely within the range.
		if (currentYear > year1) and (currentYear < year2) then
			return true
		else
			-- If the current year is the first requested, 
			-- we have to check if it has passed the date.
			if (currentYear == year1) then
				-- We've passed the requested month, definitely within range.
				if (currentMonth > month1) then
					return true
				-- We're within the same month, let's check the day!
				elseif (currentMonth == month1) and (currentDay >= day1) then
					return true
				end

			-- The current year is the last one requested, 
			-- we have to make sure we haven't moved outside the range.
			elseif (currentYear == year2) then
				-- We haven't reached the requested month, definitely within range.
				if (currentMonth < month2) then
					return true
				-- We're within the same month, let's check the day!
				elseif (currentMonth == month2) and (currentDay <= day2) then
					return true
				end
			end
		end
	end

	return false
end

-- Calculates standard hours from a give 24-hour time
-- Keep this systematic to the point of moronic, or I'll mess it up again. 
LibTime.ComputeStandardHours = function(self, hour)
	if 		(hour == 0) then 					return 12, S_AM 		-- 0 is 12 AM
	elseif 	(hour > 0) and (hour < 12) then 	return hour, S_AM 		-- 01-11 is 01-11 AM
	elseif 	(hour == 12) then 					return 12, S_PM 		-- 12 is 12 PM
	elseif 	(hour > 12) then 					return hour - 12, S_PM 	-- 13-24 is 01-12 PM
	end
end

-- Calculates military time, but assumes the given time is standard (12 hour)
LibTime.ComputeMilitaryHours = function(self, hour, am)
	if (am and hour == 12) then
		return 0
	elseif (not am and hour < 12) then
		return hour + 12
	else
		return hour
	end
end

-- Retrieve the local client computer time
LibTime.GetLocalTime = function(self, useStandardTime)
	local hour, minute = tonumber(date("%H")), tonumber(date("%M"))
	if useStandardTime then 
		local hour, suffix = self:ComputeStandardHours(hour)
		return hour, minute, suffix
	else 
		return hour, minute
	end 
end

-- Retrieve the server time
LibTime.GetServerTime = function(self, useStandardTime)
	local hour, minute = GetGameTime()
	if useStandardTime then 
		local hour, suffix = self:ComputeStandardHours(hour)
		return hour, minute, suffix
	else 
		return hour, minute
	end
end

LibTime.GetTime = function(self, useStandardTime, useServerTime)
	return self[useServerTime and "GetServerTime" or "GetLocalTime"](self, useStandardTime)
end

-- 2020 Retail Winter Veil.
LibTime.IsWinterVeil = function(self)
	return dateInRange(16,12,2020,2,1,2021)
end

-- 2021 Retail Love is in the Air.
LibTime.IsLoveFestival = function(self)
	return dateInRange(8,2,2021,22,2,2021)
end

local embedMethods = {
	ComputeMilitaryHours = true, 
	ComputeStandardHours = true,
	GetTime = true, 
	GetLocalTime = true, 
	GetServerTime = true, 
	IsWinterVeil = true,
	IsLoveFestival = true
}

LibTime.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibTime.embeds) do
	LibTime:Embed(target)
end
