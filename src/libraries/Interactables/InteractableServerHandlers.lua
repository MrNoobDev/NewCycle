local ReplicatedStorage = game:GetService("ReplicatedStorage")

local interactablesFolder = ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Interactables")
local packets = require(interactablesFolder:WaitForChild("InteractablePackets"))
local util = require(interactablesFolder:WaitForChild("InteractableUtil"))

local handlers = {}

local function getOpenDirection(root: BasePart, model: Model, hinge: BasePart, angleDeg: number): number
	local doorPart = model:FindFirstChild("Door", true)
	if not (doorPart and doorPart:IsA("BasePart")) then
		return 1
	end

	local hingePos = hinge.Position
	local axis = hinge.CFrame.UpVector
	local offset = doorPart.Position - hingePos

	local plus = CFrame.fromAxisAngle(axis, math.rad(angleDeg)) * offset
	local minus = CFrame.fromAxisAngle(axis, -math.rad(angleDeg)) * offset

	local distPlus = (hingePos + plus - root.Position).Magnitude
	local distMinus = (hingePos + minus - root.Position).Magnitude

	return if distPlus >= distMinus then 1 else -1
end

local function findHinge(model: Model): BasePart?
	local direct = model:FindFirstChild("Hinge")
	if direct and direct:IsA("BasePart") then
		return direct
	end

	local deep = model:FindFirstChild("Hinge", true)
	if deep and deep:IsA("BasePart") then
		return deep
	end

	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function ensureOpenState(instance: Instance): boolean
	local current = instance:GetAttribute("IsOpen")

	if current == nil then
		current = instance:GetAttribute("StartOpen") and true or false
		instance:SetAttribute("IsOpen", current)
	end

	return current and true or false
end

local function sendOpenableVisual(instance: Instance, prefix: string, isOpen: boolean)
	packets.playVisual.sendToAll({
		target = instance,
		visualType = if isOpen then prefix .. "Open" else prefix .. "Close",
	})
end

local function sendLockedVisual(instance: Instance, prefix: string)
	local bumps = instance:GetAttribute("LockedBumps") or 0
	instance:SetAttribute("LockedBumps", bumps + 1)

	packets.playVisual.sendToAll({
		target = instance,
		visualType = prefix .. "Locked",
	})
end

local function toggleOpenable(instance: Instance, prefix: string)
	ensureOpenState(instance)

	if instance:GetAttribute("Locked") then
		sendLockedVisual(instance, prefix)
		return
	end

	local isOpen = not (instance:GetAttribute("IsOpen") or false)
	instance:SetAttribute("IsOpen", isOpen)

	sendOpenableVisual(instance, prefix, isOpen)
end

local function awardPickup(player: Player, instance: Instance, context)
	local playerData = context and context.playerData
	if not playerData then
		return
	end

	local pickupType = instance:GetAttribute("PickupType")
	local amount = instance:GetAttribute("Amount") or instance:GetAttribute("PickupAmount") or 1

	if pickupType == "Key" then
		local keyId = instance:GetAttribute("KeyId")
		if type(keyId) ~= "string" or keyId == "" then
			warn("[Pickup] Key pickup missing KeyId:", instance:GetFullName())
			return
		end

		playerData:AddKey(player, keyId)
		return
	end

	if pickupType == "Slug" or pickupType == "Slugs" then
		playerData:AddSlugs(player, amount)
	elseif pickupType == "GentPart" or pickupType == "GentParts" then
		playerData:AddGentParts(player, amount)
	elseif pickupType == "Battery" or pickupType == "Batteries" then
		playerData:AddBatteries(player, amount)
	elseif pickupType == "ToolKit" or pickupType == "ToolKits" then
		playerData:AddToolKits(player, amount)
	elseif pickupType == "GentCard" or pickupType == "GentCards" then
		playerData:AddGentCards(player, amount)
	elseif type(pickupType) == "string" and pickupType ~= "" then
		playerData:AddItem(player, pickupType, amount)
	end
end

local function applyConsumable(player: Player, instance: Instance, context)
	local playerData = context and context.playerData
	if not playerData then
		return
	end

	local consumableType = instance:GetAttribute("ConsumableType")

	if consumableType == "BaconSoup" or consumableType == "Soup" then
		playerData:AddSoupEaten(player, 1)
	elseif type(consumableType) == "string" and consumableType ~= "" then
		-- Add custom consumable effects here later.
	end
