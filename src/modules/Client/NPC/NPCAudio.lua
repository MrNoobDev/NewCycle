--[=[
	Per-NPC audio controller. Resolves the correct sound set from NPCSoundData
	by matching the NPC's `SoundId` attribute (falls back to "Default").

	Footsteps fire on movement distance accumulation — no per-frame polling
	beyond the single Heartbeat connection already running for movement.
	Voice lines play on a randomised timer while the NPC is patrolling/wandering.
	Attack and death sounds are fired imperatively by the caller.

	All connections and Sound instances are cleaned up via the supplied Janitor.

	@class NPCAudio
	@author mrnoob
]=]

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local NPCSoundData = require(script.Parent.NPCSoundData)

--\ Settings \--
local FOOTSTEP_STRIDE = 4.0 -- studs per step
local VOICE_LINE_MIN_INTERVAL = 12 -- seconds between patrol voice lines
local VOICE_LINE_MAX_INTERVAL = 25
local SOUND_VOLUME = 0.9
local FOOTSTEP_PITCH_MIN = 0.90
local FOOTSTEP_PITCH_MAX = 1.10

--\ Module \--
local NPCAudio = {}
NPCAudio.__index = NPCAudio

--\ Private helpers \--

local function pickRandom(t, lastIndex)
	if not t or #t == 0 then
		return nil, lastIndex
	end
	if #t == 1 then
		return t[1], 1
	end
	local idx
	repeat
		idx = math.random(1, #t)
	until idx ~= lastIndex
	return t[idx], idx
end

local function resolveSet(soundId)
	if soundId and NPCSoundData[soundId] then
		return NPCSoundData[soundId]
	end
	return NPCSoundData.Default
end

local function buildSounds(set, parent, janitor)
	local pool = {}
	-- Footstep pool
	local footstepPool = {}
	for _, id in (set.Footsteps or {}) do
		if type(id) == "string" and id ~= "" then
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Volume = SOUND_VOLUME
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMaxDistance = 50
			s.RollOffMinDistance = 5
			s.Parent = parent
			table.insert(footstepPool, s)
			janitor:GiveChore(s)
		end
	end
	pool.footsteps = footstepPool

	-- Attack pool
	local attackPool = {}
	for _, id in (set.Attack or {}) do
		if type(id) == "string" and id ~= "" then
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Volume = SOUND_VOLUME
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMaxDistance = 50
			s.RollOffMinDistance = 5
			s.Parent = parent
			table.insert(attackPool, s)
			janitor:GiveChore(s)
		end
	end
	pool.attack = attackPool

	-- Death pool
	local deathPool = {}
	for _, id in (set.Death or {}) do
		if type(id) == "string" and id ~= "" then
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Volume = SOUND_VOLUME
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMaxDistance = 50
			s.RollOffMinDistance = 5
			s.Parent = parent
			table.insert(deathPool, s)
			janitor:GiveChore(s)
		end
	end
	pool.death = deathPool

	-- Voice lines are played detached (no 3D instance needed yet)
	pool.voiceLines = set.VoiceLines or {}

	-- Preload
	local preloadList = {}
	for _, bucket in { footstepPool, attackPool, deathPool } do
		for _, s in bucket do
			table.insert(preloadList, s)
		end
	end
	if #preloadList > 0 then
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, preloadList)
		end)
	end

	return pool
end

--\ Lifecycle \--

function NPCAudio.new(hrp, soundId, janitor)
	assert(hrp, "NPCAudio.new: hrp required")
	assert(janitor, "NPCAudio.new: janitor required")

	local self = setmetatable({}, NPCAudio)
	self._hrp = hrp
	self._janitor = janitor
	self._rng = Random.new()
	self._lastFootIndex = 0
	self._lastAttIndex = 0
	self._lastDeathIndex = 0
	self._lastVoiceIndex = 0
	self._distAccum = 0
	self._lastPos = hrp.Position
	self._voiceThread = nil
	self._voicePaused = true

	local set = resolveSet(soundId)
	self._pool = buildSounds(set, hrp, janitor)
	self._soundId = soundId or "Default"

	-- Footstep heartbeat
	local footConn = RunService.Heartbeat:Connect(function(dt)
		self:_tickFootsteps(dt)
	end)
	janitor:GiveChore(footConn)

	return self
end

--\ Public \--

-- Call when the NPC starts patrolling/wandering so voice lines begin
function NPCAudio:StartVoiceLines()
	if self._voiceThread then
		return
	end
	self._voicePaused = false
	self._voiceThread = task.spawn(function()
		while not self._destroyed do
			local wait = VOICE_LINE_MIN_INTERVAL
				+ self._rng:NextNumber() * (VOICE_LINE_MAX_INTERVAL - VOICE_LINE_MIN_INTERVAL)
			task.wait(wait)
			if self._destroyed or self._voicePaused then
				break
			end
			self:_playVoiceLine()
		end
		self._voiceThread = nil
	end)
end

-- Call when entering chase/attack so voice lines stop
function NPCAudio:StopVoiceLines()
	self._voicePaused = true
	if self._voiceThread then
		task.cancel(self._voiceThread)
		self._voiceThread = nil
	end
end

function NPCAudio:PlayAttack()
	local pool = self._pool.attack
	if #pool == 0 then
		print(string.format("[NPCAudio:%s] Attack sound (no asset yet)", self._soundId))
		return
	end
	local s, idx = pickRandom(pool, self._lastAttIndex)
	self._lastAttIndex = idx
	if s then
		s:Play()
	end
end

function NPCAudio:PlayDeath()
	local pool = self._pool.death
	if #pool == 0 then
		print(string.format("[NPCAudio:%s] Death sound (no asset yet)", self._soundId))
		return
	end
	local s, idx = pickRandom(pool, self._lastDeathIndex)
	self._lastDeathIndex = idx
	if s then
		s:Play()
	end
end

function NPCAudio:Destroy()
	self._destroyed = true
	self:StopVoiceLines()
end

--\ Private \--

function NPCAudio:_tickFootsteps(_dt)
	if self._destroyed then
		return
	end
	local pos = self._hrp.Position
	local delta = pos - self._lastPos
	self._lastPos = pos

	local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
	self._distAccum = self._distAccum + flat

	if self._distAccum >= FOOTSTEP_STRIDE then
		self._distAccum = self._distAccum - FOOTSTEP_STRIDE
		self:_playFootstep()
	end
end

function NPCAudio:_playFootstep()
	local pool = self._pool.footsteps
	if #pool == 0 then
		return
	end -- silent until assets are added
	local s, idx = pickRandom(pool, self._lastFootIndex)
	self._lastFootIndex = idx
	if s then
		s.PlaybackSpeed = FOOTSTEP_PITCH_MIN + self._rng:NextNumber() * (FOOTSTEP_PITCH_MAX - FOOTSTEP_PITCH_MIN)
		s:Play()
	end
end

function NPCAudio:_playVoiceLine()
	local lines = self._pool.voiceLines
	if not lines or #lines == 0 then
		print(string.format("[NPCAudio:%s] Voice line (no asset yet)", self._soundId))
		return
	end
	local id, idx = pickRandom(lines, self._lastVoiceIndex)
	self._lastVoiceIndex = idx
	if type(id) == "string" and id ~= "" then
		print(string.format("[NPCAudio:%s] Playing voice line: %s", self._soundId, id))
		-- When real assets are ready: instantiate a detached Sound and Play() it.
	end
end

return NPCAudio
