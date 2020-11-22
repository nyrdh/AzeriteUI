--[[--

	The purpose of this file is to provide
	standarized forges for common widgets,
	like action- and aura buttons.

--]]--
local ADDON, Private = ...

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "Schematics::Widgets requires LibClientBuild to be loaded.")

-- Lua API
local pairs = pairs
local setmetatable = setmetatable
local tonumber = tonumber

-- WoW API
local IsBindingForGamePad = IsBindingForGamePad

-- WoW client version constants
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Private API
local Colors = Private.Colors
local GetAuraFilter = Private.GetAuraFilter
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia
local GetSchematic = Private.GetSchematic

-- Keybind Graphics
-----------------------------------------------------------
local BindingArt = {
	["PAD1"] = setmetatable({
		["playstation"] = 		GetMedia("controller-ps4-cross"),
		["xbox"] = 				GetMedia("controller-xbox-a"),
		["xbox-reversed"] = 	GetMedia("controller-xbox-b"),
		["generic"] = 			GetMedia("controller-generic-button1")
	}, { __index = function(t,k) return t.generic end }),

	["PAD2"] = setmetatable({ 
		["playstation"] = 		GetMedia("controller-ps4-circle"),
		["xbox"] = 				GetMedia("controller-xbox-b"),
		["xbox-reversed"] = 	GetMedia("controller-xbox-a"),
		["generic"] = 			GetMedia("controller-generic-button2")
	}, { __index = function(t,k) return t.generic end }),

	["PAD3"] = setmetatable({ 
		["playstation"] = 		GetMedia("controller-ps4-square"),
		["xbox"] = 				GetMedia("controller-xbox-x"),
		["xbox-reversed"] = 	GetMedia("controller-xbox-y"),
		["generic"] = 			GetMedia("controller-generic-button3")
	}, { __index = function(t,k) return t.generic end }),

	["PAD4"] = setmetatable({ 
		["playstation"] = 		GetMedia("controller-ps4-triangle"),
		["xbox"] = 				GetMedia("controller-xbox-y"),
		["xbox-reversed"] = 	GetMedia("controller-xbox-x"),
		["generic"] = 			GetMedia("controller-generic-button4")
	}, { __index = function(t,k) return t.generic end }),

	["PAD5"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-generic-button5")
	}, { __index = function(t,k) return t.generic end }),

	["PAD6"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-generic-button6")
	}, { __index = function(t,k) return t.generic end }),

	["PADBACK"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-xbox-back")
	}, { __index = function(t,k) return t.generic end }),

	["PADFORWARD"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-xbox-start")
	}, { __index = function(t,k) return t.generic end }),

	["PADDUP"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-xbox-dpad-up")
	}, { __index = function(t,k) return t.generic end }),

	["PADDDOWN"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-xbox-dpad-down")
	}, { __index = function(t,k) return t.generic end }),

	["PADDLEFT"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-xbox-dpad-left")
	}, { __index = function(t,k) return t.generic end }),

	["PADDRIGHT"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-xbox-dpad-right")
	}, { __index = function(t,k) return t.generic end }),

	["PADLTRIGGER"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-xbox-lt")
	}, { __index = function(t,k) return t.generic end }),

	["PADRTRIGGER"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-xbox-rt")
	}, { __index = function(t,k) return t.generic end }),

	["PADLSHOULDER"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-xbox-lb")
	}, { __index = function(t,k) return t.generic end }),

	["PADRSHOULDER"] = setmetatable({ 
		["generic"] = 			GetMedia("controller-xbox-rb")
	}, { __index = function(t,k) return t.generic end })
}

local GetBindingArt = function(key, artType)
	if (key) then
		for id,art in pairs(BindingArt) do
			if (key:find(id)) then
				return art[artType or "generic"]
			end
		end
	end
end

-- Utility Functions
-----------------------------------------------------------
-- Azerite theme Button mouseover highlight update
-- Requires: Darken, Border, Glow
local Azerite_ActionButton_PostUpdateMouseOver = function(self)
	if (self.isMouseOver) then 
		self.Darken:SetAlpha(0)
		self.Border:SetVertexColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], 1)
		self.Glow:Show()
	else 
		self.Darken:SetAlpha(.15)
		self.Border:SetVertexColor(Colors.ui[1], Colors.ui[2], Colors.ui[3], 1)
		self.Glow:Hide()
	end 
end 

-- Azerite theme Button mouseover highlight update
-- Requires: Darken, Border, Glow
local Legacy_ActionButton_PostUpdateMouseOver = function(self)
	if (self.isMouseOver) then 
		self.Darken:SetAlpha(0)
		self.Border:SetBackdropBorderColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], 1)
		self.Glow:Show()
	else 
		self.Darken:SetAlpha(.15)
		self.Border:SetBackdropBorderColor(Colors.ui[1], Colors.ui[2], Colors.ui[3], 1)
		self.Glow:Hide()
	end 
end 

-- Button stack/charge count font update
-- Optional: Count,Rank
local Azerite_ActionButton_PostUpdateStackCount = function(self, count)
	count = tonumber(count) or 0
	if (self.Count) then
		-- This is fairly theme specific.
		local font = GetFont((count < 10) and 18 or 14, true) 
		if (self.Count:GetFontObject() ~= font) then 
			self.Count:SetFontObject(font)
		end
	end
	-- TO BACK-END!
	-- Hide the rank text element if a count exists. 
	-- I don't think this'll ever happen (?), 
	-- but better safe than sorry. 
	if (self.Rank) then 
		self.Rank:SetShown((count == 0))
	end 
end

-- Button stack/charge count font update
-- Optional: Count,Rank
local Legacy_ActionButton_PostUpdateStackCount = function(self, count)
	count = tonumber(count) or 0
	if (self.Count) then
		-- This is fairly theme specific.
		local font = GetFont((count < 10) and 15 or 13, true) 
		if (self.Count:GetFontObject() ~= font) then 
			self.Count:SetFontObject(font)
		end
	end
	-- TO BACK-END!
	-- Hide the rank text element if a count exists. 
	-- I don't think this'll ever happen (?), 
	-- but better safe than sorry. 
	if (self.Rank) then 
		self.Rank:SetShown((count == 0))
	end 
end

-- Update the swipe color of button cooldowns
local ActionButton_PostUpdateCooldown = function(self, cooldown) 
	cooldown:SetSwipeColor(0, 0, 0, .75) 
end

-- Update the swipe color of button charge/stack cooldowns
local ActionButton_PostUpdateChargeCooldown = function(self, cooldown) 
	cooldown:SetSwipeColor(0, 0, 0, .5) 
end

