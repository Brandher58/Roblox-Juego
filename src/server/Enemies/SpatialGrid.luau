--!strict
-- Hash espacial por celdas. Evita el O(n^2) de "cada enemigo contra cada enemigo"
-- en separación, impactos y selección de objetivo. Solo guarda entradas: la
-- posición vive en el propio enemigo y se escribe una vez por frame.
local Grid = {}
Grid.__index = Grid

export type Grid = typeof(setmetatable(
	{} :: {
		cellSize: number,
		buckets: { [string]: { any } },
		scratch: { any },
	},
	Grid
))

function Grid.new(cellSize: number): Grid
	return setmetatable({ cellSize = cellSize, buckets = {}, scratch = {} }, Grid)
end

function Grid:clear()
	table.clear(self.buckets)
end

-- Clave numérica de celda: una multiplicación en vez de una cadena por celda evita
-- reservar memoria en el hot path. Solo es inyectiva si el rango de celdas cabe en
-- 4096 columnas, cosa que cumple la arena; si el mapa creciera habría que revisar
-- el factor.
local function cellIndex(grid: Grid, position: Vector3): number
	return math.floor(position.X / grid.cellSize) + math.floor(position.Z / grid.cellSize) * 4096
end

function Grid:insert(entry: any, position: Vector3)
	local key = cellIndex(self, position)
	local bucket = self.buckets[key]
	if not bucket then
		bucket = {}
		self.buckets[key] = bucket
	end
	table.insert(bucket, entry)
end

-- Recorre solo las celdas que tocan el círculo de consulta. Devuelve la tabla
-- interna para no asignar en el hot path; el llamante no debe conservarla.
function Grid:queryRadius(position: Vector3, radius: number): { any }
	local results = self.scratch
	table.clear(results)

	local size = self.cellSize
	local minX = math.floor((position.X - radius) / size)
	local maxX = math.floor((position.X + radius) / size)
	local minZ = math.floor((position.Z - radius) / size)
	local maxZ = math.floor((position.Z + radius) / size)

	for cx = minX, maxX do
		for cz = minZ, maxZ do
			local bucket = self.buckets[cx + cz * 4096]
			if bucket then
				for _, entry in bucket do
					table.insert(results, entry)
				end
			end
		end
	end

	return results
end

return Grid
