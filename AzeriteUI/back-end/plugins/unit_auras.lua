local LibFrame = Wheel("LibFrame")
assert(LibFrame, "UnitAuras requires LibFrame to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "UnitAuras requires LibClientBuild to be loaded.")

local LibAura = Wheel("LibAura")
assert(LibAura, "UnitAuras requires LibAura to be loaded.")

-- Lua API
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
local UnitAura = UnitAura
local UnitBuff = UnitBuff
local UnitCanAttack = UnitCanAttack
local UnitDebuff = UnitDebuff
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsEnemy = UnitIsEnemy
local UnitIsFriend = UnitIsFriend
local UnitIsUnit = UnitIsUnit

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsRetail = LibClientBuild:IsRetail()

-- Blizzard Textures
local EDGE_TEXTURE = [[Interface\Cooldown\edge]]
local BLING_TEXTURE = [[Interface\Cooldown\star4]]

-- Sourced from FrameXML/BuffFrame.lua
local BUFF_MAX_DISPLAY = BUFF_MAX_DISPLAY
local DEBUFF_MAX_DISPLAY = DEBUFF_MAX_DISPLAY

-- Constants
local DAY, HOUR, MINUTE = 86400, 3600, 60
local LONG_THRESHOLD = MINUTE*3
local HZ = 1/20

-- We want to track this.
local IN_COMBAT

-- Aura Caches
local DisplayCache = {} -- display caches after custom filter and visibility limits
local BuffCache = {} -- full buff caches according to current filter
local DebuffCache = {} -- full debuff caches according to current filter

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

local auraSort = function(a,b)
	if (a) and (b) and (a.id) and (b.id) then

		-- Put auras cast by the player first.
		if (a.isCastByPlayer == b.isCastByPlayer) then

			-- If one of the auras are static
			if (a.duration == 0) or (b.duration == 0) then

				-- If both are static, sort by name
				if (a.duration == b.duration) then
					if (a.name) and (b.name) then
						return (a.name > b.name)
					end
				else
					-- Put the static one last
					return (b.duration == 0)
				end
			else

				-- If both expire at the same time
				if (a.expirationTime == b.expirationTime) then

					-- Sort by name
					if (a.name) and (b.name) then
						return (a.name > b.name)
					end
				else

					-- Sort by remaining time, first expiring first.
					return (a.expirationTime < b.expirationTime) 
				end
			end
		end
	else
		return a.isCastByPlayer
	end
end

local auraSortBuffsFirst = function(a,b)
	if (a) and (b) and (a.id) and (b.id) then

		-- Put buffs first
		if (a.isBuff == b.isBuff) then

			-- Put auras cast by the player first.
			if (a.isCastByPlayer == b.isCastByPlayer) then

				-- If one of the auras are static
				if (a.duration == 0) or (b.duration == 0) then

					-- If both are static, sort by name
					if (a.duration == b.duration) then
						if (a.name) and (b.name) then
							return (a.name > b.name)
						end
					else
						-- Put the static one last
						return (b.duration == 0)
					end
				else

					-- If both expire at the same time
					if (a.expirationTime == b.expirationTime) then

						-- Sort by name
						if (a.name) and (b.name) then
							return (a.name > b.name)
						end
					else

						-- Sort by remaining time, first expiring first.
						return (a.expirationTime < b.expirationTime) 
					end
				end
			else
				return a.isCastByPlayer
			end

		else
			return a.isBuff
		end
	end
end

local auraSortDebuffsFirst = function(a,b)
	if (a) and (b) and (a.id) and (b.id) then

		-- Put buffs first
		if (a.isBuff == b.isBuff) then

			-- Put auras cast by the player first.
			if (a.isCastByPlayer == b.isCastByPlayer) then

				-- If one of the auras are static
				if (a.duration == 0) or (b.duration == 0) then

					-- If both are static, sort by name
					if (a.duration == b.duration) then
						if (a.name) and (b.name) then
							return (a.name > b.name)
						end
					else
						-- Put the static one last
						return (b.duration == 0)
					end
				else

					-- If both expire at the same time
					if (a.expirationTime == b.expirationTime) then

						-- Sort by name
						if (a.name) and (b.name) then
							return (a.name > b.name)
						end
					else

						-- Sort by remaining time, first expiring first.
						return (a.expirationTime < b.expirationTime) 
					end
				end
			else
				return a.isCastByPlayer
			end

		else
			return (not a.isBuff)
		end
	end
end

-- Table cache system.
-- Note that all tables here are assumed to be regular tables,
-- so any frames, textures or fontstrings inserted WILL cause bugs.
local tables = {} -- Our local cache. We ignore other plugin versions.
local get,give,clear -- They might need to call themselves, so define here!

clear = function(tbl)
	if (not tbl) then
		return
	end
	-- Return any sub-tables
	-- to our cache.
	for i,v in pairs(tbl) do
		if (type(v) == "table") then
			give(v)
		end
	end
	-- Clear the references.
	for i,v in pairs(tbl) do
		tbl[i] = nil
	end
	-- Return the cleared table
	return tbl
end

give = function(tbl)
	if (not tbl) then
		return
	end
	table_insert(tables, clear(tbl))
end

get = function(tbl)
	return tbl and clear(tbl) or table_remove(tables) or {}
end

-- Aura Button Template
-----------------------------------------------------
local Aura = {}

Aura.CreateButton = function(element)

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
	cooldown:SetEdgeTexture(EDGE_TEXTURE)
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
		button:SetScript("OnEnter", Aura.OnEnter)
		button:SetScript("OnLeave", Aura.OnLeave)
		button:SetScript("OnClick", Aura.OnClick)
		button:SetScript("PreClick", Aura.PreClick)
		button:SetScript("PostClick", Aura.PostClick)
	end 

	return button
end 

Aura.OnEnter = function(button)
	if (button.OnEnter) then 
		return button:OnEnter()
	end 
	button.isMouseOver = true
	button.UpdateTooltip = Aura.UpdateTooltip
	button:UpdateTooltip()
	if (button.PostEnter) then 
		return button:PostEnter()
	end 
end

Aura.OnLeave = function(button)
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

Aura.OnClick = function(button, buttonPressed, down)
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

Aura.PreClick = function(button, buttonPressed, down)
	if (button.PreClick) then 
		return button:PreClick(buttonPressed, down)
	end 
end 

Aura.PostClick = function(button, buttonPressed, down)
	if (button.PostClick) then 
		return button:PostClick(buttonPressed, down)
	end 
end 

Aura.SetCooldownTimer = function(button, start, duration)
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

Aura.SetTimer = function(button, fullDuration, expirationTime)
	if (fullDuration) and (fullDuration > 0) then
		button.fullDuration = fullDuration
		button.timeStarted = expirationTime - fullDuration
		button.timeLeft = expirationTime - GetTime()
		button:SetScript("OnUpdate", Aura.UpdateTimer)
		Aura.SetCooldownTimer(button, button.timeStarted, button.fullDuration)
	else
		button:SetScript("OnUpdate", nil)
		Aura.SetCooldownTimer(button, 0,0)
		button.Time:SetText("")
		button.fullDuration = 0
		button.timeStarted = 0
		button.timeLeft = 0
	end
	if (button:IsShown()) and (button._owner.PostUpdateButton) then
		button._owner:PostUpdateButton(button, "Timer")
	end
end

Aura.SetPosition = function(element, button, buttonNum)

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

Aura.UpdateTooltip = function(button)
	local tooltip = button:GetTooltip()
	tooltip:Hide()
	tooltip:SetMinimumWidth(160)
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

Aura.UpdateTimer = function(button, elapsed)
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
				Aura.SetCooldownTimer(button, 0,0)
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

-- Aura Iterations
-----------------------------------------------------
local CacheBuffs = function(element)

	local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3

	local cache = element.cache or get()

	for i = 1, BUFF_MAX_DISPLAY do 

		name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = LibAura:GetUnitBuff(element.unit, i, element.filter)

		if (not name) then
			break
		end

		local entry = get()
		entry.isBuff = true
		entry.id = i
		entry.unit = element.unit
		entry.filter = element.filter
		entry.isOwnedByPlayer = unitCaster and (unitCaster == "player" or unitCaster == "pet")
		entry.name = name
		entry.icon = icon
		entry.count = count
		entry.debuffType = debuffType
		entry.duration = duration or 0
		entry.expirationTime = expirationTime
		entry.unitCaster = unitCaster
		entry.isStealable = isStealable
		entry.nameplateShowPersonal = nameplateShowPersonal
		entry.spellId = spellId
		entry.canApplyAura = canApplyAura
		entry.isBossDebuff = isBossDebuff
		entry.isCastByPlayer = isCastByPlayer
		entry.nameplateShowAll = nameplateShowAll
		entry.timeMod = timeMod
		entry.value1 = value1
		entry.value2 = value2
		entry.value3 = value3

		cache[#cache + 1] = entry
	end 

	element.cache = cache

end

local CacheDebuffs = function(element)

	local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3

	local cache = element.cache or get()

	for i = 1, DEBUFF_MAX_DISPLAY do 

		name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = LibAura:GetUnitDebuff(element.unit, i, element.filter)

		if (not name) then
			break
		end
		
		local entry = get()
		entry.isBuff = false
		entry.id = i
		entry.unit = element.unit
		entry.filter = element.filter
		entry.isOwnedByPlayer = unitCaster and (unitCaster == "player" or unitCaster == "pet")
		entry.name = name
		entry.icon = icon
		entry.count = count
		entry.debuffType = debuffType
		entry.duration = duration or 0
		entry.expirationTime = expirationTime
		entry.unitCaster = unitCaster
		entry.isStealable = isStealable
		entry.nameplateShowPersonal = nameplateShowPersonal
		entry.spellId = spellId
		entry.canApplyAura = canApplyAura
		entry.isBossDebuff = isBossDebuff
		entry.isCastByPlayer = isCastByPlayer
		entry.nameplateShowAll = nameplateShowAll
		entry.timeMod = timeMod
		entry.value1 = value1
		entry.value2 = value2
		entry.value3 = value3

		cache[#cache + 1] = entry
	end 

	element.cache = cache

end

local Iterate = function(element)
	if (not element.cache) then
		return
	end

	for i,entry in ipairs(element.cache) do 
		if (entry.id) then

			local hideAura
			local auraPriority
			
			if (element.customFilter) then 
				local displayAura, displayPriority = element:customFilter(
					entry.isBuff, 
					entry.unit, 
					entry.isOwnedByPlayer, 
					entry.name, 
					entry.icon, 
					entry.count, 
					entry.debuffType, 
					entry.duration, 
					entry.expirationTime, 
					entry.unitCaster, 
					entry.isStealable, 
					entry.nameplateShowPersonal, 
					entry.spellId, 
					entry.canApplyAura, 
					entry.isBossDebuff, 
					entry.isCastByPlayer, 
					entry.nameplateShowAll, 
					entry.timeMod, 
					entry.value1, 
					entry.value2, 
					entry.value3
				)
				if (displayAura) then 
					auraPriority = displayPriority
				else 
					hideAura = true
				end 
			end 

			-- Stop iteration if we've hit the maximum displayed allowed.
			if (element.maxVisible and (element.maxVisible == element.visibleAuras)) then
				break 
			end 

			if (not hideAura) then 

				-- We can have reached the max of buffs or debuffs, yet have space for the opposite.
				-- So we check whether or not we should display each single aura.
				local skip = ((element.maxBuffs) and (entry.isBuff) and (element.maxBuffs == element.visibleBuffs)) 
						or ((element.maxDebuffs) and (not entry.isBuff) and (element.maxDebuffs == element.visibleDebuffs))  

				-- Go ahead and display this button.
				if (not skip) then 
					-- Increase the total visible counter
					element.visibleAuras = element.visibleAuras + 1

					-- Increase the other counters
					if (entry.isBuff) then 
						element.visibleBuffs = element.visibleBuffs + 1
					else
						element.visibleDebuffs = element.visibleDebuffs + 1
					end

					-- Can't have frames that only are referenced by indexed table entries, 
					-- we need a hashed key or for some reason /framestack will bug out. 
					local visibleKey = tostring(element.visibleAuras)

					-- Create a new button, and initially hide it while setting it up
					if (not element[visibleKey]) then
						element[visibleKey] = (element.CreateButton or Aura.CreateButton) (element)
						element[visibleKey]:Hide()
					end

					local button = element[visibleKey]
					button:SetID(entry.id)
					button.isBuff = entry.isBuff
					button.unit = entry.unit
					button.filter = entry.filter
					button.name = entry.name
					button.icon = entry.icon
					button.count = entry.count
					button.debuffType = entry.debuffType
					button.duration = entry.duration
					button.expirationTime = entry.expirationTime
					button.unitCaster = entry.unitCaster
					button.isStealable = entry.isStealable
					button.isBossDebuff = entry.isBossDebuff
					button.isCastByPlayer = entry.isCastByPlayer
					button.isOwnedByPlayer = entry.isOwnedByPlayer
					button.auraPriority = auraPriority

					-- Update the icon texture
					button.Icon:SetTexture(button.icon)

					-- Update stack counts
					button.Count:SetText((button.count > 1) and button.count or "")

					-- Update timers
					Aura.SetTimer(button, button.duration, button.expirationTime)

					-- Run module post updates
					if (element.PostUpdateButton) then
						element:PostUpdateButton(button, "Iteration")
					end

					-- Show the button if it was hidden
					if (not button:IsShown()) then
						button:Show()
					end
				end

			end

		end
	end 

	-- Position them all
	--*Why on earth would this bug out?
	for i = 1,element.visibleAuras do
		local visibleKey = tostring(i)
		local button = element[visibleKey]
		if (button) then
			Aura.SetPosition(element, button, i)
		end
	end
end

local EvaluateVisibilities = function(element, visible)

	-- Hide superflous buttons
	local nextAura = visible + 1
	local visibleKey = tostring(nextAura)
	while (element[visibleKey]) do
		local aura = element[visibleKey]
		aura:Hide()
		Aura.SetTimer(aura,0,0)
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

	-- Always process these flags
	if (event == "PLAYER_ENTERING_WORLD") or (event == "PLAYER_REGEN_ENABLED") then
		IN_COMBAT = nil
	elseif (event == "PLAYER_REGEN_DISABLED") then
		IN_COMBAT = true
	end

	-- Bail out on missing unit, which should never happen, but does.
	if (not unit) or (unit ~= self.unit) then 
		return 
	end 

	local isEnemy = UnitCanAttack("player", unit)
	local isFriend = UnitIsFriend("player", unit)
	local isYou = UnitIsUnit("player", unit)

	local Auras = self.Auras
	local Buffs = self.Buffs
	local Debuffs = self.Debuffs

	if (Auras) then 
		if (Auras.PreUpdate) then
			Auras:PreUpdate(unit)
		end

		-- Cache everything.
		clear(Auras.cache)
		CacheBuffs(Auras)
		CacheDebuffs(Auras)

		local cache = Auras.cache
		local customFilter = Auras.customFilter
		local numTotal, numBuffs, numDebuffs = #cache, 0, 0
		local numBoss, numMagic, numCurse, numDisease, numPoison = 0, 0, 0, 0, 0
		local visible, visibleBuffs, visibleDebuffs = 0, 0, 0

		-- Parse the cached auras for meta info. 
		for i,entry in ipairs(cache) do
			if (entry.isBossDebuff) then
				numBoss = numBoss + 1
			end
			if (entry.isBuff) then
				numBuffs = numBuffs + 1
			else
				numDebuffs = numDebuffs + 1
				local debuffType = entry.debuffType
				if (debuffType == "Magic") then
					numMagic = numMagic + 1
				elseif (debuffType == "Curse") then
					numCurse = numCurse + 1
				elseif (debuffType == "Disease") then
					numDisease = numDisease + 1
				elseif (debuffType == "Poison") then
					numPoison = numPoison + 1
				end
			end
		end

		-- Store the meta info for the sorting filters.
		Auras.inCombat = IN_COMBAT
		Auras.isEnemy = isEnemy
		Auras.isFriend = isFriend
		Auras.isYou = isYou
		Auras.numAuras = numTotal
		Auras.numBuffs = numBuffs
		Auras.numDebuffs = numDebuffs
		Auras.numBoss = numBoss
		Auras.numMagic = numMagic
		Auras.numCurse = numCurse
		Auras.numDisease = numDisease
		Auras.numPoison = numPoison

		-- Do some initial sorting
		table_sort(cache, (Auras.debuffsFirst) and auraSortDebuffsFirst or auraSortBuffsFirst)

		-- Reset counters
		Auras.visibleAuras = 0
		Auras.visibleBuffs = 0
		Auras.visibleDebuffs = 0

		-- Run filtered iteration
		Iterate(Auras)

		-- Evaluate if the element should be shown
		EvaluateVisibilities(Auras, Auras.visibleAuras)

		if (Auras.PostUpdate) then 
			Auras:PostUpdate(unit, Auras.visibleAuras)
		end 
	end 

	if (Buffs) then
		if (Buffs.PreUpdate) then
			Buffs:PreUpdate(unit)
		end

		-- Cache everything.
		clear(Buffs.cache)
		CacheBuffs(Buffs)

		local cache = Buffs.cache
		local numTotal, numBuffs, numDebuffs = #cache, 0, 0
		local numBoss, numMagic, numCurse, numDisease, numPoison = 0, 0, 0, 0, 0
		local visible, visibleBuffs, visibleDebuffs = 0, 0, 0

		-- Parse the cached auras for meta info. 
		for i,entry in ipairs(cache) do
			if (entry.isBossDebuff) then
				numBoss = numBoss + 1
			end
			if (entry.isBuff) then
				numBuffs = numBuffs + 1
			else
				numDebuffs = numDebuffs + 1
				local debuffType = entry.debuffType
				if (debuffType == "Magic") then
					numMagic = numMagic + 1
				elseif (debuffType == "Curse") then
					numCurse = numCurse + 1
				elseif (debuffType == "Disease") then
					numDisease = numDisease + 1
				elseif (debuffType == "Poison") then
					numPoison = numPoison + 1
				end
			end
		end

		-- Store the meta info for the sorting filters.
		Buffs.inCombat = IN_COMBAT
		Buffs.isEnemy = isEnemy
		Buffs.isFriend = isFriend
		Buffs.isYou = isYou
		Buffs.numAuras = numTotal
		Buffs.numBuffs = numBuffs
		Buffs.numDebuffs = numDebuffs
		Buffs.numBoss = numBoss
		Buffs.numMagic = numMagic
		Buffs.numCurse = numCurse
		Buffs.numDisease = numDisease
		Buffs.numPoison = numPoison

		-- Do some initial sorting
		table_sort(cache, auraSortBuffsFirst)

		-- Reset counters
		Buffs.visibleAuras = 0
		Buffs.visibleBuffs = 0
		Buffs.visibleDebuffs = 0

		-- Run filtered iteration
		Iterate(Buffs)

		-- Evaluate if the element should be shown
		EvaluateVisibilities(Buffs, Buffs.visibleAuras)

		if (Buffs.PostUpdate) then 
			Buffs:PostUpdate(unit, Buffs.visibleAuras)
		end 
	end 

	if (Debuffs) then 
		if (Debuffs.PreUpdate) then
			Debuffs:PreUpdate(unit)
		end

		-- Cache everything.
		clear(Debuffs.cache)
		CacheDebuffs(Debuffs)

		local cache = Debuffs.cache
		local numTotal, numBuffs, numDebuffs = #cache, 0, 0
		local numBoss, numMagic, numCurse, numDisease, numPoison = 0, 0, 0, 0, 0
		local visible, visibleBuffs, visibleDebuffs = 0, 0, 0

		-- Parse the cached auras for meta info. 
		for i,entry in ipairs(cache) do
			if (entry.isBossDebuff) then
				numBoss = numBoss + 1
			end
			if (entry.isBuff) then
				numBuffs = numBuffs + 1
			else
				numDebuffs = numDebuffs + 1
				local debuffType = entry.debuffType
				if (debuffType == "Magic") then
					numMagic = numMagic + 1
				elseif (debuffType == "Curse") then
					numCurse = numCurse + 1
				elseif (debuffType == "Disease") then
					numDisease = numDisease + 1
				elseif (debuffType == "Poison") then
					numPoison = numPoison + 1
				end
			end
		end

		-- Store the meta info for the sorting filters.
		Debuffs.inCombat = IN_COMBAT
		Debuffs.isEnemy = isEnemy
		Debuffs.isFriend = isFriend
		Debuffs.isYou = isYou
		Debuffs.numAuras = numTotal
		Debuffs.numBuffs = numBuffs
		Debuffs.numDebuffs = numDebuffs
		Debuffs.numBoss = numBoss
		Debuffs.numMagic = numMagic
		Debuffs.numCurse = numCurse
		Debuffs.numDisease = numDisease
		Debuffs.numPoison = numPoison

		-- Do some initial sorting
		table_sort(cache, auraSortDebuffsFirst)

		-- Reset counters
		Debuffs.visibleAuras = 0
		Debuffs.visibleBuffs = 0
		Debuffs.visibleDebuffs = 0

		-- Run filtered iteration
		Iterate(Debuffs)

		-- Evaluate if the element should be shown
		EvaluateVisibilities(Debuffs, Debuffs.visibleAuras)

		if (Debuffs.PostUpdate) then 
			Debuffs:PostUpdate(unit, Debuffs.visibleAuras)
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
			BuffCache[Auras] = BuffCache[Auras] or {}
			DebuffCache[Auras] = DebuffCache[Auras] or {}
		end

		if (Buffs) then
			Buffs._owner = self
			Buffs.unit = unit
			Buffs.ForceUpdate = ForceUpdate
			DisplayCache[Buffs] = DisplayCache[Buffs] or {}
			BuffCache[Buffs] = BuffCache[Buffs] or {}
		end
		
		if (Debuffs) then
			Debuffs._owner = self
			Debuffs.unit = unit
			Debuffs.ForceUpdate = ForceUpdate
			DisplayCache[Debuffs] = DisplayCache[Debuffs] or {}
			DebuffCache[Debuffs] = DebuffCache[Debuffs] or {}
		end

		local frequent = (Auras and Auras.frequent) or (Buffs and Buffs.frequent) or (Debuffs and Debuffs.frequent)
		if (frequent) then
			self:EnableFrequentUpdates("Auras", frequent)
		else
			self:RegisterEvent("UNIT_AURA", Proxy)
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
			if (BuffCache[Auras]) then 
				table_wipe(BuffCache[Auras])
			end
			if (DebuffCache[Auras]) then 
				table_wipe(DebuffCache[Auras])
			end
		end
	
		if (Buffs) then
			Buffs.unit = nil
			Buffs:Hide()
			if (DisplayCache[Buffs]) then 
				table_wipe(DisplayCache[Buffs])
			end
			if (BuffCache[Buffs]) then 
				table_wipe(BuffCache[Buffs])
			end
		end
	
		if (Debuffs) then
			Debuffs.unit = nil
			Debuffs:Hide()
			if (DisplayCache[Debuffs]) then 
				table_wipe(DisplayCache[Debuffs])
			end
			if (DebuffCache[Debuffs]) then 
				table_wipe(DebuffCache[Debuffs])
			end
		end
	
		if not ((Auras and Auras.frequent) or (Buffs and Buffs.frequent) or (Debuffs and Debuffs.frequent)) then
			self:UnregisterEvent("UNIT_AURA", Proxy)
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
	Lib:RegisterElement("Auras", Enable, Disable, Proxy, 71)
end 
