--[[--

The purpose of this tool is to supply 
basic filters for chat output.

--]]--

local LibChatTool = Wheel:Set("LibChatTool", 7)
if (not LibChatTool) then
	return
end

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibChatTool requires LibClientBuild to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibChatTool requires LibEvent to be loaded.")

local LibColorTool = Wheel("LibColorTool")
assert(LibColorTool, "LibChatTool requires LibColorTool to be loaded.")

LibEvent:Embed(LibChatTool)

-- Library registries
LibChatTool.embeds = LibChatTool.embeds or {}
LibChatTool.filterStatus = LibChatTool.filterStatus or {}
LibChatTool.methodCache = LibChatTool.methodCache or {}

-- Filter Cache
local Filters = {}

-- Speed!
local FilterStatus = LibChatTool.filterStatus
local MethodCache = LibChatTool.methodCache

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

-- Constants
local Colors = LibColorTool:GetColorTable()
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()
local PlayerFaction, PlayerFactionLabel = UnitFactionGroup("player")

-- Output Templates
-----------------------------------------------------------------
-- Chat output color codes
local sign, value, label = "|cffeaeaea", "|cfff0f0f0", "|cffffb200"
local red = "|cffcc0000"
local green = "|cff00cc00"
local gray = "|cff888888"
local yellow = "|cffffb200"
local orange = "|cffff6600"
local gain, loss, busy = gray, red, yellow

-- Chat output templates
local T = {}
T.ACHIEVEMENT = "!%s: %s"
T.HONOR_KILL = gain.."+|r "..value.."%d|r "..label.."%s:|r %s "..sign.."(%d %s)|r"
T.HONOR_BONUS = gain.."+|r "..value.."%d|r "..label.."%s|r"
T.HONOR_BATTLEFIELD = "%s: "..value.."%d|r "..label.."%s|r"
T.LOOT = gain.."+|r %s"
T.LOOT_MULTIPLE = gain.."+|r %s "..sign.."(%d)|r"
T.LOOT_MINUS = loss.."- %s|r"
T.REP = gain.."+ %s:|r %s"
T.REP_MULTIPLE = gain.."+|r "..value.."%d|r "..sign.."%s:|r %s"
T.XP = gain.."+|r "..value.."%d|r "..sign.."%s|r"
T.XP_MULTIPLE = gain.."+|r "..value.."%d|r "..sign.."%s:|r "..label.."%s|r"
T.AFK_ADDED = busy.."+ "..FRIENDS_LIST_AWAY.."|r"
T.AFK_ADDED_MESSAGE = busy.."+ "..FRIENDS_LIST_AWAY..": |r"..value.."%s|r"
T.AFK_CLEARED = green.."- "..FRIENDS_LIST_AWAY.."|r"
T.DND_ADDED = orange.."+ "..FRIENDS_LIST_BUSY.."|r"
T.DND_ADDED_MESSAGE = orange.."+ "..FRIENDS_LIST_BUSY..": |r"..value.."%s|r"
T.DND_CLEARED = green.."- "..FRIENDS_LIST_BUSY.."|r"
T.RESTED_ADDED = gain.."+ "..TUTORIAL_TITLE26.."|r"
T.RESTED_CLEARED = busy.."- "..TUTORIAL_TITLE26.."|r"
T.SKILL = gain.."+|r %s "..sign.."(%d)|r"

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
local L_GOLD_DEFAULT = string_format("|TInterface\\MoneyFrame\\UI-GoldIcon:16:16:2:0|t")
local L_GOLD = L_GOLD_DEFAULT

local L_SILVER_DEFAULT = string_format("|TInterface\\MoneyFrame\\UI-SilverIcon:16:16:2:0|t")
local L_SILVER = L_SILVER_DEFAULT

local L_COPPER_DEFAULT = string_format("|TInterface\\MoneyFrame\\UI-CopperIcon:16:16:2:0|t")
local L_COPPER = L_COPPER_DEFAULT

-- Search Pattern Cache.
-- This will generate the pattern on the first lookup.
local P = setmetatable({}, { __index = function(t,k) 
	rawset(t,k,getFilter(k))
	return rawget(t,k)
end })

-- Patterns to identify loot.
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

