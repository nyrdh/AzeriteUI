--[[--

	The purpose of this file is to provide
	forges for the actionbar module.
	The idea is to set up methods, values and callbacks 
	here to keep what's in the front-end fully generic.

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

-- WoW API
local GetTotemTimeLeft = GetTotemTimeLeft
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local IsMounted = IsMounted
local UnitExists = UnitExists
local UnitOnTaxi = UnitOnTaxi

-- WoW client version constants
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Private API
local Colors = Private.Colors
local GetAuraFilter = Private.GetAuraFilter
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia
local GetSchematic = Private.GetSchematic

-- Addon Localization
local L = Wheel("LibLocale"):GetLocale(ADDON)

-- Utility Functions
-----------------------------------------------------------
-- ActionButton Post Create 
local ActionButton_PostCreate_Normal = function(self)
	self:Forge(Private.GetSchematic("WidgetForge::ActionButton::Normal")) 
end 

-- PetButton Post Create
local ActionButton_PostCreate_Small = function(self)
	self:Forge(Private.GetSchematic("WidgetForge::ActionButton::Small")) 
end 

-- Module Schematics
-----------------------------------------------------------
-- Generic
Private.RegisterSchematic("ModuleForge::ActionBars", "Generic", {
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

					},
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

-- Legacy
Private.RegisterSchematic("ModuleForge::ActionBars", "Legacy", {
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
						"Buttons", {},
						"ButtonLookup", {},
						"PetButtons", {},

						-- Secure Code Snippets.
						-- These are used by the menu system and the bars themselves
						-- to update layout and other secure settings even while in combat.
						"secureSnippets", {
							-- Arrange the main and extra actionbar buttons
							arrangeButtons = [=[
								local UICenter = self:GetFrameRef("UICenter"); 

								for id,button in ipairs(Buttons) do 
									local buttonID = button:GetID(); 
									local layoutID = button:GetAttribute("layoutID");
									local barID = Pagers[id]:GetID(); 

								end 
							]=],

							-- Arrange the pet action bar buttons
							arrangePetButtons = [=[
								local UICenter = self:GetFrameRef("UICenter");
								for id,button in ipairs(PetButtons) do
								end
							]=],

							-- Saved setting changed.
							-- This is called by the options menu after changes and on startup.
							attributeChanged = [=[
								-- 'name' appears to be turned to lowercase by the restricted environment(?), 
								-- but we're doing it manually anyway, just to avoid problems. 
								if name then 
									name = string.lower(name); 
								end 

								if (name == "change-castondown") then 
									self:SetAttribute("castOnDown", value and true or false); 
									self:CallMethod("UpdateCastOnDown"); 

								elseif (name == "change-buttonlock") then 
									self:SetAttribute("buttonLock", value and true or false); 

									-- change all button attributes
									for id, button in ipairs(Buttons) do 
										button:SetAttribute("buttonLock", value);
									end

									-- change all pet button attributes
									for id, button in ipairs(PetButtons) do 
										button:SetAttribute("buttonLock", value);
									end

								elseif (name == "change-keybinddisplaypriority") then 
									self:SetAttribute("keybindDisplayPriority", value);
									self:CallMethod("UpdateKeybindDisplay"); 

								elseif (name == "change-gamepadtype") then
									self:SetAttribute("gamePadType", value);
									self:CallMethod("UpdateKeybindDisplay"); 
								end 

							]=]
						},

						-- Event handler
						----------------------------------------------------
						"OnEvent", function(self, event, ...)
							if (event == "UPDATE_BINDINGS") then
								self:UpdateActionButtonBindings()
						
							elseif (event == "PLAYER_ENTERING_WORLD") then
								self.inCombat = false
								self:UpdateActionButtonBindings()
						
							elseif (event == "PLAYER_REGEN_DISABLED") then
								self.inCombat = true 
						
							elseif (event == "PLAYER_REGEN_ENABLED") then
								self.inCombat = false
						
							elseif (event == "GP_FORCED_ACTIONBAR_VISIBILITY_REQUESTED") then
								self:SetForcedVisibility(true)
						
							elseif (event == "GP_FORCED_ACTIONBAR_VISIBILITY_CANCELED") then
								self:SetForcedVisibility(false)
							
							elseif (event == "GP_USING_GAMEPAD") then
								self.db.lastKeybindDisplayType = "gamepad"
								self:UpdateKeybindDisplay()

							elseif (event == "GP_USING_KEYBOARD") then
								self.db.lastKeybindDisplayType = "keyboard"
								self:UpdateKeybindDisplay()

							--elseif (event == "PET_BAR_UPDATE") then
							--	self:UpdateExplorerModeAnchors()
							end
						end, 

						-- Spawning
						----------------------------------------------------
						-- Method to create scaffolds and overlay frames.
						"CreateScaffolds", function(self)
							-- Create master frame. This one becomes secure.
							self.frame = self:CreateFrame("Frame", nil, "UICenter", "BackdropTemplate")

							-- Create overlay frames used for explorer mode.
							self.frameOverlay = self:CreateFrame("Frame", nil, "UICenter")
						
							-- Apply overlay alpha to the master frame.
							hooksecurefunc(self.frameOverlay, "SetAlpha", function(_,alpha) self.frame:SetAlpha(alpha) end)
						end,

						-- Method to create the secure callback frame for the menu system.
						"CreateSecureUpdater", function(self)
							local OptionsMenu = self:GetOwner():GetModule("OptionsMenu", true)
							if (OptionsMenu) then
								local callbackFrame = OptionsMenu:CreateCallbackFrame(self)
								callbackFrame:AssignSettings(self.db)
								callbackFrame:AssignProxyMethods("UpdateCastOnDown", "UpdateButtonCount", "UpdateKeybindDisplay", "UpdateExplorerModeAnchors")
					
								-- Create tables to hold the buttons
								-- within the restricted environment.
								callbackFrame:Execute([=[ 
									Buttons = table.new();
									Pagers = table.new();
									PetButtons = table.new();
									PetPagers = table.new();
									StanceButtons = table.new();
								]=])
					
								-- Apply references and attributes used for updates.
								callbackFrame:AssignAttributes(
									"BOTTOMLEFT_ACTIONBAR_PAGE", BOTTOMLEFT_ACTIONBAR_PAGE,
									"BOTTOMRIGHT_ACTIONBAR_PAGE", BOTTOMRIGHT_ACTIONBAR_PAGE,
									"RIGHT_ACTIONBAR_PAGE", RIGHT_ACTIONBAR_PAGE,
									"LEFT_ACTIONBAR_PAGE", LEFT_ACTIONBAR_PAGE,
									"arrangeButtons", self.secureSnippets.arrangeButtons,
									"arrangePetButtons", self.secureSnippets.arrangePetButtons
								)
					
								callbackFrame:AssignCallback(self.secureSnippets.attributeChanged)
							end
						end, 

						-- Spawns the primary action bar, 
						-- which holds the default 12 buttons.
						-- This is the bar that page switches.
						"SpawnPrimaryBar", function(self)
							local db = self.db
							local proxy = self:GetSecureUpdater()

							local size,padding,offsetY,padSide,padTop = 50,2,40,0,-2
							--local frameW,frameH = size*6 + padding*5, size*2+padding
							local frameW,frameH = size*12 + padding*11, size

							local frame = self.frame
							frame:SetFrameStrata("LOW")
							frame:SetFrameLevel(1)
							frame:SetSize(2,2)
							frame:Place("BOTTOM", "UICenter", "BOTTOM", 2, 28)

							local primaryBackdrop = frame:CreateFrame("Frame")
							primaryBackdrop:SetFrameStrata("LOW")
							primaryBackdrop:SetFrameLevel(1)
							primaryBackdrop:SetSize(frameW + 21 + padSide*2 + 2, frameH + 21 + padTop*2 + 1)
							primaryBackdrop:SetBackdrop({
								bgFile = [[Interface\ChatFrame\ChatFrameBackground]], tile = false,
								edgeFile = GetMedia("tooltip_border_hex"), edgeSize = 32, 
								insets = { top = 10.5, bottom = 10.5, left = 10.5, right = 10.5 }
							})
							primaryBackdrop:SetBackdropColor(0, 0, 0, .75)
							primaryBackdrop:SetBackdropBorderColor(Colors.ui[1], Colors.ui[2], Colors.ui[3])
							primaryBackdrop:Place("BOTTOM", "UICenter", "BOTTOM", padding, offsetY - 21/2 - padding)

							-- Primary Action Bar
							for id = 1,NUM_ACTIONBAR_BUTTONS do 
								self.buttonID = (self.buttonID or 0) + 1

								local postCreate = ActionButton_PostCreate_Normal
								--local postCreate = ActionButton_PostCreate_Small
								local button = self:SpawnActionButton("action", self.frame, postCreate, id, 1)

								if (id == 1) then
									primaryBackdrop:SetParent(button)
									primaryBackdrop:SetFrameStrata("LOW")
									primaryBackdrop:SetFrameLevel(1)
								end

								--12x1
								button:Place("BOTTOMLEFT", self.frame, "BOTTOM", -frameW/2 + -2 + padSide + (id-1)*(size+padding), 7)
								
								-- 6x2
								--local x = -frameW/2 + ((id > 6) and (id-7) or (id-1))*(size+padding)
								--local y = offsetY + (id > 6 and (size + padding) or 0)
								--button:Place("BOTTOMLEFT", "UICenter", "BOTTOM", x, y)
								--button.BorderFrame:Hide()

								-- Layout helper
								button:SetAttribute("layoutID", self.buttonID)

								-- Apply saved buttonLock setting
								button:SetAttribute("buttonLock", db.buttonLock)

								-- Link the buttons and their pagers 
								proxy:SetFrameRef("Button"..self.buttonID, button)
								proxy:SetFrameRef("Pager"..self.buttonID, button:GetPager())
	
								-- Reference all buttons in our menu callback frame
								proxy:Execute(([=[
									table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
									table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
								]=]):format(self.buttonID, self.buttonID))
								
								-- Let's put on a special visibility driver 
								-- that hides these buttons in vehicles, and on taxis.
								UnregisterAttributeDriver(button._owner, "state-vis")
								RegisterAttributeDriver(button._owner, "state-vis", "[canexitvehicle,novehicleui][vehicleui][overridebar][possessbar][shapeshift]hide;[@player,exists]show;hide")

								-- Button cache
								self.Buttons[self.buttonID] = button

								-- Faster lookups
								self.ButtonLookup[button] = true
							end

						end,

						-- Spawns the secondary bar, 
						-- which in the default UI is known as 
						-- "the bottom left multi actionbar".
						-- It is normally placed above the default bar, 
						-- which is why we have chosen this one as secondary.
						"SpawnSecondaryBar", function(self)
						end,

						"SpawnPetBar", function(self)
						end,

						-- Spawns a custom vehicle action bar.
						-- We'll be using a separate set of bars and 
						-- unit frames for vehicles in the Legacy theme.
						-- One reason for this is how our unit frames
						-- directly get in the way of on-screen elements
						-- in for example BfA vehicle based mini-games.
						"SpawnVehicleBar", function(self)
							local db = self.db
							local proxy = self:GetSecureUpdater()

							local size,padding,offsetY,padSide,padTop = 50,2,40,0,-2
							local frameW,frameH = size*6 + padding*5, size

							local primaryBackdrop = self.frame:CreateFrame("Frame")
							primaryBackdrop:SetFrameStrata("LOW")
							primaryBackdrop:SetFrameLevel(1)
							primaryBackdrop:SetSize(frameW + 21 + padSide*2 + 2, frameH + 21 + padTop*2 + 1)
							primaryBackdrop:SetBackdrop({
								bgFile = [[Interface\ChatFrame\ChatFrameBackground]], tile = false,
								edgeFile = GetMedia("tooltip_border_hex"), edgeSize = 32, 
								insets = { top = 10.5, bottom = 10.5, left = 10.5, right = 10.5 }
							})
							primaryBackdrop:SetBackdropColor(0, 0, 0, .75)
							primaryBackdrop:SetBackdropBorderColor(Colors.ui[1], Colors.ui[2], Colors.ui[3])
							primaryBackdrop:Place("BOTTOM", "UICenter", "BOTTOM", padding, offsetY - 21/2 - padding)

							-- Primary Action Bar
							for id = 1,6 do 
								self.buttonID = (self.buttonID or 0) + 1

								local postCreate = ActionButton_PostCreate_Normal
								--local postCreate = ActionButton_PostCreate_Small
								local button = self:SpawnActionButton("action", self.frame, postCreate, id, 1)
								button.overrideAlphaWhenEmpty = .9

								if (id == 1) then
									primaryBackdrop:SetParent(button)
									primaryBackdrop:SetFrameStrata("LOW")
									primaryBackdrop:SetFrameLevel(1)
								end

								--6x1
								button:Place("BOTTOMLEFT", self.frame, "BOTTOM", -frameW/2 + -2 + padSide + (id-1)*(size+padding), 7)
								
								-- Layout helper
								button:SetAttribute("layoutID", self.buttonID)

								-- Always lock vehicle buttons
								button:SetAttribute("buttonLock", true)

								-- Link the buttons and their pagers 
								--proxy:SetFrameRef("Button"..self.buttonID, button)
								--proxy:SetFrameRef("Pager"..self.buttonID, button:GetPager())
	
								-- Reference all buttons in our menu callback frame
								--proxy:Execute(([=[
								--	table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
								--	table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
								--]=]):format(self.buttonID, self.buttonID))
								
								-- Let's put on a special visibility driver 
								-- that hides these buttons in vehicles, and on taxis.
								UnregisterAttributeDriver(button._owner, "state-vis")
								local visibilityDriver = "[canexitvehicle,novehicleui]hide;[overridebar][possessbar][shapeshift][vehicleui]show;hide"

								--RegisterAttributeDriver(button._owner, "state-vis", "[canexitvehicle,novehicleui][vehicleui][overridebar][possessbar]hide;[@player,exists][shapeshift]show;hide")
								RegisterAttributeDriver(button._owner, "state-vis", visibilityDriver)

								-- Button cache
								--self.Buttons[self.buttonID] = button

								-- Faster lookups
								self.ButtonLookup[button] = true
							end

						end,

						"SpawnStanceBar", function(self)
						end,
						
						"SpawnTotemBar", function(self)
							if (not IsRetail) then
								return
							end
						
							local db = self.db
						
							-- Restrictions:
							-- 	Can't reposition or reparent in combat
							-- 	Can't remove button methods like SetPoint to prevent blizzard repositioning
							-- 	Can't really mess with PetFrame hide/show either, it needs to remain whatever Blizzard intended.
						
							local totemScale = 1.5 
							local width, height = 37*4 + (-4)*3, 37 -- (136*37) size of the totem buttons, plus space between them
						
							-- Just for my own reference:
							-- 	player castbar "BOTTOM", "UICenter", "BOTTOM", 0, 290
							-- 	player altpower "BOTTOM", "UICenter", "BOTTOM", 0, 340 ("CENTER", "UICenter", "CENTER", 0, -189)
							local totemHolderFrame = self:CreateFrame("Frame", nil, "UICenter")
							totemHolderFrame:SetSize(2,2)
							totemHolderFrame:Place("BOTTOM", self:GetFrame("Minimap"), "TOP", 0, 60)
							--totemHolderFrame:Place("BOTTOM", "UICenter", "BOTTOM", 0, 390)
							
							-- Scaling it up get a more fitting size,
							-- without messing with actual relative
							-- positioning of the buttons.
							local totemFrame = TotemFrame -- original size is 128x53
							totemFrame:SetParent(totemHolderFrame)
							totemFrame:SetScale(totemScale)
							totemFrame:SetSize(width, height)
							
						
							local hidden = CreateFrame("Frame")
							hidden:Hide()
						
							for i = 1,4 do -- MAX_TOTEMS = 4
								local buttonName = "TotemFrameTotem"..i
								local button = _G[buttonName]
								local buttonBackground = _G[buttonName.."Background"]
								local buttonIcon = _G[buttonName.."IconTexture"] -- doesn't support SetMask
								local buttonDuration = _G[buttonName.."Duration"]
								local buttonCooldown = _G[buttonName.."IconCooldown"] -- doesn't support SetMask
						
								buttonBackground:SetParent(hidden)
								buttonDuration:SetParent(hidden)
								buttonCooldown:SetReverse(false)
								
								local borderFrame, borderTexture
								for i = 1, button:GetNumChildren() do
									local child = select(i, button:GetChildren())
									if (child:GetObjectType() == "Frame") and (not child:GetName()) then
										for j = 1, child:GetNumRegions() do
											local region = select(j, child:GetRegions())
											if (region:GetObjectType() == "Texture") and (region:GetTexture() == [=[Interface\CharacterFrame\TotemBorder]=]) then
												region:ClearAllPoints()
												region:SetPoint("CENTER", 0, 0)
												region:SetTexture(GetMedia("actionbutton-border"))
												region:SetSize(256*.25,256*.25)
												borderFrame = child
												borderTexture = region
												break
											end
										end
									end
									if (borderFrame and borderTexture) then
										break
									end
								end
								button.borderFrame = borderFrame
								button.borderTexture = borderTexture
						
								local duration = borderFrame:CreateFontString()
								duration:SetDrawLayer("OVERLAY")
								duration:SetPoint("CENTER", button, "BOTTOMRIGHT", -8, 10)
								duration:SetFontObject(GetFont(9,true))
								duration:SetAlpha(.75)
						
								button.duration = duration
							end
						
							-- Aimed to be compact and displayed on buttons
							local DAY, HOUR, MINUTE = 86400, 3600, 60
							local formatCooldownTime = function(time)
								if (time > DAY) then -- more than a day
									time = time + DAY/2
									return "%d%s", time/DAY - time/DAY%1, "d"
								elseif (time > HOUR) then -- more than an hour
									time = time + HOUR/2
									return "%d%s", time/HOUR - time/HOUR%1, "h"
								elseif (time > MINUTE) then -- more than a minute
									time = time + MINUTE/2
									return "%d%s", time/MINUTE - time/MINUTE%1, "m"
								elseif (time > 10) then -- more than 10 seconds
									return "%d", time - time%1
								elseif (time >= 1) then -- more than 5 seconds
									return "|cffff8800%d|r", time - time%1
								elseif (time > 0) then
									return "|cffff0000%d|r", time*10 - time*10%1
								else
									return ""
								end	
							end

							local totemButtonOnUpdate = function(button, elapsed)
								button.duration:SetFormattedText(formatCooldownTime(GetTotemTimeLeft(button.slot)))
							end
						
							local totemButtonUpdate = function(button, startTime, duration, icon)
								if (duration > 0) then
									button:SetScript("OnUpdate", totemButtonOnUpdate)
								else
									button:SetScript("OnUpdate", nil)
								end
							end
							hooksecurefunc("TotemButton_Update", totemButtonUpdate)
						
							local totemUpdate
							totemUpdate = function(self, event, ...)
								-- Trying the tainty way
								--if (InCombatLockdown()) then
								--	self:RegisterEvent("PLAYER_REGEN_ENABLED", totemUpdate)
								--	return
								--end
								--if (event == "PLAYER_REGEN_ENABLED") then
								--	self:UnregisterEvent("PLAYER_REGEN_ENABLED", totemUpdate)
								--end
								local point, anchor = totemFrame:GetPoint()
								if (anchor ~= totemHolderFrame) then
									totemFrame:ClearAllPoints()
									totemFrame:SetPoint("CENTER", totemHolderFrame, "CENTER", 0, 0)
								end
							end
							hooksecurefunc(TotemFrame, "SetPoint", totemUpdate)
						
							-- Initial update to position it
							totemUpdate()
						end,
						
						"SpawnExitButton", function(self)
							-- Proper conversion constant.
							local deg2rad = math.pi/180
						
							local layout = Private.GetLayout(self:GetName(), "Azerite")
							local button = self:SpawnActionButton("exit", self:GetFrame("UICenter"))
							button:SetFrameLevel(100)
							button:Place("CENTER", "Minimap", "CENTER", -math.cos(45*deg2rad)*114, math.sin(45*deg2rad)*114)
							button:SetSize(32, 32)
							button.texture = button:CreateTexture()
							button.texture:SetSize(64, 64)
							button.texture:SetPoint("CENTER", 0, 0)
							button.texture:SetTexture(GetMedia("icon_exit_flight"))
							button.texture:SetVertexColor(.75,.75,.75)
							button.PostLeave = function(self)
								self.texture:SetVertexColor(.75,.75,.75)
							end
							button.PostEnter = function(self)
								self.texture:SetVertexColor(1,1,1)
								local tooltip = self:GetTooltip()
								tooltip:Hide()
								tooltip:SetDefaultAnchor(self)
								if (UnitOnTaxi("player")) then 
									tooltip:AddLine(TAXI_CANCEL)
									tooltip:AddLine(TAXI_CANCEL_DESCRIPTION, Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
								elseif (IsMounted()) then 
									tooltip:AddLine(BINDING_NAME_DISMOUNT)
									tooltip:AddLine(L["%s to dismount."]:format(L["<Left-Click>"]), Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
								elseif (IsPossessBarVisible() and PetCanBeDismissed()) then
									tooltip:AddLine(PET_DISMISS)
									tooltip:AddLine(L["%s to dismiss your controlled minion."]:format(L["<Left-Click>"]), Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
								else
									tooltip:AddLine(LEAVE_VEHICLE)
									tooltip:AddLine(L["%s to leave the vehicle."]:format(L["<Left-Click>"]), Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
								end 
								tooltip:Show()
							end
					
							self.VehicleExitButton = button
						end,

						-- Getters
						----------------------------------------------------
						-- Return an iterator for actionbar buttons
						"GetButtons", function(self)
							return pairs(self.Buttons)
						end,

						-- Return an iterator for pet actionbar buttons
						"GetPetButtons", function(self)
							return pairs(self.PetButtons)
						end,

						-- Return the frames for the explorer mode mouseover
						"GetExplorerModeFrameAnchors", function(self)
							return self:GetOverlayFrame()
						end,

						-- Return the actionbar frame for the explorer mode mouseover
						"GetOverlayFrame", function(self)
							return self.frameOverlay
						end,
						

						-- Setters
						----------------------------------------------------
						-- Method that allows any module to request the actionbars
						-- to temporarily be faded in and fully visible.
						-- This does not apply to fully hidden buttons, 
						-- but affects buttons hidden by fadeout or the explorer mode.
						"SetForcedVisibility", function(self, force)
							--local actionBarHoverFrame = self:GetFadeFrame()
							--actionBarHoverFrame.FORCED = force and true
						end,

						-- Updates
						----------------------------------------------------
						-- Post update that sends the message 
						-- GP_UPDATE_ACTIONBUTTON_COUNT to registered modules
						-- when the count of available buttons is updated.
						-- Other modules can listen for this to adjust as needed.
						"UpdateButtonCount", function(self)
							self:SendMessage("GP_UPDATE_ACTIONBUTTON_COUNT")
						end,

						-- Just a proxy for the secure arrangement method.
						-- Only ever call this out of combat, as it does not check for it.
						"UpdateButtonLayout", function(self)
							local proxy = self:GetSecureUpdater()
							if (proxy) then
								proxy:Execute(proxy:GetAttribute("arrangeButtons"))
								proxy:Execute(proxy:GetAttribute("arrangePetButtons"))
							end
						end,

						-- Updates whether spells are cast on button press or release.
						-- This cannot be changed in combat, as it requires changing 
						-- a cvar, and not even secure handlers can do that in combat.
						-- It is however queued for combat end, so it still happens after.
						"UpdateCastOnDown", function(self)
							if InCombatLockdown() then 
								return self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateSettings")
							end
							if (event == "PLAYER_REGEN_ENABLED") then 
								self:UnregisterEvent("PLAYER_REGEN_ENABLED", "UpdateSettings")
							end 
							local db = self.db
							for button in self:GetAllActionButtonsOrdered() do
								button:RegisterForClicks(db.castOnDown and "AnyDown" or "AnyUp")
								button:Update()
							end 
						end,

						-- Updates the anchors used by the explorer mode
						-- to decide when you are hovering above the actionbar section.
						"UpdateExplorerModeAnchors", function(self)
							local db = self.db
							local frame = self:GetOverlayFrame()
							frame:ClearAllPoints()
							frame:SetPoint("TOPLEFT", self.Buttons[1], "TOPLEFT")
							frame:SetPoint("BOTTOMRIGHT", self.Buttons[12], "BOTTOMRIGHT")
						end,

						-- Update actionbutton tooltip display settings.
						"UpdateTooltipSettings", function(self)
							local tooltip = self:GetActionButtonTooltip()
							tooltip.colorNameAsSpellWithUse = true -- color item name as a spell (not by rarity) when it has a Use effect
							tooltip.hideItemLevelWithUse = true -- hide item level when it has a Use effect 
							tooltip.hideStatsWithUseEffect = true -- hide item stats when it has a Use effect
							tooltip.hideBindsWithUseEffect = true -- hide item bind status when it has a Use effect
							tooltip.hideUniqueWithUseEffect = true -- hide item unique status when it has a Use effect
							tooltip.hideEquipTypeWithUseEffect = false -- hide item equip location and item type with Use effect
						end,

												-- This method only sets button parameters, 
						-- the actual keybind display and graphic choices
						-- are done in the button widget in ./schematics-widgets.lua.
						"UpdateKeybindDisplay", function(self)
							local db = self.db
							for button in self:GetAllActionButtonsOrdered() do
								button.padType = self:GetGamepadType()
								button.padStyle = db.gamePadType or "default"

								if (db.keybindDisplayPriority == "gamepad") then
									button.prioritizeGamePadBinds = true
									button.prioritzeKeyboardBinds = nil

								elseif (db.keybindDisplayPriority == "keyboard") then
									button.prioritizeGamePadBinds = nil
									button.prioritzeKeyboardBinds = true
								else
									button.prioritizeGamePadBinds = (db.lastKeybindDisplayType == "gamepad") or self:IsUsingGamepad()
									button.prioritzeKeyboardBinds = true
								end

								if (button.UpdateBinding) then
									button:UpdateBinding()
								end
							end 
						end, 

						-- A general method to update all things at once.
						"UpdateSettings", function(self, event, ...)
							self:UpdateExplorerModeAnchors()
							self:UpdateCastOnDown()
							self:UpdateKeybindDisplay()
							self:UpdateTooltipSettings()
						end

					},
					-- The 'chain' sections performs methods on the module,
					-- and passes the unpacked arguments in the tables 
					-- to those methods. An empty table means no arguments.
					-- Here we can call methods created in previously defined
					-- 'values' sections.
					chain = {
						"CreateScaffolds", {},
						"CreateSecureUpdater", {},
						"SpawnPrimaryBar", {},
						"SpawnSecondaryBar", {},
						"SpawnVehicleBar", {},
						"SpawnPetBar", {},
						"SpawnStanceBar", {},
						"SpawnExitButton", {},
						"SpawnTotemBar", {},
						"UpdateButtonLayout", {},
						"UpdateActionButtonBindings", {},
						"UpdateSettings", {}
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
						--"RegisterEvent", { "PET_BAR_UPDATE", "OnEvent" },
						"RegisterEvent", { "PLAYER_ENTERING_WORLD", "OnEvent" },
						"RegisterEvent", { "PLAYER_REGEN_ENABLED", "OnEvent" },
						"RegisterEvent", { "PLAYER_REGEN_DISABLED", "OnEvent" },
						"RegisterMessage", { "GP_USING_GAMEPAD", "OnEvent"},
						"RegisterMessage", { "GP_USING_KEYBOARD", "OnEvent"},
						"RegisterMessage", { "GP_FORCED_ACTIONBAR_VISIBILITY_REQUESTED", "OnEvent"},
						"RegisterMessage", { "GP_FORCED_ACTIONBAR_VISIBILITY_CANCELED", "OnEvent"},
						"RegisterEvent", { "UPDATE_BINDINGS", "OnEvent"}
					}
				}
			}
		}
	}
})

-- Azerite
Private.RegisterSchematic("ModuleForge::ActionBars", "Azerite", {
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
						-- Cache of buttons
						"Buttons", {}, -- all action buttons
						"PetButtons", {}, -- all pet buttons
						"HoverButtons", {}, -- all action buttons that can fade out
						"ButtonLookup", {}, -- quickly identify a frame as our button

						-- Secure Code Snippets.
						-- These are used by the menu system and the bars themselves
						-- to update layout and other secure settings even while in combat.
						"secureSnippets", {
							-- Arrange the main and extra actionbar buttons
							arrangeButtons = [=[
								local UICenter = self:GetFrameRef("UICenter"); 
								local extraButtonsCount = tonumber(self:GetAttribute("extraButtonsCount")) or 0;
								local buttonSize, buttonSpacing, iconSize = 64, 8, 44;
								local row2mod = 1-2/5; -- horizontal offset for upper row

								for id,button in ipairs(Buttons) do 
									local buttonID = button:GetID(); 
									local barID = Pagers[id]:GetID(); 

									-- Brave New World.
									local layoutID = button:GetAttribute("layoutID");
									if (layoutID <= 7) then
										button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((layoutID-1) * (buttonSize + buttonSpacing)), 42)
									else
										local slot = floor((layoutID - 8)/2)

										-- Bottom row
										if (layoutID%2 == 0) then

											button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((slot+7) * (buttonSize + buttonSpacing)), 42 )

										-- Top row
										else

											button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOMLEFT", 60 + ((slot+7 + row2mod) * (buttonSize + buttonSpacing)), 42 + buttonSize + buttonSpacing)
										end

									end

								end 

								-- lua callback to update the hover frame anchors to the current layout
								self:CallMethod("UpdateFadeAnchors"); 
							
							]=],

							-- Arrange the pet action bar buttons
							arrangePetButtons = [=[
								local UICenter = self:GetFrameRef("UICenter");
								local buttonSize, buttonSpacing = 64*3/4, 2;
								local startX, startY = -(buttonSize*10 + buttonSpacing*9)/2, 200;

								for id,button in ipairs(PetButtons) do
									button:ClearAllPoints();
									button:SetPoint("BOTTOMLEFT", UICenter, "BOTTOM", startX + ((id-1) * (buttonSize + buttonSpacing)), startY);
								end

								-- lua callback to update the explorer mode anchors to the current layout
								self:CallMethod("UpdateExplorerModeAnchors"); 

							]=],

							-- Saved setting changed.
							-- This is called by the options menu after changes and on startup.
							attributeChanged = [=[
								-- 'name' appears to be turned to lowercase by the restricted environment(?), 
								-- but we're doing it manually anyway, just to avoid problems. 
								if name then 
									name = string.lower(name); 
								end 

								if (name == "change-extrabuttonsvisibility") then 
									self:SetAttribute("extraButtonsVisibility", value); 
									self:CallMethod("UpdateFadeAnchors"); 
									self:CallMethod("UpdateFading"); 
								
								elseif (name == "change-petbarvisibility") then 
										self:SetAttribute("petBarVisibility", value); 
										self:CallMethod("UpdateFadeAnchors"); 
										self:CallMethod("UpdateFading"); 
							
								elseif (name == "change-extrabuttonscount") then 
									local extraButtonsCount = tonumber(value) or 0; 
									local visible = extraButtonsCount + 7; 
							
									-- Update button visibility counts
									for i = 8,24 do 
										local pager = Pagers[i]; 
										if (i > visible) then 
											if pager:IsShown() then 
												pager:Hide(); 
											end 
										else 
											if (not pager:IsShown()) then 
												pager:Show(); 
											end 
										end 
									end 

									self:SetAttribute("extraButtonsCount", extraButtonsCount); 
									self:RunAttribute("arrangeButtons"); 

									-- tell lua about it
									self:CallMethod("UpdateButtonCount"); 

								elseif (name == "change-castondown") then 
									self:SetAttribute("castOnDown", value and true or false); 
									self:CallMethod("UpdateCastOnDown"); 

								elseif (name == "change-petbarenabled") then 
									self:SetAttribute("petBarEnabled", value and true or false); 

									for i = 1,10 do
										local pager = PetPagers[i]; 
										if value then 
											if (not pager:IsShown()) then 
												pager:Show(); 
											end 
										else 
											if pager:IsShown() then 
												pager:Hide(); 
											end 
										end 
									end

									-- lua callback to update the explorer mode anchors to the current layout
									self:CallMethod("UpdateExplorerModeAnchors"); 
									self:CallMethod("UpdateFadeAnchors"); 
									self:CallMethod("UpdateFading"); 
									
								elseif (name == "change-buttonlock") then 
									self:SetAttribute("buttonLock", value and true or false); 

									-- change all button attributes
									for id, button in ipairs(Buttons) do 
										button:SetAttribute("buttonLock", value);
									end

									-- change all pet button attributes
									for id, button in ipairs(PetButtons) do 
										button:SetAttribute("buttonLock", value);
									end

								elseif (name == "change-keybinddisplaypriority") then 
									self:SetAttribute("keybindDisplayPriority", value);
									self:CallMethod("UpdateKeybindDisplay"); 

								elseif (name == "change-gamepadtype") then
									self:SetAttribute("gamePadType", value);
									self:CallMethod("UpdateKeybindDisplay"); 
								end 

							]=]
						},

						-- Event handler
						----------------------------------------------------
						"OnEvent", function(self, event, ...)
							if (event == "UPDATE_BINDINGS") then
								self:UpdateActionButtonBindings()
						
							elseif (event == "PLAYER_ENTERING_WORLD") then
								self.inCombat = false
								self:UpdateActionButtonBindings()
						
							elseif (event == "PLAYER_REGEN_DISABLED") then
								self.inCombat = true 
						
							elseif (event == "PLAYER_REGEN_ENABLED") then
								self.inCombat = false
						
							elseif (event == "GP_FORCED_ACTIONBAR_VISIBILITY_REQUESTED") then
								self:SetForcedVisibility(true)
						
							elseif (event == "GP_FORCED_ACTIONBAR_VISIBILITY_CANCELED") then
								self:SetForcedVisibility(false)
							
							elseif (event == "GP_USING_GAMEPAD") then
								self.db.lastKeybindDisplayType = "gamepad"
								self:UpdateKeybindDisplay()

							elseif (event == "GP_USING_KEYBOARD") then
								self.db.lastKeybindDisplayType = "keyboard"
								self:UpdateKeybindDisplay()

							elseif (event == "PET_BAR_UPDATE") then
								self:UpdateExplorerModeAnchors()
							end
						end, 

						-- Spawning
						----------------------------------------------------
						-- Method to create scaffolds and overlay frames.
						"CreateScaffolds", function(self)
							-- Create master frame. This one becomes secure.
							self.frame = self:CreateFrame("Frame", nil, "UICenter")
						
							-- Create overlay frames used for explorer mode.
							self.frameOverlay = self:CreateFrame("Frame", nil, "UICenter")
							self.frameOverlayPet = self:CreateFrame("Frame", nil, "UICenter")
						
							-- Apply overlay alpha to the master frame.
							hooksecurefunc(self.frameOverlay, "SetAlpha", function(_,alpha) self.frame:SetAlpha(alpha) end)
						end,

						-- Method to create the secure callback frame for the menu system.
						"CreateSecureUpdater", function(self)
							local OptionsMenu = self:GetOwner():GetModule("OptionsMenu", true)
							if (OptionsMenu) then
								local callbackFrame = OptionsMenu:CreateCallbackFrame(self)
								callbackFrame:AssignSettings(self.db)
								callbackFrame:AssignProxyMethods("UpdateCastOnDown", "UpdateFading", "UpdateFadeAnchors", "UpdateExplorerModeAnchors", "UpdateButtonCount", "UpdateKeybindDisplay")
					
								-- Create tables to hold the buttons
								-- within the restricted environment.
								callbackFrame:Execute([=[ 
									Buttons = table.new();
									Pagers = table.new();
									PetButtons = table.new();
									PetPagers = table.new();
									StanceButtons = table.new();
								]=])
					
								-- Apply references and attributes used for updates.
								callbackFrame:AssignAttributes(
									"BOTTOMLEFT_ACTIONBAR_PAGE", BOTTOMLEFT_ACTIONBAR_PAGE,
									"BOTTOMRIGHT_ACTIONBAR_PAGE", BOTTOMRIGHT_ACTIONBAR_PAGE,
									"RIGHT_ACTIONBAR_PAGE", RIGHT_ACTIONBAR_PAGE,
									"LEFT_ACTIONBAR_PAGE", LEFT_ACTIONBAR_PAGE,
									"arrangeButtons", self.secureSnippets.arrangeButtons,
									"arrangePetButtons", self.secureSnippets.arrangePetButtons
								)
					
								callbackFrame:AssignCallback(self.secureSnippets.attributeChanged)
							end
						end, 

						"SpawnActionBars", function(self)
							local db = self.db
							local proxy = self:GetSecureUpdater()
						
							-- Private test mode to show all
							local FORCED = false 
						
							local buttonID = 0 -- current buttonID when spawning
							local numPrimary = 7 -- Number of primary buttons always visible
							local firstHiddenID = db.extraButtonsCount + numPrimary -- first buttonID to be hidden
							
							-- Primary Action Bar
							for id = 1,NUM_ACTIONBAR_BUTTONS do 
								buttonID = buttonID + 1
								self.Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton_PostCreate_Normal, id, 1)
								self.HoverButtons[self.Buttons[buttonID]] = buttonID > numPrimary
						
								-- Experimental code to see if I could make an attribute
								-- driver changing buttonID based on modifier keys.
								-- Short answer? I could.
								if (false) then
									local button = self.Buttons[buttonID]
									if (id >= 1 and id <= 3) then
										RegisterAttributeDriver(button, "state-id", string.format("[mod:ctrl+shift]%d;[mod:shift]%d;[mod:ctrl]%d;%d", id+9, id+3, id+6, id))
										button:SetAttribute("_onattributechanged", [=[
											if (name == "state-id") then
												self:SetID(tonumber(value));
						
												local buttonPage = self:GetAttribute("actionpage"); 
												local id = self:GetID(); 
												local actionpage = tonumber(buttonPage); 
												local slot = actionpage and (actionpage > 1) and ((actionpage - 1)*12 + id) or id; 
										
												self:SetAttribute("actionpage", actionpage or 0); 
												self:SetAttribute("action", slot); 
						
												self:CallMethod("UpdateAction"); 
											end
										]=])
									end
								end
							end 
						
							-- Secondary Action Bar (Bottom Left)
							for id = 1,NUM_ACTIONBAR_BUTTONS do 
								buttonID = buttonID + 1
								self.Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton_PostCreate_Normal, id, BOTTOMLEFT_ACTIONBAR_PAGE)
								self.HoverButtons[self.Buttons[buttonID]] = true
							end 
						
							-- Layout helper
							for buttonID,button in pairs(self.Buttons) do
								button:SetAttribute("layoutID",buttonID)
							end
							
							-- First Side Bar (Bottom Right)
							if (false) then
								for id = 1,NUM_ACTIONBAR_BUTTONS do 
									buttonID = buttonID + 1
									self.Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton_PostCreate_Normal, id, BOTTOMRIGHT_ACTIONBAR_PAGE)
								end
						
								-- Second Side bar (Right)
								for id = 1,NUM_ACTIONBAR_BUTTONS do 
									buttonID = buttonID + 1
									self.Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton_PostCreate_Normal, id, RIGHT_ACTIONBAR_PAGE)
								end
						
								-- Third Side Bar (Left)
								for id = 1,NUM_ACTIONBAR_BUTTONS do 
									buttonID = buttonID + 1
									self.Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButton_PostCreate_Normal, id, LEFT_ACTIONBAR_PAGE)
								end
							end
						
							-- Apply common settings to the action buttons.
							for buttonID,button in ipairs(self.Buttons) do 
						
								-- Identify it easily.
								self.ButtonLookup[button] = true
						
								-- Apply saved buttonLock setting
								button:SetAttribute("buttonLock", db.buttonLock)
						
								-- Link the buttons and their pagers 
								proxy:SetFrameRef("Button"..buttonID, self.Buttons[buttonID])
								proxy:SetFrameRef("Pager"..buttonID, self.Buttons[buttonID]:GetPager())
						
								-- Reference all buttons in our menu callback frame
								proxy:Execute(([=[
									table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
									table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
								]=]):format(buttonID, buttonID))
						
								-- Hide buttons beyond our current maximum visible
								if (self.HoverButtons[button] and (buttonID > firstHiddenID)) then 
									button:GetPager():Hide()
								end 
							end 
						end,
						
						"SpawnPetBar", function(self)
							local db = self.db
							local proxy = self:GetSecureUpdater()
							
							-- Spawn the Pet Bar
							for id = 1,NUM_PET_ACTION_SLOTS do
								self.PetButtons[id] = self:SpawnActionButton("pet", self.frame, ActionButton_PostCreate_Small, id)
							end
						
							-- Apply common stuff to the pet buttons
							for id,button in pairs(self.PetButtons) do
						
								-- Identify it easily.
								self.ButtonLookup[button] = true
						
								-- Apply saved buttonLock setting
								button:SetAttribute("buttonLock", db.buttonLock)
						
								-- Link the buttons and their pagers 
								proxy:SetFrameRef("PetButton"..id, self.PetButtons[id])
								proxy:SetFrameRef("PetPager"..id, self.PetButtons[id]:GetPager())
						
								if (not db.petBarEnabled) then
									self.PetButtons[id]:GetPager():Hide()
								end
								
								-- Reference all buttons in our menu callback frame
								proxy:Execute(([=[
									table.insert(PetButtons, self:GetFrameRef("PetButton"..%.0f)); 
									table.insert(PetPagers, self:GetFrameRef("PetPager"..%.0f)); 
								]=]):format(id, id))
								
							end
						end,
					
						"SpawnStanceBar", function(self)
						end,
						
						"SpawnTotemBar", function(self)
							if (not IsRetail) then
								return
							end
						
							local db = self.db
						
							-- Restrictions:
							-- 	Can't reposition or reparent in combat
							-- 	Can't remove button methods like SetPoint to prevent blizzard repositioning
							-- 	Can't really mess with PetFrame hide/show either, it needs to remain whatever Blizzard intended.
						
							local totemScale = 1.5 
							local width, height = 37*4 + (-4)*3, 37 -- (136*37) size of the totem buttons, plus space between them
						
							-- Just for my own reference:
							-- 	player castbar "BOTTOM", "UICenter", "BOTTOM", 0, 290
							-- 	player altpower "BOTTOM", "UICenter", "BOTTOM", 0, 340 ("CENTER", "UICenter", "CENTER", 0, -189)
							local totemHolderFrame = self:CreateFrame("Frame", nil, "UICenter")
							totemHolderFrame:SetSize(2,2)
							totemHolderFrame:Place("BOTTOM", self:GetFrame("Minimap"), "TOP", 0, 60)
							--totemHolderFrame:Place("BOTTOM", "UICenter", "BOTTOM", 0, 390)
							
							-- Scaling it up get a more fitting size,
							-- without messing with actual relative
							-- positioning of the buttons.
							local totemFrame = TotemFrame -- original size is 128x53
							totemFrame:SetParent(totemHolderFrame)
							totemFrame:SetScale(totemScale)
							totemFrame:SetSize(width, height)
							
						
							local hidden = CreateFrame("Frame")
							hidden:Hide()
						
							for i = 1,4 do -- MAX_TOTEMS = 4
								local buttonName = "TotemFrameTotem"..i
								local button = _G[buttonName]
								local buttonBackground = _G[buttonName.."Background"]
								local buttonIcon = _G[buttonName.."IconTexture"] -- doesn't support SetMask
								local buttonDuration = _G[buttonName.."Duration"]
								local buttonCooldown = _G[buttonName.."IconCooldown"] -- doesn't support SetMask
						
								buttonBackground:SetParent(hidden)
								buttonDuration:SetParent(hidden)
								buttonCooldown:SetReverse(false)
								
								local borderFrame, borderTexture
								for i = 1, button:GetNumChildren() do
									local child = select(i, button:GetChildren())
									if (child:GetObjectType() == "Frame") and (not child:GetName()) then
										for j = 1, child:GetNumRegions() do
											local region = select(j, child:GetRegions())
											if (region:GetObjectType() == "Texture") and (region:GetTexture() == [=[Interface\CharacterFrame\TotemBorder]=]) then
												region:ClearAllPoints()
												region:SetPoint("CENTER", 0, 0)
												region:SetTexture(GetMedia("actionbutton-border"))
												region:SetSize(256*.25,256*.25)
												borderFrame = child
												borderTexture = region
												break
											end
										end
									end
									if (borderFrame and borderTexture) then
										break
									end
								end
								button.borderFrame = borderFrame
								button.borderTexture = borderTexture
						
								local duration = borderFrame:CreateFontString()
								duration:SetDrawLayer("OVERLAY")
								duration:SetPoint("CENTER", button, "BOTTOMRIGHT", -8, 10)
								duration:SetFontObject(GetFont(9,true))
								duration:SetAlpha(.75)
						
								button.duration = duration
							end
						
							-- Aimed to be compact and displayed on buttons
							local DAY, HOUR, MINUTE = 86400, 3600, 60
							local formatCooldownTime = function(time)
								if (time > DAY) then -- more than a day
									time = time + DAY/2
									return "%d%s", time/DAY - time/DAY%1, "d"
								elseif (time > HOUR) then -- more than an hour
									time = time + HOUR/2
									return "%d%s", time/HOUR - time/HOUR%1, "h"
								elseif (time > MINUTE) then -- more than a minute
									time = time + MINUTE/2
									return "%d%s", time/MINUTE - time/MINUTE%1, "m"
								elseif (time > 10) then -- more than 10 seconds
									return "%d", time - time%1
								elseif (time >= 1) then -- more than 5 seconds
									return "|cffff8800%d|r", time - time%1
								elseif (time > 0) then
									return "|cffff0000%d|r", time*10 - time*10%1
								else
									return ""
								end	
							end

							local totemButtonOnUpdate = function(button, elapsed)
								button.duration:SetFormattedText(formatCooldownTime(GetTotemTimeLeft(button.slot)))
							end
						
							local totemButtonUpdate = function(button, startTime, duration, icon)
								if (duration > 0) then
									button:SetScript("OnUpdate", totemButtonOnUpdate)
								else
									button:SetScript("OnUpdate", nil)
								end
							end
							hooksecurefunc("TotemButton_Update", totemButtonUpdate)
						
							local totemUpdate
							totemUpdate = function(self, event, ...)
								-- Trying the tainty way
								--if (InCombatLockdown()) then
								--	self:RegisterEvent("PLAYER_REGEN_ENABLED", totemUpdate)
								--	return
								--end
								--if (event == "PLAYER_REGEN_ENABLED") then
								--	self:UnregisterEvent("PLAYER_REGEN_ENABLED", totemUpdate)
								--end
								local point, anchor = totemFrame:GetPoint()
								if (anchor ~= totemHolderFrame) then
									totemFrame:ClearAllPoints()
									totemFrame:SetPoint("CENTER", totemHolderFrame, "CENTER", 0, 0)
								end
							end
							hooksecurefunc(TotemFrame, "SetPoint", totemUpdate)
						
							-- Initial update to position it
							totemUpdate()
						end,
						
						"SpawnExitButton", function(self)
							local layout = Private.GetLayout(self:GetName())
						
							local button = self:SpawnActionButton("exit", self:GetFrame("UICenter"))
							button:SetFrameLevel(100)
							button:Place(unpack(layout.ExitButtonPlace))
							button:SetSize(unpack(layout.ExitButtonSize))
							button.texture = button:CreateTexture()
							button.texture:SetSize(unpack(layout.ExitButtonTextureSize))
							button.texture:SetPoint(unpack(layout.ExitButtonTexturePlace))
							button.texture:SetTexture(layout.ExitButtonTexturePath)
							button.PostEnter = function(self)
								local tooltip = self:GetTooltip()
								tooltip:Hide()
								tooltip:SetDefaultAnchor(self)
								if (UnitOnTaxi("player")) then 
									tooltip:AddLine(TAXI_CANCEL)
									tooltip:AddLine(TAXI_CANCEL_DESCRIPTION, Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
								elseif (IsMounted()) then 
									tooltip:AddLine(BINDING_NAME_DISMOUNT)
									tooltip:AddLine(L["%s to dismount."]:format(L["<Left-Click>"]), Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
								elseif (IsPossessBarVisible() and PetCanBeDismissed()) then
									tooltip:AddLine(PET_DISMISS)
									tooltip:AddLine(L["%s to dismiss your controlled minion."]:format(L["<Left-Click>"]), Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
								else
									tooltip:AddLine(LEAVE_VEHICLE)
									tooltip:AddLine(L["%s to leave the vehicle."]:format(L["<Left-Click>"]), Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
								end 
								tooltip:Show()
							end
						
							self.VehicleExitButton = button
						end,

						-- Getters
						----------------------------------------------------
						-- Return an iterator for actionbar buttons
						"GetButtons", function(self)
							return pairs(self.Buttons)
						end,

						-- Return an iterator for pet actionbar buttons
						"GetPetButtons", function(self)
							return pairs(self.PetButtons)
						end,

						-- Return the frames for the explorer mode mouseover
						"GetExplorerModeFrameAnchors", function(self)
							return self:GetOverlayFrame(), self:GetOverlayFramePet()
						end,

						-- Return the actionbar frame for the explorer mode mouseover
						"GetOverlayFrame", function(self)
							return self.frameOverlay
						end,

						-- Return the pet actionbar frame for the explorer mode mouseover
						"GetOverlayFramePet", function(self)
							return self.frameOverlayPet
						end,

						-- Return the frame for actionbutton mouseover fading
						"GetFadeFrame", function(self)
							if (not self.ActionBarHoverFrame) then 
								local module = self
								self.ActionBarHoverFrame = self:CreateFrame("Frame")
								self.ActionBarHoverFrame.timeLeft = 0
								self.ActionBarHoverFrame.elapsed = 0
								self.ActionBarHoverFrame:SetScript("OnUpdate", function(self, elapsed) 
									self.elapsed = self.elapsed + elapsed
									self.timeLeft = self.timeLeft - elapsed
							
									if (self.timeLeft <= 0) then
										if FORCED or self.FORCED or self.always or (self.incombat and module.inCombat) or self.forced or self.flyout or self:IsMouseOver(0,0,0,0) then
											if (not self.isMouseOver) then 
												self.isMouseOver = true
												self.alpha = 1
												for id = 8,24 do 
													module.Buttons[id]:GetPager():SetAlpha(self.alpha)
												end 
											end 
										else 
											if (self.isMouseOver) then 
												self.isMouseOver = nil
												if (not self.fadeOutTime) then 
													self.fadeOutTime = 1/5
												end 
											end 
											if (self.fadeOutTime) then 
												self.fadeOutTime = self.fadeOutTime - self.elapsed
												if (self.fadeOutTime > 0) then 
													self.alpha = self.fadeOutTime / (1/5)
												else 
													self.alpha = 0
													self.fadeOutTime = nil
												end 
												for id = 8,24 do 
													module.Buttons[id]:GetPager():SetAlpha(self.alpha)
												end 
											end 
										end 
										self.elapsed = 0
										self.timeLeft = 1/20
									end 
								end) 

								local actionBarGrid, petBarGrid, buttonLock
								self.ActionBarHoverFrame:SetScript("OnEvent", function(self, event, ...) 
									if (event == "ACTIONBAR_SHOWGRID") then 
										actionBarGrid = true
									elseif (event == "ACTIONBAR_HIDEGRID") then 
										actionBarGrid = nil
									elseif (event == "PET_BAR_SHOWGRID") then 
										petBarGrid = true
									elseif (event == "PET_BAR_HIDEGRID") then 
										petBarGrid = nil
									elseif (event == "buttonLock") then
										actionBarGrid = nil
										petBarGrid = nil
									end
									if (actionBarGrid or petBarGrid) then
										self.forced = true
									else
										self.forced = nil
									end 
								end)

								hooksecurefunc("ActionButton_UpdateFlyout", function(button) 
									if (self.HoverButtons[button]) then 
										self.ActionBarHoverFrame.flyout = button:IsFlyoutShown()
									end
								end)

								self.ActionBarHoverFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
								self.ActionBarHoverFrame:RegisterEvent("ACTIONBAR_SHOWGRID")

								-- We're showing the button slots while holding a pet action in retail,
								-- since pet actions can be placed on regular action buttons here.
								-- This is not the case in classic.
								if (IsRetail) then
									self.ActionBarHoverFrame:RegisterEvent("PET_BAR_HIDEGRID")
									self.ActionBarHoverFrame:RegisterEvent("PET_BAR_SHOWGRID")
								end

								self.ActionBarHoverFrame.isMouseOver = true -- Set this to initiate the first fade-out
							end
							return self.ActionBarHoverFrame
						end,

						-- Return the frame for pet actionbutton mouseover fading
						"GetFadeFramePet", function(self)
							if (not self.PetBarHoverFrame) then
								local module = self
								self.PetBarHoverFrame = self:CreateFrame("Frame")
								self.PetBarHoverFrame.timeLeft = 0
								self.PetBarHoverFrame.elapsed = 0
								self.PetBarHoverFrame:SetScript("OnUpdate", function(self, elapsed) 
									self.elapsed = self.elapsed + elapsed
									self.timeLeft = self.timeLeft - elapsed
							
									if (self.timeLeft <= 0) then
										if FORCED or self.FORCED or self.always or (self.incombat and module.inCombat) or self.forced or self.flyout or self:IsMouseOver(0,0,0,0) then
											if (not self.isMouseOver) then 
												self.isMouseOver = true
												self.alpha = 1
												for id in pairs(module.PetButtons) do
													module.PetButtons[id]:GetPager():SetAlpha(self.alpha)
												end 
											end
										else 
											if (self.isMouseOver) then 
												self.isMouseOver = nil
												if (not self.fadeOutTime) then 
													self.fadeOutTime = 1/5
												end 
											end 
											if (self.fadeOutTime) then 
												self.fadeOutTime = self.fadeOutTime - self.elapsed
												if (self.fadeOutTime > 0) then 
													self.alpha = self.fadeOutTime / (1/5)
												else 
													self.alpha = 0
													self.fadeOutTime = nil
												end 
												for id in pairs(module.PetButtons) do
													module.PetButtons[id]:GetPager():SetAlpha(self.alpha)
												end 
											end 
										end 
										self.elapsed = 0
										self.timeLeft = 1/20
									end 
								end) 

								self.PetBarHoverFrame:SetScript("OnEvent", function(self, event, ...) 
									if (event == "PET_BAR_SHOWGRID") then 
										self.forced = true
									elseif (event == "PET_BAR_HIDEGRID") or (event == "buttonLock") then
										self.forced = nil
									end 
								end)

								self.PetBarHoverFrame:RegisterEvent("PET_BAR_SHOWGRID")
								self.PetBarHoverFrame:RegisterEvent("PET_BAR_HIDEGRID")
								self.PetBarHoverFrame.isMouseOver = true -- Set this to initiate the first fade-out
							end
							return self.PetBarHoverFrame
						end,

						-- Setters
						----------------------------------------------------
						-- Method that allows any module to request the actionbars
						-- to temporarily be faded in and fully visible.
						-- This does not apply to fully hidden buttons, 
						-- but affects buttons hidden by fadeout or the explorer mode.
						"SetForcedVisibility", function(self, force)
							local actionBarHoverFrame = self:GetFadeFrame()
							actionBarHoverFrame.FORCED = force and true
						end,

						-- Updates
						----------------------------------------------------
						-- Updates when and if the additional actionbuttons should fade in and out. 
						"UpdateFading", function(self)
							local db = self.db

							-- Set action bar hover settings
							local actionBarHoverFrame = self:GetFadeFrame()
							actionBarHoverFrame.incombat = db.extraButtonsVisibility == "combat"
							actionBarHoverFrame.always = db.extraButtonsVisibility == "always"

							-- We're hardcoding these until options can be added
							local petBarHoverFrame = self:GetFadeFramePet()
							petBarHoverFrame.incombat = db.petBarVisibility == "combat"
							petBarHoverFrame.always = db.petBarVisibility == "always"
						end,

						-- Updates the anchors used by the explorer mode
						-- to decide when you are hovering above the actionbar section.
						"UpdateExplorerModeAnchors", function(self)
							local db = self.db
							local frame = self:GetOverlayFramePet()
							if (self.db.petBarEnabled) and (UnitExists("pet")) then
								frame:ClearAllPoints()
								frame:SetPoint("TOPLEFT", self.PetButtons[1], "TOPLEFT")
								frame:SetPoint("BOTTOMRIGHT", self.PetButtons[10], "BOTTOMRIGHT")
							else
								frame:ClearAllPoints()
								frame:SetAllPoints(self:GetFrame())
							end
						end,

						-- Updates the anchors for the frames controlling
						-- the mouseover fade of the additional action buttons.
						-- Usually called on startup and after button count changes.
						"UpdateFadeAnchors", function(self)
							local db = self.db

							-- Parse buttons for hoverbutton IDs
							local first, last, left, right, top, bottom, mLeft, mRight, mTop, mBottom
							for id,button in ipairs(self.Buttons) do 
								-- If we pass number of visible hoverbuttons, just bail out
								if (id > db.extraButtonsCount + 7) then 
									break 
								end 

								local bLeft = button:GetLeft()
								local bRight = button:GetRight()
								local bTop = button:GetTop()
								local bBottom = button:GetBottom()
								
								if (self.HoverButtons[button]) then 
									-- Only counting the first encountered as the first
									if (not first) then 
										first = id 
									end 

									-- Counting every button as the last, until we actually reach it 
									last = id 

									-- Figure out hoverframe anchor buttons
									left = left and (self.Buttons[left]:GetLeft() < bLeft) and left or id
									right = right and (self.Buttons[right]:GetRight() > bRight) and right or id
									top = top and (self.Buttons[top]:GetTop() > bTop) and top or id
									bottom = bottom and (self.Buttons[bottom]:GetBottom() < bBottom) and bottom or id
								end 

								-- Figure out main frame anchor buttons, 
								-- as we need this for the explorer mode fade anchors!
								mLeft = mLeft and (self.Buttons[mLeft]:GetLeft() < bLeft) and mLeft or id
								mRight = mRight and (self.Buttons[mRight]:GetRight() > bRight) and mRight or id
								mTop = mTop and (self.Buttons[mTop]:GetTop() > bTop) and mTop or id
								mBottom = mBottom and (self.Buttons[mBottom]:GetBottom() < bBottom) and mBottom or id
							end 

							-- Setup main frame anchors for explorer mode! 
							local overlayFrame = self:GetOverlayFrame()
							overlayFrame:ClearAllPoints()
							overlayFrame:SetPoint("TOP", self.Buttons[mTop], "TOP", 0, 0)
							overlayFrame:SetPoint("BOTTOM", self.Buttons[mBottom], "BOTTOM", 0, 0)
							overlayFrame:SetPoint("LEFT", self.Buttons[mLeft], "LEFT", 0, 0)
							overlayFrame:SetPoint("RIGHT", self.Buttons[mRight], "RIGHT", 0, 0)

							-- If we have hoverbuttons, setup the anchors
							if (left and right and top and bottom) then 
								local actionBarHoverFrame = self:GetFadeFrame()
								actionBarHoverFrame:ClearAllPoints()
								actionBarHoverFrame:SetPoint("TOP", self.Buttons[top], "TOP", 0, 0)
								actionBarHoverFrame:SetPoint("BOTTOM", self.Buttons[bottom], "BOTTOM", 0, 0)
								actionBarHoverFrame:SetPoint("LEFT", self.Buttons[left], "LEFT", 0, 0)
								actionBarHoverFrame:SetPoint("RIGHT", self.Buttons[right], "RIGHT", 0, 0)
							end

							local petBarHoverFrame = self:GetFadeFramePet()
							if (self.db.petBarEnabled) then
								petBarHoverFrame:ClearAllPoints()
								petBarHoverFrame:SetPoint("TOPLEFT", self.PetButtons[1], "TOPLEFT")
								petBarHoverFrame:SetPoint("BOTTOMRIGHT", self.PetButtons[10], "BOTTOMRIGHT")
							else
								petBarHoverFrame:ClearAllPoints()
								petBarHoverFrame:SetAllPoints(self:GetFrame())
							end
						end,

						-- Post update that sends the message 
						-- GP_UPDATE_ACTIONBUTTON_COUNT to registered modules
						-- when the count of available buttons is updated.
						-- Other modules can listen for this to adjust as needed.
						"UpdateButtonCount", function(self)
							self:SendMessage("GP_UPDATE_ACTIONBUTTON_COUNT")
						end,

						-- Just a proxy for the secure arrangement method.
						-- Only ever call this out of combat, as it does not check for it.
						"UpdateButtonLayout", function(self)
							local proxy = self:GetSecureUpdater()
							if (proxy) then
								proxy:Execute(proxy:GetAttribute("arrangeButtons"))
								proxy:Execute(proxy:GetAttribute("arrangePetButtons"))
							end
						end,

						-- Updates whether spells are cast on button press or release.
						-- This cannot be changed in combat, as it requires changing 
						-- a cvar, and not even secure handlers can do that in combat.
						-- It is however queued for combat end, so it still happens after.
						"UpdateCastOnDown", function(self)
							if InCombatLockdown() then 
								return self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateSettings")
							end
							if (event == "PLAYER_REGEN_ENABLED") then 
								self:UnregisterEvent("PLAYER_REGEN_ENABLED", "UpdateSettings")
							end 
							local db = self.db
							for button in self:GetAllActionButtonsOrdered() do
								button:RegisterForClicks(db.castOnDown and "AnyDown" or "AnyUp")
								button:Update()
							end 
						end,

						-- Update actionbutton tooltip display settings.
						"UpdateTooltipSettings", function(self)
							local tooltip = self:GetActionButtonTooltip()
							tooltip.colorNameAsSpellWithUse = true -- color item name as a spell (not by rarity) when it has a Use effect
							tooltip.hideItemLevelWithUse = true -- hide item level when it has a Use effect 
							tooltip.hideStatsWithUseEffect = true -- hide item stats when it has a Use effect
							tooltip.hideBindsWithUseEffect = true -- hide item bind status when it has a Use effect
							tooltip.hideUniqueWithUseEffect = true -- hide item unique status when it has a Use effect
							tooltip.hideEquipTypeWithUseEffect = false -- hide item equip location and item type with Use effect
						end,

						-- This method only sets button parameters, 
						-- the actual keybind display and graphic choices
						-- are done in the button widget in ./schematics-widgets.lua.
						"UpdateKeybindDisplay", function(self)
							local db = self.db
							for button in self:GetAllActionButtonsOrdered() do
								button.padType = self:GetGamepadType()
								button.padStyle = db.gamePadType or "default"

								if (db.keybindDisplayPriority == "gamepad") then
									button.prioritizeGamePadBinds = true
									button.prioritzeKeyboardBinds = nil

								elseif (db.keybindDisplayPriority == "keyboard") then
									button.prioritizeGamePadBinds = nil
									button.prioritzeKeyboardBinds = true
								else
									button.prioritizeGamePadBinds = (db.lastKeybindDisplayType == "gamepad") or self:IsUsingGamepad()
									button.prioritzeKeyboardBinds = true
								end

								if (button.UpdateBinding) then
									button:UpdateBinding()
								end
							end 
						end, 

						-- A general method to update all things at once.
						"UpdateSettings", function(self, event, ...)
							self:UpdateFading()
							self:UpdateFadeAnchors()
							self:UpdateExplorerModeAnchors()
							self:UpdateCastOnDown()
							self:UpdateKeybindDisplay()
							self:UpdateTooltipSettings()
						end
						
					}
				},
				{
					-- The 'chain' sections performs methods on the module,
					-- and passes the unpacked arguments in the tables 
					-- to those methods. An empty table means no arguments.
					-- Here we can call methods created in previously defined
					-- 'values' sections.
					chain = {
						"CreateScaffolds", {},
						"CreateSecureUpdater", {},
						"SpawnActionBars", {},
						"SpawnPetBar", {},
						"SpawnStanceBar", {},
						"SpawnExitButton", {},
						"SpawnTotemBar", {},
						"UpdateButtonLayout", {},
						"UpdateActionButtonBindings", {},
						"UpdateSettings", {}
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
						"RegisterEvent", { "PET_BAR_UPDATE", "OnEvent" },
						"RegisterEvent", { "PLAYER_ENTERING_WORLD", "OnEvent" },
						"RegisterEvent", { "PLAYER_REGEN_ENABLED", "OnEvent" },
						"RegisterEvent", { "PLAYER_REGEN_DISABLED", "OnEvent" },
						"RegisterMessage", { "GP_USING_GAMEPAD", "OnEvent"},
						"RegisterMessage", { "GP_USING_KEYBOARD", "OnEvent"},
						"RegisterMessage", { "GP_FORCED_ACTIONBAR_VISIBILITY_REQUESTED", "OnEvent"},
						"RegisterMessage", { "GP_FORCED_ACTIONBAR_VISIBILITY_CANCELED", "OnEvent"},
						"RegisterEvent", { "UPDATE_BINDINGS", "OnEvent"}
					}
				}
			}
		}

	}
})
