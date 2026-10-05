--!strict
-- Entrada: usa los controles por defecto de Roblox (que ya cubren teclado, mando y
-- joystick táctil) y solo los desactiva cuando la partida está pausada. No se crea un
-- sistema de input paralelo: el HUD de móvil y el mando siguen funcionando igual.
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local playerModule = require(localPlayer.PlayerScripts:WaitForChild("PlayerModule"))
local controls = playerModule:GetControls()

local enabled = true

local RunInput = {}

function RunInput.setEnabled(next: boolean)
	if next == enabled then
		return
	end
	enabled = next
	if next then
		controls:Enable()
	else
		controls:Disable()
	end
end

function RunInput.isEnabled(): boolean
	return enabled
end

return RunInput
