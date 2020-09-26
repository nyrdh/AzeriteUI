local LibDurability = Wheel:Set("LibDurability", 3)
if (not LibDurability) then
	return
end

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibDurability requires LibMessage to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibDurability requires LibEvent to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibDurability requires LibFrame to be loaded.")

LibMessage:Embed(LibDurability)
LibEvent:Embed(LibDurability)
LibFrame:Embed(LibDurability)

-- Library registries
LibDurability.embeds = LibDurability.embeds or {}
LibDurability.widgets = LibDurability.widgets or {}

-- Speed
local Widgets = LibDurability.widgets

-- Lua API
local _G = _G
local pairs = pairs

-- WoW API
local GetInventoryAlertStatus = GetInventoryAlertStatus
local OffhandHasWeapon = C_PaperDollInfo.OffhandHasWeapon

-- Sourced from INVENTORY_ALERT_STATUS_SLOTS in FrameXML/DurabilityFrame.lua
local inventorySlots = {
	[ 1] = { slot = "Head" },
	[ 2] = { slot = "Shoulders" },
	[ 3] = { slot = "Chest" },
	[ 4] = { slot = "Waist" },
	[ 5] = { slot = "Legs" },
	[ 6] = { slot = "Feet" },
	[ 7] = { slot = "Wrists" },
	[ 8] = { slot = "Hands" },
	[ 9] = { slot = "Weapon", showSeparate = 1 },
	[10] = { slot = "Shield", showSeparate = 1 },
	[11] = { slot = "Ranged", showSeparate = 1 }
}

local inventoryColors = {
	default = { 1, 1, 1, .5 },
	[1] = { 1, .82, .18 },
	[2] = { .93, .07, .07 }
}

local durabilityPath = [[Interface\Durability\UI-Durability-Icons]]

-- Custom widget methods
local Widget = {
	SetTexture = function(self, path)
		self.Head:SetTexture(path)
		self.Shoulders:SetTexture(path)
		self.Chest:SetTexture(path)
		self.Wrists:SetTexture(path)
		self.Hands:SetTexture(path)
		self.Waist:SetTexture(path)
		self.Legs:SetTexture(path)
		self.Feet:SetTexture(path)
		self.Weapon:SetTexture(path)
		self.Shield:SetTexture(path)
		self.OffHand:SetTexture(path)
		self.Ranged:SetTexture(path)
	end
}

LibDurability.OnEvent = function(self, event, ...)
	for module,widget in pairs(Widgets) do
		self:UpdateDurabilityWidget(widget)
	end
end

LibDurability.UpdateDurabilityWidget = function(self, frame, forced)
	local numAlerts = 0
	local texture, showDurability
	local hasLeft, hasRight

	for index,value in pairs(inventorySlots) do
		texture = frame[value.slot]
		if (value.slot == "Shield") then
			if (OffhandHasWeapon()) then
				frame.Shield:Hide()
				texture = frame.OffHand
			else
				frame.OffHand:Hide()
				texture = frame.Shield
			end
		end

		local alert = GetInventoryAlertStatus(index)
		local color = alert and inventoryColors[alert]
		if (forced and not color) then
			color = inventoryColors.default
		end
		if (color) then
			texture:SetVertexColor(color[1], color[2], color[3], 1.0)
			if (value.showSeparate) then
				if ((value.slot == "Shield") or (value.slot == "Ranged")) then
					hasRight = true
				elseif (value.slot == "Weapon") then
					hasLeft = true
				end
				texture:Show()
			else
				showDurability = 1
			end
			numAlerts = numAlerts + 1
		else
			texture:SetVertexColor(1, 1, 1, .5)
			if (value.showSeparate) then
				texture:Hide()
			end
		end
	end

	for index, value in pairs(inventorySlots) do
		if (not value.showSeparate) then
			local texture = frame[value.slot]
			if (showDurability) then
				frame[value.slot]:Show()
			else
				frame[value.slot]:Hide()
			end
		end
	end

	local width = 58
	if (hasRight) then
		frame.Head:SetPoint("TOPRIGHT", -40, 0)
		width = width + 20
	else
		frame.Head:SetPoint("TOPRIGHT", -20, 0)
	end
	if (hasLeft) then
		width = width + 14
	end
	frame:SetWidth(width)

	if (numAlerts > 0) or (forced) then
		frame:Show()
	else
		frame:Hide()
	end

end

