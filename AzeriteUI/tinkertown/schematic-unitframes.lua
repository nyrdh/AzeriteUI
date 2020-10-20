local ADDON, Private = ...

-- WoW API
local UnitCanAttack = UnitCanAttack
local UnitIsEnemy = UnitIsEnemy
local UnitIsFriend = UnitIsFriend
local UnitIsUnit = UnitIsUnit

-- Private API
local Colors = Private.Colors
local GetAuraFilter = Private.GetAuraFilter
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia
local GetSchematic = Private.GetSchematic

-- Utility Functions
-----------------------------------------------------------
-- Sort method used to display auras
-- on the primary player- and target unitframes.
local Aura_SortPrimary = function(a,b)
	if (a) and (b) and (a.id) and (b.id) then
		-- If one of the auras are static
		if (a.duration == 0) or (b.duration == 0) then
			-- If both are static, sort by name
			if (a.duration == b.duration) then
				if (a.name) and (b.name) then
					return (a.name > b.name)
				end
			else
				-- Put the static one last
				return (b.duration == 0)
			end
		else
			-- If both expire at the same time
			if (a.expirationTime == b.expirationTime) then
				-- Sort by name
				if (a.name) and (b.name) then
					return (a.name > b.name)
				end
			else
				-- Sort by remaining time, first expiring first.
				return (a.expirationTime < b.expirationTime) 
			end
		end
	end
end

