--!strict
-- Encuentra visuales de armas cargados por el usuario.
-- Coloca los modelos de Roblox Assets en:
--   ReplicatedStorage → Shared → Assets → (Blade.rbx, Bomb.rbx, Projectile.rbx, …)
-- Si un modelo no existe, el juego vuelve al Part de reserva: no se rompe nada.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local GameAssets = {}

local function getFolder(): Folder?
	local assets = Shared:FindFirstChild("Assets")
	return if assets and assets:IsA("Folder") then assets else nil
end

-- Devuelve una copia de una pieza de modelo cualquiera que exista dentro de
-- Shared/Assets con el nombre indicado. Devuelve nil si no hay nada con ese nombre.
function GameAssets.find(name: string): Instance?
	local assets = getFolder()
	if not assets then
		return nil
	end
	return assets:FindFirstChild(name)
end

-- Misma idea pero obligada a ser una BasePart (MeshPart o Part). Perfecta para
-- proyectiles y miradas de OrbitBlades porque son BasePart que el resto del código
-- ya mueve con CFrame.
function GameAssets.findPart(name: string): BasePart?
	local obj = GameAssets.find(name)
	if obj and obj:IsA("BasePart") then
		return obj :: BasePart
	end
	return nil
end

return GameAssets
