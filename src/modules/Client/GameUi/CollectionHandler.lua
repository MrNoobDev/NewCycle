--[=[
	Stacked collection notifications. If you collect the same item again while
	its frame is still on screen the count animates up instead of a new frame.

	@author mrnoob
]=]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utilities = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Utilities"))

local collectionHandler = {}

local FRAME_WIDTH = 0.18
local FRAME_HEIGHT = 0.035
local FRAME_GAP = 0.008
local TOP_Y = 0.08
local END_X = 1.0  -- right-anchored: right edge of frame sits flush with right edge of screen
local START_X = 1.5 -- starts offscreen to the right
local EXIT_DELAY = 3
local FADE_TIME = 0.25

local function create(instanceType)
	return function(data)
		local obj = Instance.new(instanceType)
		for k, v in pairs(data) do
			if type(k) == "number" then
				v.Parent = obj
			elseif type(v) == "function" then
				obj[k]:Connect(v)
			else
				obj[k] = v
			end
		end
		return obj
	end
end

-- Explicit ordered list of on-screen frames (top to bottom)
local order: { any } = {}
-- Quick lookup by item name for stack-counting
local byName: { [string]: any } = {}

local function yFor(index: number): number
	return TOP_Y + (index - 1) * (FRAME_HEIGHT + FRAME_GAP)
end

local function reflow()
	for i, state in order do
		local targetY = yFor(i)
		if state.targetY ~= targetY then
			state.targetY = targetY
			Utilities.pTween(state.frame, "Position", UDim2.new(END_X, 0, targetY, 0), 0.2, "linear")
		end
	end
end

local function tweenCount(label: TextLabel, from: number, to: number, prefix: string?)
	local pre = prefix or "x "
	task.spawn(function()
		Utilities.Tween(0.35, "easeOutQuad", function(a)
			if not label.Parent then
				return false
			end
			label.Text = pre .. tostring(math.floor(from + (to - from) * a + 0.5))
		end)
		if label.Parent then
			label.Text = pre .. tostring(to)
		end
	end)
end

function collectionHandler:setupCollections(playerUI)
	local existing = playerUI:FindFirstChild("collectionHandler")
	if existing then
		existing:Destroy()
	end
	order = {}
	byName = {}

	local gui = create("ScreenGui")({
		Name = "collectionHandler",
		Parent = playerUI,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	create("Frame")({
		Name = "collectionHolder",
		Parent = gui,
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
	})
end

local function buildFrame(parent: Instance, text: string, hasIcon: boolean, hasAmount: boolean, icon: string, amount: number, targetY: number, prefix: string?)
	local fadeInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear)

	local frame = create("Frame")({
		Name = "CollectedUI",
		Parent = parent,
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(FRAME_WIDTH, 0, FRAME_HEIGHT, 0),
		Position = UDim2.new(START_X, 0, targetY, 0),
	})

	create("UIGradient")({
		Parent = frame,
		Color = ColorSequence.new(Color3.fromRGB(110, 110, 110)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
	})

	create("UICorner")({
		Parent = frame,
		CornerRadius = UDim.new(0, 6),
	})

	local pickedUp = create("TextLabel")({
		Name = "pickedUp",
		Parent = frame,
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.08, 0, 0.5, 0),
		Size = UDim2.new(0.55, 0, 0.75, 0),
		Font = Enum.Font.JosefinSans,
		Text = text,
		TextColor3 = Color3.fromRGB(207, 166, 100),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		TextWrapped = true,
		TextTransparency = 1,
	})
	TweenService:Create(pickedUp, fadeInfo, { TextTransparency = 0 }):Play()

	local multipleLabel: TextLabel? = nil
	if hasIcon then
		local label = create("ImageLabel")({
			Name = "label",
			Parent = frame,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.72, 0, 0.5, 0),
			Size = UDim2.new(0.09, 0, 0.85, 0),
			Image = icon,
			ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
		})
		TweenService:Create(label, fadeInfo, { ImageTransparency = 0 }):Play()
	end

	if hasAmount then
		multipleLabel = create("TextLabel")({
			Name = "multiple",
			Parent = frame,
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.95, 0, 0.5, 0),
			Size = UDim2.new(0.16, 0, 0.6, 0),
			Font = Enum.Font.JosefinSans,
			Text = (prefix or "x ") .. tostring(amount),
			TextColor3 = Color3.fromRGB(207, 166, 100),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextScaled = true,
			TextWrapped = true,
			TextTransparency = 1,
		})
		TweenService:Create(multipleLabel, fadeInfo, { TextTransparency = 0 }):Play()
	end

	TweenService:Create(frame, fadeInfo, { Position = UDim2.new(END_X, 0, targetY, 0) }):Play()

	return frame, pickedUp, multipleLabel
