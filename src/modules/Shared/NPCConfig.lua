--[=[
	NPC tuning. Defaults for all NPC types live here.

	@class NPCConfig
	@author mrnoob
]=]

return {
	--\ General \--
	PathRecomputeInterval = 0.5,
	WaypointReachedThreshold = 3,
	WanderRadius = 20,
	WanderIdleMin = 2,
	WanderIdleMax = 5,
	DeathDespawnTime = 30,

	--\ Movement \--
	WalkSpeed = 8,
	RunSpeed = 16,

	--\ Peaceful \--
	Peaceful = {
		FollowDistance = 5,
		FollowBehindOffset = 4,
		WalkSpeed = 8,
	},

	--\ Enemy \--
	Enemy = {
		IdleWhenNoTarget = true,
		DetectionRange = 40,
		LoseRange = 60,
		FieldOfView = 120,
		BehindDetectionRange = 15,
		CrouchedBehindRange = 4,
		CrouchedFrontMultiplier = 0.55,
		SenseRange = 3,
		SenseRate = 0.6,
		BaseDetectionRate = 2.5,
		AwarenessDecayRate = 0.5,
		AwarenessGrace = 0.4,
		SuspiciousThreshold = 0.35,
		AlertThreshold = 1.0,
		RearCrouchInvisible = true,
		AttackRange = 6.5,
		AttackHitReach = 9,
		AttackHitCone = 160,
		AttackCooldown = 1.5,
		AttackHitPhase = 0.4,
		AttackTurnDuration = 0.2,
		AttackTrackDuringWindup = true,
		PostAttackDelay = 0.4,
		PatrolWaitMin = 1,
		PatrolWaitMax = 4,
		WalkSpeed = 8,
		RunSpeed = 12,
		ChaseSpeed = 8,
		RunTriggerDistance = 15,
	},

	--\ Lost One \--
	LostOne = {
		Damage = 1,
		AttackRange = 5,
		AttackCooldown = 1.2,
		EnableLeap = false,
		LeapRange = 25,
		LeapMinRange = 14,
		LeapDamage = 14,
		LeapHitRadius = 4,
		LeapArcHeight = 2,
		LeapHorizontalSpeed = 50,
		LeapLaunchDelay = 0.15,
		LeapCooldown = 9,
		LeapWallCheckDistance = 4,
		OpeningLeapRange = 35,
		OpeningLeapMinRange = 16,
		WalkSpeed = 7,
		RunSpeed = 16,
		ChaseSpeed = 16,
		RunTriggerDistance = 9,
		RunStopDistance = 6,
		DetectionRange = 40,
		FieldOfView = 110,
	},

	--\ Bendy (Peaceful) \--
	Bendy = {
		WalkSpeed = 6,
		FollowDistance = 6,
		FollowBehindOffset = 7,
	},
}
