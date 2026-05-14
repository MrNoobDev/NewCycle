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
	self.blockStates = {}
	self.stunTokens = {}
	self.savedMovement = {}
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
		self.blockStates[player] = nil
		self.stunTokens[player] = nil
		self.savedMovement[player] = nil
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
	self.blockStates[player] = nil
	self.stunTokens[player] = nil
	self.savedMovement[player] = nil
end

function weaponService:_handleCharacterAdded(player, character)
	local state = self.playerStates[player]
	if not state then
		return
	end

	state:clearTransientState()

	character:SetAttribute("isBlocking", false)
	character:SetAttribute("blockingWeaponId", "")
	character:SetAttribute("blockWindow", "None")
	character:SetAttribute("guard", 100)
	character:SetAttribute("isWeaponStunned", false)
	character:SetAttribute("blockBroken", false)

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

	if character:GetAttribute("isWeaponStunned") then
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

	local targetPosition = data.targetPosition
	local attackCastDelay = config.combat.attackCastDelay or 0.22

	task.delay(attackCastDelay, function()
		if not player.Parent then
			return
		end

		local currentCharacter = player.Character
		local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
		local currentRootPart = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")

		if currentCharacter ~= character then
			return
		end

		if not currentCharacter or not currentHumanoid or currentHumanoid.Health <= 0 or not currentRootPart then
			return
		end

		if currentCharacter:GetAttribute("isWeaponStunned") then
			return
		end

		self:_spawnHitPart(currentCharacter, targetPosition, config)
		self:_resolveAttack(player, state, currentCharacter, currentRootPart, targetPosition, config)
	end)
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

	if character:GetAttribute("isWeaponStunned") then
		return
	end

	local now = os.clock()
	local blockInfo = self.blockStates[player]

	if data.isActive then
		if blockInfo and blockInfo.isActive then
			return
		end

		if blockInfo and blockInfo.cooldownUntil and now < blockInfo.cooldownUntil then
			return
		end

		local perfectWindow = config.combat.perfectBlockWindow or 0.2
		local maxBlockTime = config.combat.maxBlockTime or 1.25

		blockInfo = {
			startTime = now,
			perfectUntil = now + perfectWindow,
			endTime = now + maxBlockTime,
			cooldownUntil = 0,
			isActive = true,
			weaponId = weaponId,
		}

		self.blockStates[player] = blockInfo

		state:setBlocking(weaponId, true)
		character:SetAttribute("isBlocking", true)
		character:SetAttribute("blockingWeaponId", weaponId)
		character:SetAttribute("blockWindow", "Perfect")
		character:SetAttribute("blockBroken", false)

		task.delay(perfectWindow, function()
			local current = self.blockStates[player]
			if not current or current ~= blockInfo or not current.isActive then
				return
			end

			local currentCharacter = player.Character
			if currentCharacter then
				currentCharacter:SetAttribute("blockWindow", "Normal")
			end
		end)

		task.delay(maxBlockTime, function()
			local current = self.blockStates[player]
			if not current or current ~= blockInfo or not current.isActive then
				return
			end

			self:_endServerBlock(player, "timeout")
		end)
	else
		if blockInfo and blockInfo.isActive then
			self:_endServerBlock(player, "release")
		end
	end
end

function weaponService:_endServerBlock(player, reason)
	local state = self.playerStates[player]
	local character = player.Character
	local blockInfo = self.blockStates[player]

	local config
	if blockInfo and blockInfo.weaponId then
		config = weaponRegistry.getWeaponConfig(blockInfo.weaponId)
	end

	local cooldown
	if reason == "timeout" then
		cooldown = config and config.combat.blockTimeoutCooldown or 0.5
	elseif reason == "break" then
		cooldown = config and config.combat.blockBreakCooldown or 0.9
	else
		cooldown = config and config.combat.blockCooldown or 0.35
	end

	self.blockStates[player] = {
		isActive = false,
		cooldownUntil = os.clock() + cooldown,
		weaponId = blockInfo and blockInfo.weaponId or "",
	}

	if state and blockInfo and blockInfo.weaponId then
		state:setBlocking(blockInfo.weaponId, false)
	end

	if character then
		character:SetAttribute("isBlocking", false)
		character:SetAttribute("blockingWeaponId", "")
		character:SetAttribute("blockWindow", "None")
	end
