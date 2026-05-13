--[=[
	Sends the animation catalog to clients on request.

	@class AnimationDataService
	@author mrnoob
]=]

local require = require(script.Parent.loader).load(script)

local AnimationData = require("AnimationData")
local AnimationPackets = require("AnimationPackets")
local Maid = require("Maid")

local AnimationDataService = {}
AnimationDataService.ServiceName = "AnimationDataService"

function AnimationDataService:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
end

function AnimationDataService:Start()
	AnimationPackets.request.listen(function(_data, player)
		AnimationPackets.send.sendTo({ data = AnimationData }, player)
	end)
end

function AnimationDataService:GetData()
	return AnimationData
end

function AnimationDataService:Destroy()
	self._maid:DoCleaning()
end

return AnimationDataService
