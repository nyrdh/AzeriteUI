local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Blizzard PopUp Styling
local Module = Core:NewModule("BlizzardPopupStyling", "LibHook", "LibSecureHook")

-- Lua API
local pairs = pairs

-- WoW API
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown

-- Private API
local Colors = Private.Colors
local GetFont = Private.GetFont
local GetLayout = Private.GetLayout
local GetMedia = Private.GetMedia
local IsClassic = Private.IsClassic
local IsRetail = Private.IsRetail

-- Registries
local Backdrops, Borders, Handled, Styled = {}, {}, {}, {}

-- Utility Functions
-----------------------------------------------------------
local GetBackdrop = function(popup)
	local backdrop = Backdrops[popup]
	if (not backdrop) then
		backdrop = CreateFrame("Frame", nil, popup, BackdropTemplateMixin and "BackdropTemplate")
		backdrop:SetFrameLevel(popup:GetFrameLevel() - 1)
		Backdrops[popup] = backdrop
	end	
	return backdrop
end

local GetBorder = function(popup)
	local backdrop = Borders[popup]
	if (not backdrop) then
		backdrop = CreateFrame("Frame", nil, popup, BackdropTemplateMixin and "BackdropTemplate")
		backdrop:SetFrameLevel(popup:GetFrameLevel())
		Borders[popup] = backdrop
	end	
	return backdrop
end

local DisableBlizzard = function(popup)

	local name = popup:GetName()
	if (not name) then
		return
	end

	-- Remove 8.x backdrops
	if (popup.SetBackdrop) then
		popup:SetBackdrop(nil)
		popup:SetBackdropColor(0,0,0,0)
		popup:SetBackdropBorderColor(0,0,0,0)
	end

	-- Remove 9.x backdrops
	if (popup.Border) then 
		popup.Border:SetAlpha(0)
	end

	-- Remove button artwork
	for _,buttonName in pairs({ "Button1", "Button2", "Button3", "Button4", "ExtraButton" }) do
		local button = _G[name..buttonName]
		if (button) then
			button:GetNormalTexture():SetVertexColor(0, 0, 0, 0)
			button:GetHighlightTexture():SetVertexColor(0, 0, 0, 0)
			button:GetPushedTexture():SetVertexColor(0, 0, 0, 0)
			button:GetDisabledTexture():SetVertexColor(0, 0, 0, 0)
			if (button.SetBackdrop) then
				button:SetBackdrop(nil)
				button:SetBackdropColor(0,0,0,0)
				button:SetBackdropBorderColor(0,0,0.0)
			end
		end
	end

	-- Remove editbox artwork
	local editbox = _G[name .. "EditBox"]
	if (editbox) then
		for _,texName in pairs({ "EditBoxLeft", "EditBoxMid", "EditBoxRight" }) do
			local tex = _G[name..texName]
			if (tex) then
				tex:SetTexture(nil)
				tex:SetAlpha(0)
			end
		end
		if (editbox.SetBackdrop) then
			editbox:SetBackdrop(nil)
			editbox:SetBackdropColor(0, 0, 0, 0)
			editbox:SetBackdropBorderColor(0, 0, 0, 0)
		end
		editbox:SetTextInsets(6, 6, 0, 0)
	end

	-- Remaining frames:
	-- "$parentMoneyFrame" - "SmallMoneyFrameTemplate"
	-- "$parentMoneyInputFrame" - "MoneyInputFrameTemplate"
	-- "$parentItemFrame"

end

