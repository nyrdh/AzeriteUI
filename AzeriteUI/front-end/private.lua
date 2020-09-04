--[[--

The purpose of this file is to supply all the front-end modules 
with color, fonts and aura tables local to the addon only. 

--]]--

local ADDON, Private = ...

local LibAuraTool = Wheel("LibAuraTool")
assert(LibAuraTool, ADDON.." requires LibAuraTool to be loaded.")

local LibColorTool = Wheel("LibColorTool")
assert(LibColorTool, ADDON.." requires LibColorTool to be loaded.")

local LibFontTool = Wheel("LibFontTool")
assert(LibFontTool, ADDON.." requires LibFontTool to be loaded.")

-- Color Tables
-----------------------------------------------------------------
-- We start with the base colors, 
-- and only add or change what is specific to this UI.
local Colors = LibColorTool:GetColorTable()

-- Our player health bar color
Colors.health = Colors:CreateColor(245/255, 0/255, 45/255)

-- Global UI vertex coloring
Colors.ui = Colors:CreateColor(192/255, 192/255, 192/255)

-- Power Colors
local fast = Colors:CreateColor(0/255, 208/255, 176/255) 
local slow = Colors:CreateColor(116/255, 156/255, 255/255)
local angry = Colors:CreateColor(156/255, 116/255, 255/255)

Colors.power.ENERGY_CRYSTAL = fast -- Rogues, Druids
Colors.power.FOCUS_CRYSTAL = slow -- Hunters Pets (?)
Colors.power.FURY_CRYSTAL = angry -- Havoc Demon Hunter 
Colors.power.INSANITY_CRYSTAL = angry -- Shadow Priests
Colors.power.LUNAR_POWER_CRYSTAL = slow -- Balance Druid Astral Power 
Colors.power.MAELSTROM_CRYSTAL = slow -- Elemental Shamans
Colors.power.PAIN_CRYSTAL = angry -- Vengeance Demon Hunter 
Colors.power.RAGE_CRYSTAL = angry -- Druids, Warriors
Colors.power.RUNIC_POWER_CRYSTAL = slow -- Death Knights

-- Only occurs when the orb is manually disabled by the player.
Colors.power.MANA_CRYSTAL = Colors:CreateColor(101/255, 93/255, 191/255) -- Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock

-- Orb Power Colors
Colors.power.MANA_ORB = Colors:CreateColor(135/255, 125/255, 255/255) -- Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock

-- Private Addon API
-----------------------------------------------------------------
Private.Colors = Colors
Private.GetAuraFilterFunc = function(...) return LibAuraTool:GetAuraFilter(...) end
Private.GetFont = function(...) return LibFontTool:GetFont(...) end
Private.GetMedia = function(name, type) return ([[Interface\AddOns\%s\media\%s.%s]]):format(ADDON, name, type or "tga") end
Private.IsForcingSlackAuraFilterMode = function() return LibAuraTool:IsForcingSlackAuraFilterMode() end
