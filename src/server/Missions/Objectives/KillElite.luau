--!strict
-- Objetivo: eliminar N enemigos de élite (etiqueta "elite" en la definición).
local KillElite = {}

function KillElite.Label(definition): string
	return string.format("Elimina %d élite(s)", definition.Amount or 1)
end

function KillElite.Required(definition): number
	return math.max(1, definition.Amount or 1)
end

function KillElite.Update() end

function KillElite.HandleEvent(runtime, event)
	if runtime.Complete or event.Kind ~= "Kill" then
		return
	end
	if not table.find(event.Enemy.Tags, "elite") then
		return
	end
	runtime.Current += 1
	if runtime.Current >= runtime.Required then
		runtime.Complete = true
	end
end

return KillElite
