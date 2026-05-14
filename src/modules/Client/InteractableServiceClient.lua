local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Maid = require("Maid")

local interactablesFolder = ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Interactables")
local InteractableConfig = require(interactablesFolder:WaitForChild("InteractableConfig"))
local InteractableHandlers = require(interactablesFolder:WaitForChild("InteractableClientHandlers"))
local InteractablePackets = require(interactablesFolder:WaitForChild("InteractablePackets"))
local InteractableUtil = require(interactablesFolder:WaitForChild("InteractableUtil"))

local interactableServiceClient = {}
interactableServiceClient.ServiceName = "InteractableServiceClient"

function interactableServiceClient:Init(serviceBag)
	self.serviceBag = assert(serviceBag, "No serviceBag")
	self.maid = Maid.new()

	self.player = Players.LocalPlayer
	self.playerGui = nil

	self.currentTarget = nil
	self.highlight = nil
	self.lastActivateClock = 0

	self.setupCleanups = {}
	self.raycastParams = nil

	self.selectionKeyUi = nil
	self.collectionHandler = nil
	self.hoverSound = nil
end

function interactableServiceClient:Start()
	self.playerGui = self.player:WaitForChild("PlayerGui")

	self:_trySetupUi()
	self:_setupHoverSound()
	self:_bindInteractables()
	self:_bindInput()
	self:_bindHoverLoop()
	self:_bindPackets()
end

function interactableServiceClient:_buildContext()
	return {
		playerGui = self.playerGui,
		collectionHandler = self.collectionHandler,
		serviceBag = self.serviceBag,
	}
end

function interactableServiceClient:_trySetupUi()
	local okSelection, selectionKeyUi = pcall(function()
		return require(script.Parent.GameUi.SelectionKey)
	end)

	if okSelection and selectionKeyUi then
		self.selectionKeyUi = selectionKeyUi

		if self.selectionKeyUi.setupSelectionKey then
			self.selectionKeyUi:setupSelectionKey(self.playerGui, "E", "")
		end
	end

	local okCollection, collectionHandler = pcall(function()
		return require(script.Parent.GameUi.CollectionHandler)
	end)

	if okCollection and collectionHandler then
		self.collectionHandler = collectionHandler

		if self.collectionHandler.setupCollections then
			self.collectionHandler:setupCollections(self.playerGui)
		end
	end
end

function interactableServiceClient:_setupHoverSound()
	if not InteractableConfig.HoverSoundId then
		return
	end

	local hoverSound = Instance.new("Sound")
	hoverSound.SoundId = InteractableConfig.HoverSoundId
	hoverSound.Volume = InteractableConfig.HoverSoundVolume or 1
	hoverSound.Parent = SoundService

	self.hoverSound = hoverSound
	self.maid:GiveTask(hoverSound)
end

function interactableServiceClient:_bindInteractables()
	local tag = InteractableConfig.Tag

	local function bindIfHandler(instance: Instance)
		if self.setupCleanups[instance] then
			return
		end

		local id = instance:GetAttribute(InteractableConfig.AttributeId)
		if type(id) ~= "string" then
			warn(
				string.format(
					"[Interactable] Tagged instance %s has no InteractableId attribute",
					instance:GetFullName()
				)
			)
			return
		end

		local handler = InteractableHandlers[id]
		if not handler then
			warn(string.format("[Interactable] %s has unknown InteractableId %q", instance:GetFullName(), id))
			return
		end

		if handler.OnSetup then
			local cleanup = handler.OnSetup(instance)
			self.setupCleanups[instance] = cleanup or true
		else
			self.setupCleanups[instance] = true
		end
	end

	local function unbind(instance: Instance)
		local cleanup = self.setupCleanups[instance]
		if type(cleanup) == "function" then
			cleanup()
		end

		self.setupCleanups[instance] = nil

		if self.currentTarget == instance then
			self:_setTarget(nil)
		end
	end

	self.maid:GiveTask(CollectionService:GetInstanceAddedSignal(tag):Connect(bindIfHandler))
	self.maid:GiveTask(CollectionService:GetInstanceRemovedSignal(tag):Connect(unbind))

	task.delay(1, function()
		if not self.maid then
			return
		end

		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			bindIfHandler(instance)
		end
	end)
end

function interactableServiceClient:_bindInput()
	ContextActionService:BindAction("InteractableActivate", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			self:_tryActivate()
		end

		return Enum.ContextActionResult.Sink
	end, true, InteractableConfig.ActivationKey, InteractableConfig.GamepadActivationKey)

	self.maid:GiveTask(function()
		ContextActionService:UnbindAction("InteractableActivate")
	end)
end

