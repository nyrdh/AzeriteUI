--[[--

	The purpose of this file is to provide
	forges for the root modules.

--]]--
local ADDON, Private = ...

-- Private API
local Colors = Private.Colors
local GetAuraFilter = Private.GetAuraFilter
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia
local GetSchematic = Private.GetSchematic

-- Utility Functions
-----------------------------------------------------------




-- Schematics
-----------------------------------------------------------
Private.RegisterSchematic("ModuleForge::Root", "Generic", {
	OnInit = {},
	OnEnable = {
		{
			type = "ExecuteMethods",
			methods = {
				{
					repeatAction = {
						method = "DisableUIWidget",
						arguments = {
							"ActionBars",
							"Auras",
							"BuffTimer", -- Retail
							"CaptureBar", -- Retail. Also contains Azshara Ancient Wards.
							"CastBars",
							"Chat",
							"Durability",
							"Minimap",
							"OrderHall",
							"ObjectiveTracker", -- Retail
							"PlayerPowerBarAlt", -- Retail
							"QuestWatchFrame", -- Classic
							"TotemFrame", -- Retail
							"Tutorials",
							"UnitFramePlayer",
							"UnitFramePet",
							"UnitFrameTarget",
							"UnitFrameToT",
							"UnitFrameFocus", -- Retail
							"UnitFrameParty",
							"UnitFrameRaid",
							"UnitFrameBoss", -- Retail
							"UnitFrameArena", -- Classic TBC, Retail
							"ZoneText"						
						}
					}
				},
				{
					repeatAction = {
						method = "DisableUIMenuPage",
						arguments = {
							-- pageID, globalName
							{ 5, "InterfaceOptionsActionBarsPanel" },
							{ 10, "CompactUnitFrameProfiles" }					
						}
					}
				},
				{
					repeatAction = {
						method = "DisableUIMenuOption",
						arguments = {
							-- shrinkOption, globalName
							{ true, "InterfaceOptionsCombatPanelTargetOfTarget" },
							IsRetail and { "Vertical", "InterfaceOptionsNamesPanelUnitNameplatesPersonalResourceOnEnemy" } or nil
						}
					}
				}
			}
		}
	}
})

Private.RegisterSchematic("ModuleForge::Root", "Azerite", {
	OnInit = {},
	OnEnable = {
		{
			type = "ExecuteMethods",
			methods = {
				{
					repeatAction = {
						method = "DisableUIWidget",
						arguments = {
							"ActionBars",
							"Auras",
							"BuffTimer", -- Retail
							--"CaptureBar", -- Retail. Also contains Azshara Ancient Wards.
							"CastBars",
							"Chat",
							"Durability",
							"Minimap",
							"OrderHall",
							--"ObjectiveTracker", -- Retail
							"PlayerPowerBarAlt", -- Retail
							--"QuestWatchFrame", -- Classic
							--"TotemFrame", -- Retail
							"Tutorials",
							"UnitFramePlayer",
							"UnitFramePet",
							"UnitFrameTarget",
							"UnitFrameToT",
							"UnitFrameFocus", -- Retail
							"UnitFrameParty",
							"UnitFrameRaid",
							"UnitFrameBoss", -- Retail
							"UnitFrameArena", -- Classic TBC, Retail
							--"Warnings",
							"ZoneText"						
						}
					}
				},
				{
					repeatAction = {
						method = "DisableUIMenuPage",
						arguments = {
							-- pageID, globalName
							{ 5, "InterfaceOptionsActionBarsPanel" },
							{ 10, "CompactUnitFrameProfiles" }					
						}
					}
				},
				{
					repeatAction = {
						method = "DisableUIMenuOption",
						arguments = {
							-- shrinkOption, globalName
							{ true, "InterfaceOptionsCombatPanelTargetOfTarget" },
							IsRetail and { "Vertical", "InterfaceOptionsNamesPanelUnitNameplatesPersonalResourceOnEnemy" } or nil
						}
					}
				}
			}
		}
	}
})

Private.RegisterSchematic("ModuleForge::Root", "Legacy", {
	OnInit = {
		{
			type = "ExecuteMethods",
			methods = {
				{
					chain = {
						"SetObjectFadeDurationOut", .15,
						"SetObjectFadeHold", .5
					}
				}
			}
		}
	},
	OnEnable = {
		{
			type = "ExecuteMethods",
			methods = {
				{
					repeatAction = {
						method = "DisableUIWidget",
						arguments = {
							"ActionBars",
							"Auras",
							"BuffTimer", -- Retail
							--"CaptureBar", -- Retail. Also contains Azshara Ancient Wards.
							"CastBars",
							"Chat",
							"Durability",
							"Minimap",
							"OrderHall",
							--"ObjectiveTracker", -- Retail
							"PlayerPowerBarAlt", -- Retail
							--"QuestWatchFrame", -- Classic
							--"TotemFrame", -- Retail
							"Tutorials",
							"UnitFramePlayer",
							"UnitFramePet",
							"UnitFrameTarget",
							"UnitFrameToT",
							"UnitFrameFocus", -- Retail
							"UnitFrameParty",
							"UnitFrameRaid",
							"UnitFrameBoss", -- Retail
							"UnitFrameArena", -- Classic TBC, Retail
							--"Warnings",
							"ZoneText"						
						}
					}
				},
				{
					repeatAction = {
						method = "DisableUIMenuPage",
						arguments = {
							-- pageID, globalName
							{ 5, "InterfaceOptionsActionBarsPanel" },
							{ 10, "CompactUnitFrameProfiles" }					
						}
					}
				},
				{
					repeatAction = {
						method = "DisableUIMenuOption",
						arguments = {
							-- shrinkOption, globalName
							{ true, "InterfaceOptionsCombatPanelTargetOfTarget" },
							IsRetail and { "Vertical", "InterfaceOptionsNamesPanelUnitNameplatesPersonalResourceOnEnemy" } or nil
						}
					}
				}
			}
		}
	}
})
