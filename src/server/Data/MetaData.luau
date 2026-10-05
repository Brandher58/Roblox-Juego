--!strict
-- Progresión permanente del jugador (meta data). En la Fase 1 esto NO guarda nada:
-- existe para que la frontera entre "lo que dura una partida" (Run) y "lo que se
-- guarda entre partidas" (MetaData) quede marcada desde el principio, y para que
-- añadir persistencia en la Fase 4 no toque los sistemas de gameplay.
--
-- Lo que haría falta cuando se active:
--   - DataStoreService con UpdateAsync (nunca GetAsync + SetAsync).
--   - Bloqueo de sesión para que dos servidores no escriban el mismo perfil.
--   - Guardar en límites de vida (PlayerLeaving, BindToClose), no solo al salir.
--   - Reconciliar contra la plantilla y validar números antes de escribir.
local MetaData = {}

export type Template = {
	Version: number,
	PlayerId: number,
	Currency: number,
	UnlockedCharacters: { string },
	UnlockedWeapons: { string },
	Upgrades: { [string]: number },
	Statistics: {
		Runs: number,
		BestTime: number,
		BestLevel: number,
		TotalKills: number,
	},
}

function MetaData.defaults(playerId: number): Template
	return {
		Version = 1,
		PlayerId = playerId,
		Currency = 0,
		UnlockedCharacters = {},
		UnlockedWeapons = {},
		Upgrades = {},
		Statistics = {
			Runs = 0,
			BestTime = 0,
			BestLevel = 0,
			TotalKills = 0,
		},
	}
end

return MetaData
