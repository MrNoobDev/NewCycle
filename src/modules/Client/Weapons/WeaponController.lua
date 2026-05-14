-- weapon controller
--//

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local weaponPackets =
	require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponPackets"))
local weaponUtil =
	require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponUtil"))

local viewmodelController = require(script.Parent.ViewmodelController)

local weaponController = {}
weaponController.__index = weaponController

function weaponController.new(player, config)
	local self = setmetatable({}, weaponController)

	self.player = player
	self.config = config
	self.character = nil

	self.isBlocking = false
	self.blockWindow = "None"
	self.nextBlockTime = 0
	self.blockToken = 0

	self.isStunned = false
	self.stunToken = 0
	self.savedWalkSpeed = nil
	self.savedJumpPower = nil
	self.savedJumpHeight = nil

	self.canAttack = true
	self.nextAttackTime = 0
	self.swingIndex = 0
	self.isEquipped = false
	self.busyToken = 0

	self.viewmodelController = viewmodelController.new(player, config)

	return self
end

function weaponController:setCharacter(character)
	self.character = character
	self.viewmodelController:setCharacter(character)
	self:_applyStateAttributes()

	if self.isEquipped then
		self:_applyEquippedVisuals(true)
		self.viewmodelController:load()
	else
		self:_applyEquippedVisuals(false)
		self.viewmodelController:destroyViewmodel()
	end
end

function weaponController:setEquipped(isEquipped)
	self.isEquipped = isEquipped
	self:_applyStateAttributes()

	if isEquipped then
		self:_applyEquippedVisuals(true)
		self.viewmodelController:load()
	else
		if self.isBlocking then
			self:_endBlock("release", true)
		end

		self.canAttack = true
		self.nextAttackTime = 0
		self.blockWindow = "None"
		self.blockToken += 1

		self:_setWeaponBusy(false)
		self:_applyEquippedVisuals(false)
		self.viewmodelController:destroyViewmodel()
	end
end

function weaponController:update(deltaTime)
	if self.isEquipped then
		self.viewmodelController:update(deltaTime)
	end
end

function weaponController:attack(targetPosition)
	local now = os.clock()
	local attackCooldown = self.config.combat.attackCooldown or 0.8

	if
		not self.isEquipped
		or not self.canAttack
		or self.isBlocking
		or self.isStunned
		or not self.character
		or now < self.nextAttackTime
	then
		return
	end

	self.nextAttackTime = now + attackCooldown
	self.canAttack = false
	self.swingIndex = self.swingIndex % 2 + 1

	self:_setWeaponBusy(true)
	self:_playSwingSound()

	self.viewmodelController:playAttack(self.swingIndex)
	self.viewmodelController:impulseShake(self.config.camera.attackShake)

	weaponPackets.requestAttack.send({
		weaponId = self.config.id,
		targetPosition = targetPosition,
		swingIndex = self.swingIndex,
	})

	task.delay(attackCooldown, function()
		if os.clock() >= self.nextAttackTime and not self.isStunned then
			self.canAttack = true
			self:_setWeaponBusy(false)
		end
	end)
end

function weaponController:startBlock()
	local now = os.clock()
	local perfectBlockWindow = self.config.combat.perfectBlockWindow or 0.2
	local maxBlockTime = self.config.combat.maxBlockTime or 1.25

	if not self.isEquipped or self.isBlocking or self.isStunned or not self.character or now < self.nextBlockTime then
		return
	end

	self.isBlocking = true
	self.blockWindow = "Perfect"
	self.blockToken += 1

	local token = self.blockToken

	self:_applyStateAttributes()
	self.viewmodelController:startBlock()

	weaponPackets.requestBlock.send({
		weaponId = self.config.id,
		isActive = true,
	})

	task.delay(perfectBlockWindow, function()
		if self.blockToken ~= token then
			return
		end

		if self.isEquipped and self.isBlocking and not self.isStunned then
			self.blockWindow = "Normal"
			self:_applyStateAttributes()
		end
	end)

	task.delay(maxBlockTime, function()
		if self.blockToken ~= token then
			return
		end

		if self.isEquipped and self.isBlocking then
			self:_endBlock("timeout")
		end
	end)
