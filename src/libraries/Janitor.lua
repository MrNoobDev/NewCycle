--[[
	Janitor.lua
	By: Knineteen19 / hatsuhodowa
	
	A simple module useful for cleaning up effects or various other things all in one function call. You can give a janitor "chores" and
	then make that janitor :Clean() where it loops through those chores and "does" them. What it does with the chores is different depending
	on the type of object you pass into :GiveChore(). It also has a builtin function or two that aren't part of the Janitor class but can
	simply be useful to add as chores in specific use cases.


	We also make use of open source modules like janitor, shapecasthitbox, bytenet, textplus, and wind control.
	The one you'll most likely need to familiarize with is  janitor, shapecast at times, and text plus 

	Wind control is neutral, and bytenet is used for backend which i'll focus on :D


	Also grif, would a trello-esque software be something we should use for the whole team?

	Notion works :D
	Would like to mention Plaky is free

	Click up has free and has paid for 7 per user per month which is expensive but feature rich

	I wouldnt imagine it's limited to public. But you're the boss :D
	
]]

-- Module
local Janitor = {}

-- Clearing Particle
function Janitor.ClearParticle(particleModel)
	local lifetime = 0
	for i, desc in pairs(particleModel:GetDescendants()) do
		pcall(function()
			desc.Enabled = false
			lifetime = math.max(lifetime, desc.Lifetime.Max)
		end)
	end
	task.delay(lifetime, function()
		particleModel:Destroy()
	end)
end

-- Creating
function Janitor.new()
	-- Creating Self
	local self = setmetatable({}, { __index = Janitor })
	self.Chores = {}

	-- Returning
	return self
end

-- Adding Chore
function Janitor:GiveChore(_chore, ...)
	local chore = _chore
	if typeof(_chore) == "function" then
		local args = { ... }
		chore = function()
			_chore(table.unpack(args))
		end
	end
	table.insert(self.Chores, chore)
end

-- Cleaning
function Janitor:Clean()
	-- Looping Chores
	local i, chore = next(self.Chores)
	while #self.Chores > 0 do
		-- Doing Chore
		self.Chores[i] = nil
		if typeof(chore) == "RBXScriptConnection" then
			chore:Disconnect()
		elseif typeof(chore) == "function" then
			chore()
		elseif typeof(chore) == "Instance" and chore.ClassName == "AnimationTrack" then
			chore:Stop()
		else
			local success, result = pcall(function()
				chore:Destroy()
			end)
			if not success then
				warn("Janitor was not able to do chore: " .. result)
			end
		end

		i, chore = next(self.Chores)
	end
end

-- Destroying
function Janitor:Destroy()
	self:Clean()
end

-- Returning
return Janitor
