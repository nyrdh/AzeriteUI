local LibFontTool = Wheel:Set("LibFontTool", 1)
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
local normalFontPath = ({
	roman = [[Fonts\FRIZQT__.TTF]],
	russian = [[Fonts\FRIZQT___CYR.TTF]],
	korean = [[Fonts\2002.TTF]],
	simplifiedchinese = [[Fonts\ARKai_T.ttf]],
	traditionalchinese = [[Fonts\blei00d.TTF]]
})[fontFamily]

-- Set the chat font
local chatFontPath = ({
	roman = [[Fonts\ARIALN.TTF]],
	russian = [[Fonts\ARIALN.TTF]],
	korean = [[Fonts\2002.TTF]],
	simplifiedchinese = [[Fonts\ARHei.ttf]],
	traditionalchinese = [[Fonts\bHEI01B.TTF]]
})[fontFamily]


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
				rawset(t,k,CreateFont("GP_FontObject"..LibFontTool.numFonts))
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

-- Return a font object
LibFontTool.GetFont = function(self, size, useOutline, useChatFont)
	check(size, 1, "number")
	check(useOutline, 2, "boolean", "nil")
	check(useChatFont, 3, "boolean", "nil")
	local fontObject = Fonts[useChatFont and "Chat" or "Normal"][useOutline and "Outline" or "None"][size]
	fontObject:SetFont(useChatFont and chatFontPath or normalFontPath, size, useOutline and "OUTLINE" or "")
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
