-- camera controller
--//

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local cameraController = {}
cameraController.__index = cameraController

function cameraController.new(config)
	local self = setmetatable({}, cameraController)
	self.config = config
	self.character = nil
	self.humanoid = nil
	self.head = nil
	self.rootPart = nil

	self.bobTime = 0
	self.swayTime = 0
	self.cameraOffset = CFrame.new()
	self.shakeOffset = CFrame.new()
	self.activeShakeValue = nil

	self.isGrounded = true
	self.wasGrounded = true
	self.landBounceOffset = 0
	self.landBounceVelocity = 0

	self.crouchCameraOffset = CFrame.new()
	self.crouchCameraTarget = CFrame.new()
	self.lastCrouchKickToken = 0

	self.characterConnections = {}
	return self
end

function cameraController:setCharacter(character)
	self:_disconnectCharacter()

	self.character = character
	self.humanoid = nil
	self.head = nil
	self.rootPart = nil

	self.bobTime = 0
	self.swayTime = 0
	self.cameraOffset = CFrame.new()
	self.shakeOffset = CFrame.new()
	self.isGrounded = true
	self.wasGrounded = true
	self.landBounceOffset = 0
	self.landBounceVelocity = 0
	self.crouchCameraOffset = CFrame.new()
	self.crouchCameraTarget = CFrame.new()
	self.lastCrouchKickToken = 0

	if not character then
		return
	end

	self.humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	self.rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")
	self.head = character:FindFirstChild("Head") or character:WaitForChild("Head")

	table.insert(
		self.characterConnections,
		self.humanoid.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Jumping then
				if self.humanoid:GetAttribute("Crouching") == true then
					return
				end

				self.isGrounded = false
				self:_playShakeSequence(0, -0.75, 0.15, Enum.EasingStyle.Sine, 0.225, 0.6, Enum.EasingStyle.Sine)
			elseif newState == Enum.HumanoidStateType.Freefall then
				self.isGrounded = false
			elseif newState == Enum.HumanoidStateType.Landed then
				self:_playShakeSequence(-0.25, 0, 0.15, Enum.EasingStyle.Sine, 0.50, 0.6, Enum.EasingStyle.Sine)
			end
		end)
	)
end

function cameraController:update(dt, stateController)
	local camera = Workspace.CurrentCamera
	if not camera or not self.humanoid or not self.rootPart or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end

	self:_updateFov(dt, stateController)
	self:_updateLandBounce(dt)
	self:_updateCameraMotion(dt, stateController)
	self:_updateFirstPersonBody()
	self:_updateCrouchCameraKick()
	self:_applyCrouchKick(stateController)

	camera.CFrame = camera.CFrame * self.cameraOffset * self.crouchCameraOffset * self.shakeOffset
end

function cameraController:destroy()
	self:_disconnectCharacter()

	if self.activeShakeValue then
		self.activeShakeValue:Destroy()
		self.activeShakeValue = nil
	end
end

function cameraController:_updateFov(dt, stateController)
	local camera = Workspace.CurrentCamera
	local runFov = self.config.camera.runFov or 90
	local normalFov = self.config.camera.normalFov or 80
	local fovLerp = self.config.camera.fovLerp or 4
	local targetFov = stateController:isRunning() and runFov or normalFov

	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.clamp(dt * fovLerp, 0, 1)
end

function cameraController:_updateLandBounce(dt)
	self.isGrounded = self:_checkGrounded()

	if self.isGrounded and not self.wasGrounded and self.humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
		self.landBounceVelocity = -0.35
	end

	self.wasGrounded = self.isGrounded

	if self.landBounceOffset ~= 0 or self.landBounceVelocity ~= 0 then
		local landSpring = self.config.camera.landSpring or 15
		local landDamping = self.config.camera.landDamping or 0.85
		local landBounceMin = self.config.camera.landBounceMin or -0.4
		local landBounceMax = self.config.camera.landBounceMax or 0.2

		self.landBounceVelocity += dt * landSpring
		self.landBounceOffset += self.landBounceVelocity
		self.landBounceVelocity *= landDamping

		if math.abs(self.landBounceOffset) < 0.01 and math.abs(self.landBounceVelocity) < 0.01 then
			self.landBounceOffset = 0
			self.landBounceVelocity = 0
		end

		self.landBounceOffset = math.clamp(self.landBounceOffset, landBounceMin, landBounceMax)
	end
end

