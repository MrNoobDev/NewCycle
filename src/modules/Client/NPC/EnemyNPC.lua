--[=[
	Enemy NPC. Detects players with line of sight and FOV checks,
	patrols waypoints, chases, and attacks with a 3-hit combo.



	@class EnemyNPC
	@author mrnoob
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NPCBase = require(script.Parent.NPCBase)

--\ Constants \--
local noY = Vector3.new(1, 0, 1)

--\ Raycast Params \--
local LOS_PARAMS = RaycastParams.new()
LOS_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
LOS_PARAMS.IgnoreWater = true

--\ Module \--
local EnemyNPC = setmetatable({}, { __index = NPCBase })
EnemyNPC.__index = EnemyNPC

--\ Helpers \--

local function smoothFaceTarget(hrp, targetPos, duration)
	local startCF = hrp.CFrame
	local lookTarget = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)
	local elapsed = 0
	local Heartbeat = RunService.Heartbeat
	while elapsed < duration do
		local dt = Heartbeat:Wait()
		elapsed += dt
		local t = math.clamp(elapsed / duration, 0, 1)
		local ease = t * t * (3 - 2 * t)
		hrp.CFrame = startCF:Lerp(CFrame.lookAt(hrp.Position, lookTarget), ease)
	end
end

--\ Lifecycle \--

function EnemyNPC.new(instance, config)
	local self = NPCBase.new(instance, config)
	if not self then
		return nil
	end
	setmetatable(self, EnemyNPC)

	self._target = nil
	self._lastAttackClock = 0
	self._attackIndex = 0
	self._isAttacking = false
	self._isRunning = false
	self._inAttackZone = false
	self._isAlerting = false
	self._hasPlayedAlert = false
	-- Awareness
	self._awareness = 0
	self._awarenessState = "Unaware"
	self._lastSeenClock = 0

	return self
end

--\ Public \--

function EnemyNPC:GetTarget()
	return self._target
end
function EnemyNPC:IsAttacking()
	return self._isAttacking
end

function EnemyNPC:ClearTarget()
	self._target = nil
	self._state = "Idle"
	self._awareness = 0
	self._awarenessState = "Unaware"
	self._isRunning = false
	self._inAttackZone = false
	self._isAlerting = false
	self._hasPlayedAlert = false
	self._instance:SetAttribute("AwarenessState", "Unaware")
	self._instance:SetAttribute("Awareness", 0)
	-- Resume patrol/wander audio
	if self._audio then
		if #self._waypoints > 0 then
			self._audio:StartVoiceLines()
		else
			self._audio:StartVoiceLines()
		end
	end
end

--\ Override Heartbeat \--

function EnemyNPC:_onHeartbeat(dt)
	if self:IsDead() then
		return
	end
	if self._isAttacking or self._isAlerting then
		return
	end

	self:_tickDetection()

	if self._target then
		self:_tickChase(dt)
	elseif self._config.IdleWhenNoTarget then
		if self._state ~= "Idle" then
			self:StopMoving()
			self._state = "Idle"
		end
	elseif self._state ~= "Patrolling" and self._state ~= "Wandering" then
		if #self._waypoints > 0 then
			self:StartPatrol()
		else
			self:StartWander()
		end
	else
		NPCBase._onHeartbeat(self, dt)
	end

	self:_tickAnimation()
end

function EnemyNPC:_playAlertThenChase()
	if self._isAlerting or self._hasPlayedAlert or self._deathLocked or self:IsDead() then
		return
	end

	self._isAlerting = true
	self._hasPlayedAlert = true
	self:StopMoving()
	self._instance:SetAttribute("MoveDirection", Vector3.new())

	if self._humanoid then
		self._humanoid.WalkSpeed = 0
	end

	if self._animator then
		self._animator:SetLocomotion(0)

		local track = self._animator:PlayAction("Alert", 0.1)
		if track then
			track.Looped = false
			track.TimePosition = 0
			track:AdjustSpeed(1)

			task.spawn(function()
				local waitStart = os.clock()
				while track.Length <= 0 and os.clock() - waitStart < 0.5 do
					task.wait()
				end

				local length = track.Length
				if length <= 0 then
					length = self._config.AlertDuration or 0.8
				end

				task.wait(length)
				self:_finishAlert()
			end)

			return
		end
	end

	task.delay(self._config.AlertDuration or 0.8, function()
		self:_finishAlert()
	end)
end

function EnemyNPC:_finishAlert()
	if self._deathLocked or self:IsDead() then
		return
	end

	self._isAlerting = false
	self._state = "Chasing"
	self:SetSpeed(self._config.ChaseSpeed or self._config.RunSpeed or 16)

	if self._audio then
		self._audio:StopVoiceLines()
	end
end

--\ Detection — awareness meter with stealth rules \--

function EnemyNPC:_tickDetection()
	local player = Players.LocalPlayer
	local character = player and player.Character
	local playerHrp = character and character:FindFirstChild("HumanoidRootPart")
	local playerHum = character and character:FindFirstChildOfClass("Humanoid")

	if not playerHrp or not playerHrp.Parent or not playerHum or playerHum.Health <= 0 then
		if self._target then
			self:ClearTarget()
		end
		self._awareness = 0
		self._awarenessState = "Unaware"
		return
	end

	local dist = (self._hrp.Position - playerHrp.Position).Magnitude

	if self._target then
		local loseRange = self._config.LoseRange or 60
		if dist > loseRange then
			self:ClearTarget()
		end
		return
	end

	local dt = 1 / 60
	local rate = self:_computeDetectionRate(playerHrp, playerHum, dist)
	local decay = self._config.AwarenessDecayRate or 0.5

	if rate > 0 then
		self._awareness = math.min(1, self._awareness + rate * dt)
		self._lastSeenClock = os.clock()
	else
		local grace = self._config.AwarenessGrace or 0.4
		if os.clock() - self._lastSeenClock > grace then
			self._awareness = math.max(0, self._awareness - decay * dt)
		end
	end

	local suspThreshold = self._config.SuspiciousThreshold or 0.35
	local alertThreshold = self._config.AlertThreshold or 1.0
	local newState
	if self._awareness >= alertThreshold then
		newState = "Alert"
	elseif self._awareness >= suspThreshold then
		newState = "Suspicious"
	else
		newState = "Unaware"
	end

	if newState ~= self._awarenessState then
		self._awarenessState = newState
		self._instance:SetAttribute("AwarenessState", newState)
	end
	self._instance:SetAttribute("Awareness", self._awareness)

	if newState == "Alert" then
		self._target = player
		self._state = "Alerting"

		if self._audio then
			self._audio:StopVoiceLines()
		end

		self:_playAlertThenChase()
	end
end

function EnemyNPC:_computeDetectionRate(playerHrp, playerHum, dist)
	local detectionRange = self._config.DetectionRange or 40
	local behindRange = self._config.BehindDetectionRange or 15
	local crouchedBehindRange = self._config.CrouchedBehindRange or 4
	local crouchedFrontMult = self._config.CrouchedFrontMultiplier or 0.5

	local crouching = playerHum:GetAttribute("Crouching") == true
	local inFront = self:_isInFieldOfView(playerHrp)
	local effectiveRange

	if inFront then
		effectiveRange = detectionRange
		if crouching then
			effectiveRange = detectionRange * crouchedFrontMult
		end
	else
		effectiveRange = crouching and crouchedBehindRange or behindRange
	end

	if dist > effectiveRange then
		return 0
	end

	if not self:_hasLineOfSight(playerHrp) then
		local senseRange = self._config.SenseRange or 3
		if dist <= senseRange then
			return self._config.SenseRate or 0.5
		end
		return 0
	end

	local baseRate = self._config.BaseDetectionRate or 2.5
	local closeness = 1 - (dist / effectiveRange)
	local rate = baseRate * (0.35 + 0.65 * closeness)

	if crouching then
		rate *= 0.45
	end

	if playerHum.MoveDirection.Magnitude > 0.1 then
		local normalWalk = 8
		if playerHum.WalkSpeed > normalWalk * 1.3 then
			rate *= 1.5
		end
	else
		rate *= 0.7
	end

	return rate
end

function EnemyNPC:_isInFieldOfView(playerHrp)
	local fov = self._config.FieldOfView or 120
	local halfFov = math.rad(fov / 2)
	local npcLook = self._hrp.CFrame.LookVector
	local flatLook = Vector3.new(npcLook.X, 0, npcLook.Z)
	if flatLook.Magnitude < 0.001 then
		return true
	end
	flatLook = flatLook.Unit

	local toPlayer = playerHrp.Position - self._hrp.Position
	local flatToPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)
	if flatToPlayer.Magnitude < 0.001 then
		return true
	end
	flatToPlayer = flatToPlayer.Unit

	return flatLook:Dot(flatToPlayer) >= math.cos(halfFov)
