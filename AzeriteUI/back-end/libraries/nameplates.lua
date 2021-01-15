local LibNamePlate = Wheel:Set("LibNamePlate", 65)
if (not LibNamePlate) then	
	return
end

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibNamePlate requires LibMessage to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibNamePlate requires LibEvent to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibCast requires LibClientBuild to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibNamePlate requires LibFrame to be loaded.")

local LibSecureHook = Wheel("LibSecureHook")
assert(LibSecureHook, "LibNamePlate requires LibSecureHook to be loaded.")

local LibStatusBar = Wheel("LibStatusBar")
assert(LibStatusBar, "LibNamePlate requires LibStatusBar to be loaded.")

-- Embed event functionality into this
LibMessage:Embed(LibNamePlate)
LibEvent:Embed(LibNamePlate)
LibFrame:Embed(LibNamePlate)
LibSecureHook:Embed(LibNamePlate)
LibStatusBar:Embed(LibNamePlate)

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local ipairs = ipairs
local math_ceil = math.ceil
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
local table_wipe = table.wipe
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack

-- WoW API
local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsAddOnLoaded = IsAddOnLoaded
local IsLoggedIn = IsLoggedIn
local SetCVar = SetCVar
local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitClassification = UnitClassification
local UnitExists = UnitExists
local UnitIsFriend = UnitIsFriend
local UnitIsPlayer = UnitIsPlayer
local UnitIsTrivial = UnitIsTrivial
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitReaction = UnitReaction

-- WoW Frames & Objects
local WorldFrame = WorldFrame

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Plate Registries
LibNamePlate.allPlates = LibNamePlate.allPlates or {}
LibNamePlate.visiblePlates = LibNamePlate.visiblePlates or {}
LibNamePlate.castData = LibNamePlate.castData or {}
LibNamePlate.metaData = LibNamePlate.metaData or {}
LibNamePlate.alphaLevels = nil -- remove deprecated library data

LibNamePlate.elements = LibNamePlate.elements or {} -- global element registry
LibNamePlate.callbacks = LibNamePlate.callbacks or {} -- global frame and element callback registry
LibNamePlate.unitEvents = LibNamePlate.unitEvents or {} -- global frame unitevent registry
LibNamePlate.frequentUpdates = LibNamePlate.frequentUpdates or {} -- global element frequent update registry
LibNamePlate.frequentUpdateFrames = LibNamePlate.frequentUpdateFrames or {} -- global frame frequent update registry
LibNamePlate.frameElements = LibNamePlate.frameElements or {} -- per unitframe element registry
LibNamePlate.frameElementsEnabled = LibNamePlate.frameElementsEnabled or {} -- per unitframe element enabled registry
LibNamePlate.frameElementsDisabled = LibNamePlate.frameElementsDisabled or {} -- per unitframe element manually disabled registry
LibNamePlate.scriptHandlers = LibNamePlate.scriptHandlers or {} -- tracked library script handlers
LibNamePlate.scriptFrame = LibNamePlate.scriptFrame -- library script frame, will be created on demand later on

-- Modules that embed this
LibNamePlate.embeds = LibNamePlate.embeds or {}

-- We parent our update frame to the WorldFrame, 
-- as we need it to run even if the user has hidden the UI.
LibNamePlate.frame = LibNamePlate.frame or CreateFrame("Frame", nil, WorldFrame)

-- When parented to the WorldFrame, setting the strata to TOOLTIP 
-- will cause its updates to run close to last in the update cycle. 
LibNamePlate.frame:SetFrameStrata("TOOLTIP") 

-- internal switch to track enabled state
-- Looks weird. But I want it referenced up here.
LibNamePlate.isEnabled = LibNamePlate.isEnabled or false 

-- This will be updated later on by the library,
-- we just need a value of some sort here as a fallback.
LibNamePlate.SCALE = LibNamePlate.SCALE or 768/1080

-- Frame to securely hide items
if (not LibNamePlate.uiHider) then
	local uiHider = CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
	uiHider:Hide()
	uiHider:SetPoint("TOPLEFT", 0, 0)
	uiHider:SetPoint("BOTTOMRIGHT", 0, 0)
	RegisterAttributeDriver(uiHider, "state-visibility", "hide")

	-- Attach it to our library
	LibNamePlate.uiHider = uiHider
end

-- Set metadata fallbacks before updates begin
LibNamePlate.metaData.visiblePlates = 0
LibNamePlate.metaData.visiblePlatesHostile = 0
LibNamePlate.metaData.visiblePlatesFriendly = 0
LibNamePlate.metaData.visiblePlatesHighAlpha = 0

-- Speed shortcuts
local allPlates = LibNamePlate.allPlates
local visiblePlates = LibNamePlate.visiblePlates
local metaData = LibNamePlate.metaData

local elements = LibNamePlate.elements
local callbacks = LibNamePlate.callbacks
local unitEvents = LibNamePlate.unitEvents
local frequentUpdates = LibNamePlate.frequentUpdates
local frequentUpdateFrames = LibNamePlate.frequentUpdateFrames
local frameElements = LibNamePlate.frameElements
local frameElementsEnabled = LibNamePlate.frameElementsEnabled
local frameElementsDisabled = LibNamePlate.frameElementsDisabled
local scriptHandlers = LibNamePlate.scriptHandlers
local scriptFrame = LibNamePlate.scriptFrame
local uiHider = LibNamePlate.uiHider

-- This will be true if forced updates are needed on all plates
-- All plates will be updated in the next frame cycle 
local FORCEUPDATE = false

