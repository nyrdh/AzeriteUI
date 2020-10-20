local LibFrame = Wheel("LibFrame")
assert(LibFrame, "UnitAuras requires LibFrame to be loaded.")

local LibAura = Wheel("LibAura")
assert(LibAura, "UnitAuras requires LibAura to be loaded.")

-- Lua API
local _G = _G
local math_ceil = math.ceil
local math_floor = math.floor
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local table_wipe = table.wipe

-- WoW API
local CancelUnitBuff = CancelUnitBuff
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local UnitExists = UnitExists

-- Blizzard Textures
local EDGE_LOC_TEXTURE = [[Interface\Cooldown\edge-LoC]]
local EDGE_NORMAL_TEXTURE = [[Interface\Cooldown\edge]]
local BLING_TEXTURE = [[Interface\Cooldown\star4]]

-- Sourced from FrameXML/BuffFrame.lua
local BUFF_MAX_DISPLAY = BUFF_MAX_DISPLAY
local DEBUFF_MAX_DISPLAY = DEBUFF_MAX_DISPLAY

-- Aura Caches
local DisplayCache = {} -- display caches after custom filter and visibility limits
local FullBuffCache = {} -- full buff caches according to current filter
local FullDebuffCache = {} -- full debuff caches according to current filter

-- Constants
local DAY, HOUR, MINUTE = 86400, 3600, 60
local LONG_THRESHOLD = MINUTE*3
local HZ = 1/20

local IN_COMBAT

-- Utility Functions
-----------------------------------------------------
local formatTime = function(time)
	if (time > DAY) then -- more than a day
		return "%.0f%s", math_ceil(time / DAY), "d"
	elseif (time > HOUR) then -- more than an hour
		return "%.0f%s", math_ceil(time / HOUR), "h"
	elseif (time > MINUTE) then -- more than a minute
		return "%.0f%s", math_ceil(time / MINUTE), "m"
	elseif (time > 5) then 
		return "%.0f", math_ceil(time)
	elseif (time > .9) then 
		return "|cffff8800%.0f|r", math_ceil(time)
	elseif (time > .05) then
		return "|cffff0000%.0f|r", time*10 - time*10%1
	else
		return ""
	end	
end

-- Aura Button Template
-----------------------------------------------------
local Aura_OnClick = function(button, buttonPressed, down)
	if (button.OnClick) then 
		return button:OnClick(buttonPressed, down)
	end 
	-- Only called if no override exists above
	if (buttonPressed == "RightButton") and (not InCombatLockdown()) then
		-- Some times an update is run right after the unit has been removed, 
		-- causing a myriad of nil bugs. Avoid it!
		if (button.isBuff and UnitExists(button.unit)) then
			CancelUnitBuff(button.unit, button:GetID(), button.filter)
		end
	end
end

local Aura_PreClick = function(button, buttonPressed, down)
	if (button.PreClick) then 
		return button:PreClick(buttonPressed, down)
	end 
end 

local Aura_PostClick = function(button, buttonPressed, down)
	if (button.PostClick) then 
		return button:PostClick(buttonPressed, down)
	end 
end 

local Aura_UpdateTooltip = function(button)
	local tooltip = button:GetTooltip()
	tooltip:Hide()
	tooltip:SetMinimumWidth(160)
	tooltip.hideSpellID = button.isFiltered
	local element = button._owner
	if (element.tooltipDefaultPosition) then 
		tooltip:SetDefaultAnchor(button)
	elseif (element.tooltipPoint) then 
		tooltip:SetOwner(button)
		tooltip:Place(element.tooltipPoint, element.tooltipAnchor or button, element.tooltipRelPoint or element.tooltipPoint, element.tooltipOffsetX or 0, element.tooltipOffsetY or 0)
	else 
		tooltip:SetSmartAnchor(button, element.tooltipOffsetX or 10, element.tooltipOffsetY or 10)
	end 
	if (button.isBuff) then 
		tooltip:SetUnitBuff(button.unit, button:GetID(), button.filter)
	else 
		tooltip:SetUnitDebuff(button.unit, button:GetID(), button.filter)
	end 
end

local Aura_OnEnter = function(button)
	if (button.OnEnter) then 
		return button:OnEnter()
	end 
	button.isMouseOver = true
	button.UpdateTooltip = Aura_UpdateTooltip
	button:UpdateTooltip()
	if (button.PostEnter) then 
		return button:PostEnter()
	end 
end

