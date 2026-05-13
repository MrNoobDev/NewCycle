local weaponConfig = {
	weaponName = "Axe",
	weaponType = "Melee",
	animations = {
		fire = "rbxassetid://128405525724519",
		fire2 = "rbxassetid://93668736515901",
		idle = "rbxassetid://100302047786836",
		defence = "rbxassetid://94744080162798",
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
	},
	combat = {
		attackRange = 10,
		maxHitDistance = 3,
		hitPartSpeed = 80,
		attackRate = 0.5,
		defenceDuration = 0.05,
		damage = {
			base = 100,
			headshot = 100,
			bodyshot = 100,
		},
	},
	camera = {
		aimSmooth = 0.2,
		aimFOV = 60,
		sprintCFrame = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-9), 0, 0),
		shake = {
			attack = { magnitude = 0.5, roughness = 0.3, fadeIn = 0.1, fadeOut = 0.15 },
			defence = { magnitude = 1.2, roughness = 1, fadeIn = 0, fadeOut = 0.2 },
			damage = { magnitude = 6, roughness = 6, fadeIn = 0, fadeOut = 1 },
		},
	},
	effects = {
		defenceParticles = {
			"HIT",
			"STRIKES",
			"SingularRays",
			"SurroundingAura",
		},
		defenceVisuals = {
			show = { "Rope_Henry2" },
			hide = { "default_L", "hand", "ring", "Rope_Henry" },
		},
	},
}
return weaponConfig