-- Addon API
-----------------------------------------------------------
Module.StylePopup = function(self, popup)
	local name = popup and popup:GetName()
	if (not name) then
		return
	end
	if (Styled[popup]) then
		return
	end

	local layout = self.layout

	-- Clear the blizzard content
	DisableBlizzard(popup)

	-- User styled backdrops
	local backdrop = GetBackdrop(popup)
	backdrop:SetBackdrop(layout.PopupBackdrop)
	backdrop:SetBackdropColor(unpack(layout.PopupBackdropColor ))
	backdrop:SetBackdropBorderColor(unpack(layout.PopupBackdropBorderColor ))
	backdrop:SetPoint("TOPLEFT", -layout.PopupBackdropOffsets[1], layout.PopupBackdropOffsets[3])
	backdrop:SetPoint("BOTTOMRIGHT", layout.PopupBackdropOffsets[2], -layout.PopupBackdropOffsets[4])

	-- User styled buttons
	for _,buttonName in pairs({ "Button1", "Button2", "Button3", "Button4", "ExtraButton" }) do
		local button = _G[name..buttonName]
		if (button) then
			local backdrop = GetBackdrop(button)
			backdrop:SetFrameLevel(button:GetFrameLevel())
			backdrop:SetPoint("TOPLEFT", -layout.PopupButtonBackdropOffsets[1], layout.PopupButtonBackdropOffsets[3])
			backdrop:SetPoint("BOTTOMRIGHT", layout.PopupButtonBackdropOffsets[2], -layout.PopupButtonBackdropOffsets[4])
			backdrop:SetBackdrop(layout.PopupButtonBackdrop)
			backdrop:SetBackdropColor(unpack(layout.PopupButtonBackdropColor))
			backdrop:SetBackdropBorderColor(unpack(layout.PopupButtonBackdropColor))
			
			local border = GetBorder(button)
			border:SetFrameLevel(button:GetFrameLevel() + 1)
			border:SetPoint("TOPLEFT", -layout.PopupButtonBorderOffsets[1], layout.PopupButtonBorderOffsets[3])
			border:SetPoint("BOTTOMRIGHT", layout.PopupButtonBorderOffsets[2], -layout.PopupButtonBorderOffsets[4])
			border:SetBackdrop(layout.PopupButtonBorder)
			border:SetBackdropBorderColor(unpack(layout.PopupButtonBackdropBorderColor))

			button:HookScript("OnEnter", function() 
				backdrop:SetBackdropColor(unpack(layout.PopupButtonBackdropHoverColor))
				backdrop:SetBackdropBorderColor(unpack(layout.PopupButtonBackdropHoverColor))
				border:SetBackdropBorderColor(unpack(layout.PopupButtonBackdropHoverBorderColor ))
			end)
			
			button:HookScript("OnLeave", function() 
				backdrop:SetBackdropColor(unpack(layout.PopupButtonBackdropColor))
				backdrop:SetBackdropBorderColor(unpack(layout.PopupButtonBackdropColor))
				border:SetBackdropBorderColor(unpack(layout.PopupButtonBackdropBorderColor))
			end)
		end
	end

	local editbox = _G[name.."EditBox"]
	if (editbox) then
		if (editbox.SetBackdrop) then
			editbox:SetBackdrop(layout.EditBoxBackdrop)
			editbox:SetBackdropColor(unpack(layout.EditBoxBackdropColor))
			editbox:SetBackdropBorderColor(unpack(layout.EditBoxBackdropBorderColor))
		end
		editbox:SetTextInsets(unpack(layout.EditBoxInsets))
	end

	Styled[popup] = true
end

Module.StylePopups = function(self)
	for i = 1, STATICPOPUP_NUMDIALOGS do 
		local popup = _G["StaticPopup"..i]
		if (popup) and (not Handled[popup]) then
			self:SetHook(popup, "OnShow", function() self:StylePopup(popup) end, "GP_POPUP"..i.."_ONSHOW")
			Handled[popup] = true
		end
	end
end

Module.UpdatePopupAnchors = function(self, event)

	-- Not strictly certain if moving them in combat would taint them, 
	-- but knowing the blizzard UI, I'm not willing to take that chance.
	if (InCombatLockdown()) then 
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	end

	local layout = self.layout

	local previous
	for i = 1, STATICPOPUP_NUMDIALOGS do
		local popup = _G["StaticPopup"..i]
		local point, anchor, rpoint, x, y = popup:GetPoint()
		if (anchor == previous) then
			-- We only change the offsets values, not the anchor points, 
			-- since experience tells me that this is a safer way to avoid potential taint!
			popup:ClearAllPoints()
			popup:SetPoint(point, anchor, rpoint, 0, -(layout.PopupVerticalOffset or 6))
		end
		previous = popup
	end

end

-- Module Core
-----------------------------------------------------------
Module.OnEvent = function(self)
	if (event == "PLAYER_REGEN_ENABLED") then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		self:UpdatePopupAnchors()
	end
end

Module.OnInit = function(self)
	self.layout = GetLayout(self:GetName())
	if (not self.layout) then
		return self:SetUserDisabled(true)
	end
end

Module.OnEnable = function(self)
	self:StylePopups()
	self:UpdatePopupAnchors()

	-- The popups are re-anchored by blizzard, so we need to re-adjust them when they do.
	self:SetSecureHook("StaticPopup_SetUpPosition", "UpdatePopupAnchors", "GP_POPUP_SET_ANCHORS")
end