LibDurability.GetDurabilityWidget = function(self)
	if (not Widgets[self]) then
		-- Create a carbon copy of the blizzard durability frame.
		-- Everything here found in FrameXML/DurabilityFrame.xml
		local frame = LibDurability:CreateFrame("Frame", nil, "UICenter")
		frame:SetSize(60,75)

		local head = frame:CreateTexture()
		head:SetSize(18,22)
		head:SetPoint("TOPRIGHT")
		head:SetDrawLayer("BACKGROUND", 0)
		head:SetTexCoord(0, .140625, 0, .171875)
		frame.Head = head

		local shoulders = frame:CreateTexture()
		shoulders:SetSize(48,22)
		shoulders:SetPoint("TOP", head, "BOTTOM", 0,16)
		shoulders:SetDrawLayer("BACKGROUND", 0)
		shoulders:SetTexCoord(.140625, .515625, 0, .171875)
		frame.Shoulders = shoulders

		local chest = frame:CreateTexture()
		chest:SetSize(20,22)
		chest:SetPoint("TOP", shoulders, "TOP", 0,-7)
		chest:SetDrawLayer("BACKGROUND", 0)
		chest:SetTexCoord(.515625, .6640625, 0, .171875)
		frame.Chest = chest

		local wrists = frame:CreateTexture()
		wrists:SetSize(44,22)
		wrists:SetPoint("TOP", shoulders, "BOTTOM", 0,7)
		wrists:SetDrawLayer("BACKGROUND", 0)
		wrists:SetTexCoord(.6640625, 1, 0, .171875)
		frame.Wrists = wrists

		local hands = frame:CreateTexture()
		hands:SetSize(42,18)
		hands:SetPoint("TOP", wrists, "BOTTOM", 0,15)
		hands:SetDrawLayer("BACKGROUND", 0)
		hands:SetTexCoord(0, .328125, .171875, .3046875)
		frame.Hands = hands

		local waist = frame:CreateTexture()
		waist:SetSize(16,5)
		waist:SetPoint("TOP", chest, "BOTTOM", 0,6)
		waist:SetDrawLayer("BACKGROUND", 0)
		waist:SetTexCoord(.328125, .46875, .171875, .203125)
		frame.Waist = waist

		local legs = frame:CreateTexture()
		legs:SetSize(29,20)
		legs:SetPoint("TOP", waist, "BOTTOM", 0,2)
		legs:SetDrawLayer("BACKGROUND", 0)
		legs:SetTexCoord(.46875, .6875, .171875, .3203125)
		frame.Legs = legs

		local feet = frame:CreateTexture()
		feet:SetSize(41,32)
		feet:SetPoint("TOP", legs, "BOTTOM", 0,8)
		feet:SetDrawLayer("BACKGROUND", 0)
		feet:SetTexCoord(.6875, 1, .171875, .4140625)
		frame.Feet = feet

		local weapon = frame:CreateTexture()
		weapon:SetSize(20,45)
		weapon:SetPoint("RIGHT", wrists, "LEFT", 0,-6)
		weapon:SetDrawLayer("BACKGROUND", 0)
		weapon:SetTexCoord(0, .140625, .3203125, .6640625)
		frame.Weapon = weapon

		local shield = frame:CreateTexture()
		shield:SetSize(25,31)
		shield:SetPoint("LEFT", wrists, "RIGHT", 0,10)
		shield:SetDrawLayer("BACKGROUND", 0)
		shield:SetTexCoord(.1875, .375, .3203125, .5546875)
		frame.Shield = shield

		local offHand = frame:CreateTexture()
		offHand:SetSize(20,45)
		offHand:SetPoint("LEFT", wrists, "RIGHT", 0,-6)
		offHand:SetDrawLayer("BACKGROUND", 0)
		offHand:SetTexCoord(0, .140625, .3203125, .6640625)
		frame.OffHand = offHand

		local ranged = frame:CreateTexture()
		ranged:SetSize(28,38)
		ranged:SetPoint("TOP", shield, "BOTTOM", 0,5)
		ranged:SetDrawLayer("BACKGROUND", 0)
		ranged:SetTexCoord(.1875, .3984375, .5546875, .84375)
		frame.Ranged = ranged

		-- Apply custom methods
		for method,func in pairs(Widget) do
			frame[method] = func
		end

		-- Assign default texture
		frame:SetTexture(durabilityPath)

		frame.Update = function(self, forced)
			LibDurability:UpdateDurabilityWidget(self, forced)
		end

		Widgets[self] = frame
		
		-- Register events for automatic updates
		LibDurability:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
		LibDurability:RegisterEvent("UPDATE_INVENTORY_ALERTS", "OnEvent")
	end
	return Widgets[self]
end

local embedMethods = {
	GetDurabilityWidget = true
}

LibDurability.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibDurability.embeds) do
	LibDurability:Embed(target)
end
