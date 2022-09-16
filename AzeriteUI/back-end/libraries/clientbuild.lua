local LibClientBuild = Wheel:Set("LibClientBuild", 52)
if (not LibClientBuild) then
	return
end

-- Lua API
local pairs = pairs
local select = select
local string_match = string.match
local string_split = string.split
local tonumber = tonumber
local tostring = tostring

LibClientBuild.embeds = LibClientBuild.embeds or {}

local currentClientPatch, currentClientBuild, _, clientVersion = GetBuildInfo()
currentClientBuild = tonumber(currentClientBuild)

-- Let's create some constants for faster lookups
local VERSION = clientVersion
local MAJOR,MINOR,PATCH = string_split(".", currentClientPatch)
MAJOR = tonumber(MAJOR)
MINOR = tonumber(MINOR)

local IsClassic, IsTBC, IsWotLK
local IsRetail, IsRetailBFA, IsRetailShadowlands, IsRetailDragonflight

IsClassic = MAJOR == 1
IsTBC = MAJOR == 2
IsWotLK = MAJOR == 3
IsRetail = MAJOR >= 9
IsRetailBFA = MAJOR == 8
IsRetailShadowlands = MAJOR == 9
IsRetailDragonflight = MAJOR == 10

local builds = {}

-- Patch to build
builds["1.13.2"] 	= 31446
builds["1.13.3"] 	= 33526
builds["1.13.4"] 	= 34219
builds["2.5.1"] 	= 38707
builds["8.0.1"] 	= 27101
builds["8.1.0"] 	= 29600
builds["8.1.5"] 	= 29704
builds["8.2.0"] 	= 30920
builds["8.2.0"] 	= 31229
builds["8.2.5"] 	= 31960
builds["8.3.0"] 	= 34220
builds["8.3.7"] 	= 35662
builds["9.0.1"] 	= 36577
builds["9.0.2"] 	= 37474
builds["9.0.5"] 	= 37988

-- Metas
builds["Classic"] 	= builds["1.13.7"]
builds["TBC"] 		= builds["2.5.1"]
builds["Retail"] 	= builds["8.3.0"]

-- Returns true if we're on a classic patch
LibClientBuild.IsClassic = function(self)
	return IsClassic
end

-- Returns true if we're on a classic TBC patch
LibClientBuild.IsTBC = function(self)
	return IsTBC
end
LibClientBuild.IsBCC = LibClientBuild.IsTBC

-- Returns true if we're on a classic WotLK patch
LibClientBuild.IsWotLK = function(self)
	return IsWotLK
end
LibClientBuild.IsWrath = LibClientBuild.IsWotLK

-- Returns true if we're on any classic patch
LibClientBuild.IsAnyClassic = function(self)
	return IsClassic or IsTBC or IsWotLK
end

-- Returns true if we're on a retail patch
LibClientBuild.IsRetail = function(self)
	return IsRetail
end

-- Returns true if we're on a retail BFA patch
LibClientBuild.IsRetailBFA = function(self)
	return IsRetailBFA
end

-- Returns true if we're on a retail Shadowlands patch
LibClientBuild.IsRetailShadowlands = function(self)
	return IsRetailShadowlands
end

-- Returns true if we're on a retail Dragonflight patch
LibClientBuild.IsRetailDragonflight = function(self)
	return IsRetailDragonflight
end
LibClientBuild.IsDragonflight = LibClientBuild.IsRetailDragonflight

-- Return the build number for a given patch.
-- Return current build if the given patch is the current. EXPERIMENTAL!
LibClientBuild.GetClientBuildByPatch = function(self, patch)
	return (currentClientPatch == patch) and currentClientBuild or builds[patch]
end

-- Return the current full patch version as string
LibClientBuild.GetCurrentClientPatch = function(self)
	return currentClientPatch
end

-- Return the current TOC version as a number
LibClientBuild.GetCurrentClientVersion = function(self)
	return VERSION
end

-- Return the current WoW MAJOR version as a number
LibClientBuild.GetCurrentClientVersionMajor = function(self)
	return MAJOR
end

-- Return the current WoW MINOR version as a number
LibClientBuild.GetCurrentClientVersionMinor = function(self)
	return MINOR
end

-- Return the current WoW PATCH version as a string
-- *note that this is not the full patch version,
--  so for WoW Classic "1.13.7" this would return "7".
LibClientBuild.GetCurrentClientVersionPatch = function(self)
	return PATCH
end

-- Return the current WoW client build as a number
LibClientBuild.GetCurrentClientBuild = function(self)
	return currentClientBuild
end


-- Module embedding
local embedMethods = {
	IsAnyClassic = true,
	IsClassic = true,
	IsTBC = true, IsBCC = true,
	IsWotLK = true, IsWrath = true,
	IsRetail = true,
	IsRetailBFA = true,
	IsRetailShadowlands = true,
	IsRetailDragonflight = true, IsDragonflight = true,
	GetClientBuildByPatch = true,
	GetCurrentClientBuild = true,
	GetCurrentClientPatch = true,
	GetCurrentClientVersion = true,
	GetCurrentClientVersionMajor = true,
	GetCurrentClientVersionMinor = true,
	GetCurrentClientVersionPatch = true
}

LibClientBuild.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibClientBuild.embeds) do
	LibClientBuild:Embed(target)
end
