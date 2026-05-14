-- footstep controller
-- Uses SoundService.Player audio folders
--//

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local playerStateManager
pcall(function()
	playerStateManager = require(ReplicatedStorage.Modules.Manager.PlayerStateManager)
end)

local footstepController = {}
footstepController.__index = footstepController

local MATERIAL_TAGS = {
	"Carpet",
	"Metal",
	"Tile",
	"Stone",
	"Wood",
	"Ink",
}

local DEFAULT_VOLUMES = {
	foley = 0.1,
	walk = 0.3,
	run = 0.3,
	crouch = 0.15,
	climb = 0.3,
	land = 0.4,
	landMaterial = 0.4,
	jumpUp = 0.3,
	effortClimb = 0.3,
	effortRun = 0.3,
	effortLand = 0.3,
	effortFall = 0.6,
}

local DEFAULT_DISTANCES = {
	walk = 4.4,
	run = 5.0,
	crouch = 3.4,
}

local STEP_INTERVALS = {
	walk = 0.42,
	run = 0.32,
	crouch = 0.68,
}

local FALL_THRESHOLD_SMALL = 2
local FALL_THRESHOLD_PAIN = 3
local FALL_THRESHOLD_MEDIUM = 4

local function getVolume(config, name)
	if config and config.sounds and config.sounds.footstepVolume and config.sounds.footstepVolume[name] then
		return config.sounds.footstepVolume[name]
	end

	return DEFAULT_VOLUMES[name] or 0.3
end

local function getDistance(config, name)
	if config and config.sounds and config.sounds.footstepDistance and config.sounds.footstepDistance[name] then
		return config.sounds.footstepDistance[name]
	end

	return DEFAULT_DISTANCES[name] or 3.2
end

local function getFolder(...)
	local current = SoundService

	for _, name in ipairs({ ... }) do
		if not current then
			return nil
		end

		current = current:FindFirstChild(name)
	end

	return current
end

local function collectSounds(folder, volume)
	local sounds = {}

	if not folder then
		return sounds
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Sound") then
			child.Volume = volume
			table.insert(sounds, child)
		end
	end

	table.sort(sounds, function(a, b)
		return a.Name < b.Name
	end)

	return sounds
end

