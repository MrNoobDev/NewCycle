local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")

local interactablesFolder = ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Interactables")
local InteractableConfig = require(interactablesFolder:WaitForChild("InteractableConfig"))
local InteractableHandlers = require(interactablesFolder:WaitForChild("InteractableServerHandlers"))
local InteractablePackets = require(interactablesFolder:WaitForChild("InteractablePackets"))
local InteractableUtil = require(interactablesFolder:WaitForChild("InteractableUtil"))

local interactableService = {}
interactableService.ServiceName = "InteractableService"

function interactableService:Init(serviceBag)
	self.serviceBag = assert(serviceBag, "No serviceBag")
	self.maid = Maid.new()

	self.playerData = self.serviceBag:GetService(require("PlayerDataService"))
	self.lastActivate = {}
end

function interactableService:Start()
	InteractablePackets.requestInteract.listen(function(data, player)
		self:_onActivate(player, data.target)
	end)

	self.maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self.lastActivate[player] = nil
	end))
end

function interactableService:_onActivate(player: Player, target: Instance?)
	if not target or not target.Parent then
		return
	end

	if not CollectionService:HasTag(target, InteractableConfig.Tag) then
		return
	end

	local id = target:GetAttribute(InteractableConfig.AttributeId)
	if type(id) ~= "string" then
		return
	end

	local handler = InteractableHandlers[id]
	if not handler then
		return
	end

	local now = os.clock()
	local last = self.lastActivate[player] or 0
	local cooldown = InteractableConfig.ActivationCooldown or 0

	if now - last < cooldown then
		return
	end

	local root = InteractableUtil.getCharacterRoot(player)
	if not root then
		return
	end

	local targetPos = InteractableUtil.getClosestPointToInstance(target, root.Position)
		or InteractableUtil.resolvePosition(target)

	if not targetPos then
		return
	end

	local maxDistance = target:GetAttribute("MaxDistance") or handler.MaxDistance or InteractableConfig.MaxDistance

	local forgiveness = InteractableConfig.ServerDistanceForgiveness or 3

	if (targetPos - root.Position).Magnitude > maxDistance + forgiveness then
		return
	end

	self.lastActivate[player] = now

	local context = self:_buildContext(player)

	if handler.OnServerActivated then
		handler.OnServerActivated(player, target, context)
	end
end

function interactableService:_buildContext(player: Player)
	return {
		player = player,
		serviceBag = self.serviceBag,
		playerData = self.playerData,
	}
end

function interactableService:Destroy()
	self.maid:DoCleaning()
end

return interactableService
