local LibUnitFrame = Wheel:Set("LibUnitFrame", 96)
if (not LibUnitFrame) then
	return
end

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibUnitFrame requires LibEvent to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibUnitFrame requires LibFrame to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibSecureButton requires LibClientBuild to be loaded.")

local LibWidgetContainer = Wheel("LibWidgetContainer")
assert(LibWidgetContainer, "LibUnitFrame requires LibWidgetContainer to be loaded.")

local LibTooltip = Wheel("LibTooltip")
assert(LibTooltip, "LibUnitFrame requires LibTooltip to be loaded.")

local LibSound = Wheel("LibSound")
assert(LibSound, "LibUnitFrame requires LibSound to be loaded.")

LibEvent:Embed(LibUnitFrame)
LibFrame:Embed(LibUnitFrame)
LibTooltip:Embed(LibUnitFrame)
LibWidgetContainer:Embed(LibUnitFrame)

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_format = string.format
local string_gsub = string.gsub
local string_join = string.join
local string_lower = string.lower
local string_match = string.match
local table_insert = table.insert
local table_remove = table.remove
local tonumber = tonumber
local type = type
local unpack = unpack

-- Blizzard API
local CreateFrame = CreateFrame
local FriendsDropDown = FriendsDropDown
local GetAddOnEnableState = GetAddOnEnableState
local GetAddOnInfo = GetAddOnInfo
local GetNumAddOns = GetNumAddOns
local SecureCmdOptionParse = SecureCmdOptionParse
local ShowBossFrameWhenUninteractable = ShowBossFrameWhenUninteractable
local ToggleDropDownMenu = ToggleDropDownMenu
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitIsEnemy = UnitIsEnemy
local UnitIsFriend = UnitIsFriend
local UnitName = UnitName

-- Constants for client version
local IsAnyClassic = LibClientBuild:IsAnyClassic()
local IsClassic = LibClientBuild:IsClassic()
local IsTBC = LibClientBuild:IsTBC()
local IsWrath = LibClientBuild:IsWrath()
local IsRetail = LibClientBuild:IsRetail()
local IsDragonflight = LibClientBuild:IsDragonflight()

-- Library Registries
LibUnitFrame.embeds = LibUnitFrame.embeds or {} -- who embeds this?
LibUnitFrame.frames = LibUnitFrame.frames or  {} -- global unitframe registry
LibUnitFrame.scriptHandlers = LibUnitFrame.scriptHandlers or {} -- tracked library script handlers
LibUnitFrame.scriptFrame = LibUnitFrame.scriptFrame -- library script frame, will be created on demand later on

-- Speed shortcuts
local frames = LibUnitFrame.frames
local elements = LibUnitFrame.elements
local callbacks = LibUnitFrame.callbacks
local unitEvents = LibUnitFrame.unitEvents
local frequentUpdates = LibUnitFrame.frequentUpdates
local frequentUpdateFrames = LibUnitFrame.frequentUpdateFrames
local frameElements = LibUnitFrame.frameElements
local frameElementsEnabled = LibUnitFrame.frameElementsEnabled
local scriptHandlers = LibUnitFrame.scriptHandlers
local scriptFrame = LibUnitFrame.scriptFrame

-- Color Table
--------------------------------------------------------------------------
-- RGB to Hex Color Code
local hex = function(r, g, b)
	return ("|cff%02x%02x%02x"):format(math_floor(r*255), math_floor(g*255), math_floor(b*255))
end

