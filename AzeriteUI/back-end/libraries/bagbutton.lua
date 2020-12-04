local LibBagButton = Wheel:Set("LibBagButton", 17)
if (not LibBagButton) then	
	return
end

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibBagButton requires LibEvent to be loaded.")

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibBagButton requires LibMessage to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibBagButton requires LibClientBuild to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibBagButton requires LibFrame to be loaded.")

local LibTooltipScanner = Wheel("LibTooltipScanner")
assert(LibTooltipScanner, "LibBagButton requires LibTooltipScanner to be loaded.")

local LibTooltip = Wheel("LibTooltip")
assert(LibTooltip, "LibBagButton requires LibTooltip to be loaded.")

LibEvent:Embed(LibBagButton)
LibMessage:Embed(LibBagButton)
LibFrame:Embed(LibBagButton)
LibTooltip:Embed(LibBagButton)

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_format = string.format
local string_join = string.join
local string_match = string.match
local tonumber = tonumber
local type = type
local unpack = unpack

-- WoW API
local GetContainerItemLink = GetContainerItemLink
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local GetContainerNumSlots = GetContainerNumSlots
local GetItemInfo = GetItemInfo
local GetItemInfoInstant = GetItemInfoInstant
local IsLoggedIn = IsLoggedIn

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
LibBagButton.contents = LibBagButton.contents or {} -- cache of actual bank and bag contents
LibBagButton.queuedContainerIDs = LibBagButton.queuedContainerIDs or {} -- Queue system for uncached items 
LibBagButton.queuedItemIDs = LibBagButton.queuedItemIDs or {} -- Queue system for uncached items 

-- Speed
local Buttons = LibBagButton.buttons
local ButtonParents = LibBagButton.buttonParents
local ButtonSlots = LibBagButton.buttonSlots
local Containers = LibBagButton.containers
local Contents = LibBagButton.contents
local QueuedContainerIDs = LibBagButton.queuedContainerIDs
local QueuedItemIDs = LibBagButton.queuedItemIDs

-- Sourced from FrameXML/BankFrame.lua
-- Bag containing the 7 (or 6 in classic) bank bag buttons. 
local BANK_SLOT_CONTAINER = -4

-- This one does not exist. We made it up.
local BAG_SLOT_CONTAINER = -100

-- Button templates
-----------------------------------------------------------------
-- Frame type of slot buttons
local BUTTON_TYPE = IsClassic and "Button" or "ItemButton" 

-- Frame template of itembuttons in each bagType.
-- This table will have both the bagTypes and all bagIDs as keys, 
-- making it a good tool to compare slot button compatibility on bagID changes.
local ButtonTemplates = {
	Bag = "ContainerFrameItemButtonTemplate", -- bag itembutton
	Bank = "BankItemButtonGenericTemplate", -- bank itembutton
	ReagentBank = "BankItemButtonGenericTemplate", -- reagent bank itembutton
	KeyRing = "ContainerFrameItemButtonTemplate", -- keyring itembutton
	BagSlot = "BagSlotButtonTemplate", -- equippable bag container slot
	BankSlot = "BankItemButtonBagTemplate" -- equippable bank container slot
}

-- Localized names for the bags. 
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

