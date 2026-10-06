--!strict
-- Plantilla de enemigos procedurales: no dependen de 107ignore o de un asset del
-- store. El servidor clona el resultado como modelo visual básico.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

type EnemyDefinition = Types.EnemyDefinition

local P = {}

-- Fabricacion de un enemy mínimo: Root invisible + Body con el tamaño/color del
-- definition. Sirve para cualquier clase de enemigo y se adapta a su Config.
function P.makeBasicBody(definition: EnemyDefinition, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = `Enemy_{definition.Id}`

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1.6, 1.6, 1.6)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = model

	local size = definition.Size
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(size, size, size)
	body.Color = color
	body.Material = Enum.Material.Neon
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.Parent = model

	model.PrimaryPart = root
	return model
end

-- Mezcla de formas según el id para que (por ahora) cada enemigo se vea diferente
-- sin assets externos.
function P.make(definition: EnemyDefinition): Model
	local visuals = Config.EnemyVisuals[definition.Id] or {}
	local color = visuals.Color or Color3.fromRGB(214, 79, 79)
	return P.makeBasicBody(definition, color)
end

return P
