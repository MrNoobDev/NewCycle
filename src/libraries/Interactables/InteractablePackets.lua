local replicatedStorage = game:GetService("ReplicatedStorage")

local byteNet = require(replicatedStorage:WaitForChild("Packages"):WaitForChild("bytenet"))

return byteNet.defineNamespace("Interactables", function()
	return {
		requestInteract = byteNet.definePacket({
			value = byteNet.struct({
				target = byteNet.inst,
			}),
			reliabilityType = "reliable",
		}),

		playVisual = byteNet.definePacket({
			value = byteNet.struct({
				target = byteNet.inst,
				visualType = byteNet.string,
			}),
			reliabilityType = "reliable",
		}),
	}
end)
