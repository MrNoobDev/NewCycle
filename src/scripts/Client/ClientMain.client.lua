--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("NewCycle"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()

serviceBag:GetService(require("NPCServiceClient"))
serviceBag:GetService(require("PlayerServiceClient"))
serviceBag:GetService(require("WeaponServiceClient"))
serviceBag:GetService(require("InteractableServiceClient"))
serviceBag:GetService(require("PlayerDataServiceClient"))
serviceBag:Init()
serviceBag:Start()
