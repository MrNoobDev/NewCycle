local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local weaponUtil = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponUtil"))

local viewmodelController = {}
viewmodelController.__index = viewmodelController

function viewmodelController.new(player, config)
	local self = setmetatable({}, viewmodelController)
	self.player = player
	self.config = config
	self.viewmodel = nil
	self.animations = {}
	self.shakeVelocity = Vector3.zero
	self.shakeOffset = Vector3.zero
	self.lastCameraFrame = CFrame.new()
	self.swayOffset = CFrame.new()
	self.bobOffset = CFrame.new()
	return self
end

function viewmodelController:setCharacter(character)
	self.character = character
	self.humanoid = character and character:FindFirstChildOfClass("Humanoid")
end

function viewmodelController:load()
	self:destroyViewmodel()

	local camera = workspace.CurrentCamera
	local viewmodels = ReplicatedStorage:FindFirstChild("ViewModels")
	local template = viewmodels and viewmodels:FindFirstChild(self.config.viewmodelName)
	if not camera or not template then
		return
	end

	self.viewmodel = template:Clone()
	self.viewmodel.Parent = camera
	self.viewmodel.PrimaryPart = self.viewmodel:FindFirstChild("HumanoidRootPart")
	self.lastCameraFrame = camera.CFrame

	self:_setPartsVisible(false)
	task.delay(0.1, function()
		if self.viewmodel then
			self:_setPartsVisible(true)
		end
	end)

	self:_loadAnimations()
	self:playIdle()
end

function viewmodelController:update(deltaTime)
	if not self.viewmodel or not self.viewmodel.PrimaryPart then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local rotationOffset = camera.CFrame:ToObjectSpace(self.lastCameraFrame)
	local rotX, rotY = rotationOffset:ToOrientation()
	self.swayOffset = self.swayOffset:Lerp(
		CFrame.Angles(math.sin(rotX) * -0.3, math.sin(rotY) * -0.3, 0),
		self.config.camera.swayLerp
	)
	self.lastCameraFrame = camera.CFrame

	local humanoid = self.humanoid
	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		local bobSpeed = humanoid.WalkSpeed == 10 and 5 or 4
		local bobLerp = humanoid.WalkSpeed == 10 and self.config.camera.bobMovingLerp or 0.5
		self.bobOffset = self.bobOffset:Lerp(
			CFrame.new(math.cos(time() * bobSpeed) * 0.1, -humanoid.CameraOffset.Y / 3, 0)
				* CFrame.Angles(0, math.sin(time() * -bobSpeed) * -0.1, math.cos(time() * -bobSpeed) * 0.1)
				* self.config.camera.sprintOffset,
			bobLerp
		)
	else
		local cameraOffsetY = humanoid and humanoid.CameraOffset.Y or 0
		self.bobOffset = self.bobOffset:Lerp(CFrame.new(0, -cameraOffsetY / 3, 0), self.config.camera.bobIdleLerp)
	end

	self.shakeVelocity = self.shakeVelocity:Lerp(Vector3.zero, math.clamp(deltaTime * self.config.camera.shakeDecay, 0, 1))
	self.shakeOffset = self.shakeOffset:Lerp(self.shakeVelocity, 0.35)

	self.viewmodel:PivotTo(camera.CFrame * self.config.camera.viewmodelOffset * self.swayOffset * CFrame.new(self.shakeOffset) * self.bobOffset)
end

function viewmodelController:impulseShake(shake)
	self.shakeVelocity += Vector3.new(
		(math.random() - 0.5) * shake.X,
		(math.random() - 0.5) * shake.Y,
		(math.random() - 0.5) * shake.Z
	)
end

function viewmodelController:playIdle()
	if self.animations.idle then
		self.animations.idle:Play()
	end
end

function viewmodelController:playAttack(swingIndex)
	if self.animations.idle then
		self.animations.idle:Stop()
	end

	if swingIndex == 2 and self.animations.secondaryAttack then
		self.animations.secondaryAttack:Play()
	elseif self.animations.primaryAttack then
		self.animations.primaryAttack:Play()
	end
end

function viewmodelController:startBlock()
	if self.animations.primaryAttack then
		self.animations.primaryAttack:Stop()
	end

	if self.animations.secondaryAttack then
		self.animations.secondaryAttack:Stop()
	end

	if self.animations.idle then
		self.animations.idle:Stop()
	end

	if self.animations.block then
		self.animations.block.Looped = true
		self.animations.block:Play()
	end
end

function viewmodelController:stopBlock()
	if self.animations.block then
		self.animations.block:Stop()
	end

	self:playIdle()
end

function viewmodelController:showBlockFeedback()
	self:impulseShake(self.config.camera.blockShake)
	weaponUtil.toggleViewmodelParticles(self.viewmodel, self.config.effects.blockParticles, true)

	task.delay(self.config.combat.blockDuration, function()
		if self.viewmodel then
			weaponUtil.toggleViewmodelParticles(self.viewmodel, self.config.effects.blockParticles, false)
		end
	end)
end

function viewmodelController:destroyViewmodel()
	for _, track in pairs(self.animations) do
		track:Stop()
		track:Destroy()
	end

	table.clear(self.animations)

	if self.viewmodel then
		self.viewmodel:Destroy()
		self.viewmodel = nil
	end
end

function viewmodelController:destroy()
	self:destroyViewmodel()
end

function viewmodelController:_setPartsVisible(isVisible)
	if not self.viewmodel then
		return
	end

	for _, descendant in ipairs(self.viewmodel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = isVisible and (self.config.effects.hiddenViewmodelParts[descendant.Name] and 1 or 0) or 1
		end
	end
end

function viewmodelController:_loadAnimations()
	if not self.viewmodel then
		return
	end

	local animationController = self.viewmodel:FindFirstChild("AnimationController")
	local animator = animationController and animationController:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	for name, animationId in pairs(self.config.animations) do
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = animationId
		self.animations[name] = animator:LoadAnimation(animation)
	end
	self.animations.primaryAttack = self.animations.primaryAttack or self.animations.fire
	self.animations.secondaryAttack = self.animations.secondaryAttack or self.animations.fire2
end

return viewmodelController
