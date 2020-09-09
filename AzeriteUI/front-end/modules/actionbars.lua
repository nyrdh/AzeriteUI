local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Note that there's still a lot of hardcoded things in this file,
-- and they will most likely NOT be moved into the layout, 
-- as bar layouts in our UIs are very non-typical,
-- and more often than not iconic, integral elements of the design.
local L = Wheel("LibLocale"):GetLocale(ADDON)
local Module = Core:NewModule("ActionBarMain", "LibEvent", "LibMessage", "LibDB", "LibFrame", "LibSound", "LibTooltip", "LibSecureButton", "LibWidgetContainer", "LibPlayerData", "LibClientBuild")

-- Lua API
local _G = _G
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local table_remove = table.remove
local tonumber = tonumber
local tostring = tostring

-- WoW API
local FindActiveAzeriteItem = C_AzeriteItem and C_AzeriteItem.FindActiveAzeriteItem
local GetAzeriteItemXPInfo = C_AzeriteItem and C_AzeriteItem.GetAzeriteItemXPInfo
local GetPowerLevel = C_AzeriteItem and C_AzeriteItem.GetPowerLevel
local GetTotemTimeLeft = GetTotemTimeLeft
local HasOverrideActionBar = HasOverrideActionBar
local HasTempShapeshiftActionBar = HasTempShapeshiftActionBar
local HasVehicleActionBar = HasVehicleActionBar
local InCombatLockdown = InCombatLockdown
local IsMounted = IsMounted
local UnitLevel = UnitLevel
local UnitOnTaxi = UnitOnTaxi
local UnitRace = UnitRace

-- Private API
local Colors = Private.Colors
local GetConfig = Private.GetConfig
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout
local GetMedia = Private.GetMedia

-- Constants for client version
local IsClassic = Module:IsClassic()
local IsRetail = Module:IsRetail()

-- Player Class
local _,playerClass = UnitClass("player")

-- Blizzard textures for generic styling
local BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]]

-- Various string formatting for our tooltips and bars
local shortXPString = "%s%%"
local longXPString = "%s / %s"
local fullXPString = "%s / %s (%s)"
local restedString = " (%s%% %s)"
local shortLevelString = "%s %.0f"

-- Cache of buttons
local Cache = {} -- cache buttons to separate different ranks of same spell
local Buttons = {} -- all action buttons
local PetButtons = {} -- all pet buttons
local HoverButtons = {} -- all action buttons that can fade out

-- Hover frames
-- *Not related to the explorer mode.
local ActionBarHoverFrame, PetBarHoverFrame
local FadeOutHZ, FadeOutDuration = 1/20, 1/5

-- Time constants
local DAY, HOUR, MINUTE = 86400, 3600, 60

-- Is ConsolePort enabled in the addon listing?
local IsConsolePortEnabled = Module:IsAddOnEnabled("ConsolePort")

-- Track combat status
local IN_COMBAT

-- Secure Code Snippets
-- TODO: Turn these into formatstrings,
-- and fill in layout options from the layout cache
-- instead of using hardcoded values directly. 
local secureSnippets = {
	-- Arrange the main and extra actionbar buttons
	arrangeButtons = [=[

		local UICenter = self:GetFrameRef("UICenter"); 
		local extraButtonsCount = tonumber(self:GetAttribute("extraButtonsCount")) or 0;
		local buttonSize, buttonSpacing, iconSize = 64, 8, 44;
		local row2mod = 1-2/5; -- horizontal offset for upper row

		for id,button in ipairs(Buttons) do 
			local buttonID = button:GetID(); 
			local barID = Pagers[id]:GetID(); 

			-- Brave New World.
			local layoutID = button:GetAttribute("layoutID");
			if (layoutID <= 7) then
				button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((layoutID-1) * (buttonSize + buttonSpacing)), 42)
			else
				local slot = floor((layoutID - 8)/2)

				-- Bottom row
				if (layoutID%2 == 0) then

					button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((slot+7) * (buttonSize + buttonSpacing)), 42 )

				-- Top row
				else

					button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((slot+7 + row2mod) * (buttonSize + buttonSpacing)), 42 + buttonSize + buttonSpacing)
				end

			end


			if (false) then
				-- Primary Bar
				if (barID == 1) then 
					button:ClearAllPoints(); 

					if (buttonID > 10) then
						button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((buttonID-2-1 + row2mod) * (buttonSize + buttonSpacing)), 42 + buttonSize + buttonSpacing)
					else
						button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((buttonID-1) * (buttonSize + buttonSpacing)), 42)
					end 

				-- Secondary Bar
				elseif (barID == self:GetAttribute("BOTTOMLEFT_ACTIONBAR_PAGE")) then 
					button:ClearAllPoints(); 

					-- 3x2 complimentary buttons
					if (extraButtonsCount <= 11) then 
						if (buttonID < 4) then 
							button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + (((buttonID+10)-1) * (buttonSize + buttonSpacing)), 42 )
						else
							button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + (((buttonID-3+10)-1 +row2mod) * (buttonSize + buttonSpacing)), 42 + buttonSize + buttonSpacing)
						end

					-- 6x2 complimentary buttons
					else 
						if (buttonID < 7) then 
							button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + (((buttonID+10)-1) * (buttonSize + buttonSpacing)), 42 )
						else
							button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + (((buttonID-6+10)-1 +row2mod) * (buttonSize + buttonSpacing)), 42 + buttonSize + buttonSpacing)
						end
					end 
				end
			end
		end 

		-- lua callback to update the hover frame anchors to the current layout
		self:CallMethod("UpdateFadeAnchors"); 
	
	]=],

	-- Arrange the pet action bar buttons
	arrangePetButtons = [=[
		local UICenter = self:GetFrameRef("UICenter");
		local buttonSize, buttonSpacing = 64*3/4, 2;
		local startX, startY = -(buttonSize*10 + buttonSpacing*9)/2, 200;

		for id,button in ipairs(PetButtons) do
			button:ClearAllPoints();
			button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOM", startX + ((id-1) * (buttonSize + buttonSpacing)), startY);
		end

		-- lua callback to update the explorer mode anchors to the current layout
		self:CallMethod("UpdateExplorerModeAnchors"); 

	]=],

	-- Placeholder.
	arrangeSideButtons = [=[
		local UICenter = self:GetFrameRef("UICenter"); 
		local sideBar1Enabled = self:GetAttribute("sideBar1Enabled");
		local sideBar2Enabled = self:GetAttribute("sideBar2Enabled");
		local sideBar3Enabled = self:GetAttribute("sideBar3Enabled");
		local sideBarCount = (sideBar1Enabled and 1 or 0) + (sideBar2Enabled and 1 or 0) + (sideBar3Enabled and 1 or 0);
		local buttonSize, buttonSpacing, iconSize = 64, 8, 44;

		for id,button in ipairs(Buttons) do 
			local buttonID = button:GetID(); 
			local barID = Pagers[id]:GetID(); 

			-- First Side Bar
			if (barID == self:GetAttribute("RIGHT_ACTIONBAR_PAGE")) then

				if (sideBar1Enabled) then
					button:ClearAllPoints(); 

					-- 12x1
					if (sideBarCount > 1) then
						-- This is always the first when it's enabled

					-- 6x2
					else

					end
				end

			-- Second Side Bar
			elseif (barID == self:GetAttribute("LEFT_ACTIONBAR_PAGE")) then

				if (sideBar2Enabled) then
					button:ClearAllPoints(); 

					if (sideBarCount > 1) then

						-- 12x1, 2nd
						if (sideBar1Enabled) then

						-- 12x1, 1st
						else

						end

					-- 6x2, 1st
					else

					end
				end

			-- Third Side Bar
			elseif (barID == self:GetAttribute("BOTTOMRIGHT_ACTIONBAR_PAGE")) then

				if (sideBar3Enabled) then
					button:ClearAllPoints(); 

					-- 12x1, 3rd
					if (sideBarCount > 2) then

					-- 12x1, 2nd
					elseif (sideBarCount > 1) then

					-- 6x2, 1st
					else

					end
				end
			end 
		end
	]=],

	-- Saved setting changed.
	attributeChanged = [=[
		-- 'name' appears to be turned to lowercase by the restricted environment(?), 
		-- but we're doing it manually anyway, just to avoid problems. 
		if name then 
			name = string.lower(name); 
		end 

		if (name == "change-extrabuttonsvisibility") then 
			self:SetAttribute("extraButtonsVisibility", value); 
			self:CallMethod("UpdateFadeAnchors"); 
			self:CallMethod("UpdateFading"); 
		
		elseif (name == "change-petbarvisibility") then 
				self:SetAttribute("petBarVisibility", value); 
				self:CallMethod("UpdateFadeAnchors"); 
				self:CallMethod("UpdateFading"); 
	
		elseif (name == "change-extrabuttonscount") then 
			local extraButtonsCount = tonumber(value) or 0; 
			local visible = extraButtonsCount + 7; 
	
			-- Update button visibility counts
			for i = 8,24 do 
				local pager = Pagers[i]; 
				if (i > visible) then 
					if pager:IsShown() then 
						pager:Hide(); 
					end 
				else 
					if (not pager:IsShown()) then 
						pager:Show(); 
					end 
				end 
			end 

			self:SetAttribute("extraButtonsCount", extraButtonsCount); 
			self:RunAttribute("arrangeButtons"); 

			-- tell lua about it
			self:CallMethod("UpdateButtonCount"); 

		elseif (name == "change-castondown") then 
			self:SetAttribute("castOnDown", value and true or false); 
			self:CallMethod("UpdateCastOnDown"); 

		elseif (name == "change-petbarenabled") then 
			self:SetAttribute("petBarEnabled", value and true or false); 

			for i = 1,10 do
				local pager = PetPagers[i]; 
				if value then 
					if (not pager:IsShown()) then 
						pager:Show(); 
					end 
				else 
					if pager:IsShown() then 
						pager:Hide(); 
					end 
				end 
			end

			-- lua callback to update the explorer mode anchors to the current layout
			self:CallMethod("UpdateExplorerModeAnchors"); 
			self:CallMethod("UpdateFadeAnchors"); 
			self:CallMethod("UpdateFading"); 
			
		elseif (name == "change-buttonlock") then 
			self:SetAttribute("buttonLock", value and true or false); 

			-- change all button attributes
			for id, button in ipairs(Buttons) do 
				button:SetAttribute("buttonLock", value);
			end

			-- change all pet button attributes
			for id, button in ipairs(PetButtons) do 
				button:SetAttribute("buttonLock", value);
			end
		end 

	]=]
}