-- Patterns to identify reputation changes.
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
-- Anything here is filtered away when the Spam filter is active.
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
table_insert(Replacements, { "%["..string_match(CHAT_PARTY_LEADER_GET, "%[(.-)%]") .. "%]", "PL" })
table_insert(Replacements, { "%["..string_match(CHAT_PARTY_GET, "%[(.-)%]") .. "%]", "P" })
table_insert(Replacements, { "%["..string_match(CHAT_RAID_LEADER_GET, "%[(.-)%]") .. "%]", "RL" })
table_insert(Replacements, { "%["..string_match(CHAT_RAID_GET, "%[(.-)%]") .. "%]", "R" })
table_insert(Replacements, { "%["..string_match(CHAT_INSTANCE_CHAT_LEADER_GET, "%[(.-)%]") .. "%]", "IL" })
table_insert(Replacements, { "%["..string_match(CHAT_INSTANCE_CHAT_GET, "%[(.-)%]") .. "%]", "I" })
table_insert(Replacements, { "%["..string_match(CHAT_GUILD_GET, "%[(.-)%]") .. "%]", "G" })
table_insert(Replacements, { "%["..string_match(CHAT_OFFICER_GET, "%[(.-)%]") .. "%]", "O" })
table_insert(Replacements, { "%["..string_match(CHAT_RAID_WARNING_GET, "%[(.-)%]") .. "%]", "|cffff0000!|r" })
table_insert(Replacements, { "|Hchannel:(%w+):(%d)|h%[(%d)%. (%w+)%]|h", "|Hchannel:%1:%2|h%3.|h" }) -- numbered channels
table_insert(Replacements, { "|Hchannel:(%w+)|h%[(%w+)%]|h", "|Hchannel:%1|h%2|h" }) -- non-numbered channels 
table_insert(Replacements, { "^To (.-|h)", "|cffad2424@|r%1" })
table_insert(Replacements, { "^(.-|h) whispers", "%1" })
table_insert(Replacements, { "^(.-|h) says", "%1" })
table_insert(Replacements, { "^(.-|h) yells", "%1" })
table_insert(Replacements, { "<"..AFK..">", "|cffFF0000<"..AFK..">|r " })
table_insert(Replacements, { "<"..DND..">", "|cffE7E716<"..DND..">|r " })
--table_insert(Replacements, { "You gained", "Stuff appeared" })

-- Utility Functions
-----------------------------------------------------------------
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

local ParseForMoney = function(message)

	-- Remove large number formatting 
	message = string_gsub(message, "(%d)%"..LARGE_NUMBER_SEPERATOR.."(%d)", "%1%2")

	-- Basic old-style parsing first.
	-- Doing it in two steps to limit number of needed function calls.
	local gold = string_match(message, P[GOLD_AMOUNT]) -- "%d Gold"
	local gold_amount = gold and tonumber(gold) or 0
	local silver = string_match(message, P[SILVER_AMOUNT]) -- "%d Silver"
	local silver_amount = silver and tonumber(silver) or 0
	local copper = string_match(message, P[COPPER_AMOUNT]) -- "%d Copper"
	local copper_amount = copper and tonumber(copper) or 0

	-- Now we have to do it the hard way. 
	if (gold_amount == 0) and (silver_amount == 0) and (copper_amount == 0) then

		-- Discover icon and currency existence.
		-- Could definitely simplify this. But. We don't.
		local hasGold, hasSilver, hasCopper
		if (ENABLE_COLORBLIND_MODE == "1") then
			hasGold = string_find(message,"%d"..GOLD_AMOUNT_SYMBOL)
			hasSilver = string_find(message,"%d"..SILVER_AMOUNT_SYMBOL)
			hasCopper = string_find(message,"%d"..COPPER_AMOUNT_SYMBOL)
		else
			hasGold = string_find(message,"(UI%-GoldIcon)")
			hasSilver = string_find(message,"(UI%-SilverIcon)")
			hasCopper = string_find(message,"(UI%-CopperIcon)")
		end

		-- These patterns should work for both coins and symbols. Let's parse!
		if (hasGold) or (hasSilver) or (hasCopper) then
			
			-- Now kill off texture strings, replace with space for number separation.
			message = string_gsub(message, "\124T(.-)\124t", " ") 

			-- Kill off color codes. They might fuck up this thing. 
			message = string_gsub(message, "\124[cC]%x%x%x%x%x%x%x%x", "")
			message = string_gsub(message, "\124[rR]", "")

			-- And again we do it the clunky way, to minimize needed function calls.
			if (hasGold) then
				if (hasSilver) and (hasCopper) then
					gold_amount, silver_amount, copper_amount = string_match(message,"(%d+).*%s+(%d+).*%s+(%d+).*")
					return tonumber(gold_amount) or 0, tonumber(silver_amount) or 0, tonumber(copper_amount) or 0

				elseif (hasSilver) then
					gold_amount, silver_amount = string_match(message,"(%d+).*%s+(%d+).*")
					return tonumber(gold_amount) or 0, tonumber(silver_amount) or 0, 0

				elseif (hasCopper) then
					gold_amount, copper_amount = string_match(message,"(%d+).*%s+(%d+).*")
					return tonumber(gold_amount), 0, tonumber(copper_amount) or 0

				else
					gold_amount = string_match(message,"(%d+).*%s")
					return tonumber(gold_amount) or 0,0,0

				end
			elseif (hasSilver) then
				if (hasCopper) then
					silver_amount, copper_amount = string_match(message,"(%d+).*%s+(%d+).*")
					return 0, tonumber(silver_amount) or 0, tonumber(copper_amount) or 0

				else
					silver_amount = string_match(message,"(%d+).*%s")
					return 0, tonumber(silver_amount) or 0,0

				end
			elseif (hasCopper) then
				copper_amount = string_match(message,"(%d+).*%s")
				return 0,0, tonumber(copper_amount) or 0
			end
		end
		
	end

	return gold_amount, silver_amount, copper_amount
