local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "UnitPetHappiness requires LibClientBuild to be loaded.")

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- WoW API
local GetPetHappiness = GetPetHappiness
local HasPetUI = HasPetUI

-- WoW Classic globals, but still exist in Retail:
local HAPPINESS = HAPPINESS -- "Happiness"
local PET_HAPPINESS1 = PET_HAPPINESS1 -- "Unhappy"
local PET_HAPPINESS2 = PET_HAPPINESS2 -- "Content"
local PET_HAPPINESS3 = PET_HAPPINESS3 -- "Happy"

-- WoW Classic globals, removed in Retail
local GAINING_LOYALTY = GAINING_LOYALTY or "Gaining Loyalty"
local LOSING_LOYALTY = LOSING_LOYALTY or "Losing Loyalty"

-- Exist in Classic, Retail untested
local DAMAGE = DAMAGE
local DPS = STAT_DPS_SHORT

-- Sourced from _classic_\Interface\FrameXML\PetFrame.lua
local happyTexCoord = {
	[1] = { .375, .5625, 0, .359375 },
	[2] = { .1875, .375, 0, .359375 },
	[3] = { 0, .1875, 0, .359375 }
}

local happyMessage = {
	gaining = {
		[1] = HAPPINESS..": |cffff0303" .. PET_HAPPINESS1 .. "|r |cff888888(%d%% "..DPS..")|r - |cff20c000"..GAINING_LOYALTY.."|r",
		[2] = HAPPINESS..": |cfffe8a0e" .. PET_HAPPINESS2 .. "|r |cff888888(%d%% "..DPS..")|r - |cff20c000"..GAINING_LOYALTY.."|r",
		[3] = HAPPINESS..": |cff20c000" .. PET_HAPPINESS3 .. "|r |cff888888(%d%% "..DPS..")|r - |cff20c000"..GAINING_LOYALTY.."|r"
	},
	losing = {
		[1] = HAPPINESS..": |cffff0303" .. PET_HAPPINESS1 .. "|r |cff888888(%d%% "..DPS..")|r - |cffff0303"..LOSING_LOYALTY.."|r",
		[2] = HAPPINESS..": |cfffe8a0e" .. PET_HAPPINESS2 .. "|r |cff888888(%d%% "..DPS..")|r - |cffff0303"..LOSING_LOYALTY.."|r",
		[3] = HAPPINESS..": |cff20c000" .. PET_HAPPINESS3 .. "|r |cff888888(%d%% "..DPS..")|r - |cffff0303"..LOSING_LOYALTY.."|r"
	},
	passive = {
		[1] = HAPPINESS..": |cffff0303" .. PET_HAPPINESS1 .. "|r |cff888888(%d%% "..DPS..")|r",
		[2] = HAPPINESS..": |cfffe8a0e" .. PET_HAPPINESS2 .. "|r |cff888888(%d%% "..DPS..")|r",
		[3] = HAPPINESS..": |cff20c000" .. PET_HAPPINESS3 .. "|r |cff888888(%d%% "..DPS..")|r"
	}
}

local Update = function(self, event, unit, ...)
	if (not unit) or (unit ~= self.unit) then 
		return 
	end 
	if (event == "UNIT_PET") then
		local owner = ...
		if (owner ~= "player") then
			return
		end
	end

	local element = self.PetHappiness
	if (element.PreUpdate) then
		element:PreUpdate(unit)
	end

	local happiness, damagePercentage, loyaltyRate = GetPetHappiness()
	local _, hunterPet = HasPetUI()
	if (not (happiness or hunterPet)) then
		return element:Hide()
	end

	if (element:IsObjectType("FontString")) then
		if (loyaltyRate < 0) then
			element:SetFormattedText(happyMessage.losing[happiness], damagePercentage, loyaltyRate)
		elseif (loyaltyRate > 0) then
			element:SetFormattedText(happyMessage.gaining[happiness], damagePercentage, loyaltyRate)
		else
			element:SetFormattedText(happyMessage.passive[happiness], damagePercentage)
		end
	elseif (element:IsObjectType("Texture")) then
		element:SetTexCoord(unpack(happyTexCoord[happiness]))
	end

	element:Show()

	if (element.PostUpdate) then 
		return element:PostUpdate(unit, happiness, damagePercentage, loyaltyRate, hunterPet)
	end 
end 

local Proxy = function(self, ...)
	return (self.PetHappiness.Override or Update)(self, ...)
end 

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local element = self.PetHappiness
	if element then
		element._owner = self
		element.ForceUpdate = ForceUpdate

		-- Forcefully hide this when not in Classic
		if (not IsClassic) then
			element:Hide()
			return
		end

		-- Apply default Blizzard textures if none is set.
		if (element:IsObjectType("Texture")) and (not element:GetTexture()) then
			element:SetTexture([[Interface\PetPaperDollFrame\UI-PetHappiness]])
			element:SetTexCoord(unpack(happyTexCoord[3]))
		end

		self:RegisterEvent("PET_UI_UPDATE", Proxy, true)
		self:RegisterEvent("UNIT_HAPPINESS", Proxy, true)
		self:RegisterEvent("UNIT_PET", Proxy, true) -- this is a unitevent for "player", not "pet"

		return true
	end
end 

local Disable = function(self)
	local element = self.PetHappiness
	if element then
		element:Hide()

		if (not IsClassic) then
			return
		end

		self:UnregisterEvent("PET_UI_UPDATE", Proxy)
		self:UnregisterEvent("UNIT_PET", Proxy)
		self:UnregisterEvent("UNIT_HAPPINESS", Proxy)
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("PetHappiness", Enable, Disable, Proxy, 1)
end 
