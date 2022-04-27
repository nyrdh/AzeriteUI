--[[--

The purpose of this tool is to supply a basic color table,
which the requesting module can edit or add to later.

--]]--

local LibColorTool = Wheel:Set("LibColorTool", 7)
if (not LibColorTool) then
	return
end

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibColorTool requires LibClientBuild to be loaded.")

-- Lua API
local assert = assert
local debugstack = debugstack
local error = error
local math_floor = math.floor
local select = select
local string_format = string.format
local string_join = string.join
local string_match = string.match
local type = type

-- WoW API
local CreateFont = CreateFont

-- Library registries
LibColorTool.embeds = LibColorTool.embeds or {}
LibColorTool.colorDB = LibColorTool.colorDB or {}

-- Shortcuts
local Colors = LibColorTool.colorDB

-- Templates
local ColorTemplate = {}

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

local copyTable
copyTable = function(source, copy)
	check(source, 1, "table")
	check(copy, 2, "table", "nil")
	copy = copy or {}
	for k,v in pairs(source) do
		if (type(v) == "table") then
			copy[k] = copyTable(v)
		else
			copy[k] = v
		end
	end
	return copy
end

-- Convert a Blizzard Color or RGB value set 
-- into our own custom color table format. 
local createColor = function(...)
	local tbl
	if (select("#", ...) == 1) then
		local old = ...
		if (old.r) then 
			tbl = {}
			tbl[1] = old.r or 1
			tbl[2] = old.g or 1
			tbl[3] = old.b or 1
		else
			tbl = { unpack(old) }
		end
	else
		tbl = { ... }
	end
	-- Do NOT use a metatable, just embed.
	for name,method in pairs(ColorTemplate) do 
		tbl[name] = method
	end
	if (#tbl == 3) then
		tbl.colorCode = tbl:GenerateHexColorMarkup()
		tbl.colorCodeClean = tbl:GenerateHexColor()
	end
	return tbl
end

-- Convert a whole Blizzard color table
local createColorGroup = function(group)
	local tbl = {}
	for i,v in pairs(group) do 
		tbl[i] = createColor(v)
	end 
	return tbl
end 

-- Assign proxies to the color table, for modules to use
Colors.CreateColor = function(self, ...) return createColor(...) end
Colors.CreateColorGroup = function(self, ...) return createColorGroup(...) end

-- Color Template
-----------------------------------------------------------------
-- Emulate some of the Blizzard methods, 
-- since they too do colors this way now. 
-- Goal is not to be fully interchangeable. 
ColorTemplate.GetRGB = function(self)
	return self[1], self[2], self[3]
end

ColorTemplate.GetRGBAsBytes = function(self)
	return self[1]*255, self[2]*255, self[3]*255
end

ColorTemplate.GenerateHexColor = function(self)
	return string_format("ff%02x%02x%02x", math_floor(self[1]*255), math_floor(self[2]*255), math_floor(self[3]*255))
end

ColorTemplate.GenerateHexColorMarkup = function(self)
	return "|c" .. self:GenerateHexColor()
end

-- Public API
-----------------------------------------------------------------
-- Returns a populated color table, but doesn't affect our original.
LibColorTool.GetColorTable = function(self, target)
	return copyTable(Colors, target)
end

local embedMethods = {
	GetColorTable = true
}

LibColorTool.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibColorTool.embeds) do
	LibColorTool:Embed(target)
end

-- Populate Color Tables
-----------------------------------------------------------------
-- some basic ui colors used by all text
Colors.normal = createColor(229/255, 178/255, 38/255)
Colors.highlight = createColor(250/255, 250/255, 250/255)
Colors.title = createColor(255/255, 234/255, 137/255)
Colors.offwhite = createColor(196/255, 196/255, 196/255)
Colors.green = createColor( 25/255, 178/255, 25/255 )
Colors.red = createColor( 204/255, 25/255, 25/255 )

-- player status
Colors.health = createColor(191/255, 0/255, 38/255)
Colors.cast = createColor(229/255, 204/255, 127/255)
Colors.disconnected = createColor(120/255, 120/255, 120/255)
Colors.tapped = createColor(121/255, 101/255, 96/255)
Colors.dead = createColor(121/255, 101/255, 96/255)

-- xp, rep and artifact coloring
Colors.xp = createColor(116/255, 23/255, 229/255) -- xp bar 
Colors.xpValue = createColor(145/255, 77/255, 229/255) -- xp bar text
Colors.rested = createColor(163/255, 23/255, 229/255) -- xp bar while being rested
Colors.restedValue = createColor(203/255, 77/255, 229/255) -- xp bar text while being rested
Colors.restedBonus = createColor(69/255, 17/255, 134/255) -- rested bonus bar
Colors.artifact = createColor(229/255, 204/255, 127/255) -- artifact or azerite power bar