-- Keybind abbrevations. Do not localize these.
local ShortKey = {
	-- Keybinds (visible on the actionbuttons)
	["Alt"] = "A",
	["Left Alt"] = "LA",
	["Right Alt"] = "RA",
	["Ctrl"] = "C",
	["Left Ctrl"] = "LC",
	["Right Ctrl"] = "RC",
	["Shift"] = "S",
	["Left Shift"] = "LS",
	["Right Shift"] = "RS",
	["NumPad"] = "N", 
	["Backspace"] = "BS",
	["Button1"] = "B1",
	["Button2"] = "B2",
	["Button3"] = "B3",
	["Button4"] = "B4",
	["Button5"] = "B5",
	["Button6"] = "B6",
	["Button7"] = "B7",
	["Button8"] = "B8",
	["Button9"] = "B9",
	["Button10"] = "B10",
	["Button11"] = "B11",
	["Button12"] = "B12",
	["Button13"] = "B13",
	["Button14"] = "B14",
	["Button15"] = "B15",
	["Button16"] = "B16",
	["Button17"] = "B17",
	["Button18"] = "B18",
	["Button19"] = "B19",
	["Button20"] = "B20",
	["Button21"] = "B21",
	["Button22"] = "B22",
	["Button23"] = "B23",
	["Button24"] = "B24",
	["Button25"] = "B25",
	["Button26"] = "B26",
	["Button27"] = "B27",
	["Button28"] = "B28",
	["Button29"] = "B29",
	["Button30"] = "B30",
	["Button31"] = "B31",
	["Capslock"] = "Cp",
	["Clear"] = "Cl",
	["Delete"] = "Del",
	["End"] = "End",
	["Enter"] = "Ent",
	["Return"] = "Ret",
	["Home"] = "Hm",
	["Insert"] = "Ins",
	["Help"] = "Hlp",
	["Mouse Wheel Down"] = "WD",
	["Mouse Wheel Up"] = "WU",
	["Num Lock"] = "NL",
	["Page Down"] = "PD",
	["Page Up"] = "PU",
	["Print Screen"] = "Prt",
	["Scroll Lock"] = "SL",
	["Spacebar"] = "Sp",
	["Tab"] = "Tb",
	["Down Arrow"] = "Dn",
	["Left Arrow"] = "Lf",
	["Right Arrow"] = "Rt",
	["Up Arrow"] = "Up"
}

-- Hotkey abbreviations for better readability
local getBindingKeyText = function(key)
	if key then
		key = key:upper()
		key = key:gsub(" ", "")

		key = key:gsub("ALT%-", ShortKey["Alt"])
		key = key:gsub("CTRL%-", ShortKey["Ctrl"])
		key = key:gsub("SHIFT%-", ShortKey["Shift"])
		key = key:gsub("NUMPAD", ShortKey["NumPad"])

		key = key:gsub("PLUS", "%+")
		key = key:gsub("MINUS", "%-")
		key = key:gsub("MULTIPLY", "%*")
		key = key:gsub("DIVIDE", "%/")

		key = key:gsub("BACKSPACE", ShortKey["Backspace"])

		for i = 1,31 do
			key = key:gsub("BUTTON" .. i, ShortKey["Button" .. i])
		end

		key = key:gsub("CAPSLOCK", ShortKey["Capslock"])
		key = key:gsub("CLEAR", ShortKey["Clear"])
		key = key:gsub("DELETE", ShortKey["Delete"])
		key = key:gsub("END", ShortKey["End"])
		key = key:gsub("HOME", ShortKey["Home"])
		key = key:gsub("INSERT", ShortKey["Insert"])
		key = key:gsub("MOUSEWHEELDOWN", ShortKey["Mouse Wheel Down"])
		key = key:gsub("MOUSEWHEELUP", ShortKey["Mouse Wheel Up"])
		key = key:gsub("NUMLOCK", ShortKey["Num Lock"])
		key = key:gsub("PAGEDOWN", ShortKey["Page Down"])
		key = key:gsub("PAGEUP", ShortKey["Page Up"])
		key = key:gsub("SCROLLLOCK", ShortKey["Scroll Lock"])
		key = key:gsub("SPACEBAR", ShortKey["Spacebar"])
		key = key:gsub("TAB", ShortKey["Tab"])

		key = key:gsub("DOWNARROW", ShortKey["Down Arrow"])
		key = key:gsub("LEFTARROW", ShortKey["Left Arrow"])
		key = key:gsub("RIGHTARROW", ShortKey["Right Arrow"])
		key = key:gsub("UPARROW", ShortKey["Up Arrow"])

		return key
	end
end

-- Aimed to be compact and displayed on buttons
local formatCooldownTime = function(time)
	if (time > DAY) then -- more than a day
		time = time + DAY/2
		return "%d%s", time/DAY - time/DAY%1, "d"
	elseif (time > HOUR) then -- more than an hour
		time = time + HOUR/2
		return "%d%s", time/HOUR - time/HOUR%1, "h"
	elseif (time > MINUTE) then -- more than a minute
		time = time + MINUTE/2
		return "%d%s", time/MINUTE - time/MINUTE%1, "m"
	elseif (time > 10) then -- more than 10 seconds
		return "%d", time - time%1
	elseif (time >= 1) then -- more than 5 seconds
		return "|cffff8800%d|r", time - time%1
	elseif (time > 0) then
		return "|cffff0000%d|r", time*10 - time*10%1
	else
		return ""
	end	
end

-- ActionButton Template (Custom Methods)
----------------------------------------------------
local ActionButton = {}

ActionButton.GetBindingTextAbbreviated = function(self)
	return getBindingKeyText(self:GetBindingText())
end

ActionButton.UpdateBinding = function(self)
	local Keybind = self.Keybind
	if Keybind then 
		Keybind:SetText(self:GetBindingTextAbbreviated() or "")
	end 
end

ActionButton.UpdateMouseOver = function(self)
	if (self.isMouseOver) then 
		if (self.Darken) then 
			self.Darken:SetAlpha(self.Darken.highlight)
		end 
		if (self.Border) then 
			self.Border:SetVertexColor(Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], 1)
		end 
		if (self.Glow) then 
			self.Glow:Show()
		end 
	else 
		if self.Darken then 
			self.Darken:SetAlpha(self.Darken.normal)
		end 
		if self.Border then 
			self.Border:SetVertexColor(Colors.ui[1], Colors.ui[2], Colors.ui[3], 1)
		end 
		if self.Glow then 
			self.Glow:Hide()
		end 
	end 
end 

ActionButton.PostEnter = function(self)
	self:UpdateMouseOver()
end 

ActionButton.PostLeave = function(self)
	self:UpdateMouseOver()
end 

