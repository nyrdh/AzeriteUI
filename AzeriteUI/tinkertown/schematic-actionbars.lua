--[[--

	The purpose of this file is to provide
	forges for the actionbar module.
	The idea is to set up methods, values and callbacks 
	here to keep what's in the front-end fully generic.

--]]--
local ADDON, Private = ...

-- Lua API
local _G = _G
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local table_remove = table.remove
local tonumber = tonumber
local tostring = tostring

-- WoW API
local GetTotemTimeLeft = GetTotemTimeLeft
local InCombatLockdown = InCombatLockdown
local IsMounted = IsMounted
local UnitOnTaxi = UnitOnTaxi

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


-- Legacy Schematics
-----------------------------------------------------------
Private.RegisterSchematic("ModuleForge::ActionBars", "Legacy", {
	OnInit = {},
	OnEnable = {}
})

-- Azerite Schematics
-----------------------------------------------------------
Private.RegisterSchematic("ModuleForge::ActionBars", "Azerite", {
	OnInit = {
		{
			type = "ExecuteMethods",
			methods = {
				{
					values = {
						-- Cache of buttons
						"Buttons", {}, -- all action buttons
						"PetButtons", {}, -- all pet buttons
						"HoverButtons", {}, -- all action buttons that can fade out
						"ButtonLookup", {}, -- quickly identify a frame as our button

						-- Secure Code Snippets
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

						-- Update tooltip settings
						"UpdateTooltipSettings", function(self)
							local tooltip = self:GetActionButtonTooltip()
							tooltip.colorNameAsSpellWithUse = true -- color item name as a spell (not by rarity) when it has a Use effect
							tooltip.hideItemLevelWithUse = true -- hide item level when it has a Use effect 
							tooltip.hideStatsWithUseEffect = true -- hide item stats when it has a Use effect
							tooltip.hideBindsWithUseEffect = true -- hide item bind status when it has a Use effect
							tooltip.hideUniqueWithUseEffect = true -- hide item unique status when it has a Use effect
							tooltip.hideEquipTypeWithUseEffect = false -- hide item equip location and item type with Use effect
						end,

						-- Event handler
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
						
							-- ActionButton Template (Custom Methods)
							----------------------------------------------------
							local ActionButtonPostCreate = function(self)
								if (Private.HasSchematic("WidgetForge::ActionButton::Normal")) then
									self:Forge(Private.GetSchematic("WidgetForge::ActionButton::Normal")) 
								end
							end 
						
							-- Private test mode to show all
							local FORCED = false 
						
							local buttonID = 0 -- current buttonID when spawning
							local numPrimary = 7 -- Number of primary buttons always visible
							local firstHiddenID = db.extraButtonsCount + numPrimary -- first buttonID to be hidden
							
							-- Primary Action Bar
							for id = 1,NUM_ACTIONBAR_BUTTONS do 
								buttonID = buttonID + 1
								self.Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButtonPostCreate, id, 1)
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
								self.Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButtonPostCreate, id, BOTTOMLEFT_ACTIONBAR_PAGE)
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
									self.Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButtonPostCreate, id, BOTTOMRIGHT_ACTIONBAR_PAGE)
								end
						
								-- Second Side bar (Right)
								for id = 1,NUM_ACTIONBAR_BUTTONS do 
									buttonID = buttonID + 1
									self.Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButtonPostCreate, id, RIGHT_ACTIONBAR_PAGE)
								end
						
								-- Third Side Bar (Left)
								for id = 1,NUM_ACTIONBAR_BUTTONS do 
									buttonID = buttonID + 1
									self.Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButtonPostCreate, id, LEFT_ACTIONBAR_PAGE)
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
							
							-- PetButton Template (Custom Methods)
							----------------------------------------------------
							local PetButtonPostCreate = function(self)
								if (Private.HasSchematic("WidgetForge::ActionButton::Small")) then
									self:Forge(Private.GetSchematic("WidgetForge::ActionButton::Small")) 
								end
							end 
						
							-- Spawn the Pet Bar
							for id = 1,NUM_PET_ACTION_SLOTS do
								self.PetButtons[id] = self:SpawnActionButton("pet", self.frame, PetButtonPostCreate, id)
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
								elseif IsMounted() then 
									tooltip:AddLine(BINDING_NAME_DISMOUNT)
									tooltip:AddLine(L["%s to dismount."]:format(L["<Left-Click>"]), Colors.quest.green[1], Colors.quest.green[2], Colors.quest.green[3])
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
						"SetForcedVisibility", function(self, force)
							local actionBarHoverFrame = self:GetFadeFrame()
							actionBarHoverFrame.FORCED = force and true
						end,

						-- Updates
						----------------------------------------------------
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

						"UpdateButtonCount", function(self)
							-- Announce the updated button count to the world
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
	OnEnable = {
		{
			type = "ExecuteMethods",
			methods = {
				{
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