end

function EnemyNPC:_hasLineOfSight(playerHrp)
	LOS_PARAMS.FilterDescendantsInstances = { self._instance }
	local origin = self._hrp.Position + Vector3.new(0, 1.5, 0)
	local direction = (playerHrp.Position + Vector3.new(0, 1, 0)) - origin
	local result = workspace:Raycast(origin, direction, LOS_PARAMS)
	if not result then
		return true
	end
	return result.Instance:IsDescendantOf(playerHrp.Parent)
end

--\ Chase \--

function EnemyNPC:_tickChase(_dt)
	local player = self._target
	if not player then
		return
	end
	local character = player.Character
	local playerHrp = character and character:FindFirstChild("HumanoidRootPart")
	if not playerHrp or not playerHrp.Parent then
		self:ClearTarget()
		return
	end

	local rootPos = self._hrp.Position
	local playerPos = playerHrp.Position
	local flatDist = ((rootPos - playerPos) * noY).Magnitude
	local attackRange = self._config.AttackRange or 5
	local attackCooldown = self._config.AttackCooldown or 1.5

	if flatDist <= attackRange then
		self._inAttackZone = true

		-- Kill all movement imperatively — do NOT call StopMoving() here because
		-- that internally calls MoveTo which nudges the humanoid one extra frame.
		self._moveJanitor:Clean()
		self._currentPathPts = nil
		self._currentDest = nil
		self._instance:SetAttribute("MoveDirection", Vector3.new())
		self._humanoid:MoveTo(self._hrp.Position)
		self._hrp.AssemblyLinearVelocity = Vector3.new(0, self._hrp.AssemblyLinearVelocity.Y, 0)

		-- Drive the animator directly — don't rely on _tickAnimation seeing the
		-- attribute change, which has a one-frame lag
		if self._animator then
			self._animator:SetLocomotion(0)
		end

		-- Face the player while waiting for cooldown
		local toPlayer = (playerPos - rootPos) * noY
		if toPlayer.Magnitude > 0.5 then
			local lookAt = Vector3.new(playerPos.X, rootPos.Y, playerPos.Z)
			self._hrp.CFrame = self._hrp.CFrame:Lerp(CFrame.lookAt(rootPos, lookAt), 0.2)
		end

		if os.clock() - self._lastAttackClock >= attackCooldown then
			self:_startAttack(playerHrp)
		end
		return
	end

	-- Left the attack zone this frame
	self._inAttackZone = false

	-- Outside damage zone — approach the player
	local toPlayer = (playerPos - rootPos) * noY
	local approachDir = toPlayer.Unit
	-- Stop goal is inside the zone so the NPC never hovers on the boundary
	local goalPos = playerPos - approachDir * (attackRange * 0.55)

	local runTrigger = self._config.RunTriggerDistance or 15
	local runStop = self._config.RunStopDistance or (runTrigger * 0.7)
	local walkSpeed = self._config.WalkSpeed or 8
	local chaseSpeed = self._config.ChaseSpeed or self._config.RunSpeed or 16

	if self._isRunning then
		if flatDist < runStop then
			self._isRunning = false
		end
	else
		if flatDist > runTrigger then
			self._isRunning = true
		end
	end

	local speed = self._isRunning and chaseSpeed or walkSpeed
	self:SetSpeed(speed)

	-- Force locomotion NOW — before MoveToward — so there is never a frame
	-- where the NPC moves but the animator shows idle
	if self._animator then
		local walkSp = self._config.WalkSpeed or 8
		local runSp = self._config.RunSpeed or 16
		local hasRun = self._animator:GetTrack("Run") ~= nil
		if not hasRun or speed <= walkSp then
			self._animator:SetLocomotion(1)
		else
			local range = math.max(runSp - walkSp, 0.01)
			self._animator:SetLocomotion(1 + math.clamp((speed - walkSp) / range, 0, 1))
		end
	end

	self:MoveToward(goalPos)

	-- Stamp MoveDirection toward the player so _tickAnimation agrees
	if toPlayer.Magnitude > 0.001 then
		self._instance:SetAttribute("MoveDirection", toPlayer.Unit)
	end