end

-- Custom method for filtering messages
local AddMessageFiltered = function(frame, msg, r, g, b, chatID, ...)
	if (not msg) or (msg == "") then
		return
	end

	local filtered

	-- This can be used for any addon using AceConsole for output spam.
	if (FilterStatus.MaxDps) then
		local addon = "MaxDps"
		local filter = "|cff33ff99"..addon.."|r%:"
		if (string_find(msg, filter)) then
			return
		end
	end

	-- Only do this if the option is enabled,
	-- but always go through our proxy method here regardless.
	if (FilterStatus.Styling) then
		local count
		for i,info in ipairs(Replacements) do
			msg = string_gsub(msg, info[1], info[2])
			if (count) and (count > 0) then
				filtered = true
			end
		end

		-- New 9.0.5 "You gained:"-style of money.
		-- These are neither system- nor money loot events, 
		-- they are simply added to the frame.
		if (not filtered) then
			local moneyString = CreateMoneyString(ParseForMoney(msg))
			if (moneyString) then
				msg = string_format(T.LOOT, moneyString)
			end
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
	return MethodCache[frame](frame, msg, r, g, b, chatID, ...)
end

local SendMonsterMessage = function(chatType, message, monster, ...)
	RaidNotice_AddMessage(RaidBossEmoteFrame, string_format(message, monster), ChatTypeInfo[chatType])
end

-- Apply custom methods to the chat frames
local CacheMessageMethod = function(frame)

	-- Multiple library instances could be hooked, 
	if (not MethodCache[frame]) then

		-- Copy the current AddMessage method from the frame.
		-- *this also functions as our "has been handled" indicator.
		MethodCache[frame] = frame.AddMessage
	end

	-- Replace with our filtered AddMessage method.
	-- We do this always.
	frame.AddMessage = AddMessageFiltered
end

