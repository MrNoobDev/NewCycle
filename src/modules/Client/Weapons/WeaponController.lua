local ReplicatedStorage = game:GetService("ReplicatedStorage")

local weaponUtil = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponUtil"))
local weaponPackets = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponPackets"))

local viewmodelController = require(script.Parent.ViewmodelController)

local weaponController = {}
weaponController.__index = weaponController

function weaponController.new(player, config)
	local self = setmetatable({}, weaponController)
	self.player = player
	self.config = config
	self.character = nil
	self.isBlocking = false
	self.canAttack = true
	self.swingIndex = 0
	self.viewmodelController = viewmodelController.new(player, config)
	return self
end

function weaponController:setCharacter(character)
	self.character = character
	self.viewmodelController:setCharacter(character)
	self.viewmodelController:load()
end

function weaponController:update()
	self.viewmodelController:update()
end

function weaponController:attack(targetPosition)
	if not self.canAttack or self.isBlocking or not self.character then
		return
	end

	self.swingIndex = self.swingIndex % 2 + 1
	self.canAttack = false

	self.viewmodelController:playAttack(self.swingIndex)
	self.viewmodelController:impulseShake(self.config.camera.attackShake)

	weaponPackets.requestAttack.send({
		weaponId = self.config.id,
		targetPosition = targetPosition,
		swingIndex = self.swingIndex,
	})

	task.delay(self.config.combat.attackCooldown, function()
		self.canAttack = true
		if not self.isBlocking then
			self.viewmodelController:playIdle()
		end
	end)
end

function weaponController:startBlock()
	if self.isBlocking or not self.character then
		return
	end

	self.isBlocking = true
	weaponUtil.setCharacterPartTransparency(
		self.character,
		self.config.effects.defenceVisuals.hide,
		1,
		1
	)
	weaponUtil.setCharacterPartTransparency(
		self.character,
		self.config.effects.defenceVisuals.show,
		0,
		0
	)

	self.viewmodelController:startBlock()
	weaponPackets.requestBlock.send({
		weaponId = self.config.id,
		isActive = true,
	})
end

function weaponController:stopBlock()
	if not self.isBlocking or not self.character then
		return
	end

	self.isBlocking = false
	weaponUtil.setCharacterPartTransparency(
		self.character,
		self.config.effects.defenceVisuals.hide,
		0,
		0
	)
	weaponUtil.setCharacterPartTransparency(
		self.character,
		self.config.effects.defenceVisuals.show,
		1,
		1
	)

	self.viewmodelController:stopBlock()
	weaponPackets.requestBlock.send({
		weaponId = self.config.id,
		isActive = false,
	})
end

function weaponController:handleFeedback(feedbackType)
	if feedbackType == "blockSuccess" then
		self.viewmodelController:showBlockFeedback()

		local upperTorso = self.character and (self.character:FindFirstChild("UpperTorso") or self.character:FindFirstChild("Torso"))
		local blockSound = upperTorso and upperTorso:FindFirstChild(self.config.sounds.block)
		if blockSound and blockSound:IsA("Sound") then
			blockSound:Play()
		end

		self:stopBlock()
	end
end

function weaponController:destroy()
	self:stopBlock()
	self.viewmodelController:destroy()
end

return weaponController