ActionButton.SetRankVisibility = function(self, visible)
	if (not IsClassic) then
		return
	end
	local cache = Cache[self]

	-- Show rank on self
	if (visible) then 

		-- Create rank text if needed
		if (not self.Rank) then 
			local count = self.Count
			local rank = self:CreateFontString()
			rank:SetParent(count:GetParent())
			--rank:SetFontObject(count:GetFontObject()) -- nah, this one changes based on count!
			rank:SetFontObject(Private.GetFont(14,true)) -- use the smaller font
			rank:SetDrawLayer(count:GetDrawLayer())
			rank:SetTextColor(Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3])
			rank:SetPoint(count:GetPoint())
			self.Rank = rank
		end
		self.Rank:SetText(cache.spellRank)

	-- Hide rank on self, if it exists. 
	elseif (not visible) and (self.Rank) then 
		self.Rank:SetText("")
	end 
end

ActionButton.PostUpdate = function(self)
	self:UpdateMouseOver()

	-- The following is only for classic
	if (not IsClassic) then
		return
	end

	local cache = Cache[self]
	if (not cache) then 
		Cache[self] = {}
		cache = Cache[self]
	end

	-- Retrieve the previous info, if any.
	local oldCount = cache.spellCount -- counter of the amount of multiples
	local oldName = cache.spellName -- used as identifier for multiples
	local oldRank = cache.spellRank -- rank of this instance of the multiple

	-- Update cached info 
	cache.spellRank = self:GetSpellRank()
	cache.spellName = GetSpellInfo(self:GetSpellID())

	-- Button spell changed?
	if (cache.spellName ~= oldName) then 

		-- We had a spell before, and there were more of it.
		-- We need to find the old ones, update their counts,
		-- and hide them if there's only a single one left. 
		if (oldRank and (oldCount > 1)) then 
			local newCount = oldCount - 1
			for button,otherCache in pairs(Cache) do 
				-- Ignore self, as we no longer have the same counter. 
				if (button ~= self) and (otherCache.spellName == oldName) then 
					otherCache.spellCount = newCount
					button:SetRankVisibility((newCount > 1))
				end
			end
		end 
	end 

	-- Counter for number of duplicates of the current spell
	local howMany = 0
	if (cache.spellRank) then 
		for button,otherCache in pairs(Cache) do 
			if (otherCache.spellName == cache.spellName) then 
				howMany = howMany + 1
			end 
		end
	end 

	-- Update stored counter
	cache.spellCount = howMany

	-- Update all rank texts and counters
	for button,otherCache in pairs(Cache) do 
		if (otherCache.spellName == cache.spellName) then 
			otherCache.spellCount = howMany
			button:SetRankVisibility((howMany > 1))
		end 
	end
end 

ActionButton.PostCreate = function(self, ...)
	local layout = Module.layout

	self:SetSize(unpack(layout.ButtonSize))
	self:SetHitRectInsets(unpack(layout.ButtonHitRects))

	-- Assign our own global custom colors
	self.colors = Colors

	-- Restyle the blizz layers
	-----------------------------------------------------
	self.Icon:SetSize(unpack(layout.IconSize))
	self.Icon:ClearAllPoints()
	self.Icon:SetPoint(unpack(layout.IconPlace))

	-- If SetTexture hasn't been called, the mask and probably texcoords won't stick. 
	-- This started happening in build 8.1.0.29600 (March 5th, 2019), or at least that's when I noticed.
	-- Does not appear to be related to whether GetTexture() has a return value or not. 
	self.Icon:SetTexture("") 
	self.Icon:SetMask(layout.MaskTexture)

	self.Pushed:SetDrawLayer(unpack(layout.PushedDrawLayer))
	self.Pushed:SetSize(unpack(layout.PushedSize))
	self.Pushed:ClearAllPoints()
	self.Pushed:SetPoint(unpack(layout.PushedPlace))
	self.Pushed:SetMask(layout.MaskTexture)
	self.Pushed:SetColorTexture(unpack(layout.PushedColor))
	self:SetPushedTexture(self.Pushed)
	self:GetPushedTexture():SetBlendMode(layout.PushedBlendMode)
		
	-- We need to put it back in its correct drawlayer, 
	-- or Blizzard will set it to ARTWORK which can lead 
	-- to it randomly being drawn behind the icon texture. 
	self:GetPushedTexture():SetDrawLayer(unpack(layout.PushedDrawLayer)) 

	-- Add a simpler checked texture
	if self.SetCheckedTexture then
		self.Checked = self.Checked or self:CreateTexture()
		self.Checked:SetDrawLayer(unpack(layout.CheckedDrawLayer))
		self.Checked:SetSize(unpack(layout.CheckedSize))
		self.Checked:ClearAllPoints()
		self.Checked:SetPoint(unpack(layout.CheckedPlace))
		self.Checked:SetMask(layout.MaskTexture)
		self.Checked:SetColorTexture(unpack(layout.CheckedColor))
		self:SetCheckedTexture(self.Checked)
		self:GetCheckedTexture():SetBlendMode(layout.CheckedBlendMode)
	end
	
	self.Flash:SetDrawLayer(unpack(layout.FlashDrawLayer))
	self.Flash:SetSize(unpack(layout.FlashSize))
	self.Flash:ClearAllPoints()
	self.Flash:SetPoint(unpack(layout.FlashPlace))
	self.Flash:SetTexture(layout.FlashTexture)
	self.Flash:SetVertexColor(unpack(layout.FlashColor))
	self.Flash:SetMask(layout.MaskTexture)

	self.Cooldown:SetSize(unpack(layout.CooldownSize))
	self.Cooldown:ClearAllPoints()
	self.Cooldown:SetPoint(unpack(layout.CooldownPlace))
	self.Cooldown:SetSwipeTexture(layout.CooldownSwipeTexture)
	self.Cooldown:SetSwipeColor(unpack(layout.CooldownSwipeColor))
	self.Cooldown:SetDrawSwipe(layout.ShowCooldownSwipe)
	self.Cooldown:SetBlingTexture(layout.CooldownBlingTexture, unpack(layout.CooldownBlingColor)) 
	self.Cooldown:SetDrawBling(layout.ShowCooldownBling)

	self.ChargeCooldown:SetSize(unpack(layout.ChargeCooldownSize))
	self.ChargeCooldown:ClearAllPoints()
	self.ChargeCooldown:SetPoint(unpack(layout.ChargeCooldownPlace))
	self.ChargeCooldown:SetSwipeTexture(layout.ChargeCooldownSwipeTexture, unpack(layout.ChargeCooldownSwipeColor))
	self.ChargeCooldown:SetSwipeColor(unpack(layout.ChargeCooldownSwipeColor))
	self.ChargeCooldown:SetBlingTexture(layout.ChargeCooldownBlingTexture, unpack(layout.ChargeCooldownBlingColor)) 
	self.ChargeCooldown:SetDrawSwipe(layout.ShowChargeCooldownSwipe)
	self.ChargeCooldown:SetDrawBling(layout.ShowChargeCooldownBling)

	self.CooldownCount:ClearAllPoints()
	self.CooldownCount:SetPoint(unpack(layout.CooldownCountPlace))
	self.CooldownCount:SetFontObject(layout.CooldownCountFont)
	self.CooldownCount:SetJustifyH(layout.CooldownCountJustifyH)
	self.CooldownCount:SetJustifyV(layout.CooldownCountJustifyV)
	self.CooldownCount:SetShadowOffset(unpack(layout.CooldownCountShadowOffset))
	self.CooldownCount:SetShadowColor(unpack(layout.CooldownCountShadowColor))
	self.CooldownCount:SetTextColor(unpack(layout.CooldownCountColor))

	self.Count:ClearAllPoints()
	self.Count:SetPoint(unpack(layout.CountPlace))
	self.Count:SetFontObject(layout.CountFont)
	self.Count:SetJustifyH(layout.CountJustifyH)
	self.Count:SetJustifyV(layout.CountJustifyV)
	self.Count:SetShadowOffset(unpack(layout.CountShadowOffset))
	self.Count:SetShadowColor(unpack(layout.CountShadowColor))
	self.Count:SetTextColor(unpack(layout.CountColor))

	self.maxDisplayCount = layout.CountMaxDisplayed
	self.PostUpdateCount = layout.CountPostUpdate

	self.Keybind:ClearAllPoints()
	self.Keybind:SetPoint(unpack(layout.KeybindPlace))
	self.Keybind:SetFontObject(layout.KeybindFont)
	self.Keybind:SetJustifyH(layout.KeybindJustifyH)
	self.Keybind:SetJustifyV(layout.KeybindJustifyV)
	self.Keybind:SetShadowOffset(unpack(layout.KeybindShadowOffset))
	self.Keybind:SetShadowColor(unpack(layout.KeybindShadowColor))
	self.Keybind:SetTextColor(unpack(layout.KeybindColor))

	self.SpellHighlight:ClearAllPoints()
	self.SpellHighlight:SetPoint(unpack(layout.SpellHighlightPlace))
	self.SpellHighlight:SetSize(unpack(layout.SpellHighlightSize))
	self.SpellHighlight.Texture:SetTexture(layout.SpellHighlightTexture)
	self.SpellHighlight.Texture:SetVertexColor(unpack(layout.SpellHighlightColor))

	self.SpellAutoCast:ClearAllPoints()
	self.SpellAutoCast:SetPoint(unpack(layout.SpellAutoCastPlace))
	self.SpellAutoCast:SetSize(unpack(layout.SpellAutoCastSize))
	self.SpellAutoCast.Ants:SetTexture(layout.SpellAutoCastAntsTexture)
	self.SpellAutoCast.Ants:SetVertexColor(unpack(layout.SpellAutoCastAntsColor))	
	self.SpellAutoCast.Ants.Anim:SetSpeed(layout.SpellAutoCastAntsSpeed)
	self.SpellAutoCast.Ants.Anim:SetGrid(unpack(layout.SpellAutoCastAntsGrid))
	self.SpellAutoCast.Glow:SetTexture(layout.SpellAutoCastGlowTexture)
	self.SpellAutoCast.Glow:SetVertexColor(unpack(layout.SpellAutoCastGlowColor))	
	self.SpellAutoCast.Glow.Anim:SetSpeed(layout.SpellAutoCastGlowSpeed)
	self.SpellAutoCast.Glow.Anim:SetGrid(unpack(layout.SpellAutoCastGlowGrid))

	self.Backdrop = self:CreateTexture()
	self.Backdrop:SetSize(unpack(layout.BackdropSize))
	self.Backdrop:SetPoint(unpack(layout.BackdropPlace))
	self.Backdrop:SetDrawLayer(unpack(layout.BackdropDrawLayer))
	self.Backdrop:SetTexture(layout.BackdropTexture)
	self.Backdrop:SetVertexColor(unpack(layout.BackdropColor))

	self.Darken = self:CreateTexture()
	self.Darken:SetDrawLayer("BACKGROUND", 3)
	self.Darken:SetSize(unpack(layout.IconSize))
	self.Darken:SetAllPoints(self.Icon)
	self.Darken:SetMask(layout.MaskTexture)
	self.Darken:SetTexture(BLANK_TEXTURE)
	self.Darken:SetVertexColor(0, 0, 0)
	self.Darken.highlight = 0
	self.Darken.normal = .15

	self.BorderFrame = self:CreateFrame("Frame")
	self.BorderFrame:SetFrameLevel(self:GetFrameLevel() + 5)
	self.BorderFrame:SetAllPoints(self)

	self.Border = self.BorderFrame:CreateTexture()
	self.Border:SetPoint(unpack(layout.BorderPlace))
	self.Border:SetDrawLayer(unpack(layout.BorderDrawLayer))
	self.Border:SetSize(unpack(layout.BorderSize))
	self.Border:SetTexture(layout.BorderTexture)
	self.Border:SetVertexColor(unpack(layout.BorderColor))

	self.Glow = self.Overlay:CreateTexture()
	self.Glow:SetDrawLayer(unpack(layout.GlowDrawLayer))
	self.Glow:SetSize(unpack(layout.GlowSize))
	self.Glow:SetPoint(unpack(layout.GlowPlace))
	self.Glow:SetTexture(layout.GlowTexture)
	self.Glow:SetVertexColor(unpack(layout.GlowColor))
	self.Glow:SetBlendMode(layout.GlowBlendMode)
	self.Glow:Hide()
