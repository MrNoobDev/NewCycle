local replicatedStorage = game:GetService("ReplicatedStorage")

local gentPipe = require(replicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("Configs"):WaitForChild("GentPipe"))
local weaponUtil = require(replicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponUtil"))

local weaponRegistry = {}

local weapons = {
	[gentPipe.id] = gentPipe,
}

function weaponRegistry.getWeaponConfig(weaponId)
	local config = weapons[weaponId]
	if not config then
		return nil
	end

	return weaponUtil.shallowCopy(config)
end

function weaponRegistry.getSpawnWeapons()
	local result = {}

	for weaponId, config in pairs(weapons) do
		if config.grantOnSpawn then
			table.insert(result, weaponId)
		end
	end

	table.sort(result)

	return result
end

function weaponRegistry.hasWeapon(weaponId)
	return weapons[weaponId] ~= nil
end

return weaponRegistry