-- General aura border- and icon coloring.
local Aura_UpdateColor = function(element, button)
	local unit = button.unit

	local isEnemy = UnitCanAttack("player", unit) -- UnitIsEnemy(unit, "player")
	local isFriend = UnitIsFriend("player", unit)
	local isYou = UnitIsUnit("player", unit)

	-- Border
	if (isFriend) then
		if (button.isBuff) then 
			button.Border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
		else
			local color = Colors.debuff[button.debuffType or "none"]
			if color then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			else
				button.Border:SetBackdropBorderColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3])
			end 
		end
	else 
		if (button.isStealable) then 
			local color = Colors.power.ARCANE_CHARGES
			if (color) then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			else
				button.Border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
			end 
		elseif (button.isBuff) then 
			button.Border:SetBackdropBorderColor(Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
		else
			local color = Colors.debuff.none
			if (color) then 
				button.Border:SetBackdropBorderColor(color[1], color[2], color[3])
			else
				button.Border:SetBackdropBorderColor(Colors.quest.red[1], Colors.quest.red[2], Colors.quest.red[3])
			end 
		end
	end

	-- Icon
	if (isYou) then
		button.Icon:SetDesaturated(false)
	elseif (isFriend) then
		if (button.isBuff) then
			if (button.isCastByPlayer) then 
				button.Icon:SetDesaturated(false)
			else
				button.Icon:SetDesaturated(true)
			end
		else
			button.Icon:SetDesaturated(false)
		end
	else
		if (button.isBuff) then 
			button.Icon:SetDesaturated(false)
		else
			if (button.isCastByPlayer) then 
				button.Icon:SetDesaturated(false)
			else
				button.Icon:SetDesaturated(true)
			end
		end
	end
end

-- Applied to the primary player frame
Private.RegisterSchematic("UnitFrame::Player", "Legacy", {
	-- Create layered scaffold frames
	{
		type = "CreateWidgets",
		widgets = {
			{
				parent = "self", ownerKey = "BackdropScaffold", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 0 }
			},
			{
				parent = "self", ownerKey = "ContentScaffold", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 10 }
			},
			{
				parent = "self", ownerKey = "BorderScaffold", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 25 }
			},
			{
				parent = "self", ownerKey = "OverlayScaffold", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 30 }
			}
		}
	},
	-- Position and style the main frame
	{
		-- Only set the parent in modifiable widgets if it is your intention to change it.
		-- Otherwise the code will assume the owner is the parent, and leave it as is,
		-- which is what we want in the majority of cases.
		type = "ModifyWidgets",
		widgets = {
			-- Setup main frame
			{
				-- Note that a missing ownerKey
				-- will apply these changes to the original object instead.
				parent = nil, ownerKey = nil, 
				chain = {
					"SetSize", { 316, 86 }, "SetHitBox", { -4, -4, -4, -4 },
					"Place", { "BOTTOMRIGHT", "UICenter", "BOTTOM", -210, 250 }
				},
				values = {
					"colors", Colors,
					"hideInVehicles", true
				}
			},
			-- Setup backdrop and border
			{
				parent = nil, ownerKey = "BorderScaffold", objectType = "Frame", 
				chain = {
					"SetBackdrop", {{
						bgFile = nil, tile = false, 
						edgeFile = GetMedia("tooltip_border_hex"), edgeSize = 32, 
						insets = { top = 10.5, bottom = 10.5, left = 10.5, right = 10.5 }
					}},
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 },
					"ClearAllPoints", "SetPoint", { "TOPLEFT", -3, 3 }, "SetPoint", { "BOTTOMRIGHT", 3, -3 }
				}

			}
		}
	},
	-- Create child widgets
	{
		type = "CreateWidgets",
		widgets = {
			-- Health Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Health", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "RIGHT",
					"SetFlippedHorizontally", false,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 2, 
					"SetPosition", { "TOPLEFT", 8, -8 }, -- relative to unit frame
					"SetSize", { 300, 52 }, -- 18
					"SetStatusBarTexture", GetMedia("statusbar-power")
				},
				values = {
					"colorAbsorb", true, -- tint absorb overlay
					"colorClass", true, -- color players by class 
					"colorDisconnected", false, -- color disconnected units
					"colorHealth", true, -- color anything else in the default health color
					"colorReaction", true, -- color NPCs by their reaction standing with us
					"colorTapped", false, -- color tap denied units 
					"colorThreat", false, -- color non-friendly by threat
					"frequent", true, -- listen to frequent health events for more accurate updates
					"predictThreshold", .01,
					"absorbOverrideAlpha", .75
				}
			},
			-- Health Bar Backdrop Frame
			{
				parent = "self,Health", parentKey = "Bg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", -2 }
			},
			-- Health Bar Backdrop Texture
			{
				parent = "self,Health,Bg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "BACKGROUND", 1 },
					"SetPosition", { "TOPLEFT", 0, 0 },
					"SetSize", { 300, 52 },
					"SetTexture", GetMedia("statusbar-dark"),
					"SetVertexColor", { .1, .1, .1, 1 }
				}
			},
			-- Health Bar Overlay Frame
			{
				parent = "self,Health", parentKey = "Fg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 2 }
			},
			-- Health Bar Overlay Texture
			{
				parent = "self,Health,Fg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "TOPLEFT", 0, 0 },
					"SetSize", { 300, 52 },
					"SetTexture", GetMedia("statusbar-normal-overlay")	
				}
			},

			-- Health Bar Value
			{
				parent = "self,Health", parentKey = "Value", objectType = "FontString", 
				chain = {
					"SetPosition", { "RIGHT", -16, -1 },
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "RIGHT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(15,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetParentToOwnerKey", "OverlayScaffold"
				}
			},

			-- Health Bar Absorb Value
			{
				parent = "self,Health", parentKey = "ValueAbsorb", objectType = "FontString", 
				chain = {
					"SetPosition", function(self, owner, ...) 
						self:ClearAllPoints()
						self:SetPoint("RIGHT", owner.Health.Value, "LEFT", -13, 0)
					end, 
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "RIGHT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(15,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetParentToOwnerKey", "OverlayScaffold"
				}

			},
			
			-- Health Bar Overlay Cast Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Cast", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "RIGHT",
					"SetFlippedHorizontally", false,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 4, -- should be 2 higher than the health 
					"SetPosition", { "TOPLEFT", 8, -8 }, -- relative to unit frame
					"SetSize", { 300, 52 }, -- 18
					"SetStatusBarTexture", GetMedia("statusbar-power"),
					"SetStatusBarColor", { 1, 1, 1, .25 }
				}
			},

			-- Power Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Power", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "RIGHT",
					"SetFlippedHorizontally", false,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 2, 
					"SetPosition", { "BOTTOMLEFT", 8, 8 }, -- relative to unit frame
					"SetSize", { 300, 18 }, 
					"SetStatusBarTexture", GetMedia("statusbar-power")
				},
				values = {
					"frequent", true -- listen to frequent health events for more accurate updates
				}
			},
			-- Power Bar Backdrop Frame
			{
				parent = "self,Power", parentKey = "Bg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", -2 }
			},
			-- Power Bar Backdrop Texture
			{
				parent = "self,Power,Bg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "BACKGROUND", -2 },
					"SetPosition", { "BOTTOMRIGHT", 0, 0 },
					"SetSize", { 300, 18 },
					"SetTexture", GetMedia("statusbar-dark"),
					"SetVertexColor", { .1, .1, .1, 1 }
				}
			},
			-- Power Bar Overlay Frame
			{
				parent = "self,Power", parentKey = "Fg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 2 }
			},
			-- Power Bar Overlay Texture
			{
				parent = "self,Power,Fg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "BOTTOMRIGHT", 0, 0 },
					"SetSize", { 300, 18 },
					"SetTexture", GetMedia("statusbar-normal-overlay")	
				}
			},

			-- Power Bar Value
			{
				parent = "self,Power", parentKey = "Value", objectType = "FontString", 
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "CENTER", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(15,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetParentToOwnerKey", "OverlayScaffold"
				}
			},
			
			-- Unit Name
			{
				parent = "self,OverlayScaffold", ownerKey = "Name", objectType = "FontString", 
				chain = {
					"SetPosition", { "LEFT", 24, 9 },
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "LEFT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(13,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetSize", { 220, 14 }, 
				},
				values = {
					"maxChars", 16,
					"showLevel", true,
					"showLevelLast", false,
					"useSmartName", true
				}

			},

			-- Auras
			{
				parent = "self,ContentScaffold", ownerKey = "Auras", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetSize", { 304, 84 },
					"SetPoint", { "TOPRIGHT", -7, 96 }
				},
				values = {
					"auraSize", 40, 
					"auraWidth", false, 
					"auraHeight", false,
					"customSort", Aura_SortPrimary,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"filter", false, 
					"filterBuffs", false, 
					"filterDebuffs", false, 
					"func", GetAuraFilter("legacy"), 
					"funcBuffs", false,
					"funcDebuffs", false,
					"growthX", "LEFT", 
					"growthY", "UP", 
					"maxBuffs", false, 
					"maxDebuffs", false, 
					"maxVisible", 21, 
					"showDurations", true, 
					"showSpirals", false, 
					"showLongDurations", true,
					"spacingH", 4, 
					"spacingV", 4, 
					"tooltipAnchor", false,
					"tooltipDefaultPosition", false, 
					"tooltipOffsetX", 8,
					"tooltipOffsetY", 16,
					"tooltipPoint", "BOTTOMRIGHT",
					"tooltipRelPoint", "TOPRIGHT",
					"PostCreateButton", function(element, button)
						if (element._owner:Forge(button, GetSchematic("Widget::AuraButton::Large"))) then
							return 
						end
					end,
					"PostUpdateButton", Aura_UpdateColor
					
				}
			},

			-- DeBuffs
			{
				parent = "self,ContentScaffold", ownerKey = "Debuffs", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetSize", { 140, 104 },
					"SetPoint", { "TOPRIGHT", -321, 1 }
				},
				values = {
					"auraSize", 32, 
					"auraWidth", false, 
					"auraHeight", false,
					"customSort", Aura_SortPrimary,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"filter", false, 
					"filterBuffs", false, 
					"filterDebuffs", false, 
					"func", GetAuraFilter("legacy-secondary"), 
					"funcBuffs", false,
					"funcDebuffs", false,
					"growthX", "LEFT", 
					"growthY", "DOWN", 
					"maxBuffs", false, 
					"maxDebuffs", false, 
					"maxVisible", 12, 
					"showDurations", true, 
					"showSpirals", false, 
					"showLongDurations", true,
					"spacingH", 4, 
					"spacingV", 4, 
					"tooltipAnchor", false,
					"tooltipDefaultPosition", false, 
					"tooltipOffsetX", 8,
					"tooltipOffsetY", 16,
					"tooltipPoint", "BOTTOMRIGHT",
					"tooltipRelPoint", "TOPRIGHT",
					"PostCreateButton", function(element, button)
						if (element._owner:Forge(button, GetSchematic("Widget::AuraButton::Large"))) then
							return 
						end
					end,
					"PostUpdateButton", Aura_UpdateColor
				}
			}


		}
	}
})