end 

ActionButton.PostUpdateCooldown = function(self, cooldown)
	local layout = Module.layout
	cooldown:SetSwipeColor(unpack(layout.CooldownSwipeColor))
end 

ActionButton.PostUpdateChargeCooldown = function(self, cooldown)
	local layout = Module.layout
	cooldown:SetSwipeColor(unpack(layout.ChargeCooldownSwipeColor))
end

-- PetButton Template (Custom Methods)
----------------------------------------------------
local PetButton = {}

PetButton.PostCreate = function(self, ...)
	local layout = Module.layout

	self:SetSize(unpack(layout.PetButtonSize))
	self:SetHitRectInsets(unpack(layout.PetButtonHitRects))

	-- Assign our own global custom colors
	self.colors = Colors

	-- Restyle the blizz layers
	-----------------------------------------------------
	self.Icon:SetSize(unpack(layout.PetIconSize))
	self.Icon:ClearAllPoints()
	self.Icon:SetPoint(unpack(layout.PetIconPlace))

	-- If SetTexture hasn't been called, the mask and probably texcoords won't stick. 
	-- This started happening in build 8.1.0.29600 (March 5th, 2019), or at least that's when I noticed.
	-- Does not appear to be related to whether GetTexture() has a return value or not. 
	self.Icon:SetTexture("") 
	self.Icon:SetMask(layout.PetMaskTexture)

	self.Pushed:SetDrawLayer(unpack(layout.PetPushedDrawLayer))
	self.Pushed:SetSize(unpack(layout.PetPushedSize))
	self.Pushed:ClearAllPoints()
	self.Pushed:SetPoint(unpack(layout.PetPushedPlace))
	self.Pushed:SetMask(layout.PetMaskTexture)
	self.Pushed:SetColorTexture(unpack(layout.PetPushedColor))
	self:SetPushedTexture(self.Pushed)
	self:GetPushedTexture():SetBlendMode(layout.PetPushedBlendMode)
		
	-- We need to put it back in its correct drawlayer, 
	-- or Blizzard will set it to ARTWORK which can lead 
	-- to it randomly being drawn behind the icon texture. 
	self:GetPushedTexture():SetDrawLayer(unpack(layout.PetPushedDrawLayer)) 

	self.Checked = self:CreateTexture()
	self.Checked:SetDrawLayer(unpack(layout.PetCheckedDrawLayer))
	self.Checked:SetSize(unpack(layout.PetCheckedSize))
	self.Checked:ClearAllPoints()
	self.Checked:SetPoint(unpack(layout.PetCheckedPlace))
	self.Checked:SetTexture(layout.PetMaskTexture)
	self.Checked:SetVertexColor(unpack(layout.PetCheckedColor))
	self.Checked:SetBlendMode(layout.PetCheckedBlendMode)
	self:SetCheckedTexture(self.Checked)
	self:GetCheckedTexture():SetBlendMode(layout.PetCheckedBlendMode)

	self.Flash:SetDrawLayer(unpack(layout.PetFlashDrawLayer))
	self.Flash:SetSize(unpack(layout.PetFlashSize))
	self.Flash:ClearAllPoints()
	self.Flash:SetPoint(unpack(layout.PetFlashPlace))
	self.Flash:SetTexture(layout.PetFlashTexture)
	self.Flash:SetVertexColor(unpack(layout.PetFlashColor))
	self.Flash:SetMask(layout.PetMaskTexture)

	self.Cooldown:SetSize(unpack(layout.PetCooldownSize))
	self.Cooldown:ClearAllPoints()
	self.Cooldown:SetPoint(unpack(layout.PetCooldownPlace))
	self.Cooldown:SetSwipeTexture(layout.PetCooldownSwipeTexture)
	self.Cooldown:SetSwipeColor(unpack(layout.PetCooldownSwipeColor))
	self.Cooldown:SetDrawSwipe(layout.PetShowCooldownSwipe)
	self.Cooldown:SetBlingTexture(layout.PetCooldownBlingTexture, unpack(layout.PetCooldownBlingColor)) 
	self.Cooldown:SetDrawBling(layout.PetShowCooldownBling)

	self.ChargeCooldown:SetSize(unpack(layout.PetChargeCooldownSize))
	self.ChargeCooldown:ClearAllPoints()
	self.ChargeCooldown:SetPoint(unpack(layout.PetChargeCooldownPlace))
	self.ChargeCooldown:SetSwipeTexture(layout.PetChargeCooldownSwipeTexture, unpack(layout.PetChargeCooldownSwipeColor))
	self.ChargeCooldown:SetSwipeColor(unpack(layout.PetChargeCooldownSwipeColor))
	self.ChargeCooldown:SetBlingTexture(layout.PetChargeCooldownBlingTexture, unpack(layout.PetChargeCooldownBlingColor)) 
	self.ChargeCooldown:SetDrawSwipe(layout.PetShowChargeCooldownSwipe)
	self.ChargeCooldown:SetDrawBling(layout.PetShowChargeCooldownBling)

	self.CooldownCount:ClearAllPoints()
	self.CooldownCount:SetPoint(unpack(layout.PetCooldownCountPlace))
	self.CooldownCount:SetFontObject(layout.PetCooldownCountFont)
	self.CooldownCount:SetJustifyH(layout.PetCooldownCountJustifyH)
	self.CooldownCount:SetJustifyV(layout.PetCooldownCountJustifyV)
	self.CooldownCount:SetShadowOffset(unpack(layout.PetCooldownCountShadowOffset))
	self.CooldownCount:SetShadowColor(unpack(layout.PetCooldownCountShadowColor))
	self.CooldownCount:SetTextColor(unpack(layout.PetCooldownCountColor))

	self.Count:ClearAllPoints()
	self.Count:SetPoint(unpack(layout.PetCountPlace))
	self.Count:SetFontObject(layout.PetCountFont)
	self.Count:SetJustifyH(layout.PetCountJustifyH)
	self.Count:SetJustifyV(layout.PetCountJustifyV)
	self.Count:SetShadowOffset(unpack(layout.PetCountShadowOffset))
	self.Count:SetShadowColor(unpack(layout.PetCountShadowColor))
	self.Count:SetTextColor(unpack(layout.PetCountColor))

	self.Keybind:ClearAllPoints()
	self.Keybind:SetPoint(unpack(layout.PetKeybindPlace))
	self.Keybind:SetFontObject(layout.PetKeybindFont)
	self.Keybind:SetJustifyH(layout.PetKeybindJustifyH)
	self.Keybind:SetJustifyV(layout.PetKeybindJustifyV)
	self.Keybind:SetShadowOffset(unpack(layout.PetKeybindShadowOffset))
	self.Keybind:SetShadowColor(unpack(layout.PetKeybindShadowColor))
	self.Keybind:SetTextColor(unpack(layout.PetKeybindColor))

	self.SpellAutoCast:ClearAllPoints()
	self.SpellAutoCast:SetPoint(unpack(layout.PetSpellAutoCastPlace))
	self.SpellAutoCast:SetSize(unpack(layout.PetSpellAutoCastSize))
	self.SpellAutoCast.Ants:SetTexture(layout.PetSpellAutoCastAntsTexture)
	self.SpellAutoCast.Ants:SetVertexColor(unpack(layout.PetSpellAutoCastAntsColor))
	self.SpellAutoCast.Ants.Anim:SetSpeed(layout.PetSpellAutoCastAntsSpeed)
	self.SpellAutoCast.Ants.Anim:SetGrid(unpack(layout.PetSpellAutoCastAntsGrid))
	self.SpellAutoCast.Glow:SetTexture(layout.PetSpellAutoCastGlowTexture)
	self.SpellAutoCast.Glow:SetVertexColor(unpack(layout.PetSpellAutoCastGlowColor))
	self.SpellAutoCast.Glow.Anim:SetSpeed(layout.PetSpellAutoCastGlowSpeed)
	self.SpellAutoCast.Glow.Anim:SetGrid(unpack(layout.PetSpellAutoCastGlowGrid))

	self.Backdrop = self:CreateTexture()
	self.Backdrop:SetSize(unpack(layout.PetBackdropSize))
	self.Backdrop:SetPoint(unpack(layout.PetBackdropPlace))
	self.Backdrop:SetDrawLayer(unpack(layout.PetBackdropDrawLayer))
	self.Backdrop:SetTexture(layout.PetBackdropTexture)
	self.Backdrop:SetVertexColor(unpack(layout.PetBackdropColor))

	self.Darken = self:CreateTexture()
	self.Darken:SetDrawLayer("BACKGROUND", 3)
	self.Darken:SetSize(unpack(layout.PetIconSize))
	self.Darken:SetAllPoints(self.Icon)
	self.Darken:SetMask(layout.PetMaskTexture)
	self.Darken:SetTexture(BLANK_TEXTURE)
	self.Darken:SetVertexColor(0, 0, 0)
	self.Darken.highlight = 0
	self.Darken.normal = .15

	self.BorderFrame = self:CreateFrame("Frame")
	self.BorderFrame:SetFrameLevel(self:GetFrameLevel() + 5)
	self.BorderFrame:SetAllPoints(self)

	self.Border = self.BorderFrame:CreateTexture()
	self.Border:SetPoint(unpack(layout.PetBorderPlace))
	self.Border:SetDrawLayer(unpack(layout.PetBorderDrawLayer))
	self.Border:SetSize(unpack(layout.PetBorderSize))
	self.Border:SetTexture(layout.PetBorderTexture)
	self.Border:SetVertexColor(unpack(layout.PetBorderColor))

	self.Glow = self.Overlay:CreateTexture()
	self.Glow:SetDrawLayer(unpack(layout.PetGlowDrawLayer))
	self.Glow:SetSize(unpack(layout.PetGlowSize))
	self.Glow:SetPoint(unpack(layout.PetGlowPlace))
	self.Glow:SetTexture(layout.PetGlowTexture)
	self.Glow:SetVertexColor(unpack(layout.PetGlowColor))
	self.Glow:SetBlendMode(layout.PetGlowBlendMode)
	self.Glow:Hide()
