local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Note that there's still a lot of hardcoded things in this file,
-- and they will most likely NOT be moved into the layout, 
-- as bar layouts in our UIs are very non-typical,
-- and more often than not iconic, integral elements of the design.
local L = Wheel("LibLocale"):GetLocale(ADDON)
local Module = Core:NewModule("ActionBarMain", "LibEvent", "LibMessage", "LibDB", "LibFrame", "LibSound", "LibTooltip", "LibSecureButton", "LibWidgetContainer", "LibPlayerData", "LibClientBuild", "LibForge", "LibInputMethod")

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
local GetConfig = Private.GetConfig
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout
local GetMedia = Private.GetMedia

-- Constants for client version
local IsClassic = Module:IsClassic()
local IsRetail = Module:IsRetail()

-- Cache of buttons
local Buttons = {} -- all action buttons
local PetButtons = {} -- all pet buttons
local HoverButtons = {} -- all action buttons that can fade out
local ButtonLookup = {} -- quickly identify a frame as our button

-- Hover frames
-- *Not related to the explorer mode.
local ActionBarHoverFrame, PetBarHoverFrame
local FadeOutHZ, FadeOutDuration = 1/20, 1/5

-- Time constants
local DAY, HOUR, MINUTE = 86400, 3600, 60

-- Aimed to be compact and displayed on buttons
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

-- ActionButton Template (Custom Methods)
----------------------------------------------------
local ActionButtonPostCreate = function(self)
	if (Private.HasSchematic("WidgetForge::ActionButton::Normal")) then
		self:Forge(Private.GetSchematic("WidgetForge::ActionButton::Normal")) 
	end
end 

-- PetButton Template (Custom Methods)
----------------------------------------------------
local PetButtonPostCreate = function(self)
	if (Private.HasSchematic("WidgetForge::ActionButton::Small")) then
		self:Forge(Private.GetSchematic("WidgetForge::ActionButton::Small")) 
	end
end 

-- Bar Creation
----------------------------------------------------
Module.SpawnActionBars = function(self)
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
		Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButtonPostCreate, id, 1)
		HoverButtons[Buttons[buttonID]] = buttonID > numPrimary

		-- Experimental code to see if I could make an attribute
		-- driver changing buttonID based on modifier keys.
		-- Short answer? I could.
		if (false) then
			local button = Buttons[buttonID]
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
		Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButtonPostCreate, id, BOTTOMLEFT_ACTIONBAR_PAGE)
		HoverButtons[Buttons[buttonID]] = true
	end 

	-- Layout helper
	for buttonID,button in pairs(Buttons) do
		button:SetAttribute("layoutID",buttonID)
	end
	
	-- First Side Bar (Bottom Right)
	if (false) then
		for id = 1,NUM_ACTIONBAR_BUTTONS do 
			buttonID = buttonID + 1
			Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButtonPostCreate, id, BOTTOMRIGHT_ACTIONBAR_PAGE)
		end

		-- Second Side bar (Right)
		for id = 1,NUM_ACTIONBAR_BUTTONS do 
			buttonID = buttonID + 1
			Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButtonPostCreate, id, RIGHT_ACTIONBAR_PAGE)
		end

		-- Third Side Bar (Left)
		for id = 1,NUM_ACTIONBAR_BUTTONS do 
			buttonID = buttonID + 1
			Buttons[buttonID] = self:SpawnActionButton("action", self.frame, ActionButtonPostCreate, id, LEFT_ACTIONBAR_PAGE)
		end
	end

	-- Apply common settings to the action buttons.
	for buttonID,button in ipairs(Buttons) do 

		-- Identify it easily.
		ButtonLookup[button] = true

		-- Apply saved buttonLock setting
		button:SetAttribute("buttonLock", db.buttonLock)

		-- Link the buttons and their pagers 
		proxy:SetFrameRef("Button"..buttonID, Buttons[buttonID])
		proxy:SetFrameRef("Pager"..buttonID, Buttons[buttonID]:GetPager())

		-- Reference all buttons in our menu callback frame
		proxy:Execute(([=[
			table.insert(Buttons, self:GetFrameRef("Button"..%.0f)); 
			table.insert(Pagers, self:GetFrameRef("Pager"..%.0f)); 
		]=]):format(buttonID, buttonID))

		-- Hide buttons beyond our current maximum visible
		if (HoverButtons[button] and (buttonID > firstHiddenID)) then 
			button:GetPager():Hide()
		end 
	end 
