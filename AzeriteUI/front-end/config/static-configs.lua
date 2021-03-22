--[[--

The purpose of this file is to supply all the front-end modules 
with static layout data used during the setup phase, as well as
with any custom colors, fonts and aura tables local to the addon only. 

--]]--

local ADDON, Private = ...

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, ADDON.." requires LibClientBuild to be loaded.")

local LibDB = Wheel("LibDB")
assert(LibDB, ADDON.." requires LibDB to be loaded.")

local LibAuraTool = Wheel("LibAuraTool")
assert(LibAuraTool, ADDON.." requires LibAuraTool to be loaded.")

local LibColorTool = Wheel("LibColorTool")
assert(LibColorTool, ADDON.." requires LibColorTool to be loaded.")

local LibFontTool = Wheel("LibFontTool")
assert(LibFontTool, ADDON.." requires LibFontTool to be loaded.")

local LibNumbers = Wheel("LibNumbers")
assert(LibNumbers, ADDON.." requires LibNumbers to be loaded.")

-- Number Abbreviation
local short = LibNumbers:GetNumberAbbreviationShort()
local large = LibNumbers:GetNumberAbbreviationLong()

-- Addon localization
local L = Wheel("LibLocale"):GetLocale(ADDON)

-- Private API
local Colors = LibColorTool:GetColorTable()
local GetAuraFilterFunc = function(...) return LibAuraTool:GetAuraFilter(...) end
local GetFont = function(...) return LibFontTool:GetFont(...) end
local GetMedia = function(name, type) return ([[Interface\AddOns\%s\front-end\media\%s.%s]]):format(ADDON, name, type or "tga") end

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

local NEW = "*"

