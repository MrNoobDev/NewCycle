local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local replicatedStorage = game.ReplicatedStorage

local localPlayer = playersService.LocalPlayer
local playerCharacter = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local playerHumanoid = playerCharacter:WaitForChild("Humanoid")
local workspaceCamera = workspace.CurrentCamera
local playerMouse = localPlayer:GetMouse()

local cameraShaker = require(replicatedStorage.Modules.Libraries.CameraShaker)
local weaponConfig = require(replicatedStorage.Modules.WeaponSettings.Axe)
local weaponManager = require(replicatedStorage.Modules.Manager.WeaponManager)

local weaponEvent = replicatedStorage.AxeEvents.WeaponAction
local feedbackEvent = replicatedStorage.AxeEvents.WeaponFeedback

local viewmodelInstance = nil
local animations = {}
local cameraShakeInstance = nil

local weaponState = {
	isIdle = true,
	isShooting = false,
	isDefending = false,
	canShoot = true,
	clickEnabled = true,
}

local cameraOffsets = {
	aim = CFrame.new(),
	bob = CFrame.new(),
	sway = CFrame.new(),
	lastFrame = CFrame.new(),
}

local currentSwayAmount = -0.3

local function getPlatformType()
	local touchEnabled = userInputService.TouchEnabled
	local mouseEnabled = userInputService.MouseEnabled
	local keyboardEnabled = userInputService.KeyboardEnabled
	local gamepadEnabled = userInputService.GamepadEnabled

	if touchEnabled and not mouseEnabled then
		return "Mobile"
	elseif gamepadEnabled and not mouseEnabled and not keyboardEnabled then
		return "Console"
	else
		return "PC"
	end
end

local platformType = getPlatformType()

local function getMobileTargetPosition()
	local viewportSize = workspaceCamera.ViewportSize
	local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	local unitRay = workspaceCamera:ViewportPointToRay(screenCenter.X, screenCenter.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { playerCharacter, viewmodelInstance }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, raycastParams)
	if result then
		return result.Position
	end
	return unitRay.Origin + unitRay.Direction * 500
end

local function initializeCameraShake()
	cameraShakeInstance = cameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
		workspaceCamera.CFrame = workspaceCamera.CFrame * shakeCFrame
	end)
	cameraShakeInstance:Start()
end

local function loadAnimation(animationId, animationName)
	if not viewmodelInstance then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	animation.Name = animationName

	local animController = viewmodelInstance:FindFirstChild("AnimationController")
	if animController then
		local animator = animController:FindFirstChild("Animator")
		if animator then
			return animator:LoadAnimation(animation)
		end
	end
	return nil
end

