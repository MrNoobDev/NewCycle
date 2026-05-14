-- player state controller
--//

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local playerStateController = {}
playerStateController.__index = playerStateController

function playerStateController.new(player, config)
	local self = setmetatable({}, playerStateController)
	self.player = player
	self.config = config
	self.character = nil
	self.humanoid = nil
	self.rootPart = nil
	self.head = nil

	self.sprintRequested = false
	self.isSprinting = false
	self.isCrouching = false
	self.jumpLockedUntil = 0

	self.activeHipTween = nil
	self.crouchSounds = {}
	self.lastCrouchSoundIndex = 0
	self.crouchKickToken = 0

	self.characterConnections = {}
	self:_loadCrouchSounds()

	return self
end

function playerStateController:setCharacter(character)
	self:_disconnectCharacter()

	self.character = character
	self.humanoid = nil
	self.rootPart = nil
	self.head = nil
	self.sprintRequested = false
	self.isSprinting = false
	self.isCrouching = false

	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head") or character:WaitForChild("Head")

	self.humanoid = humanoid
	self.rootPart = rootPart
	self.head = head

	humanoid.WalkSpeed = self.config.movement.walkSpeed
	humanoid.HipHeight = self.config.movement.standHipHeight
	humanoid.JumpPower = self.config.movement.jumpPower

	self:_applyStateAttributes()
	self:_muteDefaultCharacterAudio(character)
	self:_stopDefaultAnimations(humanoid)

	table.insert(
		self.characterConnections,
		humanoid.StateChanged:Connect(function(_, newState)
			if self.isCrouching then
				if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
					self:exitCrouch()
				end
			end
		end)
	)

	table.insert(
		self.characterConnections,
		humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
			if not self.humanoid or not self.humanoid.Parent or not humanoid.Jump then
				return
			end

			if self.isCrouching or os.clock() < self.jumpLockedUntil or self:_isMovementLocked() then
				humanoid.Jump = false
				return
			end

			self.jumpLockedUntil = os.clock() + self.config.movement.jumpCooldown
		end)
	)

	table.insert(
		self.characterConnections,
		humanoid.Died:Connect(function()
			self.isCrouching = false
			self.sprintRequested = false
			self.isSprinting = false
			self:_applyMovementValues(
				self.config.movement.walkSpeed,
				self.config.movement.standHipHeight,
				self.config.movement.jumpPower
			)
			self:_applyStateAttributes()
		end)
	)
end

function playerStateController:update(cameraLookVector)
	local humanoid = self.humanoid
	if not humanoid or not self.rootPart then
		return
	end

	local isBlocking = humanoid:GetAttribute("WeaponBlocking") == true
	local isStunned = humanoid:GetAttribute("WeaponStunned") == true
		or (self.character and self.character:GetAttribute("isWeaponStunned") == true)

	if self:_isMovementBusy() then
		self.sprintRequested = false
	end

	local walkSpeed = self.config.movement.walkSpeed
	local jumpPower = self.config.movement.jumpPower
	local moveDirection = humanoid.MoveDirection
	local moving = moveDirection.Magnitude > 0.1
	local isRunning = false

	if isStunned then
		walkSpeed = 0
		jumpPower = 0
	elseif isBlocking then
		walkSpeed = self.config.movement.blockSpeed or self.config.movement.blockWalkSpeed or 4
		jumpPower = 0
	elseif self.isCrouching then
		walkSpeed = self.config.movement.crouchSpeed
		jumpPower = 0
	elseif moving then
		local flatLook = Vector3.new(cameraLookVector.X, 0, cameraLookVector.Z)
		if flatLook.Magnitude > 0.001 then
			local dot = moveDirection:Dot(flatLook.Unit)
			if dot < -0.5 then
				walkSpeed = self.config.movement.backwardWalkSpeed
			elseif self.sprintRequested and self:_canSprint() then
				walkSpeed = self.config.movement.runSpeed
				isRunning = true
			end
		end
	end

	self.isSprinting = isRunning
	self:_applyStateAttributes()

	if humanoid.WalkSpeed ~= walkSpeed then
		humanoid.WalkSpeed = walkSpeed
	end

	if humanoid.JumpPower ~= jumpPower then
		humanoid.JumpPower = jumpPower
	end

	if jumpPower == 0 and humanoid.Jump then
		humanoid.Jump = false
	end
end

function playerStateController:setSprintRequested(isRequested)
	self.sprintRequested = isRequested == true
	if self.isCrouching and self.sprintRequested then
		self.sprintRequested = false
	end
end

function playerStateController:toggleCrouch()
	if self.isCrouching then
		return self:exitCrouch()
	end

	return self:enterCrouch()
end

function playerStateController:enterCrouch()
	if self.isCrouching then
		return false
	end

	local humanoid = self.humanoid
	if not humanoid or not humanoid.Parent then
		return false
	end

	if self:_isMovementBusy() then
		return false
	end

	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		return false
	end

	self.isCrouching = true
	self.sprintRequested = false
	self.isSprinting = false
	self:_tweenHipHeight(self.config.movement.crouchHipHeight)
	self:_playRandomCrouchSound()
	self.crouchKickToken += 1
	self:_applyStateAttributes()

	return true
end

function playerStateController:exitCrouch()
	if not self.isCrouching then
		return false
	end

	local humanoid = self.humanoid
	if not humanoid or not humanoid.Parent then
		return false
	end

	self.isCrouching = false
	self:_tweenHipHeight(self.config.movement.standHipHeight)
	self.crouchKickToken += 1
	self:_applyStateAttributes()

	return true
