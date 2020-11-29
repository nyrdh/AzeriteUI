--[[--

	The purpose of this file is to provide
	forges for the various unitframes.

--]]--
local ADDON, Private = ...

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "Schematics::Widgets requires LibClientBuild to be loaded.")

local LibTime = Wheel("LibTime")
assert(LibTime, "UnitFrames requires LibTime to be loaded.")

-- WoW API
local UnitPowerMax = UnitPowerMax

-- WoW client version constants
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Constants for calendar events
local IsWinterVeil = LibTime:IsWinterVeil()
local IsLoveFestival = LibTime:IsLoveFestival()

-- Power type constants
-- Sourced from BlizzardInterfaceCode/AddOns/Blizzard_APIDocumentation/UnitDocumentation.lua
local SPELL_POWER_CHI = Enum.PowerType.Chi or 12

-- Private API
local Colors = Private.Colors
local GetAuraFilter = Private.GetAuraFilter
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia
local GetSchematic = Private.GetSchematic
local HasSchematic = Private.HasSchematic

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

-- General aura button post creating forge
local Aura_PostCreate = function(element, button)
	if (element._owner:Forge(button, GetSchematic("WidgetForge::AuraButton::Large"))) then
		return 
	end
end

-- General aura border- and icon coloring.
local Aura_PostUpdate = function(element, button)
	local unit = button.unit
	if (not unit) then
		return
	end

	-- Border
	if (element.isFriend) then
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
	if (element.isYou) then
		button.Icon:SetDesaturated(false)
	elseif (element.isFriend) then
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

-- Module Schematics
-----------------------------------------------------------
-- Legacy unit frame spawning and post updates.
Private.RegisterSchematic("ModuleForge::UnitFrames", "Legacy", {
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
						"Frames", {},
						"ExplorerModeFrameAnchors", {},
						"SpawnQueue", { 
							-- "unit", [UnitForge::]"ID"

							{ "player", "Player" }, 
							{ "player", "PlayerHUD" }, 
							--{ "player", "PlayerInParty" },

							{ "party1", "Party" },
							{ "party2", "Party" },
							{ "party3", "Party" }, 
							{ "party4", "Party" },

							{ "pet", "Pet" }, 
							--{ "focus", "Focus" }, 

							{ "target", "Target" },
							{ "targettarget", "ToT" },

							{ "vehicle", "PlayerInVehicle" }, 
							-- { "target", "PlayerInVehicleTarget" },


						}, 

						"SpawnUnitFrames", function(self)
							for _,queuedEntry in ipairs(self.SpawnQueue) do 
								local unit,schematicID = unpack(queuedEntry)
								if (HasSchematic("UnitForge::"..schematicID)) then
									local frame = self:SpawnUnitFrame(unit, "UICenter", function(self, unit)
										self:Forge(GetSchematic("UnitForge::"..schematicID))
									end)
									self.Frames[frame] = unit
									if (not frame.ignoreExplorerMode) then
										self.ExplorerModeFrameAnchors[#self.ExplorerModeFrameAnchors + 1] = frame
									end
								end
							end
						end, 

						-- This one is used by the explorer mode module.
						-- Typically only the bottom block of unit frames
						-- should ever be included in this. 
						"GetExplorerModeFrameAnchors", function(self)
							return unpack(self.ExplorerModeFrameAnchors)
						end
					},
					-- The 'chain' sections performs methods on the module,
					-- and passes the unpacked arguments in the tables 
					-- to those methods. An empty table means no arguments.
					-- Here we can call methods created in previously defined
					-- 'values' sections.
					chain = {
						"SpawnUnitFrames", {}
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
					}
				}
			}
		}
	}
})