local function loadWeaponViewModel()
	for _, model in pairs(workspaceCamera:GetChildren()) do
		if model:IsA("Model") then
			model:Destroy()
		end
	end

	local viewmodelTemplate = replicatedStorage.ViewModels:FindFirstChild(weaponConfig.weaponName)
	if not viewmodelTemplate then
		return
	end

	viewmodelInstance = viewmodelTemplate:Clone()
	viewmodelInstance.Parent = workspaceCamera

	local primaryPart = viewmodelInstance:FindFirstChild("HumanoidRootPart")
	if primaryPart then
		viewmodelInstance.PrimaryPart = primaryPart
	end

	animations.fire = loadAnimation(weaponConfig.animations.fire, "Fire")
	animations.fire2 = loadAnimation(weaponConfig.animations.fire2, "Fire2")
	animations.idle = loadAnimation(weaponConfig.animations.idle, "Idle")
	animations.defence = loadAnimation(weaponConfig.animations.defence, "Defence")

	if animations.defence then
		animations.defence.Looped = true
	end

	if animations.idle then
		animations.idle:Play()
	end

	for _, descendant in pairs(viewmodelInstance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		end
	end

	task.wait(0.1)

	for _, descendant in pairs(viewmodelInstance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local hiddenParts = {
				"RootPart",
				"Muzzle",
				"FakeCamera",
				"Aimpart",
				"HumanoidRootPart",
				"MuzzleFlash",
				"CameraBone",
				"Joint",
				"Main",
				"audrey_ink_Gentpipe_Upgrade2",
				"audrey_ink_Gentpipe_Upgrade3",
				"audrey_ink_Gentpipe_socket",
			}
			local shouldHide = false
			for _, partName in pairs(hiddenParts) do
				if descendant.Name == partName then
					shouldHide = true
					break
				end
			end
			if not shouldHide then
				descendant.Transparency = 0
			end
		end
	end

	weaponState.canShoot = true
end

local function performAttack(targetPosition)
	if not weaponState.clickEnabled or not weaponState.isShooting or not weaponState.canShoot then
		return
	end

	weaponState.clickEnabled = false
	weaponState.isIdle = false

	if cameraShakeInstance then
		local shakeData = weaponConfig.camera.shake.attack
		cameraShakeInstance:ShakeOnce(shakeData.magnitude, shakeData.roughness, shakeData.fadeIn, shakeData.fadeOut)
	end

	local randomAttack = math.random(1, 2)
	local selectedAnimation = randomAttack == 1 and animations.fire or animations.fire2

	if selectedAnimation then
		selectedAnimation:Play()
	end
	if animations.idle then
		animations.idle:Stop()
	end

	weaponEvent:FireServer("Attack", targetPosition)
	weaponState.isShooting = false

	task.wait(weaponConfig.combat.attackRate)

	if animations.idle then
		animations.idle:Play()
	end
	weaponState.clickEnabled = true
	weaponState.isIdle = true
end

local function activateDefence()
	if not weaponState.clickEnabled or not weaponState.isShooting or not weaponState.canShoot then
		return
	end

	weaponState.clickEnabled = false
	weaponState.isIdle = false
	weaponState.isDefending = true

	weaponEvent:FireServer("DefenceOn")

	weaponManager.applyTransparency(playerCharacter, weaponConfig.effects.defenceVisuals.hide, 1, 1)
	weaponManager.applyTransparency(playerCharacter, weaponConfig.effects.defenceVisuals.show, 0, 0)

	if animations.fire then
		animations.fire:Stop()
	end
	if animations.fire2 then
		animations.fire2:Stop()
	end
	if animations.idle then
		animations.idle:Stop()
	end
	if animations.defence then
		animations.defence:Play()
	end
end

local function deactivateDefence()
	if not weaponState.isDefending then
		return
	end

	weaponState.clickEnabled = true
	weaponState.isIdle = true
	weaponState.isDefending = false

	weaponEvent:FireServer("DefenceOff")

	weaponManager.applyTransparency(playerCharacter, weaponConfig.effects.defenceVisuals.hide, 0, 0)
	weaponManager.applyTransparency(playerCharacter, weaponConfig.effects.defenceVisuals.show, 1, 1)

	if animations.fire then
		animations.fire:Stop()
	end
	if animations.fire2 then
		animations.fire2:Stop()
	end
	if animations.defence then
		animations.defence:Stop()
	end
	if animations.idle then
		animations.idle:Play()
	end
end

local function setupMobileUI()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local gameplay = playerGui:FindFirstChild("Gameplay")
	if not gameplay then
		return
	end

	local interfaceMobile = gameplay:FindFirstChild("InterfaceMobile")
	if not interfaceMobile then
		return
	end

	interfaceMobile.Enabled = true

	local content = interfaceMobile:FindFirstChild("Content")
	if not content then
		return
	end

	local buttons = content:FindFirstChild("Buttons")
	if not buttons then
		return
	end

	local axeButton = buttons:FindFirstChild("Axe_Button")
	if axeButton then
		local hitButton = axeButton:FindFirstChild("HitButton")
		if hitButton then
			hitButton.MouseButton1Down:Connect(function()
				if playerCharacter and viewmodelInstance and weaponState.canShoot then
					weaponState.isShooting = true
					local targetPosition = getMobileTargetPosition()
					performAttack(targetPosition)
				end
			end)
		end
	end

	local defenceButton = buttons:FindFirstChild("Defence_Button")
	if defenceButton then
		local defenceButtonPress = defenceButton:FindFirstChild("DefenceButton")
		if defenceButtonPress then
			defenceButtonPress.MouseButton1Down:Connect(function()
				if playerCharacter and viewmodelInstance and weaponState.canShoot then
					weaponState.isShooting = true
					activateDefence()
				end
			end)
			defenceButtonPress.MouseButton1Up:Connect(function()
				deactivateDefence()
			end)
		end
	end
end

local function hideMobileUI()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local gameplay = playerGui:FindFirstChild("Gameplay")
	if not gameplay then
		return
	end

	local interfaceMobile = gameplay:FindFirstChild("InterfaceMobile")
	if interfaceMobile then
		interfaceMobile.Enabled = false
	end
end

runService.RenderStepped:Connect(function()
	if not viewmodelInstance then
		return
	end
	if not viewmodelInstance.PrimaryPart then
		return
	end

	playerMouse.TargetFilter = viewmodelInstance

	local rotationOffset = workspaceCamera.CFrame:ToObjectSpace(cameraOffsets.lastFrame)
	local rotX, rotY = rotationOffset:ToOrientation()
	cameraOffsets.sway = cameraOffsets.sway:Lerp(
		CFrame.Angles(math.sin(rotX) * currentSwayAmount, math.sin(rotY) * currentSwayAmount, 0),
		0.2
	)
	cameraOffsets.lastFrame = workspaceCamera.CFrame

	if playerHumanoid.MoveDirection.Magnitude > 0 then
		local speed = playerHumanoid.WalkSpeed
		local bobSpeed = speed == 10 and 5 or 4
		local bobLerp = speed == 10 and 0.1 or 0.5

		cameraOffsets.bob = cameraOffsets.bob:Lerp(
			CFrame.new(math.cos(tick() * bobSpeed) * 0.1, -playerHumanoid.CameraOffset.Y / 3, 0)
				* CFrame.Angles(0, math.sin(tick() * -bobSpeed) * -0.1, math.cos(tick() * -bobSpeed) * 0.1)
				* weaponConfig.camera.sprintCFrame,
			bobLerp
		)
	else
		cameraOffsets.bob = cameraOffsets.bob:Lerp(CFrame.new(0, -playerHumanoid.CameraOffset.Y / 3, 0), 0.1)
	end

	viewmodelInstance:SetPrimaryPartCFrame(
		workspaceCamera.CFrame * CFrame.new(0, 0, -0.6) * cameraOffsets.sway * cameraOffsets.aim * cameraOffsets.bob
	)
end)

task.wait(1)

if platformType == "Mobile" then
	setupMobileUI()
else
	hideMobileUI()
end

userInputService.InputBegan:Connect(function(inputObject, gameProcessed)
	if gameProcessed then
		return
	end

	if platformType == "PC" then
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			if playerCharacter and viewmodelInstance and weaponState.canShoot then
				weaponState.isShooting = true
				performAttack(playerMouse.Hit.Position)
			end
		end
		if inputObject.UserInputType == Enum.UserInputType.MouseButton2 then
			if playerCharacter and viewmodelInstance and weaponState.canShoot then
				weaponState.isShooting = true
				activateDefence()
			end
		end
	elseif platformType == "Console" then
		if inputObject.KeyCode == Enum.KeyCode.ButtonR2 then
			if playerCharacter and viewmodelInstance and weaponState.canShoot then
				weaponState.isShooting = true
				performAttack(playerMouse.Hit.Position)
			end
		end
		if inputObject.KeyCode == Enum.KeyCode.ButtonL2 then
			if playerCharacter and viewmodelInstance and weaponState.canShoot then
				weaponState.isShooting = true
				activateDefence()
			end
		end
	end
end)

userInputService.InputEnded:Connect(function(inputObject)
	if platformType == "PC" then
		if inputObject.UserInputType == Enum.UserInputType.MouseButton2 then
			deactivateDefence()
		end
	elseif platformType == "Console" then
		if inputObject.KeyCode == Enum.KeyCode.ButtonL2 then
			deactivateDefence()
		end
	end
end)

feedbackEvent.OnClientEvent:Connect(function(feedbackType)
	if feedbackType == "DefenceTriggered" then
		if not cameraShakeInstance or not viewmodelInstance then
			return
		end

		local shakeData = weaponConfig.camera.shake.defence
		cameraShakeInstance:ShakeOnce(shakeData.magnitude, shakeData.roughness, shakeData.fadeIn, shakeData.fadeOut)

		local blockSound = playerCharacter.UpperTorso:FindFirstChild(weaponConfig.sounds.block)
		if blockSound then
			blockSound:Play()
		end

		weaponManager.toggleParticles(viewmodelInstance, weaponConfig.effects.defenceParticles, true)

		task.wait(weaponConfig.combat.defenceDuration)

		weaponManager.toggleParticles(viewmodelInstance, weaponConfig.effects.defenceParticles, false)
		deactivateDefence()
	end
end)

initializeCameraShake()
loadWeaponViewModel()
