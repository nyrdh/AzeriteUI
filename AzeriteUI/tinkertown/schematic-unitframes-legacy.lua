--[[--

	The purpose of this file is to provide
	forges for the various unitframes.

--]]--
local ADDON, Private = ...

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "Schematics::Widgets requires LibClientBuild to be loaded.")

local LibTime = Wheel("LibTime")
assert(LibTime, "UnitFrames requires LibTime to be loaded.")

-- Lua API
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local string_format = string.format

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
			button.Border:SetBackdropBorderColor(Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3)
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
	local desaturate
	if (element.isYou) then
		-- Desature buffs on you cast by others
		if (button.isBuff) and (not button.isCastByPlayer) then 
			desaturate = true
		end
	elseif (element.isFriend) then
		-- Desature buffs on friends not cast by you
		if (button.isBuff) and (not button.isCastByPlayer) then 
			desaturate = true
		end
	else
		-- Desature debuffs not cast by you on attackable units
		if (not button.isBuff) and (not button.isCastByPlayer) then 
			desaturate = true
		end
	end

	if (desaturate) then
		button.Icon:SetDesaturated(true)
		button.Icon:SetVertexColor(.5, .5, .5)
	else
		button.Icon:SetDesaturated(false)
		button.Icon:SetVertexColor(1, 1, 1)
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
							{ "pet", "Pet" }, 
							--{ "focus", "Focus" }, 

							{ "target", "Target" },
							{ "targettarget", "ToT" },

							{ "vehicle", "PlayerInVehicle" }, 
							-- { "target", "PlayerInVehicleTarget" },

							{ "party1", "Party" },
							{ "party2", "Party" },
							{ "party3", "Party" }, 
							{ "party4", "Party" },

							{ "raid1",  "Raid" }, { "raid2",  "Raid" }, { "raid3",  "Raid" }, { "raid4",  "Raid" }, { "raid5",  "Raid" },
							{ "raid6",  "Raid" }, { "raid7",  "Raid" }, { "raid8",  "Raid" }, { "raid9",  "Raid" }, { "raid10", "Raid" },
							{ "raid11", "Raid" }, { "raid12", "Raid" }, { "raid13", "Raid" }, { "raid14", "Raid" }, { "raid15", "Raid" },
							{ "raid16", "Raid" }, { "raid17", "Raid" }, { "raid18", "Raid" }, { "raid19", "Raid" }, { "raid20", "Raid" },
							{ "raid21", "Raid" }, { "raid22", "Raid" }, { "raid23", "Raid" }, { "raid24", "Raid" }, { "raid25", "Raid" },
							{ "raid26", "Raid" }, { "raid27", "Raid" }, { "raid28", "Raid" }, { "raid29", "Raid" }, { "raid30", "Raid" },
							{ "raid31", "Raid" }, { "raid32", "Raid" }, { "raid33", "Raid" }, { "raid34", "Raid" }, { "raid35", "Raid" },
							{ "raid36", "Raid" }, { "raid37", "Raid" }, { "raid38", "Raid" }, { "raid39", "Raid" }, { "raid40", "Raid" },


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
						end,

						"OnEvent", function(self, event, ...)
							if (event == "GP_AURA_FILTER_MODE_CHANGED") then 
								for frame,unit in pairs(self.Frames) do
									local auras = frame.Auras
									if (auras) then
										local filterMode = ...
										auras.enableSlackMode = filterMode == "slack" or filterMode == "spam"
										auras.enableSpamMode = filterMode == "spam"
										auras:ForceUpdate()
									end
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
						"RegisterMessage", { "GP_AURA_FILTER_MODE_CHANGED", "OnEvent" }
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
					"SetPosition", { "LEFT", 24, 5 },
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

			-- Raid Role (Leader, Assistant, Master Looter, Main Tank, Main Assist)
			{
				parent = "self,OverlayScaffold", ownerKey = "RaidRole", objectType = "Texture", 
				chain = {
					"SetPosition", { "TOPLEFT", 26, 10 },
					"SetDrawLayer", { "OVERLAY", 2 }, 
					"SetSize", { 20, 16 }
				},
				values = {
					"ignoreRaidTargets", true
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
					"customSort", false,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"customFilter", GetAuraFilter("legacy"), 
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
					"customSort", false,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"filter", false, 
					"customFilter", GetAuraFilter("legacy-secondary"), 
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

			-- Raid Target 
			{
				parent = "self,OverlayScaffold", ownerKey = "RaidTarget", objectType = "Texture", 
				chain = {
					"SetPosition", { "TOP", 0, 12 },
					"SetDrawLayer", { "OVERLAY", 2 }, 
					"SetSize", { 30, 30 },
					"SetTexture", GetMedia("raid_target_icons_small")
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
					"customSort", false,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"filter", false, 
					"customFilter", GetAuraFilter("legacy"), 
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
					"customSort", false,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"filter", false, 
					"customFilter", GetAuraFilter("legacy-secondary"), 
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
					"customSort", false,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"filter", false, 
					"customFilter", GetAuraFilter("legacy-secondary"), 
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
					-- Will be chaos and unupdated points if not!
					"PostCreate", {}
					--"PostUpdate", {}
				},
				values = {
					-- These apply to the main element frame.
					"hideFullyWhenEmpty", true, 

					-- These apply to points.
					"alphaEmpty", 1, -- Element alpha when no points are available.
					"alphaNoCombat", 1, -- Element alpha multiplier when out of combat.
					"alphaNoCombatRunes", 1, 
					"alphaWhenHiddenRunes", 1, 
					"hideWhenEmpty", false, -- Whether to fully hide an empty bar or not.
					"hideWhenNoTarget", false, -- Whether to hide when no target exists.
					"hideWhenUnattackable", false, -- Whether to hide when target can't be attacked.
					"useAlternateColoring", true, -- Whether to use multiple point colorings when available.
					"maxComboPoints", 5, -- Does not affect runes, they will always show 6.
					"runeSortOrder", "ASC",	-- Sort order of the runes.
					"flipSide", false, -- Holds no meaning in current theme.

					"backdropMultiplier", .1,

					-- Post creation method called once and only once. 
					-- It is important that we call this prior to the back-end enabling the element, 
					-- as the maximum displayed number of sub-frames is expected to be there for updates. 
					"PostCreate", function(element)
						for i = 1,6 do
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

							element[i] = pill
						end
					end,

					-- Called by the back-end on updates.
					"PostUpdate", function(element, unit, min, max, newMax, powerType)
						if (not min) or (not max) or (not powerType) then
							element:Hide()
							return
						end

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

							-- Figure out pill sizes
							local elementWidth,elementHeight = element:GetSize()
							local width = math_floor(elementWidth/currentPillCount)
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

							-- Store the currently displayed pill count
							element.currentPillCount = currentPillCount
						end

						-- Update main element alpha and visibility. 
						-- This will override the visibility set by the back-end.
						-- *ComboPoints fail to get here sometimes? 
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
					"SetSize", { 158, 43 + 8 }, "SetHitBox", { -4, -4, -4, -4 },
					"Place", { "BOTTOMLEFT", "UICenter", "BOTTOM", 210, 250 - 43 - 4 - 8 }
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
					"SetPosition", { "LEFT", 8, 1 -3 }, -- Relative to the health bar
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

			-- Power Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Power", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "LEFT",
					"SetFlippedHorizontally", true,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 2, 
					"SetPosition", { "BOTTOMLEFT", 8, 8 }, -- relative to unit frame
					"SetSize", { 142, 8 }, 
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
					"SetSize", { 142, 8 },
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
					"SetSize", { 142, 8 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 1, 0, 0, 1 }
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

			},

			-- Raid Target 
			{
				parent = "self,OverlayScaffold", ownerKey = "RaidTarget", objectType = "Texture", 
				chain = {
					"SetPosition", { "BOTTOM", 0, -8 },
					"SetDrawLayer", { "OVERLAY", 2 }, 
					"SetSize", { 24, 24 },
					"SetTexture", GetMedia("raid_target_icons_small")
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
					"SetSize", { 158, 43 + 8 }, "SetHitBox", { -4, -4, -4, -4 },
					"Place", { "BOTTOMRIGHT", "UICenter", "BOTTOM", -210, 250 - 43 - 4 -8 }
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
					"SetPosition", { "RIGHT", -8, 1 -3 }, -- Relative to the health bar
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

			-- Power Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Power", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "RIGHT",
					"SetFlippedHorizontally", false,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 2, 
					"SetPosition", { "BOTTOMRIGHT", -8, 8 }, -- relative to unit frame
					"SetSize", { 142, 8 }, 
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
					"SetSize", { 142, 8 },
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
					"SetPosition", { "BOTTOMLEFT", 0, 0 },
					"SetSize", { 142, 8 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 1, 0, 0, 1 }
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

			},

			-- Raid Target 
			{
				parent = "self,OverlayScaffold", ownerKey = "RaidTarget", objectType = "Texture", 
				chain = {
					"SetPosition", { "BOTTOM", 0, -8 },
					"SetDrawLayer", { "OVERLAY", 2 }, 
					"SetSize", { 24, 24 },
					"SetTexture", GetMedia("raid_target_icons_small")
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
					--"visibilityPreDriver", "[group:party,nogroup:raid]show;hide;",

					-- Incremental positioning function.
					-- Will move a slot down each time it's called.
					"Position", function(self)
						local unit = self.unit
						if (not unit) then 
							return 
						end
						PARTY_SLOT_ID = PARTY_SLOT_ID + 1
						self:Place("TOPLEFT", "UICenter", "TOPLEFT", 48 + 8, -(64 + (55 + 4+30+4+20)*(PARTY_SLOT_ID-1)))
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
					"customSort", false,
					"debuffsFirst", false, 
					"disableMouse", false, 
					"filter", "PLAYER", 
					"customFilter", false, 
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
			},

			-- Group Aura
			{
				parent = "self,OverlayScaffold", ownerKey = "GroupAura", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetSize", { 32, 32 },
					"SetPoint", { "RIGHT", 32 + 10, 0 },
					"SetFrameLevelOffset", 10 -- high above the frame
				},
				values = {
					"disableMouse", true, -- disable mouse input, as it will prevent the frame from being clickable.
					"tooltipDefaultPosition", true -- just use the UIs regular tooltip position, don't want it covering frames.
				}
			},

			-- Group Aura backdrop and border
			{
				parent = "self,GroupAura", parentKey = "Border", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetFrameLevelOffset", 2,
					"SetBackdrop", {{ edgeFile = Private.GetMedia("aura_border"), edgeSize = 16 }},
					"SetBackdropBorderColor", { Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3, 1 },
					"ClearAllPoints", "SetPoint", { "TOPLEFT", -7, 7 }, "SetPoint", { "BOTTOMRIGHT", 7, -7 }
				}

			},

			-- Group Aura Icon
			{
				parent = "self,GroupAura", parentKey = "Icon", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetTexCoord", { 5/64, 59/64, 5/64, 59/64 },
					"SetSizeOffset", -10
				}
			},

			-- Group Aura Stack Count
			{
				parent = "self,GroupAura", parentKey = "Count", objectType = "FontString", 
				chain = {
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "RIGHT", 
					"SetJustifyV", "BOTTOM",
					"SetPosition", { "BOTTOMRIGHT", 4, -4 },
					"SetFontObject", Private.GetFont(16, true),
					"SetTextColor", { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
					"SetParentToOwnerKey", "self,GroupAura,Border"
				}
			},

			-- Group Aura Time
			{
				parent = "self,GroupAura", parentKey = "Time", objectType = "FontString", 
				chain = {
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "LEFT", 
					"SetJustifyV", "TOP",
					"SetPosition", { "TOPLEFT", -4, 4 },
					"SetFontObject", Private.GetFont(16, true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .85 },
					"SetParentToOwnerKey", "self,GroupAura,Border"
				}
			},

			-- Raid Target 
			{
				parent = "self,OverlayScaffold", ownerKey = "RaidTarget", objectType = "Texture", 
				chain = {
					"SetPosition", { "BOTTOM", 0, -10 },
					"SetDrawLayer", { "OVERLAY", 2 }, 
					"SetSize", { 28, 28 },
					"SetTexture", GetMedia("raid_target_icons_small")
				}
			},

			-- Raid Role (Leader, Assistant, Master Looter, Main Tank, Main Assist)
			{
				parent = "self,OverlayScaffold", ownerKey = "RaidRole", objectType = "Texture", 
				chain = {
					"SetPosition", { "TOPLEFT", 15, 8 },
					"SetDrawLayer", { "OVERLAY", 2 }, 
					"SetSize", { 20, 16 }
				},
				values = {
					"ignoreRaidTargets", true
				}
			},
			
		}
	},

	-- Create child widgets (Retail only)
	-- Contains: Group Role
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

-- Raid frames.
local RAID_SLOT_ID = 0
Private.RegisterSchematic("UnitForge::Raid", "Legacy", {
	
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
				chain = { -- 198, 55
					"SetSize", { 60+16, 30+16 }, "SetHitBox", { -4, -4, -4, -4 },
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
					--"visibilityPreDriver", "[group:party,nogroup:raid]show;hide;",

					-- Incremental positioning function.
					-- Will move a slot down each time it's called.
					"Position", function(self)
						local unit = self.unit
						if (not unit) then 
							return 
						end

						-- grid positions
						local one,two = RAID_SLOT_ID%5, math_floor(RAID_SLOT_ID/5)

						-- regular sized raids
						-- 5x5, groups grow horizontally, units within groups vertically
						local w,h = 80+16, 38+16
						local x = 56 + two * (w + 10)
						local y = -64 - one * (h + 10)

						-- big classic mess
						-- 5x8, groups grow vertically, units within groups horizontally
						local wChaos,hChaos = 80+16, 28+16
						local xChaos = 56 + one * (wChaos + 10)
						local yChaos = -64 - two * (hChaos + 10)

						RAID_SLOT_ID = RAID_SLOT_ID + 1
						
						local layoutDriver = "[@raid26,exists]chaos;cool"
						if (unit == "player") then
							layoutDriver = "[@target,exists]chaos;cool" -- just for testing
						end
					
						local layoutSwitcher = CreateFrame("Frame", nil, nil, "SecureHandlerAttributeTemplate")
						layoutSwitcher:SetFrameRef("UnitFrame", self)
						layoutSwitcher:SetFrameRef("UICenter", self:GetFrame("UICenter"))
						layoutSwitcher:SetAttribute("_onattributechanged", string_format([=[
							if (name == "state-layout") then
								local frame = self:GetFrameRef("UnitFrame"); 
								local anchor = self:GetFrameRef("UICenter");
								local oldlayout = self:GetAttribute("oldlayout");
								if (not oldlayout) or (oldlayout ~= value) then
									frame:ClearAllPoints();
									if (value == "cool") then
										frame:SetWidth(%d);
										frame:SetHeight(%d);
										frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", %d, %d);
									elseif (value == "chaos") then
										frame:SetWidth(%d);
										frame:SetHeight(%d);
										frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", %d, %d);
									end
									self:SetAttribute("oldlayout", value);
								end
							end	

						]=], w,h,x,y, wChaos,hChaos,xChaos,yChaos))
						RegisterAttributeDriver(layoutSwitcher, "state-layout", layoutDriver)

						layoutSwitcher:SetAttribute("layout", SecureCmdOptionParse(layoutDriver))
				

					end
				}
			},
			{
				parent = nil, ownerKey = "BorderScaffold", objectType = "Frame", objectSubType = "Frame", objectTemplate = BackdropTemplateMixin and "BackdropTemplate",
				chain = {
					"SetBackdrop", {{ edgeFile = GetMedia("tooltip_border_hex_small"), edgeSize = 24 }},
					"SetBackdropBorderColor", { Colors.ui[1], Colors.ui[2], Colors.ui[3], 1 },
					"ClearAllPoints", "SetPoint", { "TOPLEFT", -11, 11 }, "SetPoint", { "BOTTOMRIGHT", 11, -11 }
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
					"SetPoint", { "TOPLEFT", 8, -8 }, -- relative to unit frame
					"SetPoint", { "BOTTOMRIGHT", -8, 8 + 4 },
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
					"SetAllPointsToParent", 
					"SetDrawLayer", { "BACKGROUND", 1 },
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
					"SetAllPointsToParent", 
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 0, 1, 0, 1 }
				}
			},

			-- Health Bar Value
			--{
			--	parent = "self,Health", parentKey = "Value", objectType = "FontString", 
			--	chain = {
			--		"SetPosition", { "BOTTOMRIGHT", -2, 3 }, -- Relative to the health bar
			--		"SetDrawLayer", { "OVERLAY", 1 }, 
			--		"SetJustifyH", "RIGHT", 
			--		"SetJustifyV", "BOTTOM",
			--		"SetFontObject", GetFont(12,true),
			--		"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
			--		"SetParentToOwnerKey", "OverlayScaffold"
			--	},
			--	values = {
			--		"useSmartValue", true
			--	}
			--},
			
			-- Power Bar
			{
				parent = "self,ContentScaffold", ownerKey = "Power", objectType = "Frame", objectSubType = "StatusBar",
				chain = {
					"SetOrientation", "RIGHT",
					"SetFlippedHorizontally", false,
					"SetSmartSmoothing", true,
					"SetFrameLevelOffset", 2, 
					"SetPoint", { "BOTTOMLEFT", 8, 8 }, 
					"SetPoint", { "BOTTOMRIGHT", -8, 8 },
					"SetHeight", 4,
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
					"SetAllPointsToParent", 
					"SetDrawLayer", { "BACKGROUND", -2 },
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
					"SetAllPointsToParent", 
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetTexture", GetMedia("statusbar-normal-overlay"),
					"SetTexCoord", { 0, 1, 0, 1 }
				}
			},

			-- Unit Name
			{
				parent = "self,OverlayScaffold", ownerKey = "Name", objectType = "FontString", 
				chain = {
					--"SetPosition", { "TOPLEFT", 10, -11 }, -- relative to the whole frame (with border)
					"SetPosition", { "TOPLEFT", 12, -12 }, -- relative to the whole frame (with border)
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "LEFT", 
					"SetJustifyV", "TOP",
					"SetFontObject", GetFont(12, true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .75 },
				},
				values = {
					"maxChars", 4,
					"showLevel", false,
					"showLevelLast", false,
					"useSmartName", false
				}

			},

			-- Group Aura
			{
				parent = "self,OverlayScaffold", ownerKey = "GroupAura", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetSize", { 32, 32 },
					"SetPoint", { "CENTER", 0, 2 },
					"SetFrameLevelOffset", 10 -- high above the frame
				},
				values = {
					"disableMouse", true, -- disable mouse input, as it will prevent the frame from being clickable.
					"tooltipDefaultPosition", true -- just use the UIs regular tooltip position, don't want it covering frames.
				}
			},

			-- Group Aura backdrop and border
			{
				parent = "self,GroupAura", parentKey = "Border", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetFrameLevelOffset", 2,
					"SetBackdrop", {{ edgeFile = Private.GetMedia("aura_border"), edgeSize = 16 }},
					"SetBackdropBorderColor", { Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3, 1 },
					"ClearAllPoints", "SetPoint", { "TOPLEFT", -7, 7 }, "SetPoint", { "BOTTOMRIGHT", 7, -7 }
				}

			},

			-- Group Aura Icon
			{
				parent = "self,GroupAura", parentKey = "Icon", objectType = "Texture", 
				chain = {
					"SetDrawLayer", { "ARTWORK", 1 },
					"SetPosition", { "CENTER", 0, 0 },
					"SetTexCoord", { 5/64, 59/64, 5/64, 59/64 },
					"SetSizeOffset", -10
				}
			},

			-- Group Aura Stack Count
			{
				parent = "self,GroupAura", parentKey = "Count", objectType = "FontString", 
				chain = {
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "RIGHT", 
					"SetJustifyV", "BOTTOM",
					"SetPosition", { "BOTTOMRIGHT", -2, 2 },
					"SetFontObject", Private.GetFont(14, true),
					"SetTextColor", { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 },
					"SetParentToOwnerKey", "self,GroupAura,Border"
				}
			},

			-- Group Aura Time
			{
				parent = "self,GroupAura", parentKey = "Time", objectType = "FontString", 
				chain = {
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "LEFT", 
					"SetJustifyV", "TOP",
					"SetPosition", { "TOPLEFT", 0, 0 },
					"SetFontObject", Private.GetFont(12, true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .85 },
					"SetParentToOwnerKey", "self,GroupAura,Border"
				}
			},

			-- Group Number
			{
				parent = "self,OverlayScaffold", ownerKey = "GroupNumber", objectType = "FontString", 
				chain = {
					"SetDrawLayer", { "OVERLAY", 1 }, 
					"SetJustifyH", "LEFT", 
					"SetJustifyV", "BOTTOM",
					"SetPosition", { "BOTTOMLEFT", -4, -1 },
					"SetFontObject", Private.GetFont(12, true),
					"SetTextColor", { Colors.offwhite[1], Colors.offwhite[2], Colors.offwhite[3], .5 }
				}
			},

			-- Raid Target 
			{
				parent = "self,OverlayScaffold", ownerKey = "RaidTarget", objectType = "Texture", 
				chain = {
					"SetPosition", { "BOTTOM", 0, -10 },
					"SetDrawLayer", { "OVERLAY", 2 }, 
					"SetSize", { 28, 28 },
					"SetTexture", GetMedia("raid_target_icons_small")
				}
			},

			-- Raid Role (Leader, Assistant, Master Looter, Main Tank, Main Assist)
			{
				parent = "self,OverlayScaffold", ownerKey = "RaidRole", objectType = "Texture", 
				chain = {
					"SetPosition", { "TOPLEFT", 10, 6 },
					"SetDrawLayer", { "OVERLAY", 2 }, 
					"SetSize", { 16, 12 }
				},
				values = {
					"ignoreRaidTargets", true
				}
			},
			
		}
	},

	-- Create child widgets (Retail only)
	-- Contains: Group Role
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

Private.RegisterSchematic("UnitForge::Boss", "Legacy", {


})

Private.RegisterSchematic("UnitForge::Arena", "Legacy", {


})
