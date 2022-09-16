local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end

local Module = Core:NewModule("MultiCast", "LibMessage", "LibEvent", "LibDB")

-- Private API
local GetLayoutID = Private.GetLayoutID

-- Player Constants
local _,PlayerClass = UnitClass("player")

Module.OnInit = function(self)
	if (not IsWrath) or (not MultiCastActionBarFrame) or (PlayerClass ~= "SHAMAN") then
		return self:SetUserDisabled(true)
	end

	local multicast = backdrop:CreateFrame("Frame")
	multicast:SetSize(230,38)

	local theme = GetLayoutID()
	if (theme == "Legacy") then
		multicast:Place("CENTER", "UICenter", "CENTER", 0, -200)
	else
		multicast:Place("CENTER", "UICenter", "CENTER", 0, -300)
	end

	multicast.content = MultiCastActionBarFrame
	multicast.content.ignoreFramePositionManager = true
	multicast.content:SetScript("OnShow", nil)
	multicast.content:SetScript("OnHide", nil)
	multicast.content:SetScript("OnUpdate", nil)
	multicast.content:SetParent(multicast)
	multicast.content:Show()
	multicast.content:SetFrameLevel(multicast:GetFrameLevel() + 1)

	--hooksecurefunc("ShowMultiCastActionBar", function() end)

end
