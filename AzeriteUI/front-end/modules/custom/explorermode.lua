local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Explorer Mode
local Module = Core:NewModule("ExplorerMode", "PLUGIN", "LibMessage", "LibEvent", "LibDB", "LibFader")

Module.SetAttachExplorerFrame = function(self, moduleName, isAttached)
	local module = Core:GetModule(moduleName, true)
	if (module) and not(module:IsUserDisabled() or module:IsIncompatible() or module:DependencyFailed()) then 
		local method = isAttached and "RegisterObjectFade" or "UnregisterObjectFade"
		if (module.GetExplorerModeFrameAnchors) then
			for _,frame in ipairs({ module:GetExplorerModeFrameAnchors() }) do
				self[method](self, frame)
			end
		else
			local frame = module:GetFrame()
			if (frame) then 
				self[method](self, frame)
			end
		end
	end 
end 

Module.UpdateSettings = function(self)
	local db = self.db
	local cache = self.cacheDB

	self:SetAttachExplorerFrame("ActionBarMain", db.enableExplorer)
	self:SetAttachExplorerFrame("UnitFramePlayer", db.enableExplorer)
	self:SetAttachExplorerFrame("UnitFramePet", db.enableExplorer)
	--self:SetAttachExplorerFrame("BlizzardObjectivesTracker", db.enableTrackerFading)

	-- Forge driven system
	self:SetAttachExplorerFrame("ModuleForge::UnitFrames", db.enableExplorer) 

	if (db.enableExplorer) and (not cache.enableExplorer) then
		self:SendMessage("GP_EXPLORER_MODE_ENABLED")
		cache.enableExplorer = true

	elseif (not db.enableExplorer) and ((cache.enableExplorer) or (cache.enableExplorer == nil)) then
		self:SendMessage("GP_EXPLORER_MODE_DISABLED")
		cache.enableExplorer = false
	end 

	if (db.enableTrackerFading) and (not cache.enableTrackerFading) then
		self:SendMessage("GP_TRACKER_EXPLORER_MODE_ENABLED")
		cache.enableTrackerFading = true

	elseif (not db.enableTrackerFading) and ((cache.enableTrackerFading) or (cache.enableTrackerFading == nil)) then
		self:SendMessage("GP_TRACKER_EXPLORER_MODE_DISABLED")
		cache.enableTrackerFading = false
	end 

	if (db.enableExplorerChat) and (not cache.enableExplorerChat) then
		self:SendMessage("GP_EXPLORER_CHAT_ENABLED")
		cache.enableExplorerChat = true

	elseif (not db.enableExplorerChat) and ((cache.enableExplorerChat) or (cache.enableExplorerChat == nil)) then
		self:SendMessage("GP_EXPLORER_CHAT_DISABLED")
		cache.enableExplorerChat = false
	end
end

Module.OnInit = function(self)
	self.db = Private.GetConfig(self:GetName())
	self.cacheDB = {} -- Create a cache so we only ever update changed values

	local OptionsMenu = Core:GetModule("OptionsMenu", true)
	if (OptionsMenu) then
		local callbackFrame = OptionsMenu:CreateCallbackFrame(self)
		callbackFrame:AssignProxyMethods("UpdateSettings")
		callbackFrame:AssignSettings(self.db)
		callbackFrame:AssignCallback([=[
			if (not name) then
				return 
			end 
			name = string.lower(name); 
			if (name == "change-enableexplorer") then 
				self:SetAttribute("enableExplorer", value); 
				self:CallMethod("UpdateSettings"); 

			elseif (name == "change-enabletrackerfading") then 
				self:SetAttribute("enableTrackerFading", value); 
				self:CallMethod("UpdateSettings"); 

			elseif (name == "change-enableexplorerchat") then
				self:SetAttribute("enableExplorerChat", value); 
				self:CallMethod("UpdateSettings"); 
			end 
		]=])
	end
end 

Module.OnEnable = function(self)
	self:UpdateSettings()
end
