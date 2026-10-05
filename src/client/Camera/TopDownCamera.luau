--!strict
-- Cámara top-down isométrica ligera. Scriptable para que el motor no la sobrescriba,
-- y PreRender (nunca Heartbeat) para que la imagen vaya sincronizada con el frame.
-- No lee nada de la partida: sigue al personaje, y el servidor decide dónde está.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local localPlayer = game:GetService("Players").LocalPlayer
local camera = workspace.CurrentCamera

local connection: RBXScriptConnection? = nil

local TopDownCamera = {}

function TopDownCamera.start()
	if connection or not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.Camera.FieldOfView

	connection = RunService.PreRender:Connect(function(dt)
		local character = localPlayer.Character
		if not character then
			return
		end

		-- CameraSubject solo no puede ser nil: ponerlo lo revierte al anterior.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end

		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end

		local focus = root.Position
		local goal = CFrame.lookAt(focus + Config.Camera.Offset, focus)
		camera.CFrame = camera.CFrame:Lerp(goal, math.min(dt * Config.Camera.Smoothing, 1))
	end)
end

function TopDownCamera.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return TopDownCamera
