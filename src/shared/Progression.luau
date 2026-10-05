--!strict
-- Curva de experiencia. Función pura: sin Roblox, testeable headless.
local Progression = {}

-- XP necesaria para pasar de `level` a `level + 1`.
function Progression.xpForNext(level: number): number
	local steps = math.max(0, level - 1)
	return 6 + steps * 5 + math.floor(steps ^ 1.6)
end

function Progression.xpForLevel(level: number): number
	if level <= 1 then
		return 0
	end
	local total = 0
	for step = 1, level - 1 do
		total += Progression.xpForNext(step)
	end
	return total
end

-- Aplica la XP y devuelve el nuevo nivel, la XP dentro del nivel y cuántos
-- niveles se ganaron (puede ser más de uno con pickups grandes).
function Progression.addXp(currentLevel: number, currentXp: number, amount: number): (number, number, number)
	local level = math.max(1, currentLevel)
	local xp = math.max(0, currentXp) + math.max(0, amount)
	local gained = 0

	while true do
		local needed = Progression.xpForNext(level)
		if xp < needed then
			break
		end
		xp -= needed
		level += 1
		gained += 1
	end

	return level, xp, gained
end

return Progression
