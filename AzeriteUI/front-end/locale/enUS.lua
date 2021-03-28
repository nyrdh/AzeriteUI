local ADDON = ...
local L = Wheel("LibLocale"):NewLocale(ADDON, "enUS", true) -- only enUS must have the 'true' argument!
if (not L) then 
	return 
end 

-- No, we don't want this. 
ADDON = ADDON:gsub("_Classic", "")

-- 1.13.3 Battleground popup bugfix
L["You can now enter a new battleground, right-click the green eye on the minimap to enter or leave!"] = true

-- General Stuff
--------------------------------------------
-- Most of these are inserted into other strings, 
-- the idea here is to keep them short and simple. 
L["Enable"] = true 
L["Disable"] = true 
L["Enabled"] = "|cff00aa00Enabled|r"
L["Disabled"] = "|cffff0000Disabled|r"
L["<Left-Click>"] = true
L["<Middle-Click>"] = true
L["<Right-Click>"] = true

-- Clock & Time Settings
--------------------------------------------
-- These are shown in tooltips
L["New Event!"] = true
L["New Mail!"] = true
L["%s to toggle calendar."] = true
L["%s to use local computer time."] = true
L["%s to use game server time."] = true
L["%s to use standard (12-hour) time."] = true
L["%s to use military (24-hour) time."] = true
L["Now using local computer time."] = true
L["Now using game server time."] = true
L["Now using standard (12-hour) time."] = true
L["Now using military (24-hour) time."] = true

-- Network & Performance Information
--------------------------------------------
-- These are shown in tooltips
L["Network Stats"] = true
L["World latency:"] = true
L["This is the latency of the world server, and affects casting, crafting, interaction with other players and NPCs. This is the value that decides how delayed your combat actions are."] = true 
L["Home latency:"] = true
L["This is the latency of the home server, which affects things like chat, guild chat, the auction house and some other non-combat related things."] = true

-- XP, Honor & Artifact Bars
--------------------------------------------
-- These are shown in tooltips
L["Normal"] = true
L["Rested"] = true
L["Resting"] = true
L["Current Artifact Power: "] = true 
L["Current Honor Points: "] = true
L["Current Standing: "] = true
L["Current XP: "] = true
L["Rested Bonus: "] = true
L["%s of normal experience gained from monsters."] = true
L["You must rest for %s additional hours to become fully rested."] = true
L["You must rest for %s additional minutes to become fully rested."] = true
L["You should rest at an Inn."] = true
L["Sticky Minimap bars enabled."] = true
L["Sticky Minimap bars disabled."] = true

-- These are displayed within the circular minimap bar frame, 
-- and must be very short, or we'll have an ugly overflow going. 
L["to level %s"] = true 
L["to %s"] = true
L["to next trait"] = true
L["to next level"] = true

-- Try to keep the following fairly short, as they should
-- ideally be shown on a single line in the tooltip, 
-- even with the "<Right-Click>" and similar texts inserted.
L["%s to toggle Artifact Window>"] = true
L["%s to toggle Honor Talents Window>"] = true
L["%s to disable sticky bars."] = true 
L["%s to enable sticky bars."] = true 

-- Config & Micro Menu
--------------------------------------------
-- Config button tooltip
-- *Doing it this way to keep the localization file generic, 
--  while making sure the end result still is personalized to the addon.
L["Main Menu"] = ADDON
L["Game Panels"] = true
L["Click here to get access to game panels."] = "Click here to get access to the various in-game windows such as the character paperdoll, spellbook, talents and similar, or to change various settings for the actionbars."

-- These should be fairly short to fit in a single line without 
-- having the tooltip grow to very high widths. 
L["%s to toggle Blizzard Menu."] = "%s to toggle the micro menu."
L["%s to toggle Options Menu."] = "%s to toggle "..ADDON.." menu."
L["%s to toggle your Bags."] = "%s to toggle your bags."

