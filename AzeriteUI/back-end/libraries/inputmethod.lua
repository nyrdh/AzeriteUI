local LibInputMethod = Wheel:Set("LibInputMethod", 4)
if (not LibInputMethod) then
	return
end

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibInputMethod requires LibClientBuild to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibInputMethod requires LibEvent to be loaded.")

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibInputMethod requires LibMessage to be loaded.")

LibMessage:Embed(LibInputMethod)
LibEvent:Embed(LibInputMethod)

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local ipairs = ipairs
local pairs = pairs
local select = select
local string_format = string.format
local string_join = string.join
local string_match = string.match
local table_insert = table.insert
local table_remove = table.remove
local type = type

-- WoW API
local GetActiveDeviceID = C_GamePad and C_GamePad.GetActiveDeviceID
local GetDeviceMappedState = C_GamePad and C_GamePad.GetDeviceMappedState

-- WoW Client Constants
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Library registries
LibInputMethod.embeds = LibInputMethod.embeds or {}
LibInputMethod.frame = LibInputMethod.LibInputMethod or CreateFrame("Frame", nil, WorldFrame)
LibInputMethod.isUsingGamepad = LibInputMethod.isUsingGamepad -- semantics. listing for reference only.

-- Shortcuts!
local Frame = LibInputMethod.frame

----------------------------------------------------------------
-- Utility Functions
----------------------------------------------------------------
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

----------------------------------------------------------------
-- Listener Frame
----------------------------------------------------------------
-- Fires when a key is pressed.
Frame.OnKeyDown = function()
	-- Compare to false to also have this event fire on first keypress.
	if (LibInputMethod.isUsingGamepad ~= false) then
		LibInputMethod.isUsingGamepad = false
		LibInputMethod:SendMessage("GP_USING_KEYBOARD")
	end
end

-- Fires when the gamepad sticks are moved.
Frame.OnGamePadStick = function()
	if (not LibInputMethod.isUsingGamepad) then
		LibInputMethod.isUsingGamepad = true
		LibInputMethod:SendMessage("GP_USING_GAMEPAD")
	end
end

-- Fires when a gamepad button is pressed.
-- Not adding anything specific here yet.
Frame.OnGamePadButtonDown = Frame.OnGamePadStick

-- Setup the frame
Frame:SetPropagateKeyboardInput(true)
Frame:SetScript("OnKeyDown", Frame.OnKeyDown)

-- Let's assume this is only added to the Retail API.
if (IsRetail) then
	Frame:SetScript("OnGamePadStick", Frame.OnGamePadStick)
	Frame:SetScript("OnGamePadButtonDown", Frame.OnGamePadButtonDown)
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------
LibInputMethod.IsUsingGamepad = function(self)
	return LibInputMethod.isUsingGamepad
end

LibInputMethod.IsUsingKeyboard = function(self)
	return not LibInputMethod.isUsingGamepad
end

-- Primarily want this to return: "xbox[-reversed]", "playstation", "generic" or nil
-- @return <string,nil>
-- 		"xbox" 				A,B,X,Y
-- 		"xbox-reversed" 	B,A,Y,X
-- 		"playstation" 		cross, circle, square, triangle
-- 		"generic" 			1,2,3,4,5,6
LibInputMethod.GetGamepadType = function(self)
	-- Bail out with no return for non-Retail clients.
	-- We keep the function just to simplify front-end coding.
	if (not IsRetail) then
		return
	end
	local deviceID = GetActiveDeviceID()
	if (deviceID) then
		local mapped = GetDeviceMappedState(deviceID)
		if (mapped) then
			-- All except "Letters" is untested!
			if (mapped.labelStyle == "Letters") then 
				return "xbox"
			elseif (mapped.labelStyle == "LettersReversed") then 
				return "xbox-reversed"
			elseif (mapped.labelStyle == "Shapes") then 
				return "playstation"
			elseif (mapped.labelStyle == "Generic") then 
				return "generic"
			end	
		end
	end
end

-- Module embedding
local embedMethods = {
	GetGamepadType = true,
	IsUsingGamepad = true,
	IsUsingKeyboard = true
}

LibInputMethod.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibInputMethod.embeds) do
	LibInputMethod:Embed(target)
end
