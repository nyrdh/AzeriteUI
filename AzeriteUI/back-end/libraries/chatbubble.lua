local LibChatBubble = Wheel:Set("LibChatBubble", 29)
if (not LibChatBubble) then
	return
end

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibChatBubble requires LibClientBuild to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibChatBubble requires LibEvent to be loaded.")

local LibHook = Wheel("LibHook")
assert(LibHook, "LibChatBubble requires LibHook to be loaded.")

local LibHook = Wheel("LibHook")
assert(LibHook, "LibChatBubble requires LibHook to be loaded.")

-- Embed event functionality into this
LibEvent:Embed(LibChatBubble)
LibHook:Embed(LibChatBubble)

-- Lua API
local ipairs = ipairs
local math_abs = math.abs
local math_floor = math.floor
local pairs = pairs
local select = select
local tostring = tostring

-- WoW API
local CreateFrame = CreateFrame
local GetAllChatBubbles = C_ChatBubbles.GetAllChatBubbles
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local SetCVar = SetCVar
local UnitAffectingCombat = UnitAffectingCombat

-- Constants for client version
local IsAnyClassic = LibClientBuild:IsAnyClassic()
local IsClassic = LibClientBuild:IsClassic()
local IsTBC = LibClientBuild:IsTBC()
local IsWrath = LibClientBuild:IsWrath()
local IsRetail = LibClientBuild:IsRetail()

-- Textures
local BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]]
local BUBBLE_TEXTURE = [[Interface\Tooltips\ChatBubble-Background]]
local TOOLTIP_BORDER = [[Interface\Tooltips\UI-Tooltip-Border]]

-- Bubble Data
LibChatBubble.stylingEnabled = LibChatBubble.stylingEnabled
LibChatBubble.embeds = LibChatBubble.embeds or {}
LibChatBubble.messageToGUID = LibChatBubble.messageToGUID or {}
LibChatBubble.messageToSender = LibChatBubble.messageToSender or {}
LibChatBubble.customBubbles = LibChatBubble.customBubbles or {} -- local bubble registry
LibChatBubble.numChildren = LibChatBubble.numChildren or -1 -- worldframe children
LibChatBubble.numBubbles = LibChatBubble.numBubbles or 0 -- worldframe customBubbles
LibChatBubble.fontObject = LibChatBubble.fontObject or Game12Font_o1
LibChatBubble.fontSize = LibChatBubble.fontSize or 12

-- Visibility settings
for k,v in pairs({
	showInInstances = false, combatHideInInstances = true,
	showInWorld = true, combatHideInWorld = true
}) do
	-- If the value doesn't exist, set it to default
	if (LibChatBubble[k] == nil) then
		LibChatBubble[k] = v
	end
end

-- Custom Bubble parent frame
LibChatBubble.BubbleBox = LibChatBubble.BubbleBox or CreateFrame("Frame", nil, UIParent)
LibChatBubble.BubbleBox:SetAllPoints()
LibChatBubble.BubbleBox:Hide()

-- Update frame
LibChatBubble.BubbleUpdater = LibChatBubble.BubbleUpdater or CreateFrame("Frame", nil, WorldFrame)
LibChatBubble.BubbleUpdater:SetFrameStrata("TOOLTIP")

local customBubbles = LibChatBubble.customBubbles
local bubbleBox = LibChatBubble.BubbleBox
local bubbleUpdater = LibChatBubble.BubbleUpdater
local messageToGUID = LibChatBubble.messageToGUID
local messageToSender = LibChatBubble.messageToSender

local offsetX, offsetY = 0, -100 -- bubble offset from its original position

local getPadding = function()
	return LibChatBubble.fontSize/1.2
end

-- let the bubble size scale from 400 to 660ish (font size 22)
local getMaxWidth = function()
	return 400 + math_floor((LibChatBubble.fontSize - 12)/22 * 260)
end

local getBackdrop = function(scale)
	return {
		bgFile = [[Interface\Tooltips\CHATBUBBLE-BACKGROUND]],
		edgeFile = [[Interface\Tooltips\CHATBUBBLE-BACKDROP]],
		edgeSize = 16 * scale,
		insets = {
			left = 16 * scale,
			right = 16 * scale,
			top = 16 * scale,
			bottom = 16 * scale
		}
	}