-- Config Menu
--------------------------------------------
-- Remember that these shall fit on a button, 
-- so they can't be that long. 
-- You don't need a full description here. 
L["Debug Mode"] = "Debug Tools" -- it's not really a mode, just tools. 
L["Debug Console"] = true 
L["Load Console"] = true
L["Unload Console"] = true
L["Reload UI"] = true
L["Settings Profile"] = true
L["Global"] = true
L["Faction"] = true
L["Realm"] = true
L["Character"] = true
L["ActionBars"] = true
L["Button Lock"] = true
L["Cast on Down"] = true
L["Bind Mode"] = true
L["Display Priority"] = true
L["GamePad First"] = true
L["Keyboard First"] = true
L["GamePad Type"] = true
L["Xbox"] = true
L["Xbox (Reversed)"] = true
L["Playstation"] = true
L["More Buttons"] = true
L["No Extra Buttons"] = true
L["+%.0f Buttons"] = true
L["Extra Buttons Visibility"] = true
L["MouseOver"] = true
L["MouseOver + Combat"] = true
L["Always Visible"] = true
L["Stance Bar"] = true
L["Extra Bars"] = true
L["Secondary Bar"] = true
L["Side Bar One"] = true
L["Side Bar Two"] = true
L["Pet Bar"] = true
L["Pet Bar Visibility"] = true
L["Chat Windows"] = true
L["Chat Outline"] = true
L["Chat Filters"] = true
L["Chat Styling"] = true
L["Hide Monster Messages"] = true
L["Hide Boss Messages"] = true
L["Hide Spam"] = true
L["Battleground Filter"] = true
L["UnitFrames"] = true
L["Party Frames"] = true
L["Raid Frames"] = true
L["PvP Frames"] = true
L["Use Mana Orb"] = true
L["HUD"] = true
L["CastBar"] = true
L["ClassPower"] = true
L["Alerts"] = true
L["Kills, Levels, Loot"] = true
L["Monster Emotes"] = true
L["Raid Warnings"] = true
L["TalkingHead"] = true
L["Objectives Tracker"] = true
L["NamePlates"] = true
L["Auras"] = true
L["Player"] = true
L["Enemies"] = true 
L["Friends"] = true
L["PRD"] = true -- Personal Resource Display. Keep this abbreviated for space reasons.
L["Show Always"] = true
L["Show In Combat"] = true
L["Show With Target"] = true
L["Aspect Ratio"] = true
L["Widescreen (16:9)"] = "Widescreen |cff666666(16:9)|r"
L["Ultrawide (21:9)"] = "Ultrawide |cff666666(21:9)|r"
L["Unlimited"] = true
L["Aura Filters"] = true
L["Strict"] = true
L["Slack"] = true
L["Spam"] = true
L["Explorer Mode"] = true
L["Player Fading"] = true
L["Tracker Fading"] = true
L["Chat Positioning"] = true
L["Healer Mode"] = "Healer Layout" -- it's a layout change, so let's reflect this!

-- Config Menu Tooltips
-- *please do not let the very 
--  long texts here confuse you.
--------------------------------------------
-- Debug tools
L["Various minor tools that may or may not help you in a time of crisis. Usually only useful to the developer of the user interface."] = true
L["The debug console is a read-only used by the user interface to show status messages and debug output. Unless you are actively developing new features yourself and intentionally sends thing to the console, you do not need to enable this."] = true
L["Reloads the user interface. This can be helpful if taints occur, blocking things like quest buttons or bag items from being used."] = true

-- Aspect Ratio
L["Here you can set how much width of the screen our custom user interface elements will take up. This is mostly useful for users with ultrawide screens, as it allows them to place the frames closer to the center of the screen, making the game easier to play.|n|n|cffcc0000This does NOT apply to Blizzard windows like the character frame, spellbook and similar, and currently that is not something that can easily be implemented!|r"] = true
L["Limits the user interface to a regular 16:9 widescreen ratio. This is how the user interface was designed and intended to be, and thus the default setting."] = true
L["Limits the user interface to a 21:9 ultrawide ratio.|n|n|cffcc0000This setting only holds meaning if you have a screen wider than this, and wish to lock the width of our user interface to a 21:9 ratio.|r"] = true
L["Uses the full width of the screen, moving elements anchored to the sides of the screen all the way out.|n|n|cffcc0000This setting only holds meaning if you have a screen width a wider ratio than regular 16:9 widescreen.|r"] = true

-- Aura Filters
L["There are very many auras displayed in this game, and we have very limited space to show them in our user interface. So we filter and sort our auras to better use the space we have, and display what matters the most."] = true
L["The Strict filter follows strict rules for what to show and what to hide. It will by default show important debuffs, boss debuffs, time based auras from the environment of NPCs, as well as any whitelisted auras for your class."] = true
L["The Slack filter shows everything from the Strict filter, and also adds a lot of shorter auras or auras with stacks."] = true
L["The Spam filter shows all that the other filters show, but also adds auras with a very long duration when not currently engaged in combat."] = true

-- ActionBars
L["Click to enable the Stance Bar."] = true
L["Click to disable the Stance Bar."] = true
L["Click to enable the Pet Action Bar."] = true
L["Click to disable the Pet Action Bar."] = true

