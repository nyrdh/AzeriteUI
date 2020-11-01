local LibForge = Wheel:Set("LibForge", 9)
if (not LibForge) then
	return
end

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local ipairs = ipairs
local math_floor = math.floor
local pairs = pairs
local select = select
local string_find = string.find
local string_format = string.format
local string_join = string.join
local string_match = string.match
local string_split = string.split
local table_insert = table.insert
local tonumber = tonumber
local type = type
local unpack = unpack

-- Library registries
LibForge.embeds = LibForge.embeds or {}

-- Track current object without passing or storing it
local CURRENT_OBJECT

----------------------------------------------------------------
-- Utility Functions
----------------------------------------------------------------
-- Syntax check 
local check = function(value, num, ...)
	assert(type(num) == "number", ("Bad argument #%.0f to '%s': %s expected, got %s"):format(2, "Check", "number", type(num)))
	for i = 1,select("#", ...) do
		if type(value) == select(i, ...) then 
			return 
		end
	end
	local types = string_join(", ", ...)
	local name = string_match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
	error(string_format("Bad argument #%.0f to '%s': %s expected, got %s", num, name, types, type(value)), 3)
end

-- Find an object based on a source object and a path of comma-separated keys.
local trackParentKeys = function(object, path)
	local target = object
	if (path) then 
		if (string_find(path, ",")) then
			local trail = { string_split(",", path) }
			for _,nextPath in ipairs(trail) do
				if (nextPath == "self") then
					target = object
				else
					target = target[nextPath]
				end
			end
		else
			if (path == "self") then
				target = object
			else
				target = target[path]
			end
		end
	end
	return target or object
end

-- Unpack tables consisting of arguments,
-- but avoid attempting to unpack textures, fontstrings or frames.
local parseArguments = function(args)
	if (type(args) == "table") and (not args.GetObjectType) then
		return unpack(args)
	else
		return args
	end
end

-- Check for object type and existence, all in one.
local isObjectType = function(widget, objectType)
	return (widget) and (objectType) and (widget.IsObjectType) and (widget:IsObjectType(objectType))
end

----------------------------------------------------------------
-- Methods
----------------------------------------------------------------
-- Custom methods to ease the widget styling.
-- A return value indicates this method had no input arguments, 
-- and affects how the Chain function progresses towards the next method.
local WidgetMethods = {
	ClearAllPoints = function(widget)
		widget:ClearAllPoints()
		return true
	end,
	ClearTexture = function(widget)
		widget:SetTexture("")
		return true
	end,
	SetAllPointsToParent = function(widget)
		widget:SetAllPoints()
		return true
	end,
	SetAllPointsToParentKey = function(widget, parentKey)
		widget:SetAllPoints(trackParentKeys(widget:GetParent(), parentKey))
	end,
	SetCheckedTextureBlendMode = function(widget, ...)
		widget:GetCheckedTexture():SetBlendMode(...)
	end,
	SetCheckedTextureDrawLayer = function(widget, ...)
		widget:GetCheckedTexture():SetDrawLayer(...)
	end,
	SetCheckedTextureKey = function(widget, parentKey)
		widget:SetCheckedTexture(trackParentKeys(widget, parentKey))
	end,
	SetCheckedTextureMask = function(widget, ...)
		widget:GetCheckedTexture():SetMask(...)
	end,
	SetFrameLevelOffset = function(widget, offset)
		widget:SetFrameLevel(widget:GetParent():GetFrameLevel() + offset)
	end,
	SetHidden = function(widget)
		widget:Hide()
		return true
	end,
	SetHitBox = function(widget, ...)
		widget:SetHitRectInsets(...)
	end,
	SetParentToOwnerKey = function(widget, ownerKey)
		if (CURRENT_OBJECT) then
			local parent = trackParentKeys(CURRENT_OBJECT, ownerKey)
			if (parent) then
				widget:SetParent(parent)
			end
		end
	end,
	SetPosition = function(widget, ...)
		if (type((...)) == "function") then
			local func = ...
			func(widget, CURRENT_OBJECT, select(2, ...))
		else
			widget:ClearAllPoints()
			widget:SetPoint(...)
		end
	end,
	SetPushedTextureBlendMode = function(widget, ...)
		widget:GetPushedTexture():SetBlendMode(...)
	end,
	SetPushedTextureDrawLayer = function(widget, ...)
		widget:GetPushedTexture():SetDrawLayer(...)
	end,
	SetPushedTextureMask = function(widget, ...)
		widget:GetPushedTexture():SetMask(...)
	end,
	SetPushedTextureKey = function(widget, parentKey)
		widget:SetPushedTexture(trackParentKeys(widget, parentKey))
	end,
	SetSizeOffset = function(widget, offsetX, offsetY)
		local width, height = widget:GetParent():GetSize()
		local newWidth = math_floor(width + .5) + offsetX
		local newHeight = math_floor(height + .5) + (offsetY or offsetX)
		widget:SetSize(newWidth, newHeight)
	end
}

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------
-- Perform multiple methods to a widget at once.
-- This also accepts custom method names as listed above.
LibForge.Chain = function(self, widget, chaindata) 
	check(widget, 1, "table", "nil")
	check(chaindata, 2, "table", "nil")

	-- Silently fail if not data is passed.
	if (not widget) or (not chaindata) then
		return
	end

	local numArgs = #chaindata
	local currentArg = 1
	local func, method, args
	while (currentArg <= numArgs) do
		local noInputArgs
		method, args = chaindata[currentArg], chaindata[currentArg + 1]
		if (type(method) == "string") then
			if (WidgetMethods[method]) then
				noInputArgs = WidgetMethods[method](widget, parseArguments(args))
			else
				func = widget[method]
				if (func) then
					func(widget, parseArguments(args))
				end
			end
		elseif (type(method) == "function") then
			method(widget, parseArguments(args))
		end
		currentArg = currentArg + (noInputArgs and 1 or 2)
	end
