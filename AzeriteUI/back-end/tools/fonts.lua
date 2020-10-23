--[[--

The purpose of this tool is to supply on-demand font objects
created, sorted and stored based on size, style and type, 
without the need for the front-end modules to worry about global names.

--]]--

local LibFontTool = Wheel:Set("LibFontTool", 5)
if (not LibFontTool) then
	return
end

-- Lua API
local assert = assert
local debugstack = debugstack
local error = error
local select = select
local string_format = string.format
local string_join = string.join
local string_match = string.match
local type = type

-- WoW API
local CreateFont = CreateFont

-- Library registries
LibFontTool.embeds = LibFontTool.embeds or {}
LibFontTool.fontsDB = LibFontTool.fontsDB or {}

-- Shortcuts
Fonts = LibFontTool.fontsDB

-- Figure out the font family based on client region
local fontFamily = ({
	deDE = "roman",
	enGB = "roman", 
	enUS = "roman",
	esES = "roman",
	esMX = "roman",
	frFR = "roman",
	itIT = "roman",
	koKR = "korean",
	ptBR = "roman",
	ptPT = "roman",
	ruRU = "russian",
	zhCN = "simplifiedchinese",
	zhTW = "traditionalchinese"
})[(GetLocale())]

-- Set the normal font
local normalFontPaths = {
	roman = [[Fonts\FRIZQT__.TTF]],
	russian = [[Fonts\FRIZQT___CYR.TTF]],
	korean = [[Fonts\2002.TTF]],
	simplifiedchinese = [[Fonts\ARKai_T.ttf]],
	traditionalchinese = [[Fonts\blei00d.TTF]]
}
local normalFontPath = normalFontPaths[fontFamily]

-- Set the chat font
local chatFontPaths = {
	roman = [[Fonts\ARIALN.TTF]],
	russian = [[Fonts\ARIALN.TTF]],
	korean = [[Fonts\2002.TTF]],
	simplifiedchinese = [[Fonts\ARHei.ttf]],
	traditionalchinese = [[Fonts\bHEI01B.TTF]]
}
local chatFontPath = chatFontPaths[fontFamily]


-- Metatable that automatically
-- creates the needed tables and font objects.
local meta
meta = {
	__index = function(t,k)
		if (type(k) == "string") then
			if (not rawget(t,k)) then
				rawset(t,k,setmetatable({},meta))
			end
			return rawget(t,k)
		elseif (type(k) == "number") then
			if (not rawget(t,k)) then
				LibFontTool.numFonts = (LibFontTool.numFonts or 0) + 1
				local fontObject = CreateFont("GP_FontObject"..LibFontTool.numFonts)
				rawset(t,k,fontObject)
			end
			return rawget(t,k)
		end
	end
}

-- Assign it to the db
setmetatable(Fonts, meta)

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

local utf8charpattern = [=[[\0-\x7F\xC2-\xF4][\x80-\xBF]*]=]
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

-- Return a font object
LibFontTool.GetFont = function(self, size, useOutline, useChatFont)
	check(size, 1, "number")
	check(useOutline, 2, "boolean", "nil")
	check(useChatFont, 3, "boolean", "nil")

	-- First check for multi alphabet font families.
	local fontObject = _G["AzeriteFont"..size..(useOutline and "Outline" or "")..(useChatFont and "Chat" or "")]
	if (not fontObject) then
		-- Create one on the fly if it does not exist. These ones are locked to the locale alphabet.
		fontObject = Fonts[useChatFont and "Chat" or "Normal"][useOutline and "Outline" or "None"][size]
		fontObject:SetFont(useChatFont and chatFontPath or normalFontPath, size, useOutline and "OUTLINE" or "")
	end

	return fontObject
end

local embedMethods = {
	GetFont = true
}

LibFontTool.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibFontTool.embeds) do
	LibFontTool:Embed(target)
end
