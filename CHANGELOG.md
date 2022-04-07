# AzeriteUI Change Log
All notable changes to this project will be documented in this file. Be aware that the [Unreleased] features are not yet available in the official tagged builds.

The format is based on [Keep a Changelog](http://keepachangelog.com/) 
and this project adheres to [Semantic Versioning](http://semver.org/).

## [3.2.523-Release] 2022-04-07
- Bump for BCC client patch 2.5.4.

## [3.2.522-Release] 2022-04-06
### Changed
- Cleaning up the Retail tracker code a bit.

### Removed 
- Removed the now deprecated FixingThings.

## [3.2.521-Release] 2022-03-17
### Changed
- Slight change in how tooltip unit levels are determined in BCC. Not expected to fix the issues reported on this, this is just the first step.

## [3.2.519-Release] 2022-02-23
- ToC bump.

## [3.2.518-Release] 2022-02-16
- ToC bumps and back-end updates.

## [3.2.517-Release] 2021-12-23
- The yearly time function fix. Please teach me to count. And logic. 

## [3.2.516-Release] 2021-11-17
- Bump Classic Era toc to client patch 1.14.1: Season of Dumb.

### Fixed
- Fixed GameTooltip issues in the classic clients.

## [3.2.515-Release] 2021-11-03
- Bump Retail toc to client patch 9.1.5.

### Fixed
- Fixed most tooltip issues introduced in the latest patch.

## [3.2.514-RC] 2021-10-18
- Bump Classic Era toc to client patch 1.14.

### Fixed
- Fixed another weird and sudden SetPoint anchor issue with the QuestTimerFrame in Classic Era 1.14. 

## [3.2.513-Release] 2021-09-29
### Changed
- Added a "hidden" developer feature. My patrons know about it.

## [3.2.512-Release] 2021-09-28
### Changed
- Removed redundant theme names from the theme switcher. 

## [3.2.511-Release] 2021-09-26
### Changed
- The various blizzard widgets hooked to below the minimap should now update their position based on whether or not there currently are boss frames visible.

### Fixed
- Worked around a positioning issue with the PvP capture bars.

## [3.2.510-Release] 2021-09-22
### Fixed
- Worked around a bug that would occur with more recent versions of Narcissus.

## [3.2.509-Release] 2021-09-21
### Added
- Added the Looking For Group micro button to our micro menu in Burning Crusade Classic. 

## [3.2.508-Release] 2021-09-02
### Fixed
- Fixed the strange statusbar bug that would occur in WoW BCC 2.5.2 every time you killed something that awarded experience points. 

## [3.2.507-Release] 2021-09-01
- Bump TOC for BCC 2.5.2.

## [3.2.506-Release] 2021-08-30
### Changed
- Added better compatibility for some upcoming standalone addons. 

## [3.2.505-Release] 2021-08-17
### Changed
- Added a check to see if vehicles actually have combopoints before displaying the classpower element while in vehicles. Note that a lot of vehicles give a false positive test result on this, so the WoW API seems a bit lacking here?

## [3.2.504-Release] 2021-07-27
### Changed
- The Legacy classpower element is now force disabled if the addon SimpleClassPower is loaded.

## [3.2.503-Release] 2021-07-18
### Fixed
- Fixed the problem where certain zone abilities would be missing their icons on relogs and reloads. 

## [3.2.502-Release] 2021-07-18
### Changed
- Updated FixingThings to latest build.

## [3.2.501-Release] 2021-07-04
- Added FixingThings to help prevent quest tracker related item button taint.

## [3.2.500-Release] 2021-07-02
### Changed
- Added duration and tooltips to the temporary enchant frames (weapon buffs, fishing lures, etc) in both the Azerite and Legacy themes.

## [3.2.499-Release] 2021-06-29
- Bump toc for 9.1.0.

## [3.2.498-RC] 2021-06-12
### Changed
- Modified how the backdrops are attached to Blizzard tooltips, in an effort to solve some incompatibilities with certain other addons like Silverdragon and Raider.io. 

### Fixed
- We'll hopefully not have such random quest tracker positions in Classic anymore. 

## [3.2.497-RC] 2021-06-10
### Fixed
- Fixed the weird and sudden issue with the QuestTimerFrame in BC and Classic. 

## [3.2.496-RC] 2021-06-09
### Added
- There should be a focus frame in BC clients now. 

## [3.2.495-RC] 2021-05-31
- New tag to re-trigger GitHub actions and get builds uploaded to the now functioning CurseForge. 

### Added
- Added the minimap tracking button to BC clients, and also the minimap right-click functionality as an additional way to bring up the BC client tracking menu.
- Added the nicely styled bottom button to the chat frame in BC clients.
- Attempted to add the pet happiness element to BC clients. Untested, as I have no hunter with pet there yet.

### Changed
- Moved the quest timer frame used in classic quests such as Iverron's Antidote to the same annoying place in BC clients as in classic.

## [3.2.493-RC] 2021-05-28
### Added
- Added the option to completely disable player- and target auras when using the Legacy theme. 

## [3.2.492-RC] 2021-05-26
### Added
- Added the option to completely disable player- and target auras when using the standard Azerite theme. 

## [3.2.491-RC] 2021-05-24
### Changed
- Increased max nameplate distance in BC to 30 yards outdoors, and 41 yards in instances. 

## Fixed
- Hovering over an NPC with no questie global options yet saved should no longer cause a bug in bc or classic.

## [3.2.490-RC] 2021-05-23
### Fixed
- Various annoying micro menu alerts should now longer cause randomly hovering alert windows.

## [3.2.489-RC] 2021-05-23
### Fixed
- The collections journal should no longer cause an addon action blocked when opened during combat.

## [3.2.488-RC] 2021-05-23
### Added
- Attempted to add the same battleground finder eye to the BC minimap as we used in Classic. Untested.
- Added Questie information to BC tooltips and nameplates.

## [3.2.487-RC] 2021-05-22
### Fixed
- Added the same workaround for the tainted blizzard battleground popups in Burning Crusade as we used in Classic.

## [3.2.486-RC] 2021-05-20
### Fixed
- The experience bar should now be visible on Burning Crusade realms.

## [3.2.485-RC] 2021-05-17
- Extra push needed because the bigwigs packager changed its API from using "bc" to calling it "bcc". 

## [3.2.484-RC] 2021-05-17
### Fixed
- You should no longer get two identical target frames in legacy mode.

## [3.2.483-RC] 2021-05-13
### Changed
- WorldFrame unit tooltips no longer get their content modified by this addon if totalRP3 currently is enabled. 

## [3.2.482-RC] 2021-05-08
- First batch of fixes for BC compatibility.

## [3.2.480-Release] 2021-05-01
### Fixed
- Fixed a typo in the legacy theme unitframe module that would cause party frames to be hidden on startup and reloads until manually toggled through the menu. 

## [3.2.479-Release] 2021-04-29
### Added
- Added blip icons for WoW client patch 9.0.5.

### Fixed
- Certain toybox items with a sellprice even though they're not actually sellable will no longer cause a bug if you hover the mouse cursor above them on the action bar while holding down the shift key. 

## [3.2.478-Release] 2021-04-27
### Changed
- The temporary weapon enchant buttons (shaman weapon buffs, classic fishing lures, etc) will now follow the opacity of the player unit frame. It also has a new place to live up at the minimap in the legacy theme.
- Unit tooltips where the creature's family or type can't be determined will now mimick the default tooltip behavior and display no info about this, instead of the rather meaningless text "Not specified".

## [3.2.477-Release] 2021-04-26
### Fixed
- The focus frame which got lost a few updates back has found its way back home.

## [3.2.476-Release] 2021-04-22
### Fixed
- Fixed an issue that would break the UI for multiple classes when a tutorial was shown during the Exile's Reach intro campaign.

## [3.2.475-Release] 2021-04-20
- Minor bug fixes and workarounds.

## [3.2.474-Release] 2021-04-19
### Added
- Added menu options to toggle the Legacy theme's party- and raid frames! Now you can use Legacy with your favorite group frame addon!

### Changed
- Gave the Blizzard popups a slight facelift. They are now darker and more transparent, and just allround more beautiful. Like me. 
- There should now be a short delay from entering the Minimap's number badge until the ring frames showing the full XP/Rep/Azerite bars appear. This should help avoid that annoying situation where you accidentally touch the badge on your way to the minimap only to get the map covered by bars while you were trying to hover above an object or player on the map.   

## [3.2.473-RC] 2021-04-15
- Crazy changes.

## [3.2.470-RC] 2021-04-14
### Changed
- Updated the MaxDps integration, hopefully to the better. Keeping an eye on this.

### Fixed
- Fixed an issue in Classic that would leave an empty border around the class power element on some classes that didn't have a class power element. 

## [3.2.469-RC] 2021-04-11
### Added
- Added support for WorldMapShrinker!

### Changed
- Moving anything chat filter related out of the back-end. This is part of an ongoing chat filter overhaul. 
- Moving anything aura filter related out of the back-end. This is part of an upcoming aura filter overhaul.

### Removed
- Temporarily disabled the chat filter options, as the chat filters are temporarily out of order.

## [3.2.466-RC] 2021-04-01
### Changed
- Tuned the chat message gold display a bit. When closing your mailbox, it will now only show gold gains, not losses from mailing costs or C.O.D transactions.

### Fixed
- Fixed an issue that would cause bugs with spam filters enabled for boss chat messages in raids. 
- Working on experimental workarounds for the tooltip related taint causing quest tracker item buttons spawned in combat to bug out. Have discovered a potential source for the (current) taint, by following the taint reports and discovering a bug in the Blizzard code. Have not found anything triggering it in mine or other's addons, though. So trying various degrees of workarounds for now. 

## [3.2.464-RC] 2021-03-29
### Fixed
- Fixed wrong upvalue in party frame group debuffs, which was causing a lot of bugs in parties.

## [3.2.463-RC] 2021-03-28
### Added
- Started adding a lot of descriptive tooltips to our options menu, making it easier for everybody to understand what certain options actually do. This is a work in progress, as I intend to add tooltips for the entire menu. The only reason I'm including any at all right now, is because I needed to get the options menu workaround (see the section below) out to the public, and decided to just include the tooltips that were ready. Because they are all upgrades to not having any at all.

### Fixed
- Worked around Blizzard's bugged code in WoW client patch 9.0.5.37623. They broke important code related to their restricted environment and restricted frames, which caused our options menu to produce a lot of bugs, and also being unable to toggle actionbars and unitframes in combat. I have worked around this bug until Blizzard gets around to fixing it.

## [3.2.462-RC] 2021-03-27
### Fixed
- The hover keybind mode `/bind` now once more has actual bindable buttons in it!

## [3.2.461-RC] 2021-03-27
- Updated the tooltip changes to also work with WoW Classic.
- Updated the money report system to better work with WoW Classic.

## [3.2.460-RC] 2021-03-27
- As part of the ongoing fight against taints, I'm trimming down and simplifying a lot of modules, as well as moving a lot of modifications to central blizzard elements into the front-end. Part of this are the tooltips. No library will affect the Blizzard tooltips anymore, as this is all done through the front-end module now. 

### Changed
- Gave all the tooltips a facelift and got rid of some baggage. Run, tooltips! Run!

## [3.2.459-RC] 2021-03-26
- Restructuring continues. The goal is to take the user interface back into a fully table driven layout system again. Which will make tinkering slightly less powerful, but infinitely much easier. And the pro tinkerers tinker with any code anyway, so I kind of don't need to make advanced tinkering systems for their sake. 

### Changed
- New event driven chat filter reporting for money gains and losses are in place, with constant tweaking going on. It delays output while visiting a merchant, and suppresses output while taking a taxi flight or visiting the Auction House. You really don't need to get your chat spammed with flight point- or deposit costs. 

### Fixed
- Fixed wrong upvalue in a raid unitframe callback.

## [3.2.458-RC] 2021-03-22
- Restructuring. Before moving into the next phase of the UI, and the next group of standalone projects, I want to bring the UI code down to a much simpler level again. 

### Fixed
- Classic users should finally be rid of the Love Festival hearts. 
- Classic chat bubbles should be rid of the blizzard backdrop once again. 

## [3.1.455-RC] 2021-03-15
### Fixed
- There might not be as many taints and blocked action messages when trying to click quest items spawning in the quest tracker while engaged in combat. 

## [3.1.454-RC] 2021-03-10
- This update also contains a lot of undocument back-end changes related to primarily the bagbutton and tooltips libraries, as I'm actively developing both in preparation of both my upcoming standalone bag addon, as well as a potential quest item bar feature in AzeriteUI. 

### Added
- Added the debuff counting currently held Shackled Souls in the Revendreth World Quest "Bruised and Battered" to the aura whitelist, to better track your debuff status in combat as this affects not only the quest, but your damage taken.

### Changed
- Bump to WoW client patch 9.0.5.
- The Blizzard objectives tracker should now hide in a corner while Immersion is visible.
- Aura tooltips will now only show their spellID if the Shift key is currently held down, and hidden otherwise. 
- Added updated zhCN number abbreviations by Mengqyzh. 

### Fixed
- The chat styling filter's reputation coloring should now be more accurate for friendship reputations, even those friendship reputations that aren't displayed as friendship reputations in the reputation tab.

## [3.1.453-RC] 2021-02-24
### Changed
- Updated the time library with dates for the 2021/2022 events.
- Various back-end updates in preparation for the future.

## [3.1.452-RC] 2021-02-11
### Added
- Added Hunter's Primal Rage to the aura whitelists, in the same manner as other boosts similar to Bloodlust and Heroism.

## [3.1.451-RC] 2021-01-23
### Added
- Updated the zhCN localization. 
- The durability widget should now properly appear in the legacy theme as well. 

### Changed
- Changed to Blizzard's Shadowlands logic for toggling the visibility of the Azerite Power bar. You shouldn't see it when leveling new characters in Shadowlands anymore. Lame.

## [3.1.450-RC] 2021-01-16
### Added
- Experimental legacy theme boss frames.
- Experimental target- and focus highlight on the nameplates.

### Changed
- Personal Resource Display options have been removed from the Blizzard Interface menu, and put into ours instead, with a few extra options added! This causes a first-time override of whatever setting you previously had, as these options will be stored and handled by our UI from now on. More nameplate options to follow at a later date.
- Raid marks should no longer be shown on the personal resource display, as you have the same mark right above your character's head already.
- Matched the visibility drivers of the legacy target frame and pet action bar to also hide when inaccessible in the same manner the main player frame and the primary actionbar do.
- Tweaked the legacy focus frame aura filter to be a bit more player centered, yet boss and NPC debuff inclusive.

### Fixed
- Auras cast by the player should now be shown before those cast by others, as intended. The check was there in the filter, but at the completely wrong place. Late night coding. Fail.
- Changed how we hide the tracker during boss fights, to fix an issue where it would reappear if the UI was reloaded mid fight.

## [3.1.449-RC] 2021-01-08
### Fixed
- The exit button used to exit mounts, cancel flight paths, leave vehicles and so on will no longer bug out in WoW Classic.
- Interrupted casts should display properly in WoW Classic now, thanks to NoraHub @ GitHub seeing what I was blind to!

## [3.1.448-RC] 2021-01-03
### Added
- Added some auras to the legacy theme focus frame.
- Added many shadowlands auras to the whitelists.

## [3.1.447-RC] 2020-12-29
### Fixed
- Reduced the point count for Mage's arcane charges down from 5 to 4. Wonder why I ever set it as 5?
- Added some attempted workarounds for bugs sometimes occurring when opening the (retail) anima channel map.
- The castbar won't appear when toggled off and on if the personal resource display is enabled anymore. That was never an intended workaround, as we intentionally hide the castbar to avoid it colliding with the personal resource display which have its own castbar and appears at the same place.

## [3.1.446-RC] 2020-12-20
### Added
- Added minimap blip icons for WoW client patch 9.0.2.

### Changed
- Our nameplate module should now properly go and hide in a corner if the nameplate addon NamePlateKAI is currently enabled.

## [3.1.445-RC] 2020-12-18
### Fixed
- Possibly fixed the legacy theme growth direction of the `UIWidgetBelowMinimapContainerFrame` used by various raid encounters.

## [3.1.444-RC] 2020-12-17
### Added
- Added experimental combat feedback on the azerite theme player- and target unitframes. This is a work in progress. 
- Whitelisted the aura Crushing Stone from Hecutis in Castle Nathria in all aura filters. 

### Fixed
- Fixed mouseover alignment on the worldmap.
- Fixed problems related to a silly addon we just don't like.

## [3.1.443-RC] 2020-12-16
### Changed
- We hate the fucking Blizzard UI widget system. And their bottom centered powerbar basically does the exact same as the player altpower. Only it's not the player altpower, it's the bottom center fucking UI widget. So we hid that thing and show the value within the player altpower bar instead. Experimental change.

### Fixed
- Fixed an issue in the time library that had devastating consequences.
- Fixed the long standing taint that would prevent the worldmap or quest log from being opened in combat after clicking a quest objective title after a few times. Not all hooks were created equal, it turns out.
- Fixed an issue related to a wrongly created global value `count` in the group tools module, which should have been and now is just a regular local. This would sometimes cause strange taints in unrelated modules, as also blizz unintentionally has made a variable with this name global. My bug is fixed, how about you, Blizz?

## [3.1.442-RC] 2020-12-15
### Changed
- NPC tooltips will no longer show quest information for quests where you have completed all the objectives. 
- When you're inside Torghast, the minimap compass will now always point north to reflect that minimap rotation simply does not work inside this place.

### Fixed
- Fixed the issue where some NPCs would get mile high mouseover tooltips for no apparent reason.

## [3.1.441-RC] 2020-12-13
### Changed
- Desaturated and toned down Azerite theme auras not cast by the player on other units.
- Added a few debuffs to the Explorer Mode's safe list, so they won't prevent the UI from fading out.

### Fixed
- Fixed an error for non-healer classes related to dispellable debuffs. 

## [3.1.440-RC] 2020-12-12
### Added
- Added first draft of the focus frame. Work in progress, not all elements added yet. 
- Added dispellable- and boss auras to your pet frame as well.

### Changed
- Legacy Warlock SoulShards should now be hidden if you're not in combat, and don't currently target something.
- Explorer Mode will no longer fade in when you have a focus target. You can have a focus, and keep exploring.

### Fixed
- Redid the group debuff filter to follow [wowpedia](https://wow.gamepedia.com/Dispel).

## [3.1.439-RC] 2020-12-12
### Added
- The retail world map has player- and cursor coordinates now.

### Fixed
- Fixed an issue related to the transition to a new settings system for the actionbars, which caused certain settings such as cast on down and button lock to not save or have any effect at all in the legacy theme. The transition is complete, and it will cause a one time settings reset for the azerite theme actionbar settings. 
- Trying to fix the issue of layering after the extra action or zone ability buttons have been visible for a while, causing the cooldown spiral, keybind and charge count to be hidden beneath the border.
- Fixed an issue where the health predict element of health bars would be immediately shown after having been reset and hidden, causing the texture coordinates to be wrong, and the bar to overflow.

## [3.1.438-RC] 2020-12-09
### Added
- Added experimental legacy theme raid frames. Work in progress, more sub-elements and more testing will be done.
- Added various icons like group leader and assistant, master looter, main tank, main assist and raid targets to relevant legacy unit frames.
- Added boss- and dispellable debuffs to the legacy party frames.

### Changed
- The eye of the jailer should be less annoying now.
- Having the Honorless Target debuff from recently resurrecting should no longer prevent Explorer Mode fades.
- Reset the saved aura filter setting for all existing characters to "spam", and set that as the default for all new ones as well.

### Fixed
- Chat bubbles in instances should no longer look like modern art.
- Fixed a bunch of long standing bugs with the group debuff display.
- Fixed a strange incompatibility when AzeriteUI, Bartender and Bagnon was enabled at the same time that would cause an error when handing in anima in Shadowlands. 

## [3.1.437-RC] 2020-12-08
### Added
- The new (to me) in 9.0.1 nameplate widget containers should now be visible on our nameplates too. No styling as of yet, we simply made them visible.

### Changed
- Changed chat bubble font for latin clients and increased its size for better readability.
- Added some updates to the class power element to try to battle the issue of weirdly looking points after cinematics.
- Greatly enhanced the contrast between filled and empty points in the legacy class power element.
- Enemy faction players with much higher level than you should now have a skull in all tooltips, indicating that they are more badass than you.

## [3.1.436-RC] 2020-12-05
### Fixed
- Debuffs on the legacy theme player frame should once again be visible.

## [3.1.435-RC] 2020-12-01
### Fixed
- Aura filters now properly update to your saved setting when logging in or reloading in all themes. 

## [3.1.434-RC] 2020-12-01
### Added
- Added updated zhCN locales by Mengqyzh(GitHub).

### Changed
- Legacy class power points will no longer appear invisible after combat ends while targeting something, giving the faulty illusion that an empty bar is shown. The points will be visible at all times when the bar is visible, and visibility will instead be handled by the main bar, not by each separate point like in the Azerite theme. The Azerite theme does not display the points as a single bar, but rather like floating standalone points, so different visibility systems make sense in the different themes.
- Helpful auras on hostile targets should no longer get a green border to indicate their friendliness, as this was too easy to confuse with the more puke green colored poison color, thus making it look like an allied cast poison debuff instead. Only harmful auras will now have their borders colored.
- Unified all number abbreviations into a single maintainable back-end library. Included new zhCN abbreviation changes by Mengqyzh(GitHub).

### Fixed
- Nameplate display of name and health values on the currently mouseovered nameplate should work properly when mousing in/out over the same frame multiple times now, and not require you to mouse over another plate first before it is shown on the original again.
- Worked around a chat bug that would sometimes occur when entering pet battles while having the addons Prat or Glass installed and enabled.

## [3.1.433-RC] 2020-11-30
### Fixed
- Changed how events are unregistered in the back-end, making the process a silent one by default. If modules want errors from attempting to unregister an event or message that wasn't registered to begin with, they'll have to explicitly ask for verbose output now. Otherwise, no bugs will occur and the world will go on turning as before. 

## [3.1.432-RC] 2020-11-29
### Fixed
- Removed redundant function call in the group debuff element.

## [3.1.431-RC] 2020-11-29
### Added
- Added the class power element to the legacy theme. Work in progress.
- Added party frames to the legacy theme. Work in progress.

### Changed
- Moved the config button up to the top right corner in legacy mode, and adjusted spawn order of all micro- and menu buttons to match.
- Moved the totem buttons slightly downwards in the legacy mode.

### Fixed
- Explorer mode should work much better with legacy theme side action bars now.
- A fuck-load of rewriting done to the aura section. Might be new and exiciting bugs now.

## [3.1.430-RC] 2020-11-25
### Fixed
- Fixed spawning, layout, cooldowns, spell charges and keybind texts of extra action- and zone ability buttons for all themes. 
- Fixed a legacy HUD issue that could cause texts on the player cast bar and player altpower bar to remain visible after the bars were hidden.

## [3.1.429-RC] 2020-11-24
### Fixed
- Legacy theme fixed to work for WoW Classic!

## [3.1.428-RC] 2020-11-24
### Added
- Added a new, better system for extra action- and zone ability buttons for the legacy theme. Azerite will follow shortly!

### Fixed
- The XP bar should appear at more appropriate times now, especially for players without the latest expansion.

## [3.1.427-RC] 2020-11-23
### Added
- New beta feature: Theme changes!
	- Type `/go legacy` to try the beta version of the new GoldpawUI theme. 
	- Type `/go azerite` to return to the default AzeriteUI theme.

### Changed
- Our actionbutton now use their own spell highlight texture to display MaxDps glows. If you have enabled both MaxDps and Blizzard glows in the MaxDps settings, the MaxDps rotations and colorings will take priority. We recommend disabling the Blizzard glow.
- Players from other realms will now have their realm displayed at the bottom of unit tooltips.

## [3.0.426-RC] 2020-11-18
- Bump toc to 9.0.2.

## [3.0.425-RC] 2020-11-17
### Changed
- The exit button appearing on the minimap while in vehicles, when mounted or when taking a taxi now also works for possessions. This includes toys like the crashin' trashin' series.

### Fixed
- The minimap compass tag should once again be visible on the initial login after game start.
- Totem Bar once more makes it appearance in retail.

## [3.0.424-RC] 2020-11-11
### Added
- Error speech usually generated by Blizzard's mid-screen red error text has been added to our UI too. Failed casts and general feedback from your character to you should now be heard again. We are directing all of this to the Dialog channel, unlike Blizz who put some of it in the Master channel. Weird. 

### Changed
- The minimap compass N tag should now only be visible for users with a rotating minimap.
- Moved disabling of the HelpTip and additional Tutorial tips into the tutorial disabling section of the LibBlizzard back-end.
- Moved the Classic pet happiness into its own plugin in the back-end. It now also fades along with the unitframe.

### Removed
- Arrows, popup windows, tooltips and all the general "help" players are given when leveling a new character in Exile's Reach has been to the best of my ability purged from our universe. We are not beginners. 

## [3.0.423-RC] 2020-11-10
### Added
- Added gamepad support to our `/bind` mode, when the user has enabled it with `/console GamePadEnable 1`. 
	- Will by default automatically switch between displaying gamepad keybinds and keyboard keybinds depending on what you use.
	- Will by default automatically try to figure out whether to show Xbox or Playstation keybind icons.
	- Can be set to always prioritize gamepad bindings, always prioritize keyboard, or prioritize last used input method, which is default.
	- Can be set to display xbox icons, playstation icons, or attempt to figure it out automatically, which is default.

### Changed
- Changed the text based abbreviations of keybinds to better support gamepads. I am working on gamepad icons and plan to implement icons in the style of xbox360 and ps4 controllers, so the current text based solution is temporary. I just figured `Rt` is a bit more readable than `GamePad Right Trigger` when displayed on a small action button.
- Moved classic spell rank display to the action button back-end. 
- Moved our improved MaxDps support to the action button back-end. Will expand on this later.
- Improved how our action button back-end reassigns keybinds to the petbattle system, in a manner that actually gets the right buttons no matter the order action buttons were spawned in. 
- Holy Power should now remain visible regardless of current target, in the same manner as Soul Fragments and Runes.
- Slightly shrunk and adjusted the height and vertical position of the objective's tracker in retail, to make sure it doesn't collide with target frame auras or temporary totem buttons above the minimap.
- Spam output generated by MaxDps using AceConsole is now filtered out from the chat if our spam filter is enabled. 
- Completely violated the Narcissus minimap button's right to choose. 

### Fixed
- Added a fix for a bug in Blizzard's `ContributeButtonMixin.UpdateTooltip` method in their `Blizzard_Contribution` addon. Shouldn't be any more bugs when hovering over buttons accepting multiple contributon currencies anymore.
- Libraries that automatically look for and call methods of modules they are embedded in will no longer attempt this with force disabled modules. This was causing some bugs when addons like Glass was used, or just any other time certain modules were auto-disabled from the presence of conflicting addons.

### Removed
- Removed most code specific to BfA, and changed any Shadowlands code into just Retail code, since the 9.x API now is the current one.

## [3.0.422-RC] 2020-10-27
### Fixed
- Role counts, role check and the world marker flag button have returned to our retail group leader tools!

## [3.0.421-RC] 2020-10-26
- Various work on the Legacy theme which for the most part will remain undocumented for the time being, as it is not even considered an Alpha feature at this point.
- Started work on much better MaxDps integration in preparation of our upcoming multi-theme system. No extra work is required from MaxDps as we're able to handle this from our end to provide the users with a seamless experience no matter the theme, button shape or bar layout.

### Added
- All classes and specs can now choose between at least the Slack and Spam aura filters, allowing them to permanently hide various static spam. The Strict filter is currently only available for Mages, Warriors and Druids. I refer to my patreon goals if you wish to know how you can accelerate my work on this: [www.patreon.com/goldpawsstuff](https://www.patreon.com/goldpawsstuff)
- Added most Hallow's End costumes to the aura whitelist to easier be able to disable them. Because they suck. >:(

### Changed
- To reflect the recent level squish in retail, we have lowered the level where your unit frame loses its noobwood and turns to stone to the level you learn to fly, which now is level 30. The rocky level remains level 40 in classic, as this is when you get your first mount and your build starts to become somewhat usable.
- Slightly increased the selected nameplate top inset, to make sure the top row of nameplate auras remains on-screen.
- Changed the width limitations of worldframe tooltips, as these were weirdly large from Blizzard's end on the 9.0.2 beta realm.
- Added a lot of predefined font family objects to be able to show unit names in mixed alphabets. Mostly noticable on the 9.0.2 beta realm where people from all over the world is gathered, but should also fix any problems with showing Cyrillic names on EU clients.
- Started moving the new forge driven schematic tables to their own aptly named area in the folder hierarchy.
- Modified the aura plugin back-end to parse and sort the entire aura table before deciding on visibility. Work in progress.

### Fixed
- Fixed several issues where a unit's name and health would be displayed as tapped, even though this wasn't a unit your faction could attack. 

### Removed
- Removed the actionbar slot visibility system for empty slots, as it was buggy and not working as intended. We just hide the empty ones for now, as that is consistent, if nothing else.

## [3.0.420-RC] 2020-10-17
### Added
- You can now keybind the Azerite options menu. You can find it in Blizzard's keybind interface under the AddOns category towards the bottom, where other addons such as Bagnon and GatherMate2 live too. 

### Fixed
- Fixed some inconsistencies with return values in the cast library, which caused issues such as all channeled casts being displayed as uninterruptable.
- Fixed an issue that would cause the zone ability button to not be properly styled on the initial login if the button was visible in your current zone.
- Fixed an issue that sometimes would cause the quest tracker to not be styled or positioned on the initial login.

### Removed
- Removed a temporary workaround to make the addon MaxDPS work properly in WoW Client Patch 9.0.1. The issue was fixed upstream on MaxDPS' end, and our fix is no longer required. So go update it, slackers!

## [3.0.419-RC] 2020-10-15
### Fixed
- Absorb bars should once again be visible on all units.
- Absorb values should once again be visible on the player- and target unitframes.

## [3.0.418-RC] 2020-10-14
- Add back some Blizzard API methods just to make maxDPS function. Temporary fix.

## [3.0.417-RC] 2020-10-14
### Added
- Added updated and rearranged minimap blip icons for WoW client patch 9.0.1.

### Changed
- Holy Power should now be visible for all paladins.

### Fixed
- Worked around an issue with nameplate scaling introduced in WoW client patch 9.0.1, where our nameplates wouldn't follow the blizzard nameplate scaling, resulting in the nameplates often getting stuck at near zero size at the beginning of a fight.

## [3.0.416-RC] 2020-10-14
### Changed
- Changed most modules to simply NOT enable themselves if no stylesheet for the current theme was found. This should free us from a lot of development errors, and give us much more freedom as to how and when we add modules to the themes.
- Lowered the framestrata of various elements to not cover elements from the addon Immersion. We love Immersion.
- Moved the digsite progress bar slightly upwards, to avoid it colliding with the pet bar, the cast bar and the player alternate power bar. Can we please have MORE bars, Blizzard, because there's not enough. *dripping sarcasm*

### Fixed
- The time from 12:00 and 12:59 according to a 24-hour clock should now be labeled PM when using the 12-hour clock, instead of AM as it would previously show. Sorry for years of messing this up, but it's ASS BACKWARDS only ever counting from 1 to 12. The countries using the 12-hour clock should wake up to the 21st century. Hell, even the 20th would do. There. I said it. Bug fixed, though. :)

### Removed
- As Blizzard enabled their threat API for classic in patch 1.13.5, the library LibThreatClassic2 was no longer needed, and thus we have removed it from the addon. This should give a slight performance boost in some cases.

## [2.1.410-RC] 2020-09-29
- Hard git reset to force the missing file updates. What the actual fuck is going on?

## [2.1.409-RC] 2020-09-29
### Changed
- Several changes to structure and file names.

### Fixed
- Fixed some incompatibilities in a new library that caused errors in WoW Classic.

## [2.1.408-RC] 2020-09-27
- We needed an updated file.

## [2.1.407-RC] 2020-09-27
- More stuff moved into the back-end sections.

### Changed
- Moved the zone ability button, the extra action button, the durability frame and the vehicle seat selector closer to the minimap and farther away from the center of the screen, as they were all getting in the way of the gameplay.

## [2.1.406-RC] 2020-09-17
- Continuing the work of squashing all we can into the back-end sections.

### Changed
- There may or may not be some additional chat styling attached to the chat styling setting now.

### Fixed
- The player area should no longer fade out when you have a vehicle actionbar. This was causing problems with some world quests like the psycho turtles ones.

## [2.1.405-RC] 2020-09-16
### Changed
- Lowered the frame strata of most blizzard floating widgets (like the vehicle seat indicator) to prevent them from overlapping Immersion dialog choices.

### Fixed
- Changed how the floating castbar is toggled, so it shouldn't be invisible on first time logins for new characters anymore. 

## [2.1.404-RC] 2020-09-15
### Fixed
- Fixed the previous fix.

## [2.1.403-RC] 2020-09-15
### Changed
- Fixed an issue where sometimes when accepting flights in quest could cause the pet frame to hover in mid-air with no playerframe for a few seconds.

### Fixed
- Fixed a division by zero that sometimes could occur within the cast element on some forced updates.

## [2.1.402-RC] 2020-09-13
### Changed
- The retail Shaman totembar is now located above the minimap. Might seem a bit out of the way, but that is the point. I kept accidentally clicking off totems when it was placed in the middle, and I wasn't the only one.

### Fixed
- Fixed an issue where zoning into a rested area sometimes could cause a bug if the rested xp information wasn't available from the game yet.

## [2.1.401-RC] 2020-09-04
- Bumping the minor addon version because of backwards incompatible file structure, not because of any sparkling new feature.
- Extra important to remember to exit the game client before updating now, as I'm in the process of re-arranging the file structure, squashing down some of the content, and moving all we can to a generic back-end which works for all our user interfaces, not just this one. I'm doing this in a manner that should make no difference to the regular user, but will cause some extra work for tinkerers that manually modify the files, as most of the editable ones in the front-end now have changed position. In the end the UI will be easier to edit, though, so hang in there!

### Changed
- Swapped the middle and right click actions on the cogwheel button. Middle button now opens the user interface menu, and right button opens the Blizzard micro menu and access to the standard game panels. The left click action to toggle your bags remain unchanged.

### Fixed
- Fixed an issue where the saved aspect ratio wasn't updated on logon or reloads, just on settings changes. 
- Fixed an issue where enabling the pet bar during combat would cause the explorer mode mouseover anchors to bug out.
- Fixed an issue where the pet bar would remain hidden on mouseover until fade settings change, if the bar was initially disabled upon login or reload and changed to enabled.

## [2.0.400-RC] 2020-08-30
### Added
- Hunters (Retail) now both have aura filter choices, as well as a few aura lists to make them viable (which was missing in the previous update). 
- You can now also disable on-screen raid warnings, boss and monster emotes, boss kill announcements, level up announcements and loot announcements from the HUD menu!

## Fixed
- Made the method used to hide various HUD widgets a bit safer, to avoid some logon bugs when switching character.

## [2.0.399-RC] 2020-08-30
- Continuing the work on 9.0.1 compatibility, though chances are there will still be endgame bugs on the PTR and in the beta. Please do NOT report them. They are per say not "real" bugs, I just haven't reached that point yet. I am not in the beta, and the PTR takes 5-10 minutes to log into, then I get randomly disconnected after 2-3 minutes. Working there is hard. And takes time. 
- First round of changes to move a lot more of the generic code into the back-end. The goal is to make the UI far more stylesheet-driven, making it easier for others to edit, and easier for me to transfer to other UIs. No ETA on this mad scientist change, nor any guarantees I'll actually take it all the way.

### Changed
- Windwalker Monks with the Ascension talent should now get all their 6 Chi visible at once.
- Did some more adjustments to the nameplate distance- and target scaling, as our previous changes were a bit too extreme.
- Chat bubbles should now be visible in instances when not engaged in combat, making it easier to understand what is going on before boss encounters or during the large amount of dialog in some scenarios.

## [2.0.398-RC] 2020-08-28
- First round of changes to make this WoW 9.0.1 compatible. Note that due to loading issues and client instability, I have been unable to test most max level features at this point, and have only been able to play a fresh character leveling in the new starting zone. The fixes reflect this. Also note that the majority of changes, bug fixes and updates related to this will NOT be listed here while 9.0.1 is still on the PTR and not live. 

### Changed
- Action button backdrops become visible and buttons faded in when holding a pet ability on the cursor in retail now.

### Fixed
- Added a raid frame sorting call after toggling the frames on from the menu. This should hopefully solve the bug of raid frames not appearing.

## [2.0.394-RC] 2020-08-20
### Changed
- The UIs master frame is now forcefully turned visible upon entering combat, and a previous system that hid it when zoning between instances has been disabled, as this was proving to be buggy.
- The slightly delayed UI fade-in after logging in or reloading has been disabled. This might too have misfired at some point. Taking the safe route today.

## [2.0.393-RC] 2020-08-14
### Changed
- The minimap blip icon for the city mission boards leading to the various BfA storyline chapters now have a similar exclamation mark to the others. 
- The new rare/elite/boss icon on the nameplates now ignores the nameplate alpha. They look weird when faded, and we want to know the classification at all times. This is really needed when deciding what plate to click for the rare mob that's about to die in half a second. 
- The buff and debuff unitframe plugins - which this UI actually doesn't use - now obeys the same filter rules as the aura element does. This is just a bonus inherited from the GoldpawUI7 development. 
- The Irontide Recruit buff is now whitelisted regardless of aura filter level. This is a buff we need to toggle during the Tiragarde Sound storyline.

### Fixed
- Fixed another issue related to the objective tracker's random loading order. Hopefully we're done with these bugs for a while now. 
- Fixed nameplate castbar spell name alignment, as this would only be fully correct directly after changing between a protected and regular cast. Now it updates on every cast.

## [2.0.390-RC] 2020-08-13
### Fixed
- Fixed a back-end issue that would break the UI for some users, as it wrongly assumed the Blizzard_ObjectiveTracker always would be loaded prior to itself. Which it isn't. Though it strangely enough always is for me. 

## [2.0.389-RC] 2020-08-12
### Fixed
- Fixed a back-end issue introduced in the previous update that could cause a bug when name info was unavailable on a unit frame.

## [2.0.388-RC] 2020-08-12
### Changed
- Updated the UI switcher chat commands for compatibility with new upcoming UIs. More on this later!

### Fixed
- Modified Minimap back-end to not require our objectives tracker module anymore. Also detached Minimap alpha from the rest of the UI. We don't want to fade this frame in and out, the actual map section and its blips and pins is incompatible with this. It is now possible for tinkerers to disable the objectives tracker and minimap modules form the ToC file separately.
- We previously scaled up the Minimap blip icons about 15%, as it simply looked better. This has proven to be incompatible with addons adding their own pins to the Minimap, like GatherMate, HandyNotes or Questie, so we are removing it and going back to tiny icons. 
- We are now re-applying the game's saved setting for Minimap rotation after logging in, in an attempt to forcefully update the rotation setting in addons adding their own pins to the Minimap, as this sometimes simply did not happen after reloads, and icons would act as if no rotation was enabled, even though it was. Experimental solution, still keeping an eye on this.

## [2.0.387-RC] 2020-08-09
### Changed
- Styled a few more Minimap blip icons for better consistency.

### Fixed
- Fixed an issue that sometimes would produce a bug if a new nameplate was created in the middle of combat.
- Fixed an unalignment issue with nameplate castbar spellnames.

## [2.0.386-RC] 2020-08-09
### Fixed
- Our raid frames appear instantly once again, and not just when changing between 26 or more and 25 or less group members. The bugs get ever more interesting.

## [2.0.385-RC] 2020-08-08
### Added
- Trying to see if our pretty Nazjatar rune/line minigame interface works without imploding the game client this time.

### Changed
- No more Blizzard raid frames. We tried having it compatible for a while, it didn't work out. Use our frames, or another 3rd party raid frame addon like Grid.
- Re-adjusting most nameplate element anchors to use nameplate corners instead of the nameplate center as their reference points, as the center regions for some reason are super buggy in the game and somehow tends to make the elements drift. Parts of the nameplate are rendered by the game engine, and not the UI. And when the game devs venture into UI territory, it usually turns out comparibly to a dog standing on two legs thinking itself human. This change may or may not solve the problem.

### Fixed
- Fixed a mixup that would cause aura buttons set for mouse input to not get any, and those set to ignore mouse to get mouse input. It should once more be possible to cancel auras out of combat now. 

## [2.0.384-RC] 2020-08-07
### Fixed
- Fixed a wrong upvalue that would cause the Personal Resource Display (your own nameplate) to break.

## [2.0.383-RC] 2020-08-07
### Added
- Added Demon Hunter Soul Fragments tracking to our class resource system.

### Fixed
- Fixed a bug where the experience percent value on the minimap badge sometimes would show the percentage sign, cluttering up everything.
- Fixed a bug that made nameplates unclickable. 

## [2.0.382-RC] 2020-08-07
### Added
- Nameplates now show unit names when targeted or mouseovered, or if it's owner is attackable and you're currently engaged in combat.
- Nameplates belonging to attackable units now show health values when targeted or mouseovered.
- Nameplates belonging to attackable units now show a classification badge for rares, elites and bosses, in the same manner the target unit frame currently does.
- There should now once more be a threat glow around nameplate healthbars.

### Changed
- Classic target nameplate is now locked to the screen, thanks to the new CVar `clampTargetNameplateToScreen` introduced into the game July 14th 2020. 
- Most threat glows and threat coloring should even in Classic be visible when solo or outside of instances now. The setting might be affected by other addons using LibThreatClassic2 turning it off.

### Fixed
- Changed how the default Blizzard pet unit frame is hidden, as this was affecting the retail totem bar, causing it to not appear at times.

## [2.0.380-RC] 2020-08-03
### Added
- Trying out a new tooltip texture. Work in progress!
- The retail totem frame should be available now!

### Changed
- Split the chat filter setting into multiple options for styling and filtering.
- Adjusted how action button stack/charge count is detected. Should see a few missing things now.

## [2.0.379-RC] 2020-08-02
### Changed
- (Classic) TOC bump to WoW Classic Client Patch 1.13.5.
- (Classic) Updated Minimap blips to patch 1.13.15.
- (Retail) Updated Minimap blips to patch 8.3.7.

## [2.0.378-Alpha] 2020-08-01
### Added
- Protected casts should now have a shielded nameplate castbar.

### Changed
- Actionbuttons above the 7 default ones now fill towards the right in an up and down zig zag manner, instead of by rows as previously. This will probably mess up the bars for a lot of people. I'm fine with that, as it's a better choice to keep the bars this way, letting them grow as a solid unit from left to right.
- Actionbuttons will now show empty slots only for single empty slots which has a filled button to both its sides, while other empty slots will be hidden.
- You should see less "Failed" messages for spells that are interrupted within the spell queue window and actually completed despite the interruption.
- Healthbars are now colored according to threat where applicable. This update only applies to Retail, Classic will be done next week as it requires a little more work to avoid any additional performance cost during large group combat.

## [2.0.377-Alpha] 2020-07-30
### Fixed
- Fixed the wrong upvalue in today's previous update. You should no longer get a bug everytime something goes on full cooldown.

## [2.0.376-Alpha] 2020-07-30
### Fixed
- Retail spell charge cooldowns are now in place!

## [2.0.375-Alpha] 2020-07-23
### Fixed
- Monks should finally get their mana orb back in retail. 
- Neutral Pandaren no longer has to wait until they've chosen a faction to be able to use the micromenu without causing a bug. 

## [2.0.374-Alpha] 2020-07-14
### Fixed
- Bufftimers in certain retail quests and world quests (like "Show-Off" where you mount Cooper and score style points) should no longer bug out!

## [2.0.373-Alpha] 2020-07-07
### Changed
- Restricting certain checks and updates done by unitframes and nameplates in an effort to increase the performance in large groups a bit.

### Fixed
- Working around some issues related to checking for threat in retail.

## [2.0.372-Alpha] 2020-07-02
### Changed
- Lowered the objectives tracker strata, to prevent it from covering the Immersion buttons.

### Fixed
- Attempting a different set of visibility conditionals to avoid the pet action bar popping up as a copy of the main bar in certain Retail world quests like Beachhead.
- Fixed the Retail issue where logging in after having logged out while inside an instance would lead to weird errors.

## [2.0.371-Alpha] 2020-07-02
### Fixed
#### Retail
- Fixed an issue that would cause our keybind interface to bug out when you attempted to save the new bindings.

## [2.0.370-Alpha] 2020-07-02
### Fixed
- Tried to fix some inconsistencies in when the "Failed" message appears on the castbars.
- Fixed an issue related to multiple unregistrations of custom messages, that amongst other things affected the chat module and caused problems when using Prat. 

## [2.0.369-Alpha] 2020-07-01
### Fixed
- The fader system should no longer randomly throw errors upon logging in while inside an instance.

#### Retail
- You should no longer be spammed with messages upon entering or leaving a grouped instance.

## [2.0.368-Alpha] 2020-07-01
### Changed
#### Retail
- The Personal Resource Display now has a power bar. 
- The Personal Resource Display's castbar now shows the currently set spell queue window. Remember you can always change this with `/run SetCVar("spellQueueWindow", 55)`, where you replace the number `55` with your desired queue window in milliseconds. For a fluent gameplay for melee I recommend adding 5 to your world latency, and rounding up to the nearest 5 after that. Meaning if your latency is 28ms, you should put the spell queue window to 35ms. If you're a caster that thrive on spell batching to the point of madness, putting it to something outlandishly high like 400ms would probably work well. 
- The Personal Resource Display now grows towards the right, like the player unitframe. This is to match the said player unitframe, and also to make sure this special nameplate stands out from all the others. 
- The floating on-screen castbar is now disabled when the Personal Resource Display is enabled, since they occupy the same area on the screen.

### Removed
#### Retail
- The Blizzard interface options menu entry to show target of target has been removed, as it does not apply to our unitframes.
- The Blizzard interface options menu entry to show combo points and personal resources on the target plate has been removed, as we're already using a very centered system for secondary resources like combo points, runes, holy power and so on.

## [2.0.367-Alpha] 2020-06-29
### Fixed
- Chat filters should no longer bug out when you receive the awesome amount of 0 gold, 0 silver and 0 copper.

## [2.0.363-Alpha] 2020-06-29
### Fixed
- Chat filters should no longer bug out for non-English game clients. Tested with at least deDe.

## [2.0.362-Alpha] 2020-06-28
This update contains WoW Retail compatibility. A major part of this update is in that added compatibility, and a lot of features that previously only were a part of the Classic version will now also be a part of the Retail version. The project version has because of this been bumped to indicate the amount of added, changed and updated features, as well as the number of builds we've passed since the last public update. This changelog is meant to be read by humans, by the users, and thus will not include most of the numerous back-end changes.

### Added
- Added aspect ratio features, which allows you use the full width of the monitor or limit it to either a 21:9 ratio, or have it remain at the now default 16:9 setting, as the UI originally was designed for.
- Added a new optional default feature to have the chat window move to the bottom of the screen when player explorer mode is enabled, and the player area is faded out. This does not affect the chat window when healer mode is enabled, nor when you have a target, are engaged in combat, or any of the other elements that would cause the player area to fade back in. Furthermore, when hovering over either the player area or the chat window, the chat will return to its original position, and remain there until a few seconds after you move the mouse cursor away.
- Added a new optional default feature to clean up the multitude of chat messages sent by the game client, like when you gain loot, gold, experience, reputation, skill levels and so on. This filter does not add any messages, it only affects or throttle message types you already have chosen in your blizzard chat window settings to display in the first place. The idea is to allow you to have the kinds of messages you normally would put in separate windows in your primary one instead, without it feeling cluttered or messy. 
- Added a resting indicator to the zone name located next to the minimap.

#### Classic
- Added strict aura filter lists for Druids, Mages and Warriors, as well as menu options to choose the filter level. The other classes are getting it too, just haven't gotten there yet!
- Added threat glow to the player- and target unitframes.
- Added better Questie compatibility in unit tooltips.

#### Retail
- Added strict aura filter lists for Druids, Mages and Warriors, as well as menu options to choose the filter level. The other classes are getting it too, just haven't gotten there yet!
- Added extensive aura filter whitelists for all current BfA instances and raids.
- Added pet bar and visibility options for it. 
- Added minimap blips for WoW client patch 8.3.0.
- Added the option disable the floating castbar, and the player class power elements.
- Added a new feature that hides the rest of the interface when the Nazjatar minigame world quests are in progress, as well as put a large exit button in the upper right corner of the screen during those minigames. The minigames currently affected are the non-vehicle ones, meaning the Bejeweled ripoff and the line untangling. This feature is not available when you are part of a raidgroup, but then again, the world quest can't be completed then anyway, so that should be a non-problem.

### Changed
- Any type of eating or drinking while explorer mode is enable should force the interface to fade back in now. We previously used auraID to identify eating and drinking, but seeing as blizzard just keeps adding more and more versions of the same action, with the same name, it made sense to just identify this by name instead.
- Changed the default fallback aura filters for all unit frames and nameplates. Also note that classes that haven't gotten their strict filters finished yet, will automatically fall back to the most inclusive version of the aura filters, to ensure important auras are visible.

#### Retail
- Death Knight runes are never fully hidden anymore. This will only be the case for runes, not other types of class resources.

### Fixed
- Changed the search patterns deciding the spell cost in our actionbar tooltips. Any type of resource cost should now be detected and displayed. This was previously an issue hiding multiple spell costs from several classes and vehicles.
- Changed how difficulty coloring is decided for both Classic and Retail.

#### Retail
- The blizzard minimap widgets like PvP capture bars and the Azshara fight's Ancient Wards should now be visible above our minimap.

## [1.0.115-RC] 2020-04-01
### Fixed
- Solved an issue where pet bar actions that required a right-click weren't usable through their keybinds, only through the aforementioned right-click.

## [1.0.114-RC] 2020-03-30
### Added
- Added a battleground chat filter that removes all messages about players joining or leaving, in an effort to make the chat more readable.

### Changed
- Changed the default number of actionbuttons to 7, as the user interface was intended to have in the first place. Options to add more will always remain.

## [1.0.113-RC] 2020-03-15
### Added
- Added chat outlines. This is enabled by default, but can be toggled through the menu.
- Added highly experimental temporary enchants. Placement and design should only be considered placeholders. Shaman weapon buffs should be possible to remove in combat by right-clicking, but this is currently untested.

### Changed
- Optimized the spell activation highlight code a bit. Changed how timers are disabled.

### Fixed
- Fixed an issue that would cause a bug on logon and reloads when only the main 7 actionbuttons was enabled.
- Fixed issues related to reactive spell highlighting, where spells sometimes wouldn't trigger properly, or not go away once triggered.

## [1.0.107-RC] 2020-03-11
### Changed
- Updated minimap blips to work with patch 1.13.4.

## [1.0.106-RC] 2020-03-11
- Updated for WoW Classic Client Patch 1.13.4.

### Added
- Added spell activation highlights for Hunter Counterattack and Mongoose Bite.
- Added spell activation highlight for Paladin Hammer of Wrath.
- Added spell activation highlight for Rogue Riposte.
- Added spell activation highlights for Warrior Execute, Overpower and Revenge.

### Fixed
- Fixed a problem where the group debuff display wouldn't properly update on unit GUID changes. Fixed it in the plugin, but plan to write this into the aura back-end to make sure all modules and plugins using it automatically gets updated.

## [1.0.105-RC] 2020-03-05
### Changed
- Further adjusted the spell highlight coloring a bit. This is a work in progress, as I want the three highlight types to have easily identifiable coloring, stand out when active, and still fit the general coloring of the user interface.

### Fixed
- Finishing move spell highlights for rogues and druids should have consistent coloring now, and not suddenly switch to the reactive coloring.

## [1.0.104-RC] 2020-03-03
### Added
- Added Rogue and Druid finishing moves spell highlighting when combo points are maxed out.

## [1.0.103-RC] 2020-03-01
### Fixed
- Fixed an issue with the dispellable group frame debuff display that could cause an error when leveling up.
- Fixed an issue that could cause exact mob health values to not be displayed. This was related to API changes in the classic client that since February 18th 2020 now reveals exact mob health to the player, where we previously used RealMobHealth interaction to show this.
- Redid how it is decided whether a full health value is available or not.
- Made the clearcast highlight color brighter, as it wasn't standing enough out from its surroundings.
- Attempting to work around an issue that would cause a bug and require a `/reload` upon reaching level 60. A little hard to reproduce, though.

## [1.0.101-RC] 2020-02-29
### Changed
- Actionbutton spell highlight alerts have been moved to a new back-end of its own. 
- Actionbutton spell highlights have gotten new coloring. Clearcasts are now blue, reactive abilities bright yellow, finishing moves range.
- Added Shadow Bolt highlighting when Warlock Shadow Trance is active.

### Fixed
- Fixed an issue in the mana orb plugin that would sometimes cause it to be forcefully reshown even though the element had been disabled.
- Fixed an issue where a custom styling method would overwrite the minimap module's ring bar text display, and people hitting new experience- or reputation levels would still be seeing the "New" text.

## [1.0.99-RC] 2020-02-28
### Added
- Mana users now now have the option to use the azerite crystal for all power types, instead of the mana orb.
- There are now mana bars visible for mana users on the group frames. Note that for non-healer units the bars will only become visible when the unit is running really low on mana.
- Chat spam on logon or manual reloads is now suppressed. This is a forced setting. The Guild Message of the Day will be shown after roughly 10-12 seconds after logging in or reloading the interface. Messages after zoning in or out of instances and other portals are not affected.

### Changed
- Most non-targeted nameplates should be more visible both in and out of combat now, making tanking and healing easier.
- The dispellable debuff display on group frames now checks if the character has high enough level to actually do the dispel.
- Debuffs on unit frames belonging to hostile units are now all colored red, as displaying the debuff type using color should only be used for dispelling purposes.
- Debuffs on hostile units not cast by the player is now desaturated.
- Buffs on friendly units not cast by the player is now desaturated.
- Auras are now sorted. 
- Auras on the target frame when you target a boss now take advantage of the larger width of the frame. 
- The chat frame buttons should now always be visible if the frame isn't currently scrolled to the bottom of its content.
- When just having reached a new level, or reputation level if that is what you're current tracking, the minimap badge text should now be an asterisk `*`, and not the word "New". The latter was never intended, as we used a graphical exclamation mark in the retail version of this addon, but Blizzard changed that to the text "New" to better reflect how their quest dialogs looked in vanilla.

### Fixed
- When a group frame's unit changes while mouseovered, its tooltip should now properly update to show the new unit.
- When the target frame's unit changes during a cast or channel and the new unit isn't currently casting or channeling anything, its castbar should now properly be cleared.

## [1.0.98-RC] 2020-02-14
### Added
- The pet bar now has similar fading options as the additional action buttons. So in addition to fully being able to toggle the pet bar, you can now choose its visibility between always, in combat and mouseover, or only on mouseover.

## [1.0.97-RC] 2020-02-14
### Changed
- Player and target unit frames should now display two rows of auras, up from one.

## [1.0.96-RC] 2020-02-12
### Added
- Added cooldowns to the pet bar.

### Changed
- Updated love festival dates for 2020.

### Fixed
- May or may not have fixed an issue with additional action buttons not fading properly.

## [1.0.95-RC] 2020-02-06
### Added
- The pet buttons have been added to the `/bind` mode.

### Changed
- Actionbutton backdrops no longer become visible when you're holding a pet ability on the cursor. This was a remnant from retail where it's possible to put pet abilities on normal actionbars, something we cannot do in Classic.

### Fixed
- You should now be able to toggle autocasting of pet abilities by right-clicking the ability on the pet bar, or using your keybind.
- The Blizzard reputation watch bar should no longer invisibly interfere with your ability to click the bottom part of the action bars when you are tracking a reputation.

## [1.0.94-RC] 2020-02-03
### Added
- Added the first draft of the pet bar. Finally you can order your pet around, do something else than just stand there while mindcontrolling opposing players, and even finish killing Emberstrife for your UBRS attunement quest without having to disable the addon mid fight. 

### Changed
- Primary chat window buttons will now become visible when hovering over the window.
- Empty backdrops of actionbuttons will now be visible if there are visible buttons with content farther down along the bars. This is to prevent "holes" in the layout.

### Fixed
- PvP rank names in unit tooltips should no longer show your own faction's rank names on players from the opposite faction.

## [1.0.93-RC] 2020-01-29
### Changed
- 5 player party frames will no longer be used when player is in a raid group, even if that raid group has less than 5 total members. Party frames by default only show the raid subgroup you're in, leaving people placed in other groups invisible. This behavior was unintended, so we're sticking to party frames with portraits for parties, and smaller raid frames for any and all raid groups. 

### Fixed
- Finally fixed the small frame flickering after interrupted casts. This was an issue related to the frequent updates of frames lacking distinct unit events, like the ToT frame.

## [1.0.92-RC] 2020-01-29
### Fixed
- Party aura tooltips show now grow towards the right, instead of towards the left and straight out of the screen. Now you can read them.

## [1.0.91-RC] 2020-01-28
### Added
- First draft of aura durations added. Better filtering and display coming this week! Yay!

## [1.0.90-RC] 2020-01-11
### Added
- Spells that require reagents should now show their remaining reagent count when placed on the action bars.

### Fixed
- Trying to work around some language issues that would cause placing items on the actionbar to sometimes bug out when hovering over them. The issue was related to different formatting of some game strings in English and non-English clients.

## [1.0.89-RC] 2020-01-09
### Changed
- Added a forced update of all ToT unitframe elements on player target change, as this previously had up to half a second delay on player target changes when the ToT frame remained visible throughout the change.

## [1.0.88-RC] 2020-01-07
### Added
- Added subgroup numbers to the bottom left part of the raid frames. No more headache trying to figure out who's in what group, or where the Alliance AV leecher you want to report is!

### Fixed
- Fixed an issue with some raid frame elements like leader/assistant status as well as raid marks which sometimes only would update on a GUID change.

## [1.0.87-RC] 2020-01-05
### Fixed
- Fixed a typo in the frFR translation that caused reputation tracking on frFR game clients to bug out.

## [1.0.86-RC] 2019-12-31
### Added
- Added the very first experimental draft of our spell highlight system. Druids with Omen of Clarity will now find that Shred, Ravage, Maul and Regrowth are marked when their clearcast proc fires. This is a work in progress, and I'll expand the list for more classes, as well as write other methods into this system to light up reactive abilities like Warrior's Overpower and similar.
- Started on the nameplate aura blacklist. Certain spam like Mark of the Wild, Leader of the Pack and various other auras will no longer show up on party member nameplates. This too is a list in growth.

## [1.0.85-RC] 2019-12-18
### Changed
- Expanded the group frame hitboxes to cover the bottom part of the health border as well. Super easy to select targets now.
- Further tuned the outline and shadow of both the raid warnings and error messages.
- Dispellable and boss debuffs visible on the group frames should should now always be fully opaque, even if the group frame itself is faded down from being out of range.

### Fixed
- Fixed an issue that prevented raid marks, leader- and assistant crowns as well as main tank and main assist icons from showing up on the raid frames.

## [1.0.84-RC] 2019-12-17
### Changed
- Prettied up the raid warnings a bit more.
- Slightly trimmed the popups.
- Went for a more elegant fix for the bg popups, where instead of changing their text hide them completely. Now a flashing red message - in addition to the usual bg ready sound - will tell you how to enter the available battleground. This change is Tukz-inspired.

### Fixed
- Fixed the health value of group member pet tooltips, where their actual health value would be presented with a percentage sign behind. That was a visual bug, the value was their actual health all along.

## [1.0.83-RC] 2019-12-16
### Changed
- Boss/dispellable debuff slot on group frames should no longer react to mouseover events. There won't be a tooltip anymore, but it won't be in the way of clicking on the unitframe to select it as your target anymore.
- RaidWarnings shouldn't look as freaky and warped anymore, as we have disabled certain very faulty scaling features the default user interface applies to these messages. We also changed the font slightly to make it more readably on action filled backgrounds in raid situations.

## [1.0.82-RC] 2019-12-15
### Changed
- Fixing a wrong date in some secret code. No biggie, it'll fire tomorrow for those lacking this update. But I want pretty colors!

## [1.0.81-RC] 2019-12-14
### Changed
- The minimap tracking button now changes position based on whether the BG eye is visible or not.

## [1.0.80-RC] 2019-12-12
### Changed
- Removed the ability to enter BGs through the bugged popup. Now we'll have to learn to use the eye, or simply not get anywhere. I changed the text in the popup to reflect this new behavior. This is a temporary fix until I can figure out how to get a working BG entry popup again.

## [1.0.79-RC] 2019-12-11
### Fixed
- Both the Minimap button and BG entry popup should work... better, now. 

### Removed
- Removed the popup styling. It's problematic right now.

## [1.0.78-RC] 2019-12-11
### Fixed
- Fixed spam filter issues. Clearly chat events have changed since I was a young noob. Luckily this older noob figured it out.

## [1.0.77-RC] 2019-12-11
### Changed
- Only apply our spam removal to system messages. That should be the correct message group.

## [1.0.76-RC] 2019-12-11
### Added
- Added the Minimap Battlefield button. We're using our green groupfinder eye from the retail version of this addon.
- Added a minor chat filter to remove the "You're not in a raid group" spam that keeps happening within Battlegrounds. Cause can be other addons, but for now we're just filtering it out.

### Changed
- Slightly re-aligned the Minimap tracking button to make a little room for the new Battlefield button.
- Added back the Minimap blip textures, as they appear to be more or less unchanged from the previous patch.

### Fixed
- The Blizzard static popups will no longer be repositioned by us to accomodate our styling of them, as this was causing taint with the new Battleground popups, making the enter button unclickable. This change might cause some graphical overlap in situations with two popups visible at once, though this should be purely visual and not affect the ability to click the buttons. We'll come up with better styling soon. 

## [1.0.75-RC] 2019-12-11
### Added
- Added the keyring button to the backpack.
- Added in some groundwork for a couple of upcoming features.

### Changed
- Updated the TOC version to WoW Client Patch 1.13.3.
- Adjusted statusbar code to avoid a very subtle wobbling that nobody but me seem to have noticed.

## [1.0.74-RC] 2019-12-04
### Fixed
- The chat window position should once again instantly update without needing to reload when the Healer Layout is toggled in the menu.

## [1.0.73-RC] 2019-11-29
### Added
- Added back Blizzard's `/stopwatch` command. The stopwatch exists in Classic, so why not?

### Changed
- Left-Clicking the clock now toggles the stopwatch.
- Casts should no longer appear to continue after the unit has died.

## [1.0.72-RC] 2019-11-20
### Added
- Added in group tools with raid icon assignment, ready check and raid/party conversion buttons.
- Added player PvP titles to unit tooltips.

## [1.0.71-RC] 2019-11-20
### Fixed
- The blizzard durability frame should once again be hidden, preventing double up when our own is shown. 

## [1.0.70-RC] 2019-11-16
### Added
- Tooltips should now display when units are civilians. Gotta stay clear of those Dishonorable Kills! 

### Changed
- Adjusted nameplate raid icon position to stop it from colliding with the auras. 
- Tooltip health values now show a percentage sign when only percentage and not the real health value is available.

## [1.0.69-RC] 2019-11-08
### Changed
- The HUD castbar is now anchored to the bottom rather than the center of the screen. It has also been moved farther down, to not be as much in the way.
- Removed the target level badge for most units. 
- Added the target's level to its name text, like in the tooltips.
- Added the small target power crystal for all units that have power. 
- Changed the small target power crystal to be slightly larger, and slightly more toned down. 

## [1.0.68-RC] 2019-11-07

_**DISCLAIMER:**_  
_Loss of limbs, life or sanity is not the responsibility of the author._

### Changed
- There is now a new HUD entry in our options menu, where you can choose to disable the combo point display and the on-screen castbar. 
- Added a highly experimental feature to work around the Blizzard issue where macro buttons sometimes are missing their info and icon until the macro frame is opened or the interface reloaded. This fix might cause the whole universe to implode, and you're thus installing this at your own risk. 

## [1.0.67-RC] 2019-11-02
### Fixed
- Targeted high level hostile players should no longer get a wooden unit frame border, but instead the same spiked stone frame as max level units.
- Skinnable dead units should once more show that they can be skinned in the tooltips. This applies to both units that can be skinned for leather, as well as herbs or ore. 

## [1.0.66-RC] 2019-10-29
### Changed
- Started major reformatting of stylesheet and unitframe styling code structure. First step in changes that eventually will affect the whole addon. 
- Every time you reach a new reputation standing or experience level and your current value in these are below one percent, the minimap badge tracking these will now show an exclamation mark instead of the non-localized "xp" or "rp" texts they used to show. 
- Tooltips should now show dead players in spirit form as simply "Dead", not "Corpse". 
- Tooltips now indicates the rare- or elite status of NPCs much better. 

### Fixed
- Health numbers and percentages should no longer be visible on critters with the tiny critter unitframe, even if they're above level one. 
- Changed the way the blizzard gametooltip fonts are set to work around some alignment issues that arose in a recent version.
- Fixed an issue where the vendor sell price in some cases (e.g. AtlasLoot) would be displayed twice in the same tooltip.

## [1.0.65-RC] 2019-10-28
### Changed
- Renamed the whole library system for classic, since some adventurous tinkerers kept mixing files from retail into the classic files, leading to a series of unpredictable issues. 
- Tooltips should indicate a lot better when a unit is dead now. 

## [1.0.64-RC] 2019-10-27
### Changed
- Disable tooltip vendor sell prices when Auctionator or TradeSkillMaster is loaded. More addons will be added to this list. 

### Fixed
- Fixed a tooltip issue where the wrong object type was assumed. 

## [1.0.63-RC] 2019-10-25
### Fixed
- Item tooltips now show the correct vendor sell price for partially full item stacks. 

## [1.0.62-RC] 2019-10-25
### Added
- Added vendor sell prices to items when not at a vendor. 

### Changed
- Mouseover unit tooltips should now be much more similar to our unitframe tooltips.
- Mouseover tooltips shouldn't have a different scale before and after hovering over a unit anymore. 

### Fixed
- Fixed some tooltip parsing issues that would use the spell description as the spell cost in some cases where spells had a cost but not a range. 

## [1.0.61-RC] 2019-10-22
### Fixed
- Fixed an issue with wrongly named custom events which caused interrupted spellcasts to appear to still be casting. 

## [1.0.60-RC] 2019-10-17
### Fixed
- Fixed wrong field name causing a nil bug when channeled player spells were pushed back. 

## [1.0.59-RC] 2019-10-16
### Added
- Added in raid frames. Frames can be toggled through the menu, just like the party frames. 
- Added the first draft of castbars to other units than the player. 

## [1.0.58-RC] 2019-10-13
- Files have been added, remember to restart the game client! 

### Changed
- Added some slight filtering to party frame auras to make it easier for healers to heal. 

### Fixed
- Group frames should now spawn in the correct place after a reload when healer layout was enabled previously. 

## [1.0.57-RC] 2019-10-09
### Added
- Now compatible with RealMobHealth. 

## [1.0.56-RC] 2019-10-08
### Changed
- Now compatible with Plater Nameplates. 

## [1.0.55-RC] 2019-10-08
### Added
- Added in party frames. Might have undiscovered bugs. Frames can be toggled through our menu. 
- Added the Healer Layout (previously known as Healer Mode) back in, now that we have party frames. This layout switches the positions of the group frames and chat frames, resulting in all friendly unit frames being grouped in the bottom left corner of the screen above the actionbars, making it easier for healers. 

## [1.0.54-RC] 2019-10-08
- ToC updates. 

## [1.0.53-RC] 2019-10-07
### Changed
- Removed the immovable object also known as the Blizzard durability frame, and replaced it with our own that looks exactly the same but has the benefit of actually working without stupid bug messages about mafia anchor connections. Fuck you secure anchoring system.  

## [1.0.52-RC] 2019-09-27
### Added
- Added reputation tracking to the minimap ring bars! 
- Aura tooltips now show the magic school of the aura.

### Changed
- Aura tooltips no longer show the spellID. You don't need to see that. 
- Various aura filter tweaks, and the beginning of the Druid aura overhaul in preparation of that. All classes will eventually be covered, and I'm starting with Druid since that is my main and something I currently have direct access to. 

## [1.0.51-RC] 2019-09-25
### Added
- Added a right-click menu to the minimap to select tracking when available.
- Added a tracking button to the minimap. When left-clicked, it displays a menu of the available tracking types, when right-clicked, it disables the current tracking. 

## [1.0.50-RC] 2019-09-23
### Fixed
- Slight bug in yesterday's update that caused all auras to sometimes be hidden in combat. Working as intended with this fix. This too is temporary, as I'm currently in the process of overhauling the aura system with parsed combat log information to make it far more functional for Classic. 

## [1.0.49-RC] 2019-09-22
### Changed
- Slightly adjusted the player aura filter to be more responsive to combat changes, and to only show long duration buffs in combat when they have 30 seconds or less time remaining before running out. Debuffs are displayed as before. This is not "the final filter", it's just a minor tweak to improve the current for as long as that may remain. 

## [1.0.48-RC] 2019-09-21
### Changed
- Healer Mode currently disabled, as it made no sense to switch just the chat around without the group frames. We'll re-introduce this option later once the group frames are in place. 
- Slightly increased the size of the actionbutton hit rectangles, to make the tooltips feel a bit more responsive when hovering over the buttons. 

## [1.0.47-RC] 2019-09-18
### Changed
- If Leatrix Maps or Enhanced World Map for WoW Classic is loaded, this addon won't interfere with the World Map anymore.

## [1.0.46-RC] 2019-09-17
### Removed
- Removed our anti-spam chat throttle filter that was working fine in BfA, as it's fully borked in Classic and probably the cause of all the missing chat messages in new chat windows that people have been experiencing. 

## [1.0.45-RC] 2019-09-16
### Changed
- Switch the middle- and left mouse button actions on our config button, and made the tooltip a bit more directly descriptive. 

### Fixed
- Fixed a potential nil bug in the quest tracker. I was unable to reproduce this, but put in a safeguard. 

## [1.0.44-RC] 2019-09-11
### Changed
- I made something just about twenty percent brighter then they needed to be. Now hush! 

## [1.0.43-RC] 2019-09-10
### Changed
- Disabling aura filters for now, until we can get a proper combat event tracking system in place, and maybe some durations for class abilities too.

## [1.0.42-RC] 2019-09-09
### Changed
- Move the chat window slightly farther down the screen. 
- Removed an unannounced experimental feature that I felt belonged in an addon of its own. 
- Redid the scaling system to just be simpler. 

## [1.0.41-RC] 2019-09-08
### Fixed
- Fixed the wrong function call introduced in the previous build. 

## [1.0.40-RC] 2019-09-08
### Changed
- All target unit frames (except the tiny critter/novise frame) now shows the unit health percentage on the left side, and will only show the actual health value on the right side when it's currently available. For now that limits it to you, your pet, and your group. 

### Fixed
- Fixed a forgotten upvalue in the target unit frame aura filter which prevented most auras from being shown in combat.
- Players will now see their health at level 1, they don't have to wait until level 2 anymore. Weird bug. 

## [1.0.39-RC] 2019-09-05
### Changed
- Changed some inconsistencies in the selection- and highlight coloring of the quest log. 

## [1.0.38-RC] 2019-09-05
### Added
- Added quest levels to the quest log.
- Added a minor blacklist to the red error messages, mainly filtering out redundant information that was visually available elsewhere in the interface, or just became highly intrusive and spammy. Because we know there's not enough Energy to do that. We know. 

### Changed
- Using better quest difficulty coloring in the quest log, and not the slightly too easy looking default one. 
- Improved the Explorer Mode logic for mana for druids, as well as prevented the fading while drinking. 

## [1.0.37-RC] 2019-09-04
### Added
- Added the command `/clear` to clear the main chat window. Because why not. 

### Changed
- Most abilities should now have their resource cost displayed in the actionbar tooltips. 
- The text on the power crystal showing druid mana in forms should now be colored red when very little mana is left. 

## [1.0.36-RC] 2019-09-01
### Added
- Added a "secret" feature to automate group invites and declines a bit. The commands `/blockinvites` and `/allowinvites` have been added, where the latter is the normal all manual mode, and the former is an automated mode where invites from wow friends, bnet friends and guild are automatically accepted, and everything else automatically declined. No options for this behavior exists as of yet, except the ability to turn it on. It is disabled by default, but there for those that me that are dead tired of brainless muppets spamming invites without ever uttering a single word. 

### Changed
- Toned down the opacity and reduced the number of messages visible at once in the red error message frame. Because I get it, there's not enough energy to do that now. I get it. 
- Slightly tuned the tracker size and position for better alignment with everything else. You probably didn't even notice it, so subtle was it. 
- The World Map now becomes slightly transparent when the player is moving. Just feels better to not completely block out the center of the screen when traveling from place to place on a fresh and very ganky PvP realm. 

## [1.0.35-RC] 2019-08-31
### Fixed
- Locked the main chat in a manner not affecting its DropDown, thus preventing taint from spreading to the Compact group frames. 

## [1.0.34-RC] 2019-08-31
### Fixed
- Fixed a typo causing the UI to bug out when your pet was just content, not happy. I thought this was a feature? :)

### Changed
- Made the aura filters even less filterish. We need actual lists here, since we can't check any real meta info of units not in our group. Will get myself up a few levels, then take a day to get this right!
- Removed the 3 limit buff cap on the target frame aura element. When you're a healer, you probably need to see more than just 3 happy ones. 
- Added an extra row of auras to the target frame, just to make sure we don't miss stuff while the filters are unfilterish. 

## [1.0.33-RC] 2019-08-31
### Added
- Added an experimental feature to show spell rank on actionbuttons when more than one instance of the spell currently exists on your buttons. 

### Changed
- Made the difference between usable and not usable spells more distinct. 

## [1.0.32-RC] 2019-08-30
### Fixed
- Fixed a typo causing an error when summoning pets. 

## [1.0.31-RC] 2019-08-30
### Changed
- Fixed some aura border coloring inconsistencies, as well as applied debuff type coloring to most auras that have a type. 

## [1.0.30-RC] 2019-08-30
### Fixed
- There should no longer be any misalignment when mousing over the world map to select zones.

## [1.0.29-RC] 2019-08-30
### Added
- Added a fix for players that suffered from AzeriteUI not loading because they mistakingly has TukUI or ElvUI installed. AzeriteUI should now load anyway, despite that horrible addon list. 

## [1.0.28-RC] 2019-08-30
### Fixed
- Player PvP icon should now properly be hidden while engaged in combat, to make room for the combat indicator. 

## [1.0.27-RC] 2019-08-30
### Added
- Added Pet Happiness as an experimental message to the bottom of the screen. 

## [1.0.26-RC] 2019-08-29
### Added
- Added a player PvP icon. It is placed where the combat indicator is, and thus hidden while in combat. 

### Changed
- Made the world map smaller, and stopped it from blocking out the world. We are aware that the overlay to click on zones is slightly misaligned, working on that. 
- Changed the aura filters to be pretty all inclusive. Will tune it for classic later on. 

### Fixed
- Fixed the display of Druid cat form combo points. It should now appear. If you're wondering why the points disappear everytime you change target, that's not a bug. That's a classic feature. 
- Fixed a bug when opening the talent window. 
- Fixed a lot of small issues and bugs related to auras and castbars. 

### Removed
- Disabled all castbars on frames other than the player and the pet. We will add a limited tracking system for hostile player casts by tracking combat log events later on. 

## [1.0.16-RC] 2019-08-12
### Changed
- The quest tracker now looks far more awesome. 
- The texture for active or checked abilities on the action buttons will now be hidden if the red auto-attack flash is currently flashing, making everything far easier to see and relate to. 
- Made the tooltip for auto-attack much more interesting, as it now shows your main- and off hand damage, attack speed and damage per second. Just like the weapon tooltips in principle, but with actual damage modifiers from attack power and such taken into account. 

### Fixed
- Fixed some issues that would cause attacks on the next swing to have their tooltips displayed slightly wonky. 

## [1.0.15-RC] 2019-08-11
### Changed
- The quest watcher is now visible again. We might write a prettier one later, this old one is kind of boring. 
- Improved the size and anchoring of the bag slot buttons beneath the backpack. 

## [1.0.14-RC] 2019-08-11
### Changed
- The durability frame is now placed more wisely. 

## [1.0.13-Alpha] 2019-08-11
### Changed
- Removed the "_Classic" suffix from the UI name in options menu. It doesn't need a different display name, because it's not a different UI, just for a different client. 
- Replaced the blip icon used to indicate what I thought was just resource nodes with a yellow circle with a black dot, as it apparently also is the texture used for identifying questgivers you can turn in finished quests too. Big purple star just didn't seem right there. 

## [1.0.12-Alpha] 2019-08-11
### Added
- Added minimap blip icons for 1.13.2! 
- Added styling to the up, down and to bottom chat window buttons. 

### Changed
- The GameTooltip now follows the same scaling as our own tooltips, regardless of the actual uiScale. 

## [1.0.11-Alpha] 2019-08-10
### Changed
- Disabled the coloring of the orb glass overlay, as this looked strange when dead or empty. None of those things seem to happen in retail. They do here, however. So now I noticed. 
- Disabled castbars on nameplates, as these can't be tracked through regular events in Classic. Any nameplate units would be treated as no unit given at all, which again would default to assuming the player as the unit, resulting in mobs often getting OUR casts on their castbars. We will be adding a combatlog tracking system for this later, which relies on unitGUIDs. 

### Fixed
- Fixed a bug when right-clicking the Minimap.

## [1.0.10-Alpha] 2019-08-10
### Added
- Hunters now get a mana orb too! 

## [1.0.9-Alpha] 2019-08-09
### Changed
- Removed all API calls related to internal minimap quest area rings and blobs.
- Removed a lot of unneeded client checks, as we're not checking for any retail versions anymore. 

## [1.0.8-Alpha] 2019-08-09
### Changed
- Removed more vehicle, override and possess stuff from the unitframe library. 

## [1.0.7-Alpha] 2019-08-09
### Changed
- Removed more petbattle and vehicle stuff from actionbutton library. 

## [1.0.6-Alpha] 2019-08-09
### Changed
- Disabled Raid, Party and Boss frames. Will re-enable Raid and Party when I get it properly tested after the launch. Did Boss frames exist? 

## [1.0.5-Alpha] 2019-08-09
### Fixed
- Fixed Rogue combo points. Cannot test Druids as they get them at level 20, and level cap here in the pre-launch is 15.

## [1.0.5-Alpha] 2019-08-09
### Fixed
- Fixed micro menu.
- Fixed option menu.
- Fixed aura updates on unit changes. 

## [1.0.3-Alpha] 2019-08-09
### Fixed
- Fixed typos in bindings module.
- Fixed API for castbars. 

## [1.0.2-Alpha] 2019-08-09
### Fixed
- Changed `SaveBindings` > `AttemptToAttemptToSaveBindings`, fixing the `/bind` hover keybind mode!

## [1.0.1-Alpha] 2019-08-09
- Public Alpha. 
- Initial commit.
