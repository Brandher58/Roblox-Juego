--!strict

-- Definiciones de mapas. Un mapa es una zona del mundo, no una partida: las misiones
-- lo configuran, no lo duplican.
--
-- Los puntos se declaran con números planos (X/Y/Z) y no con `Vector3` para que el
-- registro de contenido se pueda cargar y validar en las pruebas headless. El
-- servidor los convierte a `Vector3` solo si los necesita.
local Maps: {
	[string]: {
		Id: string,
		DisplayName: string,
		Description: string?,
		Arena: { HalfExtent: number, FloorY: number },
		PlayerSpawn: { X: number, Y: number, Z: number },
		SpawnZones: { { Name: string, X: number, Y: number, Z: number, Radius: number } },
	},
} =
	{}

Maps["AbandonedMine"] = {
	Id = "AbandonedMine",
	DisplayName = "Abandoned Mine",
	Description = "A dark mine with safe areas and dire rooms.",
	Arena = { HalfExtent = 110, FloorY = 0.5 },
	PlayerSpawn = { X = 0, Y = 4, Z = 0 },
	SpawnZones = {
		{ Name = "Entrance", X = 0, Y = 0, Z = 0, Radius = 20 },
		{ Name = "BreakRoom", X = 0, Y = 0, Z = 30, Radius = 30 },
	},
}

-- Segundo mapa: existe desde ahora para que el desbloqueo del jefe apunte a algo
-- real. Todavía no tiene misiones propias; añadirlas es contenido nuevo, no código.
Maps["AbandonedFactory"] = {
	Id = "AbandonedFactory",
	DisplayName = "Abandoned Factory",
	Description = "The surface facility above the mine.",
	Arena = { HalfExtent = 120, FloorY = 0.5 },
	PlayerSpawn = { X = 0, Y = 4, Z = 0 },
	SpawnZones = {
		{ Name = "LoadingBay", X = 0, Y = 0, Z = 0, Radius = 24 },
	},
}

return Maps