local Aura_OnLeave = function(button)
	if (button.OnLeave) then 
		return button:OnLeave()
	end 

	button.UpdateTooltip = nil

	local tooltip = button:GetTooltip()
	tooltip:Hide()

	if (button.PostLeave) then 
		return button:PostLeave()
	end 
end

local Aura_SetCooldownTimer = function(button, start, duration)
	if (button._owner.showSpirals) then
		local cooldown = button.Cooldown
		cooldown:SetSwipeColor(0, 0, 0, .75)
		cooldown:SetDrawEdge(false)
		cooldown:SetDrawBling(false)
		cooldown:SetDrawSwipe(true)
		if (duration > .5) then
			cooldown:SetCooldown(start, duration)
			cooldown:Show()
		else
			cooldown:Hide()
		end
	else 
		button.Cooldown:Hide()
	end 
end 

local Aura_UpdateTimer = function(button, elapsed)
	if (button.Time) then
		button.elapsed = (button.elapsed or 0) + elapsed
		if (button.elapsed >= HZ) then
			local element = button._owner
			local timeLeft = button.expirationTime - GetTime()
			if (timeLeft > 0) then
				if (element.showDurations) and ((timeLeft < LONG_THRESHOLD) or (element.showLongDurations)) then 
					button.Time:SetFormattedText(formatTime(timeLeft))
				else
					button.Time:SetText("")
				end 
			else
				button:SetScript("OnUpdate", nil)
				Aura_SetCooldownTimer(button, 0,0)
				button.Time:SetText("")
				element:ForceUpdate()
			end	
			if (button:IsShown() and element.PostUpdateButton) then
				element:PostUpdateButton(button, "Timer")
			end
			button.timeLeft = timeLeft
			button.elapsed = 0
		end
	end
end

-- Use this to initiate the timer bars and spirals on the auras
local Aura_SetTimer = function(button, fullDuration, expirationTime)
	if (fullDuration) and (fullDuration > 0) then
		button.fullDuration = fullDuration
		button.timeStarted = expirationTime - fullDuration
		button.timeLeft = expirationTime - GetTime()
		button:SetScript("OnUpdate", Aura_UpdateTimer)
		Aura_SetCooldownTimer(button, button.timeStarted, button.fullDuration)
	else
		button:SetScript("OnUpdate", nil)
		Aura_SetCooldownTimer(button, 0,0)
		button.Time:SetText("")
		button.fullDuration = 0
		button.timeStarted = 0
		button.timeLeft = 0
	end
	if (button:IsShown()) and (button._owner.PostUpdateButton) then
		button._owner:PostUpdateButton(button, "Timer")
	end
end

local CreateAuraButton = function(element)

	local button = element:CreateFrame("Button")
	if (not element.disableMouse) then
		button:EnableMouse(true)
		button:RegisterForClicks("RightButtonUp")
	else
		button:EnableMouse(false)
	end
	button:SetSize(element.auraSize, element.auraSize)
	button._owner = element

	-- Spell icon
	local icon = button:CreateTexture()
	icon:SetDrawLayer("ARTWORK", 1)
	icon:SetAllPoints()
	button.Icon = icon

	-- Frame to contain art overlays, texts, etc
	-- Modules can put their borders and other overlays here
	local overlay = button:CreateFrame("Frame")
	overlay:SetAllPoints(button)
	overlay:SetFrameLevel(button:GetFrameLevel() + 2)
	button.Overlay = overlay

	-- Cooldown frame
	local cooldown = button:CreateFrame("Cooldown", nil, "CooldownFrameTemplate")
	cooldown:Hide()
	cooldown:SetAllPoints(button)
	cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	cooldown:SetReverse(false)
	cooldown:SetSwipeColor(0, 0, 0, .75)
	cooldown:SetBlingTexture(BLING_TEXTURE, .3, .6, 1, .75) 
	cooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
	cooldown:SetDrawSwipe(true)
	cooldown:SetDrawBling(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true) 
	button.Cooldown = cooldown

	local time = overlay:CreateFontString()
	time:SetDrawLayer("ARTWORK", 1)
	time:SetPoint("CENTER", 1, 0)
	time:SetFontObject(GameFontNormal)
	time:SetJustifyH("CENTER")
	time:SetJustifyV("MIDDLE")
	time:SetShadowOffset(0, 0)
	time:SetShadowColor(0, 0, 0, 1)
	time:SetTextColor(250/255, 250/255, 250/255, .85)
	button.Time = time

	local count = overlay:CreateFontString()
	count:SetDrawLayer("OVERLAY", 1)
	count:SetPoint("BOTTOMRIGHT", -2, 1)
	count:SetFontObject(GameFontNormal)
	count:SetJustifyH("CENTER")
	count:SetJustifyV("MIDDLE")
	count:SetShadowOffset(0, 0)
	count:SetShadowColor(0, 0, 0, 1)
	count:SetTextColor(250/255, 250/255, 250/255, .85)
	button.Count = count

	-- Borrow the unitframe tooltip
	-- *Note that this method is created after element initialization, 
	-- so we should probably use a smarter callback here. 
	-- For now this is "safe", though, since auras won't be parsed this early anyway. 
	button.GetTooltip = element._owner.GetTooltip

	-- Run user post creation method
	if element.PostCreateButton then 
		element:PostCreateButton(button)
	end 

	-- Apply script handlers
	-- * Note that we only provide out of combat aura cancelling, 
	-- any other functionality including tooltips should be added by the modules. 
	-- * Also note that we apply these AFTER the post creation callbacks!
	if (not element.disableMouse) then 
		button:SetScript("OnEnter", Aura_OnEnter)
		button:SetScript("OnLeave", Aura_OnLeave)
		button:SetScript("OnClick", Aura_OnClick)
		button:SetScript("PreClick", Aura_PreClick)
		button:SetScript("PostClick", Aura_PostClick)
	end 

	return button
