--[=[
	ByteNet packets for animation data sync.

	@class AnimationPackets
	@author mrnoob
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("bytenet"))

return ByteNet.defineNamespace("animationData", function()
	return {
		-- Client → server
		request = ByteNet.definePacket({
			value = ByteNet.struct({
				_ = ByteNet.bool,
			}),
			reliabilityType = "reliable",
		}),

		-- Server → client
		send = ByteNet.definePacket({
			value = ByteNet.struct({
				data = ByteNet.unknown,
			}),
			reliabilityType = "reliable",
		}),
	}
end)