end

--\ Attacks \--

function EnemyNPC:_startAttack(playerHrp)
	self._isAttacking = true
	self:StopMoving()
	self._instance:SetAttribute("MoveDirection", Vector3.new())

	local prevWalkSpeed = self._humanoid.WalkSpeed
	self._humanoid.WalkSpeed = 0
	self._hrp.AssemblyLinearVelocity = Vector3.new(0, self._hrp.AssemblyLinearVelocity.Y, 0)

	if self._animator then
		self._animator:SetLocomotion(0)
	end

	self._attackIndex = self._attackIndex % 3 + 1

	local damage = self._config.Damage or 10
	local postDelay = self._config.PostAttackDelay or 0.4
	local turnDur = self._config.AttackTurnDuration or 0.2

	-- Play attack sound
	if self._audio then
		self._audio:PlayAttack()
	end

	task.spawn(function()
		smoothFaceTarget(self._hrp, playerHrp.Position, turnDur)
	end)

	if self._config.AttackTrackDuringWindup then
		task.spawn(function()
			local trackTime = 0
			local maxTrack = self._config.AttackTrackDuration or 0.25
			while trackTime < maxTrack and not self._destroyed and self._isAttacking do
				local dt = RunService.Heartbeat:Wait()
				trackTime += dt
				if not playerHrp.Parent then
					break
				end
				local lookPos = Vector3.new(playerHrp.Position.X, self._hrp.Position.Y, playerHrp.Position.Z)
				self._hrp.CFrame = self._hrp.CFrame:Lerp(CFrame.lookAt(self._hrp.Position, lookPos), 0.15)
			end
		end)
	end

	task.spawn(function()
		if self._animator then
			local track = self._animator:PlayAction("Attacks", 0.25, nil, self._attackIndex)
			if track then
				local waitStart = os.clock()
				while not track.IsPlaying and os.clock() - waitStart < 0.5 do
					task.wait()
				end
				if self._destroyed then
					return
				end

				local len = track.Length
				if len <= 0 then
					len = 0.8
				end

				local hitPhase = self._config.AttackHitPhase or 0.5
				task.wait(len * hitPhase)
				self:_applyDamage(damage)
				task.wait(len * (1 - hitPhase))
			else
				task.wait(0.8)
				self:_applyDamage(damage)
			end
		else
			task.wait(0.8)
			self:_applyDamage(damage)
		end

		self._lastAttackClock = os.clock()

		if not self._destroyed then
			task.wait(postDelay)
		end
		if not self._destroyed then
			self._humanoid.WalkSpeed = prevWalkSpeed
			self._isAttacking = false
		end
	end)