end 

PetButton.PostUpdate = function(self)
	self:UpdateMouseOver()
end

PetButton.GetBindingTextAbbreviated = ActionButton.GetBindingTextAbbreviated
PetButton.UpdateBinding = ActionButton.UpdateBinding
PetButton.UpdateMouseOver = ActionButton.UpdateMouseOver
PetButton.PostEnter = ActionButton.PostEnter
PetButton.PostLeave = ActionButton.PostLeave

-- Bar Creation
----------------------------------------------------
Module.SpawnActionBars = function(self)
	local db = self.db
	local proxy = self:GetSecureUpdater()

	-- Private test mode to show all
	local FORCED = false 

	local buttonID = 0 -- current buttonID when spawning
	local numPrimary = 7 -- Number of primary buttons always visible
	local firstHiddenID = db.extraButtonsCount + numPrimary -- first buttonID to be hidden
	
	-- Primary Action Bar
	for id = 1,NUM_ACTIONBAR_BUTTONS do 
		buttonID = buttonID + 1
		Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton, 1, id)
		HoverButtons[Buttons[buttonID]] = buttonID > numPrimary
	end 

	-- Secondary Action Bar (Bottom Left)
	for id = 1,NUM_ACTIONBAR_BUTTONS do 
		buttonID = buttonID + 1
		Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton, BOTTOMLEFT_ACTIONBAR_PAGE, id)
		HoverButtons[Buttons[buttonID]] = true
	end 

	-- Layout helper
	for buttonID,button in pairs(Buttons) do
		button:SetAttribute("layoutID",buttonID)
	end
	
	-- First Side Bar (Bottom Right)
	if (false) then
		for id = 1,NUM_ACTIONBAR_BUTTONS do 
			buttonID = buttonID + 1
			Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton, BOTTOMRIGHT_ACTIONBAR_PAGE, id)
		end

		-- Second Side bar (Right)
		for id = 1,NUM_ACTIONBAR_BUTTONS do 
			buttonID = buttonID + 1
			Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton, RIGHT_ACTIONBAR_PAGE, id)
		end

		-- Third Side Bar (Left)
		for id = 1,NUM_ACTIONBAR_BUTTONS do 
			buttonID = buttonID + 1
			Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton, LEFT_ACTIONBAR_PAGE, id)
		end
	end

	-- Apply common settings to the action buttons.
	for buttonID,button in ipairs(Buttons) do 
	
		-- Apply saved buttonLock setting
		button:SetAttribute("buttonLock", db.buttonLock)

		-- Link the buttons and their pagers 
		proxy:SetFrameRef("Button"..buttonID, Buttons[buttonID])
		proxy:SetFrameRef("Pager"..buttonID, Buttons[buttonID]:GetPager())

		-- Reference all buttons in our menu callback frame
		proxy:Execute(([=[
			table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
			table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
		]=]):format(buttonID, buttonID))

		-- Hide buttons beyond our current maximum visible
		if (HoverButtons[button] and (buttonID > firstHiddenID)) then 
			button:GetPager():Hide()
		end 
	end 
end

Module.SpawnPetBar = function(self)
	local db = self.db
	local proxy = self:GetSecureUpdater()
	
	-- Spawn the Pet Bar
	for id = 1,NUM_PET_ACTION_SLOTS do
		PetButtons[id] = self:SpawnActionButton("pet", self.frame, PetButton, nil, id)
	end

	-- Apply common stuff to the pet buttons
	for id,button in pairs(PetButtons) do
		-- Apply saved buttonLock setting
		button:SetAttribute("buttonLock", db.buttonLock)

		-- Link the buttons and their pagers 
		proxy:SetFrameRef("PetButton"..id, PetButtons[id])
		proxy:SetFrameRef("PetPager"..id, PetButtons[id]:GetPager())

		if (not db.petBarEnabled) then
			PetButtons[id]:GetPager():Hide()
		end
		
		-- Reference all buttons in our menu callback frame
		proxy:Execute(([=[
			table.insert(PetButtons, self:GetFrameRef("PetButton"..%.0f)); 
			table.insert(PetPagers, self:GetFrameRef("PetPager"..%.0f)); 
		]=]):format(id, id))
		
	end
end

Module.SpawnStanceBar = function(self)
end