end

Module.SpawnPetBar = function(self)
	local db = self.db
	local proxy = self:GetSecureUpdater()
	
	-- Spawn the Pet Bar
	for id = 1,NUM_PET_ACTION_SLOTS do
		PetButtons[id] = self:SpawnActionButton("pet", self.frame, PetButtonPostCreate, id)
	end

	-- Apply common stuff to the pet buttons
	for id,button in pairs(PetButtons) do

		-- Identify it easily.
		ButtonLookup[button] = true

		-- Apply saved buttonLock setting
		button:SetAttribute("buttonLock", db.buttonLock)

		-- Link the buttons and their pagers 
		proxy:SetFrameRef("PetButton"..id, PetButtons[id])
		proxy:SetFrameRef("PetPager"..id, PetButtons[id]:GetPager())

		if (not db.petBarEnabled) then
			PetButtons[id]:GetPager():Hide()
		end
		
		-- Reference all buttons in our menu callback frame
		proxy:Execute(([=[
			table.insert(PetButtons, self:GetFrameRef("PetButton"..%.0f)); 
			table.insert(PetPagers, self:GetFrameRef("PetPager"..%.0f)); 
		]=]):format(id, id))
		
	end
end

Module.SpawnStanceBar = function(self)
end

-- Hardcoded stuff here. Work in progress.
Module.SpawnTotemBar = function(self)
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
end

Module.SpawnExitButton = function(self)
	local layout = self.layout

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
end

-- Getters
----------------------------------------------------
-- Return an iterator for actionbar buttons
Module.GetButtons = function(self)
	return pairs(Buttons)
end

-- Return an iterator for pet actionbar buttons
Module.GetPetButtons = function(self)
	return pairs(PetButtons)
end

-- Return the frames for the explorer mode mouseover
Module.GetExplorerModeFrameAnchors = function(self)
	return self:GetOverlayFrame(), self:GetOverlayFramePet()
end

-- Return the actionbar frame for the explorer mode mouseover
Module.GetOverlayFrame = function(self)
	return self.frameOverlay
end

-- Return the pet actionbar frame for the explorer mode mouseover
Module.GetOverlayFramePet = function(self)
	return self.frameOverlayPet
end

