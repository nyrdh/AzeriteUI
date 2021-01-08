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

-- Button Constructor Proxies
-----------------------------------------------------------
local Construct_Normal = function(self) self:Forge(GetSchematic("WidgetForge::ActionButton::Normal", "Legacy")) end 
local Construct_Small = function(self) self:Forge(GetSchematic("WidgetForge::ActionButton::Small", "Legacy")) end 
local Construct_Large = function(self) self:Forge(GetSchematic("WidgetForge::ActionButton::Large", "Legacy")) end 

-- Module Schematics
-----------------------------------------------------------
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
						-- Indexed tables where the button is the value.
						"Buttons", {}, -- The key holds no meaning except spawn order here.
						"PrimaryButtons", {}, -- The key in the rest of these are often the button ID.
						"SecondaryButtons", {},
						"SideBarLeftButtons", {},
						"SideBarRightButtons", {},
						"PetButtons", {},
						"VehicleButtons", {},
						"StanceButtons", {},

						-- Lookup table for all buttons with the button as the key.
						"ButtonLookup", {},
						
						-- Secure Code Snippets.
						-- These are used by the menu system and the bars themselves
						-- to update layout and other secure settings even while in combat.
						"secureSnippets", {

							-- Arrange the main and extra actionbar buttons
							arrangeButtons = [=[
								-- Current theme prefix. Use caps.
								local prefix = "Legacy::"; 

								local offsetX, offsetY;
								local primaryWidth = 0;
								local anchor = self:GetFrameRef("AnchorFrame");

								if (PrimaryButtons[1]) then
									-- First pass to decide size of the primary block
									local width, height = 2,0;
									for id,button in ipairs(PrimaryButtons) do 
										local w,h = button:GetWidth(), button:GetHeight();
										if (w and h) then
											width = width + (w-2); -- use additive width
											height = h > height and h or height; -- use largest height
										else 
											return -- bail out if something is missing.
										end
									end

									-- Arrange the primary buttons
									offsetX, offsetY = -width/2,7;
									for id,button in ipairs(PrimaryButtons) do 
										local barID = button:GetFrameRef("Page"):GetID(); 
										local buttonID = button:GetID(); 
										local layoutID = button:GetAttribute("layoutID");
										local w,h = button:GetWidth(), button:GetHeight();
										
										button:ClearAllPoints();
										button:SetPoint("BOTTOMLEFT", anchor, "BOTTOM", offsetX, offsetY);
									
										offsetX = offsetX + (w-2);
									end 

									primaryWidth = width > primaryWidth and width or primaryWidth;
								end

								if (SecondaryButtons[1]) then
									-- First pass to decide size of the secondary block
									local width,height = 2,0;
									for id,button in ipairs(SecondaryButtons) do 
										local w,h = button:GetWidth(), button:GetHeight();
										if (w and h) then
											width = width + (w-2); -- use additive width
											height = h > height and h or height; -- use largest height
										else 
											return -- bail out if something is missing.
										end
									end
	
									-- Arrange the secondary buttons
									offsetX, offsetY = -width/2, 7 + (height-2);
									for id,button in ipairs(SecondaryButtons) do 
										local barID = button:GetFrameRef("Page"):GetID(); 
										local buttonID = button:GetID(); 
										local layoutID = button:GetAttribute("layoutID");
										local w,h = button:GetWidth(), button:GetHeight();
										
										button:ClearAllPoints();
										button:SetPoint("BOTTOMLEFT", anchor, "BOTTOM", offsetX, offsetY);
									
										offsetX = offsetX + (w-2);
									end 

									primaryWidth = width > primaryWidth and width or primaryWidth;
								end

								local enableSecondaryBar = self:GetAttribute(prefix.."enableSecondaryBar");
								local enableSideBarLeft = self:GetAttribute(prefix.."enableSideBarLeft");
								local enableSideBarRight = self:GetAttribute(prefix.."enableSideBarRight");
								local rowWidth = 4; -- width of sidebar blocks in buttons
								
								-- Visibility parents for pull-out bars.
								local LeftFrame = self:GetFrameRef("LeftFrame");
								local RightFrame = self:GetFrameRef("RightFrame");

								local LeftFrameToggle = self:GetFrameRef("LeftFrameToggle");
								local RightFrameToggle = self:GetFrameRef("RightFrameToggle");

								LeftFrameToggle:ClearAllPoints();
								LeftFrameToggle:SetPoint("BOTTOMRIGHT", anchor, "BOTTOM", -primaryWidth/2 -2-8, 7+2);
								LeftFrameToggle:SetWidth(32);
								LeftFrameToggle:SetHeight(50);

								RightFrameToggle:ClearAllPoints();
								RightFrameToggle:SetPoint("BOTTOMLEFT", anchor, "BOTTOM", primaryWidth/2 +8, 7+2);
								RightFrameToggle:SetWidth(32);
								RightFrameToggle:SetHeight(50);

								if (enableSideBarLeft or enableSideBarRight) then
									RightFrameToggle:Show()
									LeftFrameToggle:Show()
								else
									RightFrameToggle:Hide()
									LeftFrameToggle:Hide()
								end

								-- Both sidebars, go for 6x2 layouts
								if (enableSideBarLeft and enableSideBarRight) then

									-- right (first) side bar
									if (SideBarRightButtons[1]) then
										local w,h = SideBarRightButtons[1]:GetWidth(), SideBarRightButtons[1]:GetHeight();
										local offsetX, offsetY = primaryWidth/2 + 20, 7;

										for id,button in ipairs(SideBarRightButtons) do 
											local barID = button:GetFrameRef("Page"):GetID(); 
											local buttonID = button:GetID(); 
											local layoutID = button:GetAttribute("layoutID");
											
											--local x = offsetX + ((id-1)%6)*(w-2);
											--local y = offsetY + (h-2)*((id > 6) and 1 or 0);
											local x = offsetX + ((id-1)%rowWidth)*(w-2);
											local y = offsetY + (h-2)*(math.floor((id-1)/rowWidth));

											button:GetFrameRef("Visibility"):SetParent(RightFrame);
											button:ClearAllPoints();
											button:SetPoint("BOTTOMLEFT", anchor, "BOTTOM", x,y);
										end

										RightFrame:ClearAllPoints();
										RightFrame:SetPoint("BOTTOMLEFT", SideBarRightButtons[1], "BOTTOMLEFT", -8, -8);
										RightFrame:SetPoint("TOPRIGHT", SideBarRightButtons[12], "TOPRIGHT", 8, 8);
									end

									-- left (second) side bar
									if (SideBarLeftButtons[1]) then
										local w,h = SideBarLeftButtons[1]:GetWidth(), SideBarLeftButtons[1]:GetHeight();
										local offsetX, offsetY = -((w-2)*rowWidth + primaryWidth/2 + 2 + 20), 7;

										for id,button in ipairs(SideBarLeftButtons) do 
											local barID = button:GetFrameRef("Page"):GetID(); 
											local buttonID = button:GetID(); 
											local layoutID = button:GetAttribute("layoutID");
											
											--local x = offsetX + ((id-1)%6)*(w-2);
											--local y = offsetY + (h-2)*((id > 6) and 1 or 0);
											local x = offsetX + ((id-1)%rowWidth)*(w-2);
											local y = offsetY + (h-2)*(math.floor((id-1)/rowWidth));

											button:GetFrameRef("Visibility"):SetParent(LeftFrame);
											button:ClearAllPoints();
											button:SetPoint("BOTTOMLEFT", anchor, "BOTTOM", x,y);

											LeftFrame:ClearAllPoints();
											LeftFrame:SetPoint("BOTTOMLEFT", SideBarLeftButtons[1], "BOTTOMLEFT", -8, -8);
											LeftFrame:SetPoint("TOPRIGHT", SideBarLeftButtons[12], "TOPRIGHT", 8, 8);
										end
									end
									

								-- Single sidebar, go for 3x2 layouts
								elseif (enableSideBarLeft or enableSideBarRight) then

									-- Retrieve the correct button table
									local buttons = enableSideBarRight and SideBarRightButtons or SideBarLeftButtons;
									if (buttons[1]) then

										local rowWidth = 3;
										local w,h = buttons[1]:GetWidth(), buttons[1]:GetHeight();
										local offsetXl, offsetYl = -((w-2)*rowWidth + primaryWidth/2 + 2 + 20), 7;
										local offsetXr, offsetYr = primaryWidth/2 + 20, 7;

										local x,y;
										for id,button in ipairs(buttons) do 
											
											if (id > 6) then
												x = offsetXr + ((id-1)%rowWidth)*(w-2);
												y = offsetYr + (h-2)*(math.floor((id-7)/rowWidth));
												button:GetFrameRef("Visibility"):SetParent(RightFrame);
											else
												x = offsetXl + ((id-1)%rowWidth)*(w-2);
												y = offsetYl + (h-2)*(math.floor((id-1)/rowWidth));
												button:GetFrameRef("Visibility"):SetParent(LeftFrame);
											end

											button:ClearAllPoints();
											button:SetPoint("BOTTOMLEFT", anchor, "BOTTOM", x,y);
										end

										LeftFrame:ClearAllPoints();
										LeftFrame:SetPoint("BOTTOMLEFT", buttons[1], "BOTTOMLEFT", -8, -8);
										LeftFrame:SetPoint("TOPRIGHT", buttons[6], "TOPRIGHT", 8, 8);

										RightFrame:ClearAllPoints();
										RightFrame:SetPoint("BOTTOMLEFT", buttons[7], "BOTTOMLEFT", -8, -8);
										RightFrame:SetPoint("TOPRIGHT", buttons[12], "TOPRIGHT", 8, 8);
									end
								end

								-- Post update backdrops
								self:CallMethod("UpdateBackdrops");
							]=],

							-- Arrange the pet action bar buttons.
							arrangePetButtons = [=[
								-- Current theme prefix. Use caps.
								local prefix = "Legacy::"; 

								local w = PetButtons[1] and PetButtons[1]:GetWidth();
								local h = Buttons[1] and Buttons[1]:GetHeight();
								if (not h) or (not w) then
									return
								end
								local anchor = self:GetFrameRef("AnchorFrame");
								local offsetY = h and (11+6 + (h-2)*((self:GetAttribute(prefix.."enableSecondaryBar")) and 2 or 1));
								for id,button in ipairs(PetButtons) do
									button:ClearAllPoints();
									button:SetPoint("BOTTOMLEFT", anchor, "BOTTOM", (id-1)*(w-3)-((w-3)*(5)+1), offsetY);
								end
							]=],

							-- Saved settings changed.
							-- This is called by the options menu after changes and on startup.
							attributeChanged = [=[
								-- Current theme prefix. Use caps.
								local prefix = "Legacy::"; 

								-- 'name' appears to be turned to lowercase by the restricted environment(?), 
								-- but we're doing it manually anyway, just to avoid problems. 
								if (name) then 
									name = string.lower(name); 
									name = name:gsub(string.lower(prefix),""); -- kill off theme prefix
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

								elseif (name == "change-enablesecondarybar") then
									self:SetAttribute(prefix.."enableSecondaryBar", value);

									for i in ipairs(SecondaryButtons) do
										local pager = SecondaryButtons[i]:GetFrameRef("Page"); 
										if (value) then 
											if (not pager:IsShown()) then 
												pager:Show(); 
											end 
										else 
											if (pager:IsShown()) then 
												pager:Hide(); 
											end 
										end 
									end

									self:RunAttribute("arrangeButtons"); 
									self:RunAttribute("arrangePetButtons"); 

									-- tell lua about it
									self:CallMethod("UpdateExplorerModeAnchors");
									self:CallMethod("UpdateButtonCount"); 

								elseif (name == "change-enablesidebarright") then
									self:SetAttribute(prefix.."enableSideBarRight", value);

									for i in ipairs(SideBarRightButtons) do
										local pager = SideBarRightButtons[i]:GetFrameRef("Page"); 
										if (value) then 
											if (not pager:IsShown()) then 
												pager:Show(); 
											end 
										else 
											if (pager:IsShown()) then 
												pager:Hide(); 
											end 
										end 
									end

									self:RunAttribute("arrangeButtons"); 

									-- tell lua about it
									self:CallMethod("UpdateExplorerModeAnchors");
									self:CallMethod("UpdateButtonCount"); 

								elseif (name == "change-enablesidebarleft") then
									self:SetAttribute(prefix.."enableSideBarLeft", value);

									for i in ipairs(SideBarLeftButtons) do
										local pager = SideBarLeftButtons[i]:GetFrameRef("Page"); 
										if (value) then 
											if (not pager:IsShown()) then 
												pager:Show(); 
											end 
										else 
											if (pager:IsShown()) then 
												pager:Hide(); 
											end 
										end 
									end

									self:RunAttribute("arrangeButtons"); 

									-- tell lua about it
									self:CallMethod("UpdateExplorerModeAnchors");
									self:CallMethod("UpdateButtonCount"); 

								elseif (name == "change-enablepetbar") then
									self:SetAttribute(prefix.."enablePetBar", value);
									
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

									self:RunAttribute("arrangePetButtons"); 

									-- tell lua about it
									self:CallMethod("UpdateExplorerModeAnchors");
									self:CallMethod("UpdateButtonCount"); 

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
							local template = BackdropTemplateMixin and "SecureHandlerAttributeTemplate,BackdropTemplate" 
																	or "SecureHandlerAttributeTemplate"
																	
							-- Create master frame. This one becomes secure.
							local frame = self:CreateFrame("Frame", nil, "UICenter", template)
							frame:SetFrameStrata("LOW")
							frame:SetFrameLevel(1)
							frame:SetSize(2,2)
							frame:Place("BOTTOM", "UICenter", "BOTTOM", 2, 28-10)
							self.frame = frame

							-- Create a master frame for the left side pull-out buttons.
							local left = self.frame:CreateFrame("Frame", nil, template)
							left:SetFrameStrata("LOW")
							left:SetFrameLevel(3)
							left:Hide()
							self.left = left

							local leftToggle = self.frame:CreateFrame("CheckButton", nil, "SecureHandlerClickTemplate")
							leftToggle:SetFrameStrata("LOW")
							leftToggle:SetFrameLevel(2)
							leftToggle:SetFrameRef("Window", self.left)
							leftToggle:SetAttribute("_onclick", [=[
								local window = self:GetFrameRef("Window");
								if (window:IsShown()) then
									window:Hide();
								else
									window:Show();
									window:RegisterAutoHide(.75);
									window:AddToAutoHide(self);
								end
							]=])
							leftToggle.tex = leftToggle:CreateTexture()
							leftToggle.tex:SetPoint("CENTER",0,0)
							leftToggle.tex:SetSize(48,96)
							leftToggle.tex:SetTexture(GetMedia("raidtoolsbutton"))
							leftToggle.tex:SetTexCoord(1,0,0,1) -- horizontal flip
							leftToggle.tex:SetDrawLayer("HIGHLIGHT")
							leftToggle.tex:SetAlpha(.5)
							left:SetScript("OnShow", function() leftToggle.tex:Hide() end)
							left:SetScript("OnHide", function() leftToggle.tex:Show() end)
							self.leftToggle = leftToggle

							-- Create a master frame for the right side pull-out buttons.
							local right = self.frame:CreateFrame("Frame", nil, template)
							right:SetFrameStrata("LOW")
							right:SetFrameLevel(3)
							right:Hide()
							self.right = right

							local rightToggle = self.frame:CreateFrame("CheckButton", nil, "SecureHandlerClickTemplate")
							rightToggle:SetFrameStrata("LOW")
							rightToggle:SetFrameLevel(1)
							rightToggle:SetFrameRef("Window", self.right)
							rightToggle:SetAttribute("_onclick", [=[
								local window = self:GetFrameRef("Window");
								if (window:IsShown()) then
									window:Hide();
								else
									window:Show();
									window:RegisterAutoHide(.75);
									window:AddToAutoHide(self);
								end
							]=])
							rightToggle.tex = rightToggle:CreateTexture()
							rightToggle.tex:SetPoint("CENTER",0,0)
							rightToggle.tex:SetSize(48,96)
							rightToggle.tex:SetTexture(GetMedia("raidtoolsbutton"))
							rightToggle.tex:SetDrawLayer("HIGHLIGHT")
							rightToggle.tex:SetAlpha(.5)
							right:SetScript("OnShow", function() rightToggle.tex:Hide() end)
							right:SetScript("OnHide", function() rightToggle.tex:Show() end)
							self.rightToggle = rightToggle

							-- Create overlay frames used for explorer mode.
							self.frameOverlay = self:CreateFrame("Frame", nil, "UICenter")
							self.frameOverlayPet = self:CreateFrame("Frame", nil, "UICenter")
							self.frameOverlayLeft = self:CreateFrame("Frame", nil, "UICenter")
							self.frameOverlayRight = self:CreateFrame("Frame", nil, "UICenter")
						
							-- Apply overlay alpha to the master frame.
							hooksecurefunc(self.frameOverlay, "SetAlpha", function(_,alpha) self.frame:SetAlpha(alpha) end)
						end,

						-- Method to create the backdrops we use to gather 
						-- the various action bars into groups.
						"CreateBackdrops", function(self)
							local frame = self.frame
							local backdrops = { 
								primary = frame:CreateFrame("Frame", BackdropTemplateMixin and "BackdropTemplate"), 
								vehicle = frame:CreateFrame("Frame", BackdropTemplateMixin and "BackdropTemplate"), 
								left = frame:CreateFrame("Frame", BackdropTemplateMixin and "BackdropTemplate"), 
								right = frame:CreateFrame("Frame", BackdropTemplateMixin and "BackdropTemplate") 
							}
							for i,backdrop in pairs(backdrops) do
								backdrop:SetFrameStrata("LOW")
								backdrop:SetFrameLevel(1)
								backdrop:SetBackdrop({
									bgFile = [[Interface\ChatFrame\ChatFrameBackground]], tile = false,
									edgeFile = GetMedia("tooltip_border_hex"), edgeSize = 32, 
									insets = { top = 10.5, bottom = 10.5, left = 10.5, right = 10.5 }
								})
								backdrop:SetBackdropColor(0, 0, 0, .75)
								backdrop:SetBackdropBorderColor(Colors.ui[1], Colors.ui[2], Colors.ui[3])
							end
							self.backdrops = backdrops
						end,

						-- Method to create the secure callback frame for the menu system.
						"CreateSecureUpdater", function(self)
							local OptionsMenu = self:GetOwner():GetModule("OptionsMenu", true)
							if (OptionsMenu) then

								local callbackFrame = OptionsMenu:CreateCallbackFrame(self)

								-- Assign settings and proxies for module updates
								callbackFrame:AssignSettings(self.db)
								callbackFrame:AssignProxyMethods(
									"UpdateBackdrops",
									"UpdateButtonCount", 
									"UpdateCastOnDown", 
									"UpdateExplorerModeAnchors", 
									"UpdateKeybindDisplay"
								)
								-- Create tables to hold the buttons
								-- within the restricted environment.
								callbackFrame:Execute([=[ 
									Buttons = table.new();
									PrimaryButtons = table.new();
									SecondaryButtons = table.new();
									SideBarLeftButtons = table.new();
									SideBarRightButtons = table.new();
									PetButtons = table.new();
									StanceButtons = table.new();
									Pagers = table.new();
									PetPagers = table.new();
								]=])
		
								-- Apply references and attributes used for updates.
								callbackFrame:SetFrameRef("AnchorFrame", self.frame)
								callbackFrame:SetFrameRef("LeftFrame", self.left)
								callbackFrame:SetFrameRef("LeftFrameToggle", self.leftToggle)
								callbackFrame:SetFrameRef("RightFrame", self.right)
								callbackFrame:SetFrameRef("RightFrameToggle", self.rightToggle)
								callbackFrame:AssignAttributes(
									"arrangeButtons", self.secureSnippets.arrangeButtons,
									"arrangePetButtons", self.secureSnippets.arrangePetButtons
								)
					
								-- Assign the menu system's callback on changed settings.
								callbackFrame:AssignCallback(self.secureSnippets.attributeChanged)
							end
						end, 

						-- Updates the position of the various backdrops.
						-- This is needed after most bar visibility changes.
						"UpdateBackdrops", function(self)

							local primary = self.backdrops.primary
							primary:SetParent(self.Buttons[1])
							primary:SetFrameStrata("LOW")
							primary:SetFrameLevel(1)
							primary:ClearAllPoints()
							primary:SetPoint("BOTTOMLEFT", self.Buttons[1], -10, -7)
							primary:SetPoint("TOPRIGHT", self.Buttons[(self:GetDB("enableSecondaryBar")) and 24 or 12], 10, 7)

							local vehicle = self.backdrops.vehicle
							vehicle:SetParent(self.VehicleButtons[1])
							vehicle:SetFrameStrata("LOW")
							vehicle:SetFrameLevel(1)
							vehicle:ClearAllPoints()
							vehicle:SetPoint("BOTTOMLEFT", self.VehicleButtons[1], -10, -7)
							vehicle:SetPoint("TOPRIGHT", self.VehicleButtons[#self.VehicleButtons], 10, 7)

							local enableSideBarLeft = self:GetDB("enableSideBarLeft")
							local enableSideBarRight = self:GetDB("enableSideBarRight")
							local left = self.backdrops.left
							local right = self.backdrops.right

							if (enableSideBarRight and enableSideBarLeft) then
								left:SetParent(self.SideBarLeftButtons[1])
								left:SetFrameStrata("LOW")
								left:SetFrameLevel(1)
								left:ClearAllPoints()
								left:SetPoint("BOTTOMLEFT", self.SideBarLeftButtons[1], -10, -7)
								left:SetPoint("TOPRIGHT", self.SideBarLeftButtons[#self.SideBarLeftButtons], 10, 7)

								right:SetParent(self.SideBarRightButtons[1])
								right:SetFrameStrata("LOW")
								right:SetFrameLevel(1)
								right:ClearAllPoints()
								right:SetPoint("BOTTOMLEFT", self.SideBarRightButtons[1], -10, -7)
								right:SetPoint("TOPRIGHT", self.SideBarRightButtons[#self.SideBarRightButtons], 10, 7)

							elseif (enableSideBarLeft or enableSideBarRight) then

								local buttons = enableSideBarLeft and self.SideBarLeftButtons or self.SideBarRightButtons

								left:SetParent(buttons[1])
								left:SetFrameStrata("LOW")
								left:SetFrameLevel(1)
								left:ClearAllPoints()
								left:SetPoint("BOTTOMLEFT", buttons[1], -10, -7)
								left:SetPoint("TOPRIGHT", buttons[6], 10, 7)

								right:SetParent(buttons[7])
								right:SetFrameStrata("LOW")
								right:SetFrameLevel(1)
								right:ClearAllPoints()
								right:SetPoint("BOTTOMLEFT", buttons[7], -10, -7)
								right:SetPoint("TOPRIGHT", buttons[12], 10, 7)

							end

						end,

						-- Spawns the primary action bar, 
						-- which holds the default 12 buttons.
						-- This is the bar that page switches.
						"SpawnPrimaryBar", function(self)
							local db = self.db
							local proxy = self:GetSecureUpdater()
							local frame = self.frame

							for id = 1,NUM_ACTIONBAR_BUTTONS do 
								self.buttonID = (self.buttonID or 0) + 1

								local button = self:SpawnActionButton("action", self.frame, Construct_Normal, id, 1)
								button:SetAttribute("layoutID", self.buttonID)
								button:SetAttribute("buttonLock", db.buttonLock)
								button.overrideAlphaWhenEmpty = 1

								-- Link the buttons and their pagers 
								-- and reference all buttons in our menu callback frame
								proxy:SetFrameRef("Button"..self.buttonID, button)
								proxy:SetFrameRef("Pager"..self.buttonID, button:GetPager())
								proxy:Execute(([=[
									table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
									table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
									table.insert(PrimaryButtons, self:GetFrameRef("Button"..%.0f)); 
								]=]):format(self.buttonID, self.buttonID, self.buttonID))
								
								-- Let's put on a special visibility driver 
								-- that hides these buttons in vehicles, and in taxis.
								UnregisterAttributeDriver(button:GetVisibilityDriverFrame(), "state-vis")
								RegisterAttributeDriver(button:GetVisibilityDriverFrame(), "state-vis", "[canexitvehicle,novehicleui][vehicleui][overridebar][possessbar][shapeshift]hide;[@player,exists]show;hide")

								-- Button cache
								self.Buttons[self.buttonID] = button
								self.PrimaryButtons[id] = button

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
							local db = self.db
							local proxy = self:GetSecureUpdater()

							for id = 1,NUM_ACTIONBAR_BUTTONS do 
								self.buttonID = (self.buttonID or 0) + 1

								local button = self:SpawnActionButton("action", self.frame, Construct_Normal, id, BOTTOMLEFT_ACTIONBAR_PAGE)

								button:SetAttribute("layoutID", self.buttonID)
								button:SetAttribute("buttonLock", db.buttonLock)
								button.overrideAlphaWhenEmpty = 1

								if (not self:GetDB("enableSecondaryBar")) then
									button:GetPager():Hide()
								end

								-- Link the buttons and their pagers 
								-- and reference all buttons in our menu callback frame
								proxy:SetFrameRef("Button"..self.buttonID, button)
								proxy:SetFrameRef("Pager"..self.buttonID, button:GetPager())
								proxy:Execute(([=[
									table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
									table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
									table.insert(SecondaryButtons, self:GetFrameRef("Button"..%.0f)); 
								]=]):format(self.buttonID, self.buttonID, self.buttonID))
								
								-- Let's put on a special visibility driver 
								-- that hides these buttons in vehicles, and in taxis.
								UnregisterAttributeDriver(button:GetVisibilityDriverFrame(), "state-vis")
								RegisterAttributeDriver(button:GetVisibilityDriverFrame(), "state-vis", "[canexitvehicle,novehicleui][vehicleui][overridebar][possessbar][shapeshift]hide;[@player,exists]show;hide")

								-- Button cache
								self.Buttons[self.buttonID] = button
								self.SecondaryButtons[id] = button

								-- Faster lookups
								self.ButtonLookup[button] = true
							end
						end,

						-- Spawn the side bars, which are the same sidebars as the default ones.
						-- When both are enabled we display them as 6x2 blocks on each side of the primary bars,
						-- and when just a single sidebar is enabled, not matter which, we display it as a
						-- split bar, with each 3x2 half on each side of the primary action bar block. 
						"SpawnSideBars", function(self)
							local db = self.db
							local proxy = self:GetSecureUpdater()
 
							for i,barID in ipairs({ RIGHT_ACTIONBAR_PAGE, LEFT_ACTIONBAR_PAGE }) do
								for id = 1,NUM_ACTIONBAR_BUTTONS do
									self.buttonID = (self.buttonID or 0) + 1

									local button = self:SpawnActionButton("action", self.frame, Construct_Small, id, barID)
									button:SetAttribute("buttonLock", db.buttonLock)
									button.overrideAlphaWhenEmpty = 1
		
									-- Link the buttons and their pagers 
									-- and reference all buttons in our menu callback frame
									proxy:SetFrameRef("Button"..self.buttonID, button)
									proxy:SetFrameRef("Pager"..self.buttonID, button:GetPager())

									if (barID == RIGHT_ACTIONBAR_PAGE) then 
										proxy:Execute(([=[
											table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
											table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
											table.insert(SideBarRightButtons, self:GetFrameRef("Button"..%.0f));
										]=]):format(self.buttonID, self.buttonID, self.buttonID))

									elseif (barID == LEFT_ACTIONBAR_PAGE) then
										proxy:Execute(([=[
											table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
											table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
											table.insert(SideBarLeftButtons, self:GetFrameRef("Button"..%.0f));
										]=]):format(self.buttonID, self.buttonID, self.buttonID))
									end

									-- Let's put on a special visibility driver 
									-- that hides these buttons in vehicles, and in taxis.
									UnregisterAttributeDriver(button:GetVisibilityDriverFrame(), "state-vis")
									RegisterAttributeDriver(button:GetVisibilityDriverFrame(), "state-vis", "[canexitvehicle,novehicleui][vehicleui][overridebar][possessbar][shapeshift]hide;[@player,exists]show;hide")

									-- Button caches
									self.Buttons[self.buttonID] = button
									if (barID == RIGHT_ACTIONBAR_PAGE) then 
										self.SideBarRightButtons[id] = button
									elseif (barID == LEFT_ACTIONBAR_PAGE) then
										self.SideBarLeftButtons[id] = button
									end

									-- Faster lookups
									self.ButtonLookup[button] = true
								end
							end

						end,

						-- Spawns the pet action bar.
						"SpawnPetBar", function(self)
							local db = self.db
							local proxy = self:GetSecureUpdater()

							for id = 1,NUM_PET_ACTION_SLOTS do 
								self.buttonID = (self.buttonID or 0) + 1

								local button = self:SpawnActionButton("pet", self.frame, Construct_Small, id)
								button:SetAttribute("buttonLock", db.buttonLock)
								button.overrideAlphaWhenEmpty = 1

								if (not self:GetDB("enablePetBar")) then
									button:GetPager():Hide()
								end

								-- Link the buttons and their pagers 
								-- and reference all buttons in our menu callback frame
								proxy:SetFrameRef("PetButton"..id, button)
								proxy:SetFrameRef("PetPager"..id, button:GetPager())
								proxy:Execute(([=[
									table.insert(PetButtons, self:GetFrameRef("PetButton"..%.0f)); 
									table.insert(PetPagers, self:GetFrameRef("PetPager"..%.0f)); 
								]=]):format(id, id))

								-- Let's put on a special visibility driver 
								-- that hides these buttons in vehicles, and in taxis.
								UnregisterAttributeDriver(button:GetVisibilityDriverFrame(), "state-vis")
								RegisterAttributeDriver(button:GetVisibilityDriverFrame(), "state-vis", "[canexitvehicle,novehicleui][vehicleui][overridebar][possessbar][shapeshift]hide;[@pet,exists]show;hide")

								-- Button cache
								self.Buttons[self.buttonID] = button
								self.PetButtons[id] = button

								-- Faster lookups
								self.ButtonLookup[button] = true
							end
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

							-- Primary Action Bar
							for id = 1,6 do 
								self.buttonID = (self.buttonID or 0) + 1

								local button = self:SpawnActionButton("action", self.frame, Construct_Large, id, 1)
								button:SetAttribute("layoutID", self.buttonID)
								button:SetAttribute("buttonLock", true)
								button.overrideAlphaWhenEmpty = 1
								
								local w,h = button:GetSize()
								button:Place("BOTTOMLEFT", self.frame, "BOTTOM", (id-1)*(w-2)-((w-2)*3+1), 7)

								-- Link the buttons and their pagers 
								-- and reference all buttons in our menu callback frame
								proxy:SetFrameRef("Button"..self.buttonID, button)
								proxy:SetFrameRef("Pager"..self.buttonID, button:GetPager())
								proxy:Execute(([=[
									table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
									table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
								]=]):format(self.buttonID, self.buttonID))
								
								-- Let's put on a special visibility driver 
								-- that hides these buttons in vehicles, and on taxis.
								--local visibilityDriver = "[canexitvehicle,novehicleui,nooverridebar,nopossessbar,noshapeshift]hide;[overridebar][possessbar][shapeshift][vehicleui]show;hide"
								local visibilityDriver = "[canexitvehicle,novehicleui,nooverridebar,nopossessbar,noshapeshift]hide;[overridebar][possessbar][shapeshift][vehicleui]show;hide"
								UnregisterAttributeDriver(button:GetVisibilityDriverFrame(), "state-vis")
								RegisterAttributeDriver(button:GetVisibilityDriverFrame(), "state-vis", visibilityDriver)

								-- Button caches
								self.Buttons[self.buttonID] = button
								self.VehicleButtons[id] = button

								-- Faster lookups
								self.ButtonLookup[button] = true
							end

						end,

						-- Does nothing yet. 
						-- Shape, form and implementation to be decided!
						"SpawnStanceBar", function(self)
						end,
						
						-- Spawns the totem bar used for retail temporary "totems",
						-- which include a multitude of things like death knight ghouls,
						-- shaman ghost wolves, druid mushrooms and so on.
						-- Blizzard decides what goes into these, 
						-- and we're actually just restyling the blizzard buttons, 
						-- as there is no API in existence except the blizzard buttons
						-- that allows us to cancel existing totems. 
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
							totemHolderFrame:Place("BOTTOM", self:GetFrame("Minimap"), "TOP", 0, 36)
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
								elseif (IsRetail) and (IsPossessBarVisible() and PetCanBeDismissed()) then
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
							return 	self:GetPrimaryOverlayFrame(), 
									self:GetPetOverlayFrame(),
									self:GetSideBarLeftOverlayFrame(),
									self:GetSideBarRightOverlayFrame()
						end,

						-- Return the actionbar overlay frame for the explorer mode mouseover
						"GetPrimaryOverlayFrame", function(self)
							return self.frameOverlay
						end,

						-- Return the pet actionbar overlay frame for the explorer mode mouseover
						"GetPetOverlayFrame", function(self)
							return self.frameOverlayPet
						end,

						-- Return the left actionbar overlay frame for the explorer mode mouseover
						"GetSideBarLeftOverlayFrame", function(self)
							return self.frameOverlayLeft
						end,

						-- Return the right actionbar overlay frame for the explorer mode mouseover
						"GetSideBarRightOverlayFrame", function(self)
							return self.frameOverlayRight
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

							local primary = self:GetPrimaryOverlayFrame()
							local pet = self:GetPetOverlayFrame()
							local left = self:GetSideBarLeftOverlayFrame()
							local right = self:GetSideBarRightOverlayFrame()

							local enableSecondaryBar = self:GetDB("enableSecondaryBar")
							local enableSideBarLeft = self:GetDB("enableSideBarLeft")
							local enableSideBarRight = self:GetDB("enableSideBarRight")
							local enablePetBar = self:GetDB("enablePetBar")

							local offsetX, offsetY = (enableSideBarLeft or enableSideBarRight) and 32 or 8,8

							if (enableSecondaryBar) then
								primary:Place("BOTTOMLEFT", self.PrimaryButtons[1], "BOTTOMLEFT", -offsetX, -offsetY)
								primary:SetPoint("TOPRIGHT", self.SecondaryButtons[#self.SecondaryButtons], "TOPRIGHT", offsetX, offsetY)
							else
								primary:Place("BOTTOMLEFT", self.PrimaryButtons[1], "BOTTOMLEFT", -offsetX, -offsetY)
								primary:SetPoint("TOPRIGHT", self.PrimaryButtons[#self.PrimaryButtons], "TOPRIGHT", offsetX, offsetY)
							end

							-- Dodgy. Need a callback for pets here instead.
							local enablePetBarHover
							if (enablePetBar) then
								for id,button in pairs(self.PetButtons) do
									if (button:IsShown()) then
										enablePetBarHover = true
										break
									end
								end
							end
							if (enablePetBarHover) then
								pet:Place("TOPLEFT", self.PetButtons[1], "TOPLEFT", 0, 0)
								pet:SetPoint("BOTTOMRIGHT", self.PetButtons[#self.PetButtons], "BOTTOMRIGHT", 0, 0)
								pet:Show()
							else
								pet:Hide()
							end

							offsetX, offsetY = 8,8
							if (enableSideBarLeft) and (enableSideBarRight) then

								left:SetParent(self.SideBarLeftButtons[1])
								left:Place("BOTTOMLEFT", self.SideBarLeftButtons[1], "BOTTOMLEFT", -offsetX, -offsetY)
								left:SetPoint("TOPRIGHT", self.SideBarLeftButtons[12], "TOPRIGHT", offsetX, offsetY)
								left:Show()

								right:SetParent(self.SideBarRightButtons[1])
								right:Place("BOTTOMLEFT", self.SideBarRightButtons[1], "BOTTOMLEFT", -offsetX, -offsetY)
								right:SetPoint("TOPRIGHT", self.SideBarRightButtons[12], "TOPRIGHT", offsetX, offsetY)
								right:Show()


							elseif (enableSideBarLeft) or (enableSideBarRight) then
								local buttons = enableSideBarRight and self.SideBarRightButtons or self.SideBarLeftButtons;

								left:SetParent(buttons[1])
								right:SetParent(buttons[7])

								left:Place("BOTTOMLEFT", buttons[1], "BOTTOMLEFT", -offsetX, -offsetY)
								left:SetPoint("TOPRIGHT", buttons[6], "TOPRIGHT", offsetX, offsetY)
								left:Show()

								right:Place("BOTTOMLEFT", buttons[7], "BOTTOMLEFT", -offsetX, -offsetY)
								right:SetPoint("TOPRIGHT", buttons[12], "TOPRIGHT", offsetX, offsetY)
								right:Show()
							else
								left:Hide()
								right:Hide()
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
						-- Embed libraries on the fly.
						-- Doing it this way allows the theme to
						-- only request and load what is actually used.
						"EmbedLibraries", { "LibEvent", "LibFrame", "LibInputMethod", "LibMessage", "LibSecureButton", "LibTooltip" },
						-- Create scaffolds and root frames
						"CreateScaffolds", {},
						"CreateBackdrops", {},
						"CreateSecureUpdater", {},
						-- Spawn the various buttons
						"SpawnPrimaryBar", {},
						"SpawnSecondaryBar", {},
						"SpawnSideBars", {},
						"SpawnVehicleBar", {},
						"SpawnPetBar", {},
						"SpawnStanceBar", {},
						"SpawnExitButton", {},
						"SpawnTotemBar", {},
						-- Initial updates of elements
						"UpdateBackdrops", {}, 
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
