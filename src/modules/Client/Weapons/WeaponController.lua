-- weapon controller
--//

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	self.canAttack = true
	self.swingIndex = 0
	self.isEquipped = false
	self.viewmodelController = viewmodelController.new(player, config)
	self.busyToken = 0
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
			self:stopBlock()
		end
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
	if not self.isEquipped or not self.canAttack or self.isBlocking or not self.character then
		return
	end

	self.swingIndex = self.swingIndex % 2 + 1
	self.canAttack = false
	self:_setWeaponBusy(true)

	self.viewmodelController:playAttack(self.swingIndex)
	self.viewmodelController:impulseShake(self.config.camera.attackShake)

	weaponPackets.requestAttack.send({
		weaponId = self.config.id,
		targetPosition = targetPosition,
		swingIndex = self.swingIndex,
	})

	task.delay(self.config.combat.attackCooldown, function()
		self.canAttack = true
		self:_setWeaponBusy(false)
		if self.isEquipped and not self.isBlocking then
			self.viewmodelController:playIdle()
		end
	end)
end

function weaponController:startBlock()
	if not self.isEquipped or self.isBlocking or not self.character then
		return
	end

	self.isBlocking = true
	self:_applyStateAttributes()
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
	self:_applyStateAttributes()
	self.viewmodelController:stopBlock()

	weaponPackets.requestBlock.send({
		weaponId = self.config.id,
		isActive = false,
	})
end

function weaponController:handleFeedback(feedbackType)
	if feedbackType == "blockSuccess" then
		self.viewmodelController:showBlockFeedback()

		local upperTorso = self.character
			and (self.character:FindFirstChild("UpperTorso") or self.character:FindFirstChild("Torso"))
		local blockSound = upperTorso and upperTorso:FindFirstChild(self.config.sounds.block)
		if blockSound and blockSound:IsA("Sound") then
			blockSound:Play()
		end

		self:stopBlock()
	end
end

function weaponController:destroy()
	if self.isBlocking then
		self:stopBlock()
	end

	self:_applyEquippedVisuals(false)
	self.viewmodelController:destroy()
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
		task.delay(self.config.combat.attackCooldown, function()
			if self.character and self.busyToken == token then
				humanoid:SetAttribute("WeaponBusy", false)
			end
		end)
	else
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