-- quest difficulty coloring 
Colors.quest = {}
Colors.quest.red = createColor(204/255, 26/255, 26/255)
Colors.quest.orange = createColor(255/255, 106/255, 26/255)
Colors.quest.yellow = createColor(255/255, 178/255, 38/255)
Colors.quest.green = createColor(89/255, 201/255, 89/255)
Colors.quest.gray = createColor(120/255, 120/255, 120/255)

-- Unit Class Coloring
-- Original colors at https://wow.gamepedia.com/Class#Class_colors
-- *Note that for classic, SHAMAN and PALADIN are the same.
Colors.blizzclass = createColorGroup(RAID_CLASS_COLORS)

Colors.class = {}
Colors.class.DEATHKNIGHT = createColor(176/255, 31/255, 79/255)
Colors.class.DEMONHUNTER = createColor(163/255, 48/255, 201/255)
Colors.class.DRUID = createColor(225/255, 125/255, 35/255)
Colors.class.EVOKER = createColor(51/255, 147/255, 127/255)
Colors.class.HUNTER = createColor(191/255, 232/255, 115/255) 
Colors.class.MAGE = createColor(105/255, 204/255, 240/255)
Colors.class.MONK = createColor(0/255, 255/255, 150/255)
Colors.class.PALADIN = createColor(225/255, 160/255, 226/255)
Colors.class.PRIEST = createColor(176/255, 200/255, 225/255)
Colors.class.ROGUE = createColor(255/255, 225/255, 95/255) 
Colors.class.SHAMAN = createColor(32/255, 122/255, 222/255) 
Colors.class.WARLOCK = createColor(148/255, 130/255, 201/255) 
Colors.class.WARRIOR = createColor(229/255, 156/255, 110/255) 
Colors.class.UNKNOWN = createColor(195/255, 202/255, 217/255)

-- debuffs
Colors.debuff = {}
Colors.debuff.none = createColor(204/255, 0/255, 0/255)
Colors.debuff.Magic = createColor(51/255, 153/255, 255/255)
Colors.debuff.Curse = createColor(204/255, 0/255, 255/255)
Colors.debuff.Disease = createColor(153/255, 102/255, 0/255)
Colors.debuff.Poison = createColor(0/255, 153/255, 0/255)
Colors.debuff[""] = createColor(0/255, 0/255, 0/255)

-- faction 
Colors.faction = {}
Colors.faction.Alliance = createColor(74/255, 84/255, 232/255)
Colors.faction.Horde = createColor(229/255, 13/255, 18/255)
Colors.faction.Neutral = createColor(249/255, 158/255, 35/255) 

-- damage feedback
Colors.feedback = {}
Colors.feedback.DAMAGE = createColor(176/255, 79/255, 79/255)
Colors.feedback.CRUSHING = createColor(176/255, 79/255, 79/255)
Colors.feedback.CRITICAL = createColor(176/255, 79/255, 79/255)
Colors.feedback.GLANCING = createColor(176/255, 79/255, 79/255)
Colors.feedback.STANDARD = createColor(214/255, 191/255, 165/255)
Colors.feedback.IMMUNE = createColor(214/255, 191/255, 165/255)
Colors.feedback.ABSORB = createColor(214/255, 191/255, 165/255)
Colors.feedback.BLOCK = createColor(214/255, 191/255, 165/255)
Colors.feedback.RESIST = createColor(214/255, 191/255, 165/255)
Colors.feedback.MISS = createColor(214/255, 191/255, 165/255)
Colors.feedback.HEAL = createColor(84/255, 150/255, 84/255)
Colors.feedback.CRITHEAL = createColor(84/255, 150/255, 84/255)
Colors.feedback.ENERGIZE = createColor(79/255, 114/255, 160/255)
Colors.feedback.CRITENERGIZE = createColor(79/255, 114/255, 160/255)

