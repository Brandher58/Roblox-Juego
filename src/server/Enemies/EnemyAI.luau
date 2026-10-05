--!strict
-- Comportamiento de los enemigos. Un solo bucle para todos ellos, con un cursor
-- giratorio que refresca objetivos por tandas: así el coste no crece de golpe con
-- cientos de enemigos ni aparece un pico en un solo frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(script.Parent.Parent.Stats)
local PlayerAvatar = require(script.Parent.Parent.PlayerAvatar)
local EnemyRegistry = require(script.Parent.EnemyRegistry)

type Enemy = EnemyRegistry.Enemy

local SEPARATION_WEIGHT = 1.6
local TARGETS_PER_SLICE = 8

local cursor = 0
local targets: { { player: Player, position: Vector3 } } = {}

local function collectTargets()
	table.clear(targets)
	for _, player in PlayerAvatar.alivePlayers() do
		local root = PlayerAvatar.root(player)
		if root then
			table.insert(targets, { player = player, position = root.Position })
		end
	end
end

local function nearestTarget(position: Vector3): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, target in targets do
		local dx = target.position.X - position.X
		local dz = target.position.Z - position.Z
		local distance = dx * dx + dz * dz
		if distance < bestDistance then
			bestDistance = distance
			best = target.player
		end
	end
	return best
end

local function isValidTarget(player: Player?): boolean
	if not player then
		return false
	end
	for _, target in targets do
		if target.player == player then
			return true
		end
	end
	return false
end

local function refreshTargets()
	local enemies = EnemyRegistry.all()
	if #enemies == 0 then
		cursor = 0
		return
	end
	local slice = math.min(#enemies, TARGETS_PER_SLICE)
	for _ = 1, slice do
		cursor = cursor % #enemies + 1
		local enemy = enemies[cursor]
		enemy.Target = nearestTarget(enemy.Position)
	end
end

local function moveEnemies(dt: number)
	local enemies = EnemyRegistry.all()
	local half = Config.Arena.HalfExtent
	local floorY = Config.Arena.FloorY

	for index = #enemies, 1, -1 do
		local enemy = enemies[index]
		local target = enemy.Target
		if not isValidTarget(target) then
			target = nil
		end

		local steer = Vector3.zero
		if target then
			for _, entry in targets do
				if entry.player == target then
					local dx = entry.position.X - enemy.Position.X
					local dz = entry.position.Z - enemy.Position.Z
					local distance = math.sqrt(dx * dx + dz * dz)
					if distance > 0.01 then
						steer = Vector3.new(dx / distance, 0, dz / distance)
					end
					break
				end
			end
		end

		-- Separación: evita que la horda se apile en un solo punto y que el jugador
		-- solo pueda golpear a un enemigo a la vez.
		local separation = Vector3.zero
		local size = enemy.Definition.Size
		for _, other in EnemyRegistry.queryRadius(enemy.Position, size * 2) do
			if other ~= enemy then
				local dx = enemy.Position.X - other.Position.X
				local dz = enemy.Position.Z - other.Position.Z
				local distance = math.sqrt(dx * dx + dz * dz)
				local minimum = size * 0.5 + other.Definition.Size * 0.5
				if distance < minimum and distance > 0.001 then
					local push = (minimum - distance) / minimum
					separation += Vector3.new(dx / distance, 0, dz / distance) * push
				end
			end
		end

		local direction = steer + separation * SEPARATION_WEIGHT
		local magnitude = direction.Magnitude
		if magnitude > 1 then
			direction /= magnitude
		end

		local next = enemy.Position + direction * enemy.Speed * dt
		next = Vector3.new(math.clamp(next.X, -half, half), floorY, math.clamp(next.Z, -half, half))

		enemy.Position = next
		-- Sin dirección (recién spawneado y sin vecinos) no hay hacia dónde mirar:
		-- CFrame.lookAt exige dos puntos distintos, así que en ese frame no se rota.
		if direction.Magnitude > 0.001 then
			enemy.Root.CFrame =
				CFrame.lookAt(next + Vector3.new(0, 1, 0), next + direction + Vector3.new(0, 1, 0))
		end
		if enemy.IsAsset then
			-- El asset no tiene un "Body" que mover; el modelo completo se coloca por su
			-- PrimaryPart. El Root sirve solo para la rejilla espacial.
			enemy.Model:PivotTo(CFrame.new(next + Vector3.new(0, size * 0.5, 0)))
		else
			enemy.Body.CFrame = CFrame.new(next + Vector3.new(0, size * 0.5, 0))
		end
	end
end

local function attackPlayers(now: number)
	local enemies = EnemyRegistry.all()
	for _, enemy in enemies do
		local target = enemy.Target
		if target and now >= enemy.NextAttackAt then
			for _, entry in targets do
				if entry.player == target then
					local dx = entry.position.X - enemy.Position.X
					local dz = entry.position.Z - enemy.Position.Z
					if dx * dx + dz * dz <= enemy.AttackRange * enemy.AttackRange then
						local stats = Stats.get(target, now)
						local applied = PlayerAvatar.damage(target, stats, enemy.Damage)
						enemy.NextAttackAt = now + enemy.AttackInterval
						if applied > 0 then
							Remotes.CombatEffect:FireAllClients("playerHurt", entry.position, 1)
						end
					end
					break
				end
			end
		end
	end
end

local EnemyAI = {}

function EnemyAI.update(dt: number, now: number)
	collectTargets()
	if #targets == 0 then
		return
	end
	refreshTargets()
	moveEnemies(dt)
	attackPlayers(now)
end

return EnemyAI