end

local getBackdropClean = function(scale)
	return {
		bgFile = BLANK_TEXTURE,
		edgeFile = TOOLTIP_BORDER,
		edgeSize = 16 * scale,
		insets = {
			left = 2.5 * scale,
			right = 2.5 * scale,
			top = 2.5 * scale,
			bottom = 2.5 * scale
		}
	}
end

local OnUpdate = function(self)
	-- 	Reference:
	-- 		bubble, customBubble.blizzardText = original bubble and message
	-- 		customBubbles[bubble], customBubbles[bubble].text = our custom bubble and message
	local scale = WorldFrame:GetHeight()/UIParent:GetHeight()
	for _, bubble in pairs(GetAllChatBubbles()) do

		if (not customBubbles[bubble]) then
			LibChatBubble:InitBubble(bubble)
		end

		local customBubble = customBubbles[bubble]

		if bubble:IsShown() then
			-- continuing the fight against overlaps blending into each other!
			customBubbles[bubble]:SetFrameLevel(bubble:GetFrameLevel()) -- this works?

			local blizzTextWidth = math_floor(customBubble.blizzardText:GetWidth())
			local blizzTextHeight = math_floor(customBubble.blizzardText:GetHeight())
			local point, anchor, rpoint, blizzX, blizzY = customBubble.blizzardText:GetPoint()
			local r, g, b = customBubble.blizzardText:GetTextColor()
			customBubbles[bubble].color[1] = r
			customBubbles[bubble].color[2] = g
			customBubbles[bubble].color[3] = b

			if blizzTextWidth and blizzTextHeight and point and rpoint and blizzX and blizzY then
				if not customBubbles[bubble]:IsShown() then
					customBubbles[bubble]:Show()
				end
				local msg = customBubble.blizzardText:GetText()
				if msg and (customBubbles[bubble].last ~= msg) then
					customBubbles[bubble].text:SetText(msg or "")
					customBubbles[bubble].text:SetTextColor(r, g, b)
					customBubbles[bubble].last = msg
					local sWidth = customBubbles[bubble].text:GetStringWidth()
					local maxWidth = getMaxWidth()
					if sWidth > maxWidth then
						customBubbles[bubble].text:SetWidth(maxWidth)
					else
						customBubbles[bubble].text:SetWidth(sWidth)
					end
				end
				local space = getPadding()
				local ourTextWidth = customBubbles[bubble].text:GetWidth()
				local ourTextHeight = customBubbles[bubble].text:GetHeight()

				-- chatbubbles are rendered at BOTTOM, WorldFrame, BOTTOMLEFT, x, y
				local ourX = math_floor(offsetX + (blizzX - blizzTextWidth/2)/scale - (ourTextWidth-blizzTextWidth)/2)
				local ourY = math_floor(offsetY + blizzY/scale - (ourTextHeight-blizzTextHeight)/2) -- get correct bottom coordinate
				local ourWidth = math_floor(ourTextWidth + space*2)
				local ourHeight = math_floor(ourTextHeight + space*2)

				-- hide while sizing and moving, to gain fps
				customBubbles[bubble]:Hide()
				customBubbles[bubble]:SetSize(ourWidth, ourHeight)
				customBubbles[bubble]:SetBackdropColor(0, 0, 0, .5)
				customBubbles[bubble]:SetBackdropBorderColor(0, 0, 0, .5)

				-- show the bubble again
				customBubbles[bubble]:Show()
			end

			customBubble.blizzardText:SetAlpha(0)
		else
			if customBubbles[bubble]:IsShown() then
				customBubbles[bubble]:Hide()
			else
				customBubbles[bubble].last = nil -- to avoid repeated messages not being shown
			end
		end
	end
	for bubble in pairs(customBubbles) do
		if (not bubble:IsShown()) and (customBubbles[bubble]:IsShown()) then
			customBubbles[bubble]:Hide()
		end
	end
end

