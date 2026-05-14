--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService.NewCycle:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.NewCycle)

local serviceBag = require("ServiceBag").new()

serviceBag:GetService(require("AnimationDataService"))
serviceBag:GetService(require("NPCService"))
serviceBag:GetService(require("WeaponService"))
serviceBag:GetService(require("InteractableService"))
serviceBag:GetService(require("PlayerDataService"))
serviceBag:Init()
serviceBag:Start()