-- Return the frame for actionbutton mouseover fading
Module.GetFadeFrame = function(self)
	if (not ActionBarHoverFrame) then 
		ActionBarHoverFrame = self:CreateFrame("Frame")
		ActionBarHoverFrame.timeLeft = 0
		ActionBarHoverFrame.elapsed = 0
		ActionBarHoverFrame:SetScript("OnUpdate", function(self, elapsed) 
			self.elapsed = self.elapsed + elapsed
			self.timeLeft = self.timeLeft - elapsed
	
			if (self.timeLeft <= 0) then
				if FORCED or self.FORCED or self.always or (self.incombat and Module.inCombat) or self.forced or self.flyout or self:IsMouseOver(0,0,0,0) then
					if (not self.isMouseOver) then 
						self.isMouseOver = true
						self.alpha = 1
						for id = 8,24 do 
							Buttons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end 
				else 
					if (self.isMouseOver) then 
						self.isMouseOver = nil
						if (not self.fadeOutTime) then 
							self.fadeOutTime = FadeOutDuration
						end 
					end 
					if (self.fadeOutTime) then 
						self.fadeOutTime = self.fadeOutTime - self.elapsed
						if (self.fadeOutTime > 0) then 
							self.alpha = self.fadeOutTime / FadeOutDuration
						else 
							self.alpha = 0
							self.fadeOutTime = nil
						end 
						for id = 8,24 do 
							Buttons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end 
				end 
				self.elapsed = 0
				self.timeLeft = FadeOutHZ
			end 
		end) 

		local actionBarGrid, petBarGrid, buttonLock
		ActionBarHoverFrame:SetScript("OnEvent", function(self, event, ...) 
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

		hooksecurefunc("ActionButton_UpdateFlyout", function(self) 
			if (HoverButtons[self]) then 
				ActionBarHoverFrame.flyout = self:IsFlyoutShown()
			end
		end)

		ActionBarHoverFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
		ActionBarHoverFrame:RegisterEvent("ACTIONBAR_SHOWGRID")

		-- We're showing the button slots while holding a pet action in retail,
		-- since pet actions can be placed on regular action buttons here.
		-- This is not the case in classic.
		if (IsRetail) then
			ActionBarHoverFrame:RegisterEvent("PET_BAR_HIDEGRID")
			ActionBarHoverFrame:RegisterEvent("PET_BAR_SHOWGRID")
		end

		ActionBarHoverFrame.isMouseOver = true -- Set this to initiate the first fade-out
	end
	return ActionBarHoverFrame
end

-- Return the frame for pet actionbutton mouseover fading
Module.GetFadeFramePet = function(self)
	if (not PetBarHoverFrame) then
		PetBarHoverFrame = self:CreateFrame("Frame")
		PetBarHoverFrame.timeLeft = 0
		PetBarHoverFrame.elapsed = 0
		PetBarHoverFrame:SetScript("OnUpdate", function(self, elapsed) 
			self.elapsed = self.elapsed + elapsed
			self.timeLeft = self.timeLeft - elapsed
	
			if (self.timeLeft <= 0) then
				if FORCED or self.FORCED or self.always or (self.incombat and Module.inCombat) or self.forced or self.flyout or self:IsMouseOver(0,0,0,0) then
					if (not self.isMouseOver) then 
						self.isMouseOver = true
						self.alpha = 1
						for id in pairs(PetButtons) do
							PetButtons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end
				else 
					if (self.isMouseOver) then 
						self.isMouseOver = nil
						if (not self.fadeOutTime) then 
							self.fadeOutTime = FadeOutDuration
						end 
					end 
					if (self.fadeOutTime) then 
						self.fadeOutTime = self.fadeOutTime - self.elapsed
						if (self.fadeOutTime > 0) then 
							self.alpha = self.fadeOutTime / FadeOutDuration
						else 
							self.alpha = 0
							self.fadeOutTime = nil
						end 
						for id in pairs(PetButtons) do
							PetButtons[id]:GetPager():SetAlpha(self.alpha)
						end 
					end 
				end 
				self.elapsed = 0
				self.timeLeft = FadeOutHZ
			end 
		end) 

		PetBarHoverFrame:SetScript("OnEvent", function(self, event, ...) 
			if (event == "PET_BAR_SHOWGRID") then 
				self.forced = true
			elseif (event == "PET_BAR_HIDEGRID") or (event == "buttonLock") then
				self.forced = nil
			end 
		end)


		PetBarHoverFrame:RegisterEvent("PET_BAR_SHOWGRID")
		PetBarHoverFrame:RegisterEvent("PET_BAR_HIDEGRID")
		PetBarHoverFrame.isMouseOver = true -- Set this to initiate the first fade-out
	end
	return PetBarHoverFrame
end

-- Setters
----------------------------------------------------
Module.SetForcedVisibility = function(self, force)
	local actionBarHoverFrame = self:GetFadeFrame()
	actionBarHoverFrame.FORCED = force and true
end

-- Updates
----------------------------------------------------
Module.UpdateFading = function(self)
	local db = self.db

	-- Set action bar hover settings
	local actionBarHoverFrame = self:GetFadeFrame()
	actionBarHoverFrame.incombat = db.extraButtonsVisibility == "combat"
	actionBarHoverFrame.always = db.extraButtonsVisibility == "always"

	-- We're hardcoding these until options can be added
	local petBarHoverFrame = self:GetFadeFramePet()
	petBarHoverFrame.incombat = db.petBarVisibility == "combat"
	petBarHoverFrame.always = db.petBarVisibility == "always"
end 

Module.UpdateExplorerModeAnchors = function(self)
	local db = self.db
	local frame = self:GetOverlayFramePet()
	if (self.db.petBarEnabled) and (UnitExists("pet")) then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", PetButtons[1], "TOPLEFT")
		frame:SetPoint("BOTTOMRIGHT", PetButtons[10], "BOTTOMRIGHT")
	else
		frame:ClearAllPoints()
		frame:SetAllPoints(self:GetFrame())
	end
end

Module.UpdateFadeAnchors = function(self)
	local db = self.db

	-- Parse buttons for hoverbutton IDs
	local first, last, left, right, top, bottom, mLeft, mRight, mTop, mBottom
	for id,button in ipairs(Buttons) do 
		-- If we pass number of visible hoverbuttons, just bail out
		if (id > db.extraButtonsCount + 7) then 
			break 
		end 

		local bLeft = button:GetLeft()
		local bRight = button:GetRight()
		local bTop = button:GetTop()
		local bBottom = button:GetBottom()
		
		if HoverButtons[button] then 
			-- Only counting the first encountered as the first
			if (not first) then 
				first = id 
			end 

			-- Counting every button as the last, until we actually reach it 
			last = id 

			-- Figure out hoverframe anchor buttons
			left = left and (Buttons[left]:GetLeft() < bLeft) and left or id
			right = right and (Buttons[right]:GetRight() > bRight) and right or id
			top = top and (Buttons[top]:GetTop() > bTop) and top or id
			bottom = bottom and (Buttons[bottom]:GetBottom() < bBottom) and bottom or id
		end 

		-- Figure out main frame anchor buttons, 
		-- as we need this for the explorer mode fade anchors!
		mLeft = mLeft and (Buttons[mLeft]:GetLeft() < bLeft) and mLeft or id
		mRight = mRight and (Buttons[mRight]:GetRight() > bRight) and mRight or id
		mTop = mTop and (Buttons[mTop]:GetTop() > bTop) and mTop or id
		mBottom = mBottom and (Buttons[mBottom]:GetBottom() < bBottom) and mBottom or id
	end 

	-- Setup main frame anchors for explorer mode! 
	local overlayFrame = self:GetOverlayFrame()
	overlayFrame:ClearAllPoints()
	overlayFrame:SetPoint("TOP", Buttons[mTop], "TOP", 0, 0)
	overlayFrame:SetPoint("BOTTOM", Buttons[mBottom], "BOTTOM", 0, 0)
	overlayFrame:SetPoint("LEFT", Buttons[mLeft], "LEFT", 0, 0)
	overlayFrame:SetPoint("RIGHT", Buttons[mRight], "RIGHT", 0, 0)

	-- If we have hoverbuttons, setup the anchors
	if (left and right and top and bottom) then 
		local actionBarHoverFrame = self:GetFadeFrame()
		actionBarHoverFrame:ClearAllPoints()
		actionBarHoverFrame:SetPoint("TOP", Buttons[top], "TOP", 0, 0)
		actionBarHoverFrame:SetPoint("BOTTOM", Buttons[bottom], "BOTTOM", 0, 0)
		actionBarHoverFrame:SetPoint("LEFT", Buttons[left], "LEFT", 0, 0)
		actionBarHoverFrame:SetPoint("RIGHT", Buttons[right], "RIGHT", 0, 0)
	end

	local petBarHoverFrame = self:GetFadeFramePet()
	if (self.db.petBarEnabled) then
		petBarHoverFrame:ClearAllPoints()
		petBarHoverFrame:SetPoint("TOPLEFT", PetButtons[1], "TOPLEFT")
		petBarHoverFrame:SetPoint("BOTTOMRIGHT", PetButtons[10], "BOTTOMRIGHT")
	else
		petBarHoverFrame:ClearAllPoints()
		petBarHoverFrame:SetAllPoints(self:GetFrame())
	end
end

Module.UpdateButtonCount = function(self)
	-- Announce the updated button count to the world
	self:SendMessage("GP_UPDATE_ACTIONBUTTON_COUNT")
end

-- Just a proxy for the secure arrangement method.
-- Only ever call this out of combat, as it does not check for it.
Module.UpdateButtonLayout = function(self)
	local proxy = self:GetSecureUpdater()
	if (proxy) then
		proxy:Execute(proxy:GetAttribute("arrangeButtons"))
		proxy:Execute(proxy:GetAttribute("arrangePetButtons"))
	end
end

Module.UpdateCastOnDown = function(self)
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
end

Module.UpdateSettings = function(self, event, ...)
	self:UpdateFading()
	self:UpdateFadeAnchors()
	self:UpdateExplorerModeAnchors()
	self:UpdateCastOnDown()
	self:UpdateButtonBindpriority()
	self:UpdateTooltipSettings()
end 

-- Initialization
----------------------------------------------------
Module.OnInit = function(self)
	if (Private.HasSchematic("ModuleForge::ActionBars")) then
		self:Forge(Private.GetSchematic("ModuleForge::ActionBars").OnInit) 
	end
	if (Private.GetLayoutID == "Legacy") then
		return self:SetUserDisabled(true) -- to disable the menu while developing
	end
	
	-- Deprecated settings keep piling up in this one.
	self:PurgeSavedSettingFromAllProfiles(self:GetName(), "editMode", "buttonsPrimary", "buttonsComplimentary", "enableComplimentary", "enableStance", "enablePet", "showBinds", "showCooldown", "showCooldownCount", "showNames", "visibilityPrimary", "visibilityComplimentary", "visibilityStance", "visibilityPet")

	self.db = GetConfig(self:GetName())
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end

	local OptionsMenu = Core:GetModule("OptionsMenu", true)
	if (OptionsMenu) then
		local callbackFrame = OptionsMenu:CreateCallbackFrame(self)
		callbackFrame:AssignSettings(self.db)
		callbackFrame:AssignProxyMethods("UpdateCastOnDown", "UpdateFading", "UpdateFadeAnchors", "UpdateExplorerModeAnchors", "UpdateButtonCount", "UpdateButtonBindpriority")

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

	-- Create master frame. This one becomes secure.
	self.frame = self:CreateFrame("Frame", nil, "UICenter")

	-- Create overlay frames used for explorer mode.
	self.frameOverlay = self:CreateFrame("Frame", nil, "UICenter")
	self.frameOverlayPet = self:CreateFrame("Frame", nil, "UICenter")

	-- Apply overlay alpha to the master frame.
	hooksecurefunc(self.frameOverlay, "SetAlpha", function(_,alpha) self.frame:SetAlpha(alpha) end)

	-- Spawn the bars
	self:SpawnActionBars()
	self:SpawnPetBar()
	self:SpawnStanceBar()
	self:SpawnExitButton()

	-- Verified to only exist in retail.
	if (IsRetail) then
		self:SpawnTotemBar()
	end

	-- Arrange buttons
	-- *We're using the non-secure proxy method here,
	--  so take care to only ever do this out of combat.
	self:UpdateButtonLayout()

	-- Update saved settings
	self:UpdateActionButtonBindings()
	self:UpdateSettings()
end 

Module.OnEnable = function(self)
	if (Private.HasSchematic("ModuleForge::ActionBars")) then
		self:Forge(Private.GetSchematic("ModuleForge::ActionBars").OnEnable) 
	end
end