-- UnitFrame Schematics
-----------------------------------------------------------
-- Applied to the primary player frame
Private.RegisterSchematic("UnitForge::Player", "Legacy", {
	-- Create layered scaffold frames.
	-- These are used to house the other widgets and elements.
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

					-- hides when the unit has a vehicleui
					"hideInVehicles", true, 

					-- hides when the unit is in a vehicle, but lacks a vehicleui (tortollan minigames)
					--"visibilityPreDriver", "[canexitvehicle,novehicleui,nooverridebar,nopossessbar,noshapeshift]hide;", 
					"visibilityPreDriver", "[canexitvehicle,novehicleui][vehicleui][overridebar][possessbar][shapeshift]hide;"
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
					"SetSize", { 300, 58 }, -- 52
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
					"SetSize", { 300, 58 },
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
					"SetSize", { 300, 58 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 0, 1, 0, 1 }
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
				},
				values = {
					"useSmartValue", true
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
					"SetSize", { 300, 58 }, -- 18
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
					"SetSize", { 300, 12 }, --18
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
					"SetSize", { 300, 12 },
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
					"SetSize", { 300, 12 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 0, 1, 0, 1 }
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
			
			-- Combat Status
			{
				parent = "self,OverlayScaffold", ownerKey = "Combat", objectType = "Texture", 
				chain = {
					"SetPosition", { "CENTER", 0, 9 },
					"SetDrawLayer", { "OVERLAY", 2 }, 
					"SetSize", { 64, 64 }, 
					"SetTexture", GetMedia("state-grid"),
					"SetTexCoord", { .5, 1, 0, .5 }
				}
			},

			-- Unit Name
			{
				parent = "self,OverlayScaffold", ownerKey = "Name", objectType = "FontString", 
				chain = {
					"SetPosition", { "LEFT", 24, 6 },
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
					"tooltipOffsetX", -8,
					"tooltipOffsetY", 16,
					"tooltipPoint", "BOTTOMRIGHT",
					"tooltipRelPoint", "TOPRIGHT",
					"PostCreateButton", Aura_PostCreate,
					"PostUpdateButton", Aura_PostUpdate
					
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
					"PostCreateButton", Aura_PostCreate,
					"PostUpdateButton", Aura_PostUpdate
				}
			}
			
		}
	}
})

-- Applied to the primary target frame
Private.RegisterSchematic("UnitForge::Target", "Legacy", {
	-- Create layered scaffold frames.
	-- These are used to house the other widgets and elements.
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

					-- hides when the unit has a vehicleui
					"hideInVehicles", true, 

					-- don't need the explorer mode on this, 
					-- as it's visibility is tied to the fade-in anyway.
					"ignoreExplorerMode", true,

					-- hides when the unit is in a vehicle, but lacks a vehicleui (tortollan minigames)
					--"visibilityPreDriver", "[canexitvehicle,novehicleui,nooverridebar,nopossessbar,noshapeshift]hide;", 
					"visibilityPreDriver", "[canexitvehicle,novehicleui][vehicleui][overridebar][possessbar][shapeshift]hide;"
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
					"SetSize", { 300, 58 }, -- 18
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
					"SetSize", { 300, 58 },
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
					"SetSize", { 300, 58 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 1, 0, 0, 1 }
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
				},
				values = {
					"useSmartValue", true
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
					"SetSize", { 300, 58 }, -- 18
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
					"SetSize", { 300, 12 }, 
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
					"SetSize", { 300, 12 },
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
					"SetSize", { 300, 12 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 1, 0, 0, 1 }
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
					"SetPosition", { "RIGHT", -24, 6 },
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
					"PostCreateButton", Aura_PostCreate,
					"PostUpdateButton", Aura_PostUpdate
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
					"PostCreateButton", Aura_PostCreate,
					"PostUpdateButton", Aura_PostUpdate
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
					"PostCreateButton", Aura_PostCreate,
					"PostUpdateButton", Aura_PostUpdate
				}
			}

		}
	}
})