-- power
Colors.power = {}
Colors.power.ENERGY = createColor(254/255, 245/255, 145/255) -- Rogues, Druids
Colors.power.FURY = createColor(255/255, 0/255, 111/255) -- Vengeance Demon Hunter
Colors.power.FOCUS = createColor(125/255, 168/255, 195/255) -- Hunter Pets
Colors.power.INSANITY = createColor(102/255, 64/255, 204/255) -- Shadow Priests 
Colors.power.LUNAR_POWER = createColor(121/255, 152/255, 192/255) -- Balance Druid Astral Power 
Colors.power.MAELSTROM = createColor(0/255, 188/255, 255/255) -- Elemental Shamans
Colors.power.MANA = createColor(80/255, 116/255, 255/255) -- Druid, Hunter, Mage, Paladin, Priest, Shaman, Warlock
Colors.power.PAIN = createColor(142/255, 191/255, 0/255) 
Colors.power.RAGE = createColor(215/255, 7/255, 7/255) -- Druids, Warriors
Colors.power.RUNIC_POWER = createColor(0/255, 236/255, 255/255) -- Death Knights

-- Secondary Resource Colors
Colors.power.ARCANE_CHARGES = createColor(121/255, 152/255, 192/255) -- Arcane Mage
Colors.power.CHI = createColor(126/255, 255/255, 163/255) -- Monk 
Colors.power.COMBO_POINTS = createColor(255/255, 0/255, 30/255) -- Rogues, Druids
Colors.power.HOLY_POWER = createColor(245/255, 254/255, 145/255) -- Retribution Paladins 
Colors.power.RUNES = createColor(100/255, 155/255, 225/255) -- Death Knight 
Colors.power.SOUL_FRAGMENTS = createColor(148/255, 130/255, 201/255) -- Demon Hunter
Colors.power.SOUL_SHARDS = createColor(148/255, 130/255, 201/255) -- Warlock 

-- Coloring when modules use a different color for each point.
-- Weirdly enough we're only using to to produce an alternate color.
-- This will be changed later, it was just the fastest way to a goal right now.
Colors.power.COMBO_POINTS_MULTIPLE = {
	createColor(225/255, 65/255, 30/255), 
	createColor(225/255, 65/255, 30/255), 
	createColor(225/255, 65/255, 30/255), 
	createColor(225/255, 65/255, 30/255), 
	createColor(225/255, 65/255, 30/255) 
}

-- GUI2 style
--Colors.power.COMBO_POINTS_MULTIPLE = {
--	createColor{ 0.89, 0.00, 0.00 },
--	createColor{ 0.89, 0.35, 0.00 },
--	createColor{ 0.89, 0.65, 0.00 },
--	createColor{ 0.89, 0.89, 0.00 },
--	createColor{ 0.00, 0.89, 0.00 }
--}

-- Alternate Power
Colors.power.ALTERNATE = createColor(70/255, 255/255, 131/255)

-- Vehicle Powers
Colors.power.AMMOSLOT = createColor(204/255, 153/255, 0/255)
Colors.power.FUEL = createColor(0/255, 140/255, 127/255)
Colors.power.STAGGER = {}
Colors.power.STAGGER[1] = createColor(132/255, 255/255, 132/255) 
Colors.power.STAGGER[2] = createColor(255/255, 250/255, 183/255) 
Colors.power.STAGGER[3] = createColor(255/255, 107/255, 107/255) 

-- Fallback for the rare cases where an unknown type is requested.
Colors.power.UNUSED = createColor(195/255, 202/255, 217/255) 

-- Allow us to use power type index to get the color
-- FrameXML/UnitFrame.lua
Colors.power[0] = Colors.power.MANA
Colors.power[1] = Colors.power.RAGE
Colors.power[2] = Colors.power.FOCUS
Colors.power[3] = Colors.power.ENERGY
Colors.power[4] = Colors.power.CHI
Colors.power[5] = Colors.power.RUNES
Colors.power[6] = Colors.power.RUNIC_POWER
Colors.power[7] = Colors.power.SOUL_SHARDS
Colors.power[8] = Colors.power.LUNAR_POWER
Colors.power[9] = Colors.power.HOLY_POWER
Colors.power[11] = Colors.power.MAELSTROM
Colors.power[13] = Colors.power.INSANITY
Colors.power[17] = Colors.power.FURY
Colors.power[18] = Colors.power.PAIN

-- reactions
Colors.reaction = {}
Colors.reaction[1] = createColor(205/255, 46/255, 36/255) -- hated
Colors.reaction[2] = createColor(205/255, 46/255, 36/255) -- hostile
Colors.reaction[3] = createColor(192/255, 68/255, 0/255) -- unfriendly
Colors.reaction[4] = createColor(249/255, 188/255, 65/255) -- neutral 
Colors.reaction[5] = createColor( 64/255, 131/255, 38/255) -- friendly
Colors.reaction[6] = createColor( 64/255, 131/255, 69/255) -- honored
Colors.reaction[7] = createColor( 64/255, 131/255, 104/255) -- revered
Colors.reaction[8] = createColor( 64/255, 131/255, 131/255) -- exalted
Colors.reaction.civilian = createColor(64/255, 131/255, 38/255) -- used for friendly player nameplates