-- Setup all bag tables.
local bagIDs = {}
local isBagID = { [BACKPACK_CONTAINER] = true }
for id = BACKPACK_CONTAINER + 1, NUM_BAG_SLOTS do
	isBagID[id] = true
	bagIDs[#bagIDs + 1] = id
	ButtonTemplates[id] = ButtonTemplates.Bag
	BagTypesFromID[id] = "Bag"
end

-- Setup all bank tables.
local bankIDs = {}
local isBankID = { [BANK_CONTAINER] = true }
for id = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
	isBankID[id] = true
	bankIDs[#bankIDs + 1] = id
	ButtonTemplates[id] = ButtonTemplates.Bank
	BagTypesFromID[id] = "Bank"
end

-- This only exists in classic, 
-- but we leave the empty tables for a simpler API.
local isKeyRingID = {}
if (IsClassic) then
	isBagID[KEYRING_CONTAINER] = true
	isKeyRingID[KEYRING_CONTAINER] = true
	bagIDs[#bagIDs + 1] = KEYRING_CONTAINER
	ButtonTemplates[KEYRING_CONTAINER] = ButtonTemplates.KeyRing
	BagNames[KEYRING_CONTAINER] = KEYRING
	BagTypesFromID[KEYRING_CONTAINER] = "KeyRing"
end

-- This only exists in retail, 
-- but we leave the empty tables for a simpler API.
local isReagentBankID = {}
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

-- Button Templates
-- These do not have to be connected to any container object,
-- and thus do not rely on bag/bank opening events to be shown.
-- You can use them to track quest items, food, whatever.
-----------------------------------------------------------------
local Button = LibBagButton:CreateFrame(BUTTON_TYPE)
local Button_MT = { __index = Button }

-- Set the bagID of the button.
-- Only accept changes within the same bagType range,
-- silentyly fail if a template change is attempted.
-- Reason we can't change templates is because of the
-- Blizzard OnClick functionality needed for interaction,
-- which can't be modified, added or changed after creation.
Button.SetBagID = function(self, bagID)
	-- First compare the old bagID to the new one.
	local oldBagID = ButtonParents[self]:GetID()
	if (oldBagID ~= bagID) then
		-- If we requested a new ID, see if the old and new share button templates,
		-- as this will tell us whether or not the bagIDs are interchangeable.
		if (ButtonTemplates[oldBagID] == ButtonTemplates[bagID]) then
			ButtonParents[self]:SetID(bagID)
			self:Update()
		end
	end
end

-- Change the slotID of a button.
Button.SetSlotID = function(self, slotID)
	local oldSlotID = ButtonSlots[self]:GetID()
	if (oldSlotID ~= slotID) then
		ButtonSlots[self]:SetID(oldSlotID)
		self:Update()
	end
end

Button.SetBagAndSlotID = function(self, bagID, slotID)
	-- See if any of the IDs are changed.
	local oldBagID = ButtonParents[self]:GetID()
	local oldSlotID = ButtonSlots[self]:GetID()
	if (oldBagID ~= bagID) or (oldSlotID ~= slotID) then
		-- If we had a change, make sure it's a valid one.
		if (ButtonTemplates[oldBagID] == ButtonTemplates[bagID]) then
			ButtonParents[self]:SetID(bagID)
			ButtonSlots[self]:SetID(oldSlotID)
			self:Update()
		end
	end
end

-- Updates the icon of a slot button.
Button.UpdateIcon = function(self)
end

-- Updates the stack/charge count of a slot button.
Button.UpdateCount = function(self)
end

-- Updates the rarity colorign of a slot button.
Button.UpdateRarity = function(self)
end

-- Updates the quest icons of a slot button.
Button.UpdateQuest = function(self)
end

-- Updates all the sub-elements of a slot button at once.
Button.Update = function(self)
	self:UpdateIcon()
	self:UpdateCount()
	self:UpdateRarity()
	self:UpdateQuest()
end

Button.GetTooltip = function(self)
	return LibBagButton:GetBagButtonTooltip()
end

-- Container Template
-- This is NOT the equivalent of the blizzard bags,
-- as our containers are not restricted to specific bagIDs.
-- Containers do however respond to game events
-- for showing/hiding/toggling the bags and bank.
-----------------------------------------------------------------
local Container = LibBagButton:CreateFrame("Frame")
local Container_MT = { __index = Container }

Container.SetFilter = function(self, filterMethod)
end

Container.SetSorting = function(self, sortMethod)
end

Container.GetTooltip = function(self)
	return LibBagButton:GetBagButtonTooltip()
end

-- Library API
-----------------------------------------------------------------
LibBagButton.SpawnContainer = function(self)


end

-- @input bagType <integer,string> bagID or bagType
-- @return <frame> the button
LibBagButton.SpawnItemButton = function(self, bagType)
	check(bagType, 1, "string", "number")

	-- A bagID was provided, translate it to backType and validate.
	local bagID
	if (type(bagType) == "number") then
		bagID = bagType
		bagType = BagTypesFromID[bagType]

		-- An illegal bagType has been requested.
		if (not bagType) then
			return error(string_format("No bagType for the bagID '%d' exists!", bagID))
		end
	end

	-- An unknown bagType was requested.
	if (not Buttons[bagType]) then
		return error(string_format("No bagType named '%d' exists!", bagID))
	end

	local button -- vertual button object returned to the user
	local parent -- hidden button parent for bag items
	local slot -- slot object that contains the "actual" button

	button = setmetatable(self:CreateFrame(BUTTON_TYPE), Button_MT)

	parent = button:CreateFrame("Frame")
	parent:SetAllPoints()



	slot = parent:CreateFrame(BUTTON_TYPE, nil, ButtonTemplates[bagID])
	slot:SetAllPoints()

	-- Cache up our elements 
	ButtonParents[button] = parent
	ButtonSlots[button] = slot

	-- Insert the virtual button slot object into the correct cache.
	table_insert(Buttons[bagType], button) 

	--[[-- 

		frame
			backdrop
			icon

		cooldownframe
			cooldown

		borderframe
			border
			stack

		overlayframe
			itemlevel
			questtexture

	--]]--

	-- Return the button slot object to the user
	return button
end

LibBagButton.GetBagButtonTooltip = function(self)
	return LibSecureButton:GetTooltip("GP_BagButtonTooltip") or LibSecureButton:CreateTooltip("GP_BagButtonTooltip")
end

--[[-- 
	local numberOfFreeSlots, bagType = GetContainerNumFreeSlots(bagID)
	bagType = 2^(bitfield-1) 
	(https://wow.gamepedia.com/ItemFamily)
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

LibBagButton.GetContainerCache = function(self, bagID)
	if (not Contents[bagID]) then
		Contents[bagID] = {}
	end
	return Contents[bagID]
end

LibBagButton.GetContainerSlotCache = function(self, bagID, slotID)
	if (not Contents[bagID]) then
		Contents[bagID] = {}
	end
	if (not Contents[bagID][slotID]) then
		Contents[bagID][slotID] = {}
	end
	return Contents[bagID][slotID]
end

LibBagButton.ClearContainerSlot = function(self, bagID, slotID)
	if (Contents[bagID]) then
		if (Contents[bagID][slotID]) then
			for i in pairs(Contents[bagID][slotID]) do
				Contents[bagID][slotID][i] = nil
			end
		end
	end
end

LibBagButton.ParseContainerSlot = function(self, bagID, slotID)
	local _
	local itemID, itemName, itemIcon, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount
	local itemEquipLoc, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent
	local isQuestItem, questID, isActive

	local itemLink = GetContainerItemLink(bagID, slotID)
	if (itemLink) then

		local Item = self:GetContainerSlotCache(bagID, slotID)
		if (Item.itemLink ~= itemLink) then

			-- No quest item info in classic
			if (not IsClassic) then
				isQuestItem, questID, isActive = GetContainerItemQuestInfo(bagID, slotID)
			end

			itemName, _, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent = GetItemInfo(itemLink)
			
			-- Get some basic info if the item hasn't been cached up yet
			if (not itemName) then
				if (not QueuedContainerIDs[bagID]) then
					QueuedContainerIDs[bagID] = {}
				end
				if (not QueuedContainerIDs[bagID][slotID]) then
					QueuedContainerIDs[bagID][slotID] = itemID
				end
				self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnEvent")
	
				-- Use the client-only API for faster lookups here
				itemID, itemType, itemSubType, itemEquipLoc, itemIcon, itemClassID, itemSubClassID = GetItemInfoInstant(itemLink)
			end

			Item.itemID = itemID or tonumber(string_match(itemLink, "item:(%d+)"))
			Item.itemString = string_match(itemLink, "item[%-?%d:]+")
			Item.itemName = itemName
			Item.itemLink = itemLink
			Item.itemRarity = itemRarity
			Item.itemLevel = itemLevel
			Item.itemMinLevel = itemMinLevel
			Item.itemType = itemType
			Item.itemSubType = itemSubType
			Item.itemStackCount = itemStackCount
			Item.itemEquipLoc = itemEquipLoc
			Item.itemEquipLocLabel = (itemEquipLoc and (itemEquipLoc ~= "")) and _G[itemEquipLoc] or nil
			Item.itemIcon = itemIcon
			Item.itemSellPrice = itemSellPrice
			Item.itemClassID = itemClassID
			Item.itemSubClassID = itemSubClassID
			Item.bindType = bindType
			Item.expacID = expacID
			Item.itemSetID = itemSetID
			Item.isCraftingReagent = isCraftingReagent
			Item.isUsable = IsUsableItem(Item.itemID)
			Item.isQuestItem = isQuestItem
			Item.isQuestActive = isQuestItem and isActive
			Item.isUsableQuestItem = Item.isQuestItem and Item.isUsable
			Item.questID = isQuestItem and questID
		end

	end
end

LibBagButton.ParseSingleContainer = function(self, bagID)

	local numberOfSlots = GetContainerNumSlots(bagID) or 0 -- returns 0 before the BAG_UPDATE for the bagID has fired.
	local numberOfFreeSlots, bagType = GetContainerNumFreeSlots(bagID) or -1

	if (numberOfSlots > 0) then

		local Container = self:GetContainerCache(bagID)
		Container.bagType = bagType
		Container.freeSlots = numberOfFreeSlots
		Container.totalSlots = numberOfSlots
		Container.name = BagNames[bagID] or GetBagName(bagID)

		for slotID = 1, numberOfSlots do
			self:ParseContainerSlot(bagID, slotID)
		end
	end
end

LibBagButton.ParseMultipleContainers = function(self, ...)
	local bagID
	local numContainers = select("#", ...)
	if (numContainers) and (numContainers > 0) then
		for i = 1,numContainers do
			bagID = select(i, ...)
			local numberOfFreeSlots, numberOfFreeSlots, bagType
			self:ParseSingleContainer(bagID)
		end
	end
end

LibBagButton.IsAtBank = function(self)
	return self.atBank
end

-- Shows your bag frames
LibBagButton.ShowBags = function(self)
end

LibBagButton.HideBags = function(self)
end

-- Toggles your bag frames
LibBagButton.ToggleBags = function(self)
end

-- Displays your bank frames.
-- Will use stored information when available, 
-- making it possible to track bank contents when not at the bank.
-- TODO: Add API to assign a cache at container creation!
LibBagButton.ShowBank = function(self)
end

LibBagButton.HideBank = function(self)
end

-- Toggles your bank frames.
LibBagButton.ToggleBank = function(self)
end

LibBagButton.HookGameEvents = function(self)

	-- backpack
	local Blizzard_ToggleBackpack = ToggleBackpack
	ToggleBackpack = function()
		if (not LibBagButton:ToggleBags()) then
			Blizzard_ToggleBackpack()
		end
	end

	local Blizzard_OpenBackpack = OpenBackpack
	OpenBackpack = function()
		if (not LibBagButton:ShowBags()) then
			Blizzard_OpenBackpack()
		end
	end

	-- single bag
	local Blizzard_ToggleBag = ToggleBag
	ToggleBag = function(bag)
		if (not LibBagButton:ToggleBags()) then
			Blizzard_ToggleBag(bag)
		end
	end

	local Blizzard_OpenBag = OpenBag
	OpenBag = function(bag)
		if (not LibBagButton:ShowBags()) then
			Blizzard_OpenBag(bag)
		end
	end

	-- all bags
	local Blizzard_OpenAllBags = OpenAllBags
	OpenAllBags = function(frame)
		if (not LibBagButton:ShowBags()) then
			Blizzard_OpenAllBags(frame)
		end
	end

	if (ToggleAllBags) then
		local Blizzard_ToggleAllBags = ToggleAllBags
		ToggleAllBags = function()
			if (not LibBagButton:ToggleBags()) then
				Blizzard_ToggleAllBags()
			end
		end
	end
end

LibBagButton.OnEvent = function(self, event, ...)
	if (event == "BANKFRAME_OPENED") then
		self.atBank = true
		self:ParseMultipleContainers(unpack(bankIDs))
		self:ShowBank()
		self:ShowBags()
		self:SendMessage("GP_BANKFRAME_OPENED")

	elseif (event == "BANKFRAME_CLOSED") then
		self.atBank = nil
		self:HideBank()
		self:HideBags()
		self:SendMessage("GP_BANKFRAME_CLOSED")

	elseif (event == "BAG_UPDATE") then
		local bagID = ...

		-- This is where the actual magic happens. 
		self:ParseSingleContainer(bagID)
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
						self:ParseContainerSlot(bagID, slotID)
						self:SendMessage("GP_GET_ITEM_INFO_RECEIVED",  updatedItemID, success, bagID, slotID)
						self:SendMessage("GP_BAG_UPDATE", bagID, slotID)

					-- Item does not exist, clear it
					elseif (success == nil) then
						-- Clear this slot
						self:ClearContainerSlot(bagID, slotID)
						self:SendMessage("GP_GET_ITEM_INFO_RECEIVED",  updatedItemID, success, bagID, slotID)
						self:SendMessage("GP_BAG_UPDATE", bagID, slotID)
					end

				end
			end
		end
		-- Check if anything is still queued
		for bagID in pairs(QueuedContainerIDs) do
			for slotID, itemID in pairs(QueuedContainerIDs[bagID]) do
				-- If anything is found, just return
				return 
			end
		end
		-- Kill off the event if no more itemslots are queued
		self:UnregisterEvent("GET_ITEM_INFO_RECEIVED", "OnEvent")

	elseif (event == "PLAYER_ENTERING_WORLD") then

		-- Only ever want this once after library enabling.
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")

		-- Now we can start tracking stuff
		self:RegisterEvent("BANKFRAME_OPENED", "OnEvent")
		self:RegisterEvent("BANKFRAME_CLOSED", "OnEvent")

		-- Even though technically all data is available at this point,
		-- information like the size of each container isn't available
		-- until those containers get their BAG_UPDATE event.
		-- This is most likely due to the UI resettings its
		-- internal cache sometimes between these events.
		self:RegisterEvent("BAG_UPDATE", "OnEvent")

		-- Do an initial parsing of the bags.
		-- The results might be lacking because of the above.
		self:ParseMultipleContainers(unpack(bagIDs))

		-- Fire off some semi-fake events.
		-- The idea is to have the front-end only rely on custom messages, 
		-- so we need these here instead of the Blizzard events.
		for _,bagID in ipairs(bagIDs) do
			self:SendMessage("GP_BAG_UPDATE", bagID)
		end

	end
end

LibBagButton.Start = function(self)
	-- Always kill off all events here.
	self:UnregisterAllEvents()

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
end

-- Module embedding
local embedMethods = {
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