LibChatBubble.DisableBlizzard = function(self, bubble)
	local customBubble = customBubbles[bubble]

	-- Grab the original bubble's text color
	customBubble.blizzardColor[1],
	customBubble.blizzardColor[2],
	customBubble.blizzardColor[3] = customBubble.blizzardText:GetTextColor()

	-- Make the original blizzard text transparent
	customBubble.blizzardText:SetAlpha(0)

	-- Remove all the default textures
	for region, texture in pairs(customBubbles[bubble].blizzardRegions) do
		-- Needed in classic, as the game keeps resetting the alpha.
		if (IsClassic or IsTBC or IsWrath) then
			region:SetTexture(nil)
		end
		region:SetAlpha(0)
	end
	--if (customBubble.blizzardBackdropFrame) then
	--	customBubble.blizzardBackdropFrame:SetBackdrop(nil)
	--end
end

LibChatBubble.EnableBlizzard = function(self, bubble)
	local customBubble = customBubbles[bubble]

	-- Restore the original text color
	customBubble.blizzardText:SetTextColor(customBubble.blizzardColor[1], customBubble.blizzardColor[2], customBubble.blizzardColor[3], 1)

	-- Restore all the original textures
	for region, texture in pairs(customBubbles[bubble].blizzardRegions) do
		--region:SetTexture(texture)
		region:SetAlpha(1)
	end
	--if (customBubble.blizzardBackdropFrame) then
	--	customBubble.blizzardBackdropFrame:SetBackdrop(customBubble.blizzardBackdrop)
	--end
end

LibChatBubble.SetBlizzardBubbleFontObject = function(self, fontObject)
	ChatBubbleFont:SetFontObject(fontObject)
end

LibChatBubble.SetBubbleFontObject = function(self, fontObject)
	LibChatBubble.fontObject = fontObject
	fontObject = LibChatBubble:GetFontObject()

	local font, fontSize = fontObject:GetFont()
	LibChatBubble.fontSize = fontSize

	for bubble,customBubble in pairs(customBubbles) do
		customBubble.text:SetFontObject(fontObject)
	end
end

LibChatBubble.GetFontObject = function(self)
	return LibChatBubble.fontObject or Game12Font_o1
end

LibChatBubble.InitBubble = function(self, bubble)
	LibChatBubble.numBubbles = LibChatBubble.numBubbles + 1

	local customBubble = CreateFrame("Frame", nil, bubbleBox, BackdropTemplateMixin and "BackdropTemplate")
	customBubble:Hide()
	customBubble:SetFrameStrata("BACKGROUND")
	customBubble:SetFrameLevel(LibChatBubble.numBubbles%128 + 1) -- try to avoid overlapping bubbles blending into each other
	customBubble:SetBackdrop(getBackdrop(.75))
	customBubble:SetPoint("BOTTOM", bubble, "BOTTOM", 0, 0)

	customBubble.blizzardRegions = {}
	customBubble.blizzardColor = { 1, 1, 1, 1 }
	customBubble.color = { 1, 1, 1, 1 }

	if (customBubble.SetBackdrop) then
		customBubble.blizzardBackdropFrame = customBubble
		customBubble.blizzardBackdrop = customBubble:GetBackdrop()
	end

	customBubble.text = customBubble:CreateFontString()
	customBubble.text:SetPoint("BOTTOMLEFT", 12, 12)
	customBubble.text:SetFontObject(LibChatBubble:GetFontObject())
	customBubble.text:SetShadowOffset(0, 0)
	customBubble.text:SetShadowColor(0, 0, 0, 0)

	-- Old way, still active in classic.
	-- Update 22-03-2021: NOT working in classic anymore?!
	for i = 1, bubble:GetNumRegions() do
		local region = select(i, bubble:GetRegions())
		if (region:GetObjectType() == "Texture") then
			customBubble.blizzardRegions[region] = region:GetTexture()
		elseif (region:GetObjectType() == "FontString") then
			customBubble.blizzardText = region
		end
	end

	-- Chat bubble has been moved to a nameless subframe in 9.0.1
	if (not customBubble.blizzardText) then
		for i = 1, bubble:GetNumChildren() do
			local child = select(i, select(i, bubble:GetChildren()))
			if (child:GetObjectType() == "Frame") and (child.String) and (child.Center) then
				if (child.SetBackdrop) and (not customBubble.blizzardBackdrop) then
					customBubble.blizzardBackdropFrame = child
					customBubble.blizzardBackdrop = child:GetBackdrop()
				end
				for i = 1, child:GetNumRegions() do
					local region = select(i, child:GetRegions())
					if (region:GetObjectType() == "Texture") then
						customBubble.blizzardRegions[region] = region:GetTexture()
					elseif (region:GetObjectType() == "FontString") then
						customBubble.blizzardText = region
					end
				end
			end
		end
	end

	customBubbles[bubble] = customBubble

	-- Only disable the Blizzard bubble outside of instances,
	-- and only when any cinematics aren't playing.
	local _, instanceType = IsInInstance()
	if ((instanceType == "none") and (not MovieFrame:IsShown()) and (not CinematicFrame:IsShown()) and UIParent:IsShown()) then
		LibChatBubble:DisableBlizzard(bubble)
	end

	if LibChatBubble.PostCreateBubble then
		LibChatBubble.PostCreateBubble(bubble)
	end
