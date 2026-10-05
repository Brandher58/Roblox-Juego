--!strict
-- Puente entre las estadísticas de la partida y el avatar del jugador.
-- El Humanoid es la representación física de la vida y la velocidad; las cifras
-- autoritativas viven en Stats, aquí solo se las proyectamos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

type StatBlock = Types.StatBlock

local PlayerAvatar = {}

function PlayerAvatar.humanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function PlayerAvatar.root(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function PlayerAvatar.isAlive(player: Player): boolean
	local humanoid = PlayerAvatar.humanoid(player)
	return humanoid ~= nil and humanoid.Health > 0
end

-- Si sube la vida máxima, el jugador recibe la diferencia en vida actual: un +25
-- de salud máxima se siente como una cura y no como una cura desperdiciada.
function PlayerAvatar.applyStats(player: Player, stats: StatBlock)
	local humanoid = PlayerAvatar.humanoid(player)
	if not humanoid then
		return
	end

	local maxHealth = math.max(1, stats.MaxHealth or humanoid.MaxHealth)
	local previousMax = humanoid.MaxHealth
	humanoid.MaxHealth = maxHealth
	if maxHealth > previousMax and humanoid.Health > 0 then
		humanoid.Health = math.min(maxHealth, humanoid.Health + (maxHealth - previousMax))
	end

	humanoid.WalkSpeed = stats.MoveSpeed or 16
end

-- La armadura resta daño plano con un suelo del 25% del daño original, para que
-- nunca llegue a ser invulnerable.
function PlayerAvatar.damage(player: Player, stats: StatBlock, amount: number): number
	local humanoid = PlayerAvatar.humanoid(player)
	if not humanoid or humanoid.Health <= 0 or amount <= 0 then
		return 0
	end
	local armor = stats.Armor or 0
	local applied = math.max(amount * 0.25, amount - armor)
	applied = math.min(applied, humanoid.Health)
	humanoid.Health = humanoid.Health - applied
	return applied
end

function PlayerAvatar.heal(player: Player, amount: number)
	local humanoid = PlayerAvatar.humanoid(player)
	if not humanoid or humanoid.Health <= 0 or amount <= 0 then
		return
	end
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
end

function PlayerAvatar.teleport(player: Player, position: Vector3)
	local root = PlayerAvatar.root(player)
	if root then
		root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

function PlayerAvatar.alivePlayers(): { Player }
	local alive = {}
	for _, player in Players:GetPlayers() do
		if PlayerAvatar.isAlive(player) then
			table.insert(alive, player)
		end
	end
	return alive
end

return PlayerAvatar