-- Tone down and desaturate gamepad binds when not usable.
local ActionButton_PostUpdateUsable = function(self, shouldDesaturate)
	local i = 1
	while (i) do
		local slot = self["GamePadKeySlot"..i]
		if (slot) then
			if (shouldDesaturate) then
				slot:SetDesaturated(true)
				if (i == 2) then
					slot:SetVertexColor(.5, .5, .5)
				else
					slot:SetVertexColor(.25, .25, .25)
				end
			else
				slot:SetDesaturated(false)
				if (i == 2) then
					slot:SetVertexColor(1, 1, 1)
				else
					slot:SetVertexColor(.35, .35, .35)
				end
			end
			i = i + 1
		else
			i = nil
		end
	end
end

-- Keybind graphic magic
-- *Note that this method includes WoW API that only exists
--  in 9.0.1 or later, so do NOT call it AT ALL in classic!
local ActionButton_GetBindingTextAbbreviated = function(self)
	local key = self:GetBindingText()
	if (key) then
		key = key:upper()

		local keyboard = self:GetBindingText("key")
		local gamepad = self:GetBindingText("pad")

		if (keyboard and gamepad) then
			if (self.prioritizeGamePadBinds) then
				key = gamepad
			elseif (self.prioritzeKeyboardBinds) then
				key = keyboard
			end
		end

		-- (key:find("PAD"))
		if (IsBindingForGamePad(key)) then

			local mods = 0
			local slot1, slot2, slot3, slot4

			-- Get the main button pressed, without modifiers
			local main = key:match("%-?([%a%d]-)$")
			if (main) then

				-- Only while developing!
				local layout = Private.GetLayoutID()

				local padType = (self.padStyle == "default") and self.padType or self.padStyle
				local padAlt, padCtrl, padShift
				local padAltKey, padCtrlKey, padShiftKey

				-- Figure out what modifiers are used
				local alt = key:find("ALT%-")
				local ctrl = key:find("CTRL%-")
				local shift = key:find("SHIFT%-")

				-- If modifiers are used, check if the pad has them assigned. 
				if (alt or ctrl or shift) then
					if (alt) then
						padAltKey = GetCVar("GamePadEmulateAlt")
						if (padAltKey == "" or padAltKey == "none") then
							padAltKey = nil
						end 
						if (padAltKey) then
							padAlt = GetBindingArt(padAltKey,padType)
							mods = mods + 1
						end
					end
					if (ctrl) then
						padCtrlKey = GetCVar("GamePadEmulateCtrl")
						if (padCtrlKey == "" or padCtrlKey == "none") then
							padCtrlKey = nil
						end 
						if (padCtrlKey) then
							padCtrl = GetBindingArt(padCtrlKey,padType)
							mods = mods + 1
						end
					end
					if (shift) then
						padShiftKey = GetCVar("GamePadEmulateShift")
						if (padShiftKey == "" or padShiftKey == "none") then
							padShiftKey = nil
						end 
						if (padShiftKey) then
							padShift = GetBindingArt(padShiftKey,padType)
							mods = mods + 1
						end
					end
				end

				-- Main button art
				slot2 = GetBindingArt(main,padType)

				-- Note that this is only mods that has been assigned to the gamepad, 
				-- any keyboard buttons will not be shown here.
				if (mods == 1) then
					-- first available mod
					slot1 = padAlt or padCtrl or padShift 

				elseif (mods == 2) then
					-- first available mod
					slot3 = padAlt or padCtrl or padShift 

					-- alt exists > show ctrl or shift
					-- alt does not exist > (ctrl implicitly exists) > show shift
					slot1 = padAlt and (padCtrl or padShift) or padShift 

					local modKey = (slot1 == padAlt) and padAltKey or (slot1 == padCtrl) and padCtrlKey or padShiftKey
					if (layout == "Azerite") and (modKey:find("TRIGGER")) then
						slot1,slot3 = slot3,slot1
					end
					--if (layout == "Legacy") and (modKey:find("SHOULDER")) then
					--	slot1,slot3 = slot3,slot1
					--end

				elseif (mods == 3) then

					-- All of them exist
					slot3 = padAlt
					slot4 = padCtrl
					slot1 = padShift

				end

				if (layout == "Azerite") then
					if (mods > 0) then
						self.GamePadKeySlot2:SetPoint("TOPLEFT", 6, 0)
					else
						self.GamePadKeySlot2:SetPoint("TOPLEFT", 0, 0)
					end
					self.GamePadKeySlot2:SetSize(24,24)
					self.GamePadKeySlot2:SetDrawLayer("BORDER", 2)
	
					self.GamePadKeySlot1:SetPoint("TOPLEFT", -20, 6)
					self.GamePadKeySlot1:SetSize(36,36)
					self.GamePadKeySlot1:SetDrawLayer("BORDER", 3)

					self.GamePadKeySlot3:SetPoint("TOPLEFT", -14, -12)
					self.GamePadKeySlot3:SetSize(32,32)
					self.GamePadKeySlot3:SetDrawLayer("BORDER", 3)

					self.GamePadKeySlot4:SetPoint("TOPLEFT", -18, -30)
					self.GamePadKeySlot4:SetSize(32,32)
					self.GamePadKeySlot4:SetDrawLayer("BORDER", 3)
				else
					-- This whole thing looks just fucking bad.
					-- Not happy.
					local s,x,y = 3/4,9,8
					self.GamePadKeySlot2:SetPoint("TOPLEFT", -4+x, 4-y)
					self.GamePadKeySlot2:SetSize(24*s,24*s)
					self.GamePadKeySlot2:SetDrawLayer("BORDER", 2)
	
					self.GamePadKeySlot1:SetPoint("TOPLEFT", -8+x, -8-y)
					self.GamePadKeySlot1:SetSize(32*s,32*s)
					self.GamePadKeySlot1:SetDrawLayer("BORDER", 3)

					self.GamePadKeySlot3:SetPoint("TOPLEFT", -8+x, -20-y)
					self.GamePadKeySlot3:SetSize(32*s,32*s)
					self.GamePadKeySlot3:SetDrawLayer("BORDER", 3)

					self.GamePadKeySlot4:SetPoint("TOPLEFT", -8+x, -30-y)
					self.GamePadKeySlot4:SetSize(32*s,32*s)
					self.GamePadKeySlot4:SetDrawLayer("BORDER", 3)
				end


				if (mods == 1) then
					local modKey = (slot1 == padAlt) and padAltKey or (slot1 == padCtrl) and padCtrlKey or padShiftKey
					if (modKey:find("SHOULDER")) then
						if (layout == "Azerite") then
							self.GamePadKeySlot1:SetSize(32,32)
						else
							self.GamePadKeySlot1:SetSize(32*3/4,32*3/4)
						end
					end

				elseif (mods == 2) then
					local modKey1 = (slot1 == padAlt) and padAltKey or (slot1 == padCtrl) and padCtrlKey or padShiftKey
					local modKey2 = (slot3 == padAlt) and padAltKey or (slot3 == padCtrl) and padCtrlKey or padShiftKey
					if (modKey2:find("TRIGGER")) and (not modKey1:find("TRIGGER")) then
						slot1,slot3 = slot3,slot1
					end

				elseif (mods == 3) then
					local modKey1 = (slot1 == padAlt) and padAltKey or (slot1 == padCtrl) and padCtrlKey or padShiftKey
					local modKey2 = (slot3 == padAlt) and padAltKey or (slot3 == padCtrl) and padCtrlKey or padShiftKey
					local modKey3 = (slot4 == padAlt) and padAltKey or (slot4 == padCtrl) and padCtrlKey or padShiftKey

				end
				
				self.GamePadKeySlot1:SetTexture(slot1)
				self.GamePadKeySlot3:SetTexture(slot3)
				self.GamePadKeySlot4:SetTexture(slot4)
				self.GamePadKeySlot2:SetTexture(slot2)

				-- Return empty string to hide regular keybinds.
				return ""
			end
		end

		-- If no pad bind was used, clear out the textures
		self.GamePadKeySlot1:SetTexture("")
		self.GamePadKeySlot2:SetTexture("")
		self.GamePadKeySlot3:SetTexture("")
		self.GamePadKeySlot4:SetTexture("")
		
		-- Return standard abbreviations if no pad bind was used.
		return self:AbbreviateBindText(key)
	end
	return ""