-- Applied to the player HUD elements like cast bar, combo points and alt power.
Private.RegisterSchematic("UnitForge::PlayerHUD", "Legacy", {
	-- Create layered scaffold frames.
	-- These are used to house the other widgets and elements.
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
					"SetSize", { 224, 26 }, "SetHitBox", { -4, -4, -4, -4 },
					"Place", { "BOTTOM", "UICenter", "BOTTOM", 0, 230 }
				},
				values = {
					"colors", Colors,
					"ignoreMouseOver", true,
					"ignoreExplorerMode", true
				}
			}
		}
	},
	-- Create child widgets
	{
		type = "CreateWidgets",
		widgets = {
			-- Cast Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Cast", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "RIGHT",
					"SetFlippedHorizontally", false,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 4,
					"SetPosition", { "TOPLEFT", 0, 0 }, -- relative to unit frame
					"SetSize", { 224, 26 }, -- 18
					"SetStatusBarTexture", GetMedia("statusbar-power"),
					"SetStatusBarColor", { 70/255, 255/255, 131/255, .69 }
				},
				values = {
					"maxNameChars", 24
				}
			},
			-- Cast Bar Backdrop Frame
			{
				parent = "self,Cast", parentKey = "Bg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", -2 }
			},
			-- Cast Bar Backdrop Texture
			{
				parent = "self,Cast,Bg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetAllPointsToParent", "SetDrawLayer", { "BACKGROUND", 1 },
					"SetTexture", GetMedia("statusbar-dark"), "SetVertexColor", { .1, .1, .1, 1 }
				}
			},
			-- Cast Bar Overlay Frame
			{
				parent = "self,Cast", parentKey = "Fg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 2 }
			},
			-- Cast Bar Overlay Texture
			{
				parent = "self,Cast,Fg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetAllPointsToParent", "SetDrawLayer", { "ARTWORK", 1 },
					"SetTexture", GetMedia("statusbar-normal-overlay")	
				}
			},
			-- Setup backdrop and border
			{
				parent = "self,Cast", parentKey = "Border", objectType = "Frame", objectSubType = "Frame", objectTemplate = BackdropTemplateMixin and "BackdropTemplate",
				chain = {
					"SetFrameLevelOffset", 3,
					"SetSizeOffset", 46,
					"SetPosition", { "CENTER", 0, 0 },
					"SetBackdrop", {{ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 32 }},
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 }
				}

			},
			-- Cast Bar Value
			{
				parent = "self,Cast", parentKey = "Value", objectType = "FontString", 
				chain = {
					"SetPosition", { "RIGHT", -16, 0 },
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "RIGHT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(14,true),
					"SetTextColor", { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
					"SetParentToOwnerKey", "Cast,Border"
				}
			},
			-- Cast Bar Name
			{
				parent = "self,Cast", parentKey = "Name", objectType = "FontString", 
				chain = {
					"SetPosition", { "LEFT", 16, 0 },
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "CENTER", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(12,true),
					"SetTextColor", { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
					"SetParentToOwnerKey", "Cast,Border"
				}
			},
			-- Cast Bar Spell Queue
			{
				parent = "self,Cast", parentKey = "SpellQueue", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetPosition", { "BOTTOMRIGHT", 0, 0 },
					"SetSizeOffset", 0,
					"SetOrientation", "LEFT",
					"SetStatusBarTexture", GetMedia("statusbar-power"),
					"SetStatusBarColor", { 1, 1, 1, .5 },
					"DisableSmoothing", true
				}
			}

			,

			-- Class Power
			{
				parent = "self,ContentScaffold", ownerKey = "ClassPower", objectType = "Frame", objectSubType = "Frame",
				chain = { 
					"SetFrameLevelOffset", 4,
					--"Place", { "BOTTOM", "UICenter", "BOTTOM", 0, 230 + 26+16+2 }, 
					"Place", { "TOPLEFT", 0, 18+16+2 }, 
					"SetSize", { 224, 18 }, 
				
					-- We need to call this once on element creation, 
					-- to force-trigger our pill spawning method before 
					-- the back-end can start its own updates.
					--"PostUpdate", {}
				},
				values = {
					"alphaEmpty", 1, -- Element alpha when no points are available.
					"alphaNoCombat", 1, -- Element alpha multiplier when out of combat.
					"alphaNoCombatRunes", 1, 
					"alphaWhenHiddenRunes", 1, 
					"hideWhenEmpty", true, -- Whether to fully hide an empty bar or not.
					"hideWhenNoTarget", true, -- Whether to hide when no target exists.
					"hideWhenUnattackable", true, -- Whether to hide when target can't be attacked.
					"useAlternateColoring", true, -- Whether to use multiple point colorings when available.
					"maxComboPoints", 5, -- Does not affect runes, they will always show 6.
					"runeSortOrder", "ASC",	-- Sort order of the runes.
					"flipSide", false, -- Holds no meaning in current theme.

					-- Called by the back-end on updates
					"PostUpdate", function(element, unit, min, max, newMax, powerType)

						-- Figure out the number of pills to divide the bar into.
						-- Anything not having an exception here will default to 5.
						local currentPillCount
						if (powerType == "RUNES") or ((powerType == "CHI") and (UnitPowerMax("player", SPELL_POWER_CHI) == 6)) then 
							currentPillCount = 6
						elseif (powerType == "STAGGER") then 
							currentPillCount = 3
						else
							currentPillCount = 5
						end 

						-- Align and toggle pills on count changes.
						-- This will also fire off the first time we call this method.
						if (currentPillCount ~= element.currentPillCount) then 

							-- Spawn and style missing pills on-the-fly
							local numPills = #element
							if (numPills < currentPillCount) then
								for i = numPills + 1, currentPillCount do
									local pill = element:CreateStatusBar()
									pill:SetMinMaxValues(0,1,true)
									pill:SetValue(0,true)
									pill:SetStatusBarTexture(GetMedia("statusbar-power"))
									pill:SetStatusBarColor(70/255, 255/255, 131/255, 1) -- back-end overwrites this
				
									local bg = element:CreateFrame("Frame")
									bg:SetAllPoints()
									bg:SetFrameLevel(pill:GetFrameLevel()-2)

									-- Empty slot texture
									local bgTexture = bg:CreateTexture()
									bgTexture:SetDrawLayer("BACKGROUND", 1)
									bgTexture:SetTexture(GetMedia("statusbar-power")) -- dark
									bgTexture:SetVertexColor( .1, .1, .1, 1)
									bgTexture:SetAllPoints(pill)
									pill.bg = bgTexture

									--local fg = element:CreateFrame("Frame")
									--fg:SetAllPoints()
									--fg:SetFrameLevel(pill:GetFrameLevel()+2)

									-- Overlay glow
									--local fgTexture = fg:CreateTexture()
									--fgTexture:SetDrawLayer("BACKGROUND", 1)
									--fgTexture:SetTexture(GetMedia("statusbar-normal-overlay"))
									--fgTexture:SetVertexColor(1, 1, 1, 1)
									--fgTexture:SetAllPoints(pill)
									--pill.Fg = fgTexture
			

									element[i] = pill
								end
							end

							-- Figure out pill sizes
							local elementWidth,elementHeight = element:GetSize()
							local width = math.floor(elementWidth/currentPillCount)
							local widthLast = elementWidth - width*(currentPillCount - 1)

							-- Style and position the pills
							for i = 1,currentPillCount do
								local pill = element[i]
								if (pill) then
									pill:SetSize(i == currentPillCount and widthLast or width, elementHeight)
									pill:Place("TOPLEFT", (i-1)*width, 0)

									if (powerType == "RUNES") then
										pill:DisableSmoothing(false)
										pill:SetSmartSmoothing(true)
									else
										pill:DisableSmoothing(true)
									end

								end
							end

							-- Hide superflous pills
							-- *Doesn't the back-end do this?
							--for i = currentPillCount + 1, #element do
							--	element[i]:Hide()
							--end

							-- Store the currently displayed pill count
							element.currentPillCount = currentPillCount
						end

						-- Update main element alpha and visibility. 
						-- This will override the visibility set by the back-end.
						if ((min >= max) and (not UnitAffectingCombat("player")) and (not UnitExists("target")))
						or ((min == 0) and (powerType ~= "RUNES")) then
							element:Hide()
						end
					
					end
				}
			},

			-- Class Power backdrop and border
			{
				parent = "self,ClassPower", parentKey = "Border", objectType = "Frame", objectSubType = "Frame", objectTemplate = BackdropTemplateMixin and "BackdropTemplate",
				chain = {
					"SetFrameLevelOffset", 3,
					"SetSizeOffset", 46,
					"SetPosition", { "CENTER", 0, 0 },
					"SetBackdrop", {{ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 32 }},
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 }
				}

			}
		}
	},

	-- Retail only
	IsRetail and {
		type = "CreateWidgets",
		widgets = {
			-- AltPower Bar
			{
				parent = "self,ContentScaffold", ownerKey = "AltPower", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "RIGHT",
					"SetFlippedHorizontally", false,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 4, -- should be 2 higher than the health 
					"SetPosition", { "TOPLEFT", 0, -26-16-2 }, -- relative to unit frame
					"SetSize", { 224, 18 }, 
					"SetStatusBarTexture", GetMedia("statusbar-power"),
					"SetStatusBarColor", { 70/255, 255/255, 131/255, .69 }
				},
				values = {
					"maxNameChars", 24
				}
			},
			-- AltPower Bar Backdrop Frame
			{
				parent = "self,AltPower", parentKey = "Bg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", -2 }
			},
			-- AltPower Bar Backdrop Texture
			{
				parent = "self,AltPower,Bg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetAllPointsToParent", "SetDrawLayer", { "BACKGROUND", 1 },
					"SetTexture", GetMedia("statusbar-dark"), "SetVertexColor", { .1, .1, .1, 1 }
				}
			},
			-- AltPower Bar Overlay Frame
			{
				parent = "self,AltPower", parentKey = "Fg", objectType = "Frame", objectSubType = "Frame",
				chain = { "SetAllPointsToParent", "SetFrameLevelOffset", 2 }
			},
			-- AltPower Bar Overlay Texture
			{
				parent = "self,AltPower,Fg", parentKey = "Texture", objectType = "Texture", 
				chain = {
					"SetAllPointsToParent", "SetDrawLayer", { "ARTWORK", 1 },
					"SetTexture", GetMedia("statusbar-normal-overlay")	
				}
			},
			-- Setup backdrop and border
			{
				parent = "self,AltPower", parentKey = "Border", objectType = "Frame", objectSubType = "Frame", objectTemplate = BackdropTemplateMixin and "BackdropTemplate",
				chain = {
					"SetFrameLevelOffset", 3,
					"SetSizeOffset", 46,
					"SetPosition", { "CENTER", 0, 0 },
					"SetBackdrop", {{ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 32 }},
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 }
				}

			},
			-- AltPower Bar Value
			{
				parent = "self,AltPower", parentKey = "Value", objectType = "FontString", 
				chain = {
					"SetPosition", { "RIGHT", -16, 0 },
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "RIGHT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(14,true),
					"SetTextColor", { Colors.highlight[1], Colors.highlight[2], Colors.highlight[3], .5 },
					"SetParentToOwnerKey", "AltPower,Border"
				}
			}
		}
	} or nil
	
})

