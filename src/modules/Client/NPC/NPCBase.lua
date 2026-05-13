--[=[
	Base NPC class. Handles pathfinding, movement, wandering, and waypoints.


	@class NPCBase
	@author mrnoob
]=]

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClientLibraries = ReplicatedStorage:WaitForChild("ClientLibraries")
local Janitor = require(ClientLibraries:WaitForChild("Janitor"))
local NPCAnimator = require(script.Parent.NPCAnimator)
local NPCAudio = require(script.Parent.NPCAudio)

--\ Constants \--
local noY = Vector3.new(1, 0, 1)

--\ Settings \--
local PATH_RECOMPUTE_MIN_INTERVAL = 0.35 -- seconds between full recomputes
local DIRECT_RAY_EXTRA = 3 -- studs ahead of goal for clearance cast
local ARRIVE_THRESHOLD_SQ_DEFAULT = 9 -- (3 studs)^2

--\ Waypoint Behaviours \--
-- Map from waypoint Id string → function(npc, waypointPart)
-- Add entries here to give waypoints scripted behaviour.
-- The system calls the function when the NPC arrives, then resumes patrol.
local WaypointBehaviours = {
	-- Example animated waypoint: just prints a message.
	-- Replace or extend with real logic (play anim, trigger cutscene, etc.)
	default_message = function(npc, waypointPart)
		local msg = waypointPart:GetAttribute("Message") or "..."
		print(string.format("[NPC:%s] Waypoint says: %s", npc._instance.Name, msg))
	end,
}

--\ Module \--
local NPCBase = {}
NPCBase.__index = NPCBase

--\ Lifecycle \--

function NPCBase.new(instance, config)
	local self = setmetatable({}, NPCBase)
	self._instance = instance
	self._config = config or {}
	self._destroyed = false
	self._connections = {}
	self._state = "Idle"

	-- Waypoints
	self._waypointIndex = 1
	self._waypoints = {} -- { position: Vector3, part: BasePart? }
	self._wanderOrigin = nil
	self._wanderTarget = nil
	self._wanderIdleUntil = nil
	self._patrolIdleUntil = nil

	-- Pathfinding
	self._lastPathRecompute = 0
	self._currentPathPts = nil
	self._currentDest = nil

	-- Janitor owns everything
	self._janitor = Janitor.new()
	self._moveJanitor = Janitor.new()
	self._janitor:GiveChore(self._moveJanitor)

	self._humanoid = instance:WaitForChild("Humanoid", 10)
	self._hrp = instance:WaitForChild("HumanoidRootPart", 10)

	if not self._humanoid or not self._hrp then
		warn("[NPCBase] Model missing Humanoid or HumanoidRootPart:", instance:GetFullName())
		return nil
	end

	self._humanoid.WalkSpeed = self._config.WalkSpeed or 8
	self._humanoid.BreakJointsOnDeath = false
	self._humanoid.RequiresNeck = false

	self._path = PathfindingService:CreatePath({
		AgentRadius = self._config.AgentRadius or 3,
		AgentHeight = self._config.AgentHeight or 5,
		AgentCanJump = self._config.AgentCanJump ~= false,
		AgentCanClimb = false,
		Costs = { Water = 100 },
	})

	self._rayParams = RaycastParams.new()
	self._rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self._rayParams.FilterDescendantsInstances = { instance }
	self._rayParams.IgnoreWater = true

	self._animator = nil
	self._audio = nil
	self._heartbeat = nil

	instance:SetAttribute("MoveDirection", Vector3.new())

	-- Audio
	local soundId = instance:GetAttribute("SoundId")
	self._audio = NPCAudio.new(self._hrp, soundId, self._janitor)

	return self
end

function NPCBase:Init()
	if self._destroyed then
		return
	end
	self:_startHeartbeat()

	-- Death listener
	local diedConn
	diedConn = self._humanoid.Died:Connect(function()
		if diedConn then
			diedConn:Disconnect()
		end
		self:_onDied()
	end)
	table.insert(self._connections, diedConn)

	if self._humanoid.Health <= 0 then
		task.defer(function()
			self:_onDied()
		end)
	end
end