local function getRandomIndex(list, lastIndex)
	if #list <= 0 then
		return nil
	end

	if #list == 1 then
		return 1
	end

	local index
	repeat
		index = math.random(1, #list)
	until index ~= lastIndex

	return index
end

local function playSound(sound, volume)
	if not sound then
		return
	end

	if volume then
		sound.Volume = volume
	end

	sound:Stop()
	sound.TimePosition = 0
	sound:Play()
end

function footstepController.new(config)
	local self = setmetatable({}, footstepController)

	self.config = config
	self.character = nil
	self.humanoid = nil
	self.rootPart = nil

	self.distanceAccumulator = 0
	self.lastStepTime = 0
	self.lastIndexes = {}

	self.stateConnection = nil
	self.diedConnection = nil

	self.isJumping = false
	self.fallStartY = nil

	self.soundBank = self:_buildSoundBank()

	return self
end

function footstepController:_buildSoundBank()
	local playerFolder = getFolder("Player")

	local bank = {
		foley = {},
		walk = {
			Default = {},
		},
		run = {},
		land = {
			Default = {},
		},
		climb = {},
		jumpUp = {},
		effortClimb = {},
		effortRun = {},
		effortLand = {},
		effortSmall = {},
		effortPain = {},
		effortMedium = {},
	}

	if not playerFolder then
		warn("[FootstepController] Missing SoundService.Player folder")
		return bank
	end

	bank.foley = collectSounds(getFolder("Player", "Movement_Pipe", "Walk"), DEFAULT_VOLUMES.foley)

	bank.walk.Default = collectSounds(getFolder("Player", "Walk"), DEFAULT_VOLUMES.walk)

	bank.climb = collectSounds(getFolder("Player", "Climb"), DEFAULT_VOLUMES.climb)

	bank.jumpUp = collectSounds(getFolder("Player", "Climb", "Up"), DEFAULT_VOLUMES.jumpUp)

	bank.land.Default = collectSounds(getFolder("Player", "Land"), DEFAULT_VOLUMES.land)

	bank.effortClimb = collectSounds(getFolder("Player", "Effort", "Small"), DEFAULT_VOLUMES.effortClimb)

	bank.effortRun = collectSounds(getFolder("Player", "Effort", "Run"), DEFAULT_VOLUMES.effortRun)

	bank.effortLand = collectSounds(getFolder("Player", "Effort", "Land"), DEFAULT_VOLUMES.effortLand)

	bank.effortSmall = collectSounds(getFolder("Player", "Effort", "Small"), DEFAULT_VOLUMES.effortFall)

	bank.effortPain = collectSounds(getFolder("Player", "Effort", "Pain"), DEFAULT_VOLUMES.effortFall)

	bank.effortMedium = collectSounds(getFolder("Player", "Effort", "Medium"), DEFAULT_VOLUMES.effortFall)

	for _, tag in ipairs(MATERIAL_TAGS) do
		bank.walk[tag] = collectSounds(getFolder("Player", "Materials", "Walk", tag), DEFAULT_VOLUMES.walk)

		bank.run[tag] = collectSounds(getFolder("Player", "Materials", "Run", tag), DEFAULT_VOLUMES.run)

		bank.land[tag] = collectSounds(getFolder("Player", "Materials", "Land", tag), DEFAULT_VOLUMES.landMaterial)
	end

	return bank
end

function footstepController:setCharacter(character)
	self:destroy(false)

	self.character = character
	self.humanoid = character and (character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid"))
	self.rootPart = character
		and (character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart"))

	self.distanceAccumulator = 0
	self.lastStepTime = 0
	self.isJumping = false
	self.fallStartY = nil

	if not self.humanoid or not self.rootPart then
		return
	end

	self.stateConnection = self.humanoid.StateChanged:Connect(function(_, newState)
		self:_onHumanoidStateChanged(newState)
	end)

	self.diedConnection = self.humanoid.Died:Connect(function()
		self:destroy(false)
	end)
end

function footstepController:update(dt, stateController)
	local humanoid = self.humanoid
	local rootPart = self.rootPart

	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	if humanoid.MoveDirection.Magnitude <= 0.08 or not stateController:isGrounded() then
		self.distanceAccumulator = 0
		return
	end

	local flatVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z)

	self.distanceAccumulator += flatVelocity.Magnitude * dt

	local strideDistance, volume, movementType = self:_getStepSettings(stateController)

	if self.distanceAccumulator < strideDistance then
		return
	end

	local minInterval = STEP_INTERVALS[movementType] or 0.25
	local now = os.clock()

	if now - self.lastStepTime < minInterval then
		return
	end

	self.lastStepTime = now
	self.distanceAccumulator -= strideDistance
	self:_playFootstep(volume, movementType)
end

function footstepController:destroy(clearSoundBank)
	if self.stateConnection then
		self.stateConnection:Disconnect()
		self.stateConnection = nil
	end

	if self.diedConnection then
		self.diedConnection:Disconnect()
		self.diedConnection = nil
	end

	self.character = nil
	self.humanoid = nil
	self.rootPart = nil
	self.distanceAccumulator = 0
	self.lastStepTime = 0
	self.isJumping = false
	self.fallStartY = nil

	if clearSoundBank then
		self.soundBank = nil
	end
end

function footstepController:_getStepSettings(stateController)
	if self.humanoid and self.humanoid:GetAttribute("Crouching") then
		return getDistance(self.config, "crouch"), getVolume(self.config, "crouch"), "crouch"
	end

	if stateController:isRunning() then
		return getDistance(self.config, "run"), getVolume(self.config, "run"), "run"
	end

	return getDistance(self.config, "walk"), getVolume(self.config, "walk"), "walk"
end

function footstepController:_getFloorInstance()
	if not self.rootPart or not self.character then
		return nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { self.character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(self.rootPart.Position, Vector3.new(0, -4, 0), raycastParams)

	return result and result.Instance or nil
end

function footstepController:_getMaterialTag(floorInstance)
	if not floorInstance then
		return nil
	end

	for _, tag in ipairs(MATERIAL_TAGS) do
		if CollectionService:HasTag(floorInstance, tag) then
			return tag
		end
	end

	return nil
end

function footstepController:_pickSound(listKey, sounds)
	if not sounds or #sounds <= 0 then
		return nil
	end

	local lastIndex = self.lastIndexes[listKey] or 0
	local index = getRandomIndex(sounds, lastIndex)

	if not index then
		return nil
	end

	self.lastIndexes[listKey] = index
	return sounds[index]
end

function footstepController:_playFromList(listKey, sounds, volume)
	local sound = self:_pickSound(listKey, sounds)
	playSound(sound, volume)
end

function footstepController:_playFootstep(volume, movementType)
	local floorInstance = self:_getFloorInstance()
	local materialTag = self:_getMaterialTag(floorInstance)

	self:_playFromList("foley", self.soundBank.foley, DEFAULT_VOLUMES.foley)

	local sounds

	if movementType == "run" then
		sounds = materialTag and self.soundBank.run[materialTag] or nil

		if not sounds or #sounds <= 0 then
			sounds = self.soundBank.walk.Default
		end

		self:_playFromList("effortRun", self.soundBank.effortRun, DEFAULT_VOLUMES.effortRun)
	else
		sounds = materialTag and self.soundBank.walk[materialTag] or nil

		if not sounds or #sounds <= 0 then
			sounds = self.soundBank.walk.Default
		end
	end

	self:_playFromList("step_" .. tostring(materialTag or "Default") .. "_" .. movementType, sounds, volume)
end

function footstepController:_onHumanoidStateChanged(newState)
	if not self.humanoid or not self.rootPart then
		return
	end

	if newState == Enum.HumanoidStateType.Jumping then
		if self.isJumping then
			return
		end

		self.isJumping = true
		self.fallStartY = nil

		self:_playFromList("jumpUp", self.soundBank.jumpUp, DEFAULT_VOLUMES.jumpUp)
		self:_playFromList("climb", self.soundBank.climb, DEFAULT_VOLUMES.climb)
		self:_playFromList("effortClimb", self.soundBank.effortClimb, DEFAULT_VOLUMES.effortClimb)
	elseif newState == Enum.HumanoidStateType.Freefall then
		if self.fallStartY == nil then
			self.fallStartY = self.rootPart.Position.Y
		end
	elseif newState == Enum.HumanoidStateType.Landed then
		task.delay(0.1, function()
			if not self.rootPart or not self.humanoid then
				return
			end

			local fallDistance = 0

			if self.fallStartY ~= nil then
				fallDistance = self.fallStartY - self.rootPart.Position.Y
				self.fallStartY = nil
			end

			local floorInstance = self:_getFloorInstance()
			local materialTag = self:_getMaterialTag(floorInstance)

			local landSounds = materialTag and self.soundBank.land[materialTag] or nil

			if not landSounds or #landSounds <= 0 then
				landSounds = self.soundBank.land.Default
			end

			self:_playFromList("land_" .. tostring(materialTag or "Default"), landSounds, DEFAULT_VOLUMES.land)

			local isInjured = false

			if playerStateManager and playerStateManager.getState then
				isInjured = playerStateManager.getState("IsInjured")
			end

			if isInjured then
				self:_playFromList("effortLand", self.soundBank.effortLand, DEFAULT_VOLUMES.effortLand)
			elseif fallDistance > FALL_THRESHOLD_MEDIUM then
				self:_playFromList("effortMedium", self.soundBank.effortMedium, DEFAULT_VOLUMES.effortFall)
			elseif fallDistance > FALL_THRESHOLD_PAIN then
				self:_playFromList("effortPain", self.soundBank.effortPain, DEFAULT_VOLUMES.effortFall)
			elseif fallDistance > FALL_THRESHOLD_SMALL then
				self:_playFromList("effortSmall", self.soundBank.effortSmall, DEFAULT_VOLUMES.effortFall)
			end

			self.isJumping = false
		end)
	end
end

return footstepController
