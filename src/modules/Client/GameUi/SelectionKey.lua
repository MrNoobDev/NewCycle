local selectionKey = {}
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

function selectionKey:setupSelectionKey(plrUI, key, action)
	local check = pcall(function()
		if plrUI["keyBND"] then
			plrUI["keyBND"]:Destroy()
		end
	end)
	if check then
		print("found deleting")
	end
	local keyBND = create("ScreenGui")({
		Name = "keyBND",
		Parent = plrUI,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local SelectionKey = create("Frame")({
		Name = "SelectionKey",
		Parent = keyBND,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1.000,
		Position = UDim2.new(0.5, 0, 0.756, 0),
		Size = UDim2.new(0.078, 0, 0.139, 0),
	})

	local Image = create("ImageLabel")({
		Name = "Image",
		Parent = SelectionKey,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1.000,
		Size = UDim2.new(1, 0, 1, 0),
		Image = "rbxassetid://14914416433",
		ImageRectOffset = Vector2.new(778, 718),
		ImageRectSize = Vector2.new(90, 90),
		ScaleType = Enum.ScaleType.Fit,
	})

	local Key = create("TextLabel")({
		Name = "Key",
		Parent = Image,
		AnchorPoint = Vector2.new(0.49000001, 0.280000001),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1.000,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0.49000001, 0, 0.280000001, 0),
		Size = UDim2.new(0.25, 0, 0.25, 0),
		FontFace = Font.new(
			"rbxasset://fonts/families/JosefinSans.json",
			Enum.FontWeight.Medium,
			Enum.FontStyle.Normal
		),
		Text = key,
		TextColor3 = Color3.fromRGB(181, 154, 91),
		TextScaled = true,
		TextSize = 14.000,
		TextWrapped = true,
	})

	local Type = create("TextLabel")({
		Name = "Type",
		Parent = SelectionKey,
		AnchorPoint = Vector2.new(0.49000001, 0.675000012),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1.000,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0.454443365, 0, 0.75, 0),
		Size = UDim2.new(0.926999986, 0, 0.200000003, 0),
		FontFace = Font.new(
			"rbxasset://fonts/families/JosefinSans.json",
			Enum.FontWeight.Medium,
			Enum.FontStyle.Normal
		),
		Text = action,
		TextColor3 = Color3.fromRGB(181, 154, 91),
		TextScaled = true,
		TextSize = 14.000,
		TextWrapped = true,
	})
end

function selectionKey:changeCurrentSelection(plrUI, key, action)
	local check = pcall(function()
		if plrUI["keyBND"] then
			local userInputService = game:GetService("UserInputService")
			if userInputService.TouchEnabled then
				plrUI["keyBND"].Enabled = true
				plrUI["keyBND"].SelectionKey.Image.Key.Text = "Tap"
				plrUI["keyBND"].SelectionKey.Type.Text = action
			elseif userInputService.GamepadEnabled then
				plrUI["keyBND"].Enabled = true
				plrUI["keyBND"].SelectionKey.Image.Key.Text = "X"
				plrUI["keyBND"].SelectionKey.Type.Text = action
			elseif userInputService.KeyboardEnabled then
				plrUI["keyBND"].Enabled = true
				plrUI["keyBND"].SelectionKey.Image.Key.Text = key
				plrUI["keyBND"].SelectionKey.Type.Text = action
			end
		end
	end)
end

function selectionKey:hideSelect(plrUI)
	local check = pcall(function()
		if plrUI["keyBND"] then
			plrUI["keyBND"].Enabled = false
		end
	end)
end

return selectionKey
