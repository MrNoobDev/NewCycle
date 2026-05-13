--[=[
	Client-side NPC manager. Detects tagged NPC models via CollectionService,
	creates the appropriate class, and manages lifecycle.

	Supported tags: "NPC_LostOne", "NPC_Bendy"
	Attributes on model:
	  - WaypointFolder (string): name of a Folder under workspace.NPCWaypoints
	  - WalkSpeed, RunSpeed, etc.: per-instance overrides

	@class NPCServiceClient
	@author mrnoob
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")

local AnimationData = require("AnimationData")
local Maid = require("Maid")
local NPCConfig = require("NPCConfig")

local BendyNPC = require(script.Parent.NPC.BendyNPC)
local LostOneNPC = require(script.Parent.NPC.LostOneNPC)

--\ Tag Registry \--
local TAG_MAP = {
	NPC_LostOne = "LostOne",
	NPC_Bendy = "Bendy",
}

--\ Module \--
local NPCServiceClient = {}
NPCServiceClient.ServiceName = "NPCServiceClient"

function NPCServiceClient:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._npcs = {}
end

function NPCServiceClient:Start()
	for tag, npcType in TAG_MAP do
		self._maid:GiveTask(CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			self:_onTagged(instance, npcType)
		end))
		self._maid:GiveTask(CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
			self:_onUntagged(instance)
		end))
		for _, instance in CollectionService:GetTagged(tag) do
			task.defer(self._onTagged, self, instance, npcType)
		end
	end
end

--\ Public \--

function NPCServiceClient:GetNPC(instance: Model): any?
	return self._npcs[instance]
end

function NPCServiceClient:SpawnNPC(npcType: string, template: Model, parent: Instance, position: CFrame): Model?
	local clone = template:Clone()
	clone:PivotTo(position)
	clone.Parent = parent

	local tag = nil
	for t, nt in TAG_MAP do
		if nt == npcType then
			tag = t
			break
		end
	end
	if tag then
		CollectionService:AddTag(clone, tag)
	end

	return clone
end

function NPCServiceClient:DespawnNPC(instance: Model)
	self:_onUntagged(instance)
	if instance.Parent then
		instance:Destroy()
	end
end

--\ Private \--

function NPCServiceClient:_onTagged(instance: Instance, npcType: string)
	if not instance:IsA("Model") then
		return
	end
	if self._npcs[instance] then
		return
	end

	local npc = nil

	if npcType == "LostOne" then
		npc = self:_createLostOne(instance)
	elseif npcType == "Bendy" then
		npc = self:_createBendy(instance)
	end

	if not npc then
		return
	end

	self._npcs[instance] = npc

	self:_applyWaypoints(npc, instance)

	npc:Init()
end

function NPCServiceClient:_onUntagged(instance: Instance)
	local npc = self._npcs[instance]
	if not npc then
		return
	end
	self._npcs[instance] = nil
	npc:Destroy()
end

--\ Creators \--

function NPCServiceClient:_createLostOne(instance: Model)
	local lostOneDefaults = NPCConfig.LostOne or {}
	local enemyDefaults = NPCConfig.Enemy or {}
	local baseDefaults = {
		WalkSpeed = NPCConfig.WalkSpeed,
		RunSpeed = NPCConfig.RunSpeed,
		PathRecomputeInterval = NPCConfig.PathRecomputeInterval,
		WaypointReachedThreshold = NPCConfig.WaypointReachedThreshold,
		WanderRadius = NPCConfig.WanderRadius,
		WanderIdleMin = NPCConfig.WanderIdleMin,
		WanderIdleMax = NPCConfig.WanderIdleMax,
		DeathDespawnTime = NPCConfig.DeathDespawnTime,
	}

	local config = {}
	for k, v in baseDefaults do
		config[k] = v
	end
	for k, v in enemyDefaults do
		config[k] = v
	end
	for k, v in lostOneDefaults do
		config[k] = v
	end
	self:_applyAttributeOverrides(config, instance)

	local npc = LostOneNPC.new(instance, config)
	if not npc then
		return nil
	end

	local animData = AnimationData.Enemies and AnimationData.Enemies.LostOne
	if animData then
		npc:SetupAnimator(animData)
	end

	return npc
end

function NPCServiceClient:_createBendy(instance: Model)
	local bendyDefaults = NPCConfig.Bendy or {}
	local peacefulDefaults = NPCConfig.Peaceful or {}
	local baseDefaults = {
		WalkSpeed = NPCConfig.WalkSpeed,
		RunSpeed = NPCConfig.RunSpeed,
		PathRecomputeInterval = NPCConfig.PathRecomputeInterval,
		WaypointReachedThreshold = NPCConfig.WaypointReachedThreshold,
		WanderRadius = NPCConfig.WanderRadius,
		WanderIdleMin = NPCConfig.WanderIdleMin,
		WanderIdleMax = NPCConfig.WanderIdleMax,
		DeathDespawnTime = NPCConfig.DeathDespawnTime,
	}

	local config = {}
	for k, v in baseDefaults do
		config[k] = v
	end
	for k, v in peacefulDefaults do
		config[k] = v
	end
	for k, v in bendyDefaults do
		config[k] = v
	end
	self:_applyAttributeOverrides(config, instance)

	local animData = AnimationData.Peaceful and AnimationData.Peaceful.Bendy
	local npc = BendyNPC.new(instance, config, animData)

	return npc
end

--\ Helpers \--

function NPCServiceClient:_applyAttributeOverrides(config: { [string]: any }, instance: Model)
	for key, _ in config do
		local attr = instance:GetAttribute(key)
		if attr ~= nil then
			config[key] = attr
		end
	end
end

function NPCServiceClient:_applyWaypoints(npc, instance: Model)
	local folderName = instance:GetAttribute("WaypointFolder")
	if not folderName then
		return
	end

	local root = workspace:FindFirstChild("NPCWaypoints")
	if not root then
		return
	end

	local folder = root:FindFirstChild(folderName)
	if not folder then
		return
	end

	npc:SetWaypointsFromFolder(folder)
end

--\ Cleanup \--

function NPCServiceClient:Destroy()
	for _, npc in self._npcs do
		npc:Destroy()
	end
	table.clear(self._npcs)
	self._maid:DoCleaning()
end

return NPCServiceClient
