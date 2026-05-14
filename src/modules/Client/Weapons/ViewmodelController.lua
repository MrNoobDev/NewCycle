-- viewmodel controller
--//

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

	self.swaySpeedMultiplier = 1
	self.swayAmountMultiplier = 1

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
	self.swaySpeedMultiplier = 1
	self.swayAmountMultiplier = 1

	self:_setPartsVisible(false)
	task.delay(0.03, function()
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

	local playerMouse = self.player and self.player:GetMouse()
	if playerMouse then
		playerMouse.TargetFilter = self.viewmodel
	end

	local humanoid = self.humanoid

	local isBlocking = humanoid and humanoid:GetAttribute("WeaponBlocking") == true
	local isStunned = humanoid and humanoid:GetAttribute("WeaponStunned") == true
	local isCrouching = humanoid and humanoid:GetAttribute("Crouching") == true
	local isSprinting = humanoid and humanoid:GetAttribute("Sprinting") == true

	if humanoid then
		if humanoid.WalkSpeed <= 8 then
			isCrouching = true
			isSprinting = false
		elseif humanoid.WalkSpeed >= 18 then
			isSprinting = true
			isCrouching = false
		end
	end

	local targetSwaySpeedMultiplier = 1
	local targetSwayAmountMultiplier = 1

	if isSprinting then
		targetSwaySpeedMultiplier = 1.15
	elseif isCrouching then
		targetSwaySpeedMultiplier = 0.82
	end

	if isBlocking then
		targetSwayAmountMultiplier = 0.45
		targetSwaySpeedMultiplier *= 0.85
	end

	if isStunned then
		targetSwayAmountMultiplier = 0.25
		targetSwaySpeedMultiplier = 0.65
	end

	local swayTransitionAlpha = 1 - math.exp(-deltaTime * 10)
	self.swaySpeedMultiplier += (targetSwaySpeedMultiplier - self.swaySpeedMultiplier) * swayTransitionAlpha
	self.swayAmountMultiplier += (targetSwayAmountMultiplier - self.swayAmountMultiplier) * swayTransitionAlpha

	local rotationOffset = camera.CFrame:ToObjectSpace(self.lastCameraFrame)
	local rotX, rotY = rotationOffset:ToOrientation()

	local baseSwayAmount = self.config.camera and self.config.camera.viewmodelSwayAmount or -0.12
	local currentSwayAmount = baseSwayAmount * self.swayAmountMultiplier
	local swayLerpAlpha = math.clamp(0.2 * self.swaySpeedMultiplier, 0.08, 0.35)

	self.swayOffset = self.swayOffset:Lerp(
		CFrame.Angles(math.sin(rotX) * currentSwayAmount, math.sin(rotY) * currentSwayAmount, 0),
		swayLerpAlpha
	)

	self.lastCameraFrame = camera.CFrame

	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		local speed = humanoid.WalkSpeed
		local bobSpeed = speed == 10 and 5 or 4
		local sprintOffset = self.config.camera and (self.config.camera.sprintCFrame or self.config.camera.sprintOffset)
			or CFrame.new()

		local rootPart = self.character and self.character:FindFirstChild("HumanoidRootPart")
		local moveDir = humanoid.MoveDirection
		local targetLocalMoveDir = rootPart and rootPart.CFrame:VectorToObjectSpace(moveDir) or Vector3.zero

		local moveLerpAlpha = 1 - math.exp(-deltaTime * 10)
		self.smoothedLocalMoveDir = self.smoothedLocalMoveDir:Lerp(targetLocalMoveDir, moveLerpAlpha)

		local targetStrafeTilt = math.clamp(-self.smoothedLocalMoveDir.X * 0.12, -0.12, 0.12)
		local targetStrafeOffset = math.clamp(self.smoothedLocalMoveDir.X * 0.06, -0.06, 0.06)

		local strafeLerpAlpha = 1 - math.exp(-deltaTime * 12)
		self.strafeTilt = self.strafeTilt + (targetStrafeTilt - self.strafeTilt) * strafeLerpAlpha
		self.strafeOffset = self.strafeOffset + (targetStrafeOffset - self.strafeOffset) * strafeLerpAlpha

		local forwardInfluence = math.clamp(self.smoothedLocalMoveDir.Z * 0.04, -0.02, 0.04)
		local strafeVerticalInfluence = math.abs(self.smoothedLocalMoveDir.X) * 0.015
		local walkHeightOffset = 0.16 + forwardInfluence + strafeVerticalInfluence

		local bobTarget = CFrame.new(
			math.cos(tick() * bobSpeed) * 0.1 + self.strafeOffset,
			-(humanoid.CameraOffset.Y / 3) + walkHeightOffset,
			0
		) * CFrame.Angles(
			0,
			math.sin(tick() * -bobSpeed) * -0.1,
			math.cos(tick() * -bobSpeed) * 0.1 + self.strafeTilt
		) * CFrame.Angles(0, 0, -self.smoothedLocalMoveDir.X * 0.035) * sprintOffset

		local bobLerpAlpha = 1 - math.exp(-deltaTime * 8)
		self.bobOffset = self.bobOffset:Lerp(bobTarget, bobLerpAlpha)
	else
		local cameraOffsetY = humanoid and humanoid.CameraOffset.Y or 0

		local moveLerpAlpha = 1 - math.exp(-deltaTime * 10)
		self.smoothedLocalMoveDir = self.smoothedLocalMoveDir:Lerp(Vector3.zero, moveLerpAlpha)

		local strafeLerpAlpha = 1 - math.exp(-deltaTime * 12)
		self.strafeTilt = self.strafeTilt + (0 - self.strafeTilt) * strafeLerpAlpha
		self.strafeOffset = self.strafeOffset + (0 - self.strafeOffset) * strafeLerpAlpha

		local idleTarget = CFrame.new(0, -(cameraOffsetY / 3), 0)
		local bobLerpAlpha = 1 - math.exp(-deltaTime * 6)
		self.bobOffset = self.bobOffset:Lerp(idleTarget, bobLerpAlpha)
	end

	local wallTarget = self:_getWallOffset(camera)
	self.wallOffset = self.wallOffset:Lerp(wallTarget, math.clamp(deltaTime * 24, 0, 1))

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
			* CFrame.new(self.shakeOffset)
	)