end

LibChatBubble.PostCreateBubble = function(self, bubble)
	if LibChatBubble.PostCreateBubbleFunc then
		LibChatBubble.PostCreateBubbleFunc(bubble)
	end
end

LibChatBubble.SetBubblePostCreateFunc = function(self, func)
	LibChatBubble.PostCreateBubbleFunc = func
end

LibChatBubble.SetBubblePostUpdateFunc = function(self, func)
	LibChatBubble.PostUpdateBubbleFunc = func
end

-- Seems to be some taint when CinematicFrame is shown, in here?
LibChatBubble.UpdateBubbleVisibility = function(self)
	-- Add an extra layer of combat protection here,
	-- in case we got here abruptly by a started cinematic.
	if (InCombatLockdown()) then
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	end
	local _, instanceType = IsInInstance()
	if ((instanceType == "none") and (not MovieFrame:IsShown()) and (not CinematicFrame:IsShown()) and UIParent:IsShown()) then

		-- Start our updater, this will show our bubbles.
		bubbleUpdater:SetScript("OnUpdate", OnUpdate)
		bubbleBox:Show()

		-- Manually disable the blizzard bubbles
		for bubble in pairs(customBubbles) do
			self:DisableBlizzard(bubble)
		end
	else
		-- Stop our updater
		bubbleUpdater:SetScript("OnUpdate", nil)
		bubbleBox:Hide()

		-- Enable the Blizzard bubbles
		for bubble in pairs(customBubbles) do
			self:EnableBlizzard(bubble)

			-- We need to manually hide ours
			customBubbles[bubble]:Hide()
		end
	end
end

LibChatBubble.SetBubbleVisibleInInstances = function(self, showInInstances)
	LibChatBubble.showInInstances = showInInstances
	LibChatBubble:OnEvent("PLAYER_ENTERING_WORLD")
end

LibChatBubble.SetBubbleVisibleInWorld = function(self, showInWorld)
	LibChatBubble.showInWorld = showInWorld
	LibChatBubble:OnEvent("PLAYER_ENTERING_WORLD")
end

LibChatBubble.SetBubbleCombatHideInInstances = function(self, combatHideInInstances)
	LibChatBubble.combatHideInInstances = combatHideInInstances
	LibChatBubble:OnEvent("PLAYER_ENTERING_WORLD")
end

LibChatBubble.SetBubbleCombatHideInWorld = function(self, combatHideInWorld)
	LibChatBubble.combatHideInWorld = combatHideInWorld
	LibChatBubble:OnEvent("PLAYER_ENTERING_WORLD")
end

LibChatBubble.EnableBubbleStyling = function(self)
	LibChatBubble.stylingEnabled = true
	LibChatBubble:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	LibChatBubble:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
	LibChatBubble:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	LibChatBubble:OnEvent("PLAYER_ENTERING_WORLD")
end

LibChatBubble.DisableBubbleStyling = function(self)
	LibChatBubble.stylingEnabled = nil
	LibChatBubble:UnregisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	LibChatBubble:UnregisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
	LibChatBubble:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	LibChatBubble:OnEvent("PLAYER_ENTERING_WORLD")
end

LibChatBubble.GetAllChatBubbles = function(self)
	return pairs(GetAllChatBubbles())
end