-- Frame level constants and counters
local FRAMELEVEL_TARGET = 126
local FRAMELEVEL_IMPORTANT = 124 -- rares, bosses, etc
local FRAMELEVEL_CURRENT, FRAMELEVEL_MIN, FRAMELEVEL_MAX, FRAMELEVEL_STEP = 21, 21, 125, 2
local FRAMELEVEL_TRIVAL_CURRENT, FRAMELEVEL_TRIVIAL_MIN, FRAMELEVEL_TRIVIAL_MAX, FRAMELEVEL_TRIVIAL_STEP = 1, 1, 20, 2

-- Flag tracking combat state
local IN_COMBAT = false

-- Flag tracking target existence
local HAS_TARGET = false

-- Update and fading frequencies
local THROTTLE = 1/30 -- global update limit, no elements can go above this
local FADE_IN = .75 -- time in seconds to fade in
local FADE_OUT = .05 -- time in seconds to fade out
local FADE_DOWN = .25 -- time in seconds to fade down, but not out

-- Opacity Settings
-- *From library build 25 we're keeping these local
local ALPHA_FULL_INDEX = 1
local ALPHA_HIGH_INDEX = 2
local ALPHA_MEDIUM_INDEX = 3
local ALPHA_LOW_INDEX = 4
local ALPHA_NONE_INDEX = 5

local ALPHA = {
	[ALPHA_FULL_INDEX] = 1,
	[ALPHA_HIGH_INDEX] = .85,
	[ALPHA_MEDIUM_INDEX] = .75,
	[ALPHA_LOW_INDEX] = .25,
	[ALPHA_NONE_INDEX] = 0
}

-- New from build 29
local ENFORCED_CVARS = {
	nameplateMaxAlpha = 1, -- .9
	nameplateMinAlpha = .4, -- .6
	nameplateOccludedAlphaMult = .15, -- .4
	nameplateSelectedAlpha = 1, -- 1
	nameplateMaxAlphaDistance = IsClassic and 20 or IsRetail and 30, -- 40
	nameplateMinAlphaDistance = 10 -- 10
}

-- Color Table Utility
local hex = function(r, g, b)
	return ("|cff%02x%02x%02x"):format(math_floor(r*255), math_floor(g*255), math_floor(b*255))
end
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

-- Color Table
local Colors = {

	normal = prepare(229/255, 178/255, 38/255),
	highlight = prepare(250/255, 250/255, 250/255),
	title = prepare(255/255, 234/255, 137/255),

	dead = prepare(73/255, 25/255, 9/255),
	disconnected = prepare(120/255, 120/255, 120/255),
	tapped = prepare(161/255, 141/255, 120/255),

	class = {
		DEATHKNIGHT 		= prepare( 176/255,  31/255,  79/255 ),
		DEMONHUNTER 		= prepare( 163/255,  48/255, 201/255 ),
		DRUID 				= prepare( 255/255, 125/255,  10/255 ),
		HUNTER 				= prepare( 191/255, 232/255, 115/255 ), 
		MAGE 				= prepare( 105/255, 204/255, 240/255 ),
		MONK 				= prepare(   0/255, 255/255, 150/255 ),
		PALADIN 			= prepare( 225/255, 160/255, 226/255 ),
		PRIEST 				= prepare( 176/255, 200/255, 225/255 ),
		ROGUE 				= prepare( 255/255, 225/255,  95/255 ), 
		SHAMAN 				= prepare(  32/255, 122/255, 222/255 ), 
		WARLOCK 			= prepare( 148/255, 130/255, 201/255 ), 
		WARRIOR 			= prepare( 229/255, 156/255, 110/255 ), 
		UNKNOWN 			= prepare( 195/255, 202/255, 217/255 ),
	},
	debuff = {
		none 			= prepare( 204/255,   0/255,   0/255 ),
		Magic 			= prepare(  51/255, 153/255, 255/255 ),
		Curse 			= prepare( 204/255,   0/255, 255/255 ),
		Disease 		= prepare( 153/255, 102/255,   0/255 ),
		Poison 			= prepare(   0/255, 153/255,   0/255 ),
		[""] 			= prepare(   0/255,   0/255,   0/255 )
	},
	quest = {
		red = prepare(204/255, 26/255, 26/255),
		orange = prepare(255/255, 128/255, 64/255),
		yellow = prepare(229/255, 178/255, 38/255),
		green = prepare(89/255, 201/255, 89/255),
		gray = prepare(120/255, 120/255, 120/255)
	},
	reaction = {
		[1] 			= prepare( 205/255,  46/255,  36/255 ), -- hated
		[2] 			= prepare( 205/255,  46/255,  36/255 ), -- hostile
		[3] 			= prepare( 192/255,  68/255,   0/255 ), -- unfriendly
		[4] 			= prepare( 249/255, 158/255,  35/255 ), -- neutral 
		[5] 			= prepare(  64/255, 131/255,  38/255 ), -- friendly
		[6] 			= prepare(  64/255, 131/255,  69/255 ), -- honored
		[7] 			= prepare(  64/255, 131/255, 104/255 ), -- revered
		[8] 			= prepare(  64/255, 131/255, 131/255 ), -- exalted
		civilian 		= prepare(  64/255, 131/255,  38/255 )  -- used for friendly player nameplates
	}
}

-- Utility Functions
----------------------------------------------------------
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

--Return rounded number
local round = function(num, power)
	if (power and power > 0) then
		local mult = 10 ^ power
		local val = num * mult + .5
		return (val - val%1) / mult
	end
	local val = num + .5
	return val - val%1
end

-- NamePlate Template
----------------------------------------------------------
local NamePlate = LibNamePlate:CreateFrame("Frame")
local NamePlate_MT = { __index = NamePlate }

