-- player config
--//

return {
	movement = {
		walkSpeed = 8,
		runSpeed = 12,
		backwardWalkSpeed = 5,
		crouchSpeed = 4,
		standHipHeight = 2,
		crouchHipHeight = 0.5,
		jumpPower = 50,
		jumpCooldown = 0.5,
		hipTweenDuration = 0.25,
	},

	camera = {
		normalFov = 80,
		runFov = 90,
		fovLerp = 4,
		bobbingSpeedWalk = 10,
		bobbingSpeedRun = 12,
		bobbingAmountWalk = 0.15,
		bobbingAmountRun = 0.18,
		bobbingHorizontalWalk = 0,
		bobbingHorizontalRun = 0,
		bobbingDepthWalk = 0.05,
		bobbingDepthRun = 0.065,
		swayAmountWalk = 0.15,
		swayAmountRun = 0.2,
		swaySpeed = 1,
		landSpring = 15,
		landDamping = 0.85,
		landBounceMin = -0.4,
		landBounceMax = 0.2,
	},

	sounds = {
		crouchVolume = 0.5,
		crouchPath = { "Player", "Crouch" },
		crouch = {
			"sfx_audrey_foley_crouch_01",
			"sfx_audrey_foley_crouch_02",
			"sfx_audrey_foley_crouch_03",
			"sfx_audrey_foley_crouch_04",
			"sfx_audrey_foley_crouch_05",
		},
		footstepVolume = {
			walk = 0.55,
			run = 0.8,
			crouch = 0.32,
		},
		footstepDistance = {
			walk = 2.45,
			run = 1.9,
			crouch = 3.1,
		},
		muteCharacterSounds = true,
		soundBlacklist = {
			"Running",
			"Walking",
			"Jumping",
			"Climbing",
			"FreeFalling",
			"Landing",
			"Swimming",
			"Died",
		},
	},
}
