local debrisService = game:GetService("Debris")
local playersService = game:GetService("Players")
local soundService = game:GetService("SoundService")
local replicatedStorage = game.ReplicatedStorage

local weaponEvent = replicatedStorage.AxeEvents:FindFirstChild("WeaponAction")
local feedbackEvent = replicatedStorage.AxeEvents:FindFirstChild("WeaponFeedback")

local weaponManager = require(replicatedStorage.Modules.Manager.WeaponManager)

local playerCooldowns = {}
local hitRegistry = {}

local ATTACK_COOLDOWN = 0.5
local HIT_COOLDOWN = 0.1

local volumeEffortAttack = 1
local volumeSwing = 0.8

local effortAttackFolder = soundService:WaitForChild("Player"):WaitForChild("Effort"):WaitForChild("Attack")
local effortAttackNames = {
	"vo_audrey_effort_4attack_01",
	"vo_audrey_effort_4attack_02",
	"vo_audrey_effort_4attack_03",
	"vo_audrey_effort_4attack_04",
	"vo_audrey_effort_4attack_05",
	"vo_audrey_effort_4attack_06",
}
local lastEffortAttackIndex = 0

local swingNames = {
	"sfx_weapon_gent_whoosh_base_01",
	"sfx_weapon_gent_whoosh_base_02",
	"sfx_weapon_gent_whoosh_base_03",
	"sfx_weapon_gent_whoosh_base_04",
	"sfx_weapon_gent_whoosh_base_05",
	"sfx_weapon_gent_whoosh_base_06",
}
local lastSwingIndex = 0

local function nextIndex(current, max)
	return (current % max) + 1
end

local effortHitCounter = 0
local effortHitThreshold = math.random(4, 8)