-- Methods we don't wish to expose to the modules
--------------------------------------------------------------------------
local IsEventRegistered = NamePlate_MT.__index.IsEventRegistered
local RegisterEvent = NamePlate_MT.__index.RegisterEvent
local RegisterUnitEvent = NamePlate_MT.__index.RegisterUnitEvent
local UnregisterEvent = NamePlate_MT.__index.UnregisterEvent
local UnregisterAllEvents = NamePlate_MT.__index.UnregisterAllEvents

local IsMessageRegistered = LibNamePlate.IsMessageRegistered
local RegisterMessage = LibNamePlate.RegisterMessage
local SendMessage = LibNamePlate.SendMessage
local UnregisterMessage = LibNamePlate.UnregisterMessage

-- TODO: Cache some of this upon unit changes and show, to avoid so many function calls. 
NamePlate.UpdateAlpha = function(self)
	local unit = self.unit
	if (not UnitExists(unit)) then
		return 
	end
	local alphaLevel = ALPHA_NONE_INDEX
	if visiblePlates[self] then
		if (self.OverrideAlpha) then 
			return self:OverrideAlpha(unit)
		end 
		
		local alphaReduction

		if (self.isTarget or self.isYou) then
			alphaLevel = ALPHA_FULL_INDEX
		else
			-- When you have a target, all else will be lowered by blizzard.
			if HAS_TARGET then

				-- Players
				if (self.isPlayer) then

					-- Enemy Players
					if (self.isEnemy) then
						alphaLevel = ALPHA_HIGH_INDEX

					-- Friendly Players
				elseif (self.isFriend) then
						alphaLevel = ALPHA_HIGH_INDEX
						alphaReduction = true
					end
				else

					-- Important NPCs
					if (self.isElite or self.isRare or self.isBoss) then
						if (self.isFriend) then 
							alphaLevel = ALPHA_FULL_INDEX
							alphaReduction = true
						else
							alphaLevel = ALPHA_FULL_INDEX
						end

					-- Enemy NPCs
					elseif (self.isEnemy) then
						alphaLevel = ALPHA_HIGH_INDEX

					-- Friendly NPCs
					elseif (self.isFriend) then
						alphaLevel = ALPHA_LOW_INDEX

					-- Trivial NPCs (do the even exist in Classic?)
					elseif (self.isTrivial) then 
						alphaLevel = ALPHA_LOW_INDEX
					else
						-- Those that fall inbetween. Neutral NPCs?
						alphaLevel = ALPHA_MEDIUM_INDEX
					end
				end

			else

				-- Players
				if (self.isPlayer) then

					-- Enemy Players
					if (self.isEnemy) then
						alphaLevel = ALPHA_MEDIUM_INDEX

					-- Friendly Players
					elseif (self.isFriend) then
						alphaLevel = ALPHA_MEDIUM_INDEX
						alphaReduction = true
					end
				else

					-- Important NPCs
					if (self.isElite or self.isRare or self.isBoss) then
						if (self.isFriend) then 
							alphaLevel = ALPHA_HIGH_INDEX
							alphaReduction = true
						else
							alphaLevel = ALPHA_HIGH_INDEX
						end

					-- Enemy NPCs
					elseif (self.isEnemy) then
						alphaLevel = ALPHA_MEDIUM_INDEX

					-- Friendly NPCs
					elseif (self.isFriend) then
						alphaLevel = ALPHA_LOW_INDEX

					-- Trivial NPCs (do the even exist in Classic?)
					elseif (self.isTrivial) then 
						alphaLevel = ALPHA_LOW_INDEX
					else
						-- Those that fall inbetween. Neutral NPCs?
						alphaLevel = ALPHA_MEDIUM_INDEX
					end
				end
			end
		end
	end

	-- Multiply with the blizzard alpha, to piggyback on their line of sight occluded alpha
	--self.targetAlpha = self.baseFrame:GetAlpha() * ALPHA.NoCombat[alphaLevel]
	self.targetAlpha = self.baseFrame:GetAlpha() * ALPHA[alphaLevel]

	if (alphaReduction) then
		self.targetAlpha = self.targetAlpha * (not IN_COMBAT) and .5 or 1
	end

	if (self.PostUpdateAlpha) then 
		self:PostUpdateAlpha(unit, self.targetAlpha, alphaLevel)
	end 
end

NamePlate.UpdateFrameLevel = function(self)
	local unit = self.unit
	if (not UnitExists(unit)) then
		return
	end
	if visiblePlates[self] then
		if (self.OverrideFrameLevel) then 
			return self:OverrideFrameLevel(unit)
		end 
		if self.isTarget then
			-- We're placing targets at an elevated frame level, 
			-- as we want that frame visible above everything else. 
			if self:GetFrameLevel() ~= FRAMELEVEL_TARGET then
				self:SetFrameLevel(FRAMELEVEL_TARGET)
			end
		elseif self.isRare or self.isElite or self.isBoss then 
			-- We're also elevating rares and bosses to almost the same level as our target, 
			-- as we want these frames to stand out above all the others to make Legion rares easier to see.
			-- Note that this doesn't actually make it easier to click, as we can't raise the secure uniframe itself, 
			-- so it only affects the visible part created by us. 
			if (self:GetFrameLevel() ~= FRAMELEVEL_IMPORTANT) then
				self:SetFrameLevel(FRAMELEVEL_IMPORTANT)
			end
		else
			-- If the current nameplate isn't a rare, boss or our target, 
			-- we return it to its original framelevel, if the framelevel has been changed.
			if (self:GetFrameLevel() ~= self.frameLevel) then
				self:SetFrameLevel(self.frameLevel)
			end
		end
		if (self.PostUpdateFrameLevel) then 
			self:PostUpdateFrameLevel(unit, self.isTarget, self.isRare or self.isElite or self.isBoss)
		end 
	end
end

