local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local cameraController = {}
cameraController.__index = cameraController

local idleDriftSpeed = 0.28
local idleDriftAmp = 0.0035

local bobSpeedWalk = 4.5
local bobYWalk = 0.06
local bobXWalk = 0.025
local bobZWalk = 0.012
local bobTiltWalk = 0.018

local bobSpeedRun = 5.8
local bobYRun = 0.10
local bobXRun = 0.038
local bobZRun = 0.018
local bobTiltRun = 0.032

local landSpring = 18
local landDamping = 0.72
local landBounceMin = -0.55
local landBounceMax = 0.18
local landInitialVel = -0.42

function cameraController.new(config)
	local self = setmetatable({}, cameraController)
	self.config = config

	self.character = nil
	self.humanoid = nil
	self.head = nil
	self.rootPart = nil

	self.bobTime = 0
	self.bobOffset = CFrame.new()

	self.driftTime = math.random() * 100

	self.activeShakeValue = nil

	self.isGrounded = true
	self.wasGrounded = true
	self.landBounceOffset = 0
	self.landBounceVelocity = 0
	self.crouchStepAccumulator = 0
	self.angleX = 0
	self.bobX = 0
	self.bobY = 0
	self.tilt = 0
	self.vX = 0
	self.vY = 0
	self.sX = 10
	self.sY = 10

	self.crouchKickOffset = CFrame.new()
	self.crouchKickTarget = CFrame.new()
	self.lastCrouchToken = 0

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
	self.bobOffset = CFrame.new()
	self.isGrounded = true
	self.wasGrounded = true
	self.landBounceOffset = 0
	self.landBounceVelocity = 0
	self.crouchKickOffset = CFrame.new()
	self.crouchKickTarget = CFrame.new()
	self.lastCrouchToken = 0

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
				self:_playShakeSequence(0, -0.6, 0.12, Enum.EasingStyle.Sine, 0.18, 0.55, Enum.EasingStyle.Sine)
			elseif newState == Enum.HumanoidStateType.Freefall then
				self.isGrounded = false
			elseif newState == Enum.HumanoidStateType.Landed then
				self:_playShakeSequence(-0.22, 0, 0.13, Enum.EasingStyle.Sine, 0.45, 0.65, Enum.EasingStyle.Sine)
			end
		end)
	)
end

function cameraController:update(dt, stateController)
	local camera = Workspace.CurrentCamera
	if
		not camera
		or not self.humanoid
		or not self.humanoid.Parent
		or not self.rootPart
		or not self.rootPart.Parent
		or camera.CameraType ~= Enum.CameraType.Custom
	then
		return
	end

	self:_updateFov(dt, stateController)
	self:_updateLandBounce(dt)
	self:_updateBob(dt, stateController)
	self:_updateCrouchKick(dt, stateController)
	self:_updateFirstPersonBody()

	local shake = self.activeShakeValue and self.activeShakeValue.Value or CFrame.new()
	camera.CFrame = camera.CFrame * self.bobOffset * self.crouchKickOffset * shake
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
	local cfg = self.config.camera
	local runFov = cfg and cfg.runFov or 90
	local normalFov = cfg and cfg.normalFov or 80
	local lerp = cfg and cfg.fovLerp or 4
	local target = stateController:isRunning() and runFov or normalFov

	camera.FieldOfView = camera.FieldOfView + (target - camera.FieldOfView) * math.clamp(dt * lerp, 0, 1)
end

function cameraController:_updateLandBounce(dt)
	self.isGrounded = self:_checkGrounded()

	if self.isGrounded and not self.wasGrounded and self.humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
		self.landBounceVelocity = landInitialVel
	end

	self.wasGrounded = self.isGrounded

	if self.landBounceOffset ~= 0 or self.landBounceVelocity ~= 0 then
		self.landBounceVelocity = self.landBounceVelocity + dt * landSpring
		self.landBounceOffset = self.landBounceOffset + self.landBounceVelocity
		self.landBounceVelocity = self.landBounceVelocity * landDamping

		if math.abs(self.landBounceOffset) < 0.005 and math.abs(self.landBounceVelocity) < 0.005 then
			self.landBounceOffset = 0
			self.landBounceVelocity = 0
		end

		self.landBounceOffset = math.clamp(self.landBounceOffset, landBounceMin, landBounceMax)
	end
