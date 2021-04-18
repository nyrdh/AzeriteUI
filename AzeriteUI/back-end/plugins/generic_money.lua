local LibNumbers = Wheel("LibNumbers")
assert(LibNumbers, "Money requires LibNumbers to be loaded.")

-- Lua API
local math_floor = math.floor
local math_mod = math.fmod
local string_format = string.format

-- WoW API
local GetMoney = GetMoney
local GetMoneyString = GetMoneyString

-- Library API
local prettify = LibNumbers:GetNumberPrettified()

local Update = function(self, event, ...)
	local element = self.Money
	if (element.PreUpdate) then 
		element:PreUpdate()
	end 

	local money = GetMoney() or 0
	if (element.useSmartNumbering) then
		local gold = math_floor(money / (1e4))
		local silver = math_floor((money - (gold * 1e4)) / 100)
		local copper = math_mod(money, 100)
		if (gold >= 1e3) then
			money = gold * 1e4
		elseif (gold >= 10) then
			money = gold * 1e4 + silver * 100
		end
	end
	local moneyString
	if (element.coinStringGold) and (element.coinStringSilver) and (element.coinStringCopper) then 
		local gold = math_floor(money / (1e4))
		if (gold > 0) then 
			moneyString = string_format("%s%s", prettify(gold), element.coinStringGold)
		end

		local silver = math_floor((money - (gold * 1e4)) / 100)
		if (silver > 0) then 
			moneyString = (moneyString and moneyString.." " or "") .. string_format("%d%s", silver, element.coinStringSilver)
		end

		local copper = math_mod(money, 100)
		if (copper > 0) then 
			moneyString = (moneyString and moneyString.." " or "") .. string_format("%d%s", copper, element.coinStringCopper)
		end 
	else
		moneyString = GetMoneyString(money, false)
	end

	element:SetText(moneyString or "")

	if (element.PostUpdate) then 
		return element:PostUpdate()
	end 
end 

local Proxy = function(self, ...)
	return (self.Money.Override or Update)(self, ...)
end 

local ForceUpdate = function(element, ...)
	return Proxy(element._owner, "Forced", ...)
end

local Enable = function(self)
	local element = self.Money
	if (element) then 
		element._owner = self
		element.ForceUpdate = ForceUpdate

		self:RegisterEvent("PLAYER_MONEY", Proxy, true)
		self:RegisterEvent("PLAYER_ENTERING_WORLD", Proxy, true)

		return true
	end 
end 

local Disable = function(self)
	local element = self.Money
	if (element) then 

		self:UnregisterEvent("PLAYER_MONEY", Proxy)
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", Proxy)
	end 
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibWidgetContainer", true)) }) do 
	Lib:RegisterElement("Money", Enable, Disable, Proxy, 1)
end 
