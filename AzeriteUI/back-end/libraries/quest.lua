local LibQuest = Wheel:Set("LibQuest", 1)
if (not LibQuest) then
	return
end

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibQuest requires LibMessage to be loaded.")

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibQuest requires LibEvent to be loaded.")

LibMessage:Embed(LibQuest)
LibEvent:Embed(LibQuest)

-- Library registries
LibQuest.embeds = LibQuest.embeds or {}



local embedMethods = {
}

LibQuest.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibQuest.embeds) do
	LibQuest:Embed(target)
end
