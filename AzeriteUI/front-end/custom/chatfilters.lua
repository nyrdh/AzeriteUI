local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("ChatFilters", "LibFrame", "LibClientBuild")
--Module:SetIncompatible("Prat-3.0")

-- Lua API
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local pairs = pairs
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_sub = string.sub
local table_insert = table.insert
local tonumber = tonumber
local type = type

-- WoW API
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrame_RemoveMessageEventFilter
local FCF_GetCurrentChatFrame = FCF_GetCurrentChatFrame
local GetFactionInfo = GetFactionInfo
local GetNumFactions = GetNumFactions
local ExpandFactionHeader = ExpandFactionHeader
local UnitFactionGroup = UnitFactionGroup
local RaidNotice_AddMessage = RaidNotice_AddMessage

-- WoW Objects
local CHAT_FRAMES = CHAT_FRAMES

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetLayout = Private.GetLayout
local GetMedia = Private.GetMedia

-- Constants
local IsClassic = Module:IsClassic()
local IsRetail = Module:IsRetail()

-- Caches
local Templates = {}

-- Method Caches
local ChatFrame_AddMessage = {}

-- TODO!
-- - Gather all output patterns in a table
-- - Gather all filters in a system,
--   with event, conditionals and solutions.

local PlayerFaction, PlayerFactionLabel = UnitFactionGroup("player")

-- Chat output templates
local sign, value, label = "|cffeaeaea", "|cfff0f0f0", "|cffffb200"
local red = "|cffcc0000"
local green = "|cff00cc00"
local gray = "|cff888888"
local yellow = "|cffffb200"
local orange = "|cffff6600"
local gain, loss, busy = gray, red, yellow

local ACHIEVEMENT_TEMPLATE = "!%s: %s"
local HONOR_KILL_TEMPLATE = gain.."+|r "..value.."%d|r "..label.."%s:|r %s "..sign.."(%d %s)|r"
local HONOR_BONUS_TEMPLATE = gain.."+|r "..value.."%d|r "..label.."%s|r"
local HONOR_BATTLEFIELD_TEMPLATE = "%s: "..value.."%d|r "..label.."%s|r"
local LOOT_TEMPLATE = gain.."+|r %s"
local LOOT_TEMPLATE_MULTIPLE = gain.."+|r %s "..sign.."(%d)|r"
local LOOT_MINUS_TEMPLATE = loss.."- %s|r"
local REP_TEMPLATE = gain.."+ %s:|r %s"
local REP_TEMPLATE_MULTIPLE = gain.."+|r "..value.."%d|r "..sign.."%s:|r %s"
local XP_TEMPLATE = gain.."+|r "..value.."%d|r "..sign.."%s|r"
local XP_TEMPLATE_MULTIPLE = gain.."+|r "..value.."%d|r "..sign.."%s:|r "..label.."%s|r"
local AFK_ADDED_TEMPLATE = busy.."+ "..FRIENDS_LIST_AWAY.."|r"
local AFK_ADDED_TEMPLATE_MESSAGE = busy.."+ "..FRIENDS_LIST_AWAY..": |r"..value.."%s|r"
local AFK_CLEARED_TEMPLATE = green.."- "..FRIENDS_LIST_AWAY.."|r"
local DND_ADDED_TEMPLATE = orange.."+ "..FRIENDS_LIST_BUSY.."|r"
local DND_ADDED_TEMPLATE_MESSAGE = orange.."+ "..FRIENDS_LIST_BUSY..": |r"..value.."%s|r"
local DND_CLEARED_TEMPLATE = green.."- "..FRIENDS_LIST_BUSY.."|r"
local RESTED_ADDED_TEMPLATE = gain.."+ "..TUTORIAL_TITLE26.."|r"
local RESTED_CLEARED_TEMPLATE = busy.."- "..TUTORIAL_TITLE26.."|r"
local SKILL_TEMPLATE = gain.."+|r %s "..sign.."(%d)|r"

-- Get the current game client locale.
-- We're treating enGB on old clients as enUS, as it's the same in-game anyway.
local getFilter = function(msg)
	msg = string_gsub(msg, "%%d", "(%%d+)")
	msg = string_gsub(msg, "%%s", "(.+)")
	msg = string_gsub(msg, "%%(%d+)%$d", "%%%%%1$(%%d+)")
	msg = string_gsub(msg, "%%(%d+)%$s", "%%%%%1$(%%s+)")
	return msg
end

