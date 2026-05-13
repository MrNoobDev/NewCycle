--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("TheBendyGame"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()
serviceBag:GetService(require("InputManagerService"))

serviceBag:GetService(require("InteractableServiceClient"))
serviceBag:GetService(require("NPCServiceClient"))
serviceBag:Init()
serviceBag:Start()
