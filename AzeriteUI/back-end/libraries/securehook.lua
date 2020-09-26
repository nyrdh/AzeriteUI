local LibSecureHook = Wheel:Set("LibSecureHook", 10)
if (not LibSecureHook) then	
	return
end

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local ipairs = ipairs
local pairs = pairs
local select = select
local string_format = string.format
local string_join = string.join
local string_match = string.match
local table_insert = table.insert
local table_remove = table.remove
local type = type

LibSecureHook.embeds = LibSecureHook.embeds or {}
LibSecureHook.secureHooks = LibSecureHook.secureHooks or {}
LibSecureHook.modules = LibSecureHook.modules or {} 

local SecureHooks = LibSecureHook.secureHooks
local Modules = LibSecureHook.modules

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

local getUniqueID = function(self, uniqueID, hook)
	return uniqueID or (self:GetName()).."_"..hook
end

-- @input 
-- globalName, hook[, uniqueID]
-- globalTable, methodName, hook[, uniqueID]
LibSecureHook.ClearSecureHook = function(self, ...)
	if (type(...) == "string") then 
		local global, hook, uniqueID = ...

		check(global, 1, "string")
		check(hook, 2, "function", "string")
		check(uniqueID, 3, "string", "nil")

		local ref = _G[global]
		if (not ref) then 
			return 
		end 

		local hookList = SecureHooks[ref]
		if (hookList) then 
			if (type(hook) == "string") then 
				uniqueID = getUniqueID(self, uniqueID, hook)
				Modules[uniqueID] = nil
			end

			if (uniqueID) then
				hookList.unique[uniqueID] = nil
			else
				for id = #hookList,1,-1 do 
					local func = hookList[id]
					if (func == hook) then 
						table_remove(hookList, id)
					end 
				end 			
			end
		end 

	elseif (type(...) == "table") then 
		local global, method, hook, uniqueID = ...

		check(global, 1, "table")
		check(method, 2, "string")
		check(hook, 3, "function", "string")
		check(uniqueID, 4, "string", "nil")

		local ref = global[method]
		if (not ref) then 
			return 
		end 

		local hookList = SecureHooks[ref]
		if (hookList) then 
			if (type(hook) == "string") then 
				uniqueID = getUniqueID(self, uniqueID, hook)
				Modules[uniqueID] = nil
			end

			if (uniqueID) then
				hookList.unique[uniqueID] = nil
			else
				for id = #hookList,1,-1 do 
					local func = hookList[id]
					if (func == hook) then 
						table_remove(hookList, id)
					end 
				end 			
			end
		end

	end 
end 

-- @input 
-- globalName, hook[, uniqueID]
-- globalTable, methodName, hook[, uniqueID]
LibSecureHook.SetSecureHook = function(self, ...)
	if (type(...) == "string") then 
		local global, hook, uniqueID = ...

		check(global, 1, "string")
		check(hook, 2, "function", "string")
		check(uniqueID, 3, "string", "nil")

		local ref = _G[global]
		if (not ref) then 
			return 
		end 

		-- If the hook is a method, we need a uniqueID for our module reference list!
		if (type(hook) == "string") then 
			uniqueID = getUniqueID(self, uniqueID, hook)

			-- Reference the module
			Modules[uniqueID] = self
		end

		local hookList = SecureHooks[ref]
		if (not hookList) then 
			local list = { list = {}, unique = {} }
			local call = function(...)
				for id,func in pairs(list.unique) do 
					if (type(func) == "string") then 
						local module = Modules[id]
						if (module) then 
							module[func](module, id, ...)
						end
					else
					-- We allow unique hooks to just run a function
					-- without passing the self.
						func(...)
					end 
				end 

				-- This only ever occurs when the hook is a function, 
				-- and no uniqueID is given.
				for _,func in ipairs(list.list) do 
					func(...)
				end 
			end 
			hooksecurefunc(global, call)
			hookList = list
			SecureHooks[ref] = list
		end 

		if uniqueID then 
			hookList.unique[uniqueID] = hook
		else 
			local exists
			for _,func in ipairs(hookList.list) do 
				if (func == hook) then 
					exists = true 
					break 
				end 
			end 
			if (not exists) then 
				table_insert(hookList.list, hook)
			end 
		end 


	elseif (type(...) == "table") then 

		local global, method, hook, uniqueID = ...

		check(global, 1, "table")
		check(method, 2, "string")
		check(hook, 3, "function", "string")
		check(uniqueID, 4, "string", "nil")

		local ref = global[method]
		if (not ref) then 
			return 
		end 

		-- If the hook is a method, we need a uniqueID for our module reference list!
		if (type(hook) == "string") then 
			uniqueID = getUniqueID(self, uniqueID, hook)

			-- Reference the module
			Modules[uniqueID] = self
		end
		
		local hookList = SecureHooks[ref]
		if (not hookList) then 
			local list = { list = {}, unique = {} }
			local call = function(...)
				for id,func in pairs(list.unique) do 
					if (type(func) == "string") then 
						local module = Modules[id]
						if (module) then 
							module[func](module, id, ...)
						end
					else
						func(...)
					end 
	
				end 
				for _,func in ipairs(list.list) do 
					func(...)
				end 
			end 
			hooksecurefunc(global, method, call)
			hookList = list
			SecureHooks[ref] = list
		end 

		if uniqueID then 
			hookList.unique[uniqueID] = hook
		else 
			local exists
			for _,func in ipairs(hookList.list) do 
				if (func == hook) then 
					exists = true 
					break 
				end 
			end 
			if (not exists) then 
				table_insert(hookList.list, hook)
			end 
		end 

	end 
end 

-- Module embedding
local embedMethods = {
	SetSecureHook = true,
	ClearSecureHook = true
}

LibSecureHook.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibSecureHook.embeds) do
	LibSecureHook:Embed(target)
end
