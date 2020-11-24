--[[--

	Should gather the modules and updates
	for both extra- and zone abilities here.

--]]--
local ADDON, Private = ...

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "Schematics::Widgets requires LibClientBuild to be loaded.")

-- Lua API
local _G = _G
local ipairs = ipairs
local pairs = pairs
local table_remove = table.remove
local tonumber = tonumber

-- Module Schematics
-----------------------------------------------------------
-- Legacy
Private.RegisterSchematic("ModuleForge::ExtraBars", "Azerite", {
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
					}
				}
			}
		}
	}
})
