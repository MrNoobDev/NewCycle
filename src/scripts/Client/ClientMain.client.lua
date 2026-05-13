--[[
	@class ClientMain
]]
local loader = game:GetService("ReplicatedStorage"):WaitForChild("NewCycle"):WaitForChild("loader")
local require = require(loader).bootstrapGame(loader.Parent)

local serviceBag = require("ServiceBag").new()

serviceBag:GetService(require("NPCServiceClient"))
serviceBag:Init()
serviceBag:Start()
