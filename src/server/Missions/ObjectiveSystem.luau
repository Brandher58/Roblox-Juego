--!strict
-- Registro de tipos de objetivo. `MissionManager` nunca tiene una rama por tipo:
-- crea runtimes, los actualiza por tiempo y les reparte eventos de gameplay.
--
-- Añadir un objetivo nuevo = un módulo en `Objectives/` + una línea aquí. No se toca
-- ni la misión ni el gestor central.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

-- Evento de gameplay normalizado. Hoy solo hay muertes; el día que exista recogida
-- de objetos o interacción, se añade una variante y los objetivos interesados la leen.
export type ObjectiveEvent =
	{ Kind: "Kill", Enemy: Types.EnemyDefinition }
	| { Kind: "BossDefeated", BossId: string }

export type Runtime = {
	Definition: Types.MissionObjective,
	Required: number,
	Current: number,
	Complete: boolean,
	Update: (runtime: Runtime, dt: number) -> (),
	HandleEvent: (runtime: Runtime, event: ObjectiveEvent) -> (),
	Label: (definition: Types.MissionObjective) -> string,
}

local Modules: {
	[string]: {
		Label: (definition: Types.MissionObjective) -> string,
		Required: (definition: Types.MissionObjective) -> number,
		Update: (runtime: Runtime, dt: number) -> (),
		HandleEvent: (runtime: Runtime, event: ObjectiveEvent) -> (),
	},
} =
	{
		Survive = require(script.Parent.Objectives.Survive),
		KillEnemy = require(script.Parent.Objectives.KillEnemy),
		KillElite = require(script.Parent.Objectives.KillElite),
		DefeatBoss = require(script.Parent.Objectives.DefeatBoss),
	}

local ObjectiveSystem = {}

function ObjectiveSystem.create(definition: Types.MissionObjective): Runtime
	local module = Modules[definition.Type]
	if not module then
		error(`[ObjectiveSystem] tipo de objetivo desconocido {tostring(definition.Type)}`)
	end
	return {
		Definition = definition,
		Required = module.Required(definition),
		Current = 0,
		Complete = false,
		Update = module.Update,
		HandleEvent = module.HandleEvent,
		Label = module.Label,
	}
end

function ObjectiveSystem.createAll(definitions: { Types.MissionObjective }): { Runtime }
	local runtimes: { Runtime } = {}
	for _, definition in definitions do
		table.insert(runtimes, ObjectiveSystem.create(definition))
	end
	return runtimes
end

function ObjectiveSystem.update(runtimes: { Runtime }, dt: number)
	for _, runtime in runtimes do
		runtime.Update(runtime, dt)
	end
end

function ObjectiveSystem.dispatch(runtimes: { Runtime }, event: ObjectiveEvent)
	for _, runtime in runtimes do
		if not runtime.Complete then
			runtime.HandleEvent(runtime, event)
		end
	end
end

-- Todos los objetivos son obligatorios en el modo actual ("All"). Si una misión
-- futura necesita "Sequential"/"Some", se añade aquí sin tocar los objetivos.
function ObjectiveSystem.allComplete(runtimes: { Runtime }): boolean
	for _, runtime in runtimes do
		if not runtime.Complete then
			return false
		end
	end
	return true
end

function ObjectiveSystem.view(runtime: Runtime): Types.MissionObjectiveState
	return {
		Type = runtime.Definition.Type,
		Label = runtime.Label(runtime.Definition),
		Current = runtime.Current,
		Required = runtime.Required,
		Complete = runtime.Complete,
	}
end

-- Descripción sin estado, para el panel de selección: etiqueta y total de un
-- objetivo antes de que exista una ejecución.
function ObjectiveSystem.staticView(
	definition: Types.MissionObjective
): { Type: Types.MissionObjectiveType, Label: string, Required: number }
	local runtime = ObjectiveSystem.create(definition)
	return {
		Type = definition.Type,
		Label = runtime.Label(definition),
		Required = runtime.Required,
	}
end

return ObjectiveSystem
