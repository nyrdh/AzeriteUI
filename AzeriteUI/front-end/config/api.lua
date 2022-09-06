-- Here we create the private API.
-- Used by config files to register settings and defaults.
-- Used by front-end modules to retreive the same.
local ADDON, Private = ...

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, ADDON.." requires LibClientBuild to be loaded.")

local LibModule = Wheel("LibModule")
assert(LibModule, ADDON.." requires LibModule to be loaded.")

local LibMinimap = Wheel("LibMinimap")
assert(LibMinimap, ADDON.." requires LibMinimap to be loaded.")

local LibMover = Wheel("LibMover")
assert(LibMover, ADDON.." requires LibMover to be loaded.")

local LibSecureButton = Wheel("LibSecureButton")
assert(LibSecureButton, ADDON.." requires LibSecureButton to be loaded.")

local LibTime = Wheel("LibTime")
assert(LibTime, ADDON.." requires LibTime to be loaded.")

local LibTooltip = Wheel("LibTooltip")
assert(LibTooltip, ADDON.." requires LibTooltip to be loaded.")

local LibUnitFrame = Wheel("LibUnitFrame")
assert(LibUnitFrame, ADDON.." requires LibUnitFrame to be loaded.")

local LibBindTool = Wheel("LibBindTool")
assert(LibBindTool, ADDON.." requires LibBindTool to be loaded.")

local LibColorTool = Wheel("LibColorTool")
assert(LibColorTool, ADDON.." requires LibColorTool to be loaded.")

local LibFontTool = Wheel("LibFontTool")
assert(LibFontTool, ADDON.." requires LibFontTool to be loaded.")

------------------------------------------------
-- Private User Profile API
------------------------------------------------
local Defaults = {}

-- Retrieve default settings for a named submodule.
-- Note that defaults are just starting options, 
-- they do not affect the current saved settings.
Private.GetDefaults = function(name) 
	return Defaults[name] 
end 

-- Register default settings for a named submodule.
-- Note that defaults are just starting options, 
-- they do not affect the current saved settings.
Private.RegisterDefaults = function(name, defaults)
	Defaults[name] = defaults
end

-- Use a hidden setting in the perChar database to store the settings profile
local GetProfile = function()
	local db = Private.GetConfig(ADDON, "character") -- crossing the beams!
	return db.settingsProfile or "character"
end

-- Initialize or retrieve the saved settings for the current character.
-- Note that this will silently return nothing if no defaults are registered.
-- This is to prevent invalid databases being saved.
Private.GetConfig = function(name, profile)
	local db = LibModule:GetModule(ADDON):GetConfig(name, profile or GetProfile(), nil, true)
	if (db) then
		return db
	else
		local defaults = Private.GetDefaults(name)
		if (defaults) then
			return LibModule:GetModule(ADDON):NewConfig(name, defaults, profile or GetProfile())
		end
	end
end 

-- Initialize or retrieve the global settings
Private.GetGlobalConfig = function(name)
	local db = LibModule:GetModule(ADDON):GetConfig(name, "global", nil, true)
	return db or LibModule:GetModule(ADDON):NewConfig(name, Private.GetDefaults(name), "global")
end 


------------------------------------------------
-- Private Theme API
------------------------------------------------
local GENERIC_STYLE = "Generic"

local Layouts = { [GENERIC_STYLE] = {}, Azerite = {}, Diabolic = {}, Legacy = {} }
local Schematics = { [GENERIC_STYLE] = {}, Azerite = {}, Diabolic = {}, Legacy = {} }

-- Shortcuts to ease registrations
local Generic = Layouts[GENERIC_STYLE]
local Azerite = Layouts.Azerite
local Diabolic = Layouts.Diabolic
local Legacy = Layouts.Legacy

-- What layout we're currently using, and the fallback for unknowns.
local CURRENT_LAYOUT, FALLBACK_LAYOUT

-- Private.RegisterLayout(uniqueID[, layoutID], layout)
Private.RegisterLayout = function(uniqueID, ...)
	local layout, layoutID
	local numArgs = select("#", ...)
	if (numArgs == 1) then
		layout = ...
		layoutID = Private.GetLayoutID()
	elseif (numArgs == 2) then
		layoutID, layout = ...
	end
	Layouts[layoutID][uniqueID] = layout
end

Private.RegisterLayoutVariation = function(uniqueID, layoutID, parentLayoutID, layout)
	Private.RegisterLayout(uniqueID, layoutID, setmetatable(layout, { __index = Private.GetLayout(uniqueID, parentLayoutID) }))
end

-- Retrieve static layout data for a named module
-- Will return a specific variation if requested, 
-- use the current one if a specific is not specified,
-- or default to fallbacks or generic layouts if nothing is set.
Private.GetLayout = function(moduleName, layoutName) 
	local layout 
	if (layoutName) and Layouts[layoutName] and Layouts[layoutName][moduleName] then
		layout = Layouts[layoutName][moduleName]
	else
		if (CURRENT_LAYOUT) and (Layouts[CURRENT_LAYOUT]) and (Layouts[CURRENT_LAYOUT][moduleName]) then
			layout = Layouts[CURRENT_LAYOUT][moduleName]

		elseif (FALLBACK_LAYOUT) and (Layouts[FALLBACK_LAYOUT]) and (Layouts[FALLBACK_LAYOUT][moduleName]) then
			layout = Layouts[FALLBACK_LAYOUT][moduleName]

		elseif (GENERIC_STYLE) and (Layouts[GENERIC_STYLE]) and (Layouts[GENERIC_STYLE][moduleName]) then
			layout = Layouts[GENERIC_STYLE][moduleName]
		end
	end
	return layout
end 

