local ADDON, Private = ...

-----------------------------------------------------------------
-- Custom Color Tables
-----------------------------------------------------------------
local Colors = Private.Colors

-- Our player health bar color
Colors.health = Colors:CreateColor(245/255, 0/255, 45/255)

-- Global UI vertex coloring
Colors.ui = Colors:CreateColor(192/255, 192/255, 192/255)

-- Power Crystal Colors
local fast = Colors:CreateColor(0/255, 208/255, 176/255) 
local slow = Colors:CreateColor(116/255, 156/255, 255/255)
local angry = Colors:CreateColor(156/255, 116/255, 255/255)

Colors.power.ENERGY_CRYSTAL = fast -- Rogues, Druids, Monks
Colors.power.FOCUS_CRYSTAL = slow -- Hunters
Colors.power.FURY_CRYSTAL = angry -- Havoc Demon Hunter 
Colors.power.INSANITY_CRYSTAL = angry -- Shadow Priests
Colors.power.LUNAR_POWER_CRYSTAL = slow -- Balance Druid Astral Power 
Colors.power.MAELSTROM_CRYSTAL = slow -- Elemental Shamans
Colors.power.PAIN_CRYSTAL = angry -- Vengeance Demon Hunter 
Colors.power.RAGE_CRYSTAL = angry -- Druids, Warriors
Colors.power.RUNIC_POWER_CRYSTAL = slow -- Death Knights

-- Only occurs when the orb is manually disabled by the player.
Colors.power.MANA_CRYSTAL = Colors:CreateColor(101/255, 93/255, 191/255) -- Druid, Hunter (Classic), Mage, Paladin, Priest, Shaman, Warlock

-- Orb Power Colors
Colors.power.MANA_ORB = Colors:CreateColor(135/255, 125/255, 255/255) -- Druid, Hunter (Classic), Mage, Paladin, Priest, Shaman, Warlock
