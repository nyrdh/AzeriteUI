local ADDON = ...
local L = Wheel("LibLocale"):NewLocale(ADDON, "zhCN")
if (not L) then 
	return 
end 

-- No, we don't want this. 
ADDON = ADDON:gsub("_Classic", "")

-- 1.13.3 Battleground popup bugfix
L["You can now enter a new battleground, right-click the green eye on the minimap to enter or leave!"] = "现在，你可以进入一个新的战场，右键单击小地图上的绿色眼睛即可进入或离开！"

-- General Stuff
--------------------------------------------
-- Most of these are inserted into other strings, 
-- the idea here is to keep them short and simple. 
L["Enable"] = "启用" 
L["Disable"] = "禁用" 
L["Enabled"] = "|cff00aa00启用|r"
L["Disabled"] = "|cffff0000禁用|r"
L["<Left-Click>"] = "<鼠标左键>"
L["<Middle-Click>"] = "<鼠标中键>"
L["<Right-Click>"] = "<鼠标右键>"

-- Clock & Time Settings
--------------------------------------------
-- These are shown in tooltips
L["New Event!"] = "新事件！"
L["New Mail!"] = "新邮件！"
L["%s to toggle calendar."] = "按下 %s 打开或关闭日历。"
L["%s to use local computer time."] = "按下 %s 使用计算机本地时间。"
L["%s to use game server time."] = "按下 %s 使用游戏服务器时间。"
L["%s to use standard (12-hour) time."] = "按下 %s 使用12小时制。"
L["%s to use military (24-hour) time."] = "按下 %s 使用24小时制。"
L["Now using local computer time."] = "现在使用计算机本地时间。"
L["Now using game server time."] = "现在使用游戏服务器时间。"
L["Now using standard (12-hour) time."] = "现在使用12小时制。"
L["Now using military (24-hour) time."] = "现在使用24小时制。"

-- Network & Performance Information
--------------------------------------------
-- These are shown in tooltips
L["Network Stats"] = "网络状态"
L["World latency:"] = "世界延迟:"
L["This is the latency of the world server, and affects casting, crafting, interaction with other players and NPCs. This is the value that decides how delayed your combat actions are."] = "这是世界服务器的延迟，它影响施法，制造，与其他玩家或NPC的交互。这个数值决定战斗操作的延迟。" 
L["Home latency:"] = "本地延迟:"
L["This is the latency of the home server, which affects things like chat, guild chat, the auction house and some other non-combat related things."] = "这是本地服务器的延迟。它影响聊天，拍卖行和一些其他非战斗操作。"

-- XP, Honor & Artifact Bars
--------------------------------------------
-- These are in the tooltips
L["Normal"] = "正常"
L["Rested"] = "休息充分"
L["Resting"] = "休息中"
L["Current Artifact Power: "] = "当前神器能量: "
L["Current Honor Points: "] = "当前荣誉点数: "
L["Current Standing: "] = "当前声望: "
L["Current XP: "] = "当前经验值: "
L["Rested Bonus: "] = "休息充分奖励: "
L["%s of normal experience gained from monsters."] = "%s 从怪物处获取到的正常经验值"
L["You must rest for %s additional hours to become fully rested."] = "你还需要休息 %s 小时以获得休息充分状态。"
L["You must rest for %s additional minutes to become fully rested."] = "你还需要休息 %s 分钟以获得休息充分状态。"
L["You should rest at an Inn."] = "你应该在旅馆休息。"
L["Sticky Minimap bars enabled."] = "粘性小地图条已启用。"
L["Sticky Minimap bars disabled."] = "粘性小地图条已禁用。"

-- These are displayed within the circular minimap bar frame, 
-- and must be very short, or we'll have an ugly overflow going. 
L["to level %s"] = "到 %s 级" 
L["to %s"] = "到 %s"
L["to next trait"] = "到下一个特质"
L["to next level"] = "到下一个等级"

-- Try to keep the following fairly short, as they should
-- ideally be shown on a single line in the tooltip, 
-- even with the "<Right-Click>" and similar texts inserted.
L["%s to toggle Artifact Window>"] = "按下 %s 打开或关闭神器窗口>"
L["%s to toggle Honor Talents Window>"] = "按下 %s 打开或关闭荣誉天赋窗口>"
L["%s to disable sticky bars."] = "按下 %s 禁用粘性小地图条。"
L["%s to enable sticky bars."] = "按下 %s 启用粘性小地图条。"  