-- Applied to the vehicle frame only visible while in a vehicle.
Private.RegisterSchematic("UnitForge::PlayerInVehicle", "Legacy", {
	-- Create layered scaffold frames.
	-- These are used to house the other widgets and elements.
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
				parent = "self", ownerKey = "PowerBorderScaffold", objectType = "Frame", objectSubType = "Frame",
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
					"SetSize", { 24+16, 64+16 }, "SetHitBox", { -4, -4, -4, -4 },
					"Place", { "BOTTOMRIGHT", "UICenter", "BOTTOM", -162 -12, 29-10 }
				},
				values = {
					"colors", Colors,
					"visibilityOverrideDriver", "[vehicleui][overridebar][possessbar][shapeshift]show;hide",
					"unitOverrideDriver", "[nooverridebar,vehicleui]pet;[overridebar,@vehicle,exists]vehicle;player"
				}
			},
			-- Setup backdrops and borders
			{
				parent = nil, ownerKey = "BorderScaffold", objectType = "Frame", 
				chain = {
					"SetBackdrop", {{ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 24 }},
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 },
					"ClearAllPoints", "SetPoint", { "TOPLEFT", -11, 11 }, "SetPoint", { "BOTTOMRIGHT", 11, -11 }
				}

			},
			{
				parent = nil, ownerKey = "PowerBorderScaffold", objectType = "Frame", 
				chain = {
					"SetBackdrop", {{ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 24 }},
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 },
					"Place", { "BOTTOMLEFT", "UICenter", "BOTTOM", 162-11 + 4 +12, 29-11-10 },
					"SetSize", { 24+16+11*2, 64+16+11*2 }
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
					"SetOrientation", "UP",
					"SetFlippedHorizontally", false,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 2, 
					"SetPosition", { "TOPLEFT", 8, -8 }, -- relative to unit frame
					"SetSize", { 24, 64 }, 
					"SetStatusBarTexCoord", { 1,0, 0,0, 1,1, 0,1 }, -- ULx,ULy,LLx,LLy,URx,URy,LRx,LRy
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
					"SetSize", { 24, 64 },
					"SetTexture", GetMedia("statusbar-dark"),
					"SetTexCoord", { 1,0, 0,0, 1,1, 0,1 }, -- ULx,ULy,LLx,LLy,URx,URy,LRx,LRy
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
					"SetSize", { 24, 64 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 0, 1, 0, 1 }
				}
			},

			-- Health Bar Value
			{
				parent = "self,Health", parentKey = "ValuePercent", objectType = "FontString", 
				chain = {
					"SetPosition", { "TOP", 0, 30 },
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "CENTER", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(18,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .5 },
					"SetParentToOwnerKey", "OverlayScaffold"
				},
				values = {
					"useSmartValue", true,
					"PostUpdate", function(self, unit, min, max)
						if (min == max) then
							self:SetAlpha(.25)
						else
							self:SetAlpha(.5)
						end
					end
				}
			},
			
			-- Health Bar Overlay Cast Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Cast", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "UP",
					"SetFlippedHorizontally", false,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 4, -- should be 2 higher than the health 
					"SetPosition", { "TOPLEFT", 8, -8 }, -- relative to unit frame
					"SetSize", { 24, 64 }, -- 18
					"SetStatusBarTexCoord", { 1,0, 0,0, 1,1, 0,1 }, -- ULx,ULy,LLx,LLy,URx,URy,LRx,LRy
					"SetStatusBarTexture", GetMedia("statusbar-power"),
					"SetStatusBarColor", { 1, 1, 1, .25 }
				}
			},

			-- Power Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Power", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "UP",
					"SetFlippedHorizontally", false,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 2, 
					"SetSize", { 24, 64 }, 
					"SetPosition", { "TOPLEFT", 376 +24, -8 }, -- relative to unit frame
					"SetStatusBarTexCoord", { 1,0, 0,0, 1,1, 0,1 }, -- ULx,ULy,LLx,LLy,URx,URy,LRx,LRy
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
					"SetSize", { 24, 64 },
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
					"SetSize", { 24, 64 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 0, 1, 0, 1 }
				}
			},

			-- Power Bar Value
			{
				parent = "self,Power", parentKey = "ValuePercent", objectType = "FontString", 
				chain = {
					"SetPosition", { "TOP", 0, 30 },
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "CENTER", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(18,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .5 },
					"SetParentToOwnerKey", "OverlayScaffold"
				},
				values = {
					"PostUpdate", function(self, unit, min, max)
						if (min == max) then
							self:SetAlpha(.25)
						else
							self:SetAlpha(.5)
						end
					end
				}
			}

		}
	}
})