end 

-- Use the standard binding text function for Classic.
-- This is a copy of the method used by the back-end.
-- Might seem slightly redundant replacing something with itself,
-- but it saves us from any further client version checks. 
if (not IsRetail) then
	ActionButton_GetBindingTextAbbreviated = function(self)
		return self:AbbreviateBindText(self:GetBindingText())
	end
end

-- Legacy Schematics
-----------------------------------------------------------
-- Applied to aura buttons.
-- Keep these in a manner that works without knowing the size.
Private.RegisterSchematic("WidgetForge::AuraButton::Large", "Legacy", {
	{
		type = "ModifyWidgets",
		widgets = {
			{
				parent = nil, ownerKey = "Icon", objectType = "Texture",
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					"SetTexCoord", { 5/64, 59/64, 5/64, 59/64 },
					"SetSizeOffset", -10
				} 
			},
			{
				parent = nil, ownerKey = "Count", objectType = "FontString",
				chain = {
					"SetPosition", { "BOTTOMRIGHT", 2, -2 },
					"SetFontObject", Private.GetFont(14, true),
					"SetTextColor", { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 }
				}
			},
			{
				parent = nil, ownerKey = "Time", objectType = "FontString",
				chain = {
					"SetPosition", { "TOPLEFT", -2, 2 },
					"SetFontObject", Private.GetFont(14, true)
				}
			}
		}
	},
	{
		type = "CreateWidgets",
		widgets = {
			{
				parent = "self", ownerKey = "Border", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetFrameLevelOffset", 2,
					"SetBackdrop", {{ edgeFile = Private.GetMedia("aura_border"), edgeSize = 16 }},
					"SetBackdropBorderColor", { Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3, 1 },
					"ClearAllPoints", "SetPoint", { "TOPLEFT", -7, 7 }, "SetPoint", { "BOTTOMRIGHT", 7, -7 }
				}

			}
		}
	}
})