-- Hardcoded stuff here. Work in progress.
Module.SpawnTotemBar = function(self)
	local db = self.db

	-- Restrictions:
	-- 	Can't reposition or reparent in combat
	-- 	Can't remove button methods like SetPoint to prevent blizzard repositioning
	-- 	Can't really mess with PetFrame hide/show either, it needs to remain whatever Blizzard intended.

	local totemScale = 1.5 
	local width, height = 37*4 + (-4)*3, 37 -- (136*37) size of the totem buttons, plus space between them

	-- Just for my own reference:
	-- 	player castbar "BOTTOM", "UICenter", "BOTTOM", 0, 290
	-- 	player altpower "BOTTOM", "UICenter", "BOTTOM", 0, 340 ("CENTER", "UICenter", "CENTER", 0, -189)
	local totemHolderFrame = self:CreateFrame("Frame", nil, "UICenter")
	totemHolderFrame:SetSize(2,2)
	totemHolderFrame:Place("BOTTOM", self:GetFrame("Minimap"), "TOP", 0, 60)
	--totemHolderFrame:Place("BOTTOM", "UICenter", "BOTTOM", 0, 390)
	
	-- Scaling it up get a more fitting size,
	-- without messing with actual relative
	-- positioning of the buttons.
	local totemFrame = TotemFrame -- original size is 128x53
	totemFrame:SetParent(totemHolderFrame)
	totemFrame:SetScale(totemScale)
	totemFrame:SetSize(width, height)
	

	local hidden = CreateFrame("Frame")
	hidden:Hide()

	for i = 1,4 do -- MAX_TOTEMS = 4
		local buttonName = "TotemFrameTotem"..i
		local button = _G[buttonName]
		local buttonBackground = _G[buttonName.."Background"]
		local buttonIcon = _G[buttonName.."IconTexture"] -- doesn't support SetMask
		local buttonDuration = _G[buttonName.."Duration"]
		local buttonCooldown = _G[buttonName.."IconCooldown"] -- doesn't support SetMask

		buttonBackground:SetParent(hidden)
		buttonDuration:SetParent(hidden)
		buttonCooldown:SetReverse(false)
		
		local borderFrame, borderTexture
		for i = 1, button:GetNumChildren() do
			local child = select(i, button:GetChildren())
			if (child:GetObjectType() == "Frame") and (not child:GetName()) then
				for j = 1, child:GetNumRegions() do
					local region = select(j, child:GetRegions())
					if (region:GetObjectType() == "Texture") and (region:GetTexture() == [=[Interface\CharacterFrame\TotemBorder]=]) then
						region:ClearAllPoints()
						region:SetPoint("CENTER", 0, 0)
						region:SetTexture(GetMedia("actionbutton-border"))
						region:SetSize(256*.25,256*.25)
						borderFrame = child
						borderTexture = region
						break
					end
				end
			end
			if (borderFrame and borderTexture) then
				break
			end
		end
		button.borderFrame = borderFrame
		button.borderTexture = borderTexture

		local duration = borderFrame:CreateFontString()
		duration:SetDrawLayer("OVERLAY")
		duration:SetPoint("CENTER", button, "BOTTOMRIGHT", -8, 10)
		duration:SetFontObject(GetFont(9,true))
		duration:SetAlpha(.75)

		button.duration = duration
	end

	local totemButtonOnUpdate = function(button, elapsed)
		button.duration:SetFormattedText(formatCooldownTime(GetTotemTimeLeft(button.slot)))
	end

	local totemButtonUpdate = function(button, startTime, duration, icon)
		if (duration > 0) then
			button:SetScript("OnUpdate", totemButtonOnUpdate)
		else
			button:SetScript("OnUpdate", nil)
		end
	end
	hooksecurefunc("TotemButton_Update", totemButtonUpdate)

	local totemUpdate
	totemUpdate = function(self, event, ...)
		if (InCombatLockdown()) then
			self:RegisterEvent("PLAYER_REGEN_ENABLED", totemUpdate)
			return
		end
		if (event == "PLAYER_REGEN_ENABLED") then
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", totemUpdate)
		end
		local point, anchor = totemFrame:GetPoint()
		if (anchor ~= totemHolderFrame) then
			totemFrame:ClearAllPoints()
			totemFrame:SetPoint("CENTER", totemHolderFrame, "CENTER", 0, 0)
		end
	end
	hooksecurefunc(TotemFrame, "SetPoint", totemUpdate)

	-- Initial update to position it
	totemUpdate()
end

