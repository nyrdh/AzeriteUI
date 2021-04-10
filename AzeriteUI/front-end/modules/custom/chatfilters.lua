local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("ChatFilters", "LibHook", "LibSecureHook")

-- Lua API
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local math_abs = math.abs
local math_floor = math.floor
local math_mod = math.fmod
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
local GetMoney = GetMoney
local GetNumFactions = GetNumFactions
local ExpandFactionHeader = ExpandFactionHeader
local UnitFactionGroup = UnitFactionGroup
local UnitOnTaxi = UnitOnTaxi
local RaidNotice_AddMessage = RaidNotice_AddMessage

-- Private Addon API
local GetConfig = Private.GetConfig
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout
local GetMedia = Private.GetMedia
local Colors = Private.Colors
local IsClassic = Private.IsClassic
local IsRetail = Private.IsRetail

-- Filter Cache
local Filters = {}

-- Speed!
local FilterStatus = {}
local MethodCache = {}

-- WoW Objects
local CHAT_FRAMES = CHAT_FRAMES

-- Sourced from SharedXML\FormattingUtil.lua#54
local COPPER_PER_SILVER = COPPER_PER_SILVER -- 100
local SILVER_PER_GOLD = SILVER_PER_GOLD -- 100
local COPPER_PER_GOLD = COPPER_PER_SILVER * SILVER_PER_GOLD

local PlayerFaction, PlayerFactionLabel = UnitFactionGroup("player")


-- Utility Functions
-----------------------------------------------------------------
-- Make the money display pretty
local CreateMoneyString = function(gold, silver, copper, colorCode)
	local layout = Module.layout
	colorCode = colorCode or Colors.offwhite.colorCode
	local moneyString
	if (gold > 0) then 
		moneyString = colorCode..gold.."|r"..layout.GoldCoinTexture
	end
	if (silver > 0) then 
		moneyString = (moneyString and moneyString.." " or "") .. colorCode..silver.."|r"..layout.SilverCoinTexture
	end
	if (copper > 0) then 
		moneyString = (moneyString and moneyString.." " or "") .. colorCode..copper.."|r"..layout.CopperCoinTexture
	end 
	return moneyString
end

Module.CacheAllMessageMethods = function(self)
	if (self.IsCachingMessageMethods) then
		return
	end

	-- Setup all initial chat frames
	for _,chatFrameName in ipairs(CHAT_FRAMES) do 
		CacheMessageMethod(_G[chatFrameName]) 
	end

	-- Hook creation of temporary windows
	self:SetSecureHook("FCF_OpenTemporaryWindow", OnOpenTemporaryWindow, "GP_CHAT_TOOL_CACHE_TEMPORARY_WINDOW")

	-- Flag that we're doing this now.
	self.IsCachingMessageMethods = true
end

Module.SetChatFilterEnabled = function(self, filterType, shouldEnable)
	local filter = Filters[filterType]
	if (not filter) then
		return
	end
	local filterEnabled = FilterStatus[filterType]
	if (shouldEnable) and (not filterEnabled) then
		FilterStatus[filterType] = true
		--filter.Enable(self)

	elseif (not shouldEnable) and (filterEnabled) then
		FilterStatus[filterType] = nil
		--filter.Disable(self)
	end
end

Module.EnableFilter = function(self, filterType)
end

Module.DisableFilter = function(self, filterType)
end

Module.UpdateChatFilters = function(self)

	self:SetChatFilterEnabled("ClassColors", true)
	self:SetChatFilterEnabled("QualityColors", true)
	self:SetChatFilterEnabled("Styling", self.db.enableChatStyling)

	self:SetChatFilterEnabled("Spam", self.db.enableSpamFilter)
	self:SetChatFilterEnabled("Boss", self.db.enableBossFilter)
	self:SetChatFilterEnabled("Monster", self.db.enableMonsterFilter)

	if (self.db.enableSpamFilter) then
		self:SetChatFilterEnabled("MaxDps", self:IsAddOnEnabled("MaxDps"))
	end
end

Module.OnFrameHide = function(self, event, ...)
	if (not MailFrame:IsShown()) then
		self:ClearHook(MailFrame, "OnHide", "OnFrameHide", "GP_FrameHide_Merchant")
	end
	if (not MerchantFrame:IsShown()) then
		self:ClearHook(MerchantFrame, "OnHide", "OnFrameHide", "GP_FrameHide_Mail")
	end
	local money = GetMoney()
	if ((self.playerMoney or 0) > money) then
		self.playerMoney = money
		return
	end
	self:OnEvent("PLAYER_MONEY")
end

