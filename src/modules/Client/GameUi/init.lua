local gameUI = {}
local tweenService = game:GetService("TweenService")
local respawnHandles = require(game.ReplicatedStorage.gameModules.respHandles)
local utilities = require(game.ReplicatedStorage.gameModules.gameUtilities)
local function create(instanceType)
	return function(data)
		local obj = Instance.new(instanceType)
		for k, v in pairs(data) do
			local s, e = pcall(function()
				if type(k) == "number" then
					v.Parent = obj
				elseif type(v) == "function" then
					obj[k]:connect(v)
				else
					obj[k] = v
				end
			end)
			if not s then
				error("Create: could not set property " .. k .. " of " .. instanceType .. " (" .. e .. ")", 2)
			end
		end
		return obj
	end
end

function gameUI:makeFaderGui(playerGui)
	local faderUI = create("ScreenGui") {
		Name = "faderUI",
		Parent = playerGui,
	}
	local fader = create("Frame") {
		Name = "Fader",
		Parent = faderUI,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 100,
	}
end

function gameUI:makeAbilityUI(playerGui)
	local imageContainer = create("ScreenGui")({
		Name = "imageContainer",
		Parent = playerGui,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local ImageLabel = create("ImageLabel")({
		Parent = imageContainer,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1.000,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(2.5, 0, 2.5, 0),
		Image = "rbxassetid://14951585339",
		ImageColor3 = Color3.fromRGB(255, 186, 67),
		ImageTransparency = 0.350,
	})
end

function gameUI:abilityUIIn(playerGui)
	tweenService
		:Create(
			playerGui["imageContainer"].ImageLabel,
			TweenInfo.new(0.35, Enum.EasingStyle.Linear),
			{ Size = UDim2.new(1.25, 0, 1.25, 0) }
		)
		:Play()
end

function gameUI:abilityUIOUT(playerGui)
	tweenService
		:Create(
			playerGui["imageContainer"].ImageLabel,
			TweenInfo.new(0.35, Enum.EasingStyle.Linear),
			{ Size = UDim2.new(2.5, 0, 2.5, 0) }
		)
		:Play()
end

local function typingTEXT(text: string, textSpeed: number, color: Color3, label)
	label.TextColor3 = color
	label.MaxVisibleGraphemes = 0
	label.Text = text

	wait(0.55)
	repeat
		label.MaxVisibleGraphemes += 1

		wait(textSpeed)
	until label.MaxVisibleGraphemes == utf8.len(label.ContentText)
end
local function untypingTEXT(textSpeed: number, color: Color3, label)
	label.TextColor3 = color

	wait(0.2)
	repeat
		label.MaxVisibleGraphemes = label.MaxVisibleGraphemes - 1

		wait(textSpeed)
	until label.MaxVisibleGraphemes == 0
end

function gameUI:doDeathScreen(playerUI)
	local music = game.ReplicatedStorage.audios.music.mus_gameOver
	music:Play()
	local deathUI = utilities.Create("ScreenGui")({
		Name = "deathUI",
		Parent = playerUI,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
	})

	local deathMain = utilities.Create("Frame")({
		Name = "deathMain",
		Parent = deathUI,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
	})

	local background = utilities.Create("ImageLabel")({
		Name = "background",
		Parent = deathMain,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Image = "rbxassetid://18657286779",
		ScaleType = Enum.ScaleType.Fit,
		ImageTransparency = 1,
	})

	local Cons = utilities.Create("ImageLabel")({
		Name = "Cons",
		Parent = background,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0.326, 0, 0.329, 0),
		Size = UDim2.new(0.347, 0, 0.210, 0),
		ZIndex = 2,
		Image = "rbxassetid://18657420586",
		ScaleType = Enum.ScaleType.Fit,
		ImageTransparency = 1,
	})

	local death = utilities.Create("ImageLabel")({
		Name = "death",
		Parent = background,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0.326, 0, 0.474, 0),
		Size = UDim2.new(0.347, 0, 0.109, 0),
		ZIndex = 2,
		Image = "rbxassetid://18657427555",
		ScaleType = Enum.ScaleType.Fit,
		ImageTransparency = 1,
	})

	local BACKTOLOB = utilities.Create("TextButton")({
		Name = "BACKTOLOB",
		Parent = background,
		Active = false,

		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0.399, 0, 0.691, 0),
		Selectable = true,
		Size = UDim2.new(0.202, 0, 0.039, 0),
		ZIndex = 2,
		Font = Enum.Font.Unknown,
		Text = "BACK TO LOBBY",
		TextColor3 = Color3.fromRGB(77, 118, 149),
		TextScaled = true,
		TextSize = 14,
		TextTransparency = 1,
		TextWrapped = true,
	})

	local RESPN = utilities.Create("TextButton")({
		Name = "RESPN",
		Parent = background,
		Active = false,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0.399, 0, 0.638, 0),
		Selectable = true,
		Size = UDim2.new(0.202, 0, 0.039, 0),
		ZIndex = 2,
		Font = Enum.Font.Unknown,
		Text = "RESPAWN",
		TextColor3 = Color3.fromRGB(77, 118, 149),
		TextScaled = true,
		TextSize = 14,
		TextTransparency = 1,
		TextWrapped = true,
	})
	utilities.Sync {
		function()
			utilities.pTween(background, "ImageTransparency", 0, 2, "linear")
		end,
		function()
			utilities.pTween(Cons, "ImageTransparency", 0, 2, "linear")
		end,
		function()
			utilities.pTween(death, "ImageTransparency", 0, 2, "linear")
		end,
	}
	task.wait(4)
	utilities.Sync {
		function()
			utilities.pTween(RESPN, "TextTransparency", 0, 1, "linear")
		end,
		function()
			utilities.pTween(BACKTOLOB, "TextTransparency", 0, 1, "linear")
		end,
	}
	RESPN.MouseButton1Click:Connect(function()
		local spawnCheckpoint = require(game.ReplicatedStorage.gameModules.ClientEventFlags):GetValue("SpawnCheckpoint")
		utilities.Sync {
			function()
				utilities.pTween(background, "ImageTransparency", 1, 2, "linear")
			end,
			function()
				utilities.pTween(Cons, "ImageTransparency", 1, 2, "linear")
			end,
			function()
				utilities.pTween(death, "ImageTransparency", 1, 2, "linear")
			end,
			function()
				utilities.pTween(RESPN, "TextTransparency", 1, 2, "linear")
			end,
			function()
				utilities.pTween(BACKTOLOB, "TextTransparency", 1, 2, "linear")
			end,
		}
		task.wait(0.65)
		utilities.pTween(music, "Volume", 0, 2, "linear")
		task.wait(0.35)
		respawnHandles:respawnFromPoint(spawnCheckpoint)

		deathUI:Destroy()
	end)
	BACKTOLOB.MouseButton1Click:Connect(function()
		print("BackToLobby")
	end)
end

function gameUI:fadeOut(dur, fader)
	utilities.pTween(fader, "BackgroundTransparency", 0, 0.15, "linear")
end
function gameUI:fadeIn(dur, fader)
	utilities.pTween(fader, "BackgroundTransparency", 1, 0.15, "linear")
end

function gameUI:instantFadeIn(fader)
	fader.BackgroundTransparency = 0
end
function gameUI:instantFadeOut(fader)
	fader.BackgroundTransparency = 1
end

return gameUI