local OnChatMessage = function(frame, event, message, author, ...)
	if (message == ERR_NOT_IN_RAID) then
		return true
	
	elseif (event == "CHAT_MSG_MONEY") then

		local moneyString = CreateMoneyString(ParseForMoney(message))
		if (moneyString) then
			return false, string_format(T.LOOT, moneyString), author, ...
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
				local standingID, factionID, isFriend
				for i = 1, GetNumFactions() do
					local factionName, description, standingId, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionId, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)

					if (factionName == faction) then
						standingID = standingId
						factionID = factionId

						if (IsRetail) then
							local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionID)
							if (friendID) then 
								isFriend = true
							end 
						end
	
						if (factionID) and (standingID) then
							faction = Colors[isFriend and "friendship" or "reaction"][standingID].colorCode .. faction .. "|r"
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

							if (IsRetail) then
								local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionID)
								if (friendID) then 
									isFriend = true
								end 
							end
	
							if (factionID) and (standingID) then
								faction = Colors[isFriend and "friendship" or "reaction"][standingID].colorCode .. faction .. "|r"
							end
							break
						end
					end
				end
				if (value) then
					return false, string_format(T.REP_MULTIPLE, value, REPUTATION, faction), author, ...
				else
					return false, string_format(T.REP, REPUTATION, faction), author, ...
				end
			end
		end

	elseif (event == "CHAT_MSG_COMBAT_XP_GAIN") then

		-- Monster with rested bonus
		local xp_bonus_pattern = P[COMBATLOG_XPGAIN_EXHAUSTION1] -- "%s dies, you gain %d experience. (%s exp %s bonus)"
		local name, total, xp, bonus = string_match(message, xp_bonus_pattern)
		if (total) then
			return false, string_format(T.XP_MULTIPLE, total, XP, name), author, ...
		end

		-- Quest with rested bonus
		local xp_quest_rested_pattern = P[COMBATLOG_XPGAIN_QUEST] -- "You gain %d experience. (%s exp %s bonus)"
		name, total, xp, bonus = string_match(message, xp_bonus_pattern)
		if (total) then
			return false, string_format(T.XP_MULTIPLE, total, XP, name), author, ...
		end

		-- Named monster
		local xp_normal_pattern = P[COMBATLOG_XPGAIN_FIRSTPERSON] -- "%s dies, you gain %d experience."
		name, total = string_match(message, xp_normal_pattern)
		if (total) then
			return false, string_format(T.XP_MULTIPLE, total, XP, name), author, ...
		end
	
		-- Quest
		local xp_quest_pattern = P[COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED] -- "You gain %d experience."
		total = string_match(message, xp_quest_pattern)
		if (total) then
			return false, string_format(T.XP, total, XP), author, ...
		end

		-- Unknown
		local xp_quest_pattern = P[ERR_QUEST_REWARD_EXP_I] -- "Experience gained: %d."
		total = string_match(message, xp_quest_pattern)
		if (total) then
			return false, string_format(T.XP, total, XP), author, ...
		end

	elseif (event == "CHAT_MSG_SKILL") then
	
		local skillup_pattern = P[SKILL_RANK_UP] -- "Your skill in %s has increased to %d."
		local skill, gain = string_match(message, skillup_pattern)
		if (skill and gain) then
			gain = tonumber(gain)
			if (gain) then
				-- CHAT_MSG_SKILL "Skill"
				return false, string_format(T.SKILL, skill, gain), author, ...
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
		local achievement_pattern = P[ACHIEVEMENT_BROADCAST] -- "%s has earned the achievement %s!"
		local player_name, achievement = string_match(message, achievement_pattern)
		if (player_name) and (achievement) then

			-- kill brackets
			player_name = string_gsub(player_name, "[%[/%]]", "")
			achievement = string_gsub(achievement, "[%[/%]]", "")
			
			return false, string_format(T.ACHIEVEMENT, player_name, achievement), author, ...
		end

		-- Pass everything else through
		return false, message, author, ...
	else

		-- TODO:
		-- Make a system that pairs patterns with solutions,
		-- describing if it allows multiple, should block, replace, etc.

		if (FilterStatus.Styling) then

			-- Followers
			if (IsRetail) then
				-- Exhausted
				local follower_exhausted_pattern = P[GARRISON_FOLLOWER_DISBANDED] -- "%s has been exhausted."
				local follower_name = string_match(message, follower_exhausted_pattern)
				if (follower_name) then
					return false, string_format(T.LOOT_MINUS, follower_name), author, ...
				end

				-- Removed
				local follower_removed_pattern = P[GARRISON_FOLLOWER_REMOVED] -- "%s is no longer your follower."
				follower_name = string_match(message, follower_removed_pattern)
				if (follower_name) then
					return false, string_format(T.LOOT_MINUS, follower_name), author, ...
				end

				-- Added
				local follower_added_pattern = P[GARRISON_FOLLOWER_ADDED] -- "%s recruited."
				follower_name = string_match(message, follower_added_pattern)
				if (follower_name) then
					follower_name = string_gsub(follower_name, "[%[/%]]", "") -- kill brackets
					return false, string_format(T.LOOT, follower_name), author, ...
				end

				-- GARRISON_FOLLOWER_LEVEL_UP = "LEVEL UP!"
				-- GARRISON_FOLLOWER_XP_ADDED_ZONE_SUPPORT = "%s has earned %d xp."
				-- GARRISON_FOLLOWER_XP_ADDED_ZONE_SUPPORT_LEVEL_UP = "%s is now level %d!"
				-- GARRISON_FOLLOWER_XP_ADDED_ZONE_SUPPORT_QUALITY_UP = "%s has gained a quality level!"
			end

			-- Discovery XP?
			local xp_discovery_pattern = P[ERR_ZONE_EXPLORED_XP] -- "Discovered %s: %d experience gained"
			local name, total = string_match(message, xp_discovery_pattern)
			if (total) then
				return false, string_format(T.XP_MULTIPLE, total, XP, name), author, ...
			end

			-- Quest money?
			--local money_pattern = P[ERR_QUEST_REWARD_MONEY_S] -- "Received %s."
			--local money_string = string_match(message, money_pattern)
			--if (money_string) then
			--	
			--	local gold_amount = tonumber(string_match(money_string, P[GOLD_AMOUNT])) or 0
			--	local silver_amount = tonumber(string_match(money_string, P[SILVER_AMOUNT])) or 0
			--	local copper_amount = tonumber(string_match(money_string, P[COPPER_AMOUNT])) or 0
			--	
			--	local moneyString = CreateMoneyString(gold_amount, silver_amount, copper_amount)
			--	if (moneyString) then
			--		return false, string_format(T.LOOT, moneyString), author, ...
			--	else
			--		return true
			--	end
			--end

			-- New 9.0.5 "You gained:"-style of money.
			local moneyString = CreateMoneyString(ParseForMoney(message))
			if (moneyString) then
				return false, string_format(T.LOOT, moneyString), author, ...
			end

			-- AFK
			if (message == MARKED_AFK) then -- "You are now AFK."
				return false, T.AFK_ADDED, author, ...
			end
			if (message == CLEARED_AFK) then -- "You are no longer AFK."
				return false, T.AFK_CLEARED, author, ...
			end
			local afk_pattern = P[MARKED_AFK_MESSAGE] -- "You are now AFK: %s"
			local afk_message = string_match(message, afk_pattern)
			if (afk_message) then
				if (afk_message == DEFAULT_AFK_MESSAGE) then -- "Away from Keyboard"
					return false, T.AFK_ADDED, author, ...
				end
				return false, string_format(T.AFK_ADDED_MESSAGE, afk_message), author, ...
			end

			-- DND
			if (message == CLEARED_DND) then -- "You are no longer marked DND."
				return false, T.DND_CLEARED, author, ...
			end
			local dnd_pattern = P[MARKED_DND] -- "You are now DND: %s."
			local dnd_message = string_match(message, dnd_pattern)
			if (dnd_message) then
				if (dnd_message == DEFAULT_DND_MESSAGE) then -- "Do not Disturb"
					return false, T.DND_ADDED, author, ...
				end
				return false, string_format(T.DND_ADDED_MESSAGE, dnd_message), author, ...
			end

			-- Rested
			if (message == ERR_EXHAUSTION_WELLRESTED) then -- "You feel well rested."
				return false, T.RESTED_ADDED, author, ...
			end
			if (message == ERR_EXHAUSTION_NORMAL) then -- "You feel normal."
				return false, T.RESTED_CLEARED, author, ...
			end

			-- Artifact Power?
			if (IsRetail) then
				local artifact_pattern = P[ARTIFACT_XP_GAIN] -- "%s gains %s Artifact Power."
				local artifact, artifactPower = string_match(message, artifact_pattern)
				if (artifact) then
					local first, last = string_find(message, "|c(.+)|r")
					if (first and last) then
						local artifact = string_sub(message, first, last)
						artifact = string_gsub(artifact, "[%[/%]]", "") -- kill brackets
						local countString = string_sub(message, last + 1)
						local artifactPower = tonumber(string_match(countString, "(%d+)"))
						if (artifactPower) and (artifactPower > 1) then
							return false, string_format(T.REP_MULTIPLE, artifactPower, ARTIFACT_POWER, artifact), author, ...
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
							return false, string_format(T.LOOT_MULTIPLE, item, count), author, ...
						else
							return false, string_format(T.LOOT, item), author, ...
						end
					else
						return false, string_gsub(message, "|", "||"), author, ...
					end
				end
			end
		end

		-- Hide selected stuff from various other events
		if (FilterStatus.Spam) then
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

