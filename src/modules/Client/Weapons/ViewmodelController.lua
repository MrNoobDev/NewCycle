-- viewmodel controller
--//

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local weaponUtil =
	require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponUtil"))

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
	self.wallOffset = CFrame.new()
	self.aimOffset = CFrame.new()
	self.smoothedLocalMoveDir = Vector3.zero
	self.strafeTilt = 0
	self.strafeOffset = 0
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
	self.viewmodel.PrimaryPart = self.viewmodel:FindFirstChild("HumanoidRootPart") or self.viewmodel.PrimaryPart
	self.lastCameraFrame = camera.CFrame
	self.swayOffset = CFrame.new()
	self.bobOffset = CFrame.new()
	self.wallOffset = CFrame.new()
	self.aimOffset = CFrame.new()
	self.shakeVelocity = Vector3.zero
	self.shakeOffset = Vector3.zero

	self:_setPartsVisible(false)
	task.delay(0.03, function()
		if self.viewmodel then
			self:_setPartsVisible(true)
		end
	end)

	self:_loadAnimations()
	self:playIdle()
end

local vmScale = 0.7

function viewmodelController:update(deltaTime)
	if not self.viewmodel or not self.viewmodel.PrimaryPart then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local playerMouse = self.player and self.player:GetMouse()
	if playerMouse then
		playerMouse.TargetFilter = self.viewmodel
	end

	local rotationOffset = camera.CFrame:ToObjectSpace(self.lastCameraFrame)
	local rotX, rotY = rotationOffset:ToOrientation()

	local currentSwayAmount = self.config.camera and self.config.camera.viewmodelSwayAmount or -0.12
	self.swayOffset = self.swayOffset:Lerp(
		CFrame.Angles(math.sin(rotX) * currentSwayAmount, math.sin(rotY) * currentSwayAmount, 0),
		0.2
	)
	self.lastCameraFrame = camera.CFrame

	local humanoid = self.humanoid
	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		local speed = humanoid.WalkSpeed
		local bobSpeed = speed == 10 and 5 or 4
		local sprintOffset = self.config.camera and (self.config.camera.sprintCFrame or self.config.camera.sprintOffset)
			or CFrame.new()

		local rootPart = self.character and self.character:FindFirstChild("HumanoidRootPart")
		local moveDir = humanoid.MoveDirection
		local targetLocalMoveDir = rootPart and rootPart.CFrame:VectorToObjectSpace(moveDir) or Vector3.zero

		-- smooth movement direction
		local moveLerpAlpha = 1 - math.exp(-deltaTime * 10)
		self.smoothedLocalMoveDir = self.smoothedLocalMoveDir:Lerp(targetLocalMoveDir, moveLerpAlpha)

		-- smooth strafe response
		local targetStrafeTilt =
			math.clamp(-self.smoothedLocalMoveDir.X * (0.12 * vmScale), -(0.12 * vmScale), 0.12 * vmScale)
		local targetStrafeOffset =
			math.clamp(self.smoothedLocalMoveDir.X * (0.06 * vmScale), -(0.06 * vmScale), 0.06 * vmScale)
		local strafeLerpAlpha = 1 - math.exp(-deltaTime * 12)
		self.strafeTilt = self.strafeTilt + (targetStrafeTilt - self.strafeTilt) * strafeLerpAlpha
		self.strafeOffset = self.strafeOffset + (targetStrafeOffset - self.strafeOffset) * strafeLerpAlpha

		local bobTarget = CFrame.new(
			math.cos(tick() * bobSpeed) * (0.1 * vmScale) + self.strafeOffset,
			-(humanoid.CameraOffset.Y / 3) * vmScale,
			0
		) * CFrame.Angles(
			0,
			math.sin(tick() * -bobSpeed) * (-0.1 * vmScale),
			math.cos(tick() * -bobSpeed) * (0.1 * vmScale) + self.strafeTilt
		) * sprintOffset

		local bobLerpAlpha = 1 - math.exp(-deltaTime * 8)
		self.bobOffset = self.bobOffset:Lerp(bobTarget, bobLerpAlpha)
	else
		local cameraOffsetY = humanoid and humanoid.CameraOffset.Y or 0

		-- smooth return to neutral when stopping
		local moveLerpAlpha = 1 - math.exp(-deltaTime * 10)
		self.smoothedLocalMoveDir = self.smoothedLocalMoveDir:Lerp(Vector3.zero, moveLerpAlpha)

		local strafeLerpAlpha = 1 - math.exp(-deltaTime * 12)
		self.strafeTilt = self.strafeTilt + (0 - self.strafeTilt) * strafeLerpAlpha
		self.strafeOffset = self.strafeOffset + (0 - self.strafeOffset) * strafeLerpAlpha

		local idleTarget = CFrame.new(0, -(cameraOffsetY / 3) * vmScale, 0)
		local bobLerpAlpha = 1 - math.exp(-deltaTime * 6)
		self.bobOffset = self.bobOffset:Lerp(idleTarget, bobLerpAlpha)
	end

	local wallTarget = self:_getWallOffset(camera)
	self.wallOffset = self.wallOffset:Lerp(wallTarget, math.clamp(deltaTime * 18, 0, 1))

	self.shakeVelocity =
		self.shakeVelocity:Lerp(Vector3.zero, math.clamp(deltaTime * (self.config.camera.shakeDecay or 10), 0, 1))
	self.shakeOffset = self.shakeOffset:Lerp(self.shakeVelocity, 0.25)

	local baseOffset = self.config.camera and self.config.camera.viewmodelOffset or CFrame.new(0, 0, -0.6)

	self.viewmodel:PivotTo(
		camera.CFrame
			* baseOffset
			* self.wallOffset
			* self.swayOffset
			* self.aimOffset
			* self.bobOffset
			* CFrame.new(self.shakeOffset * vmScale)
	)
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

	local hiddenParts = self.config.effects and self.config.effects.hiddenViewmodelParts or {}
	local selectedStage = math.clamp(tonumber(self.config.stage) or 1, 1, 3)
	local selectedUpgradeName = "audrey_ink_Gentpipe_Upgrade" .. selectedStage

	for _, descendant in ipairs(self.viewmodel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local transparency = 0

			if not isVisible then
				transparency = 1
			elseif hiddenParts[descendant.Name] then
				transparency = 1
			end

			if descendant.Name:match("^audrey_ink_Gentpipe_Upgrade%d+$") then
				if descendant.Name == selectedUpgradeName and isVisible then
					transparency = 0
				else
					transparency = 1
				end
			end

			descendant.Transparency = transparency
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

function viewmodelController:_getWallOffset(camera)
	if not self.character then
		return CFrame.new()
	end

	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * 1.75

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.character, self.viewmodel }

	local result = workspace:Raycast(origin, direction, params)
	if not result then
		return CFrame.new()
	end

	local hitModel = result.Instance and result.Instance:FindFirstAncestorOfClass("Model")
	local hitHumanoid = hitModel and hitModel:FindFirstChildOfClass("Humanoid")
	if hitHumanoid then
		return CFrame.new()
	end

	local pushBack = math.clamp((1.75 * vmScale) - result.Distance, 0, 0.45 * vmScale)
	if pushBack <= 0 then
		return CFrame.new()
	end

	return CFrame.new(0, 0, pushBack)
end

return viewmodelController
