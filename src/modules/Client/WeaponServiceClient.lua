local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")

local weaponPackets = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponPackets"))
local weaponRegistry = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponRegistry"))
local weaponUtil = require(ReplicatedStorage:WaitForChild("ClientLibraries"):WaitForChild("Weapons"):WaitForChild("WeaponUtil"))

local weaponController = require(script.Parent.Weapons.WeaponController)

local weaponServiceClient = {}
weaponServiceClient.ServiceName = "WeaponServiceClient"

function weaponServiceClient:Init(serviceBag)
	self.serviceBag = assert(serviceBag, "No serviceBag")
	self.maid = Maid.new()
	self.player = Players.LocalPlayer
	self.character = self.player.Character or self.player.CharacterAdded:Wait()
	self.weaponControllers = {}
	self.equippedWeaponId = nil
	self.platformType = self:_getPlatformType()
end

function weaponServiceClient:Start()
	self.maid:GiveTask(self.player.CharacterAdded:Connect(function(character)
		self.character = character
		for _, controller in pairs(self.weaponControllers) do
			controller:setCharacter(character)
		end
		self:_refreshMobileUi()
	end))

	self.maid:GiveTask(RunService.RenderStepped:Connect(function(deltaTime)
		local controller = self:_getEquippedController()
		if controller then
			controller:update(deltaTime)
		end
	end))

	self.maid:GiveTask(UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		if gameProcessed then
			return
		end
		self:_handleInputBegan(inputObject)
	end))

	self.maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject)
		self:_handleInputEnded(inputObject)
	end))

	weaponPackets.assignWeapon.listen(function(data)
		self:_assignWeapon(data.weaponId)
	end)

	weaponPackets.feedback.listen(function(data)
		local controller = self.weaponControllers[data.weaponId]
		if controller then
			controller:handleFeedback(data.feedbackType)
		end
	end)

	self:_refreshMobileUi()
end

function weaponServiceClient:_assignWeapon(weaponId)
	if weaponId == "" then
		return
	end

	if self.weaponControllers[weaponId] then
		self.equippedWeaponId = weaponId
		return
	end

	local config = weaponRegistry.getWeaponConfig(weaponId)
	if not config then
		return
	end

	local controller = weaponController.new(self.player, config)
	controller:setCharacter(self.character)
	self.weaponControllers[weaponId] = controller
	self.equippedWeaponId = weaponId
end

function weaponServiceClient:_getEquippedController()
	if not self.equippedWeaponId then
		return nil
	end

	return self.weaponControllers[self.equippedWeaponId]
end

function weaponServiceClient:_handleInputBegan(inputObject)
	local controller = self:_getEquippedController()
	if not controller then
		return
	end

	if self.platformType == "PC" then
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			controller:attack(self:_getTargetPosition(controller))
		elseif inputObject.UserInputType == Enum.UserInputType.MouseButton2 then
			controller:startBlock()
		end
	elseif self.platformType == "Console" then
		if inputObject.KeyCode == Enum.KeyCode.ButtonR2 then
			controller:attack(self:_getTargetPosition(controller))
		elseif inputObject.KeyCode == Enum.KeyCode.ButtonL2 then
			controller:startBlock()
		end
	end
end

function weaponServiceClient:_handleInputEnded(inputObject)
	local controller = self:_getEquippedController()
	if not controller then
		return
	end

	if self.platformType == "PC" and inputObject.UserInputType == Enum.UserInputType.MouseButton2 then
		controller:stopBlock()
	elseif self.platformType == "Console" and inputObject.KeyCode == Enum.KeyCode.ButtonL2 then
		controller:stopBlock()
	end
end

function weaponServiceClient:_refreshMobileUi()
	local playerGui = self.player:FindFirstChildOfClass("PlayerGui")
	local gameplay = playerGui and playerGui:FindFirstChild("Gameplay")
	local interfaceMobile = gameplay and gameplay:FindFirstChild("InterfaceMobile")
	if not interfaceMobile then
		return
	end

	interfaceMobile.Enabled = self.platformType == "Mobile"
	if self.platformType ~= "Mobile" then
		return
	end

	local buttons = interfaceMobile:FindFirstChild("Content") and interfaceMobile.Content:FindFirstChild("Buttons")
	if not buttons then
		return
	end

	local axeButton = buttons:FindFirstChild("Axe_Button")
	local hitButton = axeButton and axeButton:FindFirstChild("HitButton")
	if hitButton and not hitButton:GetAttribute("weaponBound") then
		hitButton:SetAttribute("weaponBound", true)
		self.maid:GiveTask(hitButton.MouseButton1Down:Connect(function()
			local controller = self:_getEquippedController()
			if controller then
				controller:attack(self:_getTargetPosition(controller))
			end
		end))
	end

	local defenceButton = buttons:FindFirstChild("Defence_Button")
	local defenceInput = defenceButton and defenceButton:FindFirstChild("DefenceButton")
	if defenceInput and not defenceInput:GetAttribute("weaponBound") then
		defenceInput:SetAttribute("weaponBound", true)
		self.maid:GiveTask(defenceInput.MouseButton1Down:Connect(function()
			local controller = self:_getEquippedController()
			if controller then
				controller:startBlock()
			end
		end))
		self.maid:GiveTask(defenceInput.MouseButton1Up:Connect(function()
			local controller = self:_getEquippedController()
			if controller then
				controller:stopBlock()
			end
		end))
	end
end

function weaponServiceClient:_getTargetPosition(controller)
	local mouse = self.player:GetMouse()
	if self.platformType == "Mobile" then
		return weaponUtil.getTargetPosition(self.player, controller.viewmodelController.viewmodel)
	end

	return mouse.Hit.Position
end

function weaponServiceClient:_getPlatformType()
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return "Mobile"
	end

	if UserInputService.GamepadEnabled and not UserInputService.MouseEnabled and not UserInputService.KeyboardEnabled then
		return "Console"
	end

	return "PC"
end

function weaponServiceClient:Destroy()
	for _, controller in pairs(self.weaponControllers) do
		controller:destroy()
	end

	table.clear(self.weaponControllers)
	self.maid:DoCleaning()
end

return weaponServiceClient