Module.SpawnExitButton = function(self)
	local layout = self.layout

	local button = self:CreateFrame("Button", nil, "UICenter", "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(100)
	button:Place(unpack(layout.ExitButtonPlace))
	button:SetSize(unpack(layout.ExitButtonSize))
	button:SetAttribute("type", "macro")

	if (IsClassic) then
		button:SetAttribute("macrotext", "/dismount [mounted]")
	elseif (IsRetail) then
		button:SetAttribute("macrotext", "/leavevehicle [target=vehicle,exists,canexitvehicle]\n/dismount [mounted]")
	end

	-- Put our texture on the button
	button.texture = button:CreateTexture()
	button.texture:SetSize(unpack(layout.ExitButtonTextureSize))
	button.texture:SetPoint(unpack(layout.ExitButtonTexturePlace))
	button.texture:SetTexture(layout.ExitButtonTexturePath)

	button:SetScript("OnEnter", function(button)
		local tooltip = self:GetActionButtonTooltip()
		tooltip:Hide()
		tooltip:SetDefaultAnchor(button)

		if UnitOnTaxi("player") then 
			tooltip:AddLine(TAXI_CANCEL)
			tooltip:AddLine(TAXI_CANCEL_DESCRIPTION, Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
		elseif IsMounted() then 
			tooltip:AddLine(BINDING_NAME_DISMOUNT)
			tooltip:AddLine(L["%s to dismount."]:format(L["<Left-Click>"]), Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
		else
			tooltip:AddLine(LEAVE_VEHICLE)
			tooltip:AddLine(L["%s to leave the vehicle."]:format(L["<Left-Click>"]), Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
		end 

		tooltip:Show()
	end)

	button:SetScript("OnLeave", function(button) 
		local tooltip = self:GetActionButtonTooltip()
		tooltip:Hide()
	end)

	-- Gotta do this the unsecure way, no macros exist for this yet. 
	button:HookScript("OnClick", function(self, button) 
		if (UnitOnTaxi("player") and (not InCombatLockdown())) then
			TaxiRequestEarlyLanding()
		end
	end)

	-- Register a visibility driver
	if (IsClassic) then
		RegisterAttributeDriver(button, "state-visibility", "[mounted]show;hide")
	elseif (IsRetail) then
		RegisterAttributeDriver(button, "state-visibility", "[target=vehicle,exists,canexitvehicle][mounted]show;hide")
	end

	self.VehicleExitButton = button
end

-- Getters
----------------------------------------------------
-- Return an iterator for actionbar buttons
Module.GetButtons = function(self)
	return pairs(Buttons)
end

-- Return an iterator for pet actionbar buttons
Module.GetPetButtons = function(self)
	return pairs(PetButtons)
end

-- Return the frames for the explorer mode mouseover
Module.GetExplorerModeFrameAnchors = function(self)
	return self:GetOverlayFrame(), self:GetOverlayFramePet()
end

-- Return the actionbar frame for the explorer mode mouseover
Module.GetOverlayFrame = function(self)
	return self.frameOverlay
end

-- Return the pet actionbar frame for the explorer mode mouseover
Module.GetOverlayFramePet = function(self)
	return self.frameOverlayPet
end

-- Return the frame for actionbutton mouseover fading
Module.GetFadeFrame = function(self)
	if (not ActionBarHoverFrame) then 
		ActionBarHoverFrame = self:CreateFrame("Frame")
		ActionBarHoverFrame.timeLeft = 0
		ActionBarHoverFrame.elapsed = 0
		ActionBarHoverFrame:SetScript("OnUpdate", function(self, elapsed) 
			self.elapsed = self.elapsed + elapsed
			self.timeLeft = self.timeLeft - elapsed
	
			if (self.timeLeft <= 0) then
				if FORCED or self.FORCED or self.always or (self.incombat and IN_COMBAT) or self.forced or self.flyout or self:IsMouseOver(0,0,0,0) then
					if (not self.isMouseOver) then 
						self.isMouseOver = true
						self.alpha = 1
						for id = 8,24 do 
							Buttons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end 
				else 
					if (self.isMouseOver) then 
						self.isMouseOver = nil
						if (not self.fadeOutTime) then 
							self.fadeOutTime = FadeOutDuration
						end 
					end 
					if (self.fadeOutTime) then 
						self.fadeOutTime = self.fadeOutTime - self.elapsed
						if (self.fadeOutTime > 0) then 
							self.alpha = self.fadeOutTime / FadeOutDuration
						else 
							self.alpha = 0
							self.fadeOutTime = nil
						end 
						for id = 8,24 do 
							Buttons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end 
				end 
				self.elapsed = 0
				self.timeLeft = FadeOutHZ
			end 
		end) 

		local actionBarGrid, petBarGrid, buttonLock
		ActionBarHoverFrame:SetScript("OnEvent", function(self, event, ...) 
			if (event == "ACTIONBAR_SHOWGRID") then 
				actionBarGrid = true
			elseif (event == "ACTIONBAR_HIDEGRID") then 
				actionBarGrid = nil
			elseif (event == "PET_BAR_SHOWGRID") then 
				petBarGrid = true
			elseif (event == "PET_BAR_HIDEGRID") then 
				petBarGrid = nil
			elseif (event == "buttonLock") then
				actionBarGrid = nil
				petBarGrid = nil
			end
			if (actionBarGrid or petBarGrid) then
				self.forced = true
			else
				self.forced = nil
			end 
		end)

		hooksecurefunc("ActionButton_UpdateFlyout", function(self) 
			if (HoverButtons[self]) then 
				ActionBarHoverFrame.flyout = self:IsFlyoutShown()
			end
		end)

		ActionBarHoverFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
		ActionBarHoverFrame:RegisterEvent("ACTIONBAR_SHOWGRID")

		if (IsRetail) then
			ActionBarHoverFrame:RegisterEvent("PET_BAR_HIDEGRID")
			ActionBarHoverFrame:RegisterEvent("PET_BAR_SHOWGRID")
		end

		ActionBarHoverFrame.isMouseOver = true -- Set this to initiate the first fade-out
	end
	return ActionBarHoverFrame
end

-- Return the frame for pet actionbutton mouseover fading
Module.GetFadeFramePet = function(self)
	if (not PetBarHoverFrame) then
		PetBarHoverFrame = self:CreateFrame("Frame")
		PetBarHoverFrame.timeLeft = 0
		PetBarHoverFrame.elapsed = 0
		PetBarHoverFrame:SetScript("OnUpdate", function(self, elapsed) 
			self.elapsed = self.elapsed + elapsed
			self.timeLeft = self.timeLeft - elapsed
	
			if (self.timeLeft <= 0) then
				if FORCED or self.FORCED or self.always or (self.incombat and IN_COMBAT) or self.forced or self.flyout or self:IsMouseOver(0,0,0,0) then
					if (not self.isMouseOver) then 
						self.isMouseOver = true
						self.alpha = 1
						for id in pairs(PetButtons) do
							PetButtons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end
				else 
					if (self.isMouseOver) then 
						self.isMouseOver = nil
						if (not self.fadeOutTime) then 
							self.fadeOutTime = FadeOutDuration
						end 
					end 
					if (self.fadeOutTime) then 
						self.fadeOutTime = self.fadeOutTime - self.elapsed
						if (self.fadeOutTime > 0) then 
							self.alpha = self.fadeOutTime / FadeOutDuration
						else 
							self.alpha = 0
							self.fadeOutTime = nil
						end 
						for id in pairs(PetButtons) do
							PetButtons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end 
				end 
				self.elapsed = 0
				self.timeLeft = FadeOutHZ
			end 
		end) 

		PetBarHoverFrame:SetScript("OnEvent", function(self, event, ...) 
			if (event == "PET_BAR_SHOWGRID") then 
				self.forced = true
			elseif (event == "PET_BAR_HIDEGRID") or (event == "buttonLock") then
				self.forced = nil
			end 
		end)


		PetBarHoverFrame:RegisterEvent("PET_BAR_SHOWGRID")
		PetBarHoverFrame:RegisterEvent("PET_BAR_HIDEGRID")
		PetBarHoverFrame.isMouseOver = true -- Set this to initiate the first fade-out
	end
	return PetBarHoverFrame
end

-- Create or return the secure frame for the menu.
Module.GetSecureUpdater = function(self)
	if (not self.proxyUpdater) then
		-- Secure frame used by the menu system to interact with our secure buttons.
		local proxy = self:CreateFrame("Frame", nil, parent, "SecureHandlerAttributeTemplate")

		-- Add some module methods to the proxy.
		for _,method in pairs({
			"UpdateCastOnDown",
			"UpdateFading",
			"UpdateFadeAnchors",
			"UpdateExplorerModeAnchors",
			"UpdateButtonCount"
		}) do
			proxy[method] = function() self[method](self) end
		end
	
		-- Copy all saved settings to our secure proxy frame.
		for key,value in pairs(self.db) do 
			proxy:SetAttribute(key,value)
		end 
	
		-- Create tables to hold the buttons
		-- within the restricted environment.
		proxy:Execute([=[ 
			Buttons = table.new();
			Pagers = table.new();
			PetButtons = table.new();
			PetPagers = table.new();
			StanceButtons = table.new();
		]=])
	
		-- Apply references and attributes used for updates.
		proxy:SetFrameRef("UICenter", self:GetFrame("UICenter"))
		proxy:SetAttribute("BOTTOMLEFT_ACTIONBAR_PAGE", BOTTOMLEFT_ACTIONBAR_PAGE)
		proxy:SetAttribute("BOTTOMRIGHT_ACTIONBAR_PAGE", BOTTOMRIGHT_ACTIONBAR_PAGE)
		proxy:SetAttribute("RIGHT_ACTIONBAR_PAGE", RIGHT_ACTIONBAR_PAGE)
		proxy:SetAttribute("LEFT_ACTIONBAR_PAGE", LEFT_ACTIONBAR_PAGE)
		proxy:SetAttribute("arrangeButtons", secureSnippets.arrangeButtons)
		proxy:SetAttribute("arrangePetButtons", secureSnippets.arrangePetButtons)
		proxy:SetAttribute("_onattributechanged", secureSnippets.attributeChanged)
	
		-- Reference it for later use
		self.proxyUpdater = proxy
	end
	return self.proxyUpdater
end

-- Setters
----------------------------------------------------
Module.SetForcedVisibility = function(self, force)
	local actionBarHoverFrame = self:GetFadeFrame()
	actionBarHoverFrame.FORCED = force and true
end

-- Updates
----------------------------------------------------
Module.UpdateFading = function(self)
	local db = self.db

	-- Set action bar hover settings
	local actionBarHoverFrame = self:GetFadeFrame()
	actionBarHoverFrame.incombat = db.extraButtonsVisibility == "combat"
	actionBarHoverFrame.always = db.extraButtonsVisibility == "always"

	-- We're hardcoding these until options can be added
	local petBarHoverFrame = self:GetFadeFramePet()
	petBarHoverFrame.incombat = db.petBarVisibility == "combat"
	petBarHoverFrame.always = db.petBarVisibility == "always"
end 

Module.UpdateExplorerModeAnchors = function(self)
	local db = self.db
	local frame = self:GetOverlayFramePet()
	if (self.db.petBarEnabled) and (UnitExists("pet")) then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", PetButtons[1], "TOPLEFT")
		frame:SetPoint("BOTTOMRIGHT", PetButtons[10], "BOTTOMRIGHT")
	else
		frame:ClearAllPoints()
		frame:SetAllPoints(self:GetFrame())
	end
end

Module.UpdateFadeAnchors = function(self)
	local db = self.db

	-- Parse buttons for hoverbutton IDs
	local first, last, left, right, top, bottom, mLeft, mRight, mTop, mBottom
	for id,button in ipairs(Buttons) do 
		-- If we pass number of visible hoverbuttons, just bail out
		if (id > db.extraButtonsCount + 7) then 
			break 
		end 

		local bLeft = button:GetLeft()
		local bRight = button:GetRight()
		local bTop = button:GetTop()
		local bBottom = button:GetBottom()
		
		if HoverButtons[button] then 
			-- Only counting the first encountered as the first
			if (not first) then 
				first = id 
			end 

			-- Counting every button as the last, until we actually reach it 
			last = id 

			-- Figure out hoverframe anchor buttons
			left = left and (Buttons[left]:GetLeft() < bLeft) and left or id
			right = right and (Buttons[right]:GetRight() > bRight) and right or id
			top = top and (Buttons[top]:GetTop() > bTop) and top or id
			bottom = bottom and (Buttons[bottom]:GetBottom() < bBottom) and bottom or id
		end 

		-- Figure out main frame anchor buttons, 
		-- as we need this for the explorer mode fade anchors!
		mLeft = mLeft and (Buttons[mLeft]:GetLeft() < bLeft) and mLeft or id
		mRight = mRight and (Buttons[mRight]:GetRight() > bRight) and mRight or id
		mTop = mTop and (Buttons[mTop]:GetTop() > bTop) and mTop or id
		mBottom = mBottom and (Buttons[mBottom]:GetBottom() < bBottom) and mBottom or id
	end 

	-- Setup main frame anchors for explorer mode! 
	local overlayFrame = self:GetOverlayFrame()
	overlayFrame:ClearAllPoints()
	overlayFrame:SetPoint("TOP", Buttons[mTop], "TOP", 0, 0)
	overlayFrame:SetPoint("BOTTOM", Buttons[mBottom], "BOTTOM", 0, 0)
	overlayFrame:SetPoint("LEFT", Buttons[mLeft], "LEFT", 0, 0)
	overlayFrame:SetPoint("RIGHT", Buttons[mRight], "RIGHT", 0, 0)

	-- If we have hoverbuttons, setup the anchors
	if (left and right and top and bottom) then 
		local actionBarHoverFrame = self:GetFadeFrame()
		actionBarHoverFrame:ClearAllPoints()
		actionBarHoverFrame:SetPoint("TOP", Buttons[top], "TOP", 0, 0)
		actionBarHoverFrame:SetPoint("BOTTOM", Buttons[bottom], "BOTTOM", 0, 0)
		actionBarHoverFrame:SetPoint("LEFT", Buttons[left], "LEFT", 0, 0)
		actionBarHoverFrame:SetPoint("RIGHT", Buttons[right], "RIGHT", 0, 0)
	end

	local petBarHoverFrame = self:GetFadeFramePet()
	if (self.db.petBarEnabled) then
		petBarHoverFrame:ClearAllPoints()
		petBarHoverFrame:SetPoint("TOPLEFT", PetButtons[1], "TOPLEFT")
		petBarHoverFrame:SetPoint("BOTTOMRIGHT", PetButtons[10], "BOTTOMRIGHT")
	else
		petBarHoverFrame:ClearAllPoints()
		petBarHoverFrame:SetAllPoints(self:GetFrame())
	end

	self:UpdateButtonGrids()
end

Module.UpdateButtonCount = function(self)
	-- Update our smart button grids
	self:UpdateButtonGrids()

	-- Announce the updated button count to the world
	self:SendMessage("GP_UPDATE_ACTIONBUTTON_COUNT")
end

Module.UpdateButtonGrids = function(self)
	local db = self.db 
	local numButtons = db.extraButtonsCount + 7
	local button, buttonHasContent, forceGrid

	if (IsRetail) then
		-- Completely hide grids in vehicles and event driven bars
		if (HasOverrideActionBar() or HasTempShapeshiftActionBar() or HasVehicleActionBar()) then
			for buttonID = numButtons,1,-1 do
				button = Buttons[buttonID]
				button.showGrid = nil
				button.overrideAlphaWhenEmpty = nil
				button:UpdateGrid()
			end
			return
		end
	end

	local gapStartTop, gapStartBottom
	local gapCountTop, gapCountBottom = 0, 0
	local buttonID = 1
	while (buttonID <= numButtons) do

		local onMain = (buttonID <= 7)
		local onBottom = (buttonID <= 24) and ((onMain) or (buttonID%2 == 0))
		local onTop = (buttonID <= 24) and ((not onMain) and (buttonID%2 > 0))

		button = Buttons[buttonID]
		button.showGrid = nil
		button.overrideAlphaWhenEmpty = nil

		if (button:HasContent()) then
			
			if (onBottom) then
				if (gapStartBottom) and (gapStartBottom > 1) then
					if (gapCountBottom == 1) then
						for id = gapStartBottom,gapStartBottom+gapCountBottom-1,2 do
							button = Buttons[id]
							button.showGrid = true
							button.overrideAlphaWhenEmpty = .95
						end
					end
				end
				gapStartBottom = nil
				gapCountBottom = 0

			elseif (onTop) then
				if (gapStartTop) and (gapStartTop > 9) then
					if (gapCountTop == 1) then
						for id = gapStartTop,gapStartTop+gapCountTop-1,2 do
							button = Buttons[id]
							button.showGrid = true
							button.overrideAlphaWhenEmpty = .95
						end
					end
				end
				gapStartTop = nil
				gapCountTop = 0
			end

		else

			-- We are on bottom row
			if (onBottom) then
				if (not gapStartBottom) then
					gapStartBottom = buttonID
				end
				gapCountBottom = gapCountBottom + 1

			-- We are on top Row
			else
				if (not gapStartTop) then
					gapStartTop = buttonID
				end
				gapCountTop = gapCountTop + 1
			end
		end
		buttonID = buttonID + 1
	end

	for buttonID = numButtons,1,-1 do
		button = Buttons[buttonID]
		button:UpdateGrid()
	end
end

-- Just a proxy for the secure arrangement method.
-- Only ever call this out of combat, as it does not check for it.
Module.UpdateButtonLayout = function(self)
	local proxy = self:GetSecureUpdater()
	if (proxy) then
		proxy:Execute(proxy:GetAttribute("arrangeButtons"))
		proxy:Execute(proxy:GetAttribute("arrangePetButtons"))
	end
end

Module.UpdateCastOnDown = function(self)
	if InCombatLockdown() then 
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateSettings")
	end
	if (event == "PLAYER_REGEN_ENABLED") then 
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "UpdateSettings")
	end 
	local db = self.db
	for button in self:GetAllActionButtonsOrdered() do
		button:RegisterForClicks(db.castOnDown and "AnyDown" or "AnyUp")
		button:Update()
	end 
end 

Module.UpdateConsolePortBindings = function(self)
	local CP = _G.ConsolePort
	if (not CP) then 
		return 
	end 
end

Module.UpdateBindings = function(self)
	if (IsConsolePortEnabled) then 
		self:UpdateConsolePortBindings()
	else
		self:UpdateActionButtonBindings()
	end
end

Module.UpdateTooltipSettings = function(self)
	local layout = self.layout
	local tooltip = self:GetActionButtonTooltip()
	tooltip.colorNameAsSpellWithUse = layout.TooltipColorNameAsSpellWithUse
	tooltip.hideItemLevelWithUse = layout.TooltipHideItemLevelWithUse
	tooltip.hideStatsWithUseEffect = layout.TooltipHideStatsWithUse
	tooltip.hideBindsWithUseEffect = layout.TooltipHideBindsWithUse
	tooltip.hideUniqueWithUseEffect = layout.TooltipHideUniqueWithUse
	tooltip.hideEquipTypeWithUseEffect = layout.TooltipHideEquipTypeWithUse
end 

Module.UpdateSettings = function(self, event, ...)
	self:UpdateFading()
	self:UpdateFadeAnchors()
	self:UpdateExplorerModeAnchors()
	self:UpdateCastOnDown()
	self:UpdateTooltipSettings()
end 

-- Initialization
----------------------------------------------------
Module.OnEvent = function(self, event, ...)
	if (event == "UPDATE_BINDINGS") then 
		self:UpdateBindings()
	elseif (event == "PLAYER_ENTERING_WORLD") then
		IN_COMBAT = false
		self:UpdateBindings()
	elseif (event == "PLAYER_REGEN_DISABLED") then
		IN_COMBAT = true 
	elseif (event == "PLAYER_REGEN_ENABLED") then
		IN_COMBAT = false
	elseif (event == "ACTIONBAR_SLOT_CHANGED") then
		self:UpdateButtonGrids()
	elseif (event == "PET_BAR_UPDATE") then
		self:UpdateExplorerModeAnchors()
	else
		self:UpdateButtonGrids()
	end 
end 

Module.OnInit = function(self)
	self:PurgeSavedSettingFromAllProfiles(self:GetName(), 
		"buttonsPrimary", 
		"buttonsComplimentary", 
		"editMode", 
		"enableComplimentary", 
		"enableStance", 
		"enablePet", 
		"showBinds", 
		"showCooldown", 
		"showCooldownCount",
		"showNames",
		"visibilityPrimary",
		"visibilityComplimentary",
		"visibilityStance", 
		"visibilityPet"
	)
	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())

	-- Create master frame. This one becomes secure.
	self.frame = self:CreateFrame("Frame", nil, "UICenter")

	-- Create overlay frames used for explorer mode.
	self.frameOverlay = self:CreateFrame("Frame", nil, "UICenter")
	self.frameOverlayPet = self:CreateFrame("Frame", nil, "UICenter")

	-- Apply overlay alpha to the master frame.
	hooksecurefunc(self.frameOverlay, "SetAlpha", function(_,alpha) self.frame:SetAlpha(alpha) end)

	-- Spawn the bars
	self:SpawnActionBars()
	self:SpawnPetBar()
	self:SpawnStanceBar()
	self:SpawnExitButton()

	-- Verified to only exist in retail.
	if (IsRetail) then
		self:SpawnTotemBar()
	end

	-- Arrange buttons
	-- *We're using the non-secure proxy method here,
	--  so take care to only ever do this out of combat.
	self:UpdateButtonLayout()

	-- Update saved settings
	self:UpdateBindings()
	self:UpdateSettings()
end 

Module.OnEnable = function(self)
	self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "OnEvent")
	self:RegisterEvent("PET_BAR_UPDATE", "OnEvent")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
	self:RegisterEvent("UPDATE_BINDINGS", "OnEvent")

	if (IsRetail) then
		self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR", "OnEvent")
		self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", "OnEvent")
	end
end