end

function collectionHandler:createNewCollection(itemName: string, hasIcon: boolean, hasAmount: boolean, amount: number, icon: string, playerUI: Instance, isEat: boolean)
	local parent = playerUI:FindFirstChild("collectionHandler")
	parent = parent and parent:FindFirstChild("collectionHolder")
	if not parent then
		return
	end

	local stackKey = "get:" .. itemName
	local existing = byName[stackKey]
	if existing and existing.frame.Parent then
		if existing.multipleLabel then
			local oldAmount = existing.amount
			local newAmount = oldAmount + amount
			existing.amount = newAmount
			tweenCount(existing.multipleLabel, oldAmount, newAmount, existing.prefix)
		end
		existing.tokenId = (existing.tokenId or 0) + 1
		local myToken = existing.tokenId
		task.delay(EXIT_DELAY, function()
			if existing.tokenId == myToken then
				collectionHandler:_retireFrame(existing)
			end
		end)
		return
	end

	local text
	if isEat then
		text = "Eat " .. itemName
	elseif hasAmount then
		text = "Collected " .. itemName
	else
		text = "Picked up a " .. itemName
	end

	local targetY = yFor(#order + 1)
	local frame, pickedUp, multipleLabel = buildFrame(parent, text, hasIcon, hasAmount, icon or "", amount, targetY, "x ")

	local state = {
		itemName = stackKey,
		prefix = "x ",
		frame = frame,
		pickedUp = pickedUp,
		multipleLabel = multipleLabel,
		amount = amount,
		targetY = targetY,
		tokenId = 1,
	}
	table.insert(order, state)
	byName[stackKey] = state

	local myToken = state.tokenId
	task.delay(EXIT_DELAY, function()
		if state.tokenId == myToken then
			collectionHandler:_retireFrame(state)
		end
	end)
end

function collectionHandler:createSpendNotification(itemName: string, amount: number, playerUI: Instance, icon: string?)
	local parent = playerUI:FindFirstChild("collectionHandler")
	parent = parent and parent:FindFirstChild("collectionHolder")
	if not parent then
		return
	end

	local stackKey = "spend:" .. itemName
	local existing = byName[stackKey]
	if existing and existing.frame.Parent then
		if existing.multipleLabel then
			local oldAmount = existing.amount
			local newAmount = oldAmount + amount
			existing.amount = newAmount
			tweenCount(existing.multipleLabel, oldAmount, newAmount, existing.prefix)
		end
		existing.tokenId = (existing.tokenId or 0) + 1
		local myToken = existing.tokenId
		task.delay(EXIT_DELAY, function()
			if existing.tokenId == myToken then
				collectionHandler:_retireFrame(existing)
			end
		end)
		return
	end

	local hasIcon = icon ~= nil and icon ~= ""
	local text = "Spent " .. itemName
	local targetY = yFor(#order + 1)
	local frame, pickedUp, multipleLabel = buildFrame(parent, text, hasIcon, true, icon or "", amount, targetY, "- ")

	local state = {
		itemName = stackKey,
		prefix = "- ",
		frame = frame,
		pickedUp = pickedUp,
		multipleLabel = multipleLabel,
		amount = amount,
		targetY = targetY,
		tokenId = 1,
	}
	table.insert(order, state)
	byName[stackKey] = state

	local myToken = state.tokenId
	task.delay(EXIT_DELAY, function()
		if state.tokenId == myToken then
			collectionHandler:_retireFrame(state)
		end
	end)
end

function collectionHandler:_retireFrame(state)
	if byName[state.itemName] == state then
		byName[state.itemName] = nil
	end
	for i, s in order do
		if s == state then
			table.remove(order, i)
			break
		end
	end

	local fadeInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear)
	if state.frame.Parent then
		TweenService:Create(state.frame, fadeInfo, { Position = UDim2.new(START_X, 0, state.targetY, 0) }):Play()
		TweenService:Create(state.pickedUp, fadeInfo, { TextTransparency = 1 }):Play()
	end
	reflow()
	task.delay(FADE_TIME, function()
		if state.frame and state.frame.Parent then
			state.frame:Destroy()
		end
	end)
end

return collectionHandler