-- Applied to primary bar action buttons.
Private.RegisterSchematic("WidgetForge::ActionButton::Normal", "Legacy", {
	{
		-- Only set the parent in modifiable widgets if it is your intention to change it.
		-- Otherwise the code will assume the owner is the parent, and leave it as is,
		-- which is what we want in the majority of cases.
		type = "ModifyWidgets",
		widgets = {
			{
				-- Note that a missing ownerKey or parentKey
				-- will apply these changes to the original object instead.
				parent = nil, ownerKey = nil, 
				chain = {
					"SetSize", { 54, 54 }, 
					"SetHitBox", { -4, -4, -4, -4 }
				},
				values = {
					"colors", Colors,
					"maxDisplayCount", 99,

					-- Post updates
					"PostUpdateCount", Legacy_ActionButton_PostUpdateStackCount,
					"PostUpdateCooldown", ActionButton_PostUpdateCooldown,
					"PostUpdateChargeCooldown", ActionButton_PostUpdateChargeCooldown,
					"PostEnter", Legacy_ActionButton_PostUpdateMouseOver,
					"PostLeave", Legacy_ActionButton_PostUpdateMouseOver,
					"PostUpdate", Legacy_ActionButton_PostUpdateMouseOver,
					"PostUpdateUsable", ActionButton_PostUpdateUsable,

					"OnKeyDown", function(self) end,
					"OnKeyUp", function(self) end,

					"GetBindingTextAbbreviated", ActionButton_GetBindingTextAbbreviated
				}
			},
			{
				parent = nil, ownerKey = "Icon", objectType = "Texture",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"ClearTexture", 
					"SetMask", GetMedia("actionbutton-mask-square-rounded")
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = nil, ownerKey = "Pushed", ownerDependencyKey = "SetPushedTexture", objectType = "Texture",
				chain = {
					"SetSize", { 44, 44 }, 
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetMask", GetMedia("actionbutton-mask-square-rounded"),
					"SetColorTexture", { 1, 1, 1, .15 }
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = nil, ownerKey = nil, ownerDependencyKey = "SetPushedTexture",
				chain = {
					"SetPushedTextureKey", "Pushed",
					"SetPushedTextureBlendMode", "ADD",
					"SetPushedTextureDrawLayer", { "ARTWORK", 1 }
				}
			},
			{
				parent = nil, ownerKey = "Flash", objectType = "Texture",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetDrawLayer", { "ARTWORK", 2 },
					"SetTexture", [[Interface\ChatFrame\ChatFrameBackground]],
					"SetVertexColor", { 1, 0, 0, .25 },
					"SetMask", GetMedia("actionbutton-mask-square-rounded")
				}
			},
			{
				parent = nil, ownerKey = "Cooldown", objectType = "Frame", objectSubType = "Cooldown",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetSwipeTexture", GetMedia("actionbutton-mask-square-rounded"),
					"SetDrawSwipe", true,
					"SetBlingTexture", { GetMedia("blank"), 0, 0, 0 , 0 },
					"SetDrawBling", true
				}
			},
			{
				parent = nil, ownerKey = "ChargeCooldown", objectType = "Frame", objectSubType = "Cooldown",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetSwipeTexture", { GetMedia("actionbutton-mask-square-rounded"), 0, 0, 0, .5 },
					"SetSwipeColor", { 0, 0, 0, .5 },
					"SetBlingTexture", { GetMedia("blank"), 0, 0, 0 , 0 },
					"SetDrawSwipe", true,
					"SetDrawBling", false
				}
			},
			{
				parent = nil, ownerKey = "CooldownCount", objectType = "FontString", 
				chain = {
					"SetPosition", { "CENTER", 1, 0 },
					"SetFontObject", GetFont(14, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "MIDDLE",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .85 }
				}
			},
			{
				parent = nil, ownerKey = "Count", objectType = "FontString", 
				chain = {
					"SetPosition", { "BOTTOMRIGHT", -6, 6 },
					"SetFontObject", GetFont(14, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "BOTTOM",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 }
				}
			},
			(IsClassic) and {
				parent = nil, ownerKey = "Rank", objectType = "FontString", 
				chain = {
					"SetPosition", { "BOTTOMRIGHT", -6, 6 },
					"SetFontObject", GetFont(14, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "BOTTOM",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3] }
				}
			} or false,
			{
				parent = nil, ownerKey = "Keybind", objectType = "FontString", 
				chain = {
					"SetPosition", { "TOPLEFT", 6, -6 },
					"SetFontObject", GetFont(13, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "BOTTOM",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3], .75 }
				}
			},
			{
				parent = nil, ownerKey = "SpellHighlight", objectType = "Frame", 
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					"SetSize", { 46/(122/256), 46/(122/256) }
				}
			},
			{
				parent = nil, ownerKey = "SpellHighlight,Texture", objectType = "Texture", 
				chain = {
					"SetTexture", GetMedia("actionbutton-spellhighlight-square-rounded"),
					"SetVertexColor", { 255/255, 225/255, 125/255, .75 },
				}
			},

			-- SpellAutoCast
			{
				parent = nil, ownerKey = "SpellAutoCast", objectType = "Frame", 
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					--"SetSize", { 50, 50 }, -- our upcoming custom rounded rectangle texture
					"SetSize", { 40, 40 } -- blizzard texture
				}
			},
			{
				parent = nil, ownerKey = "SpellAutoCast,Ants", objectType = "Texture", 
				chain = {
					--"SetTexture", GetMedia("actionbutton-ants-small-grid"),
					--"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], 1 },
					"SetTexture", [[Interface\SpellActivationOverlay\IconAlertAnts]], -- blizzard texture
					"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], .5 }
				}
			},
			{ 
				parent = nil, ownerKey = "SpellAutoCast,Ants,Anim", objectType = "Animation", 
				chain = {
					"SetSpeed", 1/15,
					--"SetGrid", { 512, 512, 96, 96, 25 },
					"SetGrid", { 256, 256, 48, 48, 23 } -- blizzard texture
				}
			},

			{
				parent = nil, ownerKey = "SpellAutoCast,Glow", objectType = "Texture", 
				chain = {
					--"SetTexture", GetMedia("actionbutton-ants-small-glow-grid"),
					--"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], .25 },
					"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], 0 },
				}
			},
			{
				parent = nil, ownerKey = "SpellAutoCast,Glow,Anim", objectType = "Animation", 
				chain = {
					"SetSpeed", 1/15,
					--"SetGrid", { 512, 512, 96, 96, 25 },
					"SetGrid", { 256, 256, 48, 48, 23 } -- blizzard texture
				}
			}
	
		}
	},
	{
		type = "CreateWidgets",
		widgets = {
			{
				parent = "self", ownerKey = "Backdrop", objectType = "Texture",
				chain = {
					"SetSize", { 44, 44 },
					"SetPoint", { "CENTER", 0, 0 },
					"SetDrawLayer", { "BACKGROUND", 1 },
					"SetVertexColor", { 2/3, 2/3, 2/3, 1 },
					"SetTexture", GetMedia("button-slot")
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = "self", ownerKey = "Checked", ownerDependencyKey = "SetCheckedTexture", objectType = "Texture",
				chain = {
					"SetDrawLayer", { "ARTWORK", 2 },
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetMask", GetMedia("actionbutton-mask-square-rounded"),
					"SetColorTexture", { .9, .8, .1, .3 }
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				ownerDependencyKey = "SetCheckedTexture",
				chain = {
					"SetCheckedTextureKey", "Checked",
					"SetCheckedTextureBlendMode", "ADD",
					"SetCheckedTextureDrawLayer", { "ARTWORK", 1 }
				},
			},
			{
				parent = "self", ownerKey = "Darken", objectType = "Texture",
				chain = {
					"SetDrawLayer", { "BACKGROUND", 3 },
					"SetSize", { 44, 44 },
					"SetAllPointsToParentKey", "Icon",
					"SetMask", GetMedia("actionbutton-mask-square-rounded"),
					"SetTexture", [=[Interface\ChatFrame\ChatFrameBackground]=],
					"SetVertexColor", { 0, 0, 0, .15 }
				}
			},
			{
				parent = "self", ownerKey = "BorderFrame", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetFrameLevelOffset", 5,
					"SetAllPointsToParent"
				}
			},
			{
				parent = "self,BorderFrame", ownerKey = "Border", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetFrameLevelOffset", 1, 
					"SetPoint", { "TOPLEFT", -9, 9 }, -- 18
					"SetPoint", { "BOTTOMRIGHT", 9, -9 },
					"SetBackdrop", {{ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 24 }}, --32
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 }
				}
			},

			{
				parent = "self,Overlay", ownerKey = "GamePadKeySlot1", objectType = "Texture",
				chain = {
					"SetPoint",  { "TOPLEFT", -15, -2 },
					"SetDrawLayer", { "BORDER", 2 },
					"SetSize", { 18, 18 }
				}
			},
			{
				parent = "self,Overlay", ownerKey = "GamePadKeySlot2", objectType = "Texture",
				chain = {
					"SetPoint",  { "TOPLEFT", 3, -2 },
					"SetDrawLayer", { "BORDER", 2 },
					"SetSize", { 18, 18 }
				}
			},
			{
				parent = "self,Overlay", ownerKey = "GamePadKeySlot3", objectType = "Texture",
				chain = {
					"SetPoint",  { "TOPLEFT", -13, -21 },
					"SetDrawLayer", { "BORDER", 2 },
					"SetSize", { 18, 18 }
				}
			},
			{
				parent = "self,Overlay", ownerKey = "GamePadKeySlot4", objectType = "Texture",
				chain = {
					"SetPoint",  { "TOPLEFT", 5, -21 },
					"SetDrawLayer", { "BORDER", 2 },
					"SetSize", { 18, 18 }				
				}
			},
			{
				parent = "self,BorderFrame", ownerKey = "Glow", objectType = "Texture",
				chain = {
					"SetHidden",
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetSize", { 44, 44 },
					"SetPoint", { "CENTER", 0, 0 },
					"SetTexture", GetMedia("actionbutton-mask-square-rounded"),
					"SetVertexColor", { 1, 1, 1, .05 },
					"SetBlendMode", "ADD"
				}
			}

		}
	}
})