end

-- Apply a list of values to a widget.
-- String values will be keyword parsed.
LibForge.Decorate = function(self, widget, values, ...)
	check(widget, 1, "table", "nil")
	check(values, 2, "table", "nil")

	-- Silently fail if not data is passed.
	if (not widget) or (not values) then
		return
	end

	local key,value
	local currentValue, numValues = 1, #values
	while (currentValue < numValues) do
		key,value = values[currentValue], values[currentValue + 1]
		
		if (type(value) == "string") then
			if (value == ":MODULE:") then 
				value = self
			else
				local paramID = tonumber(string_match(value, ":PARAM(%d+):"))
				if (paramID) then
					value = select(paramID, ...)
				end
			end
		end
		
		widget[key] = value
		currentValue = currentValue + 2
	end
end

-- Widget forge.
LibForge.Forge = function(self, object, forgedata, ...)
	check(object, 1, "table", "nil")
	check(forgedata, 2, "table", "nil")

	-- Assume this is embedded into something 
	-- that wishes to do some self-forging.
	if (object) and (not forgedata) then
		forgedata = object
		object = self
	end

	-- Silently fail if not data is passed.
	if (not forgedata) then
		return
	end

	-- Set the current object
	CURRENT_OBJECT = object

	-- Iterate workorders in the forgedata
	for _,workorder in ipairs(forgedata) do
		if (workorder) then

			-- Workorder is to create widgets
			if (workorder.type == "CreateWidgets") then

				-- Iterate widgets to be created or modelled
				for _,item in ipairs(workorder.widgets) do
					if (item) then

						-- This will hold the widget
						local widget

						-- This will be the parent, if creation is needed.
						local parent 

						-- Figure out who the parent is
						local owner = object -- this is always the owner
						if (item.parent) and ((item.ownerKey) or (item.parentKey)) then
							parent = trackParentKeys(owner, item.parent) -- the parent can differ

							-- Check if the widget already exists, as we're only going to modify this time, not create.
							local oldWidget = item.ownerKey and owner[item.ownerKey] or item.parentKey and parent[item.parentKey]
							if (isObjectType(oldWidget, item.objectType)) then
								widget = oldWidget
							end
						else
							-- When parent and keys are omitted,
							-- we assume we are modifying the object itself. 
							widget = object
						end
						
						-- Skip it if a dependency fails.
						local dependencyFailed
						if (item.ownerDependencyKey) then
							local key = trackParentKeys(owner, item.ownerDependencyKey)
							if (not key) then
								widget = nil
								dependencyFailed = true
							end
						end

						-- Skip this if a dependency check failed.
						if (not dependencyFailed) then

							-- Create the widget if it doesn't exist, or exist of the wrong type.
							if (not widget) then
								if (item.objectType == "Texture") then
									widget = parent:CreateTexture()

								elseif (item.objectType == "FontString") then
									widget = parent:CreateFontString()

								elseif (item.objectType == "Frame") then
									if (item.objectSubType == "StatusBar") and (parent.CreateStatusBar) then
										widget = parent:CreateStatusBar()
									else
										widget = parent:CreateFrame(item.objectSubType, item.objectName, item.objectTemplate)
									end
								end
							else
								-- Object may exist at the right key relative to its indended parent, 
								-- but with the wrong parent. Fix it if that is the case.
								if (item.parent) then
									widget:SetParent(parent)
								end
							end

							-- This may not exist, we could've had an invalid parent or key, 
							-- or could be a failed dependency causing it not to be created,
							-- or could even be a widget type not currently supported by the forge.
							if (widget) then

								-- Apply any methods
								self:Chain(widget, item.chain) 

								-- Assign values
								self:Decorate(widget, item.values, ...) 
							
								-- Key the widget to its owner or parent.
								-- This should only happen in widget creation, not modification.
								if (item.ownerKey) then
									owner[item.ownerKey] = widget
								elseif (item.parentKey) then
									parent[item.parentKey] = widget
								end

							end
						end
					end
				end
			
			elseif (workorder.type == "ModifyWidgets") then

				-- Iterate widgets to be created or modelled
				for _,item in ipairs(workorder.widgets) do
					if (item) then

						-- This will hold the widget
						local widget  

						-- Figure out where the widget is
						local owner = object -- this is always the owner
						if (item.parent) and (item.ownerKey or item.parentKey) then
							local parent
							if (item.parent and item.parentKey) then
								parent = trackParentKeys(owner, item.parent) -- the parent can differ
							end

							-- Check if the widget already exists, as we're only going to modify this time, not create.
							local oldWidget
							if (item.ownerKey) then
								oldWidget = trackParentKeys(owner, item.ownerKey)
							elseif (parent) and (item.parentKey) then
								oldWidget = trackParentKeys(parent, item.parentKey)
							end
							if (isObjectType(oldWidget, item.objectType)) then
								widget = oldWidget
							end

						elseif (item.ownerKey) then

							local oldWidget
							if (item.ownerKey) then
								oldWidget = trackParentKeys(owner, item.ownerKey)
							end
							if (isObjectType(oldWidget, item.objectType)) then
								widget = oldWidget
							end

						else
							-- When parent and keys are omitted,
							-- we assume we are modifying the object itself. 
							widget = object
						end

						-- Skip it if a dependency fails.
						if (item.ownerDependencyKey) then
							local key = trackParentKeys(owner, item.ownerDependencyKey)
							if (not key) then
								widget = nil
							end
						end

						-- This may not exist, we could've had an invalid parent or key.
						if (widget) then

							-- Object may exist at the right key relative to its indended parent, 
							-- but with the wrong parent. Fix it if that is the case.
							if (item.parent) then
								local parent = trackParentKeys(owner, item.parent)
								if (parent) then
									widget:SetParent(parent)
								end
							end

							-- Apply any methods
							self:Chain(widget, item.chain) 

							-- Assign values
							self:Decorate(widget, item.values, ...) 

						end

					end
				end
		
			elseif (workorder.type == "ExecuteMethods") then

				-- Iterate widgets to be created or modelled
				for _,item in ipairs(workorder.methods) do
					if (item) then
						if (item.repeatAction) then
							local method = item.repeatAction.method
							for _,args in ipairs(item.repeatAction.arguments) do
								object[method](object, parseArguments(args))
							end
						end

						-- Apply any methods
						self:Chain(object, item.chain) 

						-- Assign values
						self:Decorate(object, item.values, ...) 
					end
				end
			end

		end
	end

	-- Clear the current object.
	-- Do not return or stop parsing before this. 
	CURRENT_OBJECT = nil

	-- Let this indicate a success 
	return true
end

local embedMethods = {
	Chain = true, 
	Decorate = true,
	Forge = true
}

LibForge.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibForge.embeds) do
	LibForge:Embed(target)
end
