local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utilities = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Utilities"))

local interactablesFolder = ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Interactables")
local util = require(interactablesFolder:WaitForChild("InteractableUtil"))

local handlers = {}

local function playSfx(model: Instance, name: string)
	util.playRandomSoundIn(model, name)
end

local function cleanupConnections(connections)
	for _, connection in ipairs(connections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end

	table.clear(connections)
end

local DOOR_TWEENS = {
	Open = { Duration = 0.8, Timing = "easeInOutQuad" },
	Close = { Duration = 0.3, Timing = "easeInSine" },
}

local CABINET_TWEENS = {
	Open = { Duration = 0.45, Timing = "easeOutSine" },
	Close = { Duration = 0.5, Timing = "easeInOutSine" },
}

local DRAWER_TWEENS = {
	Open = { Duration = 0.3, Timing = "easeOutSine" },
	Close = { Duration = 0.4, Timing = "easeInOutSine" },
}

local WALL_CABINET_TWEENS = {
	Open = { Duration = 0.5, Timing = "easeOutBounce" },
	Close = { Duration = 0.25, Timing = "easeInQuad" },
}

local LOCKER_TWEENS = {
	Open = { Duration = 0.4, Timing = "easeOutSine" },
	Close = { Duration = 0.175, Timing = "easeInSine" },
}

local GENT_CABINET_TWEENS = {
	Open = { Duration = 0.4, Timing = "easeOutBounce" },
	Close = { Duration = 0.175, Timing = "easeInSine" },
}

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

	return nil
end

local function makeSingleHingeOpenable(config)
	local states = {}

	return {
		ActionLabel = "Open",
		MaxDistance = config.MaxDistance or 12,

		GetActionLabel = function(instance)
			if instance:GetAttribute("IsOpen") then
				return instance:GetAttribute("CloseLabel") or "Close"
			end

			return instance:GetAttribute("ActionLabel") or "Open"
		end,

		OnSetup = function(instance)
			if not instance:IsA("Model") then
				return nil
			end

			local hinge = config.FindHinge(instance)
			if not hinge then
				warn(string.format("[%s] Missing Hinge in %s", config.Name, instance:GetFullName()))
				return nil
			end

			local state = {
				hinge = hinge,
				closedCFrame = hinge.CFrame,
				animId = 0,
			}

			states[instance] = state

			if instance:GetAttribute("StartOpen") or instance:GetAttribute("IsOpen") then
				local startAngle = instance:GetAttribute("StartAngle") or instance:GetAttribute("TargetAngle") or 90
				local flip = if config.UseFlip then (instance:GetAttribute("IsFlipped") and -1 or 1) else 1
				Utilities.MoveModel(hinge, state.closedCFrame * CFrame.Angles(0, math.rad(startAngle * flip), 0))
			end

			return function()
				state.animId += 1
				states[instance] = nil
			end
		end,

		OnVisual = function(instance, visualType)
			local state = states[instance]
			if not state then
				return
			end

			if visualType == config.VisualPrefix .. "Locked" then
				playSfx(instance, "SFX_Locked")
				return
			end

			local toOpen
			if visualType == config.VisualPrefix .. "Open" then
				toOpen = true
				playSfx(instance, "SFX_Open")
			elseif visualType == config.VisualPrefix .. "Close" then
				toOpen = false
				playSfx(instance, "SFX_Close")
			else
				return
			end

			state.animId += 1
			local myId = state.animId

			local angle = instance:GetAttribute("TargetAngle") or 90
			local flip = if config.UseFlip then (instance:GetAttribute("IsFlipped") and -1 or 1) else 1

			local startCFrame = state.hinge.CFrame
			local targetCFrame = if toOpen
				then state.closedCFrame * CFrame.Angles(0, math.rad(angle * flip), 0)
				else state.closedCFrame

			local tween = if toOpen then config.Tweens.Open else config.Tweens.Close

			task.spawn(function()
				Utilities.Tween(tween.Duration, tween.Timing, function(alpha)
					if state.animId ~= myId or not state.hinge.Parent then
						return false
					end

					Utilities.MoveModel(state.hinge, startCFrame:Lerp(targetCFrame, alpha))
				end)
			end)
		end,
	}
end

handlers.Door = (function()
	local states = {}

	return {
		ActionLabel = "Open",
		MaxDistance = 14,

		GetActionLabel = function(instance)
			if instance:GetAttribute("IsOpen") then
				return "Close"
			end

			return instance:GetAttribute("ActionLabel") or "Open"
		end,

		OnSetup = function(instance)
			if not instance:IsA("Model") then
				return nil
			end

			local hinge = findHinge(instance)
			if not hinge then
				warn("[Door] Missing Hinge in:", instance:GetFullName())
				return nil
			end

			local state = {
				hinge = hinge,
				restCFrame = hinge.CFrame,
				animId = 0,
			}

			states[instance] = state

			if instance:GetAttribute("StartOpen") or instance:GetAttribute("IsOpen") then
				local angle = instance:GetAttribute("TargetAngle") or 90
				local direction = instance:GetAttribute("OpenDirection") or 1
				Utilities.MoveModel(hinge, state.restCFrame * CFrame.Angles(0, math.rad(angle * direction), 0))
			end

			return function()
				state.animId += 1
				states[instance] = nil
			end
		end,

		OnVisual = function(instance, visualType)
			local state = states[instance]
			if not state then
				return
			end

			if visualType == "DoorLocked" then
				playSfx(instance, "SFX_Locked")
				return
			end

			if visualType == "DoorUnlocked" then
				playSfx(instance, "SFX_Unlock")
				return
			end

			local toOpen
			if visualType == "DoorOpen" then
				toOpen = true
				playSfx(instance, "SFX_Open")
			elseif visualType == "DoorClose" then
				toOpen = false
				playSfx(instance, "SFX_Close")
			else
				return
			end

			local angle = instance:GetAttribute("TargetAngle") or 90
			local direction = instance:GetAttribute("OpenDirection") or 1

			local startCFrame = state.hinge.CFrame
			local targetCFrame = if toOpen
				then state.restCFrame * CFrame.Angles(0, math.rad(angle * direction), 0)
				else state.restCFrame

			local tween = if toOpen then DOOR_TWEENS.Open else DOOR_TWEENS.Close

			state.animId += 1
			local myId = state.animId

			task.spawn(function()
				Utilities.Tween(tween.Duration, tween.Timing, function(alpha)
					if state.animId ~= myId or not state.hinge.Parent then
						return false
					end

					Utilities.MoveModel(state.hinge, startCFrame:Lerp(targetCFrame, alpha))
				end)
			end)
		end,
	}
end)()

handlers.FilingCabinet = (function()
	local states = {}

	return {
		ActionLabel = "Open",
		MaxDistance = 12,

		GetActionLabel = function(instance)
			return if instance:GetAttribute("IsOpen") then "Close" else (instance:GetAttribute("ActionLabel") or "Open")
		end,

		OnSetup = function(instance)
			if not instance:IsA("Model") then
				return nil
			end

			local drawersFolder = instance:FindFirstChild("Drawers")
			if not drawersFolder then
				warn("[FilingCabinet] Missing Drawers:", instance:GetFullName())
				return nil
			end

			local drawers = {}

			for _, drawer in ipairs(drawersFolder:GetChildren()) do
				if drawer:IsA("Folder") or drawer:IsA("Model") then
					local object = drawer:FindFirstChild("Object", true)
					local goal = drawer:FindFirstChild("Goal", true)

					if object and object:IsA("BasePart") and goal and goal:IsA("BasePart") then
						table.insert(drawers, {
							object = object,
							closedCFrame = object.CFrame,
							openCFrame = goal.CFrame,
						})
					end
				end
			end

			states[instance] = drawers

			if instance:GetAttribute("StartOpen") or instance:GetAttribute("IsOpen") then
				for _, drawer in ipairs(drawers) do
					drawer.object.CFrame = drawer.openCFrame
				end
			end

			return function()
				states[instance] = nil
			end
		end,

		OnVisual = function(instance, visualType)
			local drawers = states[instance]
			if not drawers then
				return
			end

			if visualType == "FilingCabinetLocked" then
				playSfx(instance, "SFX_Locked")
				return
			end

			local toOpen
			if visualType == "FilingCabinetOpen" then
				toOpen = true
				playSfx(instance, "SFX_Open")
			elseif visualType == "FilingCabinetClose" then
				toOpen = false
				playSfx(instance, "SFX_Close")
			else
				return
			end

			local tween = if toOpen then CABINET_TWEENS.Open else CABINET_TWEENS.Close

			for _, drawer in ipairs(drawers) do
				local targetCFrame = if toOpen then drawer.openCFrame else drawer.closedCFrame
				Utilities.spTween(drawer.object, "CFrame", targetCFrame, tween.Duration, tween.Timing)
			end
		end,
	}
end)()
handlers.DeskDrawer = (function()
	local states = {}

	local function findDrawerEntries(instance: Instance)
		local drawers = {}

		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("Model") and descendant.Name == "DeskDrawer" then
				local object = descendant:FindFirstChild("Object", true)
				local goal = descendant:FindFirstChild("Goal", true)

				if object and object:IsA("BasePart") and goal and goal:IsA("BasePart") then
					table.insert(drawers, {
						object = object,
						closedCFrame = object.CFrame,
						openCFrame = goal.CFrame,
					})
				end
			end
		end

		-- fallback for old single-drawer setup
		if #drawers == 0 then
			local object = instance:FindFirstChild("Object", true)
			local goal = instance:FindFirstChild("Goal", true)

			if object and object:IsA("BasePart") and goal and goal:IsA("BasePart") then
				table.insert(drawers, {
					object = object,
					closedCFrame = object.CFrame,
					openCFrame = goal.CFrame,
				})
			end
		end

		return drawers
	end

	return {
		ActionLabel = "Open",
		MaxDistance = 12,

		GetActionLabel = function(instance)
			return if instance:GetAttribute("IsOpen") then "Close" else (instance:GetAttribute("ActionLabel") or "Open")
		end,

		OnSetup = function(instance)
			if not instance:IsA("Model") then
				return nil
			end

			local drawers = findDrawerEntries(instance)

			if #drawers == 0 then
				warn("[DeskDrawer] Missing DeskDrawer/Object/Goal setup:", instance:GetFullName())
				return nil
			end

			states[instance] = drawers

			if instance:GetAttribute("StartOpen") or instance:GetAttribute("IsOpen") then
				for _, drawer in ipairs(drawers) do
					drawer.object.CFrame = drawer.openCFrame
				end
			end

			return function()
				states[instance] = nil
			end
		end,

		OnVisual = function(instance, visualType)
			local drawers = states[instance]
			if not drawers then
				return
			end

			if visualType == "DeskDrawerLocked" then
				playSfx(instance, "SFX_Locked")
				return
			end

			local toOpen
			if visualType == "DeskDrawerOpen" then
				toOpen = true
				playSfx(instance, "SFX_Open")
			elseif visualType == "DeskDrawerClose" then
				toOpen = false
				playSfx(instance, "SFX_Close")
			else
				return
			end

			local tween = if toOpen then DRAWER_TWEENS.Open else DRAWER_TWEENS.Close

			for _, drawer in ipairs(drawers) do
				local targetCFrame = if toOpen then drawer.openCFrame else drawer.closedCFrame
				Utilities.spTween(drawer.object, "CFrame", targetCFrame, tween.Duration, tween.Timing)
			end
		end,
	}
end)()

handlers.WallCabinet = (function()
	local states = {}

	return {
		ActionLabel = "Open",
		MaxDistance = 12,

		GetActionLabel = function(instance)
			return if instance:GetAttribute("IsOpen") then "Close" else (instance:GetAttribute("ActionLabel") or "Open")
		end,

		OnSetup = function(instance)
			if not instance:IsA("Model") then
				return nil
			end

			local leftDoor = instance:FindFirstChild("Door_Cabinet_Left", true)
			local rightDoor = instance:FindFirstChild("Door_Cabinet_Right", true)
			local leftHinge = leftDoor and leftDoor:FindFirstChild("Hinge", true)
			local rightHinge = rightDoor and rightDoor:FindFirstChild("Hinge", true)

			if not (leftHinge and leftHinge:IsA("BasePart") and rightHinge and rightHinge:IsA("BasePart")) then
				warn("[WallCabinet] Missing hinges:", instance:GetFullName())
				return nil
			end

			local state = {
				leftHinge = leftHinge,
				rightHinge = rightHinge,
				leftClosed = leftHinge.CFrame,
				rightClosed = rightHinge.CFrame,
				animId = 0,
			}

			states[instance] = state

			if instance:GetAttribute("StartOpen") or instance:GetAttribute("IsOpen") then
				local startAngle = instance:GetAttribute("StartAngle") or instance:GetAttribute("TargetAngle") or 90
				Utilities.MoveModel(leftHinge, state.leftClosed * CFrame.Angles(0, math.rad(-startAngle), 0))
				Utilities.MoveModel(rightHinge, state.rightClosed * CFrame.Angles(0, math.rad(startAngle), 0))
			end

			return function()
				state.animId += 1
				states[instance] = nil
			end
		end,

		OnVisual = function(instance, visualType)
			local state = states[instance]
			if not state then
				return
			end

			if visualType == "WallCabinetLocked" then
				playSfx(instance, "SFX_Locked")
				return
			end

			local toOpen
			if visualType == "WallCabinetOpen" then
				toOpen = true
				playSfx(instance, "SFX_Open")
			elseif visualType == "WallCabinetClose" then
				toOpen = false
				playSfx(instance, "SFX_Close")
			else
				return
			end

			local angle = instance:GetAttribute("TargetAngle") or 90
			local tween = if toOpen then WALL_CABINET_TWEENS.Open else WALL_CABINET_TWEENS.Close

			local leftStart = state.leftHinge.CFrame
			local rightStart = state.rightHinge.CFrame

			local leftTarget = if toOpen
				then state.leftClosed * CFrame.Angles(0, math.rad(-angle), 0)
				else state.leftClosed
			local rightTarget = if toOpen
				then state.rightClosed * CFrame.Angles(0, math.rad(angle), 0)
				else state.rightClosed

			state.animId += 1
			local myId = state.animId

			task.spawn(function()
				Utilities.Tween(tween.Duration, tween.Timing, function(alpha)
					if state.animId ~= myId then
						return false
					end

					if not state.leftHinge.Parent or not state.rightHinge.Parent then
						return false
					end

					Utilities.MoveModel(state.leftHinge, leftStart:Lerp(leftTarget, alpha))
					Utilities.MoveModel(state.rightHinge, rightStart:Lerp(rightTarget, alpha))
				end)
			end)
		end,
	}
end)()

handlers.Locker = makeSingleHingeOpenable({
	Name = "Locker",
	VisualPrefix = "Locker",
	MaxDistance = 12,
	Tweens = LOCKER_TWEENS,
	UseFlip = true,

	FindHinge = function(instance)
		local openable = instance:FindFirstChild("Openable", true)
		local hinge = (openable and openable:FindFirstChild("Hinge", true)) or instance:FindFirstChild("Hinge", true)
		return if hinge and hinge:IsA("BasePart") then hinge else nil
	end,
})

handlers.GentCabinet = makeSingleHingeOpenable({
	Name = "GentCabinet",
	VisualPrefix = "GentCabinet",
	MaxDistance = 12,
	Tweens = GENT_CABINET_TWEENS,
	UseFlip = false,

	FindHinge = function(instance)
		local openable = instance:FindFirstChild("Openable", true)
		local hinge = (openable and openable:FindFirstChild("Hinge", true)) or instance:FindFirstChild("Hinge", true)
		return if hinge and hinge:IsA("BasePart") then hinge else nil
	end,
})

local function showPickupUi(instance, context)
	if not context or not context.collectionHandler or not context.playerGui then
		return
	end

	local displayName = instance:GetAttribute("DisplayName") or instance:GetAttribute("PickupType") or "Item"
	local amount = instance:GetAttribute("Amount") or instance:GetAttribute("PickupAmount") or 1
	local icon = instance:GetAttribute("Icon") or ""

	context.collectionHandler:createNewCollection(displayName, true, true, amount, icon, context.playerGui, false)
end

local function showConsumableUi(instance, context)
	if not context or not context.collectionHandler or not context.playerGui then
		return
	end

	local displayName = instance:GetAttribute("DisplayName") or instance:GetAttribute("ConsumableType") or "Food"
	local icon = instance:GetAttribute("Icon") or ""

	context.collectionHandler:createNewCollection(displayName, false, false, 0, icon, context.playerGui, true)
end

handlers.Pickup = {
	ActionLabel = "Pick up",
	MaxDistance = 8,

	GetActionLabel = function(instance)
		return instance:GetAttribute("ActionLabel") or "Pick up"
	end,

	OnSetup = function(_instance)
		return nil
	end,

	OnVisual = function(instance, visualType, context)
		if visualType == "PickupCollected" then
			util.playDetachedSoundFrom(instance)
			util.setInstanceVisible(instance, false)
		elseif visualType == "PickupUi" then
			showPickupUi(instance, context)
		end
	end,
}

handlers.Consumable = {
	ActionLabel = "Eat",
	MaxDistance = 8,

	GetActionLabel = function(instance)
		return instance:GetAttribute("ActionLabel") or "Eat"
	end,

	OnSetup = function(_instance)
		return nil
	end,

	OnVisual = function(instance, visualType, context)
		if visualType == "ConsumableConsumed" then
			util.playDetachedSoundFrom(instance)
			util.setInstanceVisible(instance, false)
		elseif visualType == "ConsumableUi" then
			showConsumableUi(instance, context)
		end
	end,
}

-- Pickup aliases
handlers.Slug = handlers.Pickup
handlers.GentPart = handlers.Pickup
handlers.Battery = handlers.Pickup
handlers.ToolKit = handlers.Pickup
handlers.GentCard = handlers.Pickup

-- Consumable aliases
handlers.Crackers = handlers.Consumable
handlers.BaconSoup = handlers.Consumable

return handlers