-- Convert a Blizzard Color or RGB value set
-- into our own custom color table format.
local prepare = function(...)
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
	if (#tbl == 3) then
		tbl.colorCode = hex(unpack(tbl))
	end
	return tbl
end

-- Convert a whole Blizzard color table
local prepareGroup = function(group)
	local tbl = {}
	for i,v in pairs(group) do
		tbl[i] = prepare(v)
	end
	return tbl
end

-- Default Color Table
local Colors = {
	artifact = prepare( 229/255, 204/255, 127/255 ),
	class = prepareGroup(RAID_CLASS_COLORS),
	dead = prepare( 153/255, 153/255, 153/255 ),
	debuff = prepareGroup(DebuffTypeColor),
	disconnected = prepare( 153/255, 153/255, 153/255 ),
	feedback = {
		DAMAGE 			= prepare( 176/255,  79/255,  79/255 ),
		CRUSHING 		= prepare( 176/255,  79/255,  79/255 ),
		CRITICAL 		= prepare( 176/255,  79/255,  79/255 ),
		GLANCING 		= prepare( 176/255,  79/255,  79/255 ),
		STANDARD 		= prepare( 214/255, 191/255, 165/255 ),
		IMMUNE 			= prepare( 214/255, 191/255, 165/255 ),
		ABSORB 			= prepare( 214/255, 191/255, 165/255 ),
		BLOCK 			= prepare( 214/255, 191/255, 165/255 ),
		RESIST 			= prepare( 214/255, 191/255, 165/255 ),
		MISS 			= prepare( 214/255, 191/255, 165/255 ),
		HEAL 			= prepare(  84/255, 150/255,  84/255 ),
		CRITHEAL 		= prepare(  84/255, 150/255,  84/255 ),
		ENERGIZE 		= prepare(  79/255, 114/255, 160/255 ),
		CRITENERGIZE 	= prepare(  79/255, 114/255, 160/255 )
	},
	health = prepare( 25/255, 178/255, 25/255 ),
	power = { ALTERNATE = prepare(70/255, 255/255, 131/255) },
	quest = {
		red = prepare( 204/255, 25/255, 25/255 ),
		orange = prepare( 255/255, 128/255, 25/255 ),
		yellow = prepare( 255/255, 204/255, 25/255 ),
		green = prepare( 25/255, 178/255, 25/255 ),
		gray = prepare( 153/255, 153/255, 153/255 )
	},
	reaction = prepareGroup(FACTION_BAR_COLORS),
	rested = prepare( 23/255, 93/255, 180/255 ),
	restedbonus = prepare( 192/255, 111/255, 255/255 ),
	tapped = prepare( 153/255, 153/255, 153/255 ),
	xp = prepare( 18/255, 179/255, 21/255 )
}

-- Adding this for semantic reasons,
-- so that plugins can use it for friendly players
-- and the modules will have the choice of overriding it.
Colors.reaction.civilian = Colors.reaction[5]

-- Power bar colors need special handling,
-- as some of them contain sub tables.
for powerType, powerColor in pairs(PowerBarColor) do
	if (type(powerType) == "string") then
		if (powerColor.r) then
			Colors.power[powerType] = prepare(powerColor)
		else
			if powerColor[1] and (type(powerColor[1]) == "table") then
				Colors.power[powerType] = prepareGroup(powerColor)
			end
		end
	end
end

-- Secure Snippets
--------------------------------------------------------------------------
local secureSnippets = {

}

-- Utility Functions
--------------------------------------------------------------------------
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

-- Check if an addon is enabled	in the addon listing
local IsAddOnEnabled = function(target)
	local target = string_lower(target)
	for i = 1,GetNumAddOns() do
		local name, _, _, loadable = GetAddOnInfo(i)
		local enabled = not(GetAddOnEnableState(UnitName("player"), i) == 0)
		if (string_lower(name) == target) then
			if (enabled and loadable) then
				return true
			end
		end
	end
end

-- Create a constant for this
local IS_TOTALRP3_ENABLED = IsAddOnEnabled("totalRP3")

-- Library Updates
--------------------------------------------------------------------------
-- global update limit, no elements can go above this
local THROTTLE = 1/30
local OnUpdate = function(self, elapsed)

	-- Throttle the updates, to increase the performance.
	self.elapsed = (self.elapsed or 0) + elapsed
	if (self.elapsed < THROTTLE) then
		return
	end
	local elapsed = self.elapsed

	for frame, frequentElements in pairs(frequentUpdates) do
		for element, frequency in pairs(frequentElements) do
			if frequency.hz then
				frequency.elapsed = frequency.elapsed + elapsed
				if (frequency.elapsed >= frequency.hz) then
					elements[element].Update(frame, "FrequentUpdate", frame.unit, elapsed)
					frequency.elapsed = 0
				end
			else
				elements[element].Update(frame, "FrequentUpdate", frame.unit)
			end
		end
	end

	self.elapsed = 0
end

-- Unitframe Template
--------------------------------------------------------------------------
local UnitFrame = {}
local UnitFrame_MT = { __index = UnitFrame }

-- Return or create the library default tooltip
-- This is shared by all unitframes, unless these methods
-- are specifically overwritten by the modules.
UnitFrame.GetTooltip = function(self)
	return LibUnitFrame:GetUnitFrameTooltip()
end

UnitFrame.OnEnter = function(self)
	if ((not self.unit) or (not UnitExists(self.unit))) then
		return
	end

	self.isMouseOver = true

	if (IS_TOTALRP3_ENABLED) then
		if (GameTooltip:IsForbidden()) then
			return
		end

		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetUnit(self.unit)

	else
		local tooltip = self:GetTooltip()
		tooltip:Hide()
		tooltip:SetDefaultAnchor(self)
		tooltip:SetMinimumWidth(160)
		tooltip:SetUnit(self.unit)

		if self.PostEnter then
			self:PostEnter()
		end
	end
end

UnitFrame.OnLeave = function(self)
	self.isMouseOver = nil

	if (IS_TOTALRP3_ENABLED) then
		if (GameTooltip:IsForbidden()) then
			return
		end
		GameTooltip:Hide()

	else
		local tooltip = self:GetTooltip()
		tooltip:Hide()

		if self.PostLeave then
			self:PostLeave()
		end
	end
end

UnitFrame.OnHide = function(self)
	self.unitGUID = nil
end

UnitFrame.OverrideAllElements = function(self, event, ...)
	local unit = self.unit
	if (not unit) or (not UnitExists(unit) and not ShowBossFrameWhenUninteractable(unit)) then
		return
	end
	if (self.isMouseOver) then
		local OnEnter = self:GetScript("OnEnter")
		if (OnEnter) then
			OnEnter(self)
		end
	end
	return self:UpdateAllElements(event, ...)
end

-- Special method that only updates the elements if the GUID has changed.
-- Intention is to avoid performance drops from people coming and going in PuG raids.
UnitFrame.OverrideAllElementsOnChangedGUID = function(self, event, ...)
	local unit = self.unit
	if (not unit) or (not UnitExists(unit) and not ShowBossFrameWhenUninteractable(unit)) then
		return
	end
	local currentGUID = UnitGUID(unit)
	if currentGUID and (self.unitGUID ~= currentGUID) then
		self.unitGUID = currentGUID
		if (self.isMouseOver) then
			local OnEnter = self:GetScript("OnEnter")
			if (OnEnter) then
				OnEnter(self)
			end
		end
		if (unit == "target") and (not self.noTargetChangeSoundFX) then
			if (UnitExists("target")) then
				-- Play a fitting sound depending on what kind of target we gained
				if (UnitIsEnemy("target", "player")) then
					LibSound:PlaySoundKitID(SOUNDKIT.IG_CREATURE_AGGRO_SELECT, "SFX")
				elseif (UnitIsFriend("player", "target")) then
					LibSound:PlaySoundKitID(SOUNDKIT.IG_CHARACTER_NPC_SELECT, "SFX")
				else
					LibSound:PlaySoundKitID(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT, "SFX")
				end
			else
				-- Play a sound indicating we lost our target
				LibSound:PlaySoundKitID(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT, "SFX")
			end
		end
		return self:UpdateAllElements(event, ...)
	end
end

local UpdatePet = function(self, event, unit)
	local petUnit
	if (unit == "target") then
		return
	elseif (unit == "player") then
		petUnit = "pet"
	else
		petUnit = unit.."pet"
	end
	if (not self:OnAttributeChanged("unit", UnitHasVehicleUI(unit) and petUnit or unit)) then
		return self:UpdateAllElements(event, "Forced", self.unit)
	end
end

-- Library API
--------------------------------------------------------------------------
-- Return or create the library default tooltip
LibUnitFrame.GetUnitFrameTooltip = function(self)
	return LibUnitFrame:GetTooltip("GP_UnitFrameTooltip") or LibUnitFrame:CreateTooltip("GP_UnitFrameTooltip")
end

LibUnitFrame.SetScript = function(self, scriptHandler, script)
	scriptHandlers[scriptHandler] = script
	if (scriptHandler == "OnUpdate") then
		if (not scriptFrame) then
			scriptFrame = CreateFrame("Frame", nil, LibFrame:GetFrame())
		end
		if script then
			scriptFrame:SetScript("OnUpdate", function(self, ...)
				script(LibUnitFrame, ...)
			end)
		else
			scriptFrame:SetScript("OnUpdate", nil)
		end
	end
end

LibUnitFrame.GetScript = function(self, scriptHandler)
	return scriptHandlers[scriptHandler]
end

LibUnitFrame.GetUnitFrameVisibilityDriver = function(self, unit, hideInVehicles)
	local visDriver
	if (unit == "player") then
		if (IsClassic or IsTBC) then
			visDriver = "[@player,exists][mounted]show;hide"
		elseif (IsWrath) then
			-- UNTESTED!
			if (hideInVehicles) then
				visDriver = "[vehicleui]hide;[@player,exists][possessbar][overridebar][mounted]show;hide"
			else
				visDriver = "[@player,exists][vehicleui][possessbar][overridebar][mounted]show;hide"
			end
		elseif (IsRetail) then
			-- Might seem stupid, but I want the player frame to disappear along with the actionbars
			-- when we've blown the flight master's whistle and are getting picked up.
			if (hideInVehicles) then
				visDriver = "[vehicleui]hide;[@player,exists][possessbar][overridebar][mounted]show;hide"
			else
				visDriver = "[@player,exists][vehicleui][possessbar][overridebar][mounted]show;hide"
			end
		end
	elseif (unit == "pet") then
		if (IsWrath) then
			-- UNTESTED!
			local prefix = "[@player,noexists]hide;"
			if (hideInVehicles) then
				visDriver = prefix .. "[vehicleui]hide;[@pet,exists]show;hide"
			else
				visDriver = prefix .. "[@pet,exists][nooverridebar,vehicleui]show;hide"
			end
		elseif (IsRetail) then
			-- Adding this to avoid situations where the player frame is hidden,
			-- yet a pet frame hovers in mid-air.
			-- This only happens in short periods, like when a quest requires you to
			-- take a flight on a dragon to fly to or return to someplace.
			-- Still, looks silly. We want it fixed.
			local prefix = "[@player,noexists]hide;"
			if (hideInVehicles) then
				visDriver = prefix .. "[vehicleui]hide;[@pet,exists]show;hide"
			else
				visDriver = prefix .. "[@pet,exists][nooverridebar,vehicleui]show;hide"
			end
		end
	else
		local partyID = string_match(unit, "^party(%d+)")
		if (partyID) then
			if (hideInVehicles) then
				visDriver = string_format("[vehicleui]hide;[nogroup:raid,@%s,exists]show;hide", unit)
			else
				visDriver = string_format("[nogroup:raid,@%s,exists]show;hide", unit)
			end
		end
	end
	if (visDriver) then
		return visDriver
	else
		if (hideInVehicles) then
			return string_format("[vehicleui]hide;[@%s,exists]show;hide", unit)
		else
			return string_format("[@%s,exists]show;hide", unit)
		end
	end
end

LibUnitFrame.GetUnitFrameUnitDriver = function(self, unit)
	local unitDriver
	if (IsWrath) then
		-- UNTESTED!
		if (unit == "player") then
			unitDriver = "[nooverridebar,vehicleui]pet;[overridebar,@vehicle,exists]vehicle;player"
		elseif (unit == "pet") then
			unitDriver = "[nooverridebar,vehicleui]player;pet"
		elseif (string_match(unit, "^party(%d+)")) then
			unitDriver = string_format("[unithasvehicleui,@%s]%s;%s", unit, unit.."pet", unit)
		elseif (string_match(unit, "^raid(%d+)")) then
			unitDriver = string_format("[unithasvehicleui,@%s]%s;%s", unit, unit.."pet", unit)
		end
	elseif (IsRetail) then
		if (unit == "player") then
			-- Should work in all cases where the unitframe is replaced. It should always be the "pet" unit.
			--unitDriver = "[vehicleui]pet;player"
			unitDriver = "[nooverridebar,vehicleui]pet;[overridebar,@vehicle,exists]vehicle;player"
		elseif (unit == "pet") then
			unitDriver = "[nooverridebar,vehicleui]player;pet"
		elseif (string_match(unit, "^party(%d+)")) then
			unitDriver = string_format("[unithasvehicleui,@%s]%s;%s", unit, unit.."pet", unit)
		elseif (string_match(unit, "^raid(%d+)")) then
			unitDriver = string_format("[unithasvehicleui,@%s]%s;%s", unit, unit.."pet", unit)
		end
	end
	return unitDriver
end

-- spawn and style a new unitframe
LibUnitFrame.SpawnUnitFrame = function(self, unit, parent, styleFunc, ...)
	check(unit, 1, "string")
	check(parent, 2, "table", "string", "nil")
	check(styleFunc, 3, "function", "string", "nil")

	-- Alllow modules to use methods as styling functions.
	-- We don't want to allow this in the widgetcontainer back-end,
	-- so we need a bit of trickery here to make it happen.
	if (type(styleFunc) == "string") then
		local func = self[styleFunc]
		if func then
			local module, method = self, styleFunc
			styleFunc = function(...)
				-- Always call the method by name,
				-- don't assume the function is the same each time.
				-- Even though it is. So this is weird.
				return module[method](self, ...)
			end
		end
	end

	local frame = LibUnitFrame:CreateWidgetContainer("Button", parent, "SecureUnitButtonTemplate", unit, styleFunc, ...)
	for method,func in pairs(UnitFrame) do
		frame[method] = func
	end

	frame.requireUnit = true
	frame.colors = frame.colors or Colors
	frame.ignoredEvents = {}

	if (frame.ignoreMouseOver) then
		frame:EnableMouse(false)
		if (IsDragonflight) then
			frame:RegisterForClicks()
		else
			frame:RegisterForClicks("")
		end
	else
		frame:SetAttribute("*type1", "target")
		frame:SetAttribute("*type2", "togglemenu")
		frame:SetScript("OnEnter", UnitFrame.OnEnter)
		frame:SetScript("OnLeave", UnitFrame.OnLeave)
		frame:RegisterForClicks("AnyUp")
	end

	frame:SetScript("OnHide", UnitFrame.OnHide)

	local OverrideAllElements = UnitFrame.OverrideAllElementsOnChangedGUID -- UnitFrame.OverrideAllElements

	if (unit == "target") then
		frame:RegisterEvent("PLAYER_TARGET_CHANGED", OverrideAllElements, true)
		frame.ignoredEvents["PLAYER_TARGET_CHANGED"] = true

	elseif (unit == "focus") then
		if (IsRetail or IsTBC) then
			frame:RegisterEvent("PLAYER_FOCUS_CHANGED", OverrideAllElements, true)
			frame.ignoredEvents["PLAYER_FOCUS_CHANGED"] = true
		end

	elseif (unit == "mouseover") then
		frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT", OverrideAllElements, true)
		frame.ignoredEvents["UPDATE_MOUSEOVER_UNIT"] = true

	elseif (unit:match("^arena(%d+)")) then
		frame.unitGroup = "arena"
		frame:SetFrameStrata("MEDIUM")
		frame:SetFrameLevel(1000)
		frame:RegisterEvent("ARENA_OPPONENT_UPDATE", OverrideAllElements, true)
		frame.ignoredEvents["ARENA_OPPONENT_UPDATE"] = true

	elseif (string_match(unit, "^boss(%d+)")) then
		frame.unitGroup = "boss"
		frame:SetFrameStrata("MEDIUM")
		frame:SetFrameLevel(1000)

		frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", OverrideAllElements, true)
		frame.ignoredEvents["INSTANCE_ENCOUNTER_ENGAGE_UNIT"] = true

		frame:RegisterEvent("UNIT_TARGETABLE_CHANGED", OverrideAllElements, true)
		frame.ignoredEvents["UNIT_TARGETABLE_CHANGED"] = true

	elseif (string_match(unit, "^party(%d+)")) then
		frame.unitGroup = "party"
		frame:RegisterEvent("GROUP_ROSTER_UPDATE", OverrideAllElements, true)
		frame.ignoredEvents["GROUP_ROSTER_UPDATE"] = true

		if (IsRetail) then
			frame:RegisterEvent("UNIT_PET", UpdatePet)
		end

	elseif (string_match(unit, "^raid(%d+)")) then
		frame.unitGroup = "raid"
		frame:RegisterEvent("GROUP_ROSTER_UPDATE", UnitFrame.OverrideAllElementsOnChangedGUID, true)
		frame.ignoredEvents["GROUP_ROSTER_UPDATE"] = true

		if (IsRetail) then
			frame:RegisterEvent("UNIT_PET", UpdatePet)
		end

	elseif (unit == "targettarget") then
		-- Need an extra override event here so the ToT frame won't appear to lag behind on target changes.
		frame:RegisterEvent("PLAYER_TARGET_CHANGED", OverrideAllElements, true)
		frame.ignoredEvents["PLAYER_TARGET_CHANGED"] = true
		frame:EnableFrameFrequent(.5, "unit")

	elseif (string_match(unit, "%w+target")) then
		frame:EnableFrameFrequent(.5, "unit")
	end

	frame:SetAttribute("unit", unit)

	local unitDriver = frame.unitOverrideDriver or LibUnitFrame:GetUnitFrameUnitDriver(unit)
	if (unitDriver) and (not frame.hideInVehicles) then
		local unitSwitcher = CreateFrame("Frame", nil, nil, "SecureHandlerAttributeTemplate")
		unitSwitcher:SetFrameRef("UnitFrame", frame)
		unitSwitcher:SetAttribute("unit", unit)
		unitSwitcher:SetAttribute("_onattributechanged", [=[
			local frame = self:GetFrameRef("UnitFrame");
			frame:SetAttribute("unit", value);
		]=])
		frame.realUnit = unit
		frame:SetAttribute("unit", SecureCmdOptionParse(unitDriver))
		RegisterAttributeDriver(unitSwitcher, "state-vehicleswitch", unitDriver)
	else
		frame:SetAttribute("unit", unit)
	end

	local visDriver = LibUnitFrame:GetUnitFrameVisibilityDriver(unit, frame.hideInVehicles)
	if (frame.visibilityOverrideDriver) then
		visDriver = frame.visibilityOverrideDriver
	elseif (frame.visibilityPreDriver) then
		visDriver = frame.visibilityPreDriver .. visDriver
	end

	frame:SetAttribute("visibilityDriver", visDriver)
	RegisterAttributeDriver(frame, "state-visibility", visDriver)

	-- This and a global name is pretty much
	-- the shortest route to Clique compatibility.
	_G.ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[frame] = true

	frames[frame] = true

	if (frame.PostCreate) then
		frame:PostCreate()
	end

	return frame
end

-- Make this a proxy for development purposes
LibUnitFrame.RegisterElement = function(self, ...)
	LibWidgetContainer:RegisterElement(...)
end

-- Module embedding
local embedMethods = {
	SpawnUnitFrame = true,
	GetUnitFrameVisibilityDriver = true,
	GetUnitFrameTooltip = true
}

LibUnitFrame.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibUnitFrame.embeds) do
	LibUnitFrame:Embed(target)
end

-- Upgrade existing frame script handlers, if any
for frame in pairs(frames) do
	for _,handler in ipairs({ "OnEnter", "OnLeave", "Hide" }) do
		local method = frame[handler]
		local script = frame:GetScript(handler)
		if (method and script) and (method == script) then
			frame[handler] = UnitFrame[method]
			frame:SetScript(handler, UnitFrame[method])
		end
	end
end
