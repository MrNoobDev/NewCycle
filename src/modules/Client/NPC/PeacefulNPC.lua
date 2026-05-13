--[=[
	Peaceful NPC. Can follow waypoints or walk behind the player.
	Switches between modes smoothly using direct movement + pathfind fallback.

	@class PeacefulNPC
	@author mrnoob
]=]

local Players = game:GetService("Players")

local NPCBase = require(script.Parent.NPCBase)

--\ Constants \--
local noY = Vector3.new(1, 0, 1)

--\ Module \--
local PeacefulNPC = setmetatable({}, { __index = NPCBase })
PeacefulNPC.__index = PeacefulNPC

--\ Lifecycle \--

function PeacefulNPC.new(instance: Model, config: { [string]: any })
	local self = NPCBase.new(instance, config)
	if not self then
		return nil
	end
	setmetatable(self, PeacefulNPC)

	self._mode = "Waypoints"
	self._followTarget = nil
	self._lastPlayerMoveDir = nil
	self._anchorPos = nil

	return self
end

--\ Public — Mode Switching \--

function PeacefulNPC:SetMode(mode: string)
	if mode == self._mode then
		return
	end

	self:StopMoving()
	self._state = "Idle"
	self._mode = mode

	if mode == "FollowPlayer" then
		self._followTarget = Players.LocalPlayer
		self._state = "Following"
	elseif mode == "Waypoints" then
		self._followTarget = nil
		if #self._waypoints > 0 then
			self:StartPatrol()
		else
			self:StartWander()
		end
	elseif mode == "Wander" then
		self._followTarget = nil
		self:StartWander()
	end
end

function PeacefulNPC:GetMode(): string
	return self._mode
end

--\ Override Heartbeat \--

function PeacefulNPC:_onHeartbeat(dt: number)
	if self._mode == "FollowPlayer" then
		self:_tickFollowPlayer(dt)
	else
		NPCBase._onHeartbeat(self, dt)
	end

	self:_tickAnimation()
end

--\ Follow Player \--

function PeacefulNPC:_tickFollowPlayer(_dt: number)
	local player = self._followTarget
	if not player then
		return
	end
	local character = player.Character
	local playerHrp = character and character:FindFirstChild("HumanoidRootPart")
	local playerHum = character and character:FindFirstChildOfClass("Humanoid")
	if not playerHrp or not playerHrp.Parent or not playerHum then
		return
	end

	local behindOffset = self._config.FollowBehindOffset or 7
	local rootPos = self._hrp.Position
	local playerPos = playerHrp.Position

	local playerMoving = playerHum.MoveDirection.Magnitude > 0.1

	if playerMoving then
		local moveDir = (playerHum.MoveDirection * noY)
		if moveDir.Magnitude > 0.001 then
			self._lastPlayerMoveDir = moveDir.Unit
		end
		local goalPos = playerPos - self._lastPlayerMoveDir * behindOffset
		self._anchorPos = goalPos

		local distToGoal = ((rootPos - goalPos) * noY).Magnitude

		if distToGoal < 1.5 then
			self:SetSpeed(playerHum.WalkSpeed)
			self._humanoid:MoveTo(goalPos)
			self._instance:SetAttribute("MoveDirection", self._lastPlayerMoveDir)
		else
			local catchUpSpeed = playerHum.WalkSpeed + distToGoal * 0.5
			self:SetSpeed(math.min(catchUpSpeed, (self._config.RunSpeed or 16)))
			self:MoveToward(goalPos)
		end

		self._state = "Following"
	else
		if self._anchorPos then
			local distToAnchor = ((rootPos - self._anchorPos) * noY).Magnitude
			if distToAnchor > 2 then
				self:SetSpeed(self._config.WalkSpeed or 6)
				self:MoveToward(self._anchorPos)
				self._state = "Following"
			else
				self:StopMoving()
				self._state = "Idle"

				local toPlayer = (playerPos - rootPos) * noY
				if toPlayer.Magnitude > 0.5 then
					local lookAt = Vector3.new(playerPos.X, rootPos.Y, playerPos.Z)
					self._hrp.CFrame = CFrame.lookAt(rootPos, lookAt)
				end
			end
		else
			self:StopMoving()
			self._state = "Idle"
		end
	end
end

--\ Cleanup \--

function PeacefulNPC:Destroy()
	self._followTarget = nil
	NPCBase.Destroy(self)
end

return PeacefulNPC
