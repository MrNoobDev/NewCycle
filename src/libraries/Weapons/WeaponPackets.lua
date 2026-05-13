local replicatedStorage = game:GetService("ReplicatedStorage")

local byteNet = require(replicatedStorage:WaitForChild("Packages"):WaitForChild("bytenet"))

return byteNet.defineNamespace("weapons", function()
	return {
		assignWeapon = byteNet.definePacket({
			value = byteNet.struct({
				weaponId = byteNet.string,
			}),
			reliabilityType = "reliable",
		}),

		requestAttack = byteNet.definePacket({
			value = byteNet.struct({
				weaponId = byteNet.string,
				targetPosition = byteNet.vector3,
				swingIndex = byteNet.uint8,
			}),
			reliabilityType = "reliable",
		}),

		requestBlock = byteNet.definePacket({
			value = byteNet.struct({
				weaponId = byteNet.string,
				isActive = byteNet.bool,
			}),
			reliabilityType = "reliable",
		}),

		feedback = byteNet.definePacket({
			value = byteNet.struct({
				feedbackType = byteNet.string,
				weaponId = byteNet.string,
			}),
			reliabilityType = "reliable",
		}),
	}
end)