-- Applied to pet-, stance- and additional bars action buttons.
Private.RegisterSchematic("WidgetForge::ActionButton::Small", "Legacy", {
	{
		-- Only set the parent in modifiable widgets if it is your intention to change it.
		-- Otherwise the code will assume the owner is the parent, and leave it as is,
		-- which is what we want in the majority of cases.
		type = "ModifyWidgets",
		widgets = {
			{
				-- Note that a missing ownerKey or parentKey
				-- will apply these changes to the original object instead.
				parent = nil, ownerKey = nil, 
				chain = {
					"SetSize", { 54, 54 }, 
					"SetHitBox", { -4, -4, -4, -4 }
				},
				values = {
					"colors", Colors,
					"maxDisplayCount", 99,

					-- Post updates
					"PostUpdateCount", Legacy_ActionButton_PostUpdateStackCount,
					"PostUpdateCooldown", ActionButton_PostUpdateCooldown,
					"PostUpdateChargeCooldown", ActionButton_PostUpdateChargeCooldown,
					"PostEnter", Legacy_ActionButton_PostUpdateMouseOver,
					"PostLeave", Legacy_ActionButton_PostUpdateMouseOver,
					"PostUpdate", Legacy_ActionButton_PostUpdateMouseOver,
					"PostUpdateUsable", ActionButton_PostUpdateUsable,

					"OnKeyDown", function(self) end,
					"OnKeyUp", function(self) end,

					"GetBindingTextAbbreviated", ActionButton_GetBindingTextAbbreviated
				}
			},
			{
				parent = nil, ownerKey = "Icon", objectType = "Texture",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"ClearTexture", 
					"SetMask", GetMedia("actionbutton-mask-square-rounded")
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = nil, ownerKey = "Pushed", ownerDependencyKey = "SetPushedTexture", objectType = "Texture",
				chain = {
					"SetSize", { 44, 44 }, 
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetMask", GetMedia("actionbutton-mask-square-rounded"),
					"SetColorTexture", { 1, 1, 1, .15 }
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = nil, ownerKey = nil, ownerDependencyKey = "SetPushedTexture",
				chain = {
					"SetPushedTextureKey", "Pushed",
					"SetPushedTextureBlendMode", "ADD",
					"SetPushedTextureDrawLayer", { "ARTWORK", 1 }
				}
			},
			{
				parent = nil, ownerKey = "Flash", objectType = "Texture",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetDrawLayer", { "ARTWORK", 2 },
					"SetTexture", [[Interface\ChatFrame\ChatFrameBackground]],
					"SetVertexColor", { 1, 0, 0, .25 },
					"SetMask", GetMedia("actionbutton-mask-square-rounded")
				}
			},
			{
				parent = nil, ownerKey = "Cooldown", objectType = "Frame", objectSubType = "Cooldown",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetSwipeTexture", GetMedia("actionbutton-mask-square-rounded"),
					"SetDrawSwipe", true,
					"SetBlingTexture", { GetMedia("blank"), 0, 0, 0 , 0 },
					"SetDrawBling", true
				}
			},
			{
				parent = nil, ownerKey = "ChargeCooldown", objectType = "Frame", objectSubType = "Cooldown",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetSwipeTexture", { GetMedia("actionbutton-mask-square-rounded"), 0, 0, 0, .5 },
					"SetSwipeColor", { 0, 0, 0, .5 },
					"SetBlingTexture", { GetMedia("blank"), 0, 0, 0 , 0 },
					"SetDrawSwipe", true,
					"SetDrawBling", false
				}
			},
			{
				parent = nil, ownerKey = "CooldownCount", objectType = "FontString", 
				chain = {
					"SetPosition", { "CENTER", 1, 0 },
					"SetFontObject", GetFont(14, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "MIDDLE",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .85 }
				}
			},
			{
				parent = nil, ownerKey = "Count", objectType = "FontString", 
				chain = {
					"SetPosition", { "BOTTOMRIGHT", -6, 6 },
					"SetFontObject", GetFont(14, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "BOTTOM",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 }
				}
			},
			(IsClassic) and {
				parent = nil, ownerKey = "Rank", objectType = "FontString", 
				chain = {
					"SetPosition", { "BOTTOMRIGHT", -6, 6 },
					"SetFontObject", GetFont(14, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "BOTTOM",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3] }
				}
			} or false,
			{
				parent = nil, ownerKey = "Keybind", objectType = "FontString", 
				chain = {
					"SetPosition", { "TOPLEFT", 6, -6 },
					"SetFontObject", GetFont(13, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "BOTTOM",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3], .75 }
				}
			},
			{
				parent = nil, ownerKey = "SpellHighlight", objectType = "Frame", 
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					"SetSize", { 46/(122/256), 46/(122/256) }
				}
			},
			{
				parent = nil, ownerKey = "SpellHighlight,Texture", objectType = "Texture", 
				chain = {
					"SetTexture", GetMedia("actionbutton-spellhighlight-square-rounded"),
					"SetVertexColor", { 255/255, 225/255, 125/255, .75 },
				}
			},

			-- SpellAutoCast
			{
				parent = nil, ownerKey = "SpellAutoCast", objectType = "Frame", 
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					--"SetSize", { 50, 50 }, -- our upcoming custom rounded rectangle texture
					"SetSize", { 40, 40 } -- blizzard texture
				}
			},
			{
				parent = nil, ownerKey = "SpellAutoCast,Ants", objectType = "Texture", 
				chain = {
					--"SetTexture", GetMedia("actionbutton-ants-small-grid"),
					--"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], 1 },
					"SetTexture", [[Interface\SpellActivationOverlay\IconAlertAnts]], -- blizzard texture
					"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], .5 }
				}
			},
			{ 
				parent = nil, ownerKey = "SpellAutoCast,Ants,Anim", objectType = "Animation", 
				chain = {
					"SetSpeed", 1/15,
					--"SetGrid", { 512, 512, 96, 96, 25 },
					"SetGrid", { 256, 256, 48, 48, 23 } -- blizzard texture
				}
			},

			{
				parent = nil, ownerKey = "SpellAutoCast,Glow", objectType = "Texture", 
				chain = {
					--"SetTexture", GetMedia("actionbutton-ants-small-glow-grid"),
					--"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], .25 },
					"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], 0 },
				}
			},
			{
				parent = nil, ownerKey = "SpellAutoCast,Glow,Anim", objectType = "Animation", 
				chain = {
					"SetSpeed", 1/15,
					--"SetGrid", { 512, 512, 96, 96, 25 },
					"SetGrid", { 256, 256, 48, 48, 23 } -- blizzard texture
				}
			}
	
		}
	},
	{
		type = "CreateWidgets",
		widgets = {
			{
				parent = "self", ownerKey = "Backdrop", objectType = "Texture",
				chain = {
					"SetSize", { 44, 44 },
					"SetPoint", { "CENTER", 0, 0 },
					"SetDrawLayer", { "BACKGROUND", 1 },
					"SetVertexColor", { 2/3, 2/3, 2/3, 1 },
					"SetTexture", GetMedia("button-slot")
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = "self", ownerKey = "Checked", ownerDependencyKey = "SetCheckedTexture", objectType = "Texture",
				chain = {
					"SetDrawLayer", { "ARTWORK", 2 },
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetMask", GetMedia("actionbutton-mask-square-rounded"),
					"SetColorTexture", { .9, .8, .1, .3 }
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				ownerDependencyKey = "SetCheckedTexture",
				chain = {
					"SetCheckedTextureKey", "Checked",
					"SetCheckedTextureBlendMode", "ADD",
					"SetCheckedTextureDrawLayer", { "ARTWORK", 1 }
				},
			},
			{
				parent = "self", ownerKey = "Darken", objectType = "Texture",
				chain = {
					"SetDrawLayer", { "BACKGROUND", 3 },
					"SetSize", { 44, 44 },
					"SetAllPointsToParentKey", "Icon",
					"SetMask", GetMedia("actionbutton-mask-square-rounded"),
					"SetTexture", [=[Interface\ChatFrame\ChatFrameBackground]=],
					"SetVertexColor", { 0, 0, 0, .15 }
				}
			},
			{
				parent = "self", ownerKey = "BorderFrame", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetFrameLevelOffset", 5,
					"SetAllPointsToParent"
				}
			},
			{
				parent = "self,BorderFrame", ownerKey = "Border", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetFrameLevelOffset", 1, 
					"SetPoint", { "TOPLEFT", -9, 9 }, -- 18
					"SetPoint", { "BOTTOMRIGHT", 9, -9 },
					"SetBackdrop", {{ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 24 }}, --32
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 }
				}
			},
			{
				parent = "self,BorderFrame", ownerKey = "Glow", objectType = "Texture",
				chain = {
					"SetHidden",
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetSize", { 44, 44 },
					"SetPoint", { "CENTER", 0, 0 },
					"SetTexture", GetMedia("actionbutton-mask-square-rounded"),
					"SetVertexColor", { 1, 1, 1, .05 },
					"SetBlendMode", "ADD"
				}
			}

		}
	}
})

