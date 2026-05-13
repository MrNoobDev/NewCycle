local weaponUtil = {}

local torsoNames = {
	UpperTorso = true,
	LowerTorso = true,
	Torso = true,
}

function weaponUtil.shallowCopy(source)
	local result = {}

	for key, value in pairs(source) do
		if type(value) == "table" then
			result[key] = weaponUtil.shallowCopy(value)
		else
			result[key] = value
		end
	end

	return result
end

function weaponUtil.merge(...)
	local result = {}

	for _, source in ipairs({ ... }) do
		if source then
			for key, value in pairs(source) do
				if type(value) == "table" then
					result[key] = weaponUtil.shallowCopy(value)
				else
					result[key] = value
				end
			end
		end
	end

	return result
end

function weaponUtil.findFirstDescendant(root, name)
	if not root then
		return nil
	end

	if root.Name == name then
		return root
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == name then
			return descendant
		end
	end

	return nil
end

function weaponUtil.setCharacterPartTransparency(character, partNames, transparency, localTransparencyModifier)
	for _, partName in ipairs(partNames) do
		local part = weaponUtil.findFirstDescendant(character, partName)
		if part and part:IsA("BasePart") then
			part.Transparency = transparency
			part.LocalTransparencyModifier = localTransparencyModifier or transparency
		end

		local handle = part and part:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.Transparency = transparency
			handle.LocalTransparencyModifier = localTransparencyModifier or transparency

			local wrapLayer = handle:FindFirstChild("HandleWrapLayer")
			if wrapLayer and wrapLayer:IsA("WrapLayer") then
				wrapLayer.Enabled = transparency == 0
			end
		end
	end
end

function weaponUtil.toggleViewmodelParticles(viewmodel, particleNames, isEnabled)
	if not viewmodel then
		return
	end

	for _, particleName in ipairs(particleNames) do
		local particle = weaponUtil.findFirstDescendant(viewmodel, particleName)
		if particle and particle:IsA("ParticleEmitter") then
			particle.Enabled = isEnabled
		end
	end
end

function weaponUtil.calculateDamage(hitPartName, damageConfig)
	if hitPartName == "Head" then
		return damageConfig.headshot
	end

	if torsoNames[hitPartName] then
		return damageConfig.bodyshot
	end

	return damageConfig.base
end

function weaponUtil.getTargetPosition(player, viewmodel)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local viewportSize = camera.ViewportSize
	local screenCenter = Vector2.new(viewportSize.X * 0.5, viewportSize.Y * 0.5)
	local ray = camera:ViewportPointToRay(screenCenter.X, screenCenter.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { player.Character, viewmodel }

	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
	if result then
		return result.Position
	end

	return ray.Origin + ray.Direction * 500
end

return weaponUtil