-- Doesn't appear to be called anymore?
NamePlate.UpdateScale = function(self)
	local scale = LibNamePlate.SCALE * self.baseFrame:GetScale()
	--print("Setting scale of "..self:GetName().." to ".. scale)
	self:SetScale(scale)
end

NamePlate.GetBaseFrame = function(self)
	return self.baseFrame
end

NamePlate.OnShow = function(self, event, unit)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end

	self:SetAlpha(0) -- set the actual alpha to 0
	self.currentAlpha = 0 -- update stored alpha value
	self.achievedAlpha = 0 -- set this as the achieved alpha

	self.isVisible = true
	self.inCombat = IN_COMBAT
	self.isYou = UnitIsUnit(unit, "player")
	self.isTarget = UnitIsUnit(unit, "target") -- gotta update this on target changes... 
	self.isPlayer = UnitIsPlayer(unit)
	self.isEnemy = UnitIsEnemy(unit, "player")
	self.isFriend = UnitIsFriend("player", unit)
	self.isTrivial = UnitIsTrivial(unit)
	self.isBoss = (self.unitClassificiation == "worldboss") or (self.unitLevel and self.unitLevel < 1)
	self.isRare = (self.unitClassificiation == "rare") or (self.unitClassificiation == "rareelite")
	self.isElite = (self.unitClassificiation == "elite") or (self.unitClassificiation == "rareelite")
	self.unitLevel = UnitLevel(unit)
	self.unitClassificiation = UnitClassification(unit)
	self.unitCanAttack = UnitCanAttack("player", unit)

	if (self.isEnemy) then
		self.metaData.visiblePlatesHostile = self.metaData.visiblePlatesHostile + 1
	elseif (self.isFriend) then
		self.metaData.visiblePlatesFriendly = self.metaData.visiblePlatesFriendly + 1
	end
	self.metaData.visiblePlates = self.metaData.visiblePlates + 1

	-- Enabling of situational elements should be done here.
	-- Flags are available to the front-end at this point.
	if (self.PreUpdate) then 
		self:PreUpdate("OnShow", unit)
	end 
	self:KillBlizzard()
	self:UpdateScale() -- might be needed in 9.0.1
	self:Show() -- make the fully transparent frame visible

	-- this will trigger the fadein 
	visiblePlates[self] = self.baseFrame 

	-- must be called after the plate has been added to visiblePlates
	self:UpdateFrameLevel() 

	for element in pairs(elements) do
		if (not (frameElementsDisabled[self] and frameElementsDisabled[self][element])) then 
			self:EnableElement(element)
		end 
	end
	self:UpdateAllElements()

	if (self.PostUpdate) then 
		self:PostUpdate("OnShow", unit)
	end 
end

NamePlate.OnHide = function(self, event, unit)
	visiblePlates[self] = false -- this will trigger the fadeout and hiding

	if (self.isEnemy) then
		self.metaData.visiblePlatesHostile = self.metaData.visiblePlatesHostile - 1
	elseif (self.isFriend) then
		self.metaData.visiblePlatesFriendly = self.metaData.visiblePlatesFriendly - 1
	end
	self.metaData.visiblePlates = self.metaData.visiblePlates - 1

	self.isVisible = nil
	self.isYou = nil
	self.isTarget = nil
	self.isPlayer = nil
	self.isFriend = nil
	self.isEnemy = nil
	self.isTrivial = nil
	self.isBoss = nil
	self.isRare = nil
	self.isElite = nil
	self.inCombat = nil
	self.unitLevel = nil
	self.unitClassificiation = nil

	for element in pairs(elements) do
		self:DisableElement(element, true)
	end
end

NamePlate.OnEnter = function(self)
	self.isMouseOver = true
	if (self.PostUpdate) then 
		self:PostUpdate("OnEnter", self.unit)
	end 
end

NamePlate.OnLeave = function(self)
	self.isMouseOver = false
	if (self.PostUpdate) then 
		self:PostUpdate("OnLeave", self.unit)
	end 
end

NamePlate.OnEvent = function(frame, event, ...)
	if (frame:IsVisible() and callbacks[frame] and callbacks[frame][event]) then 
		local events = callbacks[frame][event]
		local isUnitEvent = unitEvents[event]
		for i = 1, #events do
			if isUnitEvent then 
				events[i](frame, event, ...)
			else 
				events[i](frame, event, frame.unit, ...)
			end 
		end
	end 
end

NamePlate.RegisterEvent = function(self, event, func, unitless)
	if (frequentUpdateFrames[self] and event ~= "UNIT_PORTRAIT_UPDATE" and event ~= "UNIT_MODEL_CHANGED") then 
		return 
	end
	if (not callbacks[self]) then
		callbacks[self] = {}
	end
	if (not callbacks[self][event]) then
		callbacks[self][event] = {}
	end
	
	local events = callbacks[self][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not IsEventRegistered(self, event)) then
		if unitless then 
			RegisterEvent(self, event)
		else 
			unitEvents[event] = true
			RegisterUnitEvent(self, event)
		end 
	end
end

NamePlate.UnregisterEvent = function(self, event, func)
	-- silently fail if the event isn't even registered
	if not callbacks[self] or not callbacks[self][event] then
		return
	end

	local events = callbacks[self][event]

	if #events > 0 then
		-- find the function's id 
		for i = #events, 1, -1 do
			if events[i] == func then
				table_remove(events, i)
				--events[i] = nil -- remove the function from the event's registry
				if #events == 0 then
					UnregisterEvent(self, event) 
				end
			end
		end
	end
end

NamePlate.UnregisterAllEvents = function(self)
	if not callbacks[self] then 
		return
	end
	for event, funcs in pairs(callbacks[self]) do
		for i = #funcs, 1, -1 do
			table_remove(funcs, i)
			--funcs[i] = nil
		end
	end
	UnregisterAllEvents(self)
