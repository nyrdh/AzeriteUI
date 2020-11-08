--[[--

	The purpose of this file is to provide
	forges for the actionbar module.
	The idea is to set up methods, values and callbacks 
	here to keep what's in the front-end fully generic.

--]]--
local ADDON, Private = ...

-- WoW API

-- Private API
local Colors = Private.Colors
local GetAuraFilter = Private.GetAuraFilter
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia
local GetSchematic = Private.GetSchematic

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
									self:CallMethod("UpdateButtonBindpriority"); 

								elseif (name == "change-gamePadType") then
									self:SetAttribute("gamePadType", value);
									self:CallMethod("UpdateButtonBindpriority"); 

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
								self:UpdateButtonBindpriority()

							elseif (event == "GP_USING_KEYBOARD") then
								self.db.lastKeybindDisplayType = "keyboard"
								self:UpdateButtonBindpriority()

							elseif (event == "PET_BAR_UPDATE") then
								self:UpdateExplorerModeAnchors()
							end
						end, 

						-- This method only sets button parameters, 
						-- the actual keybind display and graphic choices
						-- are done in the button widget in ./schematics-widgets.lua.
						"UpdateButtonBindpriority", function(self)
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
						end
						
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
