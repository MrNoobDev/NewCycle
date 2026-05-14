local interactableConfig = {}

interactableConfig.Tag = "obj_Interactable"
interactableConfig.AttributeId = "InteractableId"

interactableConfig.ActivationKey = Enum.KeyCode.E
interactableConfig.GamepadActivationKey = Enum.KeyCode.ButtonX

interactableConfig.UpdateRate = 20
interactableConfig.RaycastDistance = 100
interactableConfig.MaxDistance = 14
interactableConfig.ActivationCooldown = 0.25
interactableConfig.ServerDistanceForgiveness = 3

interactableConfig.HighlightProps = {
	FillColor = Color3.fromRGB(255, 222, 89),
	OutlineColor = Color3.fromRGB(255, 222, 89),
	FillTransparency = 1,
	OutlineTransparency = 0,
	DepthMode = Enum.HighlightDepthMode.Occluded,
}

interactableConfig.HoverSoundId = nil
interactableConfig.HoverSoundVolume = 0.4

return interactableConfig