end 

local SetAuraButtonPosition = function(element, button, buttonNum)

	-- Get the accurate size of the container
	local elementW, elementH = element:GetSize()
	elementW = (elementW + .5) - (elementW + .5)%1
	elementH = (elementH + .5) - (elementH + .5)%1

	-- Get the accurate size of the slots with spacing 
	local width = (element.auraSize or element.auraWidth) + element.spacingH
	local height = (element.auraSize or element.auraHeight) + element.spacingV
	
	-- Number of columns
	local numCols = (elementW + element.spacingH)/width
	numCols = numCols - numCols%1

	-- Number of Rows
	local numRows = (elementH + element.spacingV)/height
	numRows = numRows - numRows%1

	-- No room for this aura, return in panic!
	if (buttonNum > numCols*numRows) then 
		return true
	end 

	-- Figure out the origin
	local point = ((element.growthY == "UP") and "BOTTOM" or (element.growthY == "DOWN") and "TOP") .. ((element.growthX == "RIGHT") and "LEFT" or (element.growthX == "LEFT") and "RIGHT")

	-- Figure out the positions in the grid
	buttonNum = buttonNum - 1 
	local posX = buttonNum%numCols
	local posY = buttonNum/numCols - buttonNum/numCols%1

	-- Figure out where to grow
	local offsetX = posX * width * (element.growthX == "LEFT" and -1 or 1)
	local offsetY = posY * height * (element.growthY == "DOWN" and -1 or 1)

	-- Position the button
	button:ClearAllPoints()
	button:SetPoint(point, offsetX, offsetY)
end 

-- Let's keep the sorting as simplistic as possible.
local auraSortFunction = function(a,b)
	if (a) and (b) and (a.id) and (b.id) then
		if (a.isCastByPlayer == b.isCastByPlayer) then
			if (a.expirationTime == b.expirationTime) then
				if (a.name) and (b.name) then
					return (a.name > b.name)
				end
			else
				return (a.expirationTime > b.expirationTime)
			end
		else
			return a.isCastByPlayer
		end 
	end
end

