local require = require(script.Parent.loader).load(script)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Maid = require("Maid")

local weaponPackets = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponPackets"))
local weaponRegistry = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponRegistry"))
local weaponUtil = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponUtil"))
local weaponPlayerState = require(script.Parent.Weapons.WeaponPlayerState)

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
		if state:grantWeapon(weaponId) then
			weaponPackets.assignWeapon.sendTo({ weaponId = weaponId }, player)
		end
	end

	self.maid:GiveTask(player.CharacterAdded:Connect(function(character)
		self:_handleCharacterAdded(player, character)
		weaponPackets.assignWeapon.sendTo({ weaponId = state.equippedWeaponId or "" }, player)
		for weaponId in pairs(state.weaponIds) do
			weaponPackets.assignWeapon.sendTo({ weaponId = weaponId }, player)
		end
	end))

	self.maid:GiveTask(player.CharacterRemoving:Connect(function()
		state:clearTransientState()
	end))
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
	if state then
		state:clearTransientState()
	end

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

	local targetPlayer = Players:GetPlayerFromCharacter(hitModel)
	local targetKey = targetPlayer and tostring(targetPlayer.UserId) or hitModel:GetDebugId()
	local now = os.clock()
	if not state:canHit(targetKey, now, config.combat.hitCooldown) then
		return
	end

	if self:_isBlocked(player, rootPart, targetPlayer, hitModel, config) then
		if targetPlayer then
			weaponPackets.feedback.sendTo({
				feedbackType = "blockSuccess",
				weaponId = config.id,
			}, targetPlayer)
		end
		return
	end

	local damage = weaponUtil.calculateDamage(hitPart.Name, config.combat.damage)
	hitHumanoid:TakeDamage(damage)
end

function weaponService:_isBlocked(attacker, attackerRootPart, targetPlayer, hitModel, config)
	if not targetPlayer then
		return false
	end

	local targetState = self.playerStates[targetPlayer]
	local targetCharacter = targetPlayer.Character
	local targetRootPart = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetState or not targetCharacter or not targetRootPart then
		return false
	end

	if not targetState.blockingWeaponId then
		return false
	end

	if hitModel ~= targetCharacter then
		return false
	end

	local attackDirection = (attackerRootPart.Position - targetRootPart.Position).Unit
	local facing = targetRootPart.CFrame.LookVector
	local angle = math.deg(math.acos(math.clamp(facing:Dot(attackDirection), -1, 1)))

	return angle <= (config.combat.blockAngle * 0.5)
end

function weaponService:_spawnHitPart(character, targetPosition, config)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local direction = targetPosition - rootPart.Position
	if direction.Magnitude <= 0 then
		return
	end

	local origin = rootPart.Position + rootPart.CFrame.LookVector * 3
	local part = Instance.new("Part")
	part.Name = config.id .. "Hit"
	part.Size = config.combat.hitPartSize
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Anchored = true
	part.Transparency = 1
	part.CFrame = CFrame.new(origin, origin + direction.Unit)
	part.Parent = workspace

	local startTime = os.clock()
	local heartbeatConnection
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not part.Parent then
			heartbeatConnection:Disconnect()
			return
		end

		local offset = direction.Unit * config.combat.hitPartSpeed * deltaTime
		part.CFrame += offset

		if os.clock() - startTime >= config.combat.hitPartLifetime then
			heartbeatConnection:Disconnect()
			part:Destroy()
		end
	end)

	Debris:AddItem(part, config.combat.hitPartLifetime)
end

function weaponService:_loadCharacterSounds(character, config)
	local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not upperTorso then
		return
	end

	local soundFolder = ReplicatedStorage:FindFirstChild("Sounds")
	local weaponFolder = soundFolder and soundFolder:FindFirstChild(config.weaponModelName)
	if not weaponFolder then
		return
	end

	for _, soundName in ipairs(config.sounds.swing) do
		self:_cloneSoundIfMissing(upperTorso, weaponFolder, soundName)
	end

	self:_cloneSoundIfMissing(upperTorso, weaponFolder, config.sounds.block)
end

function weaponService:_cloneSoundIfMissing(parent, sourceFolder, soundName)
	if parent:FindFirstChild(soundName) then
		return
	end

	local template = sourceFolder:FindFirstChild(soundName)
	if template and template:IsA("Sound") then
		template:Clone().Parent = parent
	end
end

function weaponService:_playSwingSound(player, character, config)
	local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not upperTorso then
		return
	end

	local lastIndex = self.swingIndices[player] or 0
	local nextIndex = (lastIndex % #config.sounds.swing) + 1
	self.swingIndices[player] = nextIndex

	local sound = upperTorso:FindFirstChild(config.sounds.swing[nextIndex])
	if sound and sound:IsA("Sound") then
		sound.Volume = config.sounds.volume.swing
		sound:Stop()
		sound:Play()
	end
end

function weaponService:_playEffortSound(player, config)
	local folder = SoundService
	for _, name in ipairs(config.sounds.effortFolder) do
		folder = folder:FindFirstChild(name)
		if not folder then
			return
		end
	end

	local counter = (self.effortCounters[player] or 0) + 1
	self.effortCounters[player] = counter

	local threshold = self.effortThresholds[player] or math.random(4, 8)
	self.effortThresholds[player] = threshold

	if counter < threshold then
		return
	end

	self.effortCounters[player] = 0
	self.effortThresholds[player] = math.random(4, 8)

	local lastIndex = self.effortIndices[player] or 0
	local nextIndex = (lastIndex % #config.sounds.effort) + 1
	self.effortIndices[player] = nextIndex

	local sound = folder:FindFirstChild(config.sounds.effort[nextIndex])
	if sound and sound:IsA("Sound") then
		sound.Volume = config.sounds.volume.effort
		sound:Stop()
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