-- Config & Micro Menu
--------------------------------------------
-- Config button tooltip
-- *Doing it this way to keep the localization file generic, 
--  while making sure the end result still is personalized to the addon.
L["Main Menu"] = ADDON
L["Game Panels"] = "游戏面板"
L["Click here to get access to game panels."] = "单击此处可访问各种游戏窗口，例如角色，法术书，天赋，或更改动作栏的各种设置。"

-- These should be fairly short to fit in a single line without 
-- having the tooltip grow to very high widths. 
L["%s to toggle Blizzard Menu."] = "按下 %s 打开或关闭 Blizzard 菜单。"
L["%s to toggle Options Menu."] = "按下 %s 打开或关闭 "..ADDON.." 菜单。"
L["%s to toggle your Bags."] = "按下 %s 打开或关闭你的背包。"

-- Config Menu
--------------------------------------------
-- Remember that these shall fit on a button, 
-- so they can't be that long. 
-- You don't need a full description here. 
L["Debug Mode"] = "调试工具" 
L["Debug Console"] = "调试控制台" 
L["Load Console"] = "加载控制台"
L["Unload Console"] = "卸载控制台"
L["Reload UI"] = "重新载入界面"
L["Settings Profile"] = "设置配置文件"
L["Global"] = true
L["Faction"] = true
L["Realm"] = true
L["Character"] = true
L["ActionBars"] = "动作栏"
L["Button Lock"] = "按钮锁定"
L["Cast on Down"] = "按下施法"
L["Bind Mode"] = "键位绑定模式"
L["Display Priority"] = "显示优先级"
L["GamePad First"] = "手柄优先"
L["Keyboard First"] = "键盘优先"
L["GamePad Type"] = "手柄类型"
L["Xbox"] = "Xbox"
L["Xbox (Reversed)"] = "Xbox (反向)"
L["Playstation"] = "PS"
L["More Buttons"] = "更多按钮"
L["No Extra Buttons"] = "无额外按钮"
L["+%.0f Buttons"] = "+%.0f 按钮"
L["Extra Buttons Visibility"] = "额外按钮显示模式"
L["MouseOver"] = "鼠标停留显示"
L["MouseOver + Combat"] = "鼠标停留及战斗中显示"
L["Always Visible"] = "一直显示"
L["Stance Bar"] = "姿态栏"
L["Extra Bars"] = "额外的动作条"
L["Secondary Bar"] = "附加动作条"
L["Side Bar One"] = "边栏动作条1"
L["Side Bar Two"] = "边栏动作条2"
L["Pet Bar"] = "宠物栏"
L["Pet Bar Visibility"] = "宠物栏显示模式"
L["Chat Windows"] = "聊天窗口"
L["Chat Outline"] = "文字阴影"
L["Chat Filters"] = "信息过滤"
L["Chat Styling"] = "聊天风格"
L["Hide Monster Messages"] = "隐藏怪物消息"
L["Hide Boss Messages"] = "隐藏首领台词"
L["Hide Spam"] = "隐藏垃圾信息"
L["Battleground Filter"] = "战场过滤器"
L["UnitFrames"] = "单位框体"
L["Party Frames"] = "队伍框体"
L["Raid Frames"] = "团队框体"
L["PvP Frames"] = "PVP框体"
L["Use Mana Orb"] = "使用魔法球"
L["HUD"] = "界面显示"
L["CastBar"] = "施法条"
L["ClassPower"] = "职业资源"
L["Alerts"] = "警示信息"
L["Kills, Levels, Loot"] = "击杀，等级，战利品"
L["Monster Emotes"] = "怪物表情"
L["Raid Warnings"] = "团队通知"
L["TalkingHead"] = "对话框"
L["Objectives Tracker"] = "目标追踪器"
L["NamePlates"] = "姓名板"
L["Auras"] = "光环"
L["Player"] = "玩家"
L["Enemies"] = "敌方"
L["Friends"] = "友方"
L["Click-Through NamePlates"] = "点击穿透姓名板"
L["PRD"] = "显示个人资源"
L["Show Always"] = "总是显示"
L["Show In Combat"] = "战斗中显示"
L["Show With Target"] = "有目标时显示"
L["Aspect Ratio"] = "长宽比"
L["Widescreen (16:9)"] = "宽屏 |cff666666(16:9)|r"
L["Ultrawide (21:9)"] = "带鱼屏 |cff666666(21:9)|r"
L["Unlimited"] = "全屏"
L["Aura Filters"] = "光环过滤器"
--L["Strict"] = "严格"
L["Slack"] = "过滤"
L["Spam"] = "不过滤"
L["Explorer Mode"] = "探索者模式"
L["Player Fading"] = "玩家渐隐"
L["Tracker Fading"] = "任务追踪渐隐"
L["Chat Positioning"] = "聊天框位移"
L["Healer Mode"] = "治疗模式" -- it's a layout change, so let's reflect this!