end

function cameraController:_updateBob(dt, stateController)
	local camera = Workspace.CurrentCamera
	local humanoid = self.humanoid
	local rootPart = self.rootPart

	if not camera or not humanoid or not rootPart then
		self.bobOffset = self.bobOffset:Lerp(CFrame.new(), math.clamp(dt * 8, 0, 1))
		return
	end

	local velocityVector = rootPart.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocityVector.X, 0, velocityVector.Z)
	local speed = flatVelocity.Magnitude

	if speed <= 0.05 or not self.isGrounded then
		self.angleX = self.angleX + (0 - self.angleX) * math.clamp(dt * 8, 0, 1)
		self.bobX = self.bobX + (0 - self.bobX) * math.clamp(dt * 8, 0, 1)
		self.bobY = self.bobY + (0 - self.bobY) * math.clamp(dt * 8, 0, 1)
		self.tilt = self.tilt + (0 - self.tilt) * math.clamp(dt * 8, 0, 1)
		self.vX = self.vX + (0 - self.vX) * math.clamp(dt * 8, 0, 1)
		self.vY = self.vY + (0 - self.vY) * math.clamp(dt * 8, 0, 1)

		self.bobOffset = self.bobOffset:Lerp(CFrame.new(0, self.landBounceOffset, 0), math.clamp(dt * 8, 0, 1))
		return
	end

	local scaledDt = math.min(dt * 60, 2)
	local isRunning = stateController:isRunning()

	local bobSpeed = isRunning and 15 or 10
	local bobStrength = isRunning and 12 or 9

	if scaledDt <= 2 then
		self.vX = self.vX
			+ ((math.cos(time() * 0.45) * 0.015 * scaledDt - self.vX) * math.clamp(0.035 * scaledDt, 0, 1))

		self.vY = self.vY + ((math.cos(time() * 0.4) * 0.008 * scaledDt - self.vY) * math.clamp(0.03 * scaledDt, 0, 1))
	end
	local moveDir = humanoid.MoveDirection
	local localMoveDir = rootPart.CFrame:VectorToObjectSpace(moveDir)
	local directionalTilt = math.clamp(-localMoveDir.X * 0.035, -0.035, 0.035)

	local moveSpaceVelocity = camera.CFrame:VectorToObjectSpace(velocityVector / math.max(humanoid.WalkSpeed, 0.01))
	local velocityTilt = math.clamp(-moveSpaceVelocity.X * 0.02, -0.02, 0.02)
	local targetTilt = directionalTilt + velocityTilt

	local mouseDeltaX = UserInputService:GetMouseDelta().X

	self.angleX = self.angleX
		+ (math.clamp(mouseDeltaX / math.max(scaledDt, 0.001) * 0.06, -1.2, 1.2) - self.angleX)
			* math.clamp(0.18 * scaledDt, 0, 1)

	local turnTilt = math.clamp(-mouseDeltaX * 0.0007, -0.02, 0.02)
	local combinedTilt = targetTilt + turnTilt

	self.tilt = self.tilt + (combinedTilt - self.tilt) * math.clamp(0.09 * scaledDt, 0, 1)

	self.bobX = self.bobX
		+ (math.sin(time() * bobSpeed) / 7 * math.min(1, bobStrength / 10) - self.bobX)
			* math.clamp(0.2 * scaledDt, 0, 1)

	if speed > 1 then
		self.bobY = self.bobY
			+ (math.cos(time() * 0.5 * bobSpeed) * (bobSpeed / 280) - self.bobY) * math.clamp(0.2 * scaledDt, 0, 1)
	else
		self.bobY = self.bobY + (0 - self.bobY) * math.clamp(0.06 * scaledDt, 0, 1)
	end

	local target = CFrame.new(0, self.landBounceOffset, 0)
		* CFrame.Angles(0, 0, math.rad(self.angleX))
		* CFrame.Angles(
			math.rad(math.clamp(self.bobX * scaledDt, -0.08, 0.08)),
			math.rad(math.clamp(self.bobY * scaledDt, -0.22, 0.22)),
			self.tilt
		)
		* CFrame.Angles(math.rad(self.vX), math.rad(self.vY), math.rad(self.vY * 3.5))

	self.bobOffset = self.bobOffset:Lerp(target, math.clamp(dt * 10, 0, 1))
