local replicatedStorage = game:GetService("ReplicatedStorage")

local weaponRegistry = require(replicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponRegistry"))

local weaponPlayerState = {}
weaponPlayerState.__index = weaponPlayerState

function weaponPlayerState.new(player)
	local self = setmetatable({}, weaponPlayerState)
	self.player = player
	self.weaponIds = {}
	self.equippedWeaponId = nil
	self.nextAttackTime = 0
	self.blockingWeaponId = nil
	self.hitCooldowns = {}
	return self
end

function weaponPlayerState:clearTransientState()
	self.nextAttackTime = 0
	self.blockingWeaponId = nil
	table.clear(self.hitCooldowns)
end

function weaponPlayerState:grantWeapon(weaponId)
	if not weaponRegistry.hasWeapon(weaponId) then
		return false
	end

	if self.weaponIds[weaponId] then
		return false
	end

	self.weaponIds[weaponId] = true
	if not self.equippedWeaponId then
		self.equippedWeaponId = weaponId
	end

	return true
end

function weaponPlayerState:hasWeapon(weaponId)
	return self.weaponIds[weaponId] == true
end

function weaponPlayerState:isWeaponEquipped(weaponId)
	return self.equippedWeaponId == weaponId
end

function weaponPlayerState:setBlocking(weaponId, isActive)
	if isActive then
		self.blockingWeaponId = weaponId
	elseif self.blockingWeaponId == weaponId then
		self.blockingWeaponId = nil
	end
end

function weaponPlayerState:isBlocking(weaponId)
	return self.blockingWeaponId == weaponId
end

function weaponPlayerState:canAttack(now)
	return now >= self.nextAttackTime
end

function weaponPlayerState:setAttackCooldown(now, cooldown)
	self.nextAttackTime = now + cooldown
end

function weaponPlayerState:canHit(targetKey, now, hitCooldown)
	local expiresAt = self.hitCooldowns[targetKey]
	if expiresAt and expiresAt > now then
		return false
	end

	self.hitCooldowns[targetKey] = now + hitCooldown
	return true
end

function weaponPlayerState:destroy()
	table.clear(self.weaponIds)
	table.clear(self.hitCooldowns)
end

return weaponPlayerState