end

function weaponController:stopBlock()
	if not self.isBlocking then
		return
	end

	self:_endBlock("release")
end

function weaponController:handleFeedback(feedbackType)
	if feedbackType == "blockPerfect" then
		self.viewmodelController:showBlockFeedback("Perfect")
		self:_playBlockSound()
	elseif feedbackType == "blockSuccess" then
		self.viewmodelController:showBlockFeedback("Normal")
		self:_playBlockSound()
	elseif feedbackType == "blockBreak" then
		self:_breakBlock()
	elseif feedbackType == "playerStunned" or feedbackType == "parriedStun" then
		self:_stunPlayer(self.config.combat.parriedStunDuration or 1)
	end
end

function weaponController:destroy()
	if self.isBlocking then
		self:_endBlock("release", true)
	end

	self.blockToken += 1
	self.stunToken += 1

	self.canAttack = true
	self.nextAttackTime = 0
	self.blockWindow = "None"
	self.isStunned = false

	self:_restoreMovement()
	self:_setWeaponBusy(false)
	self:_applyEquippedVisuals(false)
	self.viewmodelController:destroy()
end

function weaponController:_endBlock(reason, silent)
	local now = os.clock()
	local cooldown

	if reason == "timeout" then
		cooldown = self.config.combat.blockTimeoutCooldown or 0.5
	elseif reason == "break" then
		cooldown = self.config.combat.blockBreakCooldown or 0.9
	else
		cooldown = self.config.combat.blockCooldown or 0.35
	end

	self.isBlocking = false
	self.blockWindow = "None"
	self.blockToken += 1
	self.nextBlockTime = now + cooldown

	self:_applyStateAttributes()

	if self.viewmodelController then
		self.viewmodelController:stopBlock()
	end

	if not silent then
		weaponPackets.requestBlock.send({
			weaponId = self.config.id,
			isActive = false,
		})
	end
end

function weaponController:_breakBlock()
	if self.isBlocking then
		self:_endBlock("break", true)
	else
		self.blockWindow = "None"
		self.nextBlockTime = os.clock() + (self.config.combat.blockBreakCooldown or 0.9)
		self:_applyStateAttributes()
	end

	if self.viewmodelController then
		self.viewmodelController:playBlockBreak()
	end

	self:_stunPlayer(self.config.combat.blockBreakStun or 0.6)
end

function weaponController:_stunPlayer(duration)
	if not self.character then
		return
	end

	duration = duration or 1

	self.stunToken += 1
	local token = self.stunToken

	if self.isBlocking then
		self:_endBlock("break", true)
	end

	self.isStunned = true
	self.canAttack = false
	self:_setWeaponBusy(true)
	self:_lockMovement()
	self:_applyStateAttributes()

	task.delay(duration, function()
		if self.stunToken ~= token then
			return
		end

		self.isStunned = false
		self:_restoreMovement()
		self:_applyStateAttributes()

		if os.clock() >= self.nextAttackTime then
			self.canAttack = true
			self:_setWeaponBusy(false)
		end

		if self.isEquipped and not self.isBlocking and self.viewmodelController then
			self.viewmodelController:playIdle()
		end
	end)
end

function weaponController:_lockMovement()
	local humanoid = self.character and self.character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if self.savedWalkSpeed == nil then
		self.savedWalkSpeed = humanoid.WalkSpeed
	end

	if self.savedJumpPower == nil then
		self.savedJumpPower = humanoid.JumpPower
	end

	if self.savedJumpHeight == nil then
		self.savedJumpHeight = humanoid.JumpHeight
	end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
end

function weaponController:_restoreMovement()
	local humanoid = self.character and self.character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if self.savedWalkSpeed ~= nil then
		humanoid.WalkSpeed = self.savedWalkSpeed
	end

	if self.savedJumpPower ~= nil then
		humanoid.JumpPower = self.savedJumpPower
	end

	if self.savedJumpHeight ~= nil then
		humanoid.JumpHeight = self.savedJumpHeight
	end

	self.savedWalkSpeed = nil
	self.savedJumpPower = nil
	self.savedJumpHeight = nil
