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

-- Setup the classic threat environment
local ThreatLib, UnitThreatDB, Frames
if (IsClassic) then

	-- Add in support for LibThreatClassic2.
	ThreatLib = LibStub("LibThreatClassic2")

	-- Replace the threat API with LibThreatClassic2
	UnitThreatSituation = function (unit, mob)
		return ThreatLib:UnitThreatSituation (unit, mob)
	end

	UnitDetailedThreatSituation = function (unit, mob)
		return ThreatLib:UnitDetailedThreatSituation (unit, mob)
	end

	--local CheckStatus = function(...)
	--	print(...)
	--end
	--ThreatLib:RegisterCallback("Activate", CheckStatus)
	--ThreatLib:RegisterCallback("Deactivate", CheckStatus)
	--ThreatLib:RegisterCallback("ThreatUpdated", CheckStatus)
	ThreatLib:RequestActiveOnSolo(true)

	-- I do NOT like exposing this, but I don't want multiple update handlers either,
	-- neither from multiple frames using this element or multiple versions of the plugin.
	local LibDB = Wheel("LibDB")
	assert(LibDB, "UnitThreat requires LibDB to be loaded.")

	UnitThreatDB = LibDB:GetDatabase("UnitThreatDB", true) or LibDB:NewDatabase("UnitThreatDB")
	UnitThreatDB.frames = UnitThreatDB.frames or {}

	-- Shortcut it
	Frames = UnitThreatDB.frames

end

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
			if (IsClassic) then
				-- Need to check against a specific unit in classic
				if UnitExists("target") then
					status = UnitThreatSituation(unit, "target")
				else
					-- No target exists, but a prior one did.
					-- Note that this will not be fully accurate
					-- until we once more target something.
					if (element.status and element.status > 0) then
						-- If current threat data exists
						local unitGUID = UnitGUID(unit)
						local data = ThreatLib.threatTargets[unitGUID]
						if (data) then
							-- What mod does this unit have the most threat on?
							local maxThreatVal,maxThreatGUID = 0
							for otherGUID,v in pairs(data) do
								if (v > maxThreatVal) then
									maxThreatGUID = otherGUID
									maxThreatVal = v
								end
							end

							-- If the unit has threat on somebody, and it's above 0.
							if (maxThreatGUID) and (maxThreatVal > 0) then

								-- need a comparison with other people, decide status(?)
								local maxPlayerVal, maxPlayerGUID = ThreatLib:GetMaxThreatOnTarget(maxThreatGUID)
								if (maxPlayerGUID == unitGUID) then
									status = 3 -- tanking, with highest threat

								elseif (maxThreatVal >= maxPlayerVal) then
									status = 2 -- tanking, not with highest threat

								else
									-- If we had no aggro prior to losing the target,
									-- don't show it now, would be inconsistent.
									status = (element.status == 0) and 0 or 1
								end
							end
						end
					end
				end
			else
				status = UnitThreatSituation(unit)
			end
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

local timer, HZ = 0, .2
local OnUpdate_Threat = function(this, elapsed)
	timer = timer + elapsed
	if (timer >= HZ) then
		for frame in pairs(Frames) do 
			if (frame:IsShown()) then
				Proxy(frame, "OnUpdate", frame.unit)
			end
		end
		timer = 0
	end
end

local OnEvent_Threat = function(this, event, ...)
	if (event == "PLAYER_REGEN_DISABLED") then
		this:SetScript("OnUpdate", OnUpdate_Threat)
		this:Show()
	elseif (event == "PLAYER_REGEN_ENABLED") then
		this:SetScript("OnUpdate", nil)
		this:Hide()
	end
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

		if (IsClassic) then
		
			self:RegisterEvent("PLAYER_TARGET_CHANGED", Proxy, true)
			self:RegisterEvent("PLAYER_REGEN_DISABLED", Proxy, true)
			self:RegisterEvent("PLAYER_REGEN_ENABLED", Proxy, true)

			Frames[self] = true

			-- We create the update frame on the fly
			if (not UnitThreatDB.ThreatFrame) then
				UnitThreatDB.ThreatFrame = CreateFrame("Frame")
				UnitThreatDB.ThreatFrame:Hide()
			end

			-- Reset the update frame
			UnitThreatDB.ThreatFrame:UnregisterAllEvents()
			UnitThreatDB.ThreatFrame:SetScript("OnEvent", OnEvent_Threat)
			UnitThreatDB.ThreatFrame:SetScript("OnUpdate", nil)

			UnitThreatDB.ThreatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
			UnitThreatDB.ThreatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

			-- In case this element for some reason is first enabled in combat.
			if (InCombatLockdown()) and (not UnitThreatDB.ThreatFrame:IsShown()) then
				OnEvent_Threat(UnitThreatDB.ThreatFrame, "PLAYER_REGEN_DISABLED")
			end

		elseif (IsRetail) then
			self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", Proxy)
			self:RegisterEvent("UNIT_THREAT_LIST_UPDATE", Proxy)
		end

		return true
	end
end 

local Disable = function(self)
	local element = self.Threat
	if (element) then

		if (IsClassic) then
		
			self:UnregisterEvent("PLAYER_TARGET_CHANGED", Proxy)
			self:UnregisterEvent("PLAYER_REGEN_DISABLED", Proxy)
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", Proxy)

			-- Erase the entry
			Frames[self] = nil

			-- Spooky fun way to return if the table has entries! 
			for frame in pairs(Frames) do 
				return 
			end 
	
			-- Hide the threat frame if the previous returned zero table entries
			if (UnitThreatDB.ThreatFrame) then 
				UnitThreatDB.ThreatFrame:Hide()
			end 
		
		elseif (IsRetail) then
			self:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE", Proxy)
			self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE", Proxy)
		end

		element:Hide()
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("Threat", Enable, Disable, Proxy, 17)
end 
