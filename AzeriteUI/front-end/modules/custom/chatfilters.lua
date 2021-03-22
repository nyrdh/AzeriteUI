local ADDON, Private = ...
local Core = Wheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

-- Chat Filters
local Module = Core:NewModule("ChatFilters", "LibChatTool")

Module.UpdateChatFilters = function(self)

	self:SetChatFilterEnabled("ClassColors", true)
	self:SetChatFilterEnabled("QualityColors", true)
	self:SetChatFilterEnabled("Styling", self.db.enableChatStyling)

	self:SetChatFilterEnabled("Spam", self.db.enableSpamFilter)
	self:SetChatFilterEnabled("Boss", self.db.enableBossFilter)
	self:SetChatFilterEnabled("Monster", self.db.enableMonsterFilter)

	if (self.db.enableSpamFilter) then
		self:SetChatFilterEnabled("MaxDps", self:IsAddOnEnabled("MaxDps"))
	end
end

Module.OnInit = function(self)
	self.db = Private.GetConfig(self:GetName())

	self:SetChatFilterMoneyTextures(
		string.format([[|T%s:16:16:-2:0:64:64:%d:%d:%d:%d|t]], Private.GetMedia("coins"), 0,32,0,32),
		string.format([[|T%s:16:16:-2:0:64:64:%d:%d:%d:%d|t]], Private.GetMedia("coins"), 32,64,0,32),
		string.format([[|T%s:16:16:-2:0:64:64:%d:%d:%d:%d|t]], Private.GetMedia("coins"), 0,32,32,64) 
	)

	local OptionsMenu = Core:GetModule("OptionsMenu", true)
	if (OptionsMenu) then
		local callbackFrame = OptionsMenu:CreateCallbackFrame(self)
		callbackFrame:AssignProxyMethods("UpdateChatFilters")
		callbackFrame:AssignSettings(self.db)
		callbackFrame:AssignCallback([=[
			if name then 
				name = string.lower(name); 
			end 
			if (name == "change-enablechatstyling") then
				self:SetAttribute("enableChatStyling", value); 
				self:CallMethod("UpdateChatFilters"); 

			elseif (name == "change-enablemonsterfilter") then
				self:SetAttribute("enableMonsterFilter", value); 
				self:CallMethod("UpdateChatFilters"); 

			elseif (name == "change-enablebossfilter") then
				self:SetAttribute("enableBossFilter", value); 
				self:CallMethod("UpdateChatFilters"); 

			elseif (name == "change-enablespamfilter") then
				self:SetAttribute("enableSpamFilter", value); 
				self:CallMethod("UpdateChatFilters"); 
			end 
		]=])
	end
end

Module.OnEnable = function(self)
	self:UpdateChatFilters()
end