end

function weaponController:_playSwingSound()
	local toolsFolder = SoundService:FindFirstChild("Tools")
	local axeFolder = toolsFolder and toolsFolder:FindFirstChild("Axe")
	if not axeFolder then
		return
	end

	local soundName = string.format("sfx_weapon_gent_whoosh_base_%02d", math.random(1, 6))
	local sourceSound = axeFolder:FindFirstChild(soundName)

	if sourceSound and sourceSound:IsA("Sound") then
		local swingSound = sourceSound:Clone()
		swingSound.Looped = false
		swingSound.Parent = SoundService
		swingSound:Play()

		Debris:AddItem(swingSound, math.max(swingSound.TimeLength, 1) + 0.25)
	end
end

function weaponController:_playBlockSound()
	local upperTorso = self.character
		and (self.character:FindFirstChild("UpperTorso") or self.character:FindFirstChild("Torso"))

	local blockSound = upperTorso
		and self.config.sounds
		and self.config.sounds.block
		and upperTorso:FindFirstChild(self.config.sounds.block)
	if blockSound and blockSound:IsA("Sound") then
		blockSound:Play()
	end
end

function weaponController:_applyEquippedVisuals(isEquipped)
	if not self.character then
		return
	end

	local visuals = self.config.effects and self.config.effects.defenceVisuals
	if not visuals then
		return
	end

	if isEquipped then
		weaponUtil.setCharacterPartTransparency(self.character, visuals.hide or {}, 1, 1)
		weaponUtil.setCharacterPartTransparency(self.character, visuals.show or {}, 0, 0)
	else
		weaponUtil.setCharacterPartTransparency(self.character, visuals.hide or {}, 0, 0)
		weaponUtil.setCharacterPartTransparency(self.character, visuals.show or {}, 1, 1)
	end
end

function weaponController:_setWeaponBusy(isBusy)
	local humanoid = self.character and self.character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if isBusy then
		self.busyToken += 1
		local token = self.busyToken

		humanoid:SetAttribute("WeaponBusy", true)

		task.delay((self.config.combat.attackCooldown or 0.8), function()
			if self.character and self.busyToken == token and not self.isStunned then
				humanoid:SetAttribute("WeaponBusy", false)
			end
		end)
	else
		self.busyToken += 1
		humanoid:SetAttribute("WeaponBusy", false)
	end
end

function weaponController:_applyStateAttributes()
	local humanoid = self.character and self.character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid:SetAttribute("WeaponEquipped", self.isEquipped)
	humanoid:SetAttribute("WeaponBlocking", self.isBlocking)
	humanoid:SetAttribute("WeaponBlockWindow", self.blockWindow)
	humanoid:SetAttribute("WeaponStunned", self.isStunned)

	if self.character then
		self.character:SetAttribute("isBlocking", self.isBlocking)
		self.character:SetAttribute("blockWindow", self.blockWindow)
		self.character:SetAttribute("isWeaponStunned", self.isStunned)
		self.character:SetAttribute("blockingWeaponId", self.isBlocking and self.config.id or "")
	end

	if not self.isEquipped then
		humanoid:SetAttribute("WeaponBusy", false)
	end

	local visuals = self.config.effects and self.config.effects.defenceVisuals
	if not visuals then
		return
	end

	for _, partName in ipairs(visuals.show or {}) do
		local part = self.character and self.character:FindFirstChild(partName, true)
		if part and part:IsA("BasePart") then
			part:SetAttribute("ForceVisibleInFirstPerson", self.isEquipped)
		end
	end
end

function weaponController:setStage(stage)
	self.config.stage = math.clamp(tonumber(stage) or 1, 1, 3)

	if self.isEquipped and self.viewmodelController and self.viewmodelController.viewmodel then
		self.viewmodelController:_setPartsVisible(true)
	end
end

return weaponController
