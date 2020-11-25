--[[--

	Should gather the modules and updates
	for both extra- and zone abilities here.

--]]--
local ADDON, Private = ...

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "Schematics::Widgets requires LibClientBuild to be loaded.")

-- Let's just assume this only exists in retail.
if (not LibClientBuild:IsRetail()) then
	return
end

-- Lua API
local _G = _G
local ipairs = ipairs
local pairs = pairs
local table_remove = table.remove
local tonumber = tonumber

-- WoW API
local GetBindingKey = GetBindingKey
local hooksecurefunc = hooksecurefunc

-- Private API
local Colors = Private.Colors
local GetAuraFilter = Private.GetAuraFilter
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia
local GetSchematic = Private.GetSchematic

-- Callbacks
-----------------------------------------------------------
local OnUpdate = function(button)
	local spellID = button.currentSpellID or button.spellID or button.baseSpellID
	if (spellID) then 
		local tooltip = Private:GetFloaterTooltip()
		tooltip:SetDefaultAnchor(button)
		tooltip:SetSpellByID(spellID)
	else
		if (button.action) and (HasAction(button.action)) then 
			local tooltip = Private:GetFloaterTooltip()
			tooltip:SetDefaultAnchor(button)
			tooltip:SetAction(button.action)
		end 
	end 
end

local OnEnter = function(button)
	button.UpdateTooltip = OnUpdate
	button:UpdateTooltip()
end

local OnLeave = function(button)
	button.UpdateTooltip = nil
	Private:GetFloaterTooltip():Hide()
end

