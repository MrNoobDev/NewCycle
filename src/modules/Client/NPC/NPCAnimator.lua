--[=[
	NPC animation state handler. Blends locomotion tracks (Idle/Walk/Run) by
	adjusting weights with AccelTween — no stop/start gaps, no T-posing.
	Action tracks (Attacks, Leap, Hit) play on top with higher priority.

	@class NPCAnimator
	@author mrnoob
]=]

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

--\ Constants \--
local LOCO_NAMES = { "Idle", "Walk", "Run" }
local BLEND_RATE = 5 -- higher = snappier, lower = smoother (1/s)

--\ Module \--
local NPCAnimator = {}
NPCAnimator.__index = NPCAnimator

--\ Lifecycle \--

function NPCAnimator.new(humanoid: Humanoid, animTable: { [string]: string | { string } })
	local self = setmetatable({}, NPCAnimator)
	self._humanoid = humanoid
	self._animator = humanoid:FindFirstChildOfClass("Animator")
	if not self._animator then
		self._animator = Instance.new("Animator")
		self._animator.Parent = humanoid
	end

	self._tracks = {}
	self._arrayTracks = {}
	self._actionCurrent = nil

	self._intensity = 0
	self._intensityTarget = 0

	self._destroyed = false

	self:_loadAll(animTable)
	self:_startLocomotion()
	self:_startBlendLoop()

	return self
end

--\ Public — Locomotion \--

function NPCAnimator:SetLocomotion(intensity: number)
	self._intensityTarget = math.clamp(intensity, 0, 2)
end

function NPCAnimator:GetLocomotion(): number
	return self._intensity
end

function NPCAnimator:SetLocomotionSpeed(speed: number)
	for _, name in LOCO_NAMES do
		local track = self._tracks[name]
		if track then
			track:AdjustSpeed(speed)
		end
	end
end

--\ Public — Actions \--

function NPCAnimator:PlayAction(name: string, fadeTime: number?, speed: number?, index: number?): AnimationTrack?
	local track = self:GetTrack(name, index)
	if not track then
		return nil
	end
	if self._actionCurrent == track and track.IsPlaying then
		return track
	end
	if self._actionCurrent and self._actionCurrent ~= track and self._actionCurrent.IsPlaying then
		self._actionCurrent:Stop(fadeTime or 0.2)
	end
	track:Play(fadeTime or 0.15)
	if speed then
		track:AdjustSpeed(speed)
	end
	self._actionCurrent = track
	return track
end

function NPCAnimator:StopAction(fadeTime: number?)
	if self._actionCurrent and self._actionCurrent.IsPlaying then
		self._actionCurrent:Stop(fadeTime or 0.15)
	end
	self._actionCurrent = nil
end

--\ Public — Legacy API (for compatibility with existing code) \--

function NPCAnimator:Play(name: string, fadeTime: number?, speed: number?, index: number?): AnimationTrack?
	if name == "Idle" then
		self:SetLocomotion(0)
		return self._tracks.Idle
	elseif name == "Walk" then
		self:SetLocomotion(1)
		return self._tracks.Walk
	elseif name == "Run" then
		self:SetLocomotion(2)
		return self._tracks.Run
	end
	return self:PlayAction(name, fadeTime, speed, index)
end

function NPCAnimator:Stop(name: string, fadeTime: number?, index: number?)
	if name == "Idle" or name == "Walk" or name == "Run" then
		return
	end
	local track = self:GetTrack(name, index)
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.15)
	end
	if self._actionCurrent == track then
		self._actionCurrent = nil
	end
end

function NPCAnimator:StopAll(fadeTime: number?)
	self:StopAction(fadeTime)
	self:SetLocomotion(0)
end

function NPCAnimator:GetTrack(name: string, index: number?): AnimationTrack?
	if index then
		local list = self._arrayTracks[name]
		return list and list[index]
	end
	return self._tracks[name]
end

function NPCAnimator:GetCurrent(): AnimationTrack?
	return self._actionCurrent