end

function playerStateController:isRunning()
	return self.isSprinting
end

function playerStateController:getCrouchKickToken()
	return self.crouchKickToken
end

function playerStateController:isGrounded()
	if not self.rootPart then
		return true
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.character }

	return workspace:Raycast(self.rootPart.Position, Vector3.new(0, -4, 0), params) ~= nil
end

function playerStateController:destroy()
	self:_disconnectCharacter()

	if self.activeHipTween then
		self.activeHipTween:Cancel()
		self.activeHipTween = nil
	end

	self.character = nil
	self.humanoid = nil
	self.rootPart = nil
	self.head = nil
end

function playerStateController:_applyMovementValues(walkSpeed, hipHeight, jumpPower)
	if not self.humanoid then
		return
	end

	self.humanoid.WalkSpeed = walkSpeed
	self.humanoid.HipHeight = hipHeight
	self.humanoid.JumpPower = jumpPower
end

function playerStateController:_applyStateAttributes()
	local humanoid = self.humanoid
	local character = self.character
	if not humanoid or not character then
		return
	end

	humanoid:SetAttribute("Crouching", self.isCrouching)
	humanoid:SetAttribute("Sprinting", self.isSprinting)
	character:SetAttribute("Crouching", self.isCrouching)
	character:SetAttribute("Sprinting", self.isSprinting)
end

function playerStateController:_canSprint()
	if self.isCrouching or self:_isMovementBusy() then
		return false
	end

	return self.humanoid ~= nil and self.humanoid.Health > 0
end

function playerStateController:_isMovementBusy()
	local humanoid = self.humanoid
	if not humanoid then
		return false
	end

	return humanoid:GetAttribute("WeaponBlocking") == true
		or humanoid:GetAttribute("WeaponBusy") == true
		or humanoid:GetAttribute("WeaponStunned") == true
		or (self.character and self.character:GetAttribute("isWeaponStunned") == true)
end

function playerStateController:_isMovementLocked()
	local humanoid = self.humanoid
	if not humanoid then
		return false
	end

	return humanoid:GetAttribute("WeaponBlocking") == true
		or humanoid:GetAttribute("WeaponStunned") == true
		or (self.character and self.character:GetAttribute("isWeaponStunned") == true)
end

function playerStateController:_tweenHipHeight(targetHeight)
	local humanoid = self.humanoid
	if not humanoid then
		return
	end

	if self.activeHipTween then
		self.activeHipTween:Cancel()
		self.activeHipTween = nil
	end

	local hipValue = Instance.new("NumberValue")
	hipValue.Value = humanoid.HipHeight

	local changedConnection
	changedConnection = hipValue.Changed:Connect(function(value)
		if self.humanoid and self.humanoid.Parent then
			self.humanoid.HipHeight = value
		end
	end)

	self.activeHipTween = TweenService:Create(
		hipValue,
		TweenInfo.new(self.config.movement.hipTweenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Value = targetHeight }
	)

	local completedConnection
	completedConnection = self.activeHipTween.Completed:Connect(function()
		completedConnection:Disconnect()
		changedConnection:Disconnect()
		hipValue:Destroy()
		self.activeHipTween = nil
	end)

	self.activeHipTween:Play()
end

function playerStateController:_loadCrouchSounds()
	local current = SoundService
	for _, name in ipairs(self.config.sounds.crouchPath or {}) do
		current = current:FindFirstChild(name)
		if not current then
			return
		end
	end

	for _, soundName in ipairs(self.config.sounds.crouch or {}) do
		local sound = current:FindFirstChild(soundName)
		if sound and sound:IsA("Sound") then
			sound.Volume = self.config.sounds.crouchVolume
			self.crouchSounds[soundName] = sound
		end
	end
end

function playerStateController:_playRandomCrouchSound()
	local soundNames = self.config.sounds.crouch or {}
	if #soundNames == 0 then
		return
	end

	local index = self.lastCrouchSoundIndex
	if #soundNames == 1 then
		index = 1
	else
		repeat
			index = math.random(1, #soundNames)
		until index ~= self.lastCrouchSoundIndex
	end

	self.lastCrouchSoundIndex = index

	local sound = self.crouchSounds[soundNames[index]]
	if sound then
		sound:Stop()
		sound:Play()
	end
end

function playerStateController:_stopDefaultAnimations(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 2)
	if not animator then
		return
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end

	table.insert(
		self.characterConnections,
		humanoid.AnimationPlayed:Connect(function(track)
			track:Stop(0)
		end)
	)
end

function playerStateController:_muteDefaultCharacterAudio(character)
	if not self.config.sounds.muteCharacterSounds then
		return
	end

	local function muteSound(obj)
		if not obj:IsA("Sound") then
			return
		end

		for _, name in ipairs(self.config.sounds.soundBlacklist or {}) do
			if string.find(string.lower(obj.Name), string.lower(name)) then
				obj.Volume = 0
				break
			end
		end
	end

	for _, obj in ipairs(character:GetDescendants()) do
		muteSound(obj)
	end

	table.insert(self.characterConnections, character.DescendantAdded:Connect(muteSound))
end

function playerStateController:_disconnectCharacter()
	for index = #self.characterConnections, 1, -1 do
		self.characterConnections[index]:Disconnect()
		self.characterConnections[index] = nil
	end
end

return playerStateController
