--[=[
	Lost One enemy. Extends EnemyNPC with a leap attack that closes
	distance to the player using a ballistic arc and smooth landing.

	@class LostOneNPC
	@author mrnoob
]=]

local RunService = game:GetService("RunService")

local EnemyNPC = require(script.Parent.EnemyNPC)

--\ Constants \--
local noY = Vector3.new(1, 0, 1)

--\ Raycast Params \--
local LEAP_PARAMS = RaycastParams.new()
LEAP_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
LEAP_PARAMS.IgnoreWater = true

--\ Module \--
local LostOneNPC = setmetatable({}, { __index = EnemyNPC })
LostOneNPC.__index = LostOneNPC

--\ Lifecycle \--

function LostOneNPC.new(instance: Model, config: { [string]: any })
	local self = EnemyNPC.new(instance, config)
	if not self then
		return nil
	end
	setmetatable(self, LostOneNPC)

	self._lastLeapClock = 0
	self._isLeaping = false
	self._justSpotted = false

	return self
end

--\ Override Detection — flag when target is first acquired \--

function LostOneNPC:_tickDetection()
	local hadTarget = self._target ~= nil
	EnemyNPC._tickDetection(self)
	if not hadTarget and self._target then
		self._justSpotted = true
	end
end

--\ Override Chase \--

function LostOneNPC:_tickChase(dt: number)
	if self._isLeaping then
		return
	end

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

	if self._config.EnableLeap then
		local dist = (self._hrp.Position - playerHrp.Position).Magnitude
		local leapRange = self._config.LeapRange or 18
		local leapMinRange = self._config.LeapMinRange or 7
		local leapCooldown = self._config.LeapCooldown or 6
		local openingLeapRange = self._config.OpeningLeapRange or 30
		local openingLeapMinRange = self._config.OpeningLeapMinRange or leapMinRange
		local now = os.clock()

		if self._justSpotted then
			self._justSpotted = false
			if dist >= openingLeapMinRange and dist <= openingLeapRange then
				if self:_canLeapTo(playerHrp) then
					self:_startLeap(playerHrp)
					return
				end
			end
		end

		if dist >= leapMinRange and dist <= leapRange and now - self._lastLeapClock >= leapCooldown then
			if self:_canLeapTo(playerHrp) then
				self:_startLeap(playerHrp)
				return
			end
		end
	else
		self._justSpotted = false
	end

	EnemyNPC._tickChase(self, dt)
end

--\ Leap Validation \--

function LostOneNPC:_canLeapTo(playerHrp: BasePart): boolean
	LEAP_PARAMS.FilterDescendantsInstances = { self._instance }

	local origin = self._hrp.Position + Vector3.new(0, 1, 0)
	local toPlayer = playerHrp.Position - self._hrp.Position
	local flatDir = (toPlayer * noY)
	if flatDir.Magnitude < 0.001 then
		return false
	end
	flatDir = flatDir.Unit

	local wallCheck = self._config.LeapWallCheckDistance or 4
	local wallResult = workspace:Raycast(origin, flatDir * wallCheck, LEAP_PARAMS)
	if wallResult then
		return false
	end

	local leapDist = ((self._hrp.Position - playerHrp.Position) * noY).Magnitude
	local midPoint = origin + flatDir * (leapDist * 0.5) + Vector3.new(0, 4, 0)
	local groundCheck = workspace:Raycast(midPoint, Vector3.new(0, -20, 0), LEAP_PARAMS)
	if not groundCheck then
		return false
	end

	return true
end

--\ Leap Execution \--

function LostOneNPC:_startLeap(playerHrp: BasePart)
	self._isLeaping = true
	self._isAttacking = true
	self._lastLeapClock = os.clock()
	self:StopMoving()

	local lookAt = Vector3.new(playerHrp.Position.X, self._hrp.Position.Y, playerHrp.Position.Z)
	self._hrp.CFrame = CFrame.lookAt(self._hrp.Position, lookAt)

	task.spawn(function()
		self:_leapRoutine(playerHrp)
	end)
end