-- Applied to the primary player frame
Private.RegisterSchematic("UnitFrame::Target", "Legacy", {
	-- Create layered scaffold frames
	{
		type = "CreateWidgets",
		widgets = {
			{
				parent = "self", ownerKey = "BackdropScaffold", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 0 }
			},
			{
				parent = "self", ownerKey = "ContentScaffold", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 10 }
			},
			{
				parent = "self", ownerKey = "BorderScaffold", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 25 }
			},
			{
				parent = "self", ownerKey = "OverlayScaffold", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 30 }
			}
		}
	},
	-- Position and style the main frame
	{
		-- Only set the parent in modifiable widgets if it is your intention to change it.
		-- Otherwise the code will assume the owner is the parent, and leave it as is,
		-- which is what we want in the majority of cases.
		type = "ModifyWidgets",
		widgets = {
			-- Setup main frame
			{
				-- Note that a missing ownerKey
				-- will apply these changes to the original object instead.
				parent = nil, ownerKey = nil, 
				chain = {
					"SetSize", { 316, 86 }, "SetHitBox", { -4, -4, -4, -4 },
					"Place", { "BOTTOMLEFT", "UICenter", "BOTTOM", 210, 250 }
				},
				values = {
					"colors", Colors,
					"hideInVehicles", true
				}
			},
			-- Setup backdrop and border
			{
				parent = nil, ownerKey = "BorderScaffold", objectType = "Frame", 
				chain = {
					"SetBackdrop", {{
						bgFile = nil, tile = false, 
						edgeFile = GetMedia("tooltip_border_hex"), edgeSize = 32, 
						insets = { top = 10.5, bottom = 10.5, left = 10.5, right = 10.5 }
					}},
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 },
					"ClearAllPoints", "SetPoint", { "TOPLEFT", -3, 3 }, "SetPoint", { "BOTTOMRIGHT", 3, -3 }
				}

			}
		}
	},
	-- Create child widgets
	{
		type = "CreateWidgets",
		widgets = {
			-- Health Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Health", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "LEFT",
					"SetFlippedHorizontally", true,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 2, 
					"SetPosition", { "TOPLEFT", 8, -8 }, -- relative to unit frame
					"SetSize", { 300, 52 }, -- 18
					"SetStatusBarTexture", GetMedia("statusbar-power")
				},
				values = {
					"colorAbsorb", true, -- tint absorb overlay
					"colorClass", true, -- color players by class 
					"colorDisconnected", true, -- color disconnected units
					"colorHealth", true, -- color anything else in the default health color
					"colorReaction", true, -- color NPCs by their reaction standing with us
					"colorTapped", true, -- color tap denied units 
					"colorThreat", true, -- color non-friendly by threat
					"frequent", true, -- listen to frequent health events for more accurate updates
					"predictThreshold", .01,
					"absorbOverrideAlpha", .75
				}
			},
			-- Health Bar Backdrop Frame
			{
				parent = "self,Health", parentKey = "Bg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", -2 }
			},
			-- Health Bar Backdrop Texture
			{
				parent = "self,Health,Bg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "BACKGROUND", 1 },
					"SetPosition", { "TOPLEFT", 0, 0 },
					"SetSize", { 300, 52 },
					"SetTexture", GetMedia("statusbar-dark"),
					"SetVertexColor", { .1, .1, .1, 1 }
				}
			},
			-- Health Bar Overlay Frame
			{
				parent = "self,Health", parentKey = "Fg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 2 }
			},
			-- Health Bar Overlay Texture
			{
				parent = "self,Health,Fg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "TOPLEFT", 0, 0 },
					"SetSize", { 300, 52 },
					"SetTexture", GetMedia("statusbar-normal-overlay")	
				}
			},

			-- Health Bar Value
			{
				parent = "self,Health", parentKey = "Value", objectType = "FontString", 
				chain = {
					"SetPosition", { "LEFT", 16, -1 },
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "LEFT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(15,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetParentToOwnerKey", "OverlayScaffold"
				}
			},

			-- Health Bar Absorb Value
			{
				parent = "self,Health", parentKey = "ValueAbsorb", objectType = "FontString", 
				chain = {
					"SetPosition", function(self, owner, ...) 
						self:ClearAllPoints()
						self:SetPoint("LEFT", owner.Health.Value, "RIGHT", 13, 0)
					end, 
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "LEFT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(15,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetParentToOwnerKey", "OverlayScaffold"
				}

			},
			
			-- Health Bar Overlay Cast Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Cast", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "LEFT",
					"SetFlippedHorizontally", true,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 4, -- should be 2 higher than the health 
					"SetPosition", { "TOPLEFT", 8, -8 }, -- relative to unit frame
					"SetSize", { 300, 52 }, -- 18
					"SetStatusBarTexture", GetMedia("statusbar-power"),
					"SetStatusBarColor", { 1, 1, 1, .25 }
				}
			},

			-- Power Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Power", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "LEFT",
					"SetFlippedHorizontally", true,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 2, 
					"SetPosition", { "BOTTOMLEFT", 8, 8 }, -- relative to unit frame
					"SetSize", { 300, 18 }, 
					"SetStatusBarTexture", GetMedia("statusbar-power")
				},
				values = {
					"frequent", true -- listen to frequent health events for more accurate updates
				}
			},
			-- Power Bar Backdrop Frame
			{
				parent = "self,Power", parentKey = "Bg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", -2 }
			},
			-- Power Bar Backdrop Texture
			{
				parent = "self,Power,Bg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "BACKGROUND", -2 },
					"SetPosition", { "BOTTOMRIGHT", 0, 0 },
					"SetSize", { 300, 18 },
					"SetTexture", GetMedia("statusbar-dark"),
					"SetVertexColor", { .1, .1, .1, 1 }
				}
			},
			-- Power Bar Overlay Frame
			{
				parent = "self,Power", parentKey = "Fg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 2 }
			},
			-- Power Bar Overlay Texture
			{
				parent = "self,Power,Fg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "BOTTOMRIGHT", 0, 0 },
					"SetSize", { 300, 18 },
					"SetTexture", GetMedia("statusbar-normal-overlay")	
				}
			},

			-- Power Bar Value
			{
				parent = "self,Power", parentKey = "Value", objectType = "FontString", 
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "CENTER", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(15,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetParentToOwnerKey", "OverlayScaffold"
				}
			},

			-- Unit Name
			{
				parent = "self,OverlayScaffold", ownerKey = "Name", objectType = "FontString", 
				chain = {
					"SetPosition", { "RIGHT", -24, 9 },
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "RIGHT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(13,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetSize", { 220, 14 }, 
				},
				values = {
					"maxChars", 16,
					"showLevel", true,
					"showLevelLast", true,
					"useSmartName", true
				}

			},

			-- Auras
			{
				parent = "self,ContentScaffold", ownerKey = "Auras", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetSize", { 304, 84 },
					"SetPoint", { "TOPLEFT", 7, 96 }
				},
				values = {
					"auraSize", 40, 
					"auraWidth", false, 
					"auraHeight", false,
					"customSort", Aura_SortPrimary,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"filter", false, 
					"filterBuffs", false, 
					"filterDebuffs", false, 
					"func", GetAuraFilter("legacy"), 
					"funcBuffs", false,
					"funcDebuffs", false,
					"growthX", "RIGHT", 
					"growthY", "UP", 
					"maxBuffs", false, 
					"maxDebuffs", false, 
					"maxVisible", 21, 
					"showDurations", true, 
					"showSpirals", false, 
					"showLongDurations", true,
					"spacingH", 4, 
					"spacingV", 4, 
					"tooltipAnchor", false,
					"tooltipDefaultPosition", false, 
					"tooltipOffsetX", 8,
					"tooltipOffsetY", 16,
					"tooltipPoint", "BOTTOMLEFT",
					"tooltipRelPoint", "TOPLEFT",
					"PostCreateButton", function(element, button)
						if (element._owner:Forge(button, GetSchematic("Widget::AuraButton::Large"))) then
							return 
						end
					end,
					"PostUpdateButton", Aura_UpdateColor
				}
			},

			-- Buffs
			{
				parent = "self,ContentScaffold", ownerKey = "Buffs", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetSize", { 140, 104 },
					"SetPoint", { "TOPLEFT", 321, 1 }
				},
				values = {
					"auraSize", 32, 
					"auraWidth", false, 
					"auraHeight", false,
					"customSort", Aura_SortPrimary,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"filter", false, 
					"filterBuffs", false, 
					"filterDebuffs", false, 
					"func", GetAuraFilter("legacy-secondary"), 
					"funcBuffs", false,
					"funcDebuffs", false,
					"growthX", "RIGHT", 
					"growthY", "DOWN", 
					"maxBuffs", false, 
					"maxDebuffs", false, 
					"maxVisible", 12, 
					"showDurations", true, 
					"showSpirals", false, 
					"showLongDurations", true,
					"spacingH", 4, 
					"spacingV", 4, 
					"tooltipAnchor", false,
					"tooltipDefaultPosition", false, 
					"tooltipOffsetX", 8,
					"tooltipOffsetY", 16,
					"tooltipPoint", "BOTTOMLEFT",
					"tooltipRelPoint", "TOPLEFT",
					"PostCreateButton", function(element, button)
						if (element._owner:Forge(button, GetSchematic("Widget::AuraButton::Large"))) then
							return 
						end
					end,
					"PostUpdateButton", Aura_UpdateColor
				}
			},

			-- DeBuffs
			{
				parent = "self,ContentScaffold", ownerKey = "Debuffs", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetSize", { 140, 104 },
					"SetPoint", { "TOPLEFT", 321, 1 }
				},
				values = {
					"auraSize", 32, 
					"auraWidth", false, 
					"auraHeight", false,
					"customSort", Aura_SortPrimary,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"filter", false, 
					"filterBuffs", false, 
					"filterDebuffs", false, 
					"func", GetAuraFilter("legacy-secondary"), 
					"funcBuffs", false,
					"funcDebuffs", false,
					"growthX", "RIGHT", 
					"growthY", "DOWN", 
					"maxBuffs", false, 
					"maxDebuffs", false, 
					"maxVisible", 12, 
					"showDurations", true, 
					"showSpirals", false, 
					"showLongDurations", true,
					"spacingH", 4, 
					"spacingV", 4, 
					"tooltipAnchor", false,
					"tooltipDefaultPosition", false, 
					"tooltipOffsetX", 8,
					"tooltipOffsetY", 16,
					"tooltipPoint", "BOTTOMLEFT",
					"tooltipRelPoint", "TOPLEFT",
					"PostCreateButton", function(element, button)
						if (element._owner:Forge(button, GetSchematic("Widget::AuraButton::Large"))) then
							return 
						end
					end,
					"PostUpdateButton", Aura_UpdateColor
				}
			}

		}
	}
})