LibChatBubble.OnEvent = function(self, event, ...)
	if (event == "PLAYER_ENTERING_WORLD") then

		-- Don't ever do any of this while in combat.
		-- This should never happen, we're just being overly safe here.
		if (InCombatLockdown()) then
			return self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		end

		if (self.stylingEnabled) then
			local _, instanceType = IsInInstance()
			if (instanceType == "none") then
				if (self.showInWorld) then
					if (self.combatHideInWorld) then
						-- We could be sent here by PLAYER_REGEN_DISABLED,
						-- which fires before combat lockdown starts.
						-- UnitAffectingCombat already returns true at this point,
						-- and can thus be used to toggle CVars before/after combat.
						-- I think.
						if (UnitAffectingCombat("player")) then
							SetCVar("chatBubbles", 0)
						else
							SetCVar("chatBubbles", 1)
						end
					else
						SetCVar("chatBubbles", 1)
					end
				else
					SetCVar("chatBubbles", 0)
				end
			else
				if (self.showInInstances) then
					if (self.combatHideInInstances) then
						if (UnitAffectingCombat("player")) then
							SetCVar("chatBubbles", 0)
						else
							SetCVar("chatBubbles", 1)
						end
					else
						SetCVar("chatBubbles", 1)
					end
				else
					SetCVar("chatBubbles", 0)
				end
			end

			self:SetHook(UIParent, "OnHide", "UpdateBubbleVisibility", "GP_UIPARENT_ONHIDE_BUBBLEUPDATE")
			self:SetHook(UIParent, "OnShow", "UpdateBubbleVisibility", "GP_UIPARENT_ONSHOW_BUBBLEUPDATE")
			self:SetHook(CinematicFrame, "OnHide", "UpdateBubbleVisibility", "GP_CINEMATICFRAME_ONHIDE_BUBBLEUPDATE")
			self:SetHook(CinematicFrame, "OnShow", "UpdateBubbleVisibility", "GP_CINEMATICFRAME_ONSHOW_BUBBLEUPDATE")
			self:SetHook(MovieFrame, "OnHide", "UpdateBubbleVisibility", "GP_MOVIEFRAME_ONHIDE_BUBBLEUPDATE")
			self:SetHook(MovieFrame, "OnShow", "UpdateBubbleVisibility", "GP_MOVIEFRAME_ONSHOW_BUBBLEUPDATE")
		else
			self:ClearHook(UIParent, "OnHide", "UpdateBubbleVisibility", "GP_UIPARENT_ONHIDE_BUBBLEUPDATE")
			self:ClearHook(UIParent, "OnShow", "UpdateBubbleVisibility", "GP_UIPARENT_ONSHOW_BUBBLEUPDATE")
			self:ClearHook(CinematicFrame, "OnHide", "UpdateBubbleVisibility", "GP_CINEMATICFRAME_ONHIDE_BUBBLEUPDATE")
			self:ClearHook(CinematicFrame, "OnShow", "UpdateBubbleVisibility", "GP_CINEMATICFRAME_ONSHOW_BUBBLEUPDATE")
			self:ClearHook(MovieFrame, "OnHide", "UpdateBubbleVisibility", "GP_MOVIEFRAME_ONHIDE_BUBBLEUPDATE")
			self:ClearHook(MovieFrame, "OnShow", "UpdateBubbleVisibility", "GP_MOVIEFRAME_ONSHOW_BUBBLEUPDATE")
		end

		self:UpdateBubbleVisibility()

	elseif (event == "PLAYER_REGEN_ENABLED") then
		return self:OnEvent("PLAYER_ENTERING_WORLD")

	elseif (event == "PLAYER_REGEN_DISABLED") then
		return self:OnEvent("PLAYER_ENTERING_WORLD")

	end
end

-- Module embedding
local embedMethods = {
	EnableBubbleStyling = true,
	DisableBubbleStyling = true,
	SetBlizzardBubbleFontObject = true,
	SetBubbleFontObject = true,
	SetBubblePostCreateFunc = true,
	SetBubblePostUpdateFunc = true,
	SetBubbleVisibleInInstances = true,
	SetBubbleVisibleInWorld = true,
	SetBubbleCombatHideInInstances = true,
	SetBubbleCombatHideInWorld = true
}

LibChatBubble.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibChatBubble.embeds) do
	LibChatBubble:Embed(target)
end