-- friendship
-- just using this as pointers to the reaction colors, 
-- so there won't be a need to ever edit these.
Colors.friendship = {}
Colors.friendship[1] = Colors.reaction[3] -- Stranger
Colors.friendship[2] = Colors.reaction[4] -- Acquaintance 
Colors.friendship[3] = Colors.reaction[5] -- Buddy
Colors.friendship[4] = Colors.reaction[6] -- Friend (honored color)
Colors.friendship[5] = Colors.reaction[7] -- Good Friend (revered color)
Colors.friendship[6] = Colors.reaction[8] -- Best Friend (exalted color)
Colors.friendship[7] = Colors.reaction[8] -- Best Friend (exalted color) - brawler's stuff
Colors.friendship[8] = Colors.reaction[8] -- Best Friend (exalted color) - brawler's stuff

-- player specializations
Colors.specialization = {}
Colors.specialization[1] = createColor( 0/255, 215/255, 59/255)
Colors.specialization[2] = createColor(217/255, 33/255, 0/255)
Colors.specialization[3] = createColor(218/255, 30/255, 255/255)
Colors.specialization[4] = createColor( 48/255, 156/255, 255/255)

-- timers (breath, fatigue, etc)
Colors.timer = {}
Colors.timer.UNKNOWN = createColor(179/255, 77/255, 0/255) -- fallback for timers and unknowns
Colors.timer.EXHAUSTION = createColor(179/255, 77/255, 0/255)
Colors.timer.BREATH = createColor(0/255, 128/255, 255/255)
Colors.timer.DEATH = createColor(217/255, 90/255, 0/255) 
Colors.timer.FEIGNDEATH = createColor(217/255, 90/255, 0/255) 

-- threat
Colors.threat = {}
Colors.threat[0] = Colors.reaction[4] -- not really on the threat table
Colors.threat[1] = createColor(249/255, 158/255, 35/255) -- tanks having lost threat, dps overnuking 
Colors.threat[2] = createColor(255/255, 96/255, 12/255) -- tanks about to lose threat, dps getting aggro
Colors.threat[3] = createColor(255/255, 0/255, 0/255) -- securely tanking, or totally fucked :) 

-- zone names
Colors.zone = {}
Colors.zone.arena = createColor(175/255, 76/255, 56/255)
Colors.zone.combat = createColor(175/255, 76/255, 56/255) 
Colors.zone.contested = createColor(229/255, 159/255, 28/255)
Colors.zone.friendly = createColor(64/255, 175/255, 38/255) 
Colors.zone.hostile = createColor(175/255, 76/255, 56/255) 
Colors.zone.sanctuary = createColor(104/255, 204/255, 239/255)
Colors.zone.unknown = createColor(255/255, 234/255, 137/255) -- instances, bgs, contested zones on pve realms 

-- item rarity coloring
Colors.blizzquality = createColorGroup(ITEM_QUALITY_COLORS)
Colors.quality = {}
Colors.quality[0] = createColor(157/255, 157/255, 157/255) -- Poor
Colors.quality[1] = createColor(240/255, 240/255, 240/255) -- Common
Colors.quality[2] = createColor( 30/255, 178/255, 0/255) -- Uncommon
Colors.quality[3] = createColor( 0/255, 112/255, 221/255) -- Rare
Colors.quality[4] = createColor(163/255, 53/255, 238/255) -- Epic
Colors.quality[5] = createColor(225/255, 96/255, 0/255) -- Legendary
Colors.quality[6] = createColor(230/255, 204/255, 128/255) -- Artifact
Colors.quality[7] = createColor( 79/255, 196/255, 225/255) -- Heirloom
Colors.quality[8] = createColor( 79/255, 196/255, 225/255) -- Blizard

-- world quest quality coloring
-- *using item rarities for these colors
-- *the globals I use for reference are gone in 9.0.1.
-- *change to Enums. Will look them up!
Colors.worldquestquality = {}
Colors.worldquestquality[LE_WORLD_QUEST_QUALITY_COMMON or 1] = Colors.quality[1]
Colors.worldquestquality[LE_WORLD_QUEST_QUALITY_RARE or 2] = Colors.quality[3]
Colors.worldquestquality[LE_WORLD_QUEST_QUALITY_EPIC or 3] = Colors.quality[4]
