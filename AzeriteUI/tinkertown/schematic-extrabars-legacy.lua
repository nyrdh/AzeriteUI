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
----------------------------------------------------


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

						"StyleExtraButtons", function(self)
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
							ZoneAbilityFrame.ignoreInLayout = true

							self:SetSecureHook(ZoneAbilityFrame, "UpdateDisplayedZoneAbilities", "UpdateZoneButtons")

							self:UpdateExtraButtons()
							self:UpdateZoneButtons()
						end,

						"UpdateExtraButtons", function(self)
							local i = 1
							local button = _G["ExtraActionButton"..i]
							while (button) do

								button:SetSize(52,52)
								button.style:SetAlpha(0)
								button.icon:SetAlpha(0) -- don't hide or remove, it will taint!

								-- This crazy stunt is needed to be able to set a mask 
								-- I honestly have no idea why. Somebody tell me?
								local newIcon = button:CreateTexture()
								newIcon:SetPoint("TOPLEFT", button, 6, -6)
								newIcon:SetPoint("BOTTOMRIGHT", button, -6, 6)
								newIcon:SetMask(GetMedia("actionbutton-mask-square-rounded"))
								hooksecurefunc(button.icon, "SetTexture", function(_,...) newIcon:SetTexture(...) end)

								button:GetNormalTexture():SetTexture(nil)
								button:GetHighlightTexture():SetTexture(nil)
								button:GetCheckedTexture():SetTexture(nil)

								local tex = button:CreateTexture()
								tex:SetDrawLayer("BACKGROUND", 2)
								tex:SetMask(GetMedia("actionbutton-mask-square-rounded"))
								tex:SetColorTexture(.9, .8, .1, .3)
								button:SetCheckedTexture(tex)

								local tex = button:CreateTexture()
								tex:SetDrawLayer("BACKGROUND", 1)
								tex:SetTexture(GetMedia("actionbutton-mask-square-rounded"))
								tex:SetAllPoints(newIcon)
								tex:SetVertexColor(1, 1, 1, .15)
								button:SetHighlightTexture(tex)

								button.BorderFrame = self.extraScaffold:CreateFrame("Frame")
								button.BorderFrame:SetBackdrop({ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 24 })
								button.BorderFrame:SetBackdropBorderColor(Colors.ui[1], Colors.ui[2], Colors.ui[3], 1)
								button.BorderFrame:SetPoint("TOPLEFT", newIcon, -15, 15)
								button.BorderFrame:SetPoint("BOTTOMRIGHT", newIcon, 15, -15)
								button.BorderFrame:SetParent(button)
								button.BorderFrame:SetFrameLevel(1)

								newIcon:SetParent(button.BorderFrame)
								newIcon:SetDrawLayer("BACKGROUND", -1)

								button.UpdateExtraActionButtonTooltip = function(button)
									if button.action and HasAction(button.action) then 
										local tooltip = self:GetFloaterTooltip()
										tooltip:SetDefaultAnchor(button)
										tooltip:SetAction(button.action)
									end 
								end

								button:SetScript("OnEnter", function(button)
									button.UpdateTooltip = button.UpdateExtraActionButtonTooltip
									button:UpdateTooltip()
								end)

								button:SetScript("OnLeave", function(button)
									button.UpdateTooltip = nil
									self:GetFloaterTooltip():Hide()
								end)
							
								--button.HotKey:SetText(GetBindingKey('ExtraActionButton'..i))

								self.ExtraButtons[#self.ExtraButtons + 1] = button

								i = i + 1
								button = _G["ExtraActionButton"..i]
							end

						end,

						"UpdateZoneButtons", function(self)
							self:UpdateZoneAlpha()
							local frame = ZoneAbilityFrame
							for button in frame.SpellButtonContainer:EnumerateActive() do
								if (button) and (not self.StyleCache[button]) then

									button:SetSize(52,52)
									button:GetNormalTexture():SetTexture(nil)
									button:GetHighlightTexture():SetTexture(nil)
									--button:GetCheckedTexture():SetTexture(nil) -- don't exist, not a checkbutton
	
									button.NormalTexture:SetAlpha(0)

									button.Icon:SetTexCoord(0, 1, 0, 1)
									button.Icon:ClearAllPoints()
									button.Icon:SetPoint("TOPLEFT", 6, -6)
									button.Icon:SetPoint("BOTTOMRIGHT", -6, 6)
									button.Icon:SetMask(GetMedia("actionbutton-mask-square-rounded"))

									button.BorderFrame = self.zoneScaffold:CreateFrame("Frame")
									button.BorderFrame:SetPoint("TOPLEFT", button.Icon, -15, 15)
									button.BorderFrame:SetPoint("BOTTOMRIGHT", button.Icon, 15, -15)
									button.BorderFrame:SetBackdrop({ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 24 })
									button.BorderFrame:SetBackdropBorderColor(Colors.ui[1], Colors.ui[2], Colors.ui[3], 1)
									button.BorderFrame:SetParent(button)
									button.BorderFrame:SetFrameLevel(1)

									button.Icon:SetParent(button.BorderFrame)
									button.Icon:SetDrawLayer("BACKGROUND", -1)

									local tex = button:CreateTexture()
									tex:SetDrawLayer("BACKGROUND", 2)
									tex:SetTexture(GetMedia("actionbutton-mask-square-rounded"))
									tex:SetVertexColor(1, 1, 1, .15)
									tex:SetAllPoints(button.Icon)
									button:SetHighlightTexture(tex)

									button.UpdateZoneAbilityButtonTooltip = function(button)
										local spellID = button.currentSpellID or button.spellID or button.baseSpellID
										if spellID then 
											local tooltip = self:GetFloaterTooltip()
											tooltip:SetDefaultAnchor(button)
											tooltip:SetSpellByID(spellID)
										end 
									end

									button:SetScript("OnEnter", function(button)
										button.UpdateTooltip = button.UpdateZoneAbilityButtonTooltip
										button:UpdateTooltip()
									end)

									button:SetScript("OnLeave", function(button)
										button.UpdateTooltip = nil
										self:GetFloaterTooltip():Hide()
									end)
								
									self.StyleCache[button] = true
								end
							end
						end,

						"UpdateZoneAlpha", function(self)
							local frame = ZoneAbilityFrame
							frame.Style:SetAlpha(0)
							for spellButton in frame.SpellButtonContainer:EnumerateActive() do
								--if (spellButton) then
								--	spellButton:SetAlpha(0)
								--end
							end
						end,

						"UpdateBindings", function(self)
						end,

						"GetFloaterTooltip", function(self)
							return self:GetTooltip("GP_FloaterTooltip") or self:CreateTooltip("GP_FloaterTooltip")
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
						"StyleExtraButtons", {}
					}
				}
			}
		}
	}
})