end

function NPCAnimator:AdjustSpeed(speed: number)
	if self._actionCurrent then
		self._actionCurrent:AdjustSpeed(speed)
	end
end

--\ Private \--

function NPCAnimator:_loadAll(animTable: { [string]: string | { string } })
	local toPreload = {}

	for name, value in animTable do
		if type(value) == "table" then
			local list = {}
			for i, id in value do
				if type(id) == "string" and id ~= "" then
					local track = self:_loadTrack(id, false, Enum.AnimationPriority.Action)
					list[i] = track
					table.insert(toPreload, id)
				end
			end
			self._arrayTracks[name] = list
		elseif type(value) == "string" and value ~= "" then
			local isLoco = (name == "Idle" or name == "Walk" or name == "Run")
			local priority = isLoco and Enum.AnimationPriority.Core or Enum.AnimationPriority.Action
			self._tracks[name] = self:_loadTrack(value, isLoco, priority)
			table.insert(toPreload, value)
		end
	end

	if #toPreload > 0 then
		task.spawn(function()
			local anims = {}
			for _, id in toPreload do
				local a = Instance.new("Animation")
				a.AnimationId = id
				table.insert(anims, a)
			end
			pcall(function()
				ContentProvider:PreloadAsync(anims)
			end)
			for _, a in anims do
				a:Destroy()
			end
		end)
	end
end

function NPCAnimator:_loadTrack(animId: string, looped: boolean, priority: Enum.AnimationPriority): AnimationTrack
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local track = self._animator:LoadAnimation(anim)
	track.Priority = priority
	track.Looped = looped
	anim:Destroy()
	return track
end

function NPCAnimator:_startLocomotion()
	for _, name in LOCO_NAMES do
		local track = self._tracks[name]
		if track then
			track:Play(0)
			track:AdjustWeight(0.001, 0)
		end
	end

	local idle = self._tracks.Idle
	if idle then
		idle:AdjustWeight(1, 0)
	end
end

function NPCAnimator:_startBlendLoop()
	self._blendConn = RunService.Heartbeat:Connect(function(dt)
		if self._destroyed then
			return
		end
		self:_updateBlend(dt)
	end)
end

function NPCAnimator:_updateBlend(dt: number)
	local alpha = math.clamp(dt * BLEND_RATE, 0, 1)
	self._intensity += (self._intensityTarget - self._intensity) * alpha
	local intensity = self._intensity

	local idleW = math.max(0, 1 - intensity)
	local walkW = math.max(0, 1 - math.abs(intensity - 1))
	local runW = math.max(0, intensity - 1)

	local sum = idleW + walkW + runW
	if sum < 0.001 then
		idleW = 1
		sum = 1
	end
	idleW = idleW / sum
	walkW = walkW / sum
	runW = runW / sum

	local idle = self._tracks.Idle
	local walk = self._tracks.Walk
	local run = self._tracks.Run

	if idle then
		idle:AdjustWeight(math.max(idleW, 0.001), 0)
	end
	if walk then
		walk:AdjustWeight(math.max(walkW, 0.001), 0)
	end
	if run then
		run:AdjustWeight(math.max(runW, 0.001), 0)
	end
end

--\ Cleanup \--

function NPCAnimator:Destroy()
	self._destroyed = true
	if self._blendConn then
		self._blendConn:Disconnect()
		self._blendConn = nil
	end
	if self._actionCurrent and self._actionCurrent.IsPlaying then
		self._actionCurrent:Stop(0)
	end
	for _, track in self._tracks do
		if track.IsPlaying then
			track:Stop(0)
		end
		track:Destroy()
	end
	for _, list in self._arrayTracks do
		for _, track in list do
			if track.IsPlaying then
				track:Stop(0)
			end
			track:Destroy()
		end
	end
	table.clear(self._tracks)
	table.clear(self._arrayTracks)
	self._actionCurrent = nil
end

return NPCAnimator