end

function weaponService:_resolveAttack(player, state, character, rootPart, targetPosition, config)
	local origin = rootPart.Position
	local lookDirection = rootPart.CFrame.LookVector

	local targetDirection = targetPosition - origin
	if targetDirection.Magnitude > 0.1 then
		local flatTargetDirection = Vector3.new(targetDirection.X, 0, targetDirection.Z)
		if flatTargetDirection.Magnitude > 0.1 then
			lookDirection = flatTargetDirection.Unit
		end
	end

	local maxHitDistance = config.combat.maxHitDistance or 6.5
	local hitBoxSize = config.combat.hitBoxSize or Vector3.new(5, 4, 5.5)
	local forwardOffset = config.combat.hitBoxForwardOffset or 2.8

	local castCenter = origin + lookDirection * forwardOffset
	local castCFrame = CFrame.lookAt(castCenter, castCenter + lookDirection)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }

	local parts = workspace:GetPartBoundsInBox(castCFrame, hitBoxSize, overlapParams)

	if config.combat.debugHitVisualizer then
		self:_drawDebugBox(castCFrame, hitBoxSize)
	end

	local bestModel = nil
	local bestHumanoid = nil
	local bestPart = nil
	local bestDistance = math.huge

	for _, part in ipairs(parts) do
		local hitModel = part:FindFirstAncestorOfClass("Model")
		local hitHumanoid = hitModel and hitModel:FindFirstChildOfClass("Humanoid")

		if hitHumanoid and hitHumanoid.Health > 0 and hitModel ~= character then
			local hitRoot = hitModel:FindFirstChild("HumanoidRootPart") or part
			local distance = (hitRoot.Position - origin).Magnitude

			if distance <= maxHitDistance and distance < bestDistance then
				bestModel = hitModel
				bestHumanoid = hitHumanoid
				bestPart = part
				bestDistance = distance
			end
		end
	end

	if not bestModel or not bestHumanoid or not bestPart then
		if config.combat.debugHitVisualizer then
			print("[WeaponService] Swing missed")
		end
		return
	end

	print(
		"[WeaponService] Hit:",
		bestModel.Name,
		"Part:",
		bestPart.Name,
		"Distance:",
		math.round(bestDistance * 100) / 100
	)

	local now = os.clock()
	if not state:canHit(bestModel, now, config.combat.hitCooldown) then
		return
	end

	local damage, distanceMultiplier = self:_getDistanceScaledDamage(bestDistance, config)
	local blockResult = self:_tryBlockAttack(bestModel, rootPart.Position, config)

	if blockResult and blockResult.blocked then
		local defenderPlayer = Players:GetPlayerFromCharacter(bestModel)

		if defenderPlayer then
			weaponPackets.feedback.sendTo({
				feedbackType = blockResult.feedbackType,
				weaponId = bestModel:GetAttribute("blockingWeaponId") or state.equippedWeaponId or config.id,
			}, defenderPlayer)
		end

		if blockResult.perfect then
			self:_stunCharacter(character, config.combat.parriedStunDuration or 1)

			weaponPackets.feedback.sendTo({
				feedbackType = "parriedStun",
				weaponId = state.equippedWeaponId or config.id,
			}, player)

			print("[WeaponService] Perfect blocked. Damage: 0")
			return
		end

		if blockResult.broke then
			local defenderPlayerForBreak = Players:GetPlayerFromCharacter(bestModel)

			if defenderPlayerForBreak then
				self:_endServerBlock(defenderPlayerForBreak, "break")

				weaponPackets.feedback.sendTo({
					feedbackType = "blockBreak",
					weaponId = bestModel:GetAttribute("blockingWeaponId") or config.id,
				}, defenderPlayerForBreak)
			end

			self:_stunCharacter(bestModel, config.combat.blockBreakStun or 0.6)
		end

		damage = math.floor((damage * blockResult.damageMultiplier) + 0.5)

		print("[WeaponService] Blocked damage:", damage)

		if damage > 0 then
			bestHumanoid:TakeDamage(damage)
		end

		return
	end

	print("[WeaponService] Damage:", damage, "Distance Multiplier:", math.round(distanceMultiplier * 100) / 100)

	self:_spawnInkHitVfx(rootPart, bestModel, config)
	bestHumanoid:TakeDamage(damage)
