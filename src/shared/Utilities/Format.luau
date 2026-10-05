--!strict
-- Utilidades de presentación sin estado.
local Format = {}

function Format.clock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local minutes = math.floor(total / 60)
	local rest = total % 60
	return `{minutes}:{if rest < 10 then "0" else ""}{rest}`
end

function Format.percent(value: number, decimals: number?): string
	local places = decimals or 0
	return `{math.floor(value * 10 ^ places + 0.5) / 10 ^ places * 100}%`
end

return Format