local CacheBuffs = function(element, unit, filter, customFilter)

	local cache = FullBuffCache[element]
	local numAuras = 0

	-- Iterate helpful auras
	for i = 1, BUFF_MAX_DISPLAY do 

		-- Retrieve buff information
		local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = LibAura:GetUnitBuff(unit, i, filter)

		-- No name means no more buffs matching the filter
		if (not name) then
			break
		end

		-- Figure out if the debuff is owned by us, not just cast by us
		local isOwnedByPlayer = unitCaster and (unitCaster == "player" or unitCaster == "pet")

		-- Run the custom filter method, if it exists
		local auraPriority, isFiltered
		if (customFilter) then 
			local displayAura, displayPriority, filtered = customFilter(element, true, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)

			if (displayAura) then 
				auraPriority = displayPriority
			else 
				if (unit == "player") then
					print("hiding", name)
				end
				name = nil
			end 
			isFiltered = filtered
		end 
		
		if (name) then 
			numAuras = numAuras + 1

			if (not cache[numAuras]) then
				cache[numAuras] = {}
			end

			local button = cache[numAuras]
			button.id = i
			button.isBuff = true
			button.unit = unit
			button.filter = filter
			button.name = name
			button.icon = icon
			button.count = count
			button.debuffType = debuffType
			button.duration = duration or 0
			button.expirationTime = expirationTime
			button.unitCaster = unitCaster
			button.isStealable = isStealable
			button.isBossDebuff = isBossDebuff
			button.isCastByPlayer = isCastByPlayer
			button.isOwnedByPlayer = isOwnedByPlayer
			button.auraPriority = auraPriority
			button.isFiltered = isFiltered
		end 
	end 

	-- Clear superflous entries 
	if (#cache > numAuras) then
		for i = #cache, numAuras+1,-1  do
			local button = cache[i]
			for j in pairs(button) do
				button[j] = nil
			end
		end
	end

	table_sort(cache, element.customSort or auraSortFunction)
end

local CacheDebuffs = function(element, unit, filter, customFilter)

	local cache = FullDebuffCache[element]
	local numAuras = 0

	-- Iterate helpful auras
	for i = 1, DEBUFF_MAX_DISPLAY do 

		-- Retrieve buff information
		local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = LibAura:GetUnitDebuff(unit, i, filter)

		-- No name means no more buffs matching the filter
		if (not name) then
			break
		end

		-- Figure out if the debuff is owned by us, not just cast by us
		local isOwnedByPlayer = unitCaster and (unitCaster == "player" or unitCaster == "pet")

		-- Run the custom filter method, if it exists
		local auraPriority, isFiltered
		if (customFilter) then 
			local displayAura, displayPriority, filtered = customFilter(element, false, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3)

			if (displayAura) then 
				auraPriority = displayPriority
			else 
				name = nil
			end 
			isFiltered = filtered
		end 
		
		if (name) then 
			numAuras = numAuras + 1

			if (not cache[numAuras]) then
				cache[numAuras] = {}
			end

			local button = cache[numAuras]
			button.id = i
			button.isBuff = false
			button.unit = unit
			button.filter = filter
			button.name = name
			button.icon = icon
			button.count = count
			button.debuffType = debuffType
			button.duration = duration or 0
			button.expirationTime = expirationTime
			button.unitCaster = unitCaster
			button.isStealable = isStealable
			button.isBossDebuff = isBossDebuff
			button.isCastByPlayer = isCastByPlayer
			button.isOwnedByPlayer = isOwnedByPlayer
			button.auraPriority = auraPriority
			button.isFiltered = isFiltered
		end 
	end 

	-- Clear superflous entries 
	if (#cache > numAuras) then
		for i = #cache, numAuras+1,-1  do
			local button = cache[i]
			for j in pairs(button) do
				button[j] = nil
			end
		end
	end

	table_sort(cache, element.customSort or auraSortFunction)
end

local IterateBuffs = function(element, unit, filter, visible)
	local visibleBuffs = 0 -- total number of visible buffs
	local visible = visible or 0 -- total number of visible auras so far

	-- Iterate helpful auras
	for i,cache in ipairs(FullBuffCache[element]) do 
		if (not cache.id) then
			break
		end

		-- Stop iteration if we've hit the maximum displayed 
		if (element.maxVisible and (element.maxVisible == visible)) or (element.maxBuffs and (element.maxBuffs == visibleBuffs)) then 
			break 
		end 

		visible = visible + 1
		visibleBuffs = visibleBuffs + 1

		-- Can't have frames that only are referenced by indexed table entries, 
		-- we need a hashed key or for some reason /framestack will bug out. 
		local visibleKey = tostring(visible)

		if (not element[visibleKey]) then

			-- Create a new button, and initially hide it while setting it up
			element[visibleKey] = (element.CreateButton or CreateAuraButton) (element)
			element[visibleKey]:Hide()
		end

		local button = element[visibleKey]
		button:SetID(cache.id)
		button.isBuff = cache.isBuff
		button.unit = cache.unit
		button.filter = cache.filter
		button.name = cache.name
		button.icon = cache.icon
		button.count = cache.count
		button.debuffType = cache.debuffType
		button.duration = cache.duration
		button.expirationTime = cache.expirationTime
		button.unitCaster = cache.unitCaster
		button.isStealable = cache.isStealable
		button.isBossDebuff = cache.isBossDebuff
		button.isCastByPlayer = cache.isCastByPlayer
		button.isOwnedByPlayer = cache.isOwnedByPlayer
		button.auraPriority = cache.auraPriority
		button.isFiltered = cache.isFiltered

		-- Update the icon texture
		button.Icon:SetTexture(button.icon)

		-- Update stack counts
		button.Count:SetText((button.count > 1) and button.count or "")

		-- Update timers
		Aura_SetTimer(button, button.duration, button.expirationTime)

		-- Run module post updates
		if (element.PostUpdateButton) then
			element:PostUpdateButton(button, "Iteration")
		end

		-- Show the button if it was hidden
		if (not button:IsShown()) then
			button:Show()
		end
	end 

	local offset = visible - visibleBuffs

	-- Sort them
	--local cache = DisplayCache[element]
	--for i = 1,visibleBuffs do
	--	local position = offset + i
	--	local index = tostring(position)
	--	cache[i] = element[index]
	--end
	--for i = visibleBuffs+1,#cache do
	--	cache[i] = nil
	--end
	--table_sort(cache, element.customSort or auraSortFunction)

	-- Position them all
	for i = 1,visibleBuffs do
		local position = offset + i
		local index = tostring(position)
		local button = element[index]

		-- Position the button
		SetAuraButtonPosition(element, button, position)
	end

	return visible, visibleBuffs
end

local IterateDebuffs = function(element, unit, filter, visible)

	local visibleDebuffs = 0 -- total number of visible debuffs
	local visible = visible or 0 -- total number of visible auras so far
	
	-- Iterate helpful auras
	for i,cache in ipairs(FullDebuffCache[element]) do 
		if (not cache.id) then
			break
		end

		-- Stop iteration if we've hit the maximum displayed 
		if (element.maxVisible and (element.maxVisible == visible)) or (element.maxDebuffs and (element.maxDebuffs == visibleBuffs)) then 
			break 
		end 

		visible = visible + 1
		visibleDebuffs = visibleDebuffs + 1

		-- Can't have frames that only are referenced by indexed table entries, 
		-- we need a hashed key or for some reason /framestack will bug out. 
		local visibleKey = tostring(visible)

		if (not element[visibleKey]) then

			-- Create a new button, and initially hide it while setting it up
			element[visibleKey] = (element.CreateButton or CreateAuraButton) (element)
			element[visibleKey]:Hide()
		end

		local button = element[visibleKey]
		button:SetID(cache.id)
		button.isBuff = cache.isBuff
		button.unit = cache.unit
		button.filter = cache.filter
		button.name = cache.name
		button.icon = cache.icon
		button.count = cache.count
		button.debuffType = cache.debuffType
		button.duration = cache.duration
		button.expirationTime = cache.expirationTime
		button.unitCaster = cache.unitCaster
		button.isStealable = cache.isStealable
		button.isBossDebuff = cache.isBossDebuff
		button.isCastByPlayer = cache.isCastByPlayer
		button.isOwnedByPlayer = cache.isOwnedByPlayer
		button.auraPriority = cache.auraPriority
		button.isFiltered = cache.isFiltered

		-- Update the icon texture
		button.Icon:SetTexture(button.icon)

		-- Update stack counts
		button.Count:SetText((button.count > 1) and button.count or "")

		-- Update timers
		Aura_SetTimer(button, button.duration, button.expirationTime)

		-- Run module post updates
		if (element.PostUpdateButton) then
			element:PostUpdateButton(button, "Iteration")
		end

		-- Show the button if it was hidden
		if (not button:IsShown()) then
			button:Show()
		end
	end 


	local offset = visible - visibleDebuffs

	-- Sort them
	--local cache = DisplayCache[element]
	--for i = 1,visibleDebuffs do
	--	local position = offset + i
	--	local index = tostring(position)
	--	cache[i] = element[index]
	--end
	--for i = visibleDebuffs+1,#cache do
	--	cache[i] = nil
	--end
	--table_sort(cache, element.customSort or auraSortFunction)

	-- Position them all
	for i = 1,visibleDebuffs do
		local position = offset + i
		local index = tostring(position)
		local button = element[index]

		-- Position the button
		SetAuraButtonPosition(element, button, position)
	end
	
	return visible, visibleDebuffs
end 

local EvaluateVisibilities = function(element, visible)

	-- Hide superflous buttons
	local nextAura = visible + 1
	local visibleKey = tostring(nextAura)
	while (element[visibleKey]) do
		local aura = element[visibleKey]
		aura:Hide()
		Aura_SetTimer(aura,0,0)
		nextAura = nextAura + 1
		visibleKey = tostring(nextAura)
	end

	-- Decide visibility of the whole frame
	if (visible == 0) then 
		if (element:IsShown()) then
			element:Hide()
		end
	else 
		if (not element:IsShown()) then
			element:Show()
		end
	end 
end

local Update = function(self, event, unit, ...)
	if (not unit) or (unit ~= self.unit) then 
		return 
	end 

	if (event == "PLAYER_ENTERING_WORLD") then
		IN_COMBAT = true
	elseif (event == "PLAYER_REGEN_DISABLED") then
		IN_COMBAT = true
	elseif (event == "PLAYER_REGEN_ENABLED") then
		IN_COMBAT = nil
	end

	-- Different GUID means a different player or NPC,
	-- so we want updates to be instant, not smoothed. 
	local guid = UnitGUID(unit)
	local forced = event == "Forced"

	local Auras = self.Auras
	local Buffs = self.Buffs
	local Debuffs = self.Debuffs

	if (Auras) then 
		if (Auras.PreUpdate) then
			Auras:PreUpdate(unit)
		end

		-- Store some basic values on the element
		local forced = forced or (guid ~= Auras.guid) or (not Auras.guid)
		Auras.guid = guid
		Auras.inCombat = IN_COMBAT
	
		-- Filter strings passed to the blizzard API calls
		local buffFilter = Auras.filter or Auras.filterBuffs 
		local debuffFilter = Auras.filter or Auras.filterDebuffs
		
		-- Filter functions used to filter the displayed auras
		local buffFilterFunc = Auras.func or Auras.funcBuffs 
		local debuffFilterFunc = Auras.func or Auras.funcDebuffs

		-- Force the back-end to cache the auras for the relevant filters
		if (forced) then 
			LibAura:CacheUnitBuffsByFilter(unit, buffFilter)
			LibAura:CacheUnitDebuffsByFilter(unit, debuffFilter)
		end 
	
		-- Retrieve full back-end caches for meta parsing 
		local buffCache = LibAura:GetUnitBuffCacheByFilter(unit, buffFilter)
		local debuffCache = LibAura:GetUnitDebuffCacheByFilter(unit, debuffFilter)

		-- Store meta info from the full cache,
		-- so that the sorting filters in turn have access to this.
		Auras.numAuras = buffCache.numAuras + debuffCache.numAuras
		Auras.numBuffs = buffCache.numBuffs
		Auras.numDebuffs = debuffCache.numDebuffs
		Auras.numBoss = debuffCache.numDebuffs
		Auras.numMagic = debuffCache.numDebuffs
		Auras.numCurse = debuffCache.numDebuffs
		Auras.numDisease = debuffCache.numDebuffs
		Auras.numPoison = debuffCache.numDebuffs

		-- Create local, filtered, sorted, cache copies
		CacheBuffs(Auras, unit, buffFilter, buffFilterFunc)
		CacheDebuffs(Auras, unit, debuffFilter, debuffFilterFunc)

		-- Decide what to show based on available space
		local visible, visibleBuffs, visibleDebuffs = 0, 0, 0
		if (Auras.debuffsFirst) then 
			visible, visibleDebuffs = IterateDebuffs(Auras, unit, debuffFilter, visible) 
			visible, visibleBuffs = IterateBuffs(Auras, unit, buffFilter, visible)
		else 
			visible, visibleBuffs = IterateBuffs(Auras, unit, buffFilter, visible)
			visible, visibleDebuffs = IterateDebuffs(Auras, unit, debuffFilter, visible)
		end 

		-- Add in meta-info for post updates
		Auras.visibleAuras = visible
		Auras.visibleBuffs = visibleBuffs
		Auras.visibleDebuffs = visibleDebuffs
		Auras.hasBuffs = visibleBuffs > 0
		Auras.hasDebuffs = visibleDebuffs > 0

		EvaluateVisibilities(Auras, visible)

		if (Auras.PostUpdate) then 
			Auras:PostUpdate(unit, visible)
		end 
	end 

	if (Buffs) then 
		if (Buffs.PreUpdate) then
			Buffs:PreUpdate(unit)
		end

		-- Store some basic values on the element
		local forced = forced or (guid ~= Buffs.guid) or (not Buffs.guid)
		Buffs.guid = guid
		Buffs.inCombat = IN_COMBAT

		-- Filter strings passed to the blizzard API calls
		local buffFilter = Buffs.filter or Buffs.filterBuffs 
		
		-- Filter functions used to filter the displayed auras
		local buffFilterFunc = Buffs.func or Buffs.funcBuffs 

		-- Force the back-end to cache the auras for the relevant filters
		if (forced) then 
			LibAura:CacheUnitBuffsByFilter(unit, buffFilter)
		end 

		-- Retrieve full back-end caches for meta parsing 
		local buffCache = LibAura:GetUnitBuffCacheByFilter(unit, buffFilter)

		-- Store meta info from the full cache,
		-- so that the sorting filters in turn have access to this.
		Buffs.numAuras = buffCache.numAuras
		Buffs.numBuffs = buffCache.numBuffs
		Buffs.numDebuffs = buffCache.numDebuffs
		Buffs.numBoss = buffCache.numDebuffs
		Buffs.numMagic = buffCache.numDebuffs
		Buffs.numCurse = buffCache.numDebuffs
		Buffs.numDisease = buffCache.numDebuffs
		Buffs.numPoison = buffCache.numDebuffs
		
		-- Create a local, filtered, sorted, cache copy
		CacheBuffs(Buffs, unit, buffFilter, buffFilterFunc)

		-- Decide what to show based on available space
		local visible, visibleBuffs, visibleDebuffs = 0, 0, 0
		visible, visibleBuffs = IterateBuffs(Buffs, unit, buffFilter, visible)

		-- Add in meta-info for post updates
		Buffs.visibleAuras = visible
		Buffs.visibleBuffs = visibleBuffs
		Buffs.visibleDebuffs = visibleDebuffs
		Buffs.hasBuffs = visibleBuffs > 0
		Buffs.hasDebuffs = visibleDebuffs > 0

		EvaluateVisibilities(Buffs, visible)

		if (Buffs.PostUpdate) then 
			Buffs:PostUpdate(unit, visible)
		end 
	end 

	if (Debuffs) then 
		if (Debuffs.PreUpdate) then
			Debuffs:PreUpdate(unit)
		end

		-- Store some basic values on the element
		local forced = forced or (guid ~= Debuffs.guid) or (not Debuffs.guid)
		Debuffs.guid = guid
		Debuffs.inCombat = IN_COMBAT
		
		-- Filter strings passed to the blizzard API calls
		local debuffFilter = Debuffs.filter or Debuffs.filterDebuffs
		
		-- Filter functions used to filter the displayed auras
		local debuffFilterFunc = Debuffs.func or Debuffs.funcDebuffs

		-- Force the back-end to cache the auras for the relevant filters
		if (forced) then 
			LibAura:CacheUnitDebuffsByFilter(unit, debuffFilter)
		end 

		-- Retrieve full back-end caches for meta parsing 
		local debuffCache = LibAura:GetUnitDebuffCacheByFilter(unit, debuffFilter)

		-- Store meta info from the full cache,
		-- so that the sorting filters in turn have access to this.
		Debuffs.numAuras = debuffCache.numAuras
		Debuffs.numBuffs = debuffCache.numBuffs
		Debuffs.numDebuffs = debuffCache.numDebuffs
		Debuffs.numBoss = debuffCache.numDebuffs
		Debuffs.numMagic = debuffCache.numDebuffs
		Debuffs.numCurse = debuffCache.numDebuffs
		Debuffs.numDisease = debuffCache.numDebuffs
		Debuffs.numPoison = debuffCache.numDebuffs
		
		-- Create a local, filtered, sorted, cache copy
		CacheDebuffs(Debuffs, unit, debuffFilter, debuffFilterFunc)

		-- Decide what to show based on available space
		local visible, visibleBuffs, visibleDebuffs = 0, 0, 0
		visible, visibleDebuffs = IterateDebuffs(Debuffs, unit, debuffFilter, visible)

		-- Add in meta-info for post updates
		Debuffs.visibleAuras = visible
		Debuffs.visibleBuffs = visibleBuffs
		Debuffs.visibleDebuffs = visibleDebuffs
		Debuffs.hasBuffs = visibleBuffs > 0
		Debuffs.hasDebuffs = visibleDebuffs > 0

		EvaluateVisibilities(Debuffs, visible)

		if (Debuffs.PostUpdate) then 
			Debuffs:PostUpdate(unit, visible)
		end 
	end 

end 

local Proxy = function(self, ...)
	return Update(self, ...)
end 

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local Auras = self.Auras
	local Buffs = self.Buffs
	local Debuffs = self.Debuffs

	if (Auras or Buffs or Debuffs) then
		local unit = self.unit

		if (Auras) then
			Auras._owner = self
			Auras.unit = unit
			Auras.ForceUpdate = ForceUpdate
			DisplayCache[Auras] = DisplayCache[Auras] or {}
			FullBuffCache[Auras] = FullBuffCache[Auras] or {}
			FullDebuffCache[Auras] = FullDebuffCache[Auras] or {}
		end

		if (Buffs) then
			Buffs._owner = self
			Buffs.unit = unit
			Buffs.ForceUpdate = ForceUpdate
			DisplayCache[Buffs] = DisplayCache[Buffs] or {}
			FullBuffCache[Buffs] = FullBuffCache[Buffs] or {}
		end
		
		if (Debuffs) then
			Debuffs._owner = self
			Debuffs.unit = unit
			Debuffs.ForceUpdate = ForceUpdate
			DisplayCache[Debuffs] = DisplayCache[Debuffs] or {}
			FullDebuffCache[Debuffs] = FullDebuffCache[Debuffs] or {}
		end

		local frequent = (Auras and Auras.frequent) or (Buffs and Buffs.frequent) or (Debuffs and Debuffs.frequent)
		if (frequent) then
			self:EnableFrequentUpdates("Auras", frequent)
		else
			self:RegisterMessage("GP_UNIT_AURA", Proxy)
			self:RegisterEvent("PLAYER_ENTERING_WORLD", Proxy, true)
			self:RegisterEvent("PLAYER_REGEN_DISABLED", Proxy, true)
			self:RegisterEvent("PLAYER_REGEN_ENABLED", Proxy, true)

			if (IsRetail) then
				self:RegisterEvent("UNIT_ENTERED_VEHICLE", Proxy)
				self:RegisterEvent("UNIT_ENTERING_VEHICLE", Proxy)
				self:RegisterEvent("UNIT_EXITING_VEHICLE", Proxy)
				self:RegisterEvent("UNIT_EXITED_VEHICLE", Proxy)
				self:RegisterEvent("VEHICLE_UPDATE", Proxy, true)
			end

			if (unit == "target") or (unit == "targettarget") then
				self:RegisterEvent("PLAYER_TARGET_CHANGED", Proxy, true)
			end
		end

		return true
	end
end 

local Disable = function(self)
	local Auras = self.Auras
	local Buffs = self.Buffs
	local Debuffs = self.Debuffs

	if (Auras or Buffs or Debuffs) then
	
		if (Auras) then
			Auras.unit = nil
			Auras:Hide()
			if (DisplayCache[Auras]) then 
				table_wipe(DisplayCache[Auras])
			end
			if (FullBuffCache[Auras]) then 
				table_wipe(FullBuffCache[Auras])
			end
			if (FullDebuffCache[Auras]) then 
				table_wipe(FullDebuffCache[Auras])
			end
		end
	
		if (Buffs) then
			Buffs.unit = nil
			Buffs:Hide()
			if (DisplayCache[Buffs]) then 
				table_wipe(DisplayCache[Buffs])
			end
			if (FullBuffCache[Buffs]) then 
				table_wipe(FullBuffCache[Buffs])
			end
		end
	
		if (Debuffs) then
			Debuffs.unit = nil
			Debuffs:Hide()
			if (DisplayCache[Debuffs]) then 
				table_wipe(DisplayCache[Debuffs])
			end
			if (FullDebuffCache[Debuffs]) then 
				table_wipe(FullDebuffCache[Debuffs])
			end
		end
	
		if not ((Auras and Auras.frequent) or (Buffs and Buffs.frequent) or (Debuffs and Debuffs.frequent)) then
			self:UnregisterMessage("GP_UNIT_AURA", Proxy)
			self:UnregisterEvent("PLAYER_ENTERING_WORLD", Proxy)
			self:UnregisterEvent("PLAYER_REGEN_DISABLED", Proxy)
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", Proxy)
			self:UnregisterEvent("UNIT_ENTERED_VEHICLE", Proxy)
			self:UnregisterEvent("UNIT_ENTERING_VEHICLE", Proxy)
			self:UnregisterEvent("UNIT_EXITING_VEHICLE", Proxy)
			self:UnregisterEvent("UNIT_EXITED_VEHICLE", Proxy)
			self:UnregisterEvent("VEHICLE_UPDATE", Proxy)

			if (unit == "target") or (unit == "targettarget") then
				self:UnregisterEvent("PLAYER_TARGET_CHANGED", Proxy)
			end
		end
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("Auras", Enable, Disable, Proxy, 62)
end 
