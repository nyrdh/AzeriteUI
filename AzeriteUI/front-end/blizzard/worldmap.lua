local ADDON = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end

local Module = Core:NewModule("BlizzardWorldMap", "LibEvent", "LibBlizzard", "LibClientBuild", "LibSecureHook")
Module:SetIncompatible("ClassicWorldMapEnhanced")
Module:SetIncompatible("Leatrix_Maps")

-- Constants for client version
local IsClassic = Module:IsClassic()
local IsRetail = Module:IsRetail()



local smallerMapScale = .8

Module.SetLargeWorldMap = function(self)
	WorldMapFrame:SetParent(UIParent)
	WorldMapFrame:SetScale(1)
	WorldMapFrame.ScrollContainer.Child:SetScale(smallerMapScale)

	if (WorldMapFrame:GetAttribute("UIPanelLayout-area") ~= "center") then
		SetUIPanelAttribute(WorldMapFrame, "area", "center");
	end

	if (WorldMapFrame:GetAttribute("UIPanelLayout-allowOtherPanels") ~= true) then
		SetUIPanelAttribute(WorldMapFrame, "allowOtherPanels", true)
	end

	WorldMapFrame:OnFrameSizeChanged()
	if (WorldMapFrame:GetMapID()) then
		WorldMapFrame.NavBar:Refresh()
	end
end

Module.UpdateMaximizedSize = function(self)
	local width, height = WorldMapFrame:GetSize()
	local magicNumber = (1 - smallerMapScale) * 100
	WorldMapFrame:SetSize((width * smallerMapScale) - (magicNumber + 2), (height * smallerMapScale) - 2)
end

Module.SynchronizeDisplayState = function(self)
	if (WorldMapFrame:IsMaximized()) then
		WorldMapFrame:ClearAllPoints()
		WorldMapFrame:SetPoint("CENTER", UIParent)
	end
end

Module.SetSmallWorldMap = function(self)
	if (not WorldMapFrame:IsMaximized()) then
		WorldMapFrame:ClearAllPoints()
		WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -94)
	end
end

Module.WorldMapOnShow = function(self, event, ...)
	if (self.mapSized) then
		return
	end

	-- Don't do this in combat, there are secure elements here.
	if (InCombatLockdown()) then
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "WorldMapOnShow")
		return

	-- Only ever need this event once.
	elseif (event == "PLAYER_REGEN_ENABLED") then
		self:UnregisterEvent(event, "WorldMapOnShow")
	end

	if (WorldMapFrame:IsMaximized()) then
		WorldMapFrame:UpdateMaximizedSize()
		self:SetLargeWorldMap()
	else
		self:SetSmallWorldMap()
	end

	-- Never again!
	self.mapSized = true
end

Module.OnInit = function(self)
	-- Nothing, really?
end

Module.OnEnable = function(self)
	if (IsClassic) then
		-- This does NOT disable the map,
		-- but rather shrink it and adds some
		-- conveniences like coordinates and movement fading.
		self:DisableUIWidget("WorldMap")

	elseif (IsRetail) then

		WorldMapFrame.BlackoutFrame.Blackout:SetTexture(nil)
		WorldMapFrame.BlackoutFrame:EnableMouse(false)

		self:SetSecureHook(WorldMapFrame, "Maximize", "SetLargeWorldMap", "GP_SET_LARGE_WORLDMAP")
		self:SetSecureHook(WorldMapFrame, "Minimize", "SetSmallWorldMap", "GP_SET_SMALL_WORLDMAP")
		self:SetSecureHook(WorldMapFrame, "SynchronizeDisplayState", "SynchronizeDisplayState", "GP_SYNC_DISPLAYSTATE_WORLDMAP")
		self:SetSecureHook(WorldMapFrame, "UpdateMaximizedSize", "UpdateMaximizedSize", "GP_UPDATE_MAXIMIZED_WORLDMAP")

		WorldMapFrame:HookScript("OnShow", function() self:WorldMapOnShow() end)
	end
end 
