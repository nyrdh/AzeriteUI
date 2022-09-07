local LibInputMethod = Wheel:Set("LibInputMethod", 11)
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

-- WoW API
local GetActiveDeviceID = C_GamePad and C_GamePad.GetActiveDeviceID
local GetDeviceMappedState = C_GamePad and C_GamePad.GetDeviceMappedState

-- WoW Client Constants
local IsAnyClassic = LibClientBuild:IsAnyClassic()
local IsClassic = LibClientBuild:IsClassic()
local IsTBC = LibClientBuild:IsTBC()
local IsWrath = LibClientBuild:IsWrath()
local IsRetail = LibClientBuild:IsRetail()

-- Library registries
LibInputMethod.embeds = LibInputMethod.embeds or {}
LibInputMethod.frame = LibInputMethod.LibInputMethod or CreateFrame("Frame", nil, WorldFrame)
LibInputMethod.isUsingGamepad = LibInputMethod.isUsingGamepad -- semantics. listing for reference only.

-- Shortcuts!
local Frame = LibInputMethod.frame

----------------------------------------------------------------
-- Listener Frame
----------------------------------------------------------------
-- Fires when a key is pressed.
-- *Does not fire on repeated usage, only when a gamepad previously was used.
Frame.OnKeyDown = function(self, button)
	-- Since modifiers can be assigned to gamepad buttons,
	-- it's better if we simply choose to ignore them.
	if (IsRetail) then
		if (button == "ALT") or (button == "RALT") or (button == "LALT")
		or (button == "CTRL") or (button == "RCTRL") or (button == "LCTRL")
		or (button == "SHIFT") or (button == "RSHIFT") or (button == "LSHIFT")
		or (button == "ESCAPE") then
			return
		end
	end
	-- Compare to false to also have this event fire on first keypress.
	-- *as opposed to pure booleans which would also accept nil/unset
	if (LibInputMethod.isUsingGamepad ~= false) then
		LibInputMethod.isUsingGamepad = false
		LibInputMethod:SendMessage("GP_USING_KEYBOARD")
	end
end

-- Fires when the gamepad sticks are moved.
-- *Does not fire on repeated usage, only when keyboard previously was used.
Frame.OnGamePadStick = function(self, button)
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
-- @return <boolean> 'true' if a gamepad was the last used input method
LibInputMethod.IsUsingGamepad = function(self)
	return LibInputMethod.isUsingGamepad
end

-- @return <boolean> 'true' if the keyboard was the last used input method
LibInputMethod.IsUsingKeyboard = function(self)
	return not LibInputMethod.isUsingGamepad
end

-- Returns the type of gamepad to decide icon type.
-- @return <string,nil>
-- 	"xbox" 				A,B,X,Y
-- 	"xbox-reversed" 	B,A,Y,X
-- 	"playstation" 		cross, circle, square, triangle
-- 	"generic" 			1,2,3,4,5,6
-- 	nil 				no gamepad data available
LibInputMethod.GetGamepadType = function(self)
	-- Bail out with no return for non-Retail clients.
	-- We keep the function just to simplify front-end coding.
	if (not IsRetail) then
		return
	end
	-- This section used functions only available after 9.0.1.
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