end

function weaponService:_tryBlockAttack(hitModel, attackerPosition, config)
	if not hitModel:GetAttribute("isBlocking") then
		return nil
	end

	if hitModel:GetAttribute("blockingWeaponId") == "" then
		return nil
	end

	local rootPart = hitModel:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	local toAttacker = attackerPosition - rootPart.Position
	if toAttacker.Magnitude <= 0 then
		return nil
	end

	local facing = rootPart.CFrame.LookVector
	local angle = math.deg(math.acos(math.clamp(facing:Dot(toAttacker.Unit), -1, 1)))
	if angle > (config.combat.blockAngle or 120) then
		return nil
	end

	local blockWindow = hitModel:GetAttribute("blockWindow") or "None"

	if blockWindow == "Perfect" then
		return {
			blocked = true,
			perfect = true,
			broke = false,
			damageMultiplier = 0,
			feedbackType = "blockPerfect",
		}
	end

	local guard = hitModel:GetAttribute("guard") or 100
	local guardDamage = config.combat.guardDamage or 25
	local remainingGuard = math.max(guard - guardDamage, 0)
	hitModel:SetAttribute("guard", remainingGuard)

	if remainingGuard <= 0 then
		return {
			blocked = true,
			perfect = false,
			broke = true,
			damageMultiplier = config.combat.blockBreakDamageMultiplier or 0.75,
			feedbackType = "blockBreak",
		}
	end

	return {
		blocked = true,
		perfect = false,
		broke = false,
		damageMultiplier = config.combat.blockDamageMultiplier or 0.35,
		feedbackType = "blockSuccess",
	}
end

function weaponService:_stunCharacter(character, duration)
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	duration = duration or 1

	if player then
		self.stunTokens[player] = (self.stunTokens[player] or 0) + 1
		local token = self.stunTokens[player]

		if not self.savedMovement[player] then
			self.savedMovement[player] = {
				walkSpeed = humanoid.WalkSpeed,
				jumpPower = humanoid.JumpPower,
				jumpHeight = humanoid.JumpHeight,
			}
		end

		character:SetAttribute("isWeaponStunned", true)
		humanoid:SetAttribute("WeaponStunned", true)

		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0

		task.delay(duration, function()
			if self.stunTokens[player] ~= token then
				return
			end

			local currentCharacter = player.Character
			local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
			local saved = self.savedMovement[player]

			if currentCharacter then
				currentCharacter:SetAttribute("isWeaponStunned", false)
			end

			if currentHumanoid then
				currentHumanoid:SetAttribute("WeaponStunned", false)

				if saved then
					currentHumanoid.WalkSpeed = saved.walkSpeed
					currentHumanoid.JumpPower = saved.jumpPower
					currentHumanoid.JumpHeight = saved.jumpHeight
				end
			end

			self.savedMovement[player] = nil
		end)
	else
		character:SetAttribute("isWeaponStunned", true)
		humanoid.WalkSpeed = 0

		task.delay(duration, function()
			if character then
				character:SetAttribute("isWeaponStunned", false)
			end
		end)
	end
end

