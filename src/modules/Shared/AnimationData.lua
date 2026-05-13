--[=[
	Animation catalog. Add categories and IDs here.

	@class AnimationData
	@author mrnoob
]=]

return {
	Player = {
		-- Played when the local player takes damage (random pick).
		Hit = {
			"rbxassetid://98263475781276",
			"rbxassetid://87659306937441",
		},
		Climb = "rbxassetid://99598905992792",
		Ladder = {
			Start = "rbxassetid://129251989847985",
			Loop = "rbxassetid://95154235021027",
			End = "rbxassetid://85779553873762",
		},
		Inker = {
			In = "rbxassetid://134373899091402",
			Out = "rbxassetid://102099065883898",
		},
	},

	Enemies = {
		LostOne = {
			Idle = "rbxassetid://104316237300846",
			Walk = "rbxassetid://124635458038369",
			Run = "rbxassetid://87731923969966",
			Leap = "",
			Death = "rbxassetid://70391988116400",
			Attacks = {
				"rbxassetid://90890824353762",
				"rbxassetid://133320982363260",
				"rbxassetid://117572378841513",
			},
			Hit = {
				"rbxassetid://98263475781276",
				"rbxassetid://87659306937441",
			},
		},
	},

	Peaceful = {
		Bendy = {
			Idle = "rbxassetid://107613567841688",

			Walk = "rbxassetid://138390274887621",
		},
	},
}
