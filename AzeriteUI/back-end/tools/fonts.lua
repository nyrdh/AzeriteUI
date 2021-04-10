--[[--

The purpose of this tool is to supply on-demand font objects
created, sorted and stored based on size, style and type, 
without the need for the front-end modules to worry about global names.

--]]--
local LibFontTool = Wheel:Set("LibFontTool", 8)
if (not LibFontTool) then
	return
end

-- Lua API
local pairs = pairs
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local type = type

-- WoW API
local CreateFont = CreateFont

-- Library registries
LibFontTool.embeds = LibFontTool.embeds or {}
LibFontTool.fontsDB = LibFontTool.fontsDB or {}
LibFontTool.numFonts = LibFontTool.numFonts or 0
LibFontTool.fontPrefix = LibFontTool.fontPrefix 

-- Shortcuts
Fonts = LibFontTool.fontsDB

-- Figure out the font family based on client region
local fontFamily = ({
	["koKR"] = "korean",
	["ruRU"] = "russian",
	["zhCN"] = "simplifiedchinese",
	["zhTW"] = "traditionalchinese"
})[(GetLocale())] or "roman"

-- Set the normal font
local normalFontPath = ({
	["roman"] = [[Fonts\FRIZQT__.TTF]],
	["russian"] = [[Fonts\FRIZQT___CYR.TTF]],
	["korean"] = [[Fonts\2002.TTF]],
	["simplifiedchinese"] = [[Fonts\ARKai_T.ttf]],
	["traditionalchinese"] = [[Fonts\blei00d.TTF]]
})[fontFamily]

-- Set the chat font
local chatFontPath = ({
	["roman"] = [[Fonts\ARIALN.TTF]],
	["russian"] = [[Fonts\ARIALN.TTF]],
	["korean"] = [[Fonts\2002.TTF]],
	["simplifiedchinese"] = [[Fonts\ARHei.ttf]],
	["traditionalchinese"] = [[Fonts\bHEI01B.TTF]]
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
				LibFontTool.numFonts = LibFontTool.numFonts + 1
				local fontObject = CreateFont("GP_FontObject"..LibFontTool.numFonts)
				rawset(t,k,fontObject)
			end
			return rawget(t,k)
		end
	end
}

-- Assign it to the db
setmetatable(Fonts, meta)

-- Return a font object
LibFontTool.GetFont = function(self, size, useOutline, useChatFont, prefix)
	-- First check for front-end created multi alphabet font families.
	local fontObject = (prefix) and _G[prefix..size..(useOutline and "Outline" or "")..(useChatFont and "Chat" or "")]
	if (not fontObject) then
		-- Create one on the fly if it does not exist. 
		-- These ones are locked to the locale alphabet.
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
