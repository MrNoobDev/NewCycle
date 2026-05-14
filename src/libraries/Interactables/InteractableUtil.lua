local interactableUtil = {}

function interactableUtil.resolvePosition(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	end

	if instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart.Position
		end

		return instance:GetPivot().Position
	end

	return nil
end

function interactableUtil.getClosestPointToInstance(instance: Instance, fromPosition: Vector3): Vector3?
	if instance:IsA("BasePart") then
		return instance:GetClosestPointOnSurface(fromPosition)
	end

	if instance:IsA("Model") then
		local closestPoint = nil
		local closestDistance = math.huge

		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.CanQuery then
				local point = descendant:GetClosestPointOnSurface(fromPosition)
				local distance = (point - fromPosition).Magnitude

				if distance < closestDistance then
					closestDistance = distance
					closestPoint = point
				end
			end
		end

		return closestPoint or instance:GetPivot().Position
	end

	return nil
end

function interactableUtil.getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

function interactableUtil.findTaggedAncestor(instance: Instance, tag: string, collectionService): Instance?
	local node: Instance? = instance

	while node and node ~= workspace do
		if collectionService:HasTag(node, tag) then
			return node
		end

		node = node.Parent
	end

	return nil
end

function interactableUtil.playRandomSoundIn(instance: Instance, soundName: string)
	local candidates = {}

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant.Name == soundName then
			for _, child in ipairs(descendant:GetChildren()) do
				if child:IsA("Sound") then
					table.insert(candidates, child)
				end
			end
		end
	end

	if #candidates <= 0 then
		return
	end

	candidates[math.random(1, #candidates)]:Play()
end

function interactableUtil.playDetachedSoundFrom(instance: Instance)
	local sounds = {}

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Sound") then
			table.insert(sounds, descendant)
		end
	end

	if #sounds <= 0 then
		return
	end

	local source = sounds[math.random(1, #sounds)]
	local clone = source:Clone()
	clone.Parent = workspace.Terrain
	clone:Play()

	task.delay((clone.TimeLength > 0 and clone.TimeLength or 3) + 0.5, function()
		if clone then
			clone:Destroy()
		end
	end)
end

function interactableUtil.setInstanceVisible(instance: Instance, visible: boolean)
	local transparency = visible and 0 or 1

	if instance:IsA("BasePart") then
		instance.Transparency = transparency
		instance.CanQuery = visible
		instance.CanTouch = visible
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = transparency
			descendant.CanQuery = visible
			descendant.CanTouch = visible
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = transparency
		end
	end
end

return interactableUtil
