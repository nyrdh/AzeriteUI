--[[--

	The purpose of this file is to provide
	forges for the root modules.

--]]--
local ADDON, Private = ...

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "Schematics::Widgets requires LibClientBuild to be loaded.")

-- WoW client version constants
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Private API
local Colors = Private.Colors
local GetAuraFilter = Private.GetAuraFilter
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia
local GetSchematic = Private.GetSchematic

-- Utility Functions
-----------------------------------------------------------


-- Module Schematics
-----------------------------------------------------------
-- Generic
Private.RegisterSchematic("ModuleForge::Root", "Generic", {
	-- This is called by the module when the module is initialized.
	-- This is typically where we first figure out if it should remain enabled,
	-- then in turn start spawning frames and set up the local environment as needed.
	-- Anything used later on or in the enable method should be defined here.
	OnInit = {},
	-- This is called by the module when the module is enabled.
	-- This is typically where we register events, start timers, etc.
	OnEnable = {
		{
			type = "ExecuteMethods",
			methods = {
				{
					-- A 'repeatAction' is a special type of action
					-- that performs the same method on the self object
					-- multiple times in a row, but varies the parameter 
					-- sent to that method by iterating through the 
					-- 'arguments' list. 
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
					-- A 'repeatAction' is a special type of action
					-- that performs the same method on the self object
					-- multiple times in a row, but varies the parameter 
					-- sent to that method by iterating through the 
					-- 'arguments' list. 
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
					-- A 'repeatAction' is a special type of action
					-- that performs the same method on the self object
					-- multiple times in a row, but varies the parameter 
					-- sent to that method by iterating through the 
					-- 'arguments' list. 
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

-- Azerite
Private.RegisterSchematic("ModuleForge::Root", "Azerite", {
	-- This is called by the module when the module is initialized.
	-- This is typically where we first figure out if it should remain enabled,
	-- then in turn start spawning frames and set up the local environment as needed.
	-- Anything used later on or in the enable method should be defined here.
	OnInit = {},
	-- This is called by the module when the module is enabled.
	-- This is typically where we register events, start timers, etc.
	OnEnable = {
		{
			type = "ExecuteMethods",
			methods = {
				{
					-- A 'repeatAction' is a special type of action
					-- that performs the same method on the self object
					-- multiple times in a row, but varies the parameter 
					-- sent to that method by iterating through the 
					-- 'arguments' list. 
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
					-- A 'repeatAction' is a special type of action
					-- that performs the same method on the self object
					-- multiple times in a row, but varies the parameter 
					-- sent to that method by iterating through the 
					-- 'arguments' list. 
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
					-- A 'repeatAction' is a special type of action
					-- that performs the same method on the self object
					-- multiple times in a row, but varies the parameter 
					-- sent to that method by iterating through the 
					-- 'arguments' list. 
					repeatAction = {
						method = "DisableUIMenuOption",
						arguments = {
							-- shrinkOption, globalName
							{ true, "InterfaceOptionsCombatPanelTargetOfTarget" },

							-- Personal Resource Display settings. 
							-- We're doing this from our own menu now, and provide more settings than Blizzard.
							IsRetail and { "Vertical", "InterfaceOptionsNamesPanelUnitNameplatesPersonalResource"} or nil, 
							IsRetail and { "Vertical", "InterfaceOptionsNamesPanelUnitNameplatesPersonalResourceOnEnemy" } or nil
						}
					}
				}
			}
		}
	}
})

-- Legacy
Private.RegisterSchematic("ModuleForge::Root", "Legacy", {
	-- This is called by the module when the module is initialized.
	-- This is typically where we first figure out if it should remain enabled,
	-- then in turn start spawning frames and set up the local environment as needed.
	-- Anything used later on or in the enable method should be defined here.
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
	-- This is called by the module when the module is enabled.
	-- This is typically where we register events, start timers, etc.
	OnEnable = {
		{
			type = "ExecuteMethods",
			methods = {
				{
					-- A 'repeatAction' is a special type of action
					-- that performs the same method on the self object
					-- multiple times in a row, but varies the parameter 
					-- sent to that method by iterating through the 
					-- 'arguments' list. 
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
					-- A 'repeatAction' is a special type of action
					-- that performs the same method on the self object
					-- multiple times in a row, but varies the parameter 
					-- sent to that method by iterating through the 
					-- 'arguments' list. 
					repeatAction = {
						method = "DisableUIMenuOption",
						arguments = {
							-- shrinkOption, globalName
							{ true, "InterfaceOptionsCombatPanelTargetOfTarget" },

							-- Personal Resource Display settings. 
							-- We're doing this from our own menu now, and provide more settings than Blizzard.
							IsRetail and { "Vertical", "InterfaceOptionsNamesPanelUnitNameplatesPersonalResource"} or nil, 
							IsRetail and { "Vertical", "InterfaceOptionsNamesPanelUnitNameplatesPersonalResourceOnEnemy" } or nil
						}
					}
				}
			}
		}
	}
})