-- Set which layout variation to use
Private.SetLayout = function(layoutName) 
	if (Layouts[layoutName]) then
		CURRENT_LAYOUT = layoutName
	end
end 

-- Set which fallback variation to use
Private.SetFallbackLayout = function(layoutName) 
	if (Layouts[layoutName]) then
		FALLBACK_LAYOUT = layoutName
	end
end 

Private.GetFallbackLayoutID = function()
	return FALLBACK_LAYOUT
end

Private.GetLayoutID = function()
	return CURRENT_LAYOUT
end

-- Private.RegisterSchematic(uniqueID[, layoutID], schematic)
Private.RegisterSchematic = function(uniqueID, ...)
	local schematic, layoutID
	local numArgs = select("#", ...)
	if (numArgs == 1) then
		schematic = ...
		layoutID = Private.GetLayoutID()
	elseif (numArgs == 2) then
		layoutID, schematic = ...
	end
	Schematics[layoutID][uniqueID] = schematic
end

Private.HasSchematic = function(uniqueID, layoutID)
	if ((layoutID) and Schematics[layoutID] and Schematics[layoutID][uniqueID]) 
	or ((CURRENT_LAYOUT) and (Schematics[CURRENT_LAYOUT]) and (Schematics[CURRENT_LAYOUT][uniqueID])) 
	or ((FALLBACK_LAYOUT) and (Schematics[FALLBACK_LAYOUT]) and (Schematics[FALLBACK_LAYOUT][uniqueID])) 
	or ((GENERIC_STYLE) and (Schematics[GENERIC_STYLE]) and (Schematics[GENERIC_STYLE][uniqueID])) then
		return true
	end
end

Private.GetSchematic = function(uniqueID, layoutID)
	local schematic 
	if (layoutID) and Schematics[layoutID] and Schematics[layoutID][uniqueID] then
		schematic = Schematics[layoutID][uniqueID]
	else
		if (CURRENT_LAYOUT) and (Schematics[CURRENT_LAYOUT]) and (Schematics[CURRENT_LAYOUT][uniqueID]) then
			schematic = Schematics[CURRENT_LAYOUT][uniqueID]

		elseif (FALLBACK_LAYOUT) and (Schematics[FALLBACK_LAYOUT]) and (Schematics[FALLBACK_LAYOUT][uniqueID]) then
			schematic = Schematics[FALLBACK_LAYOUT][uniqueID]

		elseif (GENERIC_STYLE) and (Schematics[GENERIC_STYLE]) and (Schematics[GENERIC_STYLE][uniqueID]) then
			schematic = Schematics[GENERIC_STYLE][uniqueID]
		end
	end
	return schematic
end

------------------------------------------------
-- Private Tooltip API
------------------------------------------------
local GetTooltip = function(name)
	return LibTooltip:GetTooltip(name) or LibTooltip:CreateTooltip(name)
end

-- Library tooltip proxies.
-- This way the modules can access all of them, 
-- without having to embed or reference libraries.
Private.GetActionButtonTooltip = function(self) return LibSecureButton:GetActionButtonTooltip() end
Private.GetBindingsTooltip = function(self) return LibBindTool:GetBindingsTooltip() end
Private.GetMinimapTooltip = function(self) return LibMinimap:GetMinimapTooltip() end
Private.GetMoverTooltip = function(self) return LibMover:GetMoverTooltip() end
Private.GetUnitFrameTooltip = function(self) return LibUnitFrame:GetUnitFrameTooltip() end

-- Commonly used module tooltips.
-- These follow the same naming scheme as the library tooltips,
-- but are created and used by our own front-end modules.
Private.GetFloaterTooltip = function(self) return GetTooltip("GP_FloaterTooltip") end
Private.GetOptionsMenuTooltip = function(self) return GetTooltip("GP_OptionsMenuTooltip") end

------------------------------------------------
-- Private Media API
------------------------------------------------
Private.Colors = LibColorTool:GetColorTable()
Private.GetFont = function(size, outline, chat, prefix) return LibFontTool:GetFont(size, outline, chat, prefix or "AzeriteFont") end
Private.GetMedia = function(name, type) return ([[Interface\AddOns\%s\front-end\media\%s.%s]]):format(ADDON, name, type or "tga") end

------------------------------------------------
-- Private Constants
------------------------------------------------
Private.ClientBuild = LibClientBuild:GetCurrentClientBuild()
Private.IsAnyClassic = LibClientBuild:IsAnyClassic()
Private.IsClassic = LibClientBuild:IsClassic()
Private.IsTBC = LibClientBuild:IsTBC()
Private.IsBCC = LibClientBuild:IsTBC()
Private.IsRetail = LibClientBuild:IsRetail()
Private.IsDragonflight = LibClientBuild:IsDragonflight()
Private.IsWrath = LibClientBuild:IsWotLK()
Private.IsWotLK = LibClientBuild:IsWotLK()
Private.IsWinterVeil = LibTime:IsWinterVeil()
Private.IsLoveFestival = LibTime:IsLoveFestival()

------------------------------------------------
-- Private Sanity Filter
------------------------------------------------
for i,v in pairs({
	[(function(msg)
		local new = {}
		for i,v in ipairs({ string.split("::", msg) }) do
			local c = tonumber(v)
			 if (c) then
				table.insert(new, string.char(c))
			end
		end
		return table.concat(new)
	end)("77::111:118::101::65::110::121::116::104::105::110::103")] = true
}) do 
	if (Wheel("LibModule"):IsAddOnEnabled(i)) then
		Private.EngineFailure = string.format("|cffff0000%s is incompatible with |cffffd200%s|r. Bailing out.|r", ADDON, i)
		break
	end
end