-- Write this in a manner so that it checks for exisiting elements, 
-- and thus can be run multiple times without creating cloned elements.
local StripNStyle = function(button)

	button:SetSize(52,52)
	button:GetNormalTexture():SetTexture(nil)

	-- Extra Button styling.
	if (button.style) then
		button.style:SetAlpha(0) -- Extra
	end

	-- Original Extra and >one icons. 
	if (button.icon or button.Icon) then
		(button.icon or button.Icon):SetAlpha(0)
	end

	-- Zone Ability Border
	if (button.NormalTexture) then
		button.NormalTexture:SetAlpha(0) 
	end

	-- Different names, but both have it.
	local cooldown = button.cooldown or button.Cooldown 
	if (cooldown) then
		cooldown:SetSize(40,40)
		cooldown:ClearAllPoints()
		cooldown:SetPoint("CENTER", 0, 0)
		cooldown:SetSwipeTexture(GetMedia("actionbutton-mask-square-rounded"))
		cooldown:SetSwipeColor(0, 0, 0, .75)
		cooldown:SetDrawSwipe(true)
		cooldown:SetBlingTexture(GetMedia("blank"), 0, 0, 0 , 0) 
		cooldown:SetDrawBling(true)

		-- Attempting to fix the issue with too opaque swipe textures
		if (not cooldown.GPSwipe) then
			cooldown:HookScript("OnShow", function() 
				cooldown:SetSwipeColor(0, 0, 0, .75)
			end)
		end
	end

	-- Spell charges.
	local count = button.Count 
	if (count) then
		count:ClearAllPoints()
		count:SetPoint("BOTTOMRIGHT", -3, 3)
		count:SetFontObject(GetFont(14, true))
		count:SetJustifyH("CENTER")
		count:SetJustifyV("BOTTOM")
	end
	
	-- Only the ExtraButtons have this
	local flash = button.Flash 
	if (flash) then
		flash:SetTexture(nil)
	end

	-- Only the first ExtraButton have this
	local keybind = button.HotKey 
	if (keybind) then
		keybind:ClearAllPoints()
		keybind:SetPoint("TOPLEFT", 5, -5)
		keybind:SetFontObject(GetFont(14, true))
		keybind:SetJustifyH("CENTER")
		keybind:SetJustifyV("BOTTOM")
		keybind:SetShadowOffset(0, 0)
		keybind:SetShadowColor(0, 0, 0, 1)
		keybind:SetTextColor(Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3], .75)
		keybind:SetText(GetBindingKey(button:GetName()))
	end

	-- Only the ExtraButtons are checkbuttons, 
	if (button:GetObjectType() == "CheckButton") then
		if (not button.GPChecked) then
			button:GetCheckedTexture():SetTexture(nil)

			local checkedTexture = button:CreateTexture()
			checkedTexture:SetDrawLayer("BACKGROUND", 2)
			checkedTexture:SetMask(GetMedia("actionbutton-mask-square-rounded"))
			checkedTexture:SetColorTexture(.9, .8, .1, .3)
			button.GPChecked = checkedTexture

			button:SetCheckedTexture(checkedTexture)
		end
	end

	-- This crazy stunt is needed to be able  
	-- to set a mask at all on the Extra buttons. 
	-- I honestly have no idea why. Somebody tell me?
	if (not button.GPIcon) then
		local icon = button:CreateTexture()
		icon:SetPoint("TOPLEFT", button, 6, -6)
		icon:SetPoint("BOTTOMRIGHT", button, -6, 6)
		icon:SetMask(GetMedia("actionbutton-mask-square-rounded"))
		button.GPIcon = icon

		hooksecurefunc((button.icon or button.Icon), "SetTexture", function(_,...) button.GPIcon:SetTexture(...) end)
	end

	if (not button.GPHighlight) then 
		button:GetHighlightTexture():SetTexture(nil)

		local highlightTexture = button:CreateTexture()
		highlightTexture:SetDrawLayer("BACKGROUND", 1)
		highlightTexture:SetTexture(GetMedia("actionbutton-mask-square-rounded"))
		highlightTexture:SetAllPoints(button.GPIcon)
		highlightTexture:SetVertexColor(1, 1, 1, .1)
		button.GPHighlight = highlightTexture

		button:SetHighlightTexture(highlightTexture)
	end

	if (not button.GPBorder) then 
		local border = button.scaffold:CreateFrame("Frame")
		border:SetBackdrop({ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 24 })
		border:SetBackdropBorderColor(Colors.ui[1], Colors.ui[2], Colors.ui[3], 1)
		border:SetPoint("TOPLEFT", button.GPIcon, -15, 15)
		border:SetPoint("BOTTOMRIGHT", button.GPIcon, 15, -15)
		border:SetParent(button)
		border:SetFrameLevel(1)
		button.GPBorder = border
	end

	button.GPIcon:SetParent(button.GPBorder)
	button.GPIcon:SetDrawLayer("BACKGROUND", -1)

	if (count) then
		count:SetParent(button.GPBorder)
		count:SetDrawLayer("OVERLAY", 1)
	end

	if (keybind) then
		keybind:SetParent(button.GPBorder)
		keybind:SetDrawLayer("OVERLAY", 1)
	end

	button:SetScript("OnEnter", OnEnter)
	button:SetScript("OnLeave", OnLeave)
end