local function playEffortAttack()
	effortHitCounter = effortHitCounter + 1
	if effortHitCounter < effortHitThreshold then
		return
	end

	effortHitCounter = 0
	effortHitThreshold = math.random(4, 8)

	lastEffortAttackIndex = nextIndex(lastEffortAttackIndex, #effortAttackNames)
	local sound = effortAttackFolder:FindFirstChild(effortAttackNames[lastEffortAttackIndex])
	if sound then
		sound.Volume = volumeEffortAttack
		sound:Stop()
		sound:Play()
	end
end

local function playSwing(upperTorso)
	lastSwingIndex = nextIndex(lastSwingIndex, #swingNames)
	local sound = upperTorso:FindFirstChild(swingNames[lastSwingIndex])
	if sound then
		sound.Volume = volumeSwing
		sound:Stop()
		sound:Play()
	end
end

local function canPerformAction(userId)
	if playerCooldowns[userId] then
		return false
	end
	playerCooldowns[userId] = true
	task.delay(ATTACK_COOLDOWN, function()
		playerCooldowns[userId] = nil
	end)
	return true
end

local function canHitTarget(attackerId, victimId)
	local key = attackerId .. "_" .. victimId
	if hitRegistry[key] then
		return false
	end
	hitRegistry[key] = true
	task.delay(HIT_COOLDOWN, function()
		hitRegistry[key] = nil
	end)
	return true
end

local function createAxeHitPart(character, targetPosition, maxDistance, hitPartSpeed)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	local origin = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 3
	local direction = (targetPosition - origin).Unit

	local hitPart = Instance.new("Part")
	hitPart.Name = "AxeHit"
	hitPart.Size = Vector3.new(2, 2, 4)
	hitPart.CFrame = CFrame.new(origin, origin + direction)
	hitPart.Transparency = 1
	hitPart.CanCollide = false
	hitPart.Anchored = false
	hitPart.Parent = workspace

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Velocity = direction * hitPartSpeed
	bodyVelocity.Parent = hitPart

	local highlight = Instance.new("Highlight")
	highlight.Parent = hitPart
	highlight.Enabled = false

	local startPosition = hitPart.Position
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		if not hitPart or not hitPart.Parent then
			connection:Disconnect()
			return
		end
		if (hitPart.Position - startPosition).Magnitude >= maxDistance then
			connection:Disconnect()
			hitPart:Destroy()
		end
	end)

	debrisService:AddItem(hitPart, maxDistance / hitPartSpeed)
	return hitPart
end

local function handleAttack(player, weaponConfig, targetPosition)
	local character = player.Character
	if not character or not canPerformAction(player.UserId) then
		return
	end

	if not targetPosition or typeof(targetPosition) ~= "Vector3" then
		return
	end

	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso then
		playSwing(upperTorso)
	end

	playEffortAttack()

	createAxeHitPart(character, targetPosition, weaponConfig.combat.maxHitDistance, weaponConfig.combat.hitPartSpeed)

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local origin = humanoidRootPart.Position
	local direction = (targetPosition - origin).Unit * weaponConfig.combat.maxHitDistance
	local result = workspace:Raycast(origin, direction, raycastParams)

	if result then
		local distanceToHit = (result.Position - origin).Magnitude
		if distanceToHit <= weaponConfig.combat.maxHitDistance then
			local hitPart = result.Instance
			local hitCharacter = hitPart.Parent
			local hitHumanoid = hitCharacter:FindFirstChild("Humanoid")

			if hitHumanoid and hitCharacter ~= character then
				if hitCharacter:FindFirstChild("Axe_Deffence") then
					local victim = playersService:GetPlayerFromCharacter(hitCharacter)
					if victim then
						feedbackEvent:FireClient(victim, "DefenceTriggered")
					end
				elseif canHitTarget(player.UserId, hitHumanoid.Parent.Name) then
					local damage = weaponManager.calculateDamage(hitPart.Name, weaponConfig.combat.damage)
					hitHumanoid:TakeDamage(damage)
				end
			end
		end
	end
end

local function handleDefenceToggle(player, isActive)
	local character = player.Character
	if not character then
		return
	end

	if isActive then
		if character:FindFirstChild("Axe_Deffence") then
			return
		end
		local forceField = Instance.new("ForceField")
		forceField.Name = "Axe_Deffence"
		forceField.Visible = false
		forceField.Parent = character
	else
		local defence = character:FindFirstChild("Axe_Deffence")
		if defence then
			defence:Destroy()
		end
	end
end

local function loadWeaponSounds(character)
	local upperTorso = character:WaitForChild("UpperTorso", 5)
	if not upperTorso then
		return
	end

	local soundNames = {
		"sfx_weapon_gent_whoosh_base_01",
		"sfx_weapon_gent_whoosh_base_02",
		"sfx_weapon_gent_whoosh_base_03",
		"sfx_weapon_gent_whoosh_base_04",
		"sfx_weapon_gent_whoosh_base_05",
		"sfx_weapon_gent_whoosh_base_06",
		"Sfx_Axe_Block",
	}

	for _, soundName in pairs(soundNames) do
		if not upperTorso:FindFirstChild(soundName) then
			local soundTemplate = replicatedStorage.Sounds.Axe:FindFirstChild(soundName)
			if soundTemplate then
				soundTemplate:Clone().Parent = upperTorso
			end
		end
	end
end

weaponEvent.OnServerEvent:Connect(function(player, actionType, ...)
	local args = { ... }
	local success, weaponConfig = pcall(function()
		return require(replicatedStorage.Modules.WeaponSettings.Axe)
	end)

	if actionType == "Attack" then
		handleAttack(player, weaponConfig, args[1])
	elseif actionType == "DefenceOn" then
		handleDefenceToggle(player, true)
	elseif actionType == "DefenceOff" then
		handleDefenceToggle(player, false)
	end
end)

playersService.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		playerCooldowns[player.UserId] = nil
		loadWeaponSounds(character)
	end)
	player.CharacterRemoving:Connect(function()
		playerCooldowns[player.UserId] = nil
	end)
end)

for _, player in pairs(playersService:GetPlayers()) do
	if player.Character then
		loadWeaponSounds(player.Character)
	end
end