-- Applied to huge floating buttons like zone abilities.
Private.RegisterSchematic("WidgetForge::ActionButton::Large", "Legacy", {
})

-- Azerite Schematics
-----------------------------------------------------------
-- Applied to primary bar action buttons.
Private.RegisterSchematic("WidgetForge::ActionButton::Normal", "Azerite", {
	{
		-- Only set the parent in modifiable widgets if it is your intention to change it.
		-- Otherwise the code will assume the owner is the parent, and leave it as is,
		-- which is what we want in the majority of cases.
		type = "ModifyWidgets",
		widgets = {
			{
				-- Note that a missing ownerKey or parentKey
				-- will apply these changes to the original object instead.
				parent = nil, ownerKey = nil, 
				chain = {
					"SetSize", { 64, 64 }, 
					"SetHitBox", { -4, -4, -4, -4 }
				},
				values = {
					"colors", Colors,
					"maxDisplayCount", 99,

					-- Post updates
					"PostUpdateCount", Azerite_ActionButton_PostUpdateStackCount,
					"PostUpdateCooldown", ActionButton_PostUpdateCooldown,
					"PostUpdateChargeCooldown", ActionButton_PostUpdateChargeCooldown,
					"PostEnter", Azerite_ActionButton_PostUpdateMouseOver,
					"PostLeave", Azerite_ActionButton_PostUpdateMouseOver,
					"PostUpdate", Azerite_ActionButton_PostUpdateMouseOver,
					"PostUpdateUsable", ActionButton_PostUpdateUsable,

					"OnKeyDown", function(self) end,
					"OnKeyUp", function(self) end,

					"GetBindingTextAbbreviated", ActionButton_GetBindingTextAbbreviated
				}
			},
			{
				parent = nil, ownerKey = "Icon", objectType = "Texture",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"ClearTexture", 
					"SetMask", GetMedia("actionbutton-mask-circular")
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = nil, ownerKey = "Pushed", ownerDependencyKey = "SetPushedTexture", objectType = "Texture",
				chain = {
					"SetSize", { 44, 44 }, 
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetMask", GetMedia("actionbutton-mask-circular"),
					"SetColorTexture", { 1, 1, 1, .15 }
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = nil, ownerKey = nil, ownerDependencyKey = "SetPushedTexture",
				chain = {
					"SetPushedTextureKey", "Pushed",
					"SetPushedTextureBlendMode", "ADD",
					"SetPushedTextureDrawLayer", { "ARTWORK", 1 }
				}
			},
			{
				parent = nil, ownerKey = "Flash", objectType = "Texture",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetDrawLayer", { "ARTWORK", 2 },
					"SetTexture", [[Interface\ChatFrame\ChatFrameBackground]],
					"SetVertexColor", { 1, 0, 0, .25 },
					"SetMask", GetMedia("actionbutton-mask-circular")
				}
			},
			{
				parent = nil, ownerKey = "Cooldown", objectType = "Frame", objectSubType = "Cooldown",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetSwipeTexture", GetMedia("actionbutton-mask-circular"),
					"SetDrawSwipe", true,
					"SetBlingTexture", { GetMedia("blank"), 0, 0, 0 , 0 },
					"SetDrawBling", true
				}
			},
			{
				parent = nil, ownerKey = "ChargeCooldown", objectType = "Frame", objectSubType = "Cooldown",
				chain = {
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetSwipeTexture", { GetMedia("actionbutton-mask-circular"), 0, 0, 0, .5 },
					"SetSwipeColor", { 0, 0, 0, .5 },
					"SetBlingTexture", { GetMedia("blank"), 0, 0, 0 , 0 },
					"SetDrawSwipe", true,
					"SetDrawBling", false
				}
			},
			{
				parent = nil, ownerKey = "CooldownCount", objectType = "FontString", 
				chain = {
					"SetPosition", { "CENTER", 1, 0 },
					"SetFontObject", GetFont(16, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "MIDDLE",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .85 }
				}
			},
			{
				parent = nil, ownerKey = "Count", objectType = "FontString", 
				chain = {
					"SetPosition", { "BOTTOMRIGHT", -3, 3 },
					"SetFontObject", GetFont(18, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "BOTTOM",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 }
				}
			},
			(IsClassic) and {
				parent = nil, ownerKey = "Rank", objectType = "FontString", 
				chain = {
					"SetPosition", { "BOTTOMRIGHT", -3, 3 },
					"SetFontObject", GetFont(18, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "BOTTOM",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3] }
				}
			} or false,
			{
				parent = nil, ownerKey = "Keybind", objectType = "FontString", 
				chain = {
					"SetPosition", { "TOPLEFT", 5, -5 },
					"SetFontObject", GetFont(15, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "BOTTOM",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3], .75 }
				}
			},
			{
				parent = nil, ownerKey = "SpellHighlight", objectType = "Frame", 
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					"SetSize", { 64/(122/256), 64/(122/256) }
				}
			},
			{
				parent = nil, ownerKey = "SpellHighlight,Texture", objectType = "Texture", 
				chain = {
					"SetTexture", GetMedia("actionbutton-spellhighlight"),
					"SetVertexColor", { 255/255, 225/255, 125/255, .75 },
				}
			},
			{
				parent = nil, ownerKey = "SpellAutoCast", objectType = "Frame", 
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					"SetSize", { 50, 50 }
				}
			},
			{
				parent = nil, ownerKey = "SpellAutoCast,Ants", objectType = "Texture", 
				chain = {
					"SetTexture", GetMedia("actionbutton-ants-small-grid"),
					"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], 1 },
				}
			},
			{
				parent = nil, ownerKey = "SpellAutoCast,Ants,Anim", objectType = "Animation", 
				chain = {
					"SetSpeed", 1/15,
					"SetGrid", { 512, 512, 96, 96, 25 },
				}
			},

			{
				parent = nil, ownerKey = "SpellAutoCast,Glow", objectType = "Texture", 
				chain = {
					"SetTexture", GetMedia("actionbutton-ants-small-glow-grid"),
					"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], .25 },
				}
			},
			{
				parent = nil, ownerKey = "SpellAutoCast,Glow,Anim", objectType = "Animation", 
				chain = {
					"SetSpeed", 1/15,
					"SetGrid", { 512, 512, 96, 96, 25 },
				}
			},
	
		}
	},
	{
		type = "CreateWidgets",
		widgets = {
			{
				parent = "self", ownerKey = "Backdrop", objectType = "Texture",
				chain = {
					"SetSize", { 64/(122/256), 64/(122/256) },
					"SetPoint", { "CENTER", 0, 0 },
					"SetDrawLayer", { "BACKGROUND", 1 },
					"SetVertexColor", { 2/3, 2/3, 2/3, 1 },
					"SetTexture", GetMedia("actionbutton-backdrop")
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = "self", ownerKey = "Checked", ownerDependencyKey = "SetCheckedTexture", objectType = "Texture",
				chain = {
					"SetDrawLayer", { "ARTWORK", 2 },
					"SetSize", { 44, 44 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetMask", GetMedia("actionbutton-mask-circular"),
					"SetColorTexture", { .9, .8, .1, .3 }
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				ownerDependencyKey = "SetCheckedTexture",
				chain = {
					"SetCheckedTextureKey", "Checked",
					"SetCheckedTextureBlendMode", "ADD",
					"SetCheckedTextureDrawLayer", { "ARTWORK", 1 }
				},
			},
			{
				parent = "self", ownerKey = "Darken", objectType = "Texture",
				chain = {
					"SetDrawLayer", { "BACKGROUND", 3 },
					"SetSize", { 44, 44 },
					"SetAllPointsToParentKey", "Icon",
					"SetMask", GetMedia("actionbutton-mask-circular"),
					"SetTexture", [=[Interface\ChatFrame\ChatFrameBackground]=],
					"SetVertexColor", { 0, 0, 0, .15 }
				}
			},
			{
				parent = "self", ownerKey = "BorderFrame", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetFrameLevelOffset", 5,
					"SetAllPointsToParent"
				}
			},
			{
				parent = "self,BorderFrame", ownerKey = "Border", objectType = "Texture",
				chain = {
					"SetPoint", { "CENTER", 0, 0 },
					"SetDrawLayer", { "BORDER", 1 },
					"SetSize", { 64/(122/256), 64/(122/256) },
					"SetTexture", GetMedia("actionbutton-border"),
					"SetVertexColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 }
				}
			},
			{
				parent = "self,BorderFrame", ownerKey = "GamePadKeySlot1", objectType = "Texture",
				chain = {
					"SetPoint",  { "TOPLEFT", 5-18, -5 },
					"SetDrawLayer", { "BORDER", 2 },
					"SetSize", { 18, 18 },
				}
			},
			{
				parent = "self,BorderFrame", ownerKey = "GamePadKeySlot2", objectType = "Texture",
				chain = {
					"SetPoint",  { "TOPLEFT", 5, -5 },
					"SetDrawLayer", { "BORDER", 2 },
					"SetSize", { 18, 18 },
				}
			},
			{
				parent = "self,BorderFrame", ownerKey = "GamePadKeySlot3", objectType = "Texture",
				chain = {
					"SetPoint",  { "TOPLEFT", 5-18, -5-18 },
					"SetDrawLayer", { "BORDER", 2 },
					"SetSize", { 18, 18 },
				}
			},
			{
				parent = "self,BorderFrame", ownerKey = "GamePadKeySlot4", objectType = "Texture",
				chain = {
					"SetPoint",  { "TOPLEFT", 5, -5-18 },
					"SetDrawLayer", { "BORDER", 2 },
					"SetSize", { 18, 18 },
				}
			},
			{
				parent = "self,Overlay", ownerKey = "Glow", objectType = "Texture",
				chain = {
					"SetHidden",
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetSize", { 44/(122/256),44/(122/256) },
					"SetPoint", { "CENTER", 0, 0 },
					"SetTexture", GetMedia("actionbutton-glow-white"),
					"SetVertexColor", { 1, 1, 1, .5 },
					"SetBlendMode", "ADD"
				}
			}

		}
	}
})