-- Tool API
-----------------------------------------------------------------
LibChatTool.SetChatFilterEnabled = function(self, filterType, shouldEnable)
	local filter = Filters[filterType]
	if (not filter) then
		return
	end
	local filterEnabled = FilterStatus[filterType]
	if (shouldEnable) and (not filterEnabled) then
		FilterStatus[filterType] = true
		filter.Enable(self)

	elseif (not shouldEnable) and (filterEnabled) then
		FilterStatus[filterType] = nil
		filter.Disable(self)
	end
end

LibChatTool.SetChatFilterMoneyTextures = function(self, goldTextureString, silverTextureString, copperTextureString)
	L_GOLD = goldTextureString or L_GOLD_DEFAULT
	L_SILVER = silverTextureString or L_SILVER_DEFAULT
	L_COPPER = copperTextureString or L_COPPER_DEFAULT
end

-- Re-enable all active filters. Use on library updates.
LibChatTool.UpdateAllFilters = function(self)
	for filterType,isEnabled in pairs(FilterStatus) do
		if (isEnabled) then
			local filter = Filters[filterType]
			filter:Disable()
			filter:Enable()
		end
	end
end

local embedMethods = {
	SetChatFilterEnabled = true,
	SetChatFilterMoneyTextures = true
}

LibChatTool.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibChatTool.embeds) do
	LibChatTool:Embed(target)
end

Filters.Styling = {
	Enable = function(module)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", OnChatMessage) -- reputation
		ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", OnChatMessage) -- xp
		ChatFrame_AddMessageEventFilter("CHAT_MSG_CURRENCY", OnChatMessage) -- money loot
		ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", OnChatMessage) -- item loot
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", OnChatMessage) -- money loot
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SKILL", OnChatMessage) -- skill ups
		if (IsRetail) then
			ChatFrame_AddMessageEventFilter("CHAT_MSG_ACHIEVEMENT", OnChatMessage)
		end

		-- Used by both styling and spam filters.
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnChatMessage)
	end,
	Disable = function(module)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", OnChatMessage) -- reputation
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", OnChatMessage) -- xp
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CURRENCY", OnChatMessage) -- money loot
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_LOOT", OnChatMessage) -- item loot
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONEY", OnChatMessage) -- money loot
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SKILL", OnChatMessage) -- skill ups
		if (IsRetail) then
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_ACHIEVEMENT", OnChatMessage)
		end

		-- Used by both styling and spam filters.
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnChatMessage)
	end
}

Filters.Spam = {
	Enable = function(module)

		-- This kills off blizzard's interfering bg spam filter,
		-- and prevents it from adding their additional leave/join messages.
		BattlegroundChatFilters:StopBGChatFilter()
		BattlegroundChatFilters:UnregisterAllEvents()
		BattlegroundChatFilters:SetScript("OnUpdate", nil)
		BattlegroundChatFilters:SetScript("OnEvent", nil)

		-- Used by both styling and spam filters.
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnChatMessage)
	end,
	Disable = function(module)

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

		-- Used by both styling and spam filters.
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", OnChatMessage)
	end
}

Filters.Boss = {
	Enable = function(module)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_BOSS_EMOTE", OnChatMessage)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_BOSS_WHISPER", OnChatMessage)
	end,
	Disable = function(module)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_RAID_BOSS_EMOTE", OnChatMessage)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_RAID_BOSS_WHISPER", OnChatMessage)
	end
}

Filters.Monster = {
	Enable = function(module)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_SAY", OnChatMessage)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_YELL", OnChatMessage)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", OnChatMessage)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_WHISPER", OnChatMessage)
	end,
	Disable = function(module)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_SAY", OnChatMessage)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_YELL", OnChatMessage)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", OnChatMessage)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONSTER_WHISPER", OnChatMessage)
	end
}

-- Just a placeholder for the filter to exist at all.
-- Since it's messages created by addons, we filter it in AddMessage.
Filters.MaxDps = {
	Enable = function(module)
	end,
	Disable = function(module)
	end
}

-- Setup all initial chat frames
for _,chatFrameName in ipairs(CHAT_FRAMES) do 
	CacheMessageMethod(_G[chatFrameName]) 
end

-- Hook creation of temporary windows
hooksecurefunc("FCF_OpenTemporaryWindow", function() 
	CacheMessageMethod((FCF_GetCurrentChatFrame())) 
end)

-- Update existing filters
LibChatTool:UpdateAllFilters()