-- Config Menu Tooltips
-- *please do not let the very 
--  long texts here confuse you.
--------------------------------------------
-- Debug tools
L["Various minor tools that may or may not help you in a time of crisis. Usually only useful to the developer of the user interface."] = "调试控制台和重载界面小工具。通常只对用户界面的开发人员有用。"
L["The debug console is a read-only used by the user interface to show status messages and debug output. Unless you are actively developing new features yourself and intentionally sends thing to the console, you do not need to enable this."] = "调试控制台是用户界面用来显示状态消息和调试输出的只读控制台。除非你自己积极开发新功能，并有意将内容发送到控制台，否则你不需要启用这一功能。"
L["Reloads the user interface. This can be helpful if taints occur, blocking things like quest buttons or bag items from being used."] = "重新加载用户界面。这在发生错误时很有帮助。"

-- Aspect Ratio
L["Here you can set how much width of the screen our custom user interface elements will take up. This is mostly useful for users with ultrawide screens, as it allows them to place the frames closer to the center of the screen, making the game easier to play.|n|n|cffcc0000This does NOT apply to Blizzard windows like the character frame, spellbook and similar, and currently that is not something that can easily be implemented!|r"] = "在这里可以设置自定义用户界面模块所占屏幕的宽度。这对于拥有超宽屏幕的用户来说非常有用，因为这样可以将更多其它框架放置在屏幕中央，让游戏更容易玩。|n|n|cffcc0000这并不适用于暴雪窗口，像角色框架，法术书和类似的东西，目前不太容易实现!|r"
L["Limits the user interface to a regular 16:9 widescreen ratio. This is how the user interface was designed and intended to be, and thus the default setting."] = "限制用户界面的宽屏比例为16:9比例。这是默认设置。"
L["Limits the user interface to a 21:9 ultrawide ratio.|n|n|cffcc0000This setting only holds meaning if you have a screen wider than this, and wish to lock the width of our user interface to a 21:9 ratio.|r"] = "限制用户界面为21:9的超宽比例。|n|n|cffcc0000只有当你有一个比这个更宽的屏幕，并且希望用户界面的宽度锁定在21:9的比例时，这个设置才有意义。|r"
L["Uses the full width of the screen, moving elements anchored to the sides of the screen all the way out.|n|n|cffcc0000This setting only holds meaning if you have a screen width a wider ratio than regular 16:9 widescreen.|r"] = "使用屏幕的全宽度，移动模块固定到屏幕的两侧。|n|n|cffcc0000此设置仅在屏幕宽度比常规16:9屏幕更宽时有效。|r"

-- Aura Filters
L["There are very many auras displayed in this game, and we have very limited space to show them in our user interface. So we filter and sort our auras to better use the space we have, and display what matters the most."] = "游戏中有非常多的光环显示，在用户界面中显示它们的空间非常有限。所以选择过滤和分类光环，以更好地利用屏幕空间，来显示最主要的东西。"
--L["The Strict filter follows strict rules for what to show and what to hide. It will by default show important debuffs, boss debuffs, time based auras from the environment of NPCs, as well as any whitelisted auras for your class."] = "“严格”过滤器遵循严格的规则来显示和隐藏光环。默认情况下只显示重要的DeBuff，BOSS DeBuff和基于时间显示的光环，以及该职业中所有列入白名单的光环。"
L["The Slack filter shows everything from the Strict filter, and also adds a lot of shorter auras or auras with stacks."] = "默认情况下只显示重要的DeBuff，BOSS DeBuff和基于时间显示的光环，以及该职业中所有列入白名单的光环，还显示了许多持续时间较短的光环或具有层数的光环。" 
L["The Spam filter shows all that the other filters show, but also adds auras with a very long duration when not currently engaged in combat."] = "显示了其他过滤器隐藏的所有内容，但是当离开战斗时，还会显示持续时间非常长的光环。"