function NPCBase:_onDied()
	if self._destroyed then
		return
	end
	self._state = "Dead"
	self:StopMoving()
	self._audio:StopVoiceLines()

	if self._heartbeat then
		self._heartbeat:Disconnect()
		self._heartbeat = nil
	end

	if self._hrp and self._hrp.Parent then
		self._hrp.AssemblyLinearVelocity = Vector3.zero
		self._hrp.AssemblyAngularVelocity = Vector3.zero
		self._hrp.Anchored = true
	end

	if self._animator then
		self._animator:SetLocomotion(0)
		self._animator:StopAction(0)
	end

	self._audio:PlayDeath()

	if self._animator then
		local deathTrack = self._animator:GetTrack("Death")
		if deathTrack then
			local markerName = self._config.DeathPauseMarker or "End"
			deathTrack.Looped = false
			local markerConn
			markerConn = deathTrack:GetMarkerReachedSignal(markerName):Connect(function()
				if markerConn then
					markerConn:Disconnect()
					markerConn = nil
				end
				if not deathTrack.Parent then
					return
				end
				deathTrack.TimePosition = math.max(deathTrack.TimePosition - 0.03, 0)
				deathTrack:AdjustSpeed(0)
			end)
			table.insert(self._connections, markerConn)
			deathTrack:Play(0.1)
		end
	end

	local despawnTime = self._config.DeathDespawnTime or 30
	task.delay(despawnTime, function()
		if not self._destroyed and self._instance and self._instance.Parent then
			self._instance:Destroy()
		end
	end)
end

function NPCBase:IsDead()
	return self._state == "Dead" or self._destroyed or (self._humanoid and self._humanoid.Health <= 0)
end

--\ Public — Animation \--

function NPCBase:SetupAnimator(animTable)
	if self._animator then
		self._animator:Destroy()
	end
	self._animator = NPCAnimator.new(self._humanoid, animTable)
end

function NPCBase:GetAnimator()
	return self._animator
end

--\ Public — Waypoints \--
-- Each entry is either a Vector3 OR a BasePart.
-- If a BasePart, its Position is used and its `Id` attribute triggers a behaviour.

function NPCBase:SetWaypoints(waypoints)
	self._waypoints = waypoints
	self._waypointIndex = 1
end

function NPCBase:SetWaypointsFromFolder(folder)
	local parts = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	table.sort(parts, function(a, b)
		local oA = a:GetAttribute("Order") or tonumber(a.Name) or 0
		local oB = b:GetAttribute("Order") or tonumber(b.Name) or 0
		return oA < oB
	end)
	-- Store parts directly so behaviour Ids are accessible at arrival
	self:SetWaypoints(parts)
end

function NPCBase:ClearWaypoints()
	self._waypoints = {}
	self._waypointIndex = 1
end

function NPCBase:GetWaypointIndex()
	return self._waypointIndex
end

--\ Public — Movement \--

function NPCBase:SetState(state)
	self._state = state
end

function NPCBase:GetState()
	return self._state
end

function NPCBase:SetSpeed(speed)
	self._humanoid.WalkSpeed = speed
end

function NPCBase:StopMoving()
	self._moveJanitor:Clean()
	self._instance:SetAttribute("MoveDirection", Vector3.new())
	self._currentPathPts = nil
	self._currentDest = nil
	self._humanoid:MoveTo(self._hrp.Position)
end

function NPCBase:GetInstance()
	return self._instance
end
function NPCBase:GetHRP()
	return self._hrp
end
function NPCBase:GetHumanoid()
	return self._humanoid
end

--\ Core Movement \--
-- Direct raycast first; pathfind on obstacle. Recomputes path only when
-- the destination changes meaningfully or the interval has elapsed.

function NPCBase:MoveToward(goalPos)
	if self._destroyed or not self._hrp.Parent then
		return
	end

	local rootPos = self._hrp.Position
	local offset = goalPos - rootPos
	local flatOffset = offset * noY
	local flatDist = flatOffset.Magnitude

	local threshold = math.sqrt(self._config.WaypointReachedThreshold or ARRIVE_THRESHOLD_SQ_DEFAULT)
	if flatDist < threshold then
		self:StopMoving()
		return
	end

	local goalDir = flatOffset.Unit
	local result = workspace:Raycast(rootPos, goalDir * (flatDist + DIRECT_RAY_EXTRA), self._rayParams)

	if not result then
		-- Clear path — direct move
		self._currentPathPts = nil
		self._currentDest = nil
		self._instance:SetAttribute("MoveDirection", goalDir)
		self._humanoid:MoveTo(goalPos)
	else
		-- Obstacle — use pathfinding with throttle
		local now = os.clock()
		local destChanged = not self._currentDest or (self._currentDest - goalPos).Magnitude > 2
		if destChanged or (now - self._lastPathRecompute) >= PATH_RECOMPUTE_MIN_INTERVAL then
			self:_recomputePath(goalPos)
		elseif self._currentPathPts then
			self:_followPath()
		end
	end
