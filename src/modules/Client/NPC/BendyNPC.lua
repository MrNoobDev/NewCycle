--[=[
	Bendy — peaceful companion NPC. Follows waypoints by default,
	can switch to follow-player mode. Supports clean destroy and respawn.

	@class BendyNPC
	@author mrnoob
]=]

local PeacefulNPC = require(script.Parent.PeacefulNPC)

--\ Module \--
local BendyNPC = setmetatable({}, { __index = PeacefulNPC })
BendyNPC.__index = BendyNPC

--\ Lifecycle \--

function BendyNPC.new(instance: Model, config: { [string]: any }, animData: { [string]: string }?)
	local self = PeacefulNPC.new(instance, config)
	if not self then
		return nil
	end
	setmetatable(self, BendyNPC)

	local anims = animData or {}
	if anims.Idle or anims.Walk then
		self:SetupAnimator(anims)
	end

	return self
end

function BendyNPC:Init()
	if self._destroyed then
		return
	end

	self:SetMode("FollowPlayer")

	PeacefulNPC.Init(self)
end

--\ Cleanup \--

function BendyNPC:Destroy()
	PeacefulNPC.Destroy(self)
end

return BendyNPC
