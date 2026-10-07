--!strict
-- Objetivo: eliminar N enemigos (opcionalmente de un `TargetId` concreto).
local KillEnemy = {}

function KillEnemy.Label(definition): string
	if definition.TargetId then
		return string.format("Elimina %d x %s", definition.Amount or 1, definition.TargetId)
	end
	return string.format("Elimina %d enemigos", definition.Amount or 1)
end

function KillEnemy.Required(definition): number
	return math.max(1, definition.Amount or 1)
end

function KillEnemy.Update() end

function KillEnemy.HandleEvent(runtime, event)
	if runtime.Complete or event.Kind ~= "Kill" then
		return
	end
	local definition = runtime.Definition
	local enemy = event.Enemy
	if definition.TargetId and enemy.Id ~= definition.TargetId then
		return
	end
	runtime.Current += 1
	if runtime.Current >= runtime.Required then
		runtime.Complete = true
	end
end

return KillEnemy