Module.OnEvent = function(self, event, ...)

	if (event == "PLAYER_ENTERING_WORLD") then
		self.playerMoney = GetMoney()
		self.isAuctionHouseFrameShown = nil
		self.isMailFrameShown = nil
		self.isMerchantFrameShown = nil

	elseif (event == "PLAYER_MONEY") then
		if (self:IsUsingAlternateMoneyFilter()) then

			-- Get the current money value.
			local currentMoney = GetMoney()

			-- Store the value and don't report anything
			-- if we're on a taxi or if the auction house is open.
			if (UnitOnTaxi("player")) 
			or (AuctionHouseFrame and AuctionHouseFrame:IsShown())
			or (AuctionFrame and AuctionFrame:IsShown()) then 
				self.playerMoney = currentMoney
				return
			end

			-- Check for spam frames, and wait for them to hide.
			local shouldWait
			if (MerchantFrame:IsShown()) then
				shouldWait = true
				self:SetHook(MerchantFrame, "OnHide", "OnFrameHide", "GP_FrameHide_Merchant")
			end
			if (MailFrame:IsShown()) then
				shouldWait = true
				self:SetHook(MailFrame, "OnHide", "OnFrameHide", "GP_FrameHide_Mail")
			end
			if (shouldWait) then
				return
			end

			-- Check if the value has been cached up previously.
			if (self.playerMoney) then
				local money = currentMoney - self.playerMoney
				local gold = math_floor(math_abs(money) / (COPPER_PER_SILVER * SILVER_PER_GOLD))
				local silver = math_floor((math_abs(money) - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
				local copper = math_mod(math_abs(money), COPPER_PER_SILVER)

				if (money > 0) then
				
					local moneyString = CreateMoneyString(gold, silver, copper)
					local moneyMessage = string_format(T.LOOT, moneyString)
					local info = ChatTypeInfo["MONEY"]
					DEFAULT_CHAT_FRAME:AddMessage(moneyMessage, info.r, info.g, info.b, info.id)

				elseif (money < 0) then

					local moneyString = CreateMoneyString(gold, silver, copper, red)
					local moneyMessage = string_format(T.MONEY_MINUS, moneyString)
					local info = ChatTypeInfo["MONEY"]
					DEFAULT_CHAT_FRAME:AddMessage(moneyMessage, info.r, info.g, info.b, info.id)

				end
				self.playerMoney = currentMoney
			end
		end
	end
end

Module.OnInit = function(self)
	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())

	local OptionsMenu = Core:GetModule("OptionsMenu", true)
	if (OptionsMenu) then
		local callbackFrame = OptionsMenu:CreateCallbackFrame(self)
		callbackFrame:AssignProxyMethods("UpdateChatFilters")
		callbackFrame:AssignSettings(self.db)
		callbackFrame:AssignCallback([=[
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
	end
end

Module.OnEnable = function(self)
	self:UpdateChatFilters()
end


Filters.Styling = {
	Enable = function(module)
		if (not LibChatTool.IsCachingMessageMethods) then
			LibChatTool:CacheAllMessageMethods()
		end

		ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", OnChatMessage) -- reputation
		ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", OnChatMessage) -- xp
		ChatFrame_AddMessageEventFilter("CHAT_MSG_CURRENCY", OnChatMessage) -- money loot
		ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", OnChatMessage) -- item loot
		
		if (LibChatTool:IsUsingAlternateMoneyFilter()) then
			LibChatTool.playerMoney = GetMoney()
			LibChatTool:RegisterEvent("PLAYER_ENTERING_WORLD", LibChatTool.OnEvent)
			LibChatTool:RegisterEvent("PLAYER_MONEY", LibChatTool.OnEvent)
		else
			ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", OnChatMessage) -- money loot
		end
		
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

		if (LibChatTool:IsUsingAlternateMoneyFilter()) then
			LibChatTool:UnregisterEvent("PLAYER_MONEY", LibChatTool.OnEvent)
			LibChatTool:UnregisterEvent("PLAYER_ENTERING_WORLD", LibChatTool.OnEvent)
		else
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_MONEY", OnChatMessage) -- money loot
		end

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

Filters.ClassColors = {
	Enable = function(module)
		if (not LibChatTool.IsCachingMessageMethods) then
			LibChatTool:CacheAllMessageMethods()
		end
	end,
	Disable = function(module)
	end
}

Filters.QualityColors = {
	Enable = function(module)
		if (not LibChatTool.IsCachingMessageMethods) then
			LibChatTool:CacheAllMessageMethods()
		end
	end,
	Disable = function(module)
	end
}

-- Just a placeholder for the filter to exist at all.
-- Since it's messages created by addons, we filter it in AddMessage.
Filters.MaxDps = {
	Enable = function(module)
		if (not LibChatTool.IsCachingMessageMethods) then
			LibChatTool:CacheAllMessageMethods()
		end
	end,
	Disable = function(module)
	end
}