function interactableServiceClient:_bindHoverLoop()
	local interval = 1 / math.max(InteractableConfig.UpdateRate or 20, 1)
	local accumulator = 0

	self.maid:GiveTask(RunService.RenderStepped:Connect(function(dt)
		accumulator += dt

		if accumulator < interval then
			return
		end

		accumulator = 0

		if os.clock() - self.lastActivateClock < (InteractableConfig.ActivationCooldown or 0) then
			self:_setTarget(nil)
			return
		end

		self:_updateHoverTarget()
	end))
end

function interactableServiceClient:_bindPackets()
	InteractablePackets.playVisual.listen(function(data)
		if typeof(data) ~= "table" then
			return
		end

		local target = data.target
		local visualType = data.visualType

		if typeof(target) ~= "Instance" or type(visualType) ~= "string" then
			return
		end

		local id = target:GetAttribute(InteractableConfig.AttributeId)
		local handler = type(id) == "string" and InteractableHandlers[id] or nil

		if handler and handler.OnVisual then
			handler.OnVisual(target, visualType, self:_buildContext())
		end
	end)
end

function interactableServiceClient:_updateHoverTarget()
	local camera = Workspace.CurrentCamera
	if not camera then
		self:_setTarget(nil)
		return
	end

	local character = self.player.Character

	local params = self.raycastParams
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		self.raycastParams = params
	end

	local excludeList = {}

	if character then
		table.insert(excludeList, character)
	end

	for _, instance in ipairs(CollectionService:GetTagged(InteractableConfig.Tag)) do
		if instance:GetAttribute("RaycastBlocked") then
			table.insert(excludeList, instance)
		end
	end

	params.FilterDescendantsInstances = excludeList

	local result = Workspace:Raycast(
		camera.CFrame.Position,
		camera.CFrame.LookVector * (InteractableConfig.RaycastDistance or 100),
		params
	)

	local target = nil

	if result and result.Instance then
		local node: Instance? = result.Instance

		while node and node ~= workspace do
			if CollectionService:HasTag(node, InteractableConfig.Tag) then
				local id = node:GetAttribute(InteractableConfig.AttributeId)
				local handler = type(id) == "string" and InteractableHandlers[id] or nil

				if handler then
					local maxDistance = node:GetAttribute("MaxDistance")
						or handler.MaxDistance
						or InteractableConfig.MaxDistance

					-- Old-code style: uses raycast hit distance.
					if result.Distance <= maxDistance then
						target = node
					end
				end

				break
			end

			node = node.Parent
		end
	end

	self:_setTarget(target)
end

function interactableServiceClient:_setTarget(target: Instance?)
	if target == self.currentTarget then
		return
	end

	self.currentTarget = target

	if self.highlight then
		self.highlight:Destroy()
		self.highlight = nil
	end

	if target then
		if self.hoverSound then
			self.hoverSound:Play()
		end

		local highlight = Instance.new("Highlight")
		highlight.Name = "InteractableHighlight"
		highlight.Adornee = target

		for property, value in pairs(InteractableConfig.HighlightProps) do
			highlight[property] = value
		end

		highlight.Parent = target
		self.highlight = highlight

		local id = target:GetAttribute(InteractableConfig.AttributeId)
		local handler = type(id) == "string" and InteractableHandlers[id] or nil

		local label = "Interact"
		if handler then
			if handler.GetActionLabel then
				label = handler.GetActionLabel(target)
			else
				label = handler.ActionLabel or label
			end
		end

		self:_showPrompt(label)
	else
		self:_hidePrompt()
	end
end

function interactableServiceClient:_tryActivate()
	local target = self.currentTarget

	if not target or not target.Parent then
		return
	end

	if os.clock() - self.lastActivateClock < (InteractableConfig.ActivationCooldown or 0) then
		return
	end

	self.lastActivateClock = os.clock()

	InteractablePackets.requestInteract.send({
		target = target,
	})

	self:_setTarget(nil)
end

function interactableServiceClient:_showPrompt(label: string)
	if self.selectionKeyUi and self.selectionKeyUi.changeCurrentSelection then
		self.selectionKeyUi:changeCurrentSelection(self.playerGui, "E", label)
	end
end

function interactableServiceClient:_hidePrompt()
	if self.selectionKeyUi and self.selectionKeyUi.hideSelect then
		self.selectionKeyUi:hideSelect(self.playerGui)
	end
end

function interactableServiceClient:Destroy()
	if self.highlight then
		self.highlight:Destroy()
		self.highlight = nil
	end

	for instance, cleanup in pairs(self.setupCleanups) do
		if type(cleanup) == "function" then
			cleanup()
		end

		self.setupCleanups[instance] = nil
	end

	self.maid:DoCleaning()
end

return interactableServiceClient