end

function NPCBase:_recomputePath(position)
	self._lastPathRecompute = os.clock()
	self._currentDest = position

	local ok = pcall(function()
		self._path:ComputeAsync(self._hrp.Position, position)
	end)

	if not ok or self._path.Status ~= Enum.PathStatus.Success then
		-- Fallback: aim directly even if there's an obstacle
		local flat = (position - self._hrp.Position) * noY
		if flat.Magnitude > 0.001 then
			self._instance:SetAttribute("MoveDirection", flat.Unit)
		end
		self._humanoid:MoveTo(position)
		self._currentPathPts = nil
		return
	end

	self._currentPathPts = self._path:GetWaypoints()
	self:_followPath()
end

function NPCBase:_followPath()
	local pts = self._currentPathPts
	if not pts then
		return
	end

	local margin = self._config.WaypointReachedThreshold or 3
	local hrpPos = self._hrp.Position
	local best

	-- Find the furthest reachable unblocked point ahead of us
	for i = #pts, 1, -1 do
		local pt = pts[i]
		if i == 1 then
			break
		end
		local distFlat = ((pt.Position - hrpPos) * noY).Magnitude
		if distFlat > margin then
			best = pt
			break
		end
	end

	if not best then
		-- Already at/past all waypoints
		self._currentPathPts = nil
		return
	end

	local moveDir = ((best.Position - hrpPos) * noY)
	if moveDir.Magnitude > 0.001 then
		self._instance:SetAttribute("MoveDirection", moveDir.Unit)
	end

	if best.Action == Enum.PathWaypointAction.Jump then
		self._humanoid.Jump = true
	end
	self._humanoid:MoveTo(best.Position)
end

--\ Public — Wandering \--

function NPCBase:StartWander()
	if self._state == "Wandering" then
		return
	end
	self._state = "Wandering"
	self._wanderOrigin = self._wanderOrigin or self._hrp.Position
	self._wanderTarget = nil
	self._audio:StartVoiceLines()
	self:_pickWanderTarget()
end

function NPCBase:SetWanderOrigin(position)
	self._wanderOrigin = position
end

function NPCBase:StopWander()
	if self._state ~= "Wandering" then
		return
	end
	self._state = "Idle"
	self:StopMoving()
end

--\ Public — Waypoint Patrol \--

function NPCBase:StartPatrol()
	if #self._waypoints == 0 then
		return
	end
	self._state = "Patrolling"
	self._waypointIndex = self:_nearestWaypointIndex()
	self._audio:StartVoiceLines()
end

function NPCBase:StopPatrol()
	if self._state ~= "Patrolling" then
		return
	end
	self._state = "Idle"
	self:StopMoving()
end

--\ Heartbeat \--

function NPCBase:_startHeartbeat()
	if self._heartbeat then
		return
	end
	self._heartbeat = RunService.Heartbeat:Connect(function(dt)
		if self._destroyed or not self._hrp.Parent then
			return
		end
		self:_onHeartbeat(dt)
	end)
	table.insert(self._connections, self._heartbeat)
end

function NPCBase:_onHeartbeat(dt)
	local state = self._state
	if state == "Wandering" then
		self:_tickWander(dt)
	elseif state == "Patrolling" then
		self:_tickPatrol(dt)
	end
	self:_tickAnimation()
end

--\ Wandering Logic \--

function NPCBase:_pickWanderTarget()
	local origin = self._wanderOrigin or self._hrp.Position
	local radius = self._config.WanderRadius or 20
	local angle = math.random() * math.pi * 2
	local dist = math.random() * radius
	local target = origin + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

	local ray = workspace:Raycast(target + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0))
	if ray then
		target = ray.Position
	end

	self._wanderTarget = target
	self._wanderIdleUntil = nil
	self:SetSpeed(self._config.WalkSpeed or 8)
