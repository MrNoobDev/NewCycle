--[=[
	Server-side NPC helper. Grants network ownership of tagged NPC models
	to the local player so client-side movement works.

	@class NPCService
	@author mrnoob
]=]

local require = require(script.Parent.loader).load(script)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Maid = require("Maid")

--\ Tag map: Player-facing NPC tag → CombatService hit-anim tag \--
local NPC_TAGS = {
	NPC_LostOne = "LostOne",
	NPC_Bendy = nil,
}

local NPCService = {}
NPCService.ServiceName = "NPCService"

function NPCService:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
end

function NPCService:Start()
	for tag, combatTag in NPC_TAGS do
		self._maid:GiveTask(CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			self:_setupNPC(instance, combatTag)
		end))
		for _, instance in CollectionService:GetTagged(tag) do
			task.defer(self._setupNPC, self, instance, combatTag)
		end
	end
end

function NPCService:_setupNPC(instance: Instance, combatTag: string?)
	if not instance:IsA("Model") then
		return
	end

	if combatTag and not CollectionService:HasTag(instance, combatTag) then
		CollectionService:AddTag(instance, combatTag)
	end

	self:_ensureHumanoidsParent(instance)
	self:_ensurePrimaryPart(instance)
	self:_ensureHitPart(instance)
	self:_claimOwnership(instance)
end

function NPCService:_ensureHumanoidsParent(instance: Model)
	local folder = workspace:FindFirstChild("Humanoids")
	if not folder or not folder:IsA("Folder") then
		folder = Instance.new("Folder")
		folder.Name = "Humanoids"
		folder.Parent = workspace
	end
	if not instance:IsDescendantOf(folder) then
		instance.Parent = folder
	end
end

function NPCService:_ensurePrimaryPart(instance: Model)
	if instance.PrimaryPart and instance.PrimaryPart.Parent == instance then
		return
	end
	local hrp = instance:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		instance.PrimaryPart = hrp
	end
end

function NPCService:_ensureHitPart(instance: Model)
	local hrp = instance:WaitForChild("HumanoidRootPart", 10)
	if not hrp then
		return
	end

	if instance:FindFirstChild("NPCHitPart") then
		return
	end

	local sizeAttr = instance:GetAttribute("HitPartSize")
	local size
	if typeof(sizeAttr) == "Vector3" then
		size = sizeAttr
	else
		size = Vector3.new(3.5, 5.5, 3.5)
	end

	local hitPart = Instance.new("Part")
	hitPart.Name = "NPCHitPart"
	hitPart.Size = size
	hitPart.Transparency = 1
	hitPart.CanCollide = false
	hitPart.CanTouch = false
	hitPart.CanQuery = true
	hitPart.Massless = true
	hitPart.TopSurface = Enum.SurfaceType.Smooth
	hitPart.BottomSurface = Enum.SurfaceType.Smooth
	hitPart.CFrame = hrp.CFrame

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = hitPart
	weld.Parent = hitPart

	hitPart.Parent = instance
end

function NPCService:_claimOwnership(instance: Model)
	local function setOwner(player: Player?)
		for _, desc in instance:GetDescendants() do
			if desc:IsA("BasePart") then
				pcall(function()
					desc:SetNetworkOwner(player)
				end)
			end
		end
	end

	local player = Players:GetPlayers()[1]
	if player then
		setOwner(player)
	else
		local conn
		conn = Players.PlayerAdded:Connect(function(p)
			conn:Disconnect()
			setOwner(p)
		end)
		self._maid:GiveTask(conn)
	end
end

function NPCService:Destroy()
	self._maid:DoCleaning()
end

return NPCService