-- TODO!
-- Applied to the target frame only visible while in a vehicle, and with a target.
Private.RegisterSchematic("UnitForge::PlayerInVehicleTarget", "Legacy", {
})

-- Applied to the target of target frame.
Private.RegisterSchematic("UnitForge::ToT", "Legacy", {
	-- Create layered scaffold frames.
	-- These are used to house the other widgets and elements.
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
					"SetSize", { 158, 43 }, "SetHitBox", { -4, -4, -4, -4 },
					"Place", { "BOTTOMLEFT", "UICenter", "BOTTOM", 210, 250 - 43 - 4 }
				},
				values = {
					"colors", Colors,

					-- Same predriver as most frames, to ensure they are hidden in vehicle situations.
					"visibilityPreDriver", "[canexitvehicle,novehicleui][vehicleui][overridebar][possessbar][shapeshift]hide;"
				}
			},
			-- Setup backdrop and border
			{
				parent = nil, ownerKey = "BorderScaffold", objectType = "Frame", 
				chain = {
					"SetBackdrop", {{ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 32 }},
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 },
					"ClearAllPoints", "SetPoint", { "TOPLEFT", -15, 15 }, "SetPoint", { "BOTTOMRIGHT", 15, -15 }
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
					"SetSize", { 142, 27 }, 
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
					"SetSize", { 142, 27 },
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
					"SetSize", { 142, 27 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 0, 1, 0, 1 }
				}
			},

			-- Health Bar Value
			{
				parent = "self,Health", parentKey = "Value", objectType = "FontString", 
				chain = {
					"SetPosition", { "LEFT", 8, 1 }, -- Relative to the health bar
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "LEFT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(12,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetParentToOwnerKey", "OverlayScaffold"
				},
				values = {
					"useSmartValue", true
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
					"SetSize", { 142, 27 }, 
					"SetStatusBarTexture", GetMedia("statusbar-power"),
					"SetStatusBarColor", { 1, 1, 1, .25 }
				}
			},

			-- Unit Name
			{
				parent = "self,OverlayScaffold", ownerKey = "Name", objectType = "FontString", 
				chain = {
					"SetPosition", { "RIGHT", -16, 1 }, -- relative to the whole frame (with border)
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "RIGHT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(11, true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetSize", { 80, 14 }, 
				},
				values = {
					"maxChars", 8,
					"showLevel", false,
					"showLevelLast", false,
					"useSmartName", true
				}

			}

		}
	}
})

