-- PlayerConfig.lua
--//

return {
	movement = {
		walkSpeed = 8,
		blockSpeed = 4,
		runSpeed = 12,
		backwardWalkSpeed = 5,
		crouchSpeed = 4,
		standHipHeight = 2,
		crouchHipHeight = 0.5,
		jumpPower = 25,
		jumpCooldown = 0.5,
		hipTweenDuration = 0.25,
	},

	camera = {
		normalFov = 80,
		runFov = 87,
		crouchFov = 73, -- zoom in when crouching
		fovLerp = 7, -- smooth FOV transition speed

		-- bob (overridden per-state inside CameraController constants,
		-- but kept here so future callers can read them)
		bobbingSpeedWalk = 4.2,
		bobbingSpeedRun = 6.0,
		bobbingAmountWalk = 0.055,
		bobbingAmountRun = 0.095,
		bobbingHorizontalWalk = 0.022,
		bobbingHorizontalRun = 0.038,
		bobbingDepthWalk = 0,
		bobbingDepthRun = 0,

		-- land spring
		landSpring = 20,
		landDamping = 0.70,
		landBounceMin = -0.50,
		landBounceMax = 0.16,
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
			run = 0.80,
			crouch = 0.32,
		},
		footstepDistance = {
			walk = 2.45,
			run = 1.90,
			crouch = 3.10,
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