function weaponService:_spawnHitPart(character, targetPosition, config)
	if not config.combat.debugHitVisualizer then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local direction = targetPosition - rootPart.Position
	if direction.Magnitude <= 0 then
		return
	end

	local distance = math.min(direction.Magnitude, config.combat.maxHitDistance or 6.5)
	local castCFrame = CFrame.lookAt(rootPart.Position, targetPosition) + direction.Unit * distance

	local hitPart = Instance.new("Part")
	hitPart.Name = "weaponHitPart"
	hitPart.Size = config.combat.hitPartSize or Vector3.new(2, 2, 4)
	hitPart.Anchored = true
	hitPart.CanCollide = false
	hitPart.CanQuery = false
	hitPart.CanTouch = false
	hitPart.Transparency = 0.75
	hitPart.Material = Enum.Material.Neon
	hitPart.Color = Color3.fromRGB(255, 180, 40)
	hitPart.CFrame = castCFrame
	hitPart.Parent = workspace

	Debris:AddItem(hitPart, config.combat.hitPartLifetime or 0.15)
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
	if not torso then
		return
	end

	local toolsFolder = SoundService:FindFirstChild("Tools")
	local axeFolder = toolsFolder and toolsFolder:FindFirstChild("Axe")

	if axeFolder then
		local soundName = string.format("sfx_weapon_gent_whoosh_base_%02d", math.random(1, 6))
		local source = axeFolder:FindFirstChild(soundName)

		if source and source:IsA("Sound") then
			local sound = source:Clone()
			sound.Looped = false
			sound.Parent = torso
			sound:Play()
			Debris:AddItem(sound, math.max(sound.TimeLength, 1) + 0.25)
			return
		end
	end

	local swings = config.sounds and config.sounds.swing
	if not swings or #swings == 0 then
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

function weaponService:_getDistanceScaledDamage(distance, config)
	local maxDistance = config.combat.maxHitDistance or 6.5
	local closeDistance = config.combat.closeDamageDistance or 1.75

	local baseDamage = config.combat.baseDamage or 28
	local minMultiplier = config.combat.minDistanceDamageMultiplier or 0.8

	if distance <= closeDistance then
		return baseDamage, 1
	end

	local alpha = math.clamp((distance - closeDistance) / math.max(maxDistance - closeDistance, 0.001), 0, 1)
	local multiplier = 1 + (minMultiplier - 1) * alpha
	local damage = baseDamage * multiplier

	return math.floor(damage + 0.5), multiplier
end

function weaponService:_drawDebugBox(cframe, size)
	local debugPart = Instance.new("Part")
	debugPart.Name = "weaponDebugHitBox"
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.CanQuery = false
	debugPart.CanTouch = false
	debugPart.Material = Enum.Material.Neon
	debugPart.Size = size
	debugPart.CFrame = cframe
	debugPart.Transparency = 0.75
	debugPart.Color = Color3.fromRGB(255, 180, 40)
	debugPart.Parent = workspace

	Debris:AddItem(debugPart, 0.2)
end

function weaponService:_spawnInkHitVfx(attackerRoot, hitModel, config)
	if not hitModel or not config then
		return
	end

	local effects = config.effects
	if not effects then
		return
	end

	local vfxPath = effects.hitInkVfxPath or { "Assets", "VFX", "WeaponHitInk", "Attachment" }
	local source = ReplicatedStorage

	for _, childName in ipairs(vfxPath) do
		source = source and source:FindFirstChild(childName)
		if not source then
			return
		end
	end

	if not source or not source:IsA("Attachment") then
		warn("[WeaponService] hitInkVfxPath must point to an Attachment")
		return
	end

	local enemyRoot = hitModel:FindFirstChild("HumanoidRootPart")
	if not enemyRoot then
		return
	end

	local attachment = source:Clone()
	attachment.Parent = enemyRoot
	attachment.CFrame = CFrame.new()

	local emitConfig = effects.hitInkEmit or {
		blood1 = 8,
		blood2 = 4,
	}

	local dripOutTime = effects.hitInkDripOutTime or 1
	local lifetime = effects.hitInkLifetime or (dripOutTime + 0.35)

	for _, descendant in ipairs(attachment:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			if descendant.Name == "DripOut" then
				descendant.Enabled = true

				task.delay(dripOutTime, function()
					if descendant and descendant.Parent then
						descendant.Enabled = false
					end
				end)
			else
				local emitAmount = emitConfig[descendant.Name] or descendant:GetAttribute("EmitCount") or 8
				descendant:Emit(emitAmount)
			end
		end
	end

	Debris:AddItem(attachment, lifetime)
end

function weaponService:Destroy()
	for player, state in pairs(self.playerStates) do
		state:destroy()
		self.playerStates[player] = nil
	end

	self.maid:DoCleaning()
end

return weaponService
