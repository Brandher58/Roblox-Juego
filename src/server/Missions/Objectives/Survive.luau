--!strict
-- Objetivo: sobrevivir N segundos. Puro: no conoce Roblox ni la misión.
--
-- Interfaz de objetivo (ver ObjectiveSystem):
--   Label(definition) -> string        texto para la UI
--   Required(definition) -> number     total normalizado
--   Update(runtime, dt)                avance por tiempo
--   HandleEvent(runtime, event)        avance por evento de gameplay
local Survive = {}

function Survive.Label(definition): string
	return string.format("Sobrevive %d s", math.floor(definition.Duration or 0))
end

function Survive.Required(definition): number
	return math.max(1, definition.Duration or 1)
end

function Survive.Update(runtime, dt: number)
	if runtime.Complete then
		return
	end
	runtime.Current = math.min(runtime.Required, runtime.Current + dt)
	if runtime.Current >= runtime.Required then
		runtime.Complete = true
	end
end

function Survive.HandleEvent() end

return Survive
