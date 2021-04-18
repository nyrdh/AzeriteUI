local ADDON, Private = ...

local LibDB = Wheel("LibDB")
assert(LibDB, ADDON.." requires LibDB to be loaded.")

local IsClassic = Private.IsClassic
local IsRetail = Private.IsRetail

------------------------------------------------
-- Module Defaults
------------------------------------------------
-- The purpose of this is to supply all the front-end modules
-- with default settings for all the user configurable choices.
-- 
-- Note that changing these won't change anything for existing characters,
-- they only affect new characters or the first install.
-- I generally advice tinkerers to leave these as they are. 
local RegisterDefaults = Private.RegisterDefaults

-- Addon Core Settings.
RegisterDefaults(ADDON, {
	-- Limits the width of the UI
	aspectRatio = "wide", -- wide/ultrawide/full

	-- Sets the aura filter level 
	--auraFilter = "strict", -- strict/slack
	auraFilterLevel = 2, -- 0 = strict, 1 = slack, 2 = spam

	-- yay!
	theme = "Azerite", -- Current variations are Azerite and Legacy. Diabolic IS coming too!

	-- Enables a layout switch targeted towards healers
	enableHealerMode = false,

	-- Loads all child modules with debug functionality, 
	-- doesn't actually load any consoles. 
	loadDebugConsole = true, 

	-- Enable console visibility. 
	-- Requires the above to be true. 
	enableDebugConsole = false
})

RegisterDefaults("BlizzardChatFrames", {
	enableChatOutline = true -- enable outlined chat for readability
})

RegisterDefaults("BlizzardFloaterHUD", (IsClassic) and {
	enableRaidWarnings = true -- not yet implemented!

} or (IsRetail) and {
	enableAlerts = false, -- achievements and currency. spams like crazy. can we filter it? I did in legion. MUST LOOK UP! 
	enableAnnouncements = false, -- level up, loot, the various types of "banners"
	enableObjectivesTracker = true, -- the blizzard monstrosity
	enableRaidBossEmotes = true, -- partly needed for instance encounters, and some wqs like snapdragon flying
	enableRaidWarnings = true,  -- groups would want this
	enableTalkingHead = true -- immersive and nice
})

RegisterDefaults("ChatFilters", {
	--enableAllChatFilters = true, -- enable chat filters to pretty things up!
	enableChatStyling = true,
	enableMonsterFilter = true,
	enableBossFilter = true,
	enableSpamFilter = true
})

RegisterDefaults("ExplorerMode", {
	enableExplorer = true,
	enableExplorerChat = true,
	enableTrackerFading = false
})

RegisterDefaults("Minimap", {
	useStandardTime = true, -- as opposed to military/24-hour time
	useServerTime = false, -- as opposed to your local computer time
	stickyBars = false
})

RegisterDefaults("NamePlates", {
	enableAuras = true,
	clickThroughEnemies = false, 
	clickThroughFriends = false, 
	clickThroughSelf = false,
	nameplateShowSelf = false, 
	NameplatePersonalShowAlways = false,
	NameplatePersonalShowInCombat = true,
	NameplatePersonalShowWithTarget = true
})

RegisterDefaults("UnitFramePlayer", {
	enablePlayerManaOrb = true
})

RegisterDefaults("UnitFramePlayerHUD", {
	enableCast = true,
	enableClassPower = true
})

RegisterDefaults("UnitFrameParty", {
	enablePartyFrames = true
})

RegisterDefaults("UnitFrameRaid", {
	enableRaidFrames = true,
	enableRaidFrameTestMode = false
})

------------------------------------------------
-- New Forge Driven Defaults
------------------------------------------------
-- New saved settings which included
-- different entries for different themes.
RegisterDefaults("ModuleForge::ActionBars", {
	-- General settings. No prefix on them.
	["buttonLock"] = true,
	["castOnDown"] = true,
	["keybindDisplayPriority"] = "default", -- can be 'gamepad', 'keyboard', 'default'
	["lastKeybindDisplayType"] = "keyboard", -- not a user setting, just to save the state.
	["gamePadType"] = "default", -- gamepad icons used. 'xbox', 'xbox-reversed', 'playstation', 'default'
	
	-- Legacy specific settings
	["Legacy::enableSecondaryBar"] = false, -- bottom left multibar
	["Legacy::enableSideBarRight"] = false, -- right (first) side bar
	["Legacy::enableSideBarLeft"] = false, -- left (second) side bar
	["Legacy::enablePetBar"] = true,

	-- Azerite specific settings
	-- *Note: Not yet using these!
	["Azerite::extraButtonsCount"] = 5, -- Valid range is 0 to 17, 5 means a single full bar.
	["Azerite::extraButtonsVisibility"] = "combat", -- can be 'always','hover','combat'
	["Azerite::petBarEnabled"] = true,
	["Azerite::petBarVisibility"] = "hover"

})

-- New defaults for the new forge driven module.
-- Themes will be added to this as we transition them.
RegisterDefaults("ModuleForge::UnitFrames", {
	-- Legacy specific settings
	["Legacy::EnableCastBar"] = true,
	["Legacy::EnableClassPower"] = true,
	["Legacy::EnablePartyFrames"] = true,
	["Legacy::EnableRaidFrames"] = true
})