-- Applied to the player's pet frame.
Private.RegisterSchematic("UnitForge::Pet", "Legacy", {
	-- Create layered scaffold frames.
	-- These are used to house the other widgets and elements.
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
					"SetSize", { 158, 43 }, "SetHitBox", { -4, -4, -4, -4 },
					"Place", { "BOTTOMRIGHT", "UICenter", "BOTTOM", -210, 250 - 43 - 4 }
				},
				values = {
					"colors", Colors,

					-- Same predriver as most frames, to ensure they are hidden in vehicle situations.
					"visibilityPreDriver", "[canexitvehicle,novehicleui][vehicleui][overridebar][possessbar][shapeshift]hide;"
				}
			},
			-- Setup backdrop and border
			{
				parent = nil, ownerKey = "BorderScaffold", objectType = "Frame", 
				chain = {
					"SetBackdrop", {{ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 32 }},
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 },
					"ClearAllPoints", "SetPoint", { "TOPLEFT", -15, 15 }, "SetPoint", { "BOTTOMRIGHT", 15, -15 }
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
					"SetSize", { 142, 27 }, 
					"SetStatusBarTexture", GetMedia("statusbar-power")
				},
				values = {
					"colorAbsorb", true, -- tint absorb overlay
					"colorClass", true, -- color players by class 
					"colorPetAsPlayer", true, 
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
					"SetSize", { 142, 27 },
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
					"SetSize", { 142, 27 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 0, 1, 0, 1 }
				}
			},

			-- Health Bar Value
			{
				parent = "self,Health", parentKey = "Value", objectType = "FontString", 
				chain = {
					"SetPosition", { "RIGHT", -8, 1 }, -- Relative to the health bar
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "RIGHT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(12,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetParentToOwnerKey", "OverlayScaffold"
				},
				values = {
					"useSmartValue", true
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
					"SetSize", { 142, 27 }, 
					"SetStatusBarTexture", GetMedia("statusbar-power"),
					"SetStatusBarColor", { 1, 1, 1, .25 }
				}
			},

			-- Unit Name
			{
				parent = "self,OverlayScaffold", ownerKey = "Name", objectType = "FontString", 
				chain = {
					"SetPosition", { "LEFT", 16, 1 }, -- relative to the whole frame (with border)
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "LEFT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(11, true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetSize", { 80, 14 }, 
				},
				values = {
					"maxChars", 8,
					"showLevel", false,
					"showLevelLast", false,
					"useSmartName", true
				}

			}

		}
	}
})