-- Money Icon Strings
local L_GOLD = string_format([[|T%s:16:16:-2:0:64:64:%d:%d:%d:%d|t]], GetMedia("coins"), 0,32,0,32)
local L_SILVER = string_format([[|T%s:16:16:-2:0:64:64:%d:%d:%d:%d|t]], GetMedia("coins"), 32,64,0,32)
local L_COPPER = string_format([[|T%s:16:16:-2:0:64:64:%d:%d:%d:%d|t]], GetMedia("coins"), 0,32,32,64)

-- Search Patterns
local P_GOLD = getFilter(GOLD_AMOUNT) -- "%d Gold"
local P_SILVER = getFilter(SILVER_AMOUNT) -- "%d Silver"
local P_COPPER = getFilter(COPPER_AMOUNT) -- "%d Copper"

-- Patterns to identify loot
local LootPatterns = {}
for i,global in ipairs({
	"LOOT_ITEM_CREATED_SELF", -- "You create: %s."
	"LOOT_ITEM_SELF_MULTIPLE", -- "You receive loot: %sx%d."
	"LOOT_ITEM_SELF", -- "You receive loot: %s."
	"LOOT_ITEM_PUSHED_SELF_MULTIPLE", -- "You receive item: %sx%d."
	"LOOT_ITEM_PUSHED_SELF", -- "You receive item: %s."

	-- Only exists in retail, I think(?)
	"CURRENCY_GAINED", -- "You receive currency: %s."
	"CURRENCY_GAINED_MULTIPLE", -- "You receive currency: %s x%d."
	"CURRENCY_GAINED_MULTIPLE_BONUS", -- "You receive currency: %s x%d. (Bonus Objective)"

}) do
	local msg = _G[global]
	if (msg) then
		table_insert(LootPatterns, getFilter(msg))
	end
end

-- Patterns to identify reputation changes
local FactionPatterns = {}
for i,global in ipairs({
	"FACTION_STANDING_INCREASED", -- "Your %s reputation has increased by %d."
	--"FACTION_STANDING_DECREASED", -- "Your %s reputation has decreased by %d."
	"FACTION_STANDING_INCREASED_GENERIC", -- "Reputation with %s increased."
	--"FACTION_STANDING_DECREASED_GENERIC", -- "Reputation with %s decreased."
}) do
	local msg = _G[global]
	if (msg) then
		table_insert(FactionPatterns, getFilter(msg))
	end
end

-- Localized search patterns created from global strings.
local FilteredGlobals = {}
for i,global in ipairs({
	-- Verified to work
	-----------------------------------------
	-- CHAT_MSG_COMBAT_HONOR_GAIN
	"COMBATLOG_HONORAWARD", -- "You have been awarded %d honor points."
	"COMBATLOG_HONORGAIN", -- "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"

	-- CHAT_MSG_LOOT
	"CREATED_ITEM", -- "%s creates: %s."
	"CREATED_ITEM_MULTIPLE", -- "%s creates: %sx%d."
	"LOOT_ITEM", -- "%s receives loot: %s."
	"LOOT_ITEM_MULTIPLE", -- "%s receives loot: %sx%d."

	"LOOT_ITEM_CREATED_SELF", -- "You create: %s."
	"LOOT_ITEM_SELF_MULTIPLE", -- "You receive loot: %sx%d."
	"LOOT_ITEM_SELF", -- "You receive loot: %s."
	"LOOT_ITEM_PUSHED_SELF_MULTIPLE", -- "You receive item: %sx%d."
	"LOOT_ITEM_PUSHED_SELF", -- "You receive item: %s."

	-- CHAT_MSG_MONEY
	"YOU_LOOT_MONEY", -- "You loot %s"

	-- CHAT_MSG_SYSTEM
	"ERR_BG_PLAYER_JOINED_SS", -- "|Hplayer:%s|h[%s]|h has joined the battle"
	"ERR_BG_PLAYER_LEFT_S", -- "%s has left the battle"
	"ERR_INSTANCE_GROUP_ADDED_S", -- "%s has joined the instance group."
	"ERR_INSTANCE_GROUP_REMOVED_S", -- "%s has left the instance group."
	"ERR_PLAYER_DIED_S", -- "%s has died."

	-- The rest
	-----------------------------------------
	"CHAT_IGNORED", -- "%s is ignoring you."
	"ERR_NOT_IN_RAID", -- "You are not in a raid group"
	"ERR_RAID_MEMBER_ADDED_S", -- "%s has joined the raid group"
	"ERR_RAID_MEMBER_REMOVED_S", -- "%s has left the raid group"
	"ERR_PLAYER_JOINED_BATTLE_D", -- "%s has joined the battle."
	"ERR_PLAYER_LEFT_BATTLE_D", -- "%s has left the battle."
	"ERR_TRADE_BLOCKED_S", -- "%s has requested to trade.  You have refused."
	-- Only added by Blizzard's filter, which we disable.
	-- These would have to be intercepted by AddMessage if removed otherwise.
	--"ERR_PLAYERLIST_JOINED_BATTLE", -- "%d players have joined the battle: %s"
	--"ERR_PLAYERLIST_LEFT_BATTLE", -- "%d players have left the battle: %s"
	--"ERR_PLAYERS_JOINED_BATTLE_D", -- "%d players have joined the battle."
	--"ERR_PLAYERS_LEFT_BATTLE_D", -- "%d players have left the battle."
}) do
	local msg = _G[global]
	if (msg) then
		msg = string_gsub(msg, "%(", "%%(");
		msg = string_gsub(msg, "%)", "%%)");
		msg = string_gsub(msg, "%[", "%%[");
		msg = string_gsub(msg, "%]", "%%]");
		table_insert(FilteredGlobals, getFilter(msg))
	end
end

-- Replacements done by the AddMessage methods.
-- The order here matters.
-- Also note that any chat filters are applied before this,
-- anything going through this method is at the very end of the chain.
-- Not counting other addons that also replace this method. 
local Replacements = {}
-- uncomment to break the chat
-- for development purposes only. weird stuff happens when used. 
--table_insert(Replacements, { "|", "||" })

-- player realm id [ colorCode name realm ]
table_insert(Replacements, { "|Hplayer:(.-)-(.-):(.-)|h%[|c(%w%w%w%w%w%w%w%w)(.-)-(.-)|r%]|h", "|Hplayer:%1-%2:%3|h|c%4%5|r|h" })

-- We have removed the brackets through our filters, need to catch that.
table_insert(Replacements, { "|Hplayer:(.-)-(.-):(.-)|h|c(%w%w%w%w%w%w%w%w)(.-)-(.-)|r|h", "|Hplayer:%1-%2:%3|h|c%4%5|r|h" })

-- player realm id [ colorCode name ]
--table_insert(Replacements, { "|Hplayer:(.-)-(.-):(.-)|h%[%|c(%w%w%w%w%w%w%w%w)(.-)-(.-)|r%]|h", "|Hplayer:%1-%2:%3|h|c%4%5|r|h" })

table_insert(Replacements, { "|Hplayer:(.-)|h%[(.-)%]|h", "|Hplayer:%1|h%2|h" })
table_insert(Replacements, { "|HBNplayer:(.-)|h%[(.-)%]|h", "|HBNplayer:%1|h%2|h" })
if (IsClassic) then
	table_insert(Replacements, 	{ "%["..string_match(CHAT_BATTLEGROUND_LEADER_GET, "%[(.-)%]") .. "%]", "BGL" })
	table_insert(Replacements, 	{ "%["..string_match(CHAT_BATTLEGROUND_GET, "%[(.-)%]") .. "%]", "BG" })
end
table_insert(Replacements, 	{ "%["..string_match(CHAT_PARTY_LEADER_GET, "%[(.-)%]") .. "%]", "PL" })
table_insert(Replacements, 	{ "%["..string_match(CHAT_PARTY_GET, "%[(.-)%]") .. "%]", "P" })
table_insert(Replacements, 	{ "%["..string_match(CHAT_RAID_LEADER_GET, "%[(.-)%]") .. "%]", "RL" })
table_insert(Replacements, 	{ "%["..string_match(CHAT_RAID_GET, "%[(.-)%]") .. "%]", "R" })
table_insert(Replacements, 	{ "%["..string_match(CHAT_INSTANCE_CHAT_LEADER_GET, "%[(.-)%]") .. "%]", "IL" })
table_insert(Replacements, 	{ "%["..string_match(CHAT_INSTANCE_CHAT_GET, "%[(.-)%]") .. "%]", "I" })
table_insert(Replacements, 	{ "%["..string_match(CHAT_GUILD_GET, "%[(.-)%]") .. "%]", "G" })
table_insert(Replacements, 	{ "%["..string_match(CHAT_OFFICER_GET, "%[(.-)%]") .. "%]", "O" })
table_insert(Replacements, 	{ "%["..string_match(CHAT_RAID_WARNING_GET, "%[(.-)%]") .. "%]", "|cffff0000!|r" })
table_insert(Replacements, 	{ "|Hchannel:(%w+):(%d)|h%[(%d)%. (%w+)%]|h", "|Hchannel:%1:%2|h%3.|h" }) -- numbered channels
table_insert(Replacements, 	{ "|Hchannel:(%w+)|h%[(%w+)%]|h", "|Hchannel:%1|h%2|h" }) -- non-numbered channels 
table_insert(Replacements, 	{ "^To (.-|h)", "|cffad2424@|r%1" })
table_insert(Replacements, 	{ "^(.-|h) whispers", "%1" })
table_insert(Replacements, 	{ "^(.-|h) says", "%1" })
table_insert(Replacements, 	{ "^(.-|h) yells", "%1" })
table_insert(Replacements, 	{ "<"..AFK..">", "|cffFF0000<"..AFK..">|r " })
table_insert(Replacements, 	{ "<"..DND..">", "|cffE7E716<"..DND..">|r " })

-- Custom method for filtering messages
local ChatFrameAddMessageFiltered = function(frame, msg, r, g, b, chatID, ...)
	if (not msg) or (msg == "") then
		return
	end

	-- Only do this if the option is enabled,
	-- but always go through our proxy method here regardless.
	if (Module.db.enableAllChatFilters) then
		for i,info in ipairs(Replacements) do
			msg = string_gsub(msg, info[1], info[2])
		end
	end

	-- Replace color codes. 
	-- This is part of the UI design, so we enforce it.
	for i,color in pairs(Colors.blizzquality) do
		msg = string_gsub(msg, color.colorCode, Colors.quality[i].colorCode)
	end

	-- Replace class colors.
	-- Make sure to not check for shamans on alliance characters or paladins on horde characters,
	-- as blizzard are still using the same color for these two in classic.
	for i,color in pairs(Colors.blizzclass) do
		local skip = IsClassic and ((PlayerFaction == "Alliance" and i == "SHAMAN") or (PlayerFaction == "Horde" and i == "PALADIN"))
		if (not skip) then
			msg = string_gsub(msg, color.colorCode, Colors.class[i].colorCode)
		end
	end

	-- Return the new message to the old method
	return ChatFrame_AddMessage[frame](frame, msg, r, g, b, chatID, ...)
end

-- Proxy functions to module methods,
-- primarily used to directly hook blizzard functions.
local ChatFilterProxy = function(...) return Module:OnChatMessage(...) end
local ChatSetupProxy = function(...) return Module:OnCreateChatFrame(...) end

-- Make the money display pretty
local CreateMoneyString = function(gold, silver, copper)
	local moneyString

	if (gold > 0) then 
		moneyString = string_format("|cfff0f0f0%d|r%s", gold, L_GOLD)
	end

	if (silver > 0) then 
		moneyString = (moneyString and moneyString.." " or "") .. string_format("|cfff0f0f0%d|r%s", silver, L_SILVER)
	end

	if (copper > 0) then 
		moneyString = (moneyString and moneyString.." " or "") .. string_format("|cfff0f0f0%d|r%s", copper, L_COPPER)
	end 

	return moneyString
end

local SendMonsterMessage = function(chatType, message, monster, ...)
	RaidNotice_AddMessage(RaidBossEmoteFrame, string_format(message, monster), ChatTypeInfo[chatType])
end