end

function cameraController:_updateCrouchKick(dt, stateController)
	local token = stateController:getCrouchKickToken()

	if token ~= self.lastCrouchToken then
		self.lastCrouchToken = token

		local isCrouching = self.humanoid and self.humanoid:GetAttribute("Crouching") == true

		if isCrouching then
			-- Horror-style crouch kick:
			-- slight downward dip + sideways roll for immersive first-person motion
			self.crouchKickTarget = CFrame.Angles(math.rad(2.5), 0, math.rad(3.5))

			task.delay(0.07, function()
				if self.lastCrouchToken == token then
					-- rebound upward + opposite lean
					self.crouchKickTarget = CFrame.Angles(math.rad(-3), 0, math.rad(-4.5))
				end
			end)

			task.delay(0.18, function()
				if self.lastCrouchToken == token then
					-- settle into subtle crouch lean
					self.crouchKickTarget = CFrame.Angles(0, 0, math.rad(1.2))
				end
			end)
		else
			-- uncrouch returns smoothly upright
			self.crouchKickTarget = CFrame.new()
		end
	end

	-- fixed 60 FPS simulation for identical feel on all framerates
	local crouching = self.humanoid and self.humanoid:GetAttribute("Crouching") == true
	local baseAlpha = crouching and 0.15 or 0.08

	self.crouchStepAccumulator += dt
	local fixedStep = 1 / 60

	while self.crouchStepAccumulator >= fixedStep do
		self.crouchStepAccumulator -= fixedStep
		self.crouchKickOffset = self.crouchKickOffset:Lerp(self.crouchKickTarget, baseAlpha)
	end
end
function cameraController:_updateFirstPersonBody()
	if not self.character or not self.head then
		return
	end

	local camera = Workspace.CurrentCamera
	local distance = (camera.CFrame.Position - self.head.Position).Magnitude

	for _, obj in ipairs(self.character:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.LocalTransparencyModifier = (distance >= 1.5 or obj:GetAttribute("ForceVisibleInFirstPerson")) and 0
				or 1
		elseif obj:IsA("Accessory") then
			local handle = obj:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.LocalTransparencyModifier = (distance >= 1.5 or handle:GetAttribute("ForceVisibleInFirstPerson"))
						and 0
					or 1
			end
		end
	end
end

function cameraController:_checkGrounded()
	if not self.rootPart or not self.rootPart.Parent then
		return true
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.character }

	return Workspace:Raycast(self.rootPart.Position, Vector3.new(0, -4, 0), params) ~= nil
end

function cameraController:_playShakeSequence(
	startAngle,
	endAngle,
	duration,
	easeStyle,
	recoveryAngle,
	recoveryDuration,
	recoveryEasing
)
	if self.activeShakeValue then
		self.activeShakeValue:Destroy()
		self.activeShakeValue = nil
	end

	local v0 = Instance.new("CFrameValue")
	v0.Value = CFrame.Angles(math.rad(startAngle), 0, 0)
	self.activeShakeValue = v0

	local t0 = TweenService:Create(
		v0,
		TweenInfo.new(duration, easeStyle, Enum.EasingDirection.Out),
		{ Value = CFrame.Angles(math.rad(endAngle), 0, 0) }
	)

	local c0
	c0 = t0.Completed:Connect(function()
		c0:Disconnect()
		t0:Destroy()

		local v1 = Instance.new("CFrameValue")
		v1.Value = CFrame.Angles(math.rad(recoveryAngle), 0, 0)
		self.activeShakeValue = v1

		local t1 = TweenService:Create(
			v1,
			TweenInfo.new(recoveryDuration, recoveryEasing, Enum.EasingDirection.Out),
			{ Value = CFrame.new() }
		)

		local c1
		c1 = t1.Completed:Connect(function()
			c1:Disconnect()
			t1:Destroy()
			v1:Destroy()

			if self.activeShakeValue == v1 then
				self.activeShakeValue = nil
			end
		end)

		t1:Play()
	end)

	t0:Play()
end

function cameraController:_disconnectCharacter()
	for i = #self.characterConnections, 1, -1 do
		self.characterConnections[i]:Disconnect()
		self.characterConnections[i] = nil
	end
end

return cameraController