function LostOneNPC:_leapRoutine(playerHrp: BasePart)
	local arcHeight = self._config.LeapArcHeight or 2.5
	local launchDelay = self._config.LeapLaunchDelay or 0.15
	local leapHorizontalSpeed = self._config.LeapHorizontalSpeed or 35

	-- Start the animation, then wait until it actually begins playing before launch.
	local leapTrack = nil
	if self._animator then
		leapTrack = self._animator:Play("Leap", 0.05)
	end
	if leapTrack then
		local waitStart = os.clock()
		while not leapTrack.IsPlaying and os.clock() - waitStart < 0.4 do
			RunService.Heartbeat:Wait()
		end
	end

	-- Optional pre-launch delay to sync with anim windup.
	if launchDelay > 0 then
		task.wait(launchDelay)
	end
	if self._destroyed then
		return
	end

	-- Land directly at the player's position (no buffer eating distance).
	local startPos = self._hrp.Position
	local playerPos = playerHrp.Position
	local toPlayer = (playerPos - startPos) * noY
	local flatDist = toPlayer.Magnitude
	if flatDist < 0.001 then
		self:_endLeap()
		return
	end
	local flatDir = toPlayer.Unit

	-- Constant horizontal speed; airtime derived from how far we need to travel.
	local airtime = flatDist / leapHorizontalSpeed
	airtime = math.clamp(airtime, 0.18, 0.8)

	-- Vertical velocity tuned so peak height = arcHeight at airtime/2.
	local g = workspace.Gravity
	local verticalDiff = playerPos.Y - startPos.Y
	-- Compute v0_y so position at airtime equals verticalDiff:
	-- y(t) = v0*t - 0.5*g*t^2  →  v0 = (verticalDiff + 0.5*g*t^2) / t
	local verticalVel = (verticalDiff + 0.5 * g * airtime * airtime) / airtime
	-- Cap so peak isn't crazy: peak = v0^2 / (2g)
	local maxV = math.sqrt(2 * g * (arcHeight + math.max(verticalDiff, 0)))
	if verticalVel > maxV then
		verticalVel = maxV
	end

	local horizontalVel = flatDir * leapHorizontalSpeed

	self._humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	self._hrp.AssemblyLinearVelocity = horizontalVel + Vector3.new(0, verticalVel, 0)
	local leapDuration = airtime

	-- Track flight, end early on landing, wall collision, or hitting the player.
	local damage = self._config.LeapDamage or self._config.Damage or 10
	local hitRadius = self._config.LeapHitRadius or 4
	local elapsed = 0
	local landed = false
	local hitPlayer = false
	while elapsed < leapDuration * 1.4 and not self._destroyed do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt

		LEAP_PARAMS.FilterDescendantsInstances = { self._instance }

		-- Mid-flight player hit — apply damage instantly and stop the leap.
		local currentPlayerHrp = playerHrp.Parent and playerHrp
		if currentPlayerHrp then
			local distToPlayer = (self._hrp.Position - currentPlayerHrp.Position).Magnitude
			if distToPlayer <= hitRadius then
				self:_applyDamage(damage)
				hitPlayer = true
				break
			end
		end

		-- Wall check forward
		local wallRay = workspace:Raycast(
			self._hrp.Position + Vector3.new(0, 1, 0),
			flatDir * 2,
			LEAP_PARAMS
		)
		if wallRay and not wallRay.Instance:IsDescendantOf(playerHrp.Parent) then
			break
		end

		-- Land detection (only after midflight, on descent)
		if elapsed > leapDuration * 0.4 then
			local groundRay = workspace:Raycast(
				self._hrp.Position,
				Vector3.new(0, -3.5, 0),
				LEAP_PARAMS
			)
			local downwardVel = self._hrp.AssemblyLinearVelocity.Y
			if groundRay and downwardVel <= 1 then
				landed = true
				break
			end
		end
	end

	-- Smooth horizontal deceleration on land.
	self:_decelerateAfterLand()

	-- Final damage check — if we didn't connect mid-flight, try once on landing.
	if not hitPlayer then
		self:_applyDamage(damage)
	end

	-- Let the leap animation finish its outro.
	if self._animator then
		local track = self._animator:GetTrack("Leap")
		if track and track.IsPlaying then
			local remaining = track.Length - track.TimePosition
			if remaining > 0 then
				task.wait(math.min(remaining, 0.25))
			end
		end
	end

	self:_endLeap()
	local _ = landed
end

function LostOneNPC:_decelerateAfterLand()
	local startVel = self._hrp.AssemblyLinearVelocity
	local flatVel = Vector3.new(startVel.X, 0, startVel.Z)
	if flatVel.Magnitude < 0.5 then
		self._hrp.AssemblyLinearVelocity = Vector3.new(0, startVel.Y, 0)
		return
	end

	local decelTime = 0.18
	local elapsed = 0
	while elapsed < decelTime and not self._destroyed do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local t = math.clamp(1 - (elapsed / decelTime), 0, 1)
		local current = self._hrp.AssemblyLinearVelocity
		self._hrp.AssemblyLinearVelocity = Vector3.new(flatVel.X * t, current.Y, flatVel.Z * t)
	end
end

function LostOneNPC:_endLeap()
	if not self._destroyed then
		self._isLeaping = false
		self._isAttacking = false
	end
end

--\ Cleanup \--

function LostOneNPC:Destroy()
	self._isLeaping = false
	EnemyNPC.Destroy(self)
end

return LostOneNPC
