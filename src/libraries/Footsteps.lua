local main = {}

local NewFootsteps = {
	"rbxassetid://86858840205905",
	"rbxassetid://79624159745078",
	"rbxassetid://138457161311284",
	"rbxassetid://96701361237195",
	"rbxassetid://82802722985788",
	"rbxassetid://127645110728783",
	"rbxassetid://139980979552745",
	"rbxassetid://89439974707389",
}

main.SoundIds = {
	Concrete = NewFootsteps,
	Dirt = NewFootsteps,
	Glass = NewFootsteps,
	Ground = NewFootsteps,
	Gravel = NewFootsteps,
	Metal_Chainlink = NewFootsteps,
	Metal_Grate = NewFootsteps,
	Metal_Solid = NewFootsteps,
	Mud = NewFootsteps,
	Rubber = NewFootsteps,
	Sand = NewFootsteps,
	Tile = NewFootsteps,
	Wood = NewFootsteps,
	Plastic = NewFootsteps,
	Snow = NewFootsteps,
}

main.MaterialMap = {

	[Enum.Material.Slate] = 		main.SoundIds.Concrete,
	[Enum.Material.Concrete] = 		main.SoundIds.Concrete,
	[Enum.Material.Brick] = 		main.SoundIds.Concrete,
	[Enum.Material.Cobblestone] = 	main.SoundIds.Concrete,
	[Enum.Material.Sandstone] =		main.SoundIds.Concrete,
	[Enum.Material.Rock] = 			main.SoundIds.Concrete,
	[Enum.Material.Basalt] = 		main.SoundIds.Concrete,
	[Enum.Material.CrackedLava] = 	main.SoundIds.Concrete,
	[Enum.Material.Asphalt] = 		main.SoundIds.Concrete,
	[Enum.Material.Limestone] = 	main.SoundIds.Concrete,
	[Enum.Material.Pavement] = 		main.SoundIds.Concrete,

	[Enum.Material.Plastic] = 		main.SoundIds.Tile,
	[Enum.Material.Marble] = 		main.SoundIds.Tile,
	[Enum.Material.Granite] = 		main.SoundIds.Tile,
	[Enum.Material.Neon] = 			main.SoundIds.Tile,

	[Enum.Material.Wood] = 			main.SoundIds.Wood,
	[Enum.Material.WoodPlanks] = 	main.SoundIds.Wood,

	[Enum.Material.DiamondPlate] = 	main.SoundIds.Metal_Solid,
	[Enum.Material.Metal] = 		main.SoundIds.Metal_Solid,

	[Enum.Material.CorrodedMetal] = main.SoundIds.Metal_Grate,

	[Enum.Material.Grass] = 		main.SoundIds.Dirt,
	[Enum.Material.Ground] = 		main.SoundIds.Dirt,
	[Enum.Material.LeafyGrass] = 	main.SoundIds.Dirt,

	[Enum.Material.Sand] = 			main.SoundIds.Sand,
	[Enum.Material.Fabric] = 		main.SoundIds.Sand,
	[Enum.Material.Salt] = 			main.SoundIds.Sand,

	[Enum.Material.Snow] = 			main.SoundIds.Snow,

	[Enum.Material.Ice] = 			main.SoundIds.Glass,
	[Enum.Material.Glacier] = 		main.SoundIds.Glass,
	[Enum.Material.Glass] = 		main.SoundIds.Glass,

	[Enum.Material.Pebble] = 		main.SoundIds.Gravel,

	[Enum.Material.SmoothPlastic] = main.SoundIds.Rubber,
	[Enum.Material.ForceField] = 	main.SoundIds.Rubber,
	[Enum.Material.Foil] = 			main.SoundIds.Rubber,

	[Enum.Material.Mud] = 			main.SoundIds.Mud,

}

function main:GetTableFromMaterial(EnumItem)
	if typeof(EnumItem) == "string" then
		EnumItem = Enum.Material[EnumItem]
	end
	return main.MaterialMap[EnumItem]
end

function main:GetRandomSound(SoundTable)
	return SoundTable[math.random(#SoundTable)]
end

return main