-- ActionBars
L["Click to enable the Stance Bar."] = "点击启用姿态栏。"
L["Click to disable the Stance Bar."] = "点击禁用姿态栏。"
L["Click to enable the Pet Action Bar."] = "点击启用宠物动作栏"
L["Click to disable the Pet Action Bar."] = "点击禁用宠物动作栏"

-- Chat Windows
L["This is a chat filter that reformats a lot of the game chat output to a much nicer format. This includes when you receive loot, earn currency or gold, when somebody gets and achievement, and so on.|n|nNote that this filter does not add or remove anything, it simply makes it easier on the eyes."] = "这是一个聊天过滤器，可将许多在聊天框输出的信息重新格式化为更好的格式。这包括获得战利品，赚取货币或金币以及某人获得成就时等等。|n|n注意，此过滤器不会添加或删除任何内容，只是让眼睛更容易识别。"
L["This filter hides most things NPCs or monsters say from that chat. Monster emotes and whispers are moved to the same place mid-screen as boss emotes and whispers are displayed.|n|nThis does not affect what is visible in chat bubbles above their heads, which is where we wish this kind of information to be available."] = "此项过滤隐藏了NPC或怪物的聊天框信息。|n|n这不会影响你在他们头顶的聊天气泡中看到的内容。"
L["This filter hides most things boss monsters say from that chat. |n|nThis does not affect what is visible mid-screen during raid fights, nor what you'll see in chat bubbles above their heads, which is where we wish this kind of information to be available."] = "此项过滤隐藏了大多数首领怪物台词信息。|n|n这不会影响在团队战斗中屏幕中间的可见内容，也不会影响你在他们头顶的聊天气泡中看到的内容。"
L["This filter hides a lot of messages related to group members in raids and especially battlegrounds, such as who joins, leaves, who loots something and so on.|n|nThe idea here is free up the chat and allow you to see what people are actually saying, and not just the constant spam of people coming and going."] = "此项过滤隐藏了很多与团队成员有关的信息，比如谁加入，谁离开，谁获得了什么等等。|n|n这里的想法是腾出聊天空间，让你看到人们实际上在说什么，而不仅仅是人们来来往往的垃圾信息。"
L["Toggles outlined text in the chat windows.|n|nWe recommend leaving it on as the chat can be really hard to read in certain situations otherwise."] = "为聊天窗口中的文字添加阴影。|n|n建议把它开着，因为在某些情况下，有些聊天内容很难阅读。"

-- NamePlates
L["This controls the visibility options of the Personal Resource Display, your personal nameplate located beneath your character."] = "这将控制个人资源的显示与隐藏，即在你的角色下方添加生命值和资源。"
L["Click to disable the Personal Resource Display."] = "点击禁用个人资源。"
L["Click to enable the Personal Resource Display."] = "点击启用个人资源。"
L["Here you can choose whether NamePlates should react to mouse events and mouse clicks as normal, or set them to be click-trhough, meaning you can see them but not interact with them.|n|nIf you wish to be able to click on a nameplate to select that unit as your target, then you should NOT use click-through NamePlates."] = "在这里，你可以选择姓名板是否应该对鼠标事件和鼠标点击做出正常反应，或者将它们设置为点击穿透，这意味着你可以看到它们，但不能与它们交互。|n|n如果你希望能够单击姓名板以选择该单位作为目标，则不应使用点击穿透姓名板。"