end

function EnemyNPC:_applyDamage(damage)
	if self._destroyed or self:IsDead() then
		return
	end
	local player = self._target
	if not player then
		return
	end
	local character = player.Character
	local playerHum = character and character:FindFirstChildOfClass("Humanoid")
	local playerHrp = character and character:FindFirstChild("HumanoidRootPart")
	if not playerHum or playerHum.Health <= 0 or not playerHrp then
		return
	end

	local dist = (self._hrp.Position - playerHrp.Position).Magnitude
	local reach = self._config.AttackHitReach or ((self._config.AttackRange or 5) + 1.5)

	-- Cone check
	local toPlayer = (playerHrp.Position - self._hrp.Position) * Vector3.new(1, 0, 1)
	if toPlayer.Magnitude > 0.001 then
		local look = self._hrp.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 0.001 then
			local dot = flatLook.Unit:Dot(toPlayer.Unit)
			local cone = self._config.AttackHitCone or 110
			if dot < math.cos(math.rad(cone / 2)) then
				return
			end
		end
	end

	if dist > reach then
		return
	end
	playerHum:TakeDamage(damage)
end

--\ Override Animation Tick — suppress during attacks or while in attack zone \--

function EnemyNPC:_tickAnimation()
	if self._isAttacking then
		return
	end
	if self._inAttackZone then
		return
	end
	NPCBase._tickAnimation(self)
end

--\ Cleanup \--

function EnemyNPC:Destroy()
	self._target = nil
	self._isAttacking = false
	self._inAttackZone = false
	NPCBase.Destroy(self)
end

return EnemyNPC
