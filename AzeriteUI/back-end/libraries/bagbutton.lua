local LibBagButton = Wheel:Set("LibBagButton", 44)
if (not LibBagButton) then	
	return
end

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibBagButton requires LibEvent to be loaded.")

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibBagButton requires LibMessage to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibBagButton requires LibClientBuild to be loaded.")

local LibSecureHook = Wheel("LibSecureHook")
assert(LibSecureHook, "LibBagButton requires LibSecureHook to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibBagButton requires LibFrame to be loaded.")

local LibTooltipScanner = Wheel("LibTooltipScanner")
assert(LibTooltipScanner, "LibBagButton requires LibTooltipScanner to be loaded.")

local LibTooltip = Wheel("LibTooltip")
assert(LibTooltip, "LibBagButton requires LibTooltip to be loaded.")

local LibWidgetContainer = Wheel("LibWidgetContainer")
assert(LibWidgetContainer, "LibBagButton requires LibWidgetContainer to be loaded.")

LibEvent:Embed(LibBagButton)
LibMessage:Embed(LibBagButton)
LibSecureHook:Embed(LibBagButton)
LibFrame:Embed(LibBagButton)
LibTooltip:Embed(LibBagButton)
LibTooltipScanner:Embed(LibBagButton)
LibWidgetContainer:Embed(LibBagButton)

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local math_floor = math.floor
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_find = string.find
local string_format = string.format
local string_join = string.join
local string_match = string.match
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local tonumber = tonumber
local type = type
local unpack = unpack

-- WoW API
local GetBagName = GetBagName
local GetContainerItemLink = GetContainerItemLink
local GetContainerItemQuestInfo = GetContainerItemQuestInfo
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local GetContainerNumSlots = GetContainerNumSlots
local GetCVarBool = GetCVarBool
local GetItemInfo = GetItemInfo
local GetItemInfoInstant = GetItemInfoInstant
local InRepairMode = InRepairMode
local IsLoggedIn = IsLoggedIn
local IsModifiedClick = IsModifiedClick
local ResetCursor = ResetCursor
local ShowContainerSellCursor = ShowContainerSellCursor
local ShowInspectCursor = ShowInspectCursor
local SpellIsTargeting = SpellIsTargeting

-- Constants
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Library registries
LibBagButton.embeds = LibBagButton.embeds or {}
LibBagButton.buttons = LibBagButton.buttons or {} -- cache of buttons spawned
LibBagButton.buttons.Bag = LibBagButton.buttons.Bag or {}
LibBagButton.buttons.BagSlot = LibBagButton.buttons.BagSlot or {}
LibBagButton.buttons.Bank = LibBagButton.buttons.Bank or {}
LibBagButton.buttons.BankSlot = LibBagButton.buttons.BankSlot or {}
LibBagButton.buttons.ReagentBank = LibBagButton.buttons.ReagentBank or {}
LibBagButton.buttonParents = LibBagButton.buttonParents or {} -- cache of hidden button parents spawned
LibBagButton.buttonSlots = LibBagButton.buttonSlots or {} -- cache of actual usable button objects
LibBagButton.containers = LibBagButton.containers or {} -- cache of virtual containers spawned
LibBagButton.elements = LibBagButton.elements or {} -- global container element registry
LibBagButton.contents = LibBagButton.contents or {} -- cache of actual bank and bag contents
LibBagButton.queuedContainerIDs = LibBagButton.queuedContainerIDs or {} -- Queue system for uncached items 
LibBagButton.queuedItemIDs = LibBagButton.queuedItemIDs or {} -- Queue system for uncached items 
LibBagButton.callbacks = LibBagButton.callbacks or {} -- button callback registry
LibBagButton.messages = LibBagButton.messages or {} -- library callback message cache
LibBagButton.blizzardMethods = LibBagButton.blizzardMethods or {}

-- Speed
local Buttons = LibBagButton.buttons
local ButtonParents = LibBagButton.buttonParents
local ButtonSlots = LibBagButton.buttonSlots
local Callbacks = LibBagButton.callbacks
local Messages = LibBagButton.messages
local Containers = LibBagButton.containers
local Elements = LibBagButton.elements
local Contents = LibBagButton.contents
local QueuedContainerIDs = LibBagButton.queuedContainerIDs
local QueuedItemIDs = LibBagButton.queuedItemIDs
local BlizzardMethods = LibBagButton.blizzardMethods

-- Blizzard FontObjects
-- Main idea about sticking to these, 
-- is that they are font families adjusting
-- themselves to whatever locale the client is using. 
-- This combined with global strings for text
-- makes the whole library work for all locales by default. 
local TextFontTiny = Game11Font_o1 -- 11
local TextFontSmall = Game13Font_o1 -- 13
local TextFontNormal = Game15Font_o1 --15
local TextFontHuge = SystemFont_Huge1_Outline -- 20
local NumberFontTiny = Number12Font_o1 -- 12
local NumberFontSmall = NumberFont_Outline_Med -- 14
local NumberFontNormal = NumberFont_Outline_Large -- 16
local NumberFontHuge = NumberFont_Outline_Huge -- 30

-- Color table assigned to buttons. Can be replaced.
-- Note that replacements should follow the same structure, 
-- as my color handling assumes the methods to be there. 
-----------------------------------------------------------------
-- Color Template
local ColorTemplate = {}

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

local Colors = {}

Colors.normal = createColor(229/255, 178/255, 38/255)
Colors.highlight = createColor(250/255, 250/255, 250/255)
Colors.title = createColor(255/255, 234/255, 137/255)
Colors.offwhite = createColor(196/255, 196/255, 196/255)
Colors.green = createColor( 25/255, 178/255, 25/255 )
Colors.red = createColor( 204/255, 25/255, 25/255 )

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

Colors.quest = {}
Colors.quest.red = createColor(204/255, 26/255, 26/255)
Colors.quest.orange = createColor(255/255, 106/255, 26/255)
Colors.quest.yellow = createColor(255/255, 178/255, 38/255)
Colors.quest.green = createColor(89/255, 201/255, 89/255)
Colors.quest.gray = createColor(120/255, 120/255, 120/255)

Colors.class = {}
Colors.class.DEATHKNIGHT = createColor(176/255, 31/255, 79/255)
Colors.class.DEMONHUNTER = createColor(163/255, 48/255, 201/255)
Colors.class.DRUID = createColor(225/255, 125/255, 35/255)
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

-- Button Creation Templates
-----------------------------------------------------------------
-- Sourced from FrameXML/BankFrame.lua
-- Bag containing the 7 (or 6 in classic) bank bag buttons. 
local BANK_SLOT_CONTAINER = -4

-- This one does not exist. We made it up.
local BAG_SLOT_CONTAINER = -100

-- Frame type of slot buttons.
local BUTTON_TYPE = (IsClassic) and "Button" or "ItemButton" 

-- Frame template of itembuttons in each bagType.
-- This table will have both the bagTypes and all bagIDs as keys, 
-- making it a good tool to compare slot button compatibility on bagID changes.
-- Since these templates can only be set on itembutton creation, 
-- we can only ever change between bagIDs using the same button templates.
local ButtonTemplates = {
	Bag = "ContainerFrameItemButtonTemplate", -- bag itembutton
	Bank = "BankItemButtonGenericTemplate", -- bank itembutton
	ReagentBank = "BankItemButtonGenericTemplate", -- reagent bank itembutton
	KeyRing = "ContainerFrameItemButtonTemplate", -- keyring itembutton
	BagSlot = "BagSlotButtonTemplate", -- equippable bag container slot
	BankSlot = "BankItemButtonBagTemplate" -- equippable bank container slot
}

-- Localized display names for the bags. 
-- Note that some names can be generated on-the-fly, 
-- so we're intentionally avoiding to list a few here.
local BagNames = { [BACKPACK_CONTAINER] = BACKPACK_TOOLTIP, [BANK_CONTAINER] = BANK }

-- Simple lookup table to get bagType from a provided bagID.
local BagTypesFromID = { 
	[BACKPACK_CONTAINER] = "Bag", 
	[BANK_CONTAINER] = "Bank", 
	[BAG_SLOT_CONTAINER] = "BagSlot", 
	[BANK_SLOT_CONTAINER] = "BankSlot" 
}

