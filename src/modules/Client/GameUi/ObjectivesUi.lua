local OBJHandler = {}

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local char = plr.Character
local plrUI = plr.PlayerGui
local utilities = require(game.ReplicatedStorage.gameModules.gameUtilities)
local create = utilities.Create
local replicatedStorage = game:GetService("ReplicatedStorage")
local Menu = require(replicatedStorage.gameModules.gameUI.Menu)

function OBJHandler:setupOBJGui()
	local ObjectiveUI = create("ScreenGui")({
		Name = "ObjectiveUI",
		Parent = plrUI,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local mFRME = create("Frame")({
		Name = "mFRME",
		Parent = ObjectiveUI,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1.000,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0.37, 0, -1, 0),
		Size = UDim2.new(0.26, 0, 0.139, 0),
		SizeConstraint = Enum.SizeConstraint.RelativeXY,
	})

	local ObjectiveUI_2 = create("ImageLabel")({
		Name = "ObjectiveUI",
		Parent = mFRME,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1.000,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0.181876666667, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Image = "rbxassetid://14167297362",
		ScaleType = Enum.ScaleType.Fit,
	})

	local NEWOBJ = create("TextLabel")({
		Name = "NEWOBJ",
		Parent = mFRME,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1.000,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0.2, 0),
		Size = UDim2.new(0.6, 0, 0.2, 0),
		FontFace = Font.new("rbxasset://fonts/families/JosefinSans.json", Enum.FontWeight.Light, Enum.FontStyle.Normal),

		Text = "NEW OBJECTIVE",
		TextColor3 = Color3.fromRGB(0, 0, 0),
		TextSize = 20.000,
		TextScaled = true,
		TextWrapped = true,
	})

	local NewObjConst = create("UITextSizeConstraint")({
		Name = "UITextSizeConstraint",
		Parent = NEWOBJ,
		MaxTextSize = 30,
		MinTextSize = 1,
	})
	local OBJTEXT = create("TextLabel")({
		Name = "OBJTEXT",
		Parent = mFRME,
		AnchorPoint = Vector2.new(0.5, 0.75),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1.000,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0.499748409, 0, 0.79405874, 0),
		Size = UDim2.new(1.096, 0, 0.273, 0),
		FontFace = Font.new(
			"rbxasset://fonts/families/JosefinSans.json",
			Enum.FontWeight.Medium,
			Enum.FontStyle.Normal
		),
		Text = "INSERT TEXT HERE",
		TextColor3 = Color3.fromRGB(248, 207, 145),
		TextScaled = true,
	})

	local NewObjConst = create("UITextSizeConstraint")({
		Name = "UITextSizeConstraint",
		Parent = OBJTEXT,
		MaxTextSize = 40,
		MinTextSize = 1,
	})
end

function OBJHandler:doObjective(objective: string, Otype: string, oInfo: string)
	local types = {
		["new"] = "NEW OBJECTIVE",
		["upd"] = "OBJECTIVE UPDATED",
	}

	local mainF = plrUI["ObjectiveUI"].mFRME
	if Otype == "new" then
		Menu:updateObjectivesUI(objective, oInfo)
	else
		Menu:updateSpecificObjective(objective, oInfo)
	end

	game.ReplicatedStorage.audios.sfx.objectiveSoundFX:Play()
	mainF["OBJTEXT"].Text = objective
	mainF["NEWOBJ"].Text = types[Otype] or "NEW OBJECTIVE"
	utilities.pTween(mainF, "Position", UDim2.new(0.37, 0, 0.025, 0), 0.1, "easeOutSine")
	task.wait(3)
	utilities.pTween(mainF, "Position", UDim2.new(0.37, 0, -0.35, 0), 0.1, "easeOutSine")
end

return OBJHandler