Module.UpdateChatFilters = function(self)
	-- Styling
	if (self.db.enableChatStyling) then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", ChatFilterProxy) -- reputation
		ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", ChatFilterProxy) -- xp
		ChatFrame_AddMessageEventFilter("CHAT_MSG_CURRENCY", ChatFilterProxy) -- money loot
		ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", ChatFilterProxy) -- item loot
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", ChatFilterProxy) -- money loot
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SKILL", ChatFilterProxy) -- skill ups
		if (IsRetail) then
			ChatFrame_AddMessageEventFilter("CHAT_MSG_ACHIEVEMENT", ChatFilterProxy)
		end
	else
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", ChatFilterProxy) -- reputation
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", ChatFilterProxy) -- xp
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CURRENCY", ChatFilterProxy) -- money loot
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_LOOT", ChatFilterProxy) -- item loot
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONEY", ChatFilterProxy) -- money loot
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SKILL", ChatFilterProxy) -- skill ups
		if (IsRetail) then
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_ACHIEVEMENT", ChatFilterProxy)
		end
	end

	-- Monster Filter
	if (self.db.enableMonsterFilter) then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_SAY", ChatFilterProxy)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_YELL", ChatFilterProxy)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", ChatFilterProxy)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_WHISPER", ChatFilterProxy)
	else
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_SAY", ChatFilterProxy)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_YELL", ChatFilterProxy)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", ChatFilterProxy)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_WHISPER", ChatFilterProxy)
	end

	-- Boss Filter
	if (self.db.enableBossFilter) then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_BOSS_EMOTE", ChatFilterProxy)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_BOSS_WHISPER", ChatFilterProxy)
	else
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_RAID_BOSS_EMOTE", ChatFilterProxy)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_RAID_BOSS_WHISPER", ChatFilterProxy)
	end

	-- Spam Filter
	if (self.db.enableSpamFilter) then
		-- This kills off blizzard's interfering bg spam filter,
		-- and prevents it from adding their additional leave/join messages.
		BattlegroundChatFilters:StopBGChatFilter()
		BattlegroundChatFilters:UnregisterAllEvents()
		BattlegroundChatFilters:SetScript("OnUpdate", nil)
		BattlegroundChatFilters:SetScript("OnEvent", nil)
	else
		-- (Re)start blizzard's interfering bg spam filter,
		-- which in my opinion creates as much spam as it removes.
		BattlegroundChatFilters:OnLoad()
		BattlegroundChatFilters:SetScript("OnEvent", BattlegroundChatFilters.OnEvent)
		if (not BattlegroundChatFilters:GetScript("OnUpdate")) then
			local _, instanceType = IsInInstance()
			if (instanceType == "pvp") then
				BattlegroundChatFilters:StartBGChatFilter()
			end
		end
	end

	-- Used by both styling and spam filters.
	if (self.db.enableSpamFilter) or (self.db.enableChatStyling) then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", ChatFilterProxy)
	else
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", ChatFilterProxy)
	end

	--[[--
	if (self.db.enableAllChatFilters) then
		-- Styling
		ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", ChatFilterProxy) -- reputation
		ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", ChatFilterProxy) -- xp
		ChatFrame_AddMessageEventFilter("CHAT_MSG_CURRENCY", ChatFilterProxy) -- money loot
		ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", ChatFilterProxy) -- item loot
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", ChatFilterProxy) -- money loot
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SKILL", ChatFilterProxy) -- skill ups
		if (IsRetail) then
			ChatFrame_AddMessageEventFilter("CHAT_MSG_ACHIEVEMENT", ChatFilterProxy)
		end

		-- Monster Filter
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_SAY", ChatFilterProxy)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_YELL", ChatFilterProxy)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", ChatFilterProxy)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_WHISPER", ChatFilterProxy)

		-- Boss Filter
		ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_BOSS_EMOTE", ChatFilterProxy)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_BOSS_WHISPER", ChatFilterProxy)

		-- Spam Filter and Styling.
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", ChatFilterProxy)

		-- This kills off blizzard's interfering bg spam filter,
		-- and prevents it from adding their additional leave/join messages.
		BattlegroundChatFilters:StopBGChatFilter()
		BattlegroundChatFilters:UnregisterAllEvents()
		BattlegroundChatFilters:SetScript("OnUpdate", nil)
		BattlegroundChatFilters:SetScript("OnEvent", nil)
	else
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", ChatFilterProxy) -- reputation
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", ChatFilterProxy) -- xp
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CURRENCY", ChatFilterProxy) -- money loot
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_LOOT", ChatFilterProxy) -- item loot
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONEY", ChatFilterProxy) -- money loot
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SKILL", ChatFilterProxy) -- skill ups
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_SAY", ChatFilterProxy)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_YELL", ChatFilterProxy)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", ChatFilterProxy)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_WHISPER", ChatFilterProxy)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_RAID_BOSS_EMOTE", ChatFilterProxy)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_RAID_BOSS_WHISPER", ChatFilterProxy)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", ChatFilterProxy)
	
		if (IsRetail) then
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_ACHIEVEMENT", ChatFilterProxy)
		end

		-- (Re)start blizzard's interfering bg spam filter,
		-- which in my opinion creates as much spam as it removes.
		BattlegroundChatFilters:OnLoad()
		BattlegroundChatFilters:SetScript("OnEvent", BattlegroundChatFilters.OnEvent)
		if (not BattlegroundChatFilters:GetScript("OnUpdate")) then
			local _, instanceType = IsInInstance()
			if (instanceType == "pvp") then
				BattlegroundChatFilters:StartBGChatFilter()
			end
		end
	end
	--]]--
end

-- Apply custom methods to the chat frames
Module.OnCreateChatFrame = function(self, frame)
	if (ChatFrame_AddMessage[frame]) then
		return
	end

	-- Copy the current AddMessage method from the frame.
	-- *this also functions as our "has been handled" indicator.
	ChatFrame_AddMessage[frame] = frame.AddMessage

	-- Replace with our filtered AddMessage method.
	frame.AddMessage = ChatFrameAddMessageFiltered
end

