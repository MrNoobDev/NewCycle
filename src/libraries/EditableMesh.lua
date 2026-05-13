-- CREATED BY AGENTLEPINEAPPLE
-- DO NOT EDIT BELOW IF YOU DO NOT KNOW WHAT YOU ARE DOING

local mesh = {}
mesh.__index = mesh

local aService = game:GetService("AssetService")
local rService = game:GetService("RunService")
local repStorage = game:GetService("ReplicatedStorage")

local modulesFolder = repStorage:WaitForChild("ClientLibraries")
local utilities = require(modulesFolder:WaitForChild("Utilities"))

-- SCRIPTING --
function mesh.new(object)
	local self = setmetatable({}, mesh)

	--// Variables
	self.OriginalMesh = object -- Original mesh asset
	self.EditableMesh = nil -- Editable mesh
	self.TemplateMesh = nil -- Editable mesh applied to meshpart (used for copying to other meshparts)

	self.UVs = {}
	self.Positions = {}
	self.Dampens = {}
	self.AppendedMeshes = {}
	--self.ShadowCasters = {}

	--// Mesh
	--self.MeshCastShadow = object:GetAttribute("MeshCastShadows")

	--// Animate UVS
	self.UVScrollVector = object:GetAttribute("UVScrollVector")

	--// Animate Vertices
	self.TurbulenceAmplitude = object:GetAttribute("TurbulenceAmplitude")
	self.TurbulenceAxis = object:GetAttribute("TurbulenceAxis")
	self.TurbulenceDampenAmount = object:GetAttribute("TurbulenceDampenAmount")
	self.TurbulenceDampenAxis = object:GetAttribute("TurbulenceDampenAxis")
	self.TurbulenceFrequency = object:GetAttribute("TurbulenceFrequency")
	self.TurbulenceSpeed = object:GetAttribute("TurbulenceSpeed") or 1

	return self
end

function mesh:AppendMesh(object)
	if not self.AppendedMeshes[object] then
		--// Preserve Texture
		local texture = object.TextureID

		--[[// Fake Shadow
		if self.MeshCastShadow and self.MeshCastShadow == true then
			local shadow = object:Clone()
			shadow.Material = Enum.Material.ForceField
			shadow.Transparency = -math.huge
			shadow.Parent = object
			self.ShadowCasters[object] = shadow
		end	]]

		--// Append Mesh
		self.AppendedMeshes[object] = object
		object:ApplyMesh(self.TemplateMesh)
		object.TextureID = texture
	end
end

function mesh:ReleaseMesh(object)
	if self.AppendedMeshes[object] then
		--// Preserve Texture
		local texture = object.TextureID

		--[[// Delete Fake Shadow
		if self.ShadowCasters[object] then
			self.ShadowCasters[object]:Destroy()
			self.ShadowCasters[object] = nil
		end]]

		--// Release Mesh
		self.AppendedMeshes[object] = nil
		object:ApplyMesh(self.OriginalMesh)
		object.TextureID = texture
	end
end

function mesh:AnimateUVs(dt)
	for id, position in pairs(self.UVs) do
		local newPosition = position + (self.UVScrollVector * dt)
		self.UVs[id] = newPosition
		self.EditableMesh:SetUV(id, position)
	end
end

function mesh:AnimateVertices()
	for id, position in pairs(self.Positions) do
		local waveVector = (
			self.TurbulenceAmplitude
			* math.sin((self.TurbulenceSpeed * tick()) + (position.Z * self.TurbulenceFrequency))
		) -- Change position.Z to some like chooseable variable later
		local dampenPercent = self.Dampens[id] or 1
		local offset = -(self.TurbulenceAxis * waveVector * dampenPercent)

		local newPosition = position + offset
		self.EditableMesh:SetPosition(id, newPosition)
	end
end

function mesh:Enable()
	--// Create Meshes
	self.EditableMesh = aService:CreateEditableMeshAsync(self.OriginalMesh.MeshContent)
	self.TemplateMesh = aService:CreateMeshPartAsync(Content.fromObject(self.EditableMesh))

	--// Get UVs
	for _, id in pairs(self.EditableMesh:GetUVs()) do
		self.UVs[id] = self.EditableMesh:GetUV(id)
	end

	--// Get Vertices
	for _, id in pairs(self.EditableMesh:GetVertices()) do
		-- Vertex Positions
		local position = self.EditableMesh:GetPosition(id)
		self.Positions[id] = position

		-- Dampened Vertex Positions
		if self.TurbulenceDampenAmount and self.TurbulenceDampenAxis then
			local relativePosition = (position + self.TemplateMesh.Size / 2) / self.TemplateMesh.Size
			local dampenedPosition =
				utilities.evalNumberSequence(self.TurbulenceDampenAmount, relativePosition[self.TurbulenceDampenAxis])
			self.Dampens[id] = dampenedPosition
		end
	end

	--// Connections
	self.AnimationConnection = rService.Heartbeat:Connect(function(dt)
		if utilities.getDictionaryLength(self.AppendedMeshes) > 0 then
			--// Animate UVs
			if self.UVScrollVector then
				self:AnimateUVs(dt)
			end

			--// Animate Vertices
			if self.TurbulenceAxis then
				self:AnimateVertices()
			end
		end
	end)
end

function mesh:Disable()
	--// Terminate Editable Mesh
	self.EditableMesh:Destroy()
	self.EditableMesh = nil

	--// Terminate Template Mesh
	self.TemplateMesh:Destroy()
	self.TemplateMesh = nil

	--// Release Append Meshes
	for _, v in pairs(self.AppendedMeshes) do
		self:ReleaseMesh(v)
	end

	--// Disable Connections
	self.AnimationConnection:Disconnect()
end

return mesh