-- Setup all bagID lookup tables.
local bagIDs = { BACKPACK_CONTAINER } -- indexed 
local isBagID = { [BACKPACK_CONTAINER] = true } -- hashed
for id = BACKPACK_CONTAINER + 1, NUM_BAG_SLOTS do
	isBagID[id] = true
	bagIDs[#bagIDs + 1] = id
	ButtonTemplates[id] = ButtonTemplates.Bag
	BagTypesFromID[id] = "Bag"
end
ButtonTemplates[BACKPACK_CONTAINER] = ButtonTemplates.Bag

-- Setup all bankBagID lookup tables.
local bankIDs = { BANK_CONTAINER } -- indexed 
local isBankID = { [BANK_CONTAINER] = true } -- hashed
for id = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
	isBankID[id] = true
	bankIDs[#bankIDs + 1] = id
	ButtonTemplates[id] = ButtonTemplates.Bank
	BagTypesFromID[id] = "Bank"
end
ButtonTemplates[BANK_CONTAINER] = ButtonTemplates.Bank

-- The keyring only exists in classic, 
-- but we leave the empty tables for a simpler API.
local isKeyRingID = {} -- hashed
if (IsClassic) then
	isBagID[KEYRING_CONTAINER] = true
	isKeyRingID[KEYRING_CONTAINER] = true
	bagIDs[#bagIDs + 1] = KEYRING_CONTAINER
	ButtonTemplates[KEYRING_CONTAINER] = ButtonTemplates.KeyRing
	BagNames[KEYRING_CONTAINER] = KEYRING
	BagTypesFromID[KEYRING_CONTAINER] = "KeyRing"
end

-- The reagant bank only exists in retail, 
-- but we leave the empty tables for a simpler API.
local isReagentBankID = {} -- hashed
if (IsRetail) then
	isBankID[REAGENTBANK_CONTAINER] = true
	isReagentBankID[REAGENTBANK_CONTAINER] = true
	bankIDs[#bankIDs + 1] = REAGENTBANK_CONTAINER
	ButtonTemplates[REAGENTBANK_CONTAINER] = ButtonTemplates.ReagentBank
	BagNames[REAGENTBANK_CONTAINER] = REAGENT_BANK
	BagTypesFromID[REAGENTBANK_CONTAINER] = "ReagentBank"
end

-- Half-truths. We need numbers to index both. 
ButtonTemplates[BAG_SLOT_CONTAINER] = ButtonTemplates.BagSlot
ButtonTemplates[BANK_SLOT_CONTAINER] = ButtonTemplates.BankSlot

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

local sortAscending = function(a,b)
	return a < b
end

local sortDescending = function(a,b)
	return a > b
end

-- Button Templates
-- These do not have to be connected to any container object,
-- and thus do not rely on bag/bank opening events to be shown.
-- You can use them to track quest items, food, whatever.
-----------------------------------------------------------------
local Button = LibBagButton:CreateFrame(BUTTON_TYPE)
local Button_MT = { __index = Button }
local Methods = getmetatable(Button).__index

-- Grab some original methods for our own event handlers
local ClearAllPoints = Methods.ClearAllPoints
local CreateFontString = Methods.CreateFontString
local CreateTexture = Methods.CreateTexture
local IsEventRegistered = Methods.IsEventRegistered
local RegisterEvent = Methods.RegisterEvent
local RegisterUnitEvent = Methods.RegisterUnitEvent
local SetAllPoints = Methods.SetAllPoints
local SetHeight = Methods.SetHeight
local SetPoint = Methods.SetPoint
local SetSize = Methods.SetSize
local SetWidth = Methods.SetWidth
local UnregisterEvent = Methods.UnregisterEvent
local UnregisterAllEvents = Methods.UnregisterAllEvents

-- ItemButton Event Handling
----------------------------------------------------
Button.RegisterEvent = function(self, event, func)
	if (not Callbacks[self]) then
		Callbacks[self] = {}
	end
	if (not Callbacks[self][event]) then
		Callbacks[self][event] = {}
	end

	local events = Callbacks[self][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not IsEventRegistered(self, event)) then
		RegisterEvent(self, event)
	end
end

Button.UnregisterEvent = function(self, event, func)
	if not Callbacks[self] or not Callbacks[self][event] then
		return
	end
	local events = Callbacks[self][event]
	if #events > 0 then
		for i = #events, 1, -1 do
			if events[i] == func then
				table_remove(events, i)
				if #events == 0 then
					UnregisterEvent(self, event) 
					break
				end
			end
		end
	end
end

Button.UnregisterAllEvents = function(self)
	if not Callbacks[self] then 
		return
	end
	for event, funcs in pairs(Callbacks[self]) do
		for i = #funcs, 1, -1 do
			table_remove(funcs, i)
		end
	end
	UnregisterAllEvents(self)
end

Button.RegisterMessage = function(self, event, func)
	if (not Callbacks[self]) then
		Callbacks[self] = {}
	end
	if (not Callbacks[self][event]) then
		Callbacks[self][event] = {}
	end

	local events = Callbacks[self][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)
	Messages[event] = (Messages[event] or 0) + 1

	if (not LibBagButton.IsMessageRegistered(self, event, func)) then
		LibBagButton.RegisterMessage(self, event, func)
	end
end

Button.UnregisterMessage = function(self, event, func)
	if not Callbacks[self] or not Callbacks[self][event] then
		return
	end
	local events = Callbacks[self][event]
	if #events > 0 then
		for i = #events, 1, -1 do
			if events[i] == func then
				table_remove(events, i)
				if #events == 0 then
					if (LibBagButton.IsMessageRegistered(self, event, func)) then
						LibBagButton.UnregisterMessage(self, event, func)
					end
					break
				end
			end
		end
	end
end

Button.SetSize = function(self, ...)
	SetSize(self, ...)
	ButtonSlots[self]:SetSize(...)
end

Button.SetWidth = function(self, ...)
	SetWidth(self, ...)
	ButtonSlots[self]:SetWidth(...)
end

Button.SetHeight = function(self, ...)
	SetHeight(self, ...)
	ButtonSlots[self]:SetHeight(...)
end

-- ItemButton ID Handling
----------------------------------------------------
-- Set the bagID of the button.
-- Only accept changes within the same bagType range,
-- silentyly fail if a template change is attempted.
-- Reason we can't change templates is because of the
-- Blizzard OnClick functionality needed for interaction,
-- which can't be modified, added or changed after creation.
Button.SetBagID = function(self, bagID)
	-- If we requested a new bagID, see if the old and new share button templates,
	-- as this will tell us whether or not the bagIDs are interchangeable.
	if (ButtonTemplates[self.bagType] == ButtonTemplates[bagID]) then
		ButtonParents[self]:SetID(bagID)
		self.bagID = bagID
		self:Update()
	end
end

-- Change the slotID of a button.
-- We can in theory set this to non-existing IDs, but don't.
Button.SetSlotID = function(self, slotID)
	ButtonSlots[self]:SetID(slotID)
	self.slotID = slotID
	self:Update()
end

-- Change the bagID and slotID at once.
-- Only accept changes within the same bagType range,
-- silentyly fail if a template change is attempted.
-- Reason we can't change templates is because of the
-- Blizzard OnClick functionality needed for interaction,
-- which can't be modified, added or changed after creation.
Button.SetBagAndSlotID = function(self, bagID, slotID)
	-- If we requested a new bagID, see if the old and new share button templates,
	-- as this will tell us whether or not the bagIDs are interchangeable.
	if (ButtonTemplates[self.bagType] == ButtonTemplates[bagID]) then
		ButtonParents[self]:SetID(bagID)
		ButtonSlots[self]:SetID(slotID)
		self.bagID = bagID
		self.slotID = slotID
		self:Update()
	end
end

-- Retrieve the button's current bagID.
-- This method is meant for 3rd party access,
-- our own method uses button flags for faster parsing. 
Button.GetBagID = function(self)
	return self.bagID
end

-- Retrieve the button's current slotID.
-- This method is meant for 3rd party access,
-- our own method uses button flags for faster parsing. 
Button.GetSlotID = function(self)
	return self.slotID
end

-- Retrieve the button's current bagID and slotID.
-- This method is meant for 3rd party access,
-- our own method uses button flags for faster parsing. 
Button.GetBagAndSlotID = function(self)
	return self.bagID, self.slotID
end

-- ItemButton display updates
----------------------------------------------------
-- Updates the icon of a slot button.
Button.UpdateIcon = function(self)
	self.Icon:SetTexture(self.itemIcon)

end

-- Updates the stack/charge count of a slot button.
Button.UpdateCount = function(self)
	local count = self.itemCount
	if (count and count > 1) then
		local previous = self.Count.previousCount
		if (count > 999) then
			if (previous) and ((previous > 99) and (previous <= 999)) then
				self.Count:SetFontObject(NumberFontNormal)
			end
			self.Count:SetText("*")  
		elseif (count > 99) then
			if (not previous) or ((previous <= 99) or (previous > 999)) then
				self.Count:SetFontObject(NumberFontSmall)
			end
			self.Count:SetText(count)
		else
			if (previous) and ((previous > 99) and (previous <= 999)) then
				self.Count:SetFontObject(NumberFontNormal)
			end
			self.Count:SetText(count)
		end
		self.Count.previousCount = count
	else
		self.Count:SetText("")
	end
end

-- Updates item level.
Button.UpdateItemLevel = function(self)
	if (self.isBattlePet) -- Always show the level of battle pets.
	or ((self.itemRarity) and (self.itemRarity > 1) and (self.itemLevel) and (self.itemLevel > 1)) then 
		local color
		if (self.isLocked) then
			color = self.colors.quest.gray
		elseif (self.colorItemLevelByRarity) then
			color = self.colors.quality[self.itemRarity]
		else
			color = self.colors.normal
		end
		self.ItemLevel:SetTextColor(color[1], color[2], color[3])
		self.ItemLevel:SetText(self.itemLevel)
	else
		self.ItemLevel:SetText("")
	end
end

-- Updates the BoE, BoU, BoA text.
Button.UpdateItemBind = function(self)
	if (not self.itemIsBound) and ((self.itemBindType == 2) or (self.itemBindType == 3)) then
		local color
		if (self.isLocked) then
			color = self.colors.quest.gray
		elseif (self.itemRarity) and (self.itemRarity > 1) then
			color = self.colors.quality[self.itemRarity]
		else
			color = self.colors.normal
		end
		self.ItemBind:SetTextColor(color[1], color[2], color[3])
		self.ItemBind:SetText((self.itemBindType == 2) and "BoE" or "BoU")
	else
		self.ItemBind:SetText("")
	end
end


-- Updates the quest icons of a slot button.
Button.UpdateQuest = function(self)
	local isQuestItem, questID, isActive = GetContainerItemQuestInfo(self.bagID, self.slotID)
	self.isQuestItem = isQuestItem or (self.itemClassID == LE_ITEM_CLASS_QUESTITEM)
	self.isQuestActive = isActive
	self.isUsableQuestItem = self.isQuestItem and self.isUsable
	self.questID = questID

	-- Quest starter
	if (self.questID) and (not self.isQuestActive) then
		if (self.isLocked) then
			self.QuestIcon:SetDesaturated(true)
			self.QuestIcon:SetVertexColor(.6,.6,.6)
		else
			self.QuestIcon:SetDesaturated(true)
			self.QuestIcon:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		end
		self.QuestIcon:Show()

	-- Active quests. We indicate this with border color instead.
	elseif (self.questID) or (self.isQuestItem) then
		self.QuestIcon:Hide()
	else
		self.QuestIcon:Hide()
	end
end

-- Updates the junk coin icon of a slot button.
Button.UpdateJunk = function(self)
	-- This method requires the 'isMerchantFrameShown' flag to be set correctly, 
	-- so it is important that we only call this method after it has been updated, 
	-- and also that we specifically recall this method after changes to that flag.
	if (self.itemRarity) and (self.itemRarity == 0) and (not self.noValue) and (LibBagButton.isMerchantFrameShown) and (MerchantFrame.selectedTab == 1) then
		self.CoinIcon:Show()
	else
		self.CoinIcon:Hide()
	end
end

Button.UpdateCooldown = function(self)
end

-- All the following are applied to all button types, 
-- and thus should need to do relevant checks themselves.
-----------------------------------------------------------------

-- Updates all the sub-elements of a slot button at once.
-- This is a big update and should only be run when shown,
-- or when the buttons slot and bag IDs are set or changed.
Button.Update = function(self)
	-- Update flags and information
	local clear
	if (self.bagID) and (self.slotID) then
		local Item = LibBagButton:GetBlizzardContainerSlotCache(self.bagID, self.slotID)
		if (Item) then
			local isQuestItem, questID, isActive = GetContainerItemQuestInfo(self.bagID, self.slotID)
			Item.isQuestItem = isQuestItem or (self.itemClassID == LE_ITEM_CLASS_QUESTITEM)
			Item.isQuestActive = isActive
			Item.isUsableQuestItem = self.isQuestItem and Item.isUsable
			Item.questID = questID

			local _, _, locked = GetContainerItemInfo(self.bagID, self.slotID)
			Item.isLocked = locked

			self.itemID = Item.itemID
			self.itemString = Item.itemString
			self.itemName = Item.itemName
			self.itemLink = Item.itemLink
			self.itemRarity = Item.itemRarity
			self.itemLevel = Item.itemLevel
			self.itemMinLevel = Item.itemMinLevel
			self.itemType = Item.itemType
			self.itemSubType = Item.itemSubType
			self.itemStackCount = Item.itemStackCount
			self.itemCount = Item.itemCount
			self.itemEquipLoc = Item.itemEquipLoc
			self.itemEquipLocLabel = Item.itemEquipLocLabel
			self.itemIcon = Item.itemIcon
			self.itemSellPrice = Item.itemSellPrice
			self.itemClassID = Item.itemClassID
			self.itemSubClassID = Item.itemSubClassID
			self.itemBindType = Item.itemBindType
			self.itemIsBound = Item.itemIsBound
			self.itemCanBind = Item.itemCanBind
			self.itemBind = Item.itemBind
			self.expacID = Item.expacID
			self.itemSetID = Item.itemSetID
			self.isCraftingReagent = Item.isCraftingReagent
			self.isUsable = Item.isUsable
			self.isQuestItem = Item.isQuestItem
			self.isUsableQuestItem = Item.isUsableQuestItem
			self.isQuestActive = Item.isQuestActive
			self.questID = Item.questID
			self.isLocked = Item.isLocked
			self.isOpenable = Item.isOpenable
			self.isBattlePet = Item.isBattlePet
			self.noValue = Item.noValue

		else
			clear = true
		end
	else
		clear = true
	end
	if (clear) then
		self.itemID = nil
		self.itemString = nil
		self.itemName = nil
		self.itemLink = nil
		self.itemRarity = nil
		self.itemLevel = nil
		self.itemMinLevel = nil
		self.itemType = nil
		self.itemSubType = nil
		self.itemStackCount = nil
		self.itemCount = nil
		self.itemEquipLoc = nil
		self.itemEquipLocLabel = nil
		self.itemIcon = ""
		self.itemSellPrice = nil
		self.itemClassID = nil
		self.itemSubClassID = nil
		self.itemBindType = nil
		self.expacID = nil
		self.itemSetID = nil
		self.isCraftingReagent = nil
		self.isUsable = nil
		self.isQuestItem = nil
		self.isQuestActive = nil
		self.isUsableQuestItem = nil
		self.questID = nil
		self.isLocked = nil
		self.isOpenable = nil
		self.isBattlePet = nil
		self.noValue = nil
	end

	-- Update layers
	self:UpdateIcon()
	self:UpdateCount()
	self:UpdateCooldown()
	self:UpdateJunk()
	self:UpdateQuest()
	self:UpdateItemLevel()
	self:UpdateItemBind()

	local tooltip = self:GetTooltip()
	if (tooltip:IsShown()) and (tooltip:GetOwner() == self) then
		self:OnUpdate()
	end

	-- Run user post updates
	if (self.PostUpdate) then
		self:PostUpdate()
	end
end

-- Basically a tooltip function that needs regular updates.
-- Used only with OnUpdate, OnEnter and OnLeave.
Button.OnUpdate = function(self)
	-- Avoid nil bugs. 
	if (not self.bagID) or (not self.bagID) then
		return
	end

	-- Is it a classic keyring? Add code. 

	local Item = LibBagButton:GetBlizzardContainerSlotCache(self.bagID, self.slotID)
	if (Item) and (Item.itemName) then
		-- Note that we are not using our available cache here, 
		-- this is to avoid display bugs related to the repair cost of newly repaired items.
		local tooltip = self:GetTooltip()
		tooltip:SetSmartItemAnchor(self, tooltip.tooltipAnchorX or 4, tooltip.tooltipAnchorY or 0) 
		tooltip:SetBagItem(self.bagID, self.slotID) 
	else
		local tooltip = self:GetTooltip()
		if (tooltip:IsShown()) and (tooltip:GetOwner() == self) then
			tooltip:Hide()
		end
	end

	-- check for modified clicks, show compare tips if need be.
	if (IsModifiedClick("COMPAREITEMS")) or (GetCVarBool("alwaysCompareItems")) then
		-- Show compare item. 
		-- We will use our own system here.
	end

	local showSell
	if (InRepairMode()) and ((Item.repairCost) and (Item.repairCost > 0)) then
		-- REPAIR_COST = "Repair Cost:"
		-- show tooltip

	elseif (LibBagButton.isMerchantFrameShown) and (MerchantFrame.selectedTab == 1) then
		showSell = 1
	end

	if (not SpellIsTargeting()) then
		if (IsModifiedClick("DRESSUP")) and ((Item) or (self.hasItem)) then
			ShowInspectCursor()

		elseif (showSell) then
			ShowContainerSellCursor(self.bagID, self.slotID)

		elseif (self.readable) then
			ShowInspectCursor()

		else
			ResetCursor()
		end
	end

end

Button.OnEnter = function(self)
	self:OnUpdate()
	self.UpdateTooltip = self.OnUpdate
end

Button.OnLeave = function(self)
	self:OnUpdate()
	self.UpdateTooltip = nil

	local tooltip = self:GetTooltip()
	if (tooltip:IsShown()) and (tooltip:GetOwner() == self) then
		tooltip:Hide()
	end

	if (not SpellIsTargeting()) then
		ResetCursor()		
	end
end

-- The button's actual event handler, 
-- as we are routing all our own callbacks to this one.
local UpdateButton = function(self, event, ...)
	local arg1, arg2 = ...
	if (event == "GP_BAG_UPDATE") then
		if (self.bagID == arg1) then
			self:Update()
		end

	elseif (event == "BAG_UPDATE_COOLDOWN") then
		-- Update all item cooldowns.
		self:UpdateCooldown()

	elseif (event == "BAG_NEW_ITEMS_UPDATED") then


	elseif (event == "ITEM_LOCK_CHANGED") then
		-- Update item lock desaturation and darkening.
		if (arg1 and arg2 and (self.bagID == arg1) and (self.slotID == arg2)) then
	
			-- Get the item lock status
			local _, _, locked = GetContainerItemInfo(self.bagID, self.slotID)
			self.isLocked = locked
	
			-- Update the icon.
			self:UpdateIcon()
			self:UpdateItemLevel()
			self:UpdateItemBind()
			self:UpdateJunk()
			self:UpdateQuest()
		
			-- Run user post updates
			if (self.PostUpdate) then
				self:PostUpdate()
			end
		end

	elseif (event == "QUEST_ACCEPTED") or ((event == "UNIT_QUEST_LOG_CHANGED") and (arg1 == "player")) then

		-- Update quest icons.
		self:UpdateQuest()

		-- Run user post updates
		if (self.PostUpdate) then
			self:PostUpdate()
		end


	elseif (event == "UNIT_INVENTORY_CHANGED") or (event == "PLAYER_SPECIALIZATION_CHANGED") then
		-- Update item upgrade icons.
	end
end

Button.OnShow = function(self)
	self.isShown = true
	self:RegisterMessage("GP_BAG_UPDATE", UpdateButton)
	self:RegisterEvent("BAG_UPDATE_COOLDOWN", UpdateButton)
	self:RegisterEvent("ITEM_LOCK_CHANGED", UpdateButton)
	self:RegisterEvent("QUEST_ACCEPTED", UpdateButton)
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", UpdateButton)
	self:RegisterEvent("UNIT_INVENTORY_CHANGED", UpdateButton)
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", UpdateButton)
	self:Update()
end

Button.OnHide = function(self)
	self.isShown = nil
	self.UpdateTooltip = nil
	self:UnregisterMessage("GP_BAG_UPDATE", UpdateButton)
	self:UnregisterEvent("BAG_UPDATE_COOLDOWN", UpdateButton)
	self:UnregisterEvent("ITEM_LOCK_CHANGED", UpdateButton)
	self:UnregisterEvent("QUEST_ACCEPTED", UpdateButton)
	self:UnregisterEvent("UNIT_QUEST_LOG_CHANGED", UpdateButton)
	self:UnregisterEvent("UNIT_INVENTORY_CHANGED", UpdateButton)
	self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", UpdateButton)
end

Button.OnEvent = function(self, event, ...)
	if (self:IsVisible() and Callbacks[self] and Callbacks[self][event]) then 
		local events = Callbacks[self][event]
		for i = 1, #events do
			events[i](self, event, ...)
		end
	end 
end

Button.GetTooltip = function(self)
	return LibBagButton:GetBagButtonTooltip()
end

Button.GetCompareTooltips = function(self)
	return LibBagButton:GetBagButtonCompareTooltips()
end

-- Container Template
-- This is NOT the equivalent of the blizzard bags or containers,
-- as our containers are not restricted to nor mirror specific bagIDs.
-- Our containers do however respond to regular game events
-- for showing/hiding/toggling the bags and bank.
-----------------------------------------------------------------
local Container = LibBagButton:CreateFrame("Frame")
local Container_MT = { __index = Container }

Container.SetFilter = function(self, filterFunction)
	check(filterFunction, 1, "function", "string", "nil")
	self.filterFunction = filterFunction
end

Container.SetSorting = function(self, sortFunction)
	check(sortFunction, 1, "function", "string", "nil")
	self.sortFunction = sortFunction
end

-- Updates the container's buttons
Container.Update = function(self)

	-- Create the display cache if it doesn't exist
	if (not self.displayCache) then
		self.displayCache = {}
	end

	-- Wipe out the display cache
	for i in pairs(self.displayCache) do
		self.displayCache[i] = nil
	end

	-- Retrieve all buttons matching the container's bagType,
	-- and insert them into our freshly wiped display cache.
	local bagType = Containers[self] 
	for i,bagID in ipairs(bagIDs) do
		if (BagTypesFromID[bagID] == bagType) then
			local container = LibBagButton:GetBlizzardContainerCache(bagID)
			if (container) then
				for slotID = 1,container.totalSlots do
					local Item = LibBagButton:GetBlizzardContainerSlotCache(bagID,slotID)
					if (Item) then
						-- Add the existing items to our local indexed cache
						self.displayCache[#self.displayCache + 1] = Item
					end
				end
			end
		end
	end

	-- Filter the display cache
	if (self.filterFunction) then
		for i = #self.displayCache,1,-1 do
			local cache = self.displayCache[i]
			if (cache) and (not self.filterFunction(cache)) then
				self.displayCache[i] = nil
			end
		end
	end

	-- Sort the display cache
	if (self.sortFunction) then
		table_sort(self.displayCache,self.sortFunction)
	end

	-- Display and arrange the display cache
	-- Start ordering buttons
		-- Add extra when needed
		-- Hide empty buttons
	
	-- Update all visible buttons
	for slot,button in pairs(self.buttons) do
		if (button.isShown) then
			button:Update()
		end
	end
end

Container.SpawnItemButton = function(self, bagType)
	if (not self.buttons) then
		self.buttons = {}
	end

	local button = LibBagButton:SpawnItemButton(bagType)
	button:SetParent(self)
	button._owner = self

	if (self.PostCreateItemButton) then
		self:PostCreateItemButton(button)
	end

	-- Insert the virtual button slot object into the correct cache.
	table_insert(self.buttons, button) 

	return button
end

Container.GetTooltip = function(self)
	return LibBagButton:GetBagButtonTooltip()
end

Container.GetCompareTooltips = function(self)
	return LibBagButton:GetBagButtonCompareTooltips()
end

-- Doing this?
Container.GetTextFontTiny = function(self) return TextFontTiny end
Container.GetTextFontSmall = function(self) return TextFontSmall end
Container.GetTextFontNormal = function(self) return TextFontNormal end
Container.GetTextFontHuge = function(self) return TextFontHuge end
Container.GetNumberFontTiny = function(self) return NumberFontTiny end
Container.GetNumberFontSmall = function(self) return NumberFontSmall end
Container.GetNumberFontNormal = function(self) return NumberFontNormal end
Container.GetNumberFontHuge = function(self) return NumberFontHuge end


-- Library API
-- *The 'self' is the library here.
-----------------------------------------------------------------
LibBagButton.GetBagButtonTooltip = function(self)
	return LibBagButton:GetTooltip("GP_BagButtonTooltip") or LibBagButton:CreateTooltip("GP_BagButtonTooltip")
end

LibBagButton.GetBagButtonCompareTooltips = function(self)
	return	LibBagButton:GetTooltip("GP_BagButtonCompareTooltip1") or LibBagButton:CreateTooltip("GP_BagButtonCompareTooltip1"),
			LibBagButton:GetTooltip("GP_BagButtonCompareTooltip2") or LibBagButton:CreateTooltip("GP_BagButtonCompareTooltip2")
end

--[[-- 
	local numberOfFreeSlots, bagType = GetContainerNumFreeSlots(bagID)
	bagType = 2^(bitfield-1) 
	(https://wow.gamepedia.com/ItemFamily)

		bit category
		-------------------------------------
		 4 	Leatherworking Supplies
		 5 	Inscription Supplies
		 6 	Herbs
		 7 	Enchanting Supplies
		 8 	Engineering Supplies
		10 	Gems
		11 	Mining Supplies
		12 	Soulbound Equipment
		16 	Fishing Supplies
		17 	Cooking Supplies
		20 	Toys
		21 	Archaeology
		22 	Alchemy
		23 	Blacksmithing
		24 	First Aid
		25 	Jewelcrafting
		26 	Skinning
		27 	Tailoring 
--]]--

-- Retrieve the existing or create a blank cache for this blizzard container.
LibBagButton.GetBlizzardContainerCache = function(self, bagID)
	if (not Contents[bagID]) then
		Contents[bagID] = {}
	end
	return Contents[bagID]
end

-- Retrieve the existing or create a blank cache for this blizzard slot.
LibBagButton.GetBlizzardContainerSlotCache = function(self, bagID, slotID)
	if (not Contents[bagID]) then
		Contents[bagID] = {}
	end
	if (not Contents[bagID][slotID]) then
		Contents[bagID][slotID] = {}
	end
	return Contents[bagID][slotID]
end

-- Clear the contents of a cached blizzard container slot if it exists.
LibBagButton.ClearBlizzardContainerSlot = function(self, bagID, slotID)
	if (Contents[bagID]) then
		if (Contents[bagID][slotID]) then
			for i in pairs(Contents[bagID][slotID]) do
				Contents[bagID][slotID][i] = nil
			end
		end
	end
end

-- Parse and cache a specific slot in a blizzard container. 
LibBagButton.ParseBlizzardContainerSlot = function(self, bagID, slotID, forceUpdate)

	local isQuestItem, questID, isActive
	local itemID, itemType, itemSubType, itemEquipLoc, itemIcon, itemClassID, itemSubClassID

	-- Check if the Blizzard slot has an item in it
	local itemLink = GetContainerItemLink(bagID, slotID)
	if (itemLink) then

		-- Check if we have cached the item previously,
		-- or create an empty cache table if none exist.
		local Item = self:GetBlizzardContainerSlotCache(bagID, slotID)

		-- This is implicit by the existence of all the other values, 
		-- but for the sake of semantics and simplicity, we use a separate value for this.
		Item.hasItem = true

		-- Compare the cache's itemlink to the blizzard itemlink, 
		-- and update or retrieve the contents to our cache if need be.
		if (Item.itemLink ~= itemLink) or (forceUpdate) then

			-- Retrieve data scanned from tooltips,
			-- pass our existing table and fill it in.
			Item = self:GetTooltipDataForContainerSlot(bagID, slotID, Item)
			Item.itemLink = itemLink


			if (Item.itemName) then 

				-- No quest item info in classic
				if (not IsClassic) then
					isQuestItem, questID, isActive = GetContainerItemQuestInfo(bagID, slotID)
				end
				
				Item.isUsable = IsUsableItem(Item.itemID)
				Item.isQuestItem = isQuestItem or (Item.itemClassID == LE_ITEM_CLASS_QUESTITEM)
				Item.isQuestActive = isActive
				Item.isUsableQuestItem = Item.isQuestItem and Item.isUsable
				Item.questID = questID

			else
				-- Get some basic info if the item hasn't been cached up yet
				if (not QueuedContainerIDs[bagID]) then
					QueuedContainerIDs[bagID] = {}
				end
				if (not QueuedContainerIDs[bagID][slotID]) then
					QueuedContainerIDs[bagID][slotID] = itemID
				end
				self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnEvent")
	
				-- Use the client-only API for faster lookups here
				Item.itemID,
				Item.itemType,
				Item.itemSubType,
				Item.itemEquipLoc,
				Item.itemIcon,
				Item.itemClassID,
				Item.itemSubClassID = GetItemInfoInstant(itemLink) 

			end
		end

	else
		-- The blizzard slot has no item, so we clear our cache if it exists.
		self:ClearBlizzardContainerSlot(bagID, slotID)
	end
end

-- Parse and cache all the slots of a blizzard container, and the container itself. 
LibBagButton.ParseSingleBlizzardContainer = function(self, bagID, forceUpdate)

	local numberOfSlots = GetContainerNumSlots(bagID) or 0 -- returns 0 before the BAG_UPDATE for the bagID has fired.
	local numberOfFreeSlots, bagType = GetContainerNumFreeSlots(bagID) or -1

	if (numberOfSlots > 0) then
		local cache = self:GetBlizzardContainerCache(bagID)
		cache.bagType = bagType or 0 -- any other value than 0 means profession bag.
		cache.freeSlots = numberOfFreeSlots 
		cache.totalSlots = numberOfSlots
		cache.name = BagNames[bagID] or GetBagName(bagID)

		for slotID = 1,numberOfSlots do
			self:ParseBlizzardContainerSlot(bagID, slotID, forceUpdate)
		end
	end
end

-- Parse and cache specific multiple blizzard containers. 
-- Note that this method always uses the forceUpdate flag.
LibBagButton.ParseMultipleBlizzardContainers = function(self, ...)
	local bagID
	local numContainers = select("#", ...)
	if (numContainers) and (numContainers > 0) then
		for i = 1,numContainers do
			bagID = select(i, ...)
			self:ParseSingleBlizzardContainer(bagID, true)
		end
	end
end

-- Shows your containers containing bag buttons.
-- Suppresses the blizzard method if 'true' is returned.
LibBagButton.ShowBags = function(self, forceUpdate)
	-- Set this flag before we start showing.
	-- The idea is to prevent buttons from calling this function, 
	-- as button updates are many and frequent, and we want low performance impact.
	self.isMerchantFrameShown = MerchantFrame:IsShown()
	local hasBags
	local changesMade
	for container, bagType in pairs(Containers) do
		if (bagType == "Bag") then
			if (not container:IsShown()) then
				changesMade = true
				container:Show()

			-- Force an update of already open bags.
			-- This is needed if the bags are open before
			-- visiting a merchant, to show junk coin icons.
			elseif (forceUpdate) then
				container:Update()
			end
			hasBags = true
		end
	end
	if (changesMade) then
		self:SendMessage("GP_BAGS_SHOWN")
	end
	-- A return value other than false
	-- suppresses the blizzard methods.
	return hasBags
end

-- Hides your containers containing bag buttons.
-- *This one is called when Esc is clicked and bags forcehidden.
-- Suppresses the blizzard method if 'true' is returned.
LibBagButton.HideBags = function(self, forceUpdate)
	--if (self:IsAtBank()) then 
	--	CloseBankFrame() 
	--end

	local hasBags
	local changesMade
	for container, bagType in pairs(Containers) do
		if (bagType == "Bag") then
			if (container:IsShown()) then
				changesMade = true
			end
			container:Hide()
			hasBags = true
		end
	end
	-- Alert the environment.
	if (changesMade) then
		self:SendMessage("GP_BAGS_HIDDEN")
	end
	-- A return value other than false
	-- suppresses the blizzard methods.
	return hasBags
end

-- Toggles your bag frames.
-- Suppresses the blizzard method if 'true' is returned.
LibBagButton.ToggleBags = function(self, ...)
	-- Check if we have bag containers, and if any are shown
	local hasBags, shouldHide
	for container, bagType in pairs(Containers) do
		if (bagType == "Bag") then
			-- We have bag containers.
			hasBags = true 
			if (container:IsShown()) then 
				-- they are visible, so this is a hide operation.
				shouldHide = true 
				-- If both flags are true, 
				-- no further iteration is needed.
				if (hasBags) then
					break
				end
			end
		end
	end
	-- Set this flag before we start toggling.
	-- The idea is to prevent buttons from calling this function, 
	-- as button updates are many and frequent, and we want low performance impact.
	if (not shouldHide) then
		self.isMerchantFrameShown = MerchantFrame:IsShown()
	end
	-- If bags were found, we need a 2nd pass to toggle visibility.
	if (hasBags) then
		local changesMade
		for container, bagType in pairs(Containers) do
			if (bagType == "Bag") then
				if (container:IsShown()) then
					if (shouldHide) then
						changesMade = true
					end
				else
					if (not shouldHide) then
						changesMade = true
					end
				end
				container:SetShown((not shouldHide))
			end
		end
		-- Alert the environment.
		if (changesMade) then
			if (shouldHide) then
				self:SendMessage("GP_BAGS_HIDDEN")
			else
				self:SendMessage("GP_BAGS_SHOWN")
			end
		end
	end
	-- A return value other than false
	-- suppresses the blizzard methods.
	return hasBags
end

-- Displays your bank frames.
-- Will use stored information when available, 
-- making it possible to track bank contents when not at the bank.
-- TODO: Add API to assign a cache at container creation!
LibBagButton.ShowBank = function(self)
end

-- Hides bank frames.
LibBagButton.HideBank = function(self)
end

-- Toggles your bank frames.
LibBagButton.ToggleBank = function(self)
end

-- Global function names, 
-- and our library equivalents.
-- Note: We should check for library version if we change this!
local methodByGlobal = {
	["ToggleAllBags"] = "ToggleBags",
	["ToggleBackpack"] = "ToggleBags",
	["ToggleBag"] = "ToggleBags",
	["OpenAllBags"] = "ShowBags",
	["OpenBackpack"] = "ShowBags",
	["OpenBag"] = "ShowBags",
	["CloseAllBags"] = "HideBags" -- only replace the full hide function, not singular bags.
}

-- Method to hook the blizzard bag toggling functions.
LibBagButton.HookBlizzardBagFunctions = function(self)
	--BankFrame:UnregisterAllEvents()
	--BankFrame:SetScript("OnLoad", nil)
	--BankFrame:SetScript("OnEvent", nil)
	--BankFrame:SetScript("OnShow", nil)
	--BankFrame:SetScript("OnHide", nil)
	--BankFrame:Hide()

	-- Replace the global funcs, or update the replacements 
	-- if this was a library upgrade. 
	-- Note: We should check for library version if we change this!
	for globalName,method in pairs(methodByGlobal) do
		local globalFunc = _G[globalName]
		if (globalFunc) then

			-- Only store the global once, to avoid overwritring precious hooks.
			BlizzardMethods[globalName] = BlizzardMethods[globalName] or globalFunc

			-- Upvalue method names and replace the global function.
			local globalName, method = globalName, method
			local func = function(frame, ...)
				if (not LibBagButton[method](LibBagButton, ...)) then
					BlizzardMethods[globalName](frame, ...)
				end
			end
			_G[globalName] = func
		end
	end
end

-- Method to restore blizzard bag toggling functions.
LibBagButton.UnhookBlizzardBagFunctions = function(self)
	--BankFrame:UnregisterAllEvents()
	--BankFrame:RegisterEvent("BANKFRAME_OPENED")
	--BankFrame:RegisterEvent("BANKFRAME_CLOSED")
	--BankFrame:SetScript("OnLoad", BankFrame_OnLoad)
	--BankFrame:SetScript("OnEvent", BankFrame_OnEvent)
	--BankFrame:SetScript("OnShow", BankFrame_OnShow)
	--BankFrame:SetScript("OnHide", BankFrame_OnHide)

	for globalName,func in pairs(BlizzardMethods) do
		_G[globalName] = func
	end
end

LibBagButton.OnEvent = function(self, event, ...)
	-- Todo:
	-- item locks changed: ITEM_LOCK_CHANGED: bagID, slotID
	-- number of available slots? BAG_SLOT_FLAGS_UPDATED: bagID
	-- number of available slots? BANK_BAG_SLOT_FLAGS_UPDATED: bagID
	-- cooldowns changed: BAG_UPDATE_COOLDOWN
	-- new item highlight: BAG_NEW_ITEMS_UPDATED
	-- item upgrade icons: (event == "UNIT_INVENTORY_CHANGED") or (event == "PLAYER_SPECIALIZATION_CHANGED")
	-- quest icons: (event == "QUEST_ACCEPTED") or (event == "UNIT_QUEST_LOG_CHANGED" and (arg1 == "player"))

	if (event == "BANKFRAME_OPENED") then
		self.atBank = true
		self:ParseMultipleBlizzardContainers(unpack(bankIDs))
		self:ShowBank()
		self:ShowBags()
		self:SendMessage("GP_BANKFRAME_OPENED")

	elseif (event == "BANKFRAME_CLOSED") then
		self.atBank = nil
		self:HideBank()
		self:HideBags()
		self:SendMessage("GP_BANKFRAME_CLOSED")
		
	elseif (event == "BAG_OPEN") then
		local bagID = ...
		if (bagID) and (BagTypesFromID[bagID]) then
			self:ShowBags()
		end

	elseif (event == "BAG_CLOSED") then
		local bagID = ...
		if (bagID) and (BagTypesFromID[bagID]) then
			self:HideBags()
		end

	elseif (event == "BAG_UPDATE") then
		local bagID = ...

		-- This is where the actual magic happens. 
		self.parsingRequired = true
		self:ParseSingleBlizzardContainer(bagID, true)
		self:SendMessage("GP_BAG_UPDATE", bagID)

	elseif (event == "GET_ITEM_INFO_RECEIVED") then
		local updatedItemID, success = ...
		for bagID in pairs(QueuedContainerIDs) do
			for slotID, itemID in pairs(QueuedContainerIDs[bagID]) do
				if (itemID == updatedItemID) then

					-- Clear the entry to avoid parsing it again
					QueuedContainerIDs[bagID][slotID] = nil

					-- Full item info is availble
					if (success) then
						-- Parse this slot
						self:ParseBlizzardContainerSlot(bagID, slotID)
						self:SendMessage("GP_GET_ITEM_INFO_RECEIVED",  updatedItemID, success, bagID, slotID)
						self:SendMessage("GP_BAG_UPDATE", bagID, slotID)

					-- Item does not exist, clear it
					elseif (success == nil) then
						-- Clear this slot
						self.parsingRequired = true
						self:ClearBlizzardContainerSlot(bagID, slotID)
						self:SendMessage("GP_GET_ITEM_INFO_RECEIVED",  updatedItemID, success, bagID, slotID)
						self:SendMessage("GP_BAG_UPDATE", bagID, slotID)
					end

				end
			end
		end
		-- Check if anything is still queued
		for bagID in pairs(QueuedContainerIDs) do
			for slotID, itemID in pairs(QueuedContainerIDs[bagID]) do
				-- If anything is found, just return.
				-- We still need the event.
				return 
			end
		end
		-- Kill off the event if no more itemslots are queued
		self:UnregisterEvent("GET_ITEM_INFO_RECEIVED", "OnEvent")
		-- Fire a custom event to indicate the queue has been parsed
		-- and all delayed item information has been received.
		self:SendMessage("GP_BAGS_READY")

	elseif (event == "PLAYER_ENTERING_WORLD") then

		-- Only ever want this once after library enabling.
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")

		-- Now we can start tracking stuff
		self:RegisterEvent("BANKFRAME_OPENED", "OnEvent")
		self:RegisterEvent("BANKFRAME_CLOSED", "OnEvent")

		-- Even though technically all data is available at this point,
		-- information like the size of each container isn't available
		-- until those containers get their BAG_UPDATE event.
		-- This is most likely due to the UI resetting its
		-- internal cache sometimes between these events.
		self:RegisterEvent("BAG_UPDATE", "OnEvent")

		-- Do an initial parsing of the bags.
		-- The results might be lacking because of the above.
		self:ParseMultipleBlizzardContainers(unpack(bagIDs))

		-- Fire off some semi-fake events.
		-- The idea is to have the front-end only rely on custom messages, 
		-- so we need these here instead of the Blizzard events.
		for _,bagID in ipairs(bagIDs) do
			self:SendMessage("GP_BAG_UPDATE", bagID)
		end

		local stillWaiting
		if (QueuedContainerIDs) then
			-- Check if anything is still queued
			for bagID in pairs(QueuedContainerIDs) do
				for slotID, itemID in pairs(QueuedContainerIDs[bagID]) do
					-- If anything is found, break here
					stillWaiting = true 
				end
			end
		end
		if (not stillWaiting) then
			-- Fire a custom event to indicate the queue has been parsed
			-- and all delayed item information has been received.
			self:SendMessage("GP_BAGS_READY")
		end

	end
end

LibBagButton.OnMerchantFrameUpdate = function(self, id, ...)
	if (MerchantFrame:IsShown()) then
		-- The idea is to prevent buttons from calling the above function, 
		-- as button updates are many and frequent, and we want low performance impact.
		LibBagButton.isMerchantFrameShown = true
		if (LibBagButton.selectedMerchantTab ~= MerchantFrame.selectedTab) then
			LibBagButton.selectedMerchantTab = MerchantFrame.selectedTab
			-- Forceupdate everything on merchant tab changes.
			if (LibBagButton:IsAnyBagOpen()) then
				LibBagButton:ShowBags(true)
			end
		end
	else
		LibBagButton.isMerchantFrameShown = nil
	end
end

LibBagButton.Start = function(self)

	-- Hook the blizzard bag toggling.
	-- It is preferable to get this done as early as possible.
	self:HookBlizzardBagFunctions()
	
	-- Always kill off all events here.
	self:UnregisterAllEvents()

	-- Hook the merchantframe to our update system.
	LibBagButton:SetSecureHook("MerchantFrame_Update", "OnMerchantFrameUpdate", "GP_LibBagButton_MerchantFrameUpdate")

	-- Could be a library upgrade, or forced restart.
	if (IsLoggedIn()) then
		-- If we restarted the engine after login, 
		-- we need to manually trigger this event as though
		-- it was the initial login, to enable event tracking.
		self:OnEvent("PLAYER_ENTERING_WORLD", true)
	else
		-- Delay all event parsing until we enter the world.
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	end

	local tooltip = self:GetBagButtonTooltip()
	tooltip:SetCValue("backdrop", {
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], 
		edgeSize = 16,
		insets = {
			left = 3.5,
			right = 3.5,
			top = 3.5,
			bottom = 3.5
		}
	})
	tooltip:SetCValue("backdropColor", { 0, 0, 0, .95 })
	tooltip:SetCValue("backdropBorderColor", { .25, .25, .25, 1 })
	tooltip:SetCValue("backdropOffsets", { 10, 10, 10, 10 })

end

-- Library Public API
-- *The 'self' is the module embedding it here.
-----------------------------------------------------------------
LibBagButton.SpawnItemContainer = function(self, ...)
	local bagType, styleFunc = ...

	check(bagType, 1, "string")
	check(styleFunc, 2, "function", "nil")

	if (bagType ~= "Bag") and (bagType ~= "Bank") then
		return error(string_format("No bagType named '%s' exists!", bagType))
	end

	local frame = LibBagButton:CreateWidgetContainer("Frame", "UICenter", BackdropTemplateMixin and "BackdropTemplate" or "", nil, function(self, ...)
		-- Manually embed our methods,
		-- we do not want to change the meta table.
		for i,v in pairs(Container) do
			if (not self[i]) then
				self[i] = v
			end
		end
		-- Run user styling and setup.
		if (styleFunc) then
			return styleFunc(self, ...)
		end
	end)

	-- Allow clicking the frame to raise it, the WorldMapFrame does it too. 
	-- Requires that they have the same strata.
	frame:SetFrameStrata(WorldMapFrame:GetFrameStrata() or "MEDIUM")
	frame:SetToplevel(true) 
	frame:EnableMouse(true)
	frame:Hide()

	frame.buttons = {}
	frame.slots = {}

	-- It just makes life easier if we simply hide it, 
	-- or we will have to forceUpdate everything on zoning.
	frame:RegisterEvent("PLAYER_ENTERING_WORLD", frame.Hide, true)

	-- Store it in our registry.
	Containers[frame] = bagType

	return frame
end

local hidden = CreateFrame("Frame")
hidden:Hide()

-- @input bagType <integer,string> bagID or bagType
-- @return <frame> the button
LibBagButton.SpawnItemButton = function(self, ...)
	local bagType, bagID, slotID

	local numArgs = select("#", ...)
	if (numArgs == 1) then
		bagType = ...
		check(bagType, 1, "string")

	elseif (numArgs == 2) then
		bagID, slotID = ...
		check(bagID, 1, "number")
		check(slotID, 2, "number")
		bagType = BagTypesFromID[bagID]

		-- An illegal bagType has been requested.
		if (not bagType) then
			return error(string_format("No bagType for the bagID '%d' exists!", bagID))
		end
	end

	-- An unknown bagType was requested.
	if (not Buttons[bagType]) then
		return error(string_format("No bagType named '%s' exists!", bagType))
	end

	local button -- virtual button object returned to the user.
	local parent -- hidden button slot parent for bag items, basically a fake bag container.
	local slot -- slot object that contains the "actual" button with functional blizz scripts and methods.

	-- Our virtual object. We don't want the front-end to directly
	-- interact with any of the actual objects created below.
	--button = setmetatable(self:CreateFrame(BUTTON_TYPE), Button_MT)
	button = setmetatable(self:CreateFrame("Frame"), Button_MT)
	button:EnableMouse(false)
	button.bagType = bagType
	button.bagID = bagID
	button.slotID = slotID
	button.colors = Colors

	-- This is basically a bag for all intents and purposes, 
	-- except that it totally isn't that at all. 
	-- We just need a parent for the slot with and ID for the template to work.
	parent = button:CreateFrame("Frame")
	--parent:SetAllPoints()
	parent:EnableMouse(false)
	parent:SetID(bagID or 100)

	-- Need to clear away blizzard layers from this one, 
	-- as they interfere with anything we do.
	slot = parent:CreateFrame(BUTTON_TYPE, nil, ButtonTemplates[bagType])
	slot:SetAllPoints(button) -- bypass the parent/fakebag object
	slot:SetPoint("CENTER", button, "CENTER", 0, 0)
	slot:EnableMouse(true)

	-- BlizzKill
	slot.UpdateTooltip = nil
	slot:DisableDrawLayer("BACKDROP")
	slot:DisableDrawLayer("BORDER")
	slot:DisableDrawLayer("ARTWORK")
	slot:DisableDrawLayer("OVERLAY")
	slot:GetNormalTexture():SetParent(hidden)
	slot:GetPushedTexture():SetParent(hidden)
	slot:GetHighlightTexture():SetParent(hidden)

	slot:SetID(slotID or 0)
	slot:Show() -- do this before we add the scripthandlers below!

	-- Set Scripts
	-- Let these be proxies
	slot:SetScript("OnEnter", function(slot) button:OnEnter() end)
	slot:SetScript("OnLeave", function(slot) button:OnLeave() end)
	--slot:SetScript("OnHide", function(slot) button:OnHide() end)
	--slot:SetScript("OnShow", function(slot) button:OnShow() end)
	--slot:SetScript("OnEvent", function(slot) button:OnEvent() end)

	button:SetScript("OnHide", button.OnHide)
	button:SetScript("OnShow", button.OnShow)
	button:SetScript("OnEvent", button.OnEvent)

	-- Cache up our elements 
	ButtonParents[button] = parent
	ButtonSlots[button] = slot

	-- Insert the virtual button slot object into the correct cache.
	table_insert(Buttons[bagType], button) 

	-- Button Scaffolds
	-----------------------------------------------------------
	-- Frame to contain art overlays, texts, etc
	local overlay = button:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(button:GetFrameLevel() + 2)

	-- Button Layers
	-----------------------------------------------------------
	-- Slot backdrop visible on empty buttons 
	local slot = button:CreateTexture()
	slot:SetDrawLayer("BACKGROUND", -1)
	slot:SetAllPoints()
	button.Slot = slot

	-- Button icon
	local icon = button:CreateTexture()
	icon:SetDrawLayer("BACKGROUND", 0)
	icon:SetAllPoints()
	icon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
	button.Icon = icon

	-- Cooldown frame

	-- Border texture
	-- Used to indicate rarity and quest items
	local border = overlay:CreateTexture()
	border:SetDrawLayer("BORDER", 0)
	border:SetAllPoints()
	button.Border = border

	-- Item count text
	local count = overlay:CreateFontString()
	count:SetDrawLayer("BORDER", 1)
	count:SetPoint("BOTTOMRIGHT", -7, 8)
	count:SetFontObject(NumberFontNormal)
	count:SetJustifyH("RIGHT")
	count:SetJustifyV("BOTTOM")
	button.Count = count

	-- Item level text
	local level = overlay:CreateFontString()
	level:SetDrawLayer("BORDER", 1)
	level:SetPoint("TOPLEFT", 8, -8)
	level:SetFontObject(NumberFontSmall)
	level:SetJustifyH("LEFT")
	level:SetJustifyV("TOP")
	button.ItemLevel = level

	-- BoE, BoU, BoA text
	local bind = overlay:CreateFontString()
	bind:SetDrawLayer("BORDER", 1)
	bind:SetPoint("BOTTOMLEFT", 8, 8)
	bind:SetFontObject(NumberFontSmall)
	bind:SetJustifyH("LEFT")
	bind:SetJustifyV("BOTTOM")
	button.ItemBind = bind

	-- Quest texture for quest starters
	local quest = overlay:CreateTexture()
	quest:SetDrawLayer("BORDER", 2)
	quest:SetPoint("BOTTOMLEFT", -1, 8)
	quest:SetSize(32,32)
	quest:SetTexture([[Interface\MINIMAP\TRACKING\OBJECTICONS]])
	quest:SetTexCoord(1/8,2/8,1/2,1)
	quest:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	button.QuestIcon = quest

	-- Gold texture for vendor trash
	local coin = overlay:CreateTexture()
	coin:SetDrawLayer("BORDER", 2)
	coin:SetPoint("TOPLEFT",8,-8)
	coin:SetSize(14,14)
	coin:SetTexture([[Interface\MoneyFrame\UI-GoldIcon]])
	coin:SetVertexColor(1,.82,0)
	button.CoinIcon = coin

	-- Return the button slot object to the user
	return button
end

-- Returns the free,total space in a specific container.
-- *Will return 0,0 if no information is yet available.
LibBagButton.GetFreeBagSpaceInBag = function(self, bagID)
	local cache = Contents[bagID]
	if (not cache) then
		return 0,0
	end
	return cache.freeSlots or 0, cache.totalSlots or 0
end

-- Returns the free bag space.
-- @input <number> query a certain bagType only. 
-- @return <number,number> currentFree, totalFree 
LibBagButton.GetFreeBagSpace = function(self, bagType)
	local freeSlots, totalSlots = 0, 0
	if (not bagType) then 
		bagType = 0 -- 0 means regular non-profession containers
	end
	if (not LibBagButton.freeSlots) then
		LibBagButton.freeSlots = {}
	end
	if (not LibBagButton.totalSlots) then
		LibBagButton.totalSlots = {}
	end
	if (LibBagButton.parsingRequired) or (not LibBagButton.freeSlots[bagType]) or (not LibBagButton.totalSlots[bagType]) then
		for i,bagID in pairs(bagIDs) do
			if (BagTypesFromID[bagID] == "Bag") then
				local cache = Contents[bagID]
				if (cache) and (cache.bagType == bagType) then 
					totalSlots = totalSlots + cache.totalSlots
					freeSlots = freeSlots + cache.freeSlots
				end
			end
			LibBagButton.freeSlots[bagType] = freeSlots
			LibBagButton.totalSlots[bagType] = totalSlots
		end
		LibBagButton.parsingRequired = nil
	end
	return LibBagButton.freeSlots[bagType] or 0, LibBagButton.totalSlots[bagType] or 0	
end

-- Returns the free bank space.
-- *Will returned a cached value if not currently at the bank,
-- @input <number> query a certain bagType only. 
-- @return <number,number> currentFree, totalFree 
LibBagButton.GetFreeBankSpace = function(self, bagType)
	local freeSlots, totalSlots = 0, 0
	if (not bagType) then 
		bagType = 0 -- 0 means regular non-profession containers
	end
	if (not LibBagButton.freeBankSlots) then
		LibBagButton.freeBankSlots = {}
	end
	if (not LibBagButton.totalBankSlots) then
		LibBagButton.totalBankSlots = {}
	end
	if (LibBagButton:IsAtBank()) then
		for i,bagID in pairs(bankIDs) do
			if (BagTypesFromID[bagID] == "Bank") then
				local cache = Contents[bagID]
				if (cache) and (cache.bagType == bagType) then 
					totalSlots = totalSlots + cache.totalSlots
					freeSlots = freeSlots + cache.freeSlots
				end
			end
		end
		LibBagButton.freeBankSlots[bagType] = freeSlots
		LibBagButton.totalBankSlots[bagType] = totalSlots
	end
	return LibBagButton.freeBankSlots[bagType] or 0, LibBagButton.totalBankSlots[bagType] or 0
end

LibBagButton.GetIteratorForBagIDs = function(self)
	local new = {}
	for i,bagID in pairs(bagIDs) do
		if (BagTypesFromID[bagID] == "Bag") then
			new[#new + 1] = bagID
		end
	end
	table_sort(new, sortAscending)
	return ipairs(new)
end

LibBagButton.GetIteratorForBagIDsReversed = function(self)
	local new = {}
	for i,bagID in pairs(bagIDs) do
		if (BagTypesFromID[bagID] == "Bag") then
			new[#new + 1] = bagID
		end
	end
	table_sort(new, sortDescending)
	return ipairs(new)
end

LibBagButton.GetIteratorForBankIDs = function(self)
	local new = {}
	for i,bagID in pairs(bankIDs) do
		if (BagTypesFromID[bagID] == "Bank") then
			new[#new + 1] = bagID
		end
	end
	return ipairs(new)
end

LibBagButton.GetIteratorForReagentBankIDs = function(self)
	local new = {}
	return ipairs(new)
end

-- Returns true if any carried container is open.
-- Does not apply to bank.
LibBagButton.IsAnyBagOpen = function(self)
	for container, bagType in pairs(Containers) do
		if (bagType == "Bag") and (container:IsShown()) then
			return true
		end
	end
end

-- Returns true if we're at the bank.
LibBagButton.IsAtBank = function(self)
	return LibBagButton.atBank
end

-- Module embedding
local embedMethods = {
	GetIteratorForBagIDs = true,
	GetIteratorForBagIDsReversed = true,
	GetIteratorForBankIDs = true,
	GetIteratorForReagentBankIDs = true,
	GetFreeBagSpace = true,
	GetFreeBagSpaceInBag = true, 
	GetFreeBankSpace = true,
	IsAnyBagOpen = true,
	IsAtBank = true,
	SpawnItemContainer = true,
	SpawnItemButton = true
}

LibBagButton.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibBagButton.embeds) do
	LibBagButton:Embed(target)
end

-- Always needed, for library upgrades too!
LibBagButton:Start()