end

function viewmodelController:impulseShake(shake)
	if not shake then
		return
	end

	self.shakeVelocity += Vector3.new(
		(math.random() - 0.5) * shake.X,
		(math.random() - 0.5) * shake.Y,
		(math.random() - 0.5) * shake.Z
	)
end

function viewmodelController:playIdle()
	local idleTrack = self.animations.idle
	if not idleTrack then
		return
	end

	if self.animations.block and self.animations.block.IsPlaying then
		return
	end

	if self.animations.blockBreak and self.animations.blockBreak.IsPlaying then
		return
	end

	if self.animations.primaryAttack and self.animations.primaryAttack.IsPlaying then
		return
	end

	if self.animations.secondaryAttack and self.animations.secondaryAttack.IsPlaying then
		return
	end

	idleTrack.Looped = true
	if not idleTrack.IsPlaying then
		idleTrack:Play(0.15)
	end
end

function viewmodelController:playAttack(swingIndex)
	if self.animations.block then
		self.animations.block:Stop(0.05)
	end

	if self.animations.blockBreak then
		self.animations.blockBreak:Stop(0.05)
	end

	if self.animations.idle then
		self.animations.idle:Stop(0.05)
	end

	if self.animations.primaryAttack then
		self.animations.primaryAttack:Stop(0)
	end

	if self.animations.secondaryAttack then
		self.animations.secondaryAttack:Stop(0)
	end

	local attackTrack
	if swingIndex == 2 and self.animations.secondaryAttack then
		attackTrack = self.animations.secondaryAttack
	else
		attackTrack = self.animations.primaryAttack
	end

	if attackTrack then
		attackTrack.Looped = false
		attackTrack.TimePosition = 0
		attackTrack:Play(0.05)

		local connection
		connection = attackTrack.Stopped:Connect(function()
			if connection then
				connection:Disconnect()
			end

			if self.viewmodel then
				self:playIdle()
			end
		end)
	end