-- Chat Windows
L["This is a chat filter that reformats a lot of the game chat output to a much nicer format. This includes when you receive loot, earn currency or gold, when somebody gets and achievement, and so on.|n|nNote that this filter does not add or remove anything, it simply makes it easier on the eyes."] = true
L["This filter hides most things NPCs or monsters say from that chat. Monster emotes and whispers are moved to the same place mid-screen as boss emotes and whispers are displayed.|n|nThis does not affect what is visible in chat bubbles above their heads, which is where we wish this kind of information to be available."] = true
L["This filter hides most things boss monsters say from that chat. |n|nThis does not affect what is visible mid-screen during raid fights, nor what you'll see in chat bubbles above their heads, which is where we wish this kind of information to be available."] = true
L["This filter hides a lot of messages related to group members in raids and especially battlegrounds, such as who joins, leaves, who loots something and so on.|n|nThe idea here is free up the chat and allow you to see what people are actually saying, and not just the constant spam of people coming and going."] = true
L["Toggles outlined text in the chat windows.|n|nWe recommend leaving it on as the chat can be really hard to read in certain situations otherwise."] = true

-- NamePlates
L["This controls the visibility options of the Personal Resource Display, your personal nameplate located beneath your character."] = true
L["Click to disable the Personal Resource Display."] = true
L["Click to enable the Personal Resource Display."] = true
L["Here you can choose whether NamePlates should react to mouse events and mouse clicks as normal, or set them to be click-trhough, meaning you can see them but not interact with them.|n|nIf you wish to be able to click on a nameplate to select that unit as your target, then you should NOT use click-through NamePlates."] = true

-- HUD
L["A head-up display, also known as a HUD, is any transparent display that presents data without requiring users to look away from their usual viewpoints. In our user interface, we use this to label elements appearing in the middle of the screen, then disappearing."] = true
L["Toggles your own castbar, which appears in the bottom center part of the screen, beneath your character and above your actionbars."] = true
L["Toggles the point based resource systems unique to your own class."] = true
L["Toggles the TalkingHead frame. This is the frame you'll see appear in the top center part of the screen, with a portrait and a text. This will usually occur when reaching certain world quest areas, or when a forced quest from your faction leader appears."] = true
L["The Objectives Tracker shows your quests, quest item buttons, world quests, campaign quests, mythic affixes, Torghast powers and so on.|n|nAnnoying as hell, but best left on unless you're very, very pro."] = true
L["Raid Warnings are important raid messages appearing in the top center part of the screen. This is where messages sent by your raid leader and raid officers appear. It is recommended to leave these on for the most part.|n|nThe exception is when you get into WoW Classic battlegrounds where everybody is promoted, and some jokers keep spamming. Then it is good to disable."] = true
L["Toggles the display of boss- and moster emotes. If you're a skilled player, it is not recommended to turn these on, as some world quests and most boss encounters send important messages here.|n|nSupport wheel users relying on Dumb Boss Mods can do whatever they please, it's not like they're looking at anything else than bars anyway."] = true
L["This includes most mid-screen announcements like when you gain a level, you receive certain types of loot, and any banner shown when you complete a scenario, kill a boss and so forth."] = true
L["Toggles the display of alert frames. These include the achievement popups, as well as multiple types of currency loot in some expansion content like the Legion zones."] = true


-- Various Button Tooltips
--------------------------------------------
L["%s to leave the vehicle."] = true
L["%s to dismount."] = true
L["%s to dismiss your controlled minion."] = true

-- Abbreviations
--------------------------------------------
-- This is shown of group frames when the unit 
-- has low or very low mana. Keep it to 3 letters max! 
L["oom"] = true -- out of mana

-- These are shown on the minimap compass when 
-- rotating minimap is enabled. Keep it to single letters!
L["N"] = true -- compass North
L["E"] = true -- compass East
L["S"] = true -- compass South
L["W"] = true -- compass West

-- Keybind mode
--------------------------------------------
-- This is shown in the frame, it is word-wrapped. 
-- Try to keep the length fairly identical to enUS, though, 
-- to make sure it fits properly inside the window. 
L["Hover your mouse over any actionbutton and press a key or a mouse button to bind it. Press the ESC key to clear the current actionbutton's keybinding."] = true

-- These are output to the chat frame. 
L["Keybinds cannot be changed while engaged in combat."] = true
L["Keybind changes were discarded because you entered combat."] = true
L["Keybind changes were saved."] = true
L["Keybind changes were discarded."] = true
L["No keybinds were changed."] = true
L["No keybinds set."] = true
L["%s is now unbound."] = true
L["%s is now bound to %s"] = true
