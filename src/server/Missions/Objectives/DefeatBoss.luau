--!strict
-- Objetivo: derrotar al jefe indicado (etiqueta "boss" en la definición). Se apoya
-- en el mismo evento de muerte que el resto: no conoce BossSystem ni la misión.
local DefeatBoss = {}

function DefeatBoss.Label(definition): string
	return string.format("Derrota al jefe (%s)", definition.TargetId or "?")
end

function DefeatBoss.Required(): number
	return 1
end

function DefeatBoss.Update() end

function DefeatBoss.HandleEvent(runtime, event)
	if runtime.Complete or event.Kind ~= "Kill" then
		return
	end
	local enemy = event.Enemy
	if not table.find(enemy.Tags, "boss") then
		return
	end
	if runtime.Definition.TargetId and enemy.Id ~= runtime.Definition.TargetId then
		return
	end
	runtime.Complete = true
	runtime.Current = runtime.Required
end

return DefeatBoss