end

function viewmodelController:startBlock()
	local blockTrack = self.animations.block
	if blockTrack and blockTrack.IsPlaying then
		return
	end

	if self.animations.primaryAttack then
		self.animations.primaryAttack:Stop(0.05)
	end

	if self.animations.secondaryAttack then
		self.animations.secondaryAttack:Stop(0.05)
	end

	if self.animations.blockBreak then
		self.animations.blockBreak:Stop(0.05)
	end

	if self.animations.idle then
		self.animations.idle:Stop(0.05)
	end

	if blockTrack then
		blockTrack.Looped = true
		blockTrack.TimePosition = 0
		blockTrack:Play(0.1)
	end
end

function viewmodelController:stopBlock()
	local blockTrack = self.animations.block
	if blockTrack and blockTrack.IsPlaying then
		blockTrack:Stop(0.1)
	end

	self:playIdle()
end

function viewmodelController:playBlockBreak()
	if self.animations.block then
		self.animations.block:Stop(0.05)
	end

	if self.animations.primaryAttack then
		self.animations.primaryAttack:Stop(0.05)
	end

	if self.animations.secondaryAttack then
		self.animations.secondaryAttack:Stop(0.05)
	end

	if self.animations.idle then
		self.animations.idle:Stop(0.05)
	end

	local breakTrack = self.animations.blockBreak
	if breakTrack then
		breakTrack.Looped = false
		breakTrack.TimePosition = 0
		breakTrack:Play(0.05)

		local connection
		connection = breakTrack.Stopped:Connect(function()
			if connection then
				connection:Disconnect()
			end

			if self.viewmodel then
				self:playIdle()
			end
		end)
	else
		task.delay(0.2, function()
			if self.viewmodel then
				self:playIdle()
			end
		end)
	end
end

function viewmodelController:showBlockFeedback(feedbackKind)
	local shake = self.config.camera and self.config.camera.blockShake
	self:impulseShake(shake)

	if not self.viewmodel then
		return
	end

	local particles = self.config.effects and self.config.effects.blockParticles
	if particles then
		weaponUtil.toggleViewmodelParticles(self.viewmodel, particles, true)

		task.delay(self.config.combat.blockDuration or 0.2, function()
			if self.viewmodel then
				weaponUtil.toggleViewmodelParticles(self.viewmodel, particles, false)
			end
		end)
	end
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

		local track = animator:LoadAnimation(animation)
		self.animations[name] = track

		if name == "idle" then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Idle
		elseif name == "block" then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Action
		else
			track.Looped = false
			track.Priority = Enum.AnimationPriority.Action
		end
	end

	self.animations.primaryAttack = self.animations.primaryAttack or self.animations.fire
	self.animations.secondaryAttack = self.animations.secondaryAttack or self.animations.fire2
	self.animations.blockBreak = self.animations.blockBreak or self.animations.guardBreak
end

function viewmodelController:_getWallOffset(camera)
	if not self.character then
		return CFrame.new()
	end

	local wallCheckDistance = 2.4
	local maxPushBack = 0.8
	local maxLower = 0.28
	local maxTilt = math.rad(24)

	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * wallCheckDistance

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

	local alpha = math.clamp((wallCheckDistance - result.Distance) / wallCheckDistance, 0, 1)
	if alpha <= 0 then
		return CFrame.new()
	end

	alpha = alpha ^ 0.65

	local pushBack = alpha * maxPushBack
	local lower = alpha * maxLower
	local tilt = alpha * maxTilt

	return CFrame.new(0, -lower, pushBack) * CFrame.Angles(-tilt, 0, 0)
end

return viewmodelController
