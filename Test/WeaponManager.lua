local weaponManager = {}

function weaponManager.getRandomSound(soundTable)
	return soundTable[math.random(1, #soundTable)]
end

function weaponManager.applyTransparency(character, parts, transparency, modifier)
	for _, partName in pairs(parts) do
		local part = character:FindFirstChild(partName)
		if part then
			local handle = part:FindFirstChild("Handle")
			if handle then
				handle.Transparency = transparency
				handle.LocalTransparencyModifier = modifier or transparency

				local wrapLayer = handle:FindFirstChild("HandleWrapLayer")
				if wrapLayer then
					wrapLayer.Enabled = transparency == 0
				end
			else
				part.Transparency = transparency
				part.LocalTransparencyModifier = modifier or transparency
			end
		end
	end
end

function weaponManager.toggleParticles(viewmodel, particleNames, enabled)
	local rootPart = viewmodel:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local middleFolder = rootPart:FindFirstChild("MIDDLE")
	if not middleFolder then
		return
	end

	for _, particleName in pairs(particleNames) do
		local particle = middleFolder:FindFirstChild(particleName)
		if particle then
			particle.Enabled = enabled
		end
	end
end

function weaponManager.calculateDamage(hitPartName, damageConfig)
	if hitPartName == "Head" then
		return damageConfig.headshot
	elseif hitPartName == "UpperTorso" or hitPartName == "LowerTorso" or hitPartName == "Torso" then
		return damageConfig.bodyshot
	end
	return damageConfig.base
end

return weaponManager
