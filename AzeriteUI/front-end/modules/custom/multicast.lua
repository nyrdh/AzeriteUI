local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then
	return
end

local Module = Core:NewModule("MultiCast", "LibMessage", "LibEvent", "LibDB", "LibSecureHook", "LibFrame")

-- Private API
local GetLayoutID = Private.GetLayoutID
local IsWrath = Private.IsWrath

-- Player Constants
local _,PlayerClass = UnitClass("player")

Module.UpdateMultiCastBar = function(self)
	local bar = MultiCastActionBarFrame
	if (not bar) then
		return
	end

	local layoutID = GetLayoutID()

	if (not self.frame) then
		local frame = self:CreateFrame("Frame", nil, "UICenter")
		frame.content = bar
		frame:SetSize(230,38)

		if (layoutID == "Legacy") then
			frame:Place("CENTER", "UICenter", "CENTER", 0, -160)
		else
			frame:Place("CENTER", "UICenter", "CENTER", 0, -300)
		end

		self.frame = frame
	end

	bar.ignoreFramePositionManager = true
	bar:SetScript("OnShow", nil)
	bar:SetScript("OnHide", nil)
	bar:SetScript("OnUpdate", nil)
	bar:SetParent(self.frame)
	bar:SetFrameLevel(self.frame:GetFrameLevel() + 1)
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", 0, 0)
	bar:SetScale(layoutID == "Legacy" and 1.2 or 1.25)

end

Module.OnInit = function(self)
	if (not IsWrath) or (not MultiCastActionBarFrame) or (PlayerClass ~= "SHAMAN") then
		self.UpdateMultiCastBar = nil
		return self:SetUserDisabled(true)
	end
	self:SetSecureHook("ShowMultiCastActionBar", "UpdateMultiCastBar")
end

Module.OnEnable = function(self)
end
