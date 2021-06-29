--[[--

The purpose of this tool is to supply 
basic filters for chat output.

--]]--

local LibChatTool = Wheel:Set("LibChatTool", 32)
if (not LibChatTool) then
	return
end

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibChatTool requires LibClientBuild to be loaded.")

local LibHook = Wheel("LibHook")
assert(LibHook, "LibChatTool requires LibHook to be loaded.")

local LibSecureHook = Wheel("LibSecureHook")
assert(LibSecureHook, "LibChatTool requires LibSecureHook to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibChatTool requires LibEvent to be loaded.")

local LibColorTool = Wheel("LibColorTool")
assert(LibColorTool, "LibChatTool requires LibColorTool to be loaded.")

LibEvent:Embed(LibChatTool)
LibHook:Embed(LibChatTool)
LibSecureHook:Embed(LibChatTool)

-- Library registries
LibChatTool.embeds = LibChatTool.embeds or {}
LibChatTool.filterStatus = LibChatTool.filterStatus or {}
LibChatTool.methodCache = LibChatTool.methodCache or {}

-- Filter Cache
local Filters = {}

-- Speed!
local FilterStatus = LibChatTool.filterStatus

-- Lua API
local ipairs = ipairs
local pairs = pairs
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_sub = string.sub
local table_insert = table.insert
local tonumber = tonumber

-- WoW API
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrame_RemoveMessageEventFilter
local FCF_GetCurrentChatFrame = FCF_GetCurrentChatFrame
local RaidNotice_AddMessage = RaidNotice_AddMessage

-- WoW Objects
local CHAT_FRAMES = CHAT_FRAMES

-- Constants
local Colors = LibColorTool:GetColorTable()
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
T.MONEY_MINUS = gain.."-|r %s"
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

local makePattern = function(msg)
	msg = string_gsub(msg, "%%d", "(%%d+)")
	msg = string_gsub(msg, "%%s", "(.+)")
	msg = string_gsub(msg, "%%(%d+)%$d", "%%%%%1$(%%d+)")
	msg = string_gsub(msg, "%%(%d+)%$s", "%%%%%1$(%%s+)")
	return msg
end

-- Search Pattern Cache.
-- This will generate the pattern on the first lookup.
local P = setmetatable({}, { __index = function(t,k) 
	rawset(t,k,makePattern(k))
	return rawget(t,k)
end })


-- Localized search patterns created from global strings.
-- Anything here is filtered away when the Spam filter is active.
local FilteredGlobals = {}
for i,global in ipairs({
	-- Verified to work
	-----------------------------------------
	-- CHAT_MSG_COMBAT_HONOR_GAIN
	"COMBATLOG_HONORAWARD", -- "You have been awarded %d honor points."
	"COMBATLOG_HONORGAIN", -- "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"

	-- CHAT_MSG_LOOT -- these are by other players, add to loot filter! 
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
		table_insert(FilteredGlobals, makePattern(msg))
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

table_insert(Replacements, { "^To (.-|h)", "|cffad2424@|r%1" })
table_insert(Replacements, { "^(.-|h) whispers", "%1" })
table_insert(Replacements, { "^(.-|h) says", "%1" })
table_insert(Replacements, { "^(.-|h) yells", "%1" })

table_insert(Replacements, { "<"..AFK..">", "|cffFF0000<"..AFK..">|r " })
table_insert(Replacements, { "<"..DND..">", "|cffE7E716<"..DND..">|r " })

--table_insert(Replacements, { "You gained", "Stuff appeared" })

local OnChatMessage = function(frame, event, message, author, ...)


		-- TODO:
		-- Make a system that pairs patterns with solutions,
		-- describing if it allows multiple, should block, replace, etc.

		if (FilterStatus.Styling) then



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

local OnOpenTemporaryWindow = function(...)
	CacheMessageMethod((FCF_GetCurrentChatFrame())) 
end

Filters.Styling = {
	Enable = function(module)
		-- Used by both styling and spam filters.
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", OnChatMessage)
	end,
	Disable = function(module)
		
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