end

function NPCBase:_tickWander(_dt)
	if self._state ~= "Wandering" then
		return
	end

	if self._wanderIdleUntil then
		if os.clock() < self._wanderIdleUntil then
			return
		end
		self._wanderIdleUntil = nil
		self:_pickWanderTarget()
		return
	end

	if not self._wanderTarget then
		self:_pickWanderTarget()
		return
	end

	local dist = ((self._hrp.Position - self._wanderTarget) * noY).Magnitude
	if dist < (self._config.WaypointReachedThreshold or 3) then
		self:StopMoving()
		local idleMin = self._config.WanderIdleMin or 2
		local idleMax = self._config.WanderIdleMax or 5
		self._wanderIdleUntil = os.clock() + idleMin + math.random() * (idleMax - idleMin)
		self._wanderTarget = nil
		return
	end

	self:MoveToward(self._wanderTarget)
end

--\ Patrol Logic \--

function NPCBase:_tickPatrol(_dt)
	if self._state ~= "Patrolling" or #self._waypoints == 0 then
		return
	end

	if self._patrolIdleUntil then
		if os.clock() < self._patrolIdleUntil then
			return
		end
		self._patrolIdleUntil = nil
		self._waypointIndex = self._waypointIndex % #self._waypoints + 1
	end

	local entry = self._waypoints[self._waypointIndex]
	if not entry then
		return
	end

	-- Resolve position from either a BasePart or a Vector3
	local target, entryPart
	if typeof(entry) == "Vector3" then
		target = entry
	elseif typeof(entry) == "Instance" and entry:IsA("BasePart") then
		target = entry.Position
		entryPart = entry
	else
		return
	end

	local dist = ((self._hrp.Position - target) * noY).Magnitude
	if dist < (self._config.WaypointReachedThreshold or 3) then
		self:StopMoving()

		-- Animated waypoint behaviour
		if entryPart then
			local id = entryPart:GetAttribute("Id")
			if type(id) == "string" and id ~= "" and WaypointBehaviours[id] then
				task.spawn(function()
					WaypointBehaviours[id](self, entryPart)
				end)
			end
		end

		local waitMin = self._config.PatrolWaitMin or self._config.WanderIdleMin or 1
		local waitMax = self._config.PatrolWaitMax or self._config.WanderIdleMax or 4
		self._patrolIdleUntil = os.clock() + waitMin + math.random() * (waitMax - waitMin)
		return
	end

	self:SetSpeed(self._config.WalkSpeed or 8)
	self:MoveToward(target)
end

function NPCBase:_nearestWaypointIndex()
	local pos = self._hrp.Position
	local best, bestDist = 1, math.huge
	for i, entry in self._waypoints do
		local wp
		if typeof(entry) == "Vector3" then
			wp = entry
		elseif typeof(entry) == "Instance" then
			wp = entry.Position
		end
		if wp then
			local d = (pos - wp).Magnitude
			if d < bestDist then
				best = i
				bestDist = d
			end
		end
	end
	return best
end

--\ Animation Tick \--

function NPCBase:_tickAnimation()
	if not self._animator then
		return
	end

	local moveDir = self._instance:GetAttribute("MoveDirection") or Vector3.new()
	local moving = moveDir.Magnitude > 0.1

	if not moving then
		self._animator:SetLocomotion(0)
		return
	end

	local walkSpeed = self._config.WalkSpeed or 8
	local runSpeed = self._config.RunSpeed or 16
	local current = self._humanoid.WalkSpeed
	local hasRun = self._animator:GetTrack("Run") ~= nil

	if not hasRun or current <= walkSpeed then
		self._animator:SetLocomotion(1)
	else
		local range = math.max(runSpeed - walkSpeed, 0.01)
		local t = math.clamp((current - walkSpeed) / range, 0, 1)
		self._animator:SetLocomotion(1 + t)
	end
end

--\ Cleanup \--

function NPCBase:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._state = "Dead"

	if self._audio then
		self._audio:Destroy()
	end

	for _, conn in self._connections do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(self._connections)

	if self._animator then
		self._animator:Destroy()
		self._animator = nil
	end

	self._janitor:Destroy()
	self._instance:SetAttribute("MoveDirection", Vector3.new())
	self._currentPathPts = nil
	self._waypoints = {}
end

return NPCBase
