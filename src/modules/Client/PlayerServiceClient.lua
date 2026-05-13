-- player service client
--//

local require = require(script.Parent.loader).load(script)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Maid = require("Maid")

local cameraController = require(script.Parent.Player.CameraController)
local footstepController = require(script.Parent.Player.FootstepController)
local playerConfig = require(script.Parent.Player.PlayerConfig)
local playerStateController = require(script.Parent.Player.PlayerStateController)

local playerServiceClient = {}
playerServiceClient.ServiceName = "PlayerServiceClient"

function playerServiceClient:Init(serviceBag)
	self.serviceBag = assert(serviceBag, "No serviceBag")
	self.maid = Maid.new()
	self.player = Players.LocalPlayer
	self.stateController = playerStateController.new(self.player, playerConfig)
	self.cameraController = cameraController.new(playerConfig)
	self.footstepController = footstepController.new(playerConfig)
	self.platformType = self:_getPlatformType()
end

function playerServiceClient:Start()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = playerConfig.camera.normalFov
	end

	self.maid:GiveTask(self.player.CharacterAdded:Connect(function(character)
		self:_bindCharacter(character)
	end))

	if self.player.Character then
		self:_bindCharacter(self.player.Character)
	end

	RunService:BindToRenderStep("PlayerSystemUpdate", Enum.RenderPriority.Camera.Value - 1, function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		self.stateController:update(camera.CFrame.LookVector)
		self.footstepController:update(dt, self.stateController)
		self.cameraController:update(dt, self.stateController)
	end)

	self.maid:GiveTask(function()
		RunService:UnbindFromRenderStep("PlayerSystemUpdate")
	end)

	ContextActionService:BindAction("PlayerSprint", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			self.stateController:setSprintRequested(true)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			self.stateController:setSprintRequested(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	ContextActionService:BindAction("PlayerCrouch", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			self.stateController:toggleCrouch()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)

	self.maid:GiveTask(function()
		ContextActionService:UnbindAction("PlayerSprint")
		ContextActionService:UnbindAction("PlayerCrouch")
	end)

	self:_refreshMobileUi()
end

function playerServiceClient:Destroy()
	self.cameraController:destroy()
	self.footstepController:destroy()
	self.stateController:destroy()
	self.maid:DoCleaning()
end

function playerServiceClient:_bindCharacter(character)
	self.stateController:setCharacter(character)
	self.cameraController:setCharacter(character)
	self.footstepController:setCharacter(character)
	self:_refreshMobileUi()
end

function playerServiceClient:_refreshMobileUi()
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

	for _, descendant in ipairs(buttons:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			local name = string.lower(descendant.Name)
			if string.find(name, "crouch") and not descendant:GetAttribute("playerCrouchBound") then
				descendant:SetAttribute("playerCrouchBound", true)
				self.maid:GiveTask(descendant.MouseButton1Down:Connect(function()
					self.stateController:toggleCrouch()
				end))
			elseif string.find(name, "sprint") and not descendant:GetAttribute("playerSprintBound") then
				descendant:SetAttribute("playerSprintBound", true)
				self.maid:GiveTask(descendant.MouseButton1Down:Connect(function()
					self.stateController:setSprintRequested(true)
				end))
				self.maid:GiveTask(descendant.MouseButton1Up:Connect(function()
					self.stateController:setSprintRequested(false)
				end))
			end
		end
	end
end

function playerServiceClient:_getPlatformType()
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return "Mobile"
	end
	if UserInputService.GamepadEnabled and not UserInputService.MouseEnabled and not UserInputService.KeyboardEnabled then
		return "Console"
	end
	return "PC"
end

return playerServiceClient
