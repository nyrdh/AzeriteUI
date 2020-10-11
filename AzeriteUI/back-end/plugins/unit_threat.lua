local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "UnitThreat requires LibClientBuild to be loaded.")

-- WoW API
local CreateFrame = CreateFrame
local IsInGroup = IsInGroup
local IsInInstance = IsInInstance
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitExists = UnitExists
local UnitThreatSituation = UnitThreatSituation

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

local UpdateColor = function(element, unit, status, r, g, b)
	if (element.OverrideColor) then
		return element:OverrideColor(unit, status, r, g, b)
	end
	-- Just some little trickery to easily support both textures and frames
	local colorFunc = element.SetVertexColor or element.SetBackdropBorderColor
	if (colorFunc) then
		colorFunc(element, r, g, b)
	end
	if (element.PostUpdateColor) then
		element:PostUpdateColor(unit, status, r, g, b)
	end 
end

local Update = function(self, event, unit, ...)
	if (not unit) or (unit ~= self.unit) then
		return 
	end
	local element = self.Threat

	-- Just do a fast kill on combat end.
	if (event == "PLAYER_REGEN_DISABLED") then
		element:Hide()
		element.status = nil
		if (element.PostUpdate) then
			return element:PostUpdate(unit, status, r, g, b)
		end
		return
	end

	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end

	local status

	-- BUG: Non-existent '*target' or '*pet' units cause UnitThreatSituation() errors (thank you oUF!)
	if UnitExists(unit) and ((not element.hideSolo) or (IsInGroup() or IsInInstance())) then
		local feedbackUnit = element.feedbackUnit
		if (feedbackUnit and (feedbackUnit ~= unit) and UnitExists(feedbackUnit)) then
			status = UnitThreatSituation(feedbackUnit, unit)
		else
			status = UnitThreatSituation(unit)
		end
	end 

	element.status = status

	local r, g, b
	if (status and (status > 0)) then
		r, g, b = self.colors.threat[status][1], self.colors.threat[status][2], self.colors.threat[status][3]
		element:UpdateColor(unit, status, r, g, b)
		element:Show()
	else
		element:Hide()
	end
	
	if (element.PostUpdate) then
		return element:PostUpdate(unit, status, r, g, b)
	end
end

local Proxy = function(self, ...)
	return (self.Threat.Override or Update)(self, ...)
end

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local element = self.Threat
	if (element) then
		element._owner = self
		element.ForceUpdate = ForceUpdate
		element.UpdateColor = UpdateColor

		self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", Proxy)
		self:RegisterEvent("UNIT_THREAT_LIST_UPDATE", Proxy)

		return true
	end
end 

local Disable = function(self)
	local element = self.Threat
	if (element) then

		self:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE", Proxy)
		self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE", Proxy)

		element:Hide()
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("Threat", Enable, Disable, Proxy, 18)
end 
