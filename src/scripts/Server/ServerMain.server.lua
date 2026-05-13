--[[
	@class ServerMain
]]
local ServerScriptService = game:GetService("ServerScriptService")

local loader = ServerScriptService.NewCycle:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapGame(ServerScriptService.NewCycle)

local serviceBag = require("ServiceBag").new()

serviceBag:Init()
serviceBag:Start()
