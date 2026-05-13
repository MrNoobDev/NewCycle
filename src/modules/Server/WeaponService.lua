local require = require(script.Parent.loader).load(script)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Maid = require("Maid")

local weaponPackets =
	require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponPackets"))
local weaponPlayerState = require(script.Parent.Weapons.WeaponPlayerState)
local weaponRegistry =
	require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponRegistry"))
local weaponUtil =
	require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponUtil"))

local weaponService = {}
weaponService.ServiceName = "WeaponService"

function weaponService:Init(serviceBag)
	self.serviceBag = assert(serviceBag, "No serviceBag")
	self.maid = Maid.new()
	self.playerStates = {}
	self.effortIndices = {}
	self.swingIndices = {}
	self.effortCounters = {}
	self.effortThresholds = {}
end

function weaponService:Start()
	self.maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:_handlePlayerAdded(player)
	end))

	self.maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self:_handlePlayerRemoving(player)
	end))

	weaponPackets.requestLoadout.listen(function(_, player)
		self:_handleLoadoutRequest(player)
	end)

	weaponPackets.requestAttack.listen(function(data, player)
		self:_handleAttackRequest(player, data)
	end)

	weaponPackets.requestBlock.listen(function(data, player)
		self:_handleBlockRequest(player, data)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_handlePlayerAdded(player)
		if player.Character then
			self:_handleCharacterAdded(player, player.Character)
		end
	end
end

function weaponService:_handlePlayerAdded(player)
	local state = weaponPlayerState.new(player)
	self.playerStates[player] = state

	for _, weaponId in ipairs(weaponRegistry.getSpawnWeapons()) do
		state:grantWeapon(weaponId)
	end

	self.maid:GiveTask(player.CharacterAdded:Connect(function(character)
		self:_handleCharacterAdded(player, character)
	end))

	self.maid:GiveTask(player.CharacterRemoving:Connect(function()
		state:clearTransientState()
	end))
end

function weaponService:_handleLoadoutRequest(player)
	local state = self.playerStates[player]
	if not state then
		return
	end

	self:_syncWeaponsToPlayer(player, state)
end

function weaponService:_syncWeaponsToPlayer(player, state)
	if not player.Parent then
		return
	end

	for weaponId in pairs(state.weaponIds) do
		weaponPackets.assignWeapon.sendTo({
			weaponId = weaponId,
			isEquipped = state.equippedWeaponId == weaponId,
		}, player)
	end
end

function weaponService:_handlePlayerRemoving(player)
	local state = self.playerStates[player]
	if not state then
		return
	end

	state:destroy()
	self.playerStates[player] = nil
	self.effortIndices[player] = nil
	self.swingIndices[player] = nil
	self.effortCounters[player] = nil
	self.effortThresholds[player] = nil
end

function weaponService:_handleCharacterAdded(player, character)
	local state = self.playerStates[player]
	if not state then
		return
	end

	state:clearTransientState()
	character:SetAttribute("isBlocking", false)
	character:SetAttribute("blockingWeaponId", "")

	for weaponId in pairs(state.weaponIds) do
		self:_loadCharacterSounds(character, weaponRegistry.getWeaponConfig(weaponId))
	end
end

function weaponService:_handleAttackRequest(player, data)
	local state = self.playerStates[player]
	if not state then
		return
	end

	local weaponId = data.weaponId
	local config = weaponRegistry.getWeaponConfig(weaponId)
	if not config then
		return
	end

	if not state:hasWeapon(weaponId) or not state:isWeaponEquipped(weaponId) then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not rootPart then
		return
	end

	if typeof(data.targetPosition) ~= "Vector3" then
		return
	end

	local now = os.clock()
	if not state:canAttack(now) then
		return
	end

	state:setAttackCooldown(now, config.combat.attackCooldown)

	self:_playSwingSound(player, character, config)
	self:_playEffortSound(player, config)
	self:_spawnHitPart(character, data.targetPosition, config)
	self:_resolveAttack(player, state, character, rootPart, data.targetPosition, config)
end

function weaponService:_handleBlockRequest(player, data)
	local state = self.playerStates[player]
	if not state then
		return
	end

	local weaponId = data.weaponId
	local config = weaponRegistry.getWeaponConfig(weaponId)
	if not config then
		return
	end

	if not state:hasWeapon(weaponId) or not state:isWeaponEquipped(weaponId) then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	state:setBlocking(weaponId, data.isActive)
	character:SetAttribute("isBlocking", data.isActive)
	character:SetAttribute("blockingWeaponId", data.isActive and weaponId or "")
end

function weaponService:_resolveAttack(player, state, character, rootPart, targetPosition, config)
	local direction = targetPosition - rootPart.Position
	if direction.Magnitude <= 0 then
		return
	end

	if direction.Magnitude > config.combat.maxHitDistance + 3 then
		return
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(rootPart.Position, direction.Unit * config.combat.maxHitDistance, raycastParams)
	if not result then
		return
	end

	local hitPart = result.Instance
	local hitModel = hitPart:FindFirstAncestorOfClass("Model")
	local hitHumanoid = hitModel and hitModel:FindFirstChildOfClass("Humanoid")
	if not hitHumanoid or hitModel == character then
		return
	end

	local distanceToHit = (result.Position - rootPart.Position).Magnitude
	if distanceToHit > config.combat.maxHitDistance then
		return
	end

	local targetKey = tostring(hitModel:GetDebugId())
	local now = os.clock()
	if not state:canHit(targetKey, now, config.combat.hitCooldown) then
		return
	end

	if self:_tryBlockAttack(hitModel, rootPart.Position, config, result.Position) then
		weaponPackets.feedback.sendTo({
			feedbackType = "blockSuccess",
			weaponId = state.equippedWeaponId or config.id,
		}, player)
		return
	end

	local damage = weaponUtil.getDamageFromHit(config, hitPart)
	hitHumanoid:TakeDamage(damage)
end

function weaponService:_tryBlockAttack(hitModel, attackerPosition, config)
	if not hitModel:GetAttribute("isBlocking") then
		return false
	end

	if hitModel:GetAttribute("blockingWeaponId") == "" then
		return false
	end

	local rootPart = hitModel:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end

	local toAttacker = (attackerPosition - rootPart.Position)
	if toAttacker.Magnitude <= 0 then
		return false
	end

	local facing = rootPart.CFrame.LookVector
	local angle = math.deg(math.acos(math.clamp(facing:Dot(toAttacker.Unit), -1, 1)))
	return angle <= config.combat.blockAngle
end

function weaponService:_spawnHitPart(character, targetPosition, config)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local hitPart = Instance.new("Part")
	hitPart.Name = "weaponHitPart"
	hitPart.Size = config.combat.hitPartSize
	hitPart.Transparency = 1
	hitPart.Anchored = true
	hitPart.CanCollide = false
	hitPart.CanQuery = false
	hitPart.CanTouch = false
	hitPart.CFrame = CFrame.lookAt(rootPart.Position, targetPosition)
		+ (targetPosition - rootPart.Position).Unit
			* math.min((targetPosition - rootPart.Position).Magnitude, config.combat.maxHitDistance)
	hitPart.Parent = workspace
	Debris:AddItem(hitPart, config.combat.hitPartLifetime)
end

function weaponService:_loadCharacterSounds(character, config)
	if not config or not config.sounds then
		return
	end

	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then
		return
	end

	for _, soundName in ipairs(config.sounds.swing or {}) do
		if not torso:FindFirstChild(soundName) then
			local source = SoundService:FindFirstChild(soundName, true)
			if source and source:IsA("Sound") then
				local sound = source:Clone()
				sound.Parent = torso
				sound.Volume = config.sounds.volume and config.sounds.volume.swing or sound.Volume
			end
		end
	end

	if config.sounds.block and not torso:FindFirstChild(config.sounds.block) then
		local blockSource = SoundService:FindFirstChild(config.sounds.block, true)
		if blockSource and blockSource:IsA("Sound") then
			blockSource:Clone().Parent = torso
		end
	end

	local effortFolder = SoundService
	for _, childName in ipairs(config.sounds.effortFolder or {}) do
		effortFolder = effortFolder and effortFolder:FindFirstChild(childName)
	end
	if effortFolder then
		for _, soundName in ipairs(config.sounds.effort or {}) do
			if not torso:FindFirstChild(soundName) then
				local source = effortFolder:FindFirstChild(soundName)
				if source and source:IsA("Sound") then
					local sound = source:Clone()
					sound.Parent = torso
					sound.Volume = config.sounds.volume and config.sounds.volume.effort or sound.Volume
				end
			end
		end
	end
end

function weaponService:_playSwingSound(player, character, config)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local swings = config.sounds and config.sounds.swing
	if not torso or not swings or #swings == 0 then
		return
	end

	local index = (self.swingIndices[player] or 0) % #swings + 1
	self.swingIndices[player] = index

	local sound = torso:FindFirstChild(swings[index])
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

function weaponService:_playEffortSound(player, config)
	local character = player.Character
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	local efforts = config.sounds and config.sounds.effort
	if not torso or not efforts or #efforts == 0 then
		return
	end

	local counter = (self.effortCounters[player] or 0) + 1
	self.effortCounters[player] = counter
	local threshold = self.effortThresholds[player] or math.random(2, 4)
	self.effortThresholds[player] = threshold
	if counter < threshold then
		return
	end

	self.effortCounters[player] = 0
	self.effortThresholds[player] = math.random(2, 4)
	local index = (self.effortIndices[player] or 0) % #efforts + 1
	self.effortIndices[player] = index

	local sound = torso:FindFirstChild(efforts[index])
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

function weaponService:Destroy()
	for player, state in pairs(self.playerStates) do
		state:destroy()
		self.playerStates[player] = nil
	end

	self.maid:DoCleaning()
end

return weaponService