end

handlers.Door = {
	ActionLabel = "Open",
	MaxDistance = 14,

	OnServerActivated = function(player: Player, instance: Instance, context)
		if not instance:IsA("Model") then
			return
		end

		local hinge = findHinge(instance)
		if not hinge then
			return
		end

		ensureOpenState(instance)

		if instance:GetAttribute("Locked") then
			local keyId = instance:GetAttribute("KeyId")
			local playerData = context and context.playerData

			if type(keyId) == "string" and keyId ~= "" and playerData and playerData:HasKey(player, keyId) then
				instance:SetAttribute("Locked", false)

				packets.playVisual.sendToAll({
					target = instance,
					visualType = "DoorUnlocked",
				})
			else
				sendLockedVisual(instance, "Door")
				return
			end
		end

		local root = util.getCharacterRoot(player)
		if not root then
			return
		end

		local isOpen = not (instance:GetAttribute("IsOpen") or false)

		if isOpen then
			local angle = instance:GetAttribute("TargetAngle") or 90
			local direction = getOpenDirection(root, instance, hinge, angle)
			instance:SetAttribute("OpenDirection", direction)
		end

		instance:SetAttribute("IsOpen", isOpen)

		packets.playVisual.sendToAll({
			target = instance,
			visualType = if isOpen then "DoorOpen" else "DoorClose",
		})
	end,
}

handlers.FilingCabinet = {
	ActionLabel = "Open",
	MaxDistance = 12,

	OnServerActivated = function(_player, instance)
		toggleOpenable(instance, "FilingCabinet")
	end,
}

handlers.DeskDrawer = {
	ActionLabel = "Open",
	MaxDistance = 12,

	OnServerActivated = function(_player, instance)
		toggleOpenable(instance, "DeskDrawer")
	end,
}

handlers.WallCabinet = {
	ActionLabel = "Open",
	MaxDistance = 12,

	OnServerActivated = function(_player, instance)
		toggleOpenable(instance, "WallCabinet")
	end,
}

handlers.Locker = {
	ActionLabel = "Open",
	MaxDistance = 12,

	OnServerActivated = function(_player, instance)
		toggleOpenable(instance, "Locker")
	end,
}

handlers.GentCabinet = {
	ActionLabel = "Open",
	MaxDistance = 12,

	OnServerActivated = function(_player, instance)
		toggleOpenable(instance, "GentCabinet")
	end,
}

handlers.Pickup = {
	ActionLabel = "Pick up",
	MaxDistance = 8,

	OnServerActivated = function(player: Player, instance: Instance, context)
		if instance:GetAttribute("Collected") then
			return
		end

		instance:SetAttribute("Collected", true)
		awardPickup(player, instance, context)

		packets.playVisual.sendToAll({
			target = instance,
			visualType = "PickupCollected",
		})

		packets.playVisual.sendTo({
			target = instance,
			visualType = "PickupUi",
		}, player)

		task.delay(0.1, function()
			if instance and instance.Parent then
				instance:Destroy()
			end
		end)
	end,
}

handlers.Consumable = {
	ActionLabel = "Eat",
	MaxDistance = 8,

	OnServerActivated = function(player: Player, instance: Instance, context)
		if instance:GetAttribute("Consumed") then
			return
		end

		instance:SetAttribute("Consumed", true)
		applyConsumable(player, instance, context)

		packets.playVisual.sendToAll({
			target = instance,
			visualType = "ConsumableConsumed",
		})

		packets.playVisual.sendTo({
			target = instance,
			visualType = "ConsumableUi",
		}, player)

		task.delay(0.1, function()
			if instance and instance.Parent then
				instance:Destroy()
			end
		end)
	end,
}

handlers.Slug = handlers.Pickup
handlers.GentPart = handlers.Pickup
handlers.Battery = handlers.Pickup
handlers.ToolKit = handlers.Pickup
handlers.GentCard = handlers.Pickup

handlers.Crackers = handlers.Consumable
handlers.BaconSoup = handlers.Consumable

return handlers
