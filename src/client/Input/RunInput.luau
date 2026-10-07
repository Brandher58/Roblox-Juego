--!strict
-- Entrada: usa los controles por defecto de Roblox (que ya cubren teclado, mando y
-- joystick táctil) y solo los desactiva cuando la partida está pausada. No se crea un
-- sistema de input paralelo: el HUD de móvil y el mando siguen funcionando igual.
--
-- El ControlModule interno de Roblox avisa ("Player:Move ... no character") si se le
-- pide moverse sin personaje. Con `CharacterAutoLoads = false` ese es justamente el
-- arranque del jugador, así que aquí hay dos defensas:
--   1. Los controles solo se habilitan cuando existe un Humanoid (estado deseado
--      recordado y aplicado en el CharacterAdded).
--   2. Su `moveFunction` se envuelve para que jamás mueva nada sin un Humanoid, lo
--      que cubre también la ventana anterior a que este script pueda desactivarlos.
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local playerModule = require(localPlayer.PlayerScripts:WaitForChild("PlayerModule"))
local controls = playerModule:GetControls()

local function hasHumanoid(): boolean
	local character = localPlayer.Character
	return character ~= nil and character:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Parche del ControlModule: el warning es interno, esto lo corta en la raíz sin
-- cambiar el comportamiento con personaje (el resto de la lógica de movimiento es
-- la original).
local originalMove = controls.moveFunction :: any
if type(originalMove) == "function" then
	controls.moveFunction = function(...)
		if not hasHumanoid() then
			return
		end
		return originalMove(...)
	end
end

-- Esta es la marca: `enabled` es lo que el juego quiere, `applied` es lo que los
-- controles tienen de verdad. Nunca se habilitan sin un Humanoid presente.
local enabled = false
local applied = false

local function apply()
	local shouldEnable = enabled and hasHumanoid()
	if shouldEnable == applied then
		return
	end
	applied = shouldEnable
	if shouldEnable then
		controls:Enable()
	else
		controls:Disable()
	end
end

local RunInput = {}

function RunInput.setEnabled(next: boolean)
	enabled = next
	apply()
end

function RunInput.isEnabled(): boolean
	return enabled
end

-- Al aparecer o desaparecer el personaje se reevalúa el estado deseado (y se apaga
-- al instante al morir, antes de que el ControlModule intente mover a nadie). Se
-- espera al Humanoid: en el CharacterAdded el modelo suele traerlo ya, pero un
-- frame perdido aquí dejaría al jugador sin moverse toda la partida.
localPlayer.CharacterAdded:Connect(function(character: Model)
	if not character:WaitForChild("Humanoid", 10) then
		return
	end
	apply()
end)
localPlayer.CharacterRemoving:Connect(function()
	if applied then
		applied = false
		controls:Disable()
	end
end)

-- Arranque: con `CharacterAutoLoads=false` el jugador aún no tiene personaje, así
-- que los controles empiezan desactivados en lugar de emitir el warning interno.
if localPlayer.Character then
	apply()
else
	controls:Disable()
	applied = false
end

return RunInput