end

NamePlate.RegisterMessage = function(self, event, func, unitless)
	if (frequentUpdateFrames[self]) then 
		return 
	end
	if (not callbacks[self]) then
		callbacks[self] = {}
	end
	if (not callbacks[self][event]) then
		callbacks[self][event] = {}
	end
	
	local events = callbacks[self][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not IsMessageRegistered(self, event, NamePlate.OnEvent)) then
		RegisterMessage(self, event, NamePlate.OnEvent)
		if (not unitless) then 
			unitEvents[event] = true
		end 
	end
end

NamePlate.SendMessage = SendMessage -- Don't need a proxy on this one

NamePlate.UnregisterMessage = function(self, event, func)
	-- silently fail if the event isn't even registered
	if not callbacks[self] or not callbacks[self][event] then
		return
	end

	local events = callbacks[self][event]

	if #events > 0 then
		for i = #events, 1, -1 do
			if events[i] == func then
				table_remove(events, i)
			end
		end
		if (#events == 0) then
			if (IsMessageRegistered(self, event, NamePlate.OnEvent)) then 
				UnregisterMessage(self, event, NamePlate.OnEvent) 
			end
		end
	end
end

NamePlate.UpdateAllElements = function(self, event, ...)
	local unit = self.unit
	if (not UnitExists(unit)) then 
		return 
	end
	if (self.PreUpdate) then
		self:PreUpdate(event, unit, ...)
	end
	if (frameElements[self]) then
		for element in pairs(frameElementsEnabled[self]) do
			-- Will run the registered Update function for the element, 
			-- which isually is the "Proxy" method in my elements. 
			-- We cannot direcly access the ForceUpdate method, 
			-- as that is meant for in-module updates to that unique
			-- instance of the element, and doesn't exist on the template element itself. 
			elements[element].Update(self, "Forced", self.unit)
		end
	end
	if (self.PostUpdate) then
		self:PostUpdate(event, unit, ...)
	end
end

NamePlate.DisableAllElements = function(self, event, ...)
	if (not UnitExists(unit)) then 
		return 
	end
	if (self.PreUpdate) then
		self:PreUpdate(event, unit, ...)
	end
	if (frameElements[self]) then
		for element in pairs(frameElementsEnabled[self]) do
			-- Will run the registered Update function for the element, 
			-- which isually is the "Proxy" method in my elements. 
			-- We cannot direcly access the ForceUpdate method, 
			-- as that is meant for in-module updates to that unique
			-- instance of the element, and doesn't exist on the template element itself. 
			elements[element].Update(self, "Forced", self.unit)
		end
	end
	if (self.PostUpdate) then
		self:PostUpdate(event, unit, ...)
	end
end

NamePlate.EnableElement = function(self, element)
	if (not frameElements[self]) then
		frameElements[self] = {}
		frameElementsEnabled[self] = {}
	end

	-- don't double enable
	if frameElementsEnabled[self][element] then 
		return 
	end 

	-- removed manually disabled entry
	if (frameElementsDisabled[self] and frameElementsDisabled[self][element]) then 
		frameElementsDisabled[self][element] = nil
	end 

	-- upvalues ftw
	local frameElements = frameElements[self]
	local frameElementsEnabled = frameElementsEnabled[self]
	
	-- avoid duplicates
	local found
	for i = 1, #frameElements do
		if (frameElements[i] == element) then
			found = true
			break
		end
	end
	if (not found) then
		-- insert the element into the list
		table_insert(frameElements, element)
	end

	-- attempt to enable the element
	if elements[element].Enable(self, self.unit) then
		-- success!
		frameElementsEnabled[element] = true
	end
end

NamePlate.DisableElement = function(self, element, softDisable)
	if (not frameElementsDisabled[self]) then 
		frameElementsDisabled[self] = {}
	end 

	-- mark this as manually disabled
	if (not softDisable) then 
		frameElementsDisabled[self][element] = true
	end

	-- silently fail if the element hasn't been enabled for the frame
	if ((not frameElementsEnabled[self]) or (not frameElementsEnabled[self][element])) then
		return
	end

	-- run the disable script
	elements[element].Disable(self, self.unit)

	-- remove the element from the enabled registries
	for i = #frameElements[self], 1, -1 do
		if (frameElements[self][i] == element) then
			table_remove(frameElements[self], i)
		end
	end

	-- remove the enabled status
	frameElementsEnabled[self][element] = nil
	
	-- remove the element's frequent update entry
	if (frequentUpdates[self] and frequentUpdates[self][element]) then
		frequentUpdates[self][element].elapsed = nil
		frequentUpdates[self][element].hz = nil
		frequentUpdates[self][element] = nil
		
		-- Remove the frame object's frequent update entry
		-- if no elements require it anymore.
		local count = 0
		for i,v in pairs(frequentUpdates[self]) do
			count = count + 1
		end
		if (count == 0) then
			frequentUpdates[self] = nil
		end
	end
end

NamePlate.IsElementEnabled = function(self, element)
	-- Keep returns consistently true/false
	return (frameElementsEnabled[self] and frameElementsEnabled[self][element]) and true or false 
end

NamePlate.EnableFrequentUpdates = function(self, element, frequency)
	if (not frequentUpdates[self]) then
		frequentUpdates[self] = {}
	end
	frequentUpdates[self][element] = { elapsed = 0, hz = tonumber(frequency) or .5 }
end

-- This is where a name plate is first created, 
-- but it hasn't been assigned a unit (Legion) or shown yet.
LibNamePlate.CreateNamePlate = function(self, baseFrame, name)
	-- Parent them to the baseFrame, or scaling simply won't work anymore
	local plate = setmetatable(self:CreateFrame("Frame", "GP_" .. (name or baseFrame:GetName()), baseFrame), NamePlate_MT)
	plate.frameLevel = FRAMELEVEL_CURRENT -- storing the framelevel
	plate.targetAlpha = 0
	plate.currentAlpha = 0
	plate.achievedAlpha = 0
	plate.colors = Colors
	plate.baseFrame = baseFrame
	plate.metaData = metaData
	plate:Hide()
	plate:SetPoint("CENTER", baseFrame, "CENTER", 0, 0)
	plate:SetFrameStrata("BACKGROUND")
	plate:SetFrameLevel(plate.frameLevel)
	plate:SetAlpha(plate.currentAlpha)
	plate:SetIgnoreParentAlpha(true)
	plate:UpdateScale()

	-- Make sure the visible part of the Blizzard frame remains hidden
	-- *Note: Do not EVER put a script on any of these with SetScript, 
	--  as it will break important secure functionality of the frame, like clicks!
	-- *Note2: Don't hook OnEnter/OnLeave on the baseFrame either, same reason as above.
	plate.KillBlizzard = function(self)
		local unitFrame = self.baseFrame.UnitFrame
		if (unitFrame) then
			unitFrame:Hide()
			-- 9.0.1 widget container.
			-- Will style it later, just need it visible now.
			self.widgetContainer = unitFrame.WidgetContainer
			if (self.widgetContainer) then
				self.widgetContainer:SetParent(self)
			end
			if (not self.hasHideScripts) then
				unitFrame:HookScript("OnShow", function() unitFrame:Hide() end) 
				self.hasHideScripts = true
			end
		end
	end

	-- Make sure our nameplate fades out when the blizzard one is hidden.
	baseFrame:HookScript("OnHide", function(baseFrame) plate:OnHide() end)

	-- Follow the blizzard scale changes.
	-- Does not appear to follow scale changes in 9.0.1.
	baseFrame:HookScript("OnSizeChanged", function() plate:UpdateScale() end)

	-- Since constantly updating frame levels can cause quite the performance drop, 
	-- we're just giving each frame a set frame level when they spawn. 
	-- We can still get frames overlapping, but in most cases we avoid it now.
	-- Targets, bosses and rares have an elevated frame level, 
	-- but when a nameplate returns to "normal" status, its previous stored level is used instead.
	FRAMELEVEL_CURRENT = FRAMELEVEL_CURRENT + FRAMELEVEL_STEP
	if (FRAMELEVEL_CURRENT > FRAMELEVEL_MAX) then
		FRAMELEVEL_CURRENT = FRAMELEVEL_MIN
	end

	-- Store the plate in our registry
	allPlates[baseFrame] = plate

	-- Enable the plate's event handler
	plate:SetScript("OnEvent", plate.OnEvent)

	-- Let modules do their thing
	self:ForAllEmbeds("PostCreateNamePlate", plate, baseFrame)

	return plate
end

-- register a widget/element
LibNamePlate.RegisterElement = function(self, elementName, enableFunc, disableFunc, updateFunc, version)
	check(elementName, 1, "string")
	check(enableFunc, 2, "function")
	check(disableFunc, 3, "function")
	check(updateFunc, 4, "function")
	check(version, 5, "number", "nil")

	-- Does an old version of the element exist?
	local old = elements[elementName]
	local needUpdate
	if old then
		if old.version then 
			if version then 
				if version <= old.version then 
					return 
				end 
				-- A more recent version is being registered
				needUpdate = true 
			else 
				return 
			end 
		else 
			if version then 
				-- A more recent version is being registered
				needUpdate = true 
			else 
				-- Two unversioned. just follow first come first served, 
				-- to allow the standalone addon to trumph. 
				return 
			end 
		end  
		return 
	end 

	-- Create our new element 
	local new = {
		Enable = enableFunc,
		Disable = disableFunc,
		Update = updateFunc,
		version = version
	}

	-- Change the pointer to the new element
	-- (doesn't change what table 'old' still points to)
	elements[elementName] = new 

	-- Postupdate existing frames embedding this if it exists
	if needUpdate then 
		-- Iterate all frames for it
		for unitFrame, element in pairs(frameElementsEnabled) do 
			if (element == elementName) then 
				-- Run the old disable method, 
				-- to get rid of old events and onupdate handlers.
				if old.Disable then 
					old.Disable(unitFrame)
				end 

				-- Run the new enable method
				if new.Enable then 
					new.Enable(unitFrame, unitFrame.unit, true)
				end 
			end 
		end 
	end 
end

-- NamePlate Handling
----------------------------------------------------------
local hasSetBlizzardSettings, hasQueuedSettingsUpdate

-- Leave any settings changes to the frontend modules
LibNamePlate.UpdateNamePlateOptions = function(self)
	if InCombatLockdown() then 
		hasQueuedSettingsUpdate = true 
		return 
	end 
	hasQueuedSettingsUpdate = nil
	hasSetBlizzardSettings = true
	self:ForAllEmbeds("PostUpdateNamePlateOptions")
end

LibNamePlate.UpdateAllScales = function(self)
	if (oldScale ~= LibNamePlate.SCALE) then
		for baseFrame, plate in pairs(allPlates) do
			if plate then
				plate:UpdateScale()
			end
		end
	end
end

-- NamePlate Event Handling
----------------------------------------------------------
LibNamePlate.OnEvent = function(self, event, ...)
	if (event == "NAME_PLATE_CREATED") then
		self:CreateNamePlate((...)) -- local namePlateFrameBase = ...

	elseif (event == "NAME_PLATE_UNIT_ADDED") then
		local unit = ...
		local baseFrame = GetNamePlateForUnit(unit)
		local plate = baseFrame and allPlates[baseFrame] 
		if plate then
			plate.unit = unit
			plate:OnShow(event, unit)
		end

	elseif (event == "NAME_PLATE_UNIT_REMOVED") then
		local unit = ...
		local baseFrame = GetNamePlateForUnit(unit)
		local plate = baseFrame and allPlates[baseFrame] 
		if plate then
			plate.unit = nil
			plate:OnHide(event, unit)
		end

	elseif (event == "PLAYER_TARGET_CHANGED") then
		HAS_TARGET = UnitExists("target")
		for plate, baseFrame in pairs(visiblePlates) do
			-- Will be 'false' when fading out, 'nil' when hidden.
			-- Either way, this only applies to visible, active plates. 
			if (baseFrame) then
				plate.isTarget = HAS_TARGET and plate.unit and UnitIsUnit(plate.unit, "target") 
				plate:UpdateAlpha()
				plate:UpdateFrameLevel()
				if (plate.PostUpdate) then
					plate:PostUpdate(event, plate.unit)
				end
			end
		end	
		
	elseif (event == "VARIABLES_LOADED") then
		self:UpdateNamePlateOptions()
	
	elseif (event == "PLAYER_ENTERING_WORLD") then
		IN_COMBAT = InCombatLockdown() and true or false
		self:ForAllEmbeds("PreUpdateNamePlateOptions")
		self:UpdateAllScales()
		self.frame.elapsed = 0
		self.frame.throttle = THROTTLE
		self.frame:SetScript("OnUpdate", self.OnUpdate)

	elseif (event == "PLAYER_LEAVING_WORLD") then 
		self.frame:SetScript("OnUpdate", nil)
		self.frame.elapsed = 0

	elseif (event == "PLAYER_REGEN_DISABLED") then 
		IN_COMBAT = true
		for plate, baseFrame in pairs(visiblePlates) do
			-- Will be 'false' when fading out, 'nil' when hidden.
			-- Either way, this only applies to visible, active plates. 
			if (baseFrame) then
				plate.inCombat = IN_COMBAT
				plate:UpdateAlpha()
				if (plate.PostUpdate) then
					plate:PostUpdate(event, plate.unit)
				end
			end
		end

	elseif (event == "PLAYER_REGEN_ENABLED") then 
		IN_COMBAT = false 
		for plate, baseFrame in pairs(visiblePlates) do
			-- Will be 'false' when fading out, 'nil' when hidden.
			-- Either way, this only applies to visible, active plates. 
			if (baseFrame) then
				plate.inCombat = IN_COMBAT
				plate:UpdateAlpha()
				if (plate.PostUpdate) then
					plate:PostUpdate(event, plate.unit)
				end
			end
		end
		if hasQueuedSettingsUpdate then 
			self:UpdateNamePlateOptions()
		end 

	elseif (event == "DISPLAY_SIZE_CHANGED") then
		self:UpdateNamePlateOptions()
		self:UpdateAllScales()

	elseif (event == "UI_SCALE_CHANGED") then
		self:UpdateAllScales()

	end
end

LibNamePlate.SetScript = function(self, scriptHandler, script)
	scriptHandlers[scriptHandler] = script
	if (scriptHandler == "OnUpdate") then
		local scriptFrame = LibNamePlate.scriptFrame
		if (not scriptFrame) then
			scriptFrame = CreateFrame("Frame", nil, LibFrame:GetFrame())
			LibNamePlate.scriptFrame = scriptFrame
		end
		if script then 
			scriptFrame:SetScript("OnUpdate", function(self, ...) 
				script(LibNamePlate, ...) 
			end)
		else
			scriptFrame:SetScript("OnUpdate", nil)
		end
	end
end

LibNamePlate.GetScript = function(self, scriptHandler)
	return scriptHandlers[scriptHandler]
end

LibNamePlate.OnUpdate = function(self, elapsed)
	
	-- Throttle the updates, to increase the performance. 
	self.elapsed = self.elapsed + elapsed
	if (self.elapsed < self.throttle) then
		return
	end

	-- We need the full value since the last set of updates
	local elapsed = self.elapsed

	for plate, frequentElements in pairs(frequentUpdates) do
		if (visiblePlates[plate]) then
			for element, frequency in pairs(frequentElements) do
				if (frequency.hz) then
					frequency.elapsed = frequency.elapsed + elapsed
					if (frequency.elapsed >= frequency.hz) then
						elements[element].Update(plate, "FrequentUpdate", plate.unit, elapsed) 
						frequency.elapsed = 0
					end
				else
					elements[element].Update(plate, "FrequentUpdate", plate.unit)
				end
			end
		end
	end

	-- Does a mouseover unit exist?
	local hasMouseOver = UnitExists("mouseover")

	-- Is a frame currently highlighted, 
	-- and if so, should it remain that way?
	local currentHighlight = self.currentHighlight
	if (currentHighlight) then
		local shouldClearCurrent
		if (hasMouseOver) then 
			-- Is the current mouseover the same as last time? 
			-- *The unit can have been cleared since last iteration,
			--  so it makes sense to check for the unit before the API call.
			local isMouseOver = (currentHighlight.unit) and UnitIsUnit("mouseover", currentHighlight.unit)
			if (isMouseOver) then
				-- This will prevent the alpha loop below
				-- from wasting time on checking for mouseover units.
				hasMouseOver = nil
			else
				-- There is a highlighted plate, 
				-- but it isn't this one. 
				shouldClearCurrent = true
			end
		else
			-- No current mouseover at all, 
			-- send signal to clear the current one.
			shouldClearCurrent = true
		end
		-- We have a new highlighted frame, 
		-- so fire the old one's leave script,
		-- and clear the reference.
		if (shouldClearCurrent) then
			currentHighlight:OnLeave()
			currentHighlight = nil
		end
	end
	
	-- Iterate!
	local visible, highAlpha, lowAlpha = 0, 0, 0
	for plate, baseFrame in pairs(visiblePlates) do

		if (hasMouseOver) and (not currentHighlight) then
			if (plate.unit) and (UnitIsUnit("mouseover", plate.unit)) then
				hasMouseOver = nil -- save all the time we can
				currentHighlight = plate -- save the reference for later
				currentHighlight:OnEnter() -- run the enter script
			end
		end

		if (baseFrame and baseFrame:IsShown()) then
			plate:UpdateAlpha()
		else
			plate.targetAlpha = 0
		end

		if (plate.currentAlpha ~= plate.targetAlpha) then
			if (plate.targetAlpha > plate.currentAlpha) then
			
				local step = elapsed/FADE_IN * (1/(plate.targetAlpha - plate.currentAlpha))

				if (plate.targetAlpha > plate.currentAlpha + step) then
					plate.currentAlpha = plate.currentAlpha + step -- fade in
				else
					plate.currentAlpha = plate.targetAlpha -- fading done
				end

			elseif (plate.targetAlpha < plate.currentAlpha) then

				local step = elapsed/(plate.targetAlpha == 0 and FADE_OUT or FADE_DOWN) * (1/(plate.currentAlpha - plate.targetAlpha))

				if (plate.targetAlpha < plate.currentAlpha - step) then
					plate.currentAlpha = plate.currentAlpha - step -- fade out
				else
					plate.currentAlpha = plate.targetAlpha -- fading done
				end
			end

			if (plate.currentAlpha == plate.targetAlpha) then 
				plate.achievedAlpha = plate.targetAlpha -- store this for the next fade
			end

			if (plate.currentAlpha >= .5) then
				highAlpha = highAlpha + 1
			end

			-- Still appears to be some weird stutter when reaching target alpha downwards here. 
			plate:SetAlpha(plate.currentAlpha)
		end

		if ((plate.achievedAlpha == 0) and (plate.targetAlpha == 0)) then

			visiblePlates[plate] = nil
			plate:Hide()

			if plate.Health then 
				plate.Health:SetValue(0, true)
			end 

			if plate.Cast then 
				plate.Cast:SetValue(0, true)
			end 
		end
	end	

	-- Store the metadata about visible plates and their alpha
	metaData.visiblePlatesHighAlpha = highAlpha

	self.currentHighlight = currentHighlight
	self.elapsed = 0
end 

LibNamePlate.SetConsoleVars = function(self, event, ...)
	if (InCombatLockdown()) then 
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "SetConsoleVars")
	end 
	if (event == "PLAYER_REGEN_ENABLED") then 
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "SetConsoleVars")
	end
	for name,value in pairs(ENFORCED_CVARS) do 
		SetCVar(name,value)
	end