function cameraController:_updateCameraMotion(dt, stateController)
	local camera = Workspace.CurrentCamera
	local velocity = self.rootPart.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local isMoving = horizontalVelocity > 0.5 and self.isGrounded

	local targetOffset = CFrame.new()

	if isMoving then
		local bobbingSpeedWalk = self.config.camera.bobbingSpeedWalk or 10
		local bobbingSpeedRun = self.config.camera.bobbingSpeedRun or 12
		local bobbingAmountWalk = self.config.camera.bobbingAmountWalk or 0.15
		local bobbingAmountRun = self.config.camera.bobbingAmountRun or 0.2
		local bobbingHorizontalWalk = self.config.camera.bobbingHorizontalWalk or 0
		local bobbingHorizontalRun = self.config.camera.bobbingHorizontalRun or 0
		local bobbingDepthWalk = self.config.camera.bobbingDepthWalk or 0.05
		local bobbingDepthRun = self.config.camera.bobbingDepthRun or 0.07
		local swayAmountWalk = self.config.camera.swayAmountWalk or 0.15
		local swayAmountRun = self.config.camera.swayAmountRun or 0.2
		local swaySpeed = self.config.camera.swaySpeed or 1

		local currentBobbingSpeed = stateController:isRunning() and bobbingSpeedRun or bobbingSpeedWalk
		local bobbingAmount = stateController:isRunning() and bobbingAmountRun or bobbingAmountWalk
		local bobbingHorizontal = stateController:isRunning() and bobbingHorizontalRun or bobbingHorizontalWalk
		local bobbingDepth = stateController:isRunning() and bobbingDepthRun or bobbingDepthWalk
		local swayAmount = stateController:isRunning() and swayAmountRun or swayAmountWalk

		self.bobTime += dt * currentBobbingSpeed * math.max(horizontalVelocity / 16, 0.1)
		self.swayTime += dt * swaySpeed

		local bobY = math.sin(self.bobTime * 2) * bobbingAmount
		local bobX = math.cos(self.bobTime) * bobbingHorizontal
		local bobZ = math.sin(self.bobTime) * bobbingDepth
		local swayTilt = math.sin(self.swayTime) * swayAmount

		targetOffset = CFrame.new(bobX, bobY, bobZ) * CFrame.Angles(0, 0, math.rad(swayTilt))
	else
		self.bobTime = 0
		self.swayTime = 0
	end

	targetOffset *= CFrame.new(0, self.landBounceOffset, 0)

	self.cameraOffset = self.cameraOffset:Lerp(targetOffset, math.clamp(dt * 10, 0, 1))
	self.shakeOffset = self.activeShakeValue and self.activeShakeValue.Value or CFrame.new()
end

function cameraController:_updateFirstPersonBody()
	if not self.character or not self.head then
		return
	end

	local camera = Workspace.CurrentCamera
	local distance = (camera.CFrame.Position - self.head.Position).Magnitude
	if distance >= 1.5 then
		for _, obj in ipairs(self.character:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.LocalTransparencyModifier = 0
			elseif obj:IsA("Accessory") then
				local handle = obj:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					handle.LocalTransparencyModifier = 0
				end
			end
		end
		return
	end

	for _, obj in ipairs(self.character:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.LocalTransparencyModifier = obj:GetAttribute("ForceVisibleInFirstPerson") and 0 or 1
		elseif obj:IsA("Accessory") then
			local handle = obj:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.LocalTransparencyModifier = handle:GetAttribute("ForceVisibleInFirstPerson") and 0 or 1
			end
		end
	end
end

function cameraController:_updateCrouchCameraKick()
	self.crouchCameraOffset = self.crouchCameraOffset:Lerp(self.crouchCameraTarget, 0.15)
end

function cameraController:_applyCrouchKick(stateController)
	local token = stateController:getCrouchKickToken()
	if token == self.lastCrouchKickToken then
		return
	end

	self.lastCrouchKickToken = token

	self.crouchCameraTarget = CFrame.Angles(math.rad(4), 0, 0)

	task.delay(0.08, function()
		if self.lastCrouchKickToken == token then
			self.crouchCameraTarget = CFrame.Angles(math.rad(-6), 0, 0)
		end
	end)

	task.delay(0.2, function()
		if self.lastCrouchKickToken == token then
			self.crouchCameraTarget = CFrame.new()
		end
	end)
end

function cameraController:_checkGrounded()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.character }
	return Workspace:Raycast(self.rootPart.Position, Vector3.new(0, -4, 0), params) ~= nil
end

function cameraController:_playShakeSequence(
	startAngle,
	endAngle,
	duration,
	easingStyle,
	recoveryAngle,
	recoveryDuration,
	recoveryEasing
)
	if self.activeShakeValue then
		self.activeShakeValue:Destroy()
		self.activeShakeValue = nil
	end

	local initialShake = Instance.new("CFrameValue")
	initialShake.Value = CFrame.Angles(math.rad(startAngle), 0, 0)
	self.activeShakeValue = initialShake

	local initialTween = TweenService:Create(
		initialShake,
		TweenInfo.new(duration, easingStyle, Enum.EasingDirection.Out),
		{ Value = CFrame.Angles(math.rad(endAngle), 0, 0) }
	)

	local initialConnection
	initialConnection = initialTween.Completed:Connect(function()
		initialConnection:Disconnect()
		initialTween:Destroy()

		local recoveryShake = Instance.new("CFrameValue")
		recoveryShake.Value = CFrame.Angles(math.rad(recoveryAngle), 0, 0)
		self.activeShakeValue = recoveryShake

		local recoveryTween = TweenService:Create(
			recoveryShake,
			TweenInfo.new(recoveryDuration, recoveryEasing, Enum.EasingDirection.Out),
			{ Value = CFrame.new() }
		)

		local recoveryConnection
		recoveryConnection = recoveryTween.Completed:Connect(function()
			recoveryConnection:Disconnect()
			recoveryTween:Destroy()
			recoveryShake:Destroy()

			if self.activeShakeValue == recoveryShake then
				self.activeShakeValue = nil
			end
		end)

		recoveryTween:Play()
	end)

	initialTween:Play()
end

function cameraController:_disconnectCharacter()
	for index = #self.characterConnections, 1, -1 do
		self.characterConnections[index]:Disconnect()
		self.characterConnections[index] = nil
	end
end

return cameraController