-- Applied to pet-, stance- and additional bars action buttons.
Private.RegisterSchematic("WidgetForge::ActionButton::Small", "Azerite", {
	{
		-- Only set the parent in modifiable widgets if it is your intention to change it.
		-- Otherwise the code will assume the owner is the parent, and leave it as is,
		-- which is what we want in the majority of cases.
		type = "ModifyWidgets",
		widgets = {
			{
				-- Note that a missing ownerKey or parentKey
				-- will apply these changes to the original object instead.
				parent = nil, ownerKey = nil, 
				chain = {
					"SetSize", { 48, 48 }, 
					"SetHitBox", { -4, -4, -4, -4 }
				},
				values = {
					"colors", Colors,
					"maxDisplayCount", 99,

					-- Post updates
					"PostUpdateCount", Azerite_ActionButton_PostUpdateStackCount,
					"PostUpdateCooldown", ActionButton_PostUpdateCooldown,
					"PostUpdateChargeCooldown", ActionButton_PostUpdateChargeCooldown,
					"PostEnter", Azerite_ActionButton_PostUpdateMouseOver,
					"PostLeave", Azerite_ActionButton_PostUpdateMouseOver,
					"PostUpdate", Azerite_ActionButton_PostUpdateMouseOver
				}
			},
			{
				parent = nil, ownerKey = "Icon", objectType = "Texture",
				chain = {
					"SetSize", { 33, 33 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"ClearTexture", 
					"SetMask", GetMedia("actionbutton-mask-circular")
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = nil, ownerKey = "Pushed", ownerDependencyKey = "SetPushedTexture", objectType = "Texture",
				chain = {
					"SetSize", { 33, 33 }, 
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetMask", GetMedia("actionbutton-mask-circular"),
					"SetColorTexture", { 1, 1, 1, .15 }
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = nil, ownerKey = nil, ownerDependencyKey = "SetPushedTexture",
				chain = {
					"SetPushedTextureKey", "Pushed",
					"SetPushedTextureMask", GetMedia("actionbutton-mask-circular"),
					"SetPushedTextureBlendMode", "ADD",
					"SetPushedTextureDrawLayer", { "ARTWORK", 1 }
				}
			},
			{
				parent = nil, ownerKey = "Flash", objectType = "Texture",
				chain = {
					"SetSize", { 33, 33 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetDrawLayer", { "ARTWORK", 2 },
					"SetTexture", [=[Interface\ChatFrame\ChatFrameBackground]=],
					"SetVertexColor", { 1, 0, 0, .25 },
					"SetMask", GetMedia("actionbutton-mask-circular")
				}
			},
			{
				parent = nil, ownerKey = "Cooldown", objectType = "Frame", objectSubType = "Cooldown",
				chain = {
					"SetSize", { 33, 33 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetSwipeTexture", GetMedia("actionbutton-mask-circular"),
					"SetDrawSwipe", true,
					"SetBlingTexture", { GetMedia("blank"), 0, 0, 0 , 0 },
					"SetDrawBling", true
				}
			},
			{
				parent = nil, ownerKey = "ChargeCooldown", objectType = "Frame", objectSubType = "Cooldown",
				chain = {
					"SetSize", { 33, 33 },
					"SetPosition", { "CENTER", 0, 0 }, 
					"SetSwipeTexture", { GetMedia("actionbutton-mask-circular"), 0, 0, 0, .5 },
					"SetSwipeColor", { 0, 0, 0, .5 },
					"SetBlingTexture", { GetMedia("blank"), 0, 0, 0 , 0 },
					"SetDrawSwipe", true,
					"SetDrawBling", false
				}
			},
			{
				parent = nil, ownerKey = "CooldownCount", objectType = "FontString", 
				chain = {
					"SetPosition", { "CENTER", 1, 0 },
					"SetFontObject", GetFont(16, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "MIDDLE",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .85 }
				}
			},
			{
				parent = nil, ownerKey = "Count", objectType = "FontString", 
				chain = {
					"SetPosition", { "BOTTOMRIGHT", -3, 3 },
					"SetFontObject", GetFont(11, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "BOTTOM",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 }
				}
			},
			{
				parent = nil, ownerKey = "Keybind", objectType = "FontString", 
				chain = {
					"SetPosition", { "TOPLEFT", 5, -5 },
					"SetFontObject", GetFont(12, true),
					"SetJustifyH", "CENTER",
					"SetJustifyV", "BOTTOM",
					"SetShadowOffset", { 0, 0 },
					"SetShadowColor", { 0, 0, 0, 1 },
					"SetTextColor", { Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3], .75 }
				}
			},
			--[[
			{
				parent = nil, ownerKey = "SpellHighlight", objectType = "Frame", 
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					"SetSize", { 48/(122/256), 48/(122/256) }
				}
			},
			{
				parent = nil, ownerKey = "SpellHighlight,Texture", objectType = "Texture", 
				chain = {
					"SetTexture", GetMedia("actionbutton-spellhighlight"),
					"SetVertexColor", { 255/255, 225/255, 125/255, .75 },
				}
			},
			--]]--
			{
				parent = nil, ownerKey = "SpellAutoCast", objectType = "Frame", 
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					"SetSize", { 37.5, 37.5 }
				}
			},
			{
				parent = nil, ownerKey = "SpellAutoCast,Ants", objectType = "Texture", 
				chain = {
					"SetTexture", GetMedia("actionbutton-ants-small-grid"),
					"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], 1 },
				}
			},
			{
				parent = nil, ownerKey = "SpellAutoCast,Ants,Anim", objectType = "Animation", 
				chain = {
					"SetSpeed", 1/15,
					"SetGrid", { 512, 512, 96, 96, 25 },
				}
			},

			{
				parent = nil, ownerKey = "SpellAutoCast,Glow", objectType = "Texture", 
				chain = {
					"SetTexture", GetMedia("actionbutton-ants-small-glow-grid"),
					"SetVertexColor", { Colors.cast[1], Colors.cast[2], Colors.cast[3], .25 },
				}
			},
			{
				parent = nil, ownerKey = "SpellAutoCast,Glow,Anim", objectType = "Animation", 
				chain = {
					"SetSpeed", 1/15,
					"SetGrid", { 512, 512, 96, 96, 25 },
				}
			},

		}
	},
	{
		type = "CreateWidgets",
		widgets = {
			{
				parent = "self", ownerKey = "Backdrop", objectType = "Texture",
				chain = {
					"SetSize", { 48/(122/256), 48/(122/256) },
					"SetPoint", { "CENTER", 0, 0 },
					"SetDrawLayer", { "BACKGROUND", 1 },
					"SetVertexColor", { 2/3, 2/3, 2/3, 1 },
					"SetTexture", GetMedia("actionbutton-backdrop")
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				parent = "self", ownerKey = "Checked", ownerDependencyKey = "SetCheckedTexture", objectType = "Texture",
				chain = {
					"SetDrawLayer", { "ARTWORK", 2 },
					"SetSize", { 33, 33 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetMask", GetMedia("actionbutton-mask-circular"),
					"SetColorTexture", { .9, .8, .1, .3 }
				}
			},
			{
				-- If the owner does not have the ownerDependencyKey key, this item will be skipped.
				ownerDependencyKey = "SetCheckedTexture",
				chain = {
					"SetCheckedTextureKey", "Checked",
					"SetCheckedTextureMask", GetMedia("actionbutton-mask-circular"),
					"SetCheckedTextureBlendMode", "ADD",
					"SetCheckedTextureDrawLayer", { "ARTWORK", 1 }
				},
			},
			{
				parent = "self", ownerKey = "Darken", objectType = "Texture",
				chain = {
					"SetDrawLayer", { "BACKGROUND", 3 },
					"SetSize", { 33, 33 },
					"SetAllPointsToParentKey", "Icon",
					"SetMask", GetMedia("actionbutton-mask-circular"),
					"SetTexture", [=[Interface\ChatFrame\ChatFrameBackground]=],
					"SetVertexColor", { 0, 0, 0, .15 }
				}
			},
			{
				parent = "self", ownerKey = "BorderFrame", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetFrameLevelOffset", 5,
					"SetAllPointsToParent"
				}
			},
			{
				-- Note that the "Border" object already exists, 
				-- so to avoid problems related to that, 
				-- we chose to simply rename our own custom element instead.
				parent = "self,BorderFrame", ownerKey = "ButtonBorder", objectType = "Texture",
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					"SetDrawLayer", { "BORDER", 1 },
					"SetSize", { 48/(122/256), 48/(122/256) },
					"SetTexture", GetMedia("actionbutton-border"),
					"SetVertexColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 }
				}
			},
			{
				parent = "self,Overlay", ownerKey = "Glow", objectType = "Texture",
				chain = {
					"SetHidden",
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetSize", { 33/(122/256), 33/(122/256) },
					"SetPoint", { "CENTER", 0, 0 },
					"SetTexture", GetMedia("actionbutton-glow-white"),
					"SetVertexColor", { 1, 1, 1, .5 },
					"SetBlendMode", "ADD"
				}
			}					
		}
	}
})