end

LibNamePlate.Enable = function(self)
	if (self.enabled) then 
		return
	end 

	-- Only call this once 
	self:UnregisterAllEvents()

	-- Detection, showing and hidding
	self:RegisterEvent("NAME_PLATE_CREATED", "OnEvent")
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnEvent")
	self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnEvent")

	-- Updates
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_LEAVING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")

	-- Scale Changes
	self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnEvent")
	self:RegisterEvent("UI_SCALE_CHANGED", "OnEvent")

	-- Remove Personal Resource Display clutter
	self:KillClassClutter()
	self:UpdateNamePlateOptions()

	-- These we will enforce
	self:SetConsoleVars()

	self.enabled = true
end 

LibNamePlate.KillClassClutter = function(self)

	local BlizzPlateManaBar = NamePlateDriverFrame.classNamePlatePowerBar
	if (BlizzPlateManaBar) then
		BlizzPlateManaBar:Hide()
		BlizzPlateManaBar:UnregisterAllEvents()
	end

	if (NamePlateDriverFrame.SetupClassNameplateBars) then
		hooksecurefunc(NamePlateDriverFrame, "SetupClassNameplateBars", function(frame)
			if (not frame) or (frame:IsForbidden()) then
				return
			end
			if (frame.classNamePlateMechanicFrame) then
				frame.classNamePlateMechanicFrame:Hide()
			end
			if (frame.classNamePlatePowerBar) then
				frame.classNamePlatePowerBar:Hide()
				frame.classNamePlatePowerBar:UnregisterAllEvents()
			end
		end)
	end