-- HUD
L["A head-up display, also known as a HUD, is any transparent display that presents data without requiring users to look away from their usual viewpoints. In our user interface, we use this to label elements appearing in the middle of the screen, then disappearing."] = "界面显示（也称为HUD）它可以显示数据，而不需要用户从他们通常的视点移开视线。在这个用户界面中，使用它来标记出现在屏幕中间然后消失的元素。"
L["Toggles your own castbar, which appears in the bottom center part of the screen, beneath your character and above your actionbars."] = "切换施法条风格，出现在屏幕底部的中间部分，在你的角色下面，在动作栏上面。"
L["Toggles the point based resource systems unique to your own class."] = "切换职业特有的资源显示风格"
L["Toggles the TalkingHead frame. This is the frame you'll see appear in the top center part of the screen, with a portrait and a text. This will usually occur when reaching certain world quest areas, or when a forced quest from your faction leader appears."] = "切换对话框架。使其出现在屏幕中间的顶部，有一个头像和一个文本。这通常会发生在到达特定的世界任务区域，或者当你的阵营任务时出现。"
L["The Objectives Tracker shows your quests, quest item buttons, world quests, campaign quests, mythic affixes, Torghast powers and so on.|n|nAnnoying as hell, but best left on unless you're very, very pro."] = "显示你的任务，任务物品按钮，世界任务，战役任务等。|n|n除非你非常非常专业，否则最好还是不要使用"
L["Raid Warnings are important raid messages appearing in the top center part of the screen. This is where messages sent by your raid leader and raid officers appear. It is recommended to leave these on for the most part.|n|nThe exception is when you get into WoW Classic battlegrounds where everybody is promoted, and some jokers keep spamming. Then it is good to disable."] = "团队通知是出现在屏幕顶部中间的重要团队消息。这是你的团队领袖和团队助理发送的消息出现的位置。建议大多数情况下将其保留。|n|n例外情况是，当你进入怀旧服战场时，每个人都得到了晋升，并且一些小丑一直在发送垃圾消息。那么禁用它是很好的。"
L["Toggles the display of boss- and monster emotes. If you're a skilled player, it is not recommended to turn these on, as some world quests and most boss encounters send important messages here.|n|nSupport wheel users relying on Dumb Boss Mods can do whatever they please, it's not like they're looking at anything else than bars anyway."] = "切换首领表情和大多数表情的显示风格。如果你是熟练的玩家，则不建议你开启这个功能，因为某些世界任务和大多数首领遭遇都会在此处发送重要信息。"
L["This includes most mid-screen announcements like when you gain a level, you receive certain types of loot, and any banner shown when you complete a scenario, kill a boss and so forth."] = "这包括大多数屏幕中间的公告，比如当你升级时，获得特定类型的战利品，以及当你完成一个场景或杀死一个首领时显示的任何横幅。"
L["Toggles the display of alert frames. These include the achievement popups, as well as multiple types of currency loot in some expansion content like the Legion zones."] = "切换警报框架的显示风格。其中包括成就弹出的窗口，以及在某些扩展内容中获得的多种类型的货币战利品。"


-- Various Button Tooltips
--------------------------------------------
L["%s to leave the vehicle."] = "按下 %s 离开载具。"
L["%s to dismount."] = "按下 %s 解散坐骑。"
L["%s to dismiss your controlled minion."] = "按下 %s来解散你被控制的仆从。"

-- Abbreviations
--------------------------------------------
-- This is shown of group frames when the unit 
-- has low or very low mana. Keep it to 3 letters max! 
L["oom"] = "oom" -- out of mana

-- These are shown on the minimap compass when 
-- rotating minimap is enabled. Keep it to single letters!
L["N"] = "北" -- compass North
L["E"] = "东" -- compass East
L["S"] = "南" -- compass South
L["W"] = "西" -- compass West

-- Keybind mode
--------------------------------------------
-- This is shown in the frame, it is word-wrapped. 
-- Try to keep the length fairly identical to enUS, though, 
-- to make sure it fits properly inside the window. 
L["Hover your mouse over any actionbutton and press a key or a mouse button to bind it. Press the ESC key to clear the current actionbutton's keybinding."] = "鼠标指向任何动作条按钮来绑定它。按Esc键来清除当前动作条按钮的按键绑定。"

-- These are output to the chat frame. 
L["Keybinds cannot be changed while engaged in combat."] = "战斗中无法修改键位绑定。"
L["Keybind changes were discarded because you entered combat."] = "键位绑定改动因进入战斗状态而被舍弃。"
L["Keybind changes were saved."] = "键位绑定改动已保存。"
L["Keybind changes were discarded."] = "键位绑定改动已舍弃。"
L["No keybinds were changed."] = "键位绑定无改动。"
L["No keybinds set."] = "无键位绑定。"
L["%s is now unbound."] = "%s 已解除绑定。"
L["%s is now bound to %s"] = "%s 已绑定到 %s"
