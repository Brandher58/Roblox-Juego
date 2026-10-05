--!strict
-- Gotas de experiencia. Es un sistema de recogidas genérico: decide magnetismo,
-- atracción y recogida, pero no qué hace el juego con la recompensa; eso lo inyecta
-- el propietario de la partida con onCollect, para que este módulo no dependa del
-- estado de partida y se pueda reutilizar para otro tipo de pickup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pool = require(script.Parent.Parent.Utility.Pool)
local Stats = require(script.Parent.Parent.Stats)
local PlayerAvatar = require(script.Parent.Parent.PlayerAvatar)

local COLLECT_RADIUS = 2.2
local MIN_PULL = 26
local MAX_PULL = 95

type Pickup = {
	Part: BasePart,
	Position: Vector3,
	Value: number,
	Slot: number,
	Lease: any,
}

-- Lista decentes candidatos reutilizada por frame: recorrer Players y buscar la raíz
-- por cada gota multiplicaría el coste por el número de gotas.
type Candidate = {
	player: Player,
	root: BasePart,
	radius: number,
}

local pickups: { Pickup } = {}
local candidates: { Candidate } = {}
local candidateCount = 0
local container: Folder = nil
local pool: Pool.Pooled = nil
local collectHandler: ((Player, number) -> ())? = nil

local function buildTemplate(): Part
	local part = Instance.new("Part")
	part.Name = "XPPickup"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.CastShadow = false
	return part
end

local XPPickups = {}

function XPPickups.init()
	if container then
		return
	end
	container = Instance.new("Folder")
	container.Name = "XPPickups"
	container.Parent = workspace
	pool = Pool.new(buildTemplate(), 64)
end

-- El propietario de la partida decide qué significa recoger XP (subir de nivel,
-- pausar la acción, avisar al cliente). Aquí solo se entrega el valor.
function XPPickups.onCollect(handler: (Player, number) -> ())
	collectHandler = handler
end

function XPPickups.count(): number
	return #pickups
end

local function applyLook(pickup: Pickup)
	local value = pickup.Value
	local size = math.clamp(0.5 + value * 0.06, 0.5, 2)
	pickup.Part.Size = Vector3.new(size, size, size)
	pickup.Part.Color = if value >= 12 then Color3.fromRGB(120, 255, 150) else Color3.fromRGB(110, 190, 255)
	pickup.Part.CFrame = CFrame.new(pickup.Position + Vector3.new(0, size * 0.5, 0))
end

-- Cuando hay demasiadas gotas en el suelo, la nueva se funde con la más cercana en
-- lugar de instanciarse. La recompensa no se pierde y el jugador ve una gota mayor.
local function mergeIntoClosest(position: Vector3, value: number): Pickup?
	local best: Pickup? = nil
	local bestDistance = Config.Pickups.MergeRadius * Config.Pickups.MergeRadius
	for _, pickup in pickups do
		local dx = pickup.Position.X - position.X
		local dz = pickup.Position.Z - position.Z
		local distance = dx * dx + dz * dz
		if distance <= bestDistance then
			bestDistance = distance
			best = pickup
		end
	end
	if best then
		best.Value += value
		applyLook(best)
	end
	return best
end

function XPPickups.spawn(position: Vector3, value: number): Pickup?
	if not pool or value <= 0 then
		return nil
	end

	if #pickups >= Config.Pickups.MaxActive then
		return mergeIntoClosest(position, value)
	end

	local acquired, lease = pool:Get(function(instance)
		local part = instance :: Part
		part.Transparency = 0.15
		part.Parent = container
	end)

	local pickup: Pickup = {
		Part = acquired :: Part,
		Position = position,
		Value = value,
		Slot = #pickups + 1,
		Lease = lease,
	}
	-- El tamaño comunica el valor de un vistazo y evita tener que etiquetar nada.
	applyLook(pickup)
	table.insert(pickups, pickup)
	return pickup
end

local function release(index: number)
	local pickup = pickups[index]
	local slot = pickup.Slot
	local last = pickups[#pickups]
	pickups[slot] = last
	last.Slot = slot
	table.remove(pickups)
	pool:Release(pickup.Part, pickup.Lease)
end

local function refreshCandidates(now: number)
	candidateCount = 0
	for _, player in PlayerAvatar.alivePlayers() do
		local root = PlayerAvatar.root(player)
		if root then
			candidateCount += 1
			local slot = candidates[candidateCount]
			if slot then
				slot.player = player
				slot.root = root
				slot.radius = Stats.get(player, now).PickupRadius or 0
			else
				table.insert(candidates, {
					player = player,
					root = root,
					radius = Stats.get(player, now).PickupRadius or 0,
				})
			end
		end
	end
end

local function updatePickup(index: number, dt: number)
	local pickup = pickups[index]

	-- Un solo recorrido decide quién atrae cada gota. En cooperativo la XP es
	-- compartida, así que vale con el jugador vivo más cercano dentro de su radio.
	local owner: Player? = nil
	local ownerRoot: BasePart? = nil
	local closest = math.huge
	local radius = 0

	for slot = 1, candidateCount do
		local candidate = candidates[slot]
		local root = candidate.root
		local dx = root.Position.X - pickup.Position.X
		local dz = root.Position.Z - pickup.Position.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance <= candidate.radius and distance < closest then
			owner = candidate.player
			ownerRoot = root
			closest = distance
			radius = candidate.radius
		end
	end

	if owner and ownerRoot then
		if closest <= COLLECT_RADIUS then
			if collectHandler then
				collectHandler(owner, pickup.Value)
			end
			release(index)
			return
		end

		-- La atracción acelera al acercarse, así que el efecto "imán" se lee sin
		-- necesidad de un tween por gota.
		local closeness = 1 - math.clamp(closest / math.max(radius, 0.001), 0, 1)
		local pull = MIN_PULL + (MAX_PULL - MIN_PULL) * closeness
		local direction = ownerRoot.Position - pickup.Position
		local distance = direction.Magnitude
		if distance > 0.01 then
			pickup.Position += (direction / distance) * pull * dt
		end
	end

	local size = pickup.Part.Size.X
	pickup.Part.CFrame = CFrame.new(pickup.Position + Vector3.new(0, size * 0.5, 0))
end

function XPPickups.update(dt: number)
	if #pickups == 0 then
		return
	end
	refreshCandidates(os.clock())
	for index = #pickups, 1, -1 do
		updatePickup(index, dt)
	end
end

function XPPickups.clearAll()
	for index = #pickups, 1, -1 do
		release(index)
	end
end

return XPPickups
