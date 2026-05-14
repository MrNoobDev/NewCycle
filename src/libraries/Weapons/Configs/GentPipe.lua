local gentPipe = {
	id = "gentPipe",
	weaponType = "melee",
	viewmodelName = "Axe",
	weaponModelName = "Axe",
	stage = 2,
	grantOnSpawn = true,
	animations = {
		primaryAttack = "rbxassetid://128405525724519",
		secondaryAttack = "rbxassetid://93668736515901",
		idle = "rbxassetid://100302047786836",
		block = "rbxassetid://94744080162798",
	},
	sounds = {
		swing = {
			"sfx_weapon_gent_whoosh_base_01",
			"sfx_weapon_gent_whoosh_base_02",
			"sfx_weapon_gent_whoosh_base_03",
			"sfx_weapon_gent_whoosh_base_04",
			"sfx_weapon_gent_whoosh_base_05",
			"sfx_weapon_gent_whoosh_base_06",
		},
		block = "Sfx_Axe_Block",
		effortFolder = { "Player", "Effort", "Attack" },
		effort = {
			"vo_audrey_effort_4attack_01",
			"vo_audrey_effort_4attack_02",
			"vo_audrey_effort_4attack_03",
			"vo_audrey_effort_4attack_04",
			"vo_audrey_effort_4attack_05",
			"vo_audrey_effort_4attack_06",
		},
		volume = {
			swing = 0.8,
			effort = 1,
		},
	},
	combat = {
		attackCooldown = 0.8,

		-- Blocking
		perfectBlockWindow = 0.2,
		maxBlockTime = 3,

		blockCooldown = 0.35,
		blockTimeoutCooldown = 0.5,
		blockBreakCooldown = 0.9,

		blockBreakStun = 0.6,
		parriedStunDuration = 1,

		attackCastDelay = 0.22,
		debugHitVisualizer = false,

		hitBoxForwardOffset = 2.8,
		hitBoxSize = Vector3.new(5, 4, 5.5),
		blockDamageMultiplier = 0.35,
		blockWalkSpeed = 4,
		blockBreakDamageMultiplier = 0.75,
		guardDamage = 25,

		blockDuration = 0.05,
		blockAngle = 115,

		hitCooldown = 0.1,
		maxHitDistance = 6.5,
		hitPartSpeed = 80,
		hitPartLifetime = 0.15,
		hitPartSize = Vector3.new(2, 2, 4),

		baseDamage = 28,
		closeDamageDistance = 1.75,
		minDistanceDamageMultiplier = 0.8,
	},
	camera = {
		viewmodelOffset = CFrame.new(0, 0.05, -0.6),
		sprintOffset = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-9), 0, 0),

		bobMovingLerp = 0.1,
		bobIdleLerp = 0.1,
		shakeDecay = 10,
		attackShake = Vector3.new(0.6, 0.35, 0.1),
		blockShake = Vector3.new(1.2, 1.2, 0.15),
	},
	effects = {
		blockParticles = {
			"HIT",
			"STRIKES",
			"SingularRays",
			"SurroundingAura",
		},
		defenceVisuals = {
			show = { "Rope_Henry2" },
			hide = { "default_L", "hand", "ring", "Rope_Henry" },
		},
		hitInkVfxPath = { "Assets", "VFX", "WeaponHitInk", "Attachment" },

		hitInkEmit = {
			blood1 = 8,
			blood2 = 4,
		},

		hitInkDripOutTime = 1,
		hitInkLifetime = 1.35,

		hiddenViewmodelParts = {
			RootPart = true,
			Muzzle = true,
			FakeCamera = true,
			Aimpart = true,
			HumanoidRootPart = true,
			MuzzleFlash = true,
			CameraBone = true,
			Joint = true,
			Main = true,
			audrey_ink_Gentpipe_Upgrade2 = true,
			audrey_ink_Gentpipe_Upgrade1 = true,
			audrey_ink_Gentpipe_Upgrade3 = true,
			audrey_ink_Gentpipe_socket = true,
		},
	},
}

return gentPipe