-- Handler for most chat filters
Module.OnChatMessage = function(self, frame, event, message, author, ...)
	if (message == ERR_NOT_IN_RAID) then
		return true
	
	elseif (event == "CHAT_MSG_MONEY") then
		local gold_amount = tonumber(string_match(message, P_GOLD)) or 0
		local silver_amount = tonumber(string_match(message, P_SILVER)) or 0
		local copper_amount = tonumber(string_match(message, P_COPPER)) or 0

		local moneyString = CreateMoneyString(gold_amount, silver_amount, copper_amount)
		if (moneyString) then
			return false, string_format(LOOT_TEMPLATE, moneyString), author, ...
		else
			return true
		end

	elseif (event == "CHAT_MSG_COMBAT_FACTION_CHANGE") then

		for i,pattern in ipairs(FactionPatterns) do
			local faction,value
			local a,b = string_match(message,pattern)
			if (type(a) == "string") then
				faction = a
				value = b
			elseif (type(b) == "string") then
				faction = b
				value = a
			end
			if (faction) then
				local standingID, factionID
				for i = 1, GetNumFactions() do
					local factionName, description, standingId, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionId, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)
					if (factionName == faction) then
						standingID = standingId
						factionID = factionId
						if (factionID) and (standingID) then
							faction = Colors.reaction[standingID].colorCode .. faction .. "|r"
						end
						break
					end
				end
				-- If nothing was found, the header was most likely collapsed.
				-- Going to force all headers to be expanded now, and repeat.
				if (not factionID) then
					for i = GetNumFactions(),1,-1 do
						local factionName, description, standingId, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionId, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)
						if (isHeader) and (isCollapsed) then
							ExpandFactionHeader(i)
						end
					end
					for i = 1, GetNumFactions() do
						local factionName, description, standingId, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionId, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)
						if (factionName == faction) then
							standingID = standingId
							factionID = factionId
							if (factionID) and (standingID) then
								faction = Colors.reaction[standingID].colorCode .. faction .. "|r"
							end
							break
						end
					end
				end
				if (value) then
					return false, string_format(REP_TEMPLATE_MULTIPLE, value, REPUTATION, faction), author, ...
				else
					return false, string_format(REP_TEMPLATE, REPUTATION, faction), author, ...
				end
			end
		end

	elseif (event == "CHAT_MSG_COMBAT_XP_GAIN") then

		-- Monster with rested bonus
		local xp_bonus_pattern = getFilter(COMBATLOG_XPGAIN_EXHAUSTION1) -- "%s dies, you gain %d experience. (%s exp %s bonus)"
		local name, total, xp, bonus = string_match(message, xp_bonus_pattern)
		if (total) then
			return false, string_format(XP_TEMPLATE_MULTIPLE, total, XP, name), author, ...
		end

		-- Quest with rested bonus
		local xp_quest_rested_pattern = getFilter(COMBATLOG_XPGAIN_QUEST) -- "You gain %d experience. (%s exp %s bonus)"
		name, total, xp, bonus = string_match(message, xp_bonus_pattern)
		if (total) then
			return false, string_format(XP_TEMPLATE_MULTIPLE, total, XP, name), author, ...
		end

		-- Named monster
		local xp_normal_pattern = getFilter(COMBATLOG_XPGAIN_FIRSTPERSON) -- "%s dies, you gain %d experience."
		name, total = string_match(message, xp_normal_pattern)
		if (total) then
			return false, string_format(XP_TEMPLATE_MULTIPLE, total, XP, name), author, ...
		end
	
		-- Quest
		local xp_quest_pattern = getFilter(COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED) -- "You gain %d experience."
		total = string_match(message, xp_quest_pattern)
		if (total) then
			return false, string_format(XP_TEMPLATE, total, XP), author, ...
		end

		-- Unknown
		local xp_quest_pattern = getFilter(ERR_QUEST_REWARD_EXP_I) -- "Experience gained: %d."
		total = string_match(message, xp_quest_pattern)
		if (total) then
			return false, string_format(XP_TEMPLATE, total, XP), author, ...
		end

	elseif (event == "CHAT_MSG_SKILL") then
	
		local skillup_pattern = getFilter(SKILL_RANK_UP) -- "Your skill in %s has increased to %d."
		local skill, gain = string_match(message, skillup_pattern)
		if (skill and gain) then
			gain = tonumber(gain)
			if (gain) then
				-- CHAT_MSG_SKILL "Skill"
				return false, string_format(SKILL_TEMPLATE, skill, gain), author, ...
			end
		end

	elseif (event == "CHAT_MSG_MONSTER_SAY") then
		return true

	elseif (event == "CHAT_MSG_MONSTER_YELL") then
		return true

	elseif (event == "CHAT_MSG_MONSTER_EMOTE") then
		SendMonsterMessage("MONSTER_EMOTE", message, author, ...)
		return true

	elseif (event == "CHAT_MSG_MONSTER_WHISPER") then
		return true

	elseif (event == "CHAT_MSG_RAID_BOSS_EMOTE") then
		SendMonsterMessage("RAID_BOSS_EMOTE", message, author, ...)
		return true

	elseif (event == "CHAT_MSG_RAID_BOSS_WHISPER") then
		SendMonsterMessage("RAID_BOSS_WHISPER", message, author, ...)
		return true

	elseif (event == "CHAT_MSG_ACHIEVEMENT") then

		-- Achievement announce
		local achievement_pattern = getFilter(ACHIEVEMENT_BROADCAST) -- "%s has earned the achievement %s!"
		local player_name, achievement = string_match(message, achievement_pattern)
		if (player_name) and (achievement) then

			-- kill brackets
			player_name = string_gsub(player_name, "[%[/%]]", "")
			achievement = string_gsub(achievement, "[%[/%]]", "")
			
			return false, string_format(ACHIEVEMENT_TEMPLATE, player_name, achievement), author, ...
		end

		-- Pass everything else through
		return false, message, author, ...
	else

		-- TODO:
		-- Make a system that pairs patterns with solutions,
		-- describing if it allows multiple, should block, replace, etc.

		if (self.db.enableChatStyling) then

			-- Followers
			if (IsRetail) then
				-- Exhausted
				local follower_exhausted_pattern = getFilter(GARRISON_FOLLOWER_DISBANDED) -- "%s has been exhausted."
				local follower_name = string_match(message, follower_exhausted_pattern)
				if (follower_name) then
					return false, string_format(LOOT_MINUS_TEMPLATE, follower_name), author, ...
				end

				-- Removed
				local follower_removed_pattern = getFilter(GARRISON_FOLLOWER_REMOVED) -- "%s is no longer your follower."
				follower_name = string_match(message, follower_removed_pattern)
				if (follower_name) then
					return false, string_format(LOOT_MINUS_TEMPLATE, follower_name), author, ...
				end

				-- Added
				local follower_added_pattern = getFilter(GARRISON_FOLLOWER_ADDED) -- "%s recruited."
				follower_name = string_match(message, follower_added_pattern)
				if (follower_name) then
					follower_name = string_gsub(follower_name, "[%[/%]]", "") -- kill brackets
					return false, string_format(LOOT_TEMPLATE, follower_name), author, ...
				end

				-- GARRISON_FOLLOWER_LEVEL_UP = "LEVEL UP!"
				-- GARRISON_FOLLOWER_XP_ADDED_ZONE_SUPPORT = "%s has earned %d xp."
				-- GARRISON_FOLLOWER_XP_ADDED_ZONE_SUPPORT_LEVEL_UP = "%s is now level %d!"
				-- GARRISON_FOLLOWER_XP_ADDED_ZONE_SUPPORT_QUALITY_UP = "%s has gained a quality level!"
			end


			-- Discovery XP?
			local xp_discovery_pattern = getFilter(ERR_ZONE_EXPLORED_XP) -- "Discovered %s: %d experience gained"
			local name, total = string_match(message, xp_discovery_pattern)
			if (total) then
				return false, string_format(XP_TEMPLATE_MULTIPLE, total, XP, name), author, ...
			end

			-- Quest money?
			local money_pattern = getFilter(ERR_QUEST_REWARD_MONEY_S) -- "Received %s."
			local money_string = string_match(message, money_pattern)
			if (money_string) then
		
				local gold_amount = tonumber(string_match(money_string, P_GOLD)) or 0
				local silver_amount = tonumber(string_match(money_string, P_SILVER)) or 0
				local copper_amount = tonumber(string_match(money_string, P_COPPER)) or 0
		
				local moneyString = CreateMoneyString(gold_amount, silver_amount, copper_amount)
				if (moneyString) then
					return false, string_format(LOOT_TEMPLATE, moneyString), author, ...
				else
					return true
				end
			end

			-- AFK
			if (message == MARKED_AFK) then -- "You are now AFK."
				return false, AFK_ADDED_TEMPLATE, author, ...
			end
			if (message == CLEARED_AFK) then -- "You are no longer AFK."
				return false, AFK_CLEARED_TEMPLATE, author, ...
			end
			local afk_pattern = getFilter(MARKED_AFK_MESSAGE) -- "You are now AFK: %s"
			local afk_message = string_match(message, afk_pattern)
			if (afk_message) then
				if (afk_message == DEFAULT_AFK_MESSAGE) then -- "Away from Keyboard"
					return false, AFK_ADDED_TEMPLATE, author, ...
				end
				return false, string_format(AFK_ADDED_TEMPLATE_MESSAGE, afk_message), author, ...
			end

			-- DND
			if (message == CLEARED_DND) then -- "You are no longer marked DND."
				return false, DND_CLEARED_TEMPLATE, author, ...
			end
			local dnd_pattern = getFilter(MARKED_DND) -- "You are now DND: %s."
			local dnd_message = string_match(message, dnd_pattern)
			if (dnd_message) then
				if (dnd_message == DEFAULT_DND_MESSAGE) then -- "Do not Disturb"
					return false, DND_ADDED_TEMPLATE, author, ...
				end
				return false, string_format(DND_ADDED_TEMPLATE_MESSAGE, dnd_message), author, ...
			end

			-- Rested
			if (message == ERR_EXHAUSTION_WELLRESTED) then -- "You feel well rested."
				return false, RESTED_ADDED_TEMPLATE, author, ...
			end
			if (message == ERR_EXHAUSTION_NORMAL) then -- "You feel normal."
				return false, RESTED_CLEARED_TEMPLATE, author, ...
			end

			-- Artifact Power?
			if (IsRetail) then
				local artifact_pattern = getFilter(ARTIFACT_XP_GAIN) -- "%s gains %s Artifact Power."
				local artifact, artifactPower = string_match(message, artifact_pattern)
				if (artifact) then
					local first, last = string_find(message, "|c(.+)|r")
					if (first and last) then
						local artifact = string_sub(message, first, last)
						artifact = string_gsub(artifact, "[%[/%]]", "") -- kill brackets
						local countString = string_sub(message, last + 1)
						local artifactPower = tonumber(string_match(countString, "(%d+)"))
						if (artifactPower) and (artifactPower > 1) then
							return false, string_format(REP_TEMPLATE_MULTIPLE, artifactPower, ARTIFACT_POWER, artifact), author, ...
						end
					end
				end
			end

			-- Loot?
			for i,pattern in ipairs(LootPatterns) do
				local item, count = string_match(message,pattern)
				if (item) then
					-- The patterns above tend to fail on the number,
					-- so we do this ugly non-localized hack instead.

					-- |cffffffff|Hitem:itemID:::::|h[display name]|h|r
					local first, last = string_find(message, "|c(.+)|r")
					if (first and last) then
						local item = string_sub(message, first, last)
						item = string_gsub(item, "[%[/%]]", "") -- kill brackets
						local countString = string_sub(message, last + 1)
						local count = tonumber(string_match(countString, "(%d+)"))
						if (count) and (count > 1) then
							return false, string_format(LOOT_TEMPLATE_MULTIPLE, item, count), author, ...
						else
							return false, string_format(LOOT_TEMPLATE, item), author, ...
						end
					else
						return false, string_gsub(message, "|", "||"), author, ...
					end
				end
			end
		end

		-- Hide selected stuff from various other events
		if (self.db.enableSpamFilter) then
			for i,pattern in ipairs(FilteredGlobals) do
				if (string_match(message,pattern)) then
					return true
				end
			end
		end
	end

	-- Pass everything else through
	return false, message, author, ...