end

LibNamePlate.StartNamePlateEngine = function(self)
	if LibNamePlate.enabled then 
		return
	end 
	if IsLoggedIn() then 
		-- Should do some initial parsing of already created nameplates here (?)
		-- *Only really needed if the modules enable it after PLAYER_ENTERING_WORLD, which they shouldn't anyway. 
		return LibNamePlate:Enable()
	else 
		LibNamePlate:UnregisterAllEvents()
		LibNamePlate:RegisterEvent("PLAYER_ENTERING_WORLD", "Enable")
	end 
end 

-- Kill off remnant events from prior library versions, just in case
LibNamePlate:UnregisterAllEvents()

-- Module embedding
local embedMethods = {
	StartNamePlateEngine = true,
	UpdateNamePlateOptions = true
}

LibNamePlate.GetEmbeds = function(self)
	return pairs(self.embeds)
end 

-- Iterate all embedded modules for the given method name or function
-- Silently fail if nothing exists. We don't want an error here. 
LibNamePlate.ForAllEmbeds = function(self, method, ...)
	for target in pairs(self.embeds) do 
		if (target) then 
			if (not target.IsUserDisabled) or (not target:IsUserDisabled()) then
				if (type(method) == "string") then
					if target[method] then
						target[method](target, ...)
					end
				else
					method(target, ...)
				end
			end
		end 
	end 
end 

LibNamePlate.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibNamePlate.embeds) do
	LibNamePlate:Embed(target)
end
