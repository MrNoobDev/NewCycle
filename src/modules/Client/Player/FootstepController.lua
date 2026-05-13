-- footstep controller
--//

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local footstepLibrary = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Footsteps"))

local footstepController = {}
footstepController.__index = footstepController

function footstepController.new(config)
	local self = setmetatable({}, footstepController)
	self.config = config
	self.character = nil
	self.humanoid = nil
	self.rootPart = nil
	self.distanceAccumulator = 0
	self.stepSound = nil
	return self
end

function footstepController:setCharacter(character)
	self:destroy()

	self.character = character
	self.humanoid = character and (character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid"))
	self.rootPart = character
		and (character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart"))
	self.distanceAccumulator = 0

	if not self.rootPart then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "PlayerFootstep"
	sound.RollOffMaxDistance = 20
	sound.RollOffMinDistance = 4
	sound.Volume = self.config.sounds.footstepVolume.walk
	sound.Parent = self.rootPart

	self.stepSound = sound
end

function footstepController:update(dt, stateController)
	local humanoid = self.humanoid
	local rootPart = self.rootPart
	if not humanoid or not rootPart or humanoid.Health <= 0 or not self.stepSound then
		return
	end

	if humanoid.MoveDirection.Magnitude <= 0.08 or not stateController:isGrounded() then
		self.distanceAccumulator = 0
		return
	end

	local flatVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z)
	self.distanceAccumulator += flatVelocity.Magnitude * dt

	local strideDistance, volume = self:_getStepSettings(stateController)
	if self.distanceAccumulator < strideDistance then
		return
	end

	self.distanceAccumulator = 0
	self:_playFootstep(volume)
end

function footstepController:destroy()
	if self.stepSound then
		self.stepSound:Destroy()
		self.stepSound = nil
	end

	self.character = nil
	self.humanoid = nil
	self.rootPart = nil
	self.distanceAccumulator = 0
end

function footstepController:_getStepSettings(stateController)
	if self.humanoid and self.humanoid:GetAttribute("Crouching") then
		return self.config.sounds.footstepDistance.crouch, self.config.sounds.footstepVolume.crouch
	end

	if stateController:isRunning() then
		return self.config.sounds.footstepDistance.run, self.config.sounds.footstepVolume.run
	end

	return self.config.sounds.footstepDistance.walk, self.config.sounds.footstepVolume.walk
end

function footstepController:_playFootstep(volume)
	local soundIds = footstepLibrary:GetTableFromMaterial(self.humanoid.FloorMaterial)
	if not soundIds then
		return
	end

	self.stepSound.SoundId = footstepLibrary:GetRandomSound(soundIds)
	self.stepSound.Volume = volume
	self.stepSound.TimePosition = 0
	self.stepSound:Play()
end

return footstepController