end

Module.OnInit = function(self)
	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())

	-- Setup all initial chat frames
	for _,chatFrameName in ipairs(CHAT_FRAMES) do ChatSetupProxy(_G[chatFrameName]) end

	-- Hook creation of temporary windows
	hooksecurefunc("FCF_OpenTemporaryWindow", function() ChatSetupProxy((FCF_GetCurrentChatFrame())) end)
	
	-- Create a secure proxy frame for the menu system
	local callbackFrame = self:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	callbackFrame.UpdateChatFilters = function() self:UpdateChatFilters() end

	-- Register module db with the secure proxy
	for key,value in pairs(self.db) do 
		callbackFrame:SetAttribute(key,value)
	end 

	-- Now that attributes have been defined, attach the onattribute script
	callbackFrame:SetAttribute("_onattributechanged", [=[
		if name then 
			name = string.lower(name); 
		end 
		if (name == "change-enablechatstyling") then
			self:SetAttribute("enableChatStyling", value); 
			self:CallMethod("UpdateChatFilters"); 

		elseif (name == "change-enablemonsterfilter") then
			self:SetAttribute("enableMonsterFilter", value); 
			self:CallMethod("UpdateChatFilters"); 

		elseif (name == "change-enablebossfilter") then
			self:SetAttribute("enableBossFilter", value); 
			self:CallMethod("UpdateChatFilters"); 

		elseif (name == "change-enablespamfilter") then
			self:SetAttribute("enableSpamFilter", value); 
			self:CallMethod("UpdateChatFilters"); 
		end 
	]=])

	-- Attach a getter method for the menu to the module
	self.GetSecureUpdater = function(self) 
		return callbackFrame 
	end

end

Module.OnEnable = function(self)
	self:UpdateChatFilters()
end
