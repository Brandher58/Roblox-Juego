--!strict
-- Feedback visual de combate. Vive en el cliente a propósito: el servidor ya decidió
-- el impacto y solo manda un aviso descartable. Los emisores y los rayos están en pool
-- y se reciclan con un reloj, así que un impacto no crea ni destruye instancias ni
-- lanza una tarea por evento.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIKit = require(script.Parent.Parent.UI.UIKit)

local POOL_SIZE = 14
local BEAM_POOL_SIZE = 12
local BUSY_SECONDS = 0.6
local BEAM_BUSY_SECONDS = 0.16

type Burst = {
	Part: Part,
	Emitter: ParticleEmitter,
	BusyUntil: number,
}

type Beam = {
	Part: Part,
	BusyUntil: number,
}

local bursts: { Burst } = {}
local beams: { Beam } = {}
local flash: Frame? = nil
local flashTween: Tween? = nil

local function buildBurst(color: Color3): Burst
	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.3, 0.55)
	emitter.Speed = NumberRange.new(6, 13)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.6
	emitter.Parent = part

	return { Part = part, Emitter = emitter, BusyUntil = 0 }
end

local function buildBeam(): Beam
	local part = Instance.new("Part")
	part.Name = "ChainBeam"
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(150, 226, 255)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = workspace
	return { Part = part, BusyUntil = 0 }
end

local CombatFeedback = {}

function CombatFeedback.build()
	for index = 1, POOL_SIZE do
		bursts[index] = buildBurst(Color3.fromRGB(255, 236, 190))
	end
	for index = 1, BEAM_POOL_SIZE do
		beams[index] = buildBeam()
	end

	local gui = UIKit.screen("CombatFeedback", 25)
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 25
	flash = UIKit.frame(
		gui,
		"Flash",
		UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0),
		nil,
		Color3.fromRGB(200, 40, 40)
	)
	flash.BackgroundTransparency = 1

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, burst in bursts do
			if burst.BusyUntil > 0 and now >= burst.BusyUntil then
				burst.BusyUntil = 0
				burst.Part.Transparency = 1
			end
		end
		for _, beam in beams do
			if beam.BusyUntil > 0 and now >= beam.BusyUntil then
				beam.BusyUntil = 0
				beam.Part.Transparency = 1
			end
		end
	end)
end

local function emit(position: Vector3, count: number, color: Color3)
	local now = os.clock()
	for _, burst in bursts do
		if burst.BusyUntil <= now then
			burst.BusyUntil = now + BUSY_SECONDS
			burst.Part.CFrame = CFrame.new(position)
			burst.Emitter.Color = ColorSequence.new(color)
			burst.Emitter:Emit(count)
			return
		end
	end
end

-- Rayo entre dos puntos del salto de la cadena. La pieza se estira a lo largo de Z y
-- se orienta con lookAt, así que el grosor y la longitud son el mismo CFrame.
local function beamBetween(from: Vector3, to: Vector3)
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.05 then
		return
	end

	local now = os.clock()
	for _, beam in beams do
		if beam.BusyUntil <= now then
			beam.BusyUntil = now + BEAM_BUSY_SECONDS
			beam.Part.Size = Vector3.new(0.35, 0.35, length)
			beam.Part.CFrame = CFrame.lookAt(from, to)
			beam.Part.Transparency = 0.15
			return
		end
	end
end

local function playFlash()
	if not flash then
		return
	end
	if flashTween then
		flashTween:Cancel()
	end
	flash.BackgroundTransparency = 0.55
	flashTween = TweenService:Create(
		flash,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	flashTween:Play()
end

local BOLT = Color3.fromRGB(255, 246, 220)
local CRIT = Color3.fromRGB(255, 208, 96)
local DEATH = Color3.fromRGB(226, 96, 96)
local BLAST = Color3.fromRGB(255, 158, 66)
local NOVA = Color3.fromRGB(126, 208, 255)

-- El servidor manda `magnitude` como radios o conteos segun el tipo; el cliente solo
-- decide como se ve. `target` solo lo usan los efectos que unen dos puntos.
function CombatFeedback.play(kind: string, position: Vector3, magnitude: number, target: Vector3?)
	if kind == "hit" then
		local crit = magnitude > 1
		emit(position, if crit then 10 else 5, if crit then CRIT else BOLT)
	elseif kind == "death" then
		emit(position, 16, DEATH)
	elseif kind == "explosion" then
		local scale = math.clamp(magnitude / 8, 0.6, 2)
		emit(position, math.round(18 * scale), BLAST)
	elseif kind == "nova" then
		local scale = math.clamp(magnitude / 8, 0.6, 2)
		emit(position, math.round(14 * scale), NOVA)
	elseif kind == "chain" then
		emit(position, 5, Color3.fromRGB(150, 226, 255))
		if target then
			beamBetween(position, target)
		end
	elseif kind == "playerHurt" then
		playFlash()
	end
end

return CombatFeedback
