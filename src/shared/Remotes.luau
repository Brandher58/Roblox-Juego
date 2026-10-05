--!strict
-- Contrato de red. Un solo punto de acceso a los remotes: el cliente nunca los
-- busca por su cuenta y el servidor siempre los referencia desde aquí.
--
-- Los payloads son datos de presentación o peticiones. Nunca se acepta desde el
-- cliente daño, XP, recompensas ni precios.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function remote(name: string, className: string): Instance
	local folder = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not folder then
		error("[Remotes] ReplicatedStorage.Remotes no llegó desde el servidor")
	end
	local instance = folder:WaitForChild(name, 10)
	if not instance then
		error(`[Remotes] falta el remote "{name}"`)
	end
	if not instance:IsA(className) then
		error(`[Remotes] "{name}" debería ser {className}`)
	end
	return instance
end

return {
	-- Servidor → cliente: (state: MatchState, elapsed: number, offers: {UpgradeOffer}?)
	MatchStateChanged = remote("MatchStateChanged", "RemoteEvent") :: RemoteEvent,
	-- Servidor → cliente: snapshot completo del HUD (RunSnapshot).
	RunSnapshot = remote("RunSnapshot", "RemoteEvent") :: RemoteEvent,
	-- Servidor → cliente: una carta ya elegida (string id).
	UpgradeChosen = remote("UpgradeChosen", "RemoteEvent") :: RemoteEvent,
	-- Cliente → servidor: el cliente ya registró sus listeners; pide su estado.
	ClientReady = remote("ClientReady", "RemoteEvent") :: RemoteEvent,
	-- Cliente → servidor: petición de elegir carta (string id). Se valida contra
	-- el conjunto de ofertas pendientes y se consume una sola vez.
	RequestUpgrade = remote("RequestUpgrade", "RemoteEvent") :: RemoteEvent,
	-- Servidor → cliente: feedback visual descartable (kind: string, position, magnitude).
	CombatEffect = remote("CombatEffect", "UnreliableRemoteEvent") :: UnreliableRemoteEvent,
}