-- Party frames.
local PARTY_SLOT_ID = 0
Private.RegisterSchematic("UnitForge::Party", "Legacy", {
	
	-- Create layered scaffold frames.
	-- These are used to house the other widgets and elements.
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
					"SetSize", { 198, 55 }, "SetHitBox", { -4, -4, -4, -4 },
					"Position", {}
				},
				-- Note that values are added before the chain is executed, 
				-- so the above chain can call methods defined in the values here.
				values = {
					"colors", Colors,

					-- Fade out frames out of range
					"Range", { outsideAlpha = .6 },

					-- Exclude these frames from explorer mode
					"ignoreExplorerMode", true,

					-- Driver to only show this in non-raid parties, but never solo.
					--"visibilityPreDriver", "[group:party,nogroup:raid]show;hide;"

					-- Incremental positioning function.
					-- Will move a slot down each time it's called.
					"Position", function(self)
						local unit = self.unit
						if (not unit) then 
							return 
						end
						local slot
						if (unit:find("party")) then
							slot = self.id or PARTY_SLOT_ID
						else
							slot = PARTY_SLOT_ID
						end
						PARTY_SLOT_ID = PARTY_SLOT_ID + 1
						self:Place("TOPLEFT", "UICenter", "TOPLEFT", 48 + 8, -(64 + (55 + 4+30+4+20)*slot))
					end
				}
			},
			-- Setup backdrop and border
			{
				parent = nil, ownerKey = "BorderScaffold", objectType = "Frame", 
				chain = {
					"SetBackdrop", {{ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 32 }},
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 },
					"ClearAllPoints", "SetPoint", { "TOPLEFT", -15, 15 }, "SetPoint", { "BOTTOMRIGHT", 15, -15 }
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
					"SetSize", { 182, 31 }, 
					"SetStatusBarTexture", GetMedia("statusbar-power")
				},
				values = {
					"colorAbsorb", true, -- tint absorb overlay
					"colorClass", true, -- color players by class 
					"colorDisconnected", true, -- color disconnected units
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
					"SetSize", { 182, 31 },
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
					"SetSize", { 182, 31 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 0, 1, 0, 1 }
				}
			},

			-- Health Bar Value
			{
				parent = "self,Health", parentKey = "Value", objectType = "FontString", 
				chain = {
					"SetPosition", { "RIGHT", -8, 0 }, -- Relative to the health bar
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "RIGHT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(12,true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetParentToOwnerKey", "OverlayScaffold"
				},
				values = {
					"useSmartValue", true
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
					"SetSize", { 182, 27 }, 
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
					"SetSize", { 182, 8 }, 
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
					"SetSize", { 182, 8 },
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
					"SetSize", { 182, 8 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 0, 1, 0, 1 }
				}
			},

			-- Unit Name
			{
				parent = "self,OverlayScaffold", ownerKey = "Name", objectType = "FontString", 
				chain = {
					"SetPosition", { "LEFT", 16, 4 }, -- relative to the whole frame (with border)
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "LEFT", 
					"SetJustifyV", "MIDDLE",
					"SetFontObject", GetFont(11, true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
					"SetSize", { 80, 14 }, 
				},
				values = {
					"maxChars", 12,
					"showLevel", true,
					"showLevelLast", false,
					"useSmartName", true
				}

			},

			-- Auras
			{
				parent = "self,ContentScaffold", ownerKey = "Auras", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetSize", { 28*6 + 4*5 + 2, 30 },
					"SetPoint", { "TOPLEFT", 4, -55 - 8 +2 }
				},
				values = {
					"auraSize", 28, 
					"auraWidth", false, 
					"auraHeight", false,
					"customSort", Aura_SortPrimary,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"filter", false, 
					"filterBuffs", "PLAYER HELPFUL", 
					"filterDebuffs", false, 
					"func", false, 
					"funcBuffs", false,
					"funcDebuffs", false,
					"growthX", "RIGHT", 
					"growthY", "DOWN", 
					"maxBuffs", false, 
					"maxDebuffs", false, 
					"maxVisible", 6, 
					"showDurations", true, 
					"showSpirals", false, 
					"showLongDurations", true,
					"spacingH", 4, 
					"spacingV", 4, 
					"tooltipAnchor", false,
					"tooltipDefaultPosition", false, 
					"tooltipOffsetX", 8,
					"tooltipOffsetY", -16,
					"tooltipPoint", "TOPLEFT",
					"tooltipRelPoint", "BOTTOMLEFT",
					"PostCreateButton", Aura_PostCreate,
					"PostUpdateButton", Aura_PostUpdate
					
				}
			}

		}
	},

	-- Create child widgets
	IsRetail and {
		type = "CreateWidgets",
		widgets = {
			-- Group Role
			{
				parent = "self,OverlayScaffold", ownerKey = "GroupRole", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetPosition", { "TOP", 0, 12 }, -- relative to unit frame
					"SetSize", { 32, 32 }
				}
			},

			{
				parent = "self,GroupRole", parentKey = "Healer", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetSize", { 32, 32 },
					"SetTexture", GetMedia("grouprole-icons-heal")
				}
			},

			{
				parent = "self,GroupRole", parentKey = "Tank", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetSize", { 32, 32 },
					"SetTexture", GetMedia("grouprole-icons-tank"),
				}
			},

			{
				parent = "self,GroupRole", parentKey = "Damager", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetSize", { 32, 32 },
					"SetTexture", GetMedia("grouprole-icons-dps")
				}
			}
		}
	} or nil

})

Private.RegisterSchematic("UnitForge::Raid", "Legacy", {


})

Private.RegisterSchematic("UnitForge::Boss", "Legacy", {


})

Private.RegisterSchematic("UnitForge::Arena", "Legacy", {


})