-- Module Schematics
-----------------------------------------------------------
-- Legacy
Private.RegisterSchematic("ModuleForge::ExtraBars", "Legacy", {
	-- This is called by the module when the module is initialized.
	-- This is typically where we first figure out if it should remain enabled,
	-- then in turn start spawning frames and set up the local environment as needed.
	-- Anything used later on or in the enable method should be defined here.
	OnInit = {
		{
			type = "ExecuteMethods",
			methods = {
				{
					-- The 'values' sections assigns values and methods
					-- to the self object, which in this case is the module.
					-- Nothing actually happens here, but this is where 
					-- we define everything the module needs in advance.
					values = {
						"ExtraButtons", {},
						"StyleCache", {},

						-- Scaffold creation
						-- The spawn position of the buttons are defined here.
						"CreateScaffolds", function(self)

							local extraScaffold = self:CreateFrame("Frame", nil, "UICenter")
							extraScaffold:Place("BOTTOM", -150, 300)
							extraScaffold:SetSize(64,64)
							self.extraScaffold = extraScaffold
						
							local zoneScaffold = self:CreateFrame("Frame", nil, "UICenter")
							zoneScaffold:Place("BOTTOM", 150, 300)
							zoneScaffold:SetSize(64,64)
							self.zoneScaffold = zoneScaffold
						
						end,

						-- One-time method to take control of the buttons,
						-- and hook the styling of any new ones.
						"HandleButtons", function(self)
							local ExtraAbilityContainer = ExtraAbilityContainer
							local ExtraActionBarFrame = ExtraActionBarFrame
							local ZoneAbilityFrame = ZoneAbilityFrame

							UIPARENT_MANAGED_FRAME_POSITIONS.ExtraAbilityContainer = nil
							ExtraAbilityContainer.SetSize = function() end
							ExtraActionBarFrame:SetParent(self.extraScaffold)
							ExtraActionBarFrame:ClearAllPoints()
							ExtraActionBarFrame:SetAllPoints()
							ExtraActionBarFrame:EnableMouse(false)
							ExtraActionBarFrame.ignoreInLayout = true
							ExtraActionBarFrame.ignoreFramePositionManager = true
						
							ZoneAbilityFrame.SpellButtonContainer.holder = self.zoneScaffold
							ZoneAbilityFrame:SetParent(self.zoneScaffold)
							ZoneAbilityFrame:ClearAllPoints()
							ZoneAbilityFrame:SetAllPoints()
							ZoneAbilityFrame:EnableMouse(false)
							ZoneAbilityFrame.ignoreInLayout = true
							ZoneAbilityFrame.ignoreFramePositionManager = true

							-- Hook creation of new zone buttons
							self:SetSecureHook(ZoneAbilityFrame, "UpdateDisplayedZoneAbilities", "UpdateZoneButtons")

							-- Initial styling updates
							self:UpdateExtraButtons()
							self:UpdateZoneButtons()
						end,

						"UpdateExtraButtons", function(self)
							local i = 1
							local button = _G["ExtraActionButton"..i]

							-- Iterate available buttons
							while (button) and (not self.StyleCache[button]) do

								-- Give the button access to its scaffold
								button.scaffold = self.extraScaffold
								
								-- Unified styling method for the buttons 
								StripNStyle(button)

								-- Cache it
								self.StyleCache[button] = true
								self.ExtraButtons[#self.ExtraButtons + 1] = button
								
								-- Keep looking for more buttons.
								i = i + 1
								button = _G["ExtraActionButton"..i]
							end

						end,

						"UpdateZoneButtons", function(self)
							local frame = ZoneAbilityFrame

							-- Kill off the fugly styling texture
							frame.Style:SetAlpha(0)

							-- Iterate the active buttons.
							for button in frame.SpellButtonContainer:EnumerateActive() do
								if (button) then

									-- Give the button access to its scaffold
									button.scaffold = self.zoneScaffold

									-- Unified styling method for the buttons 
									StripNStyle(button)
								end
							end
						end,

						"UpdateBindings", function(self)
							for id,button in ipairs(self.ExtraButtons) do
								if (button.HotKey) then
									button.HotKey:SetText(GetBindingKey(button:GetName()))
								end
							end
						end
						
					},
					-- The 'chain' sections performs methods on the module,
					-- and passes the unpacked arguments in the tables 
					-- to those methods. An empty table means no arguments.
					-- Here we can call methods created in previously defined
					-- 'values' sections.
					chain = {
					}
				}
			}
		}
	},
	-- This is called by the module when the module is enabled.
	-- This is typically where we register events, start timers, etc.
	OnEnable = {
		{
			type = "ExecuteMethods",
			methods = {
				{
					-- The 'chain' sections performs methods on the module,
					-- and passes the unpacked arguments in the tables 
					-- to those methods. An empty table means no arguments.
					-- Here we can call methods created in previously defined
					-- 'values' sections.
					chain = {
						"EmbedLibraries", { "LibFrame", "LibSecureHook", "LibTooltip" },
						"CreateScaffolds", {},
						"HandleButtons", {},
						"RegisterEvent", { "UPDATE_BINDINGS", "UpdateBindings" }
					}
				}
			}
		}
	}
})
