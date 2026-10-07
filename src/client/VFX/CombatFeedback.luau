--!strict
-- Feedback visual de combate. Vive en el cliente a propósito: el servidor ya decidió
-- el impacto y solo manda un aviso descartable. Los emisores, los rayos y los anillos
-- están en pool y se reciclan con un reloj, así que un impacto no crea ni destruye
-- instancias ni lanza una tarea por evento.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIKit = require(script.Parent.Parent.UI.UIKit)

local POOL_SIZE = 14
local BEAM_POOL_SIZE = 12
local RING_POOL_SIZE = 6
local BUSY_SECONDS = 0.6

-- Colores de presentación de cada efecto.
local BOLT = Color3.fromRGB(255, 246, 220)
local CRIT = Color3.fromRGB(255, 208, 96)
local DEATH = Color3.fromRGB(226, 96, 96)
local BLAST = Color3.fromRGB(255, 158, 66)
local NOVA = Color3.fromRGB(126, 208, 255)
local CHAIN = Color3.fromRGB(150, 226, 255)
local SLASH = Color3.fromRGB(224, 242, 255)

type Burst = {
	Part: Part,
	Emitter: ParticleEmitter,
	BusyUntil: number,
}

-- Un rayo es un Beam con dos attachments sobre una pieza ancla. Los attachments se
-- posicionan en el mundo (el CFrame de Attachment es mundial), así que el ancla solo
-- da un hogar y el Beam se dibuja exactamente entre los dos puntos pedidos.
type BeamFX = {
	Part: Part,
	Beam: Beam,
	Attach0: Attachment,
	Attach1: Attachment,
	BusyUntil: number,
	FadeStart: number,
	FadeDuration: number,
	FadeFrom: number,
}

-- Anillo expansivo (onda de choque): un cilindro delgado que crece en el suelo y se
-- funde. Lo comparten la Nova y las explosiones para darle volumen al impacto.
type Ring = {
	Part: Part,
	BusyUntil: number,
	StartAt: number,
	Radius: number,
	FadeFrom: number,
}

local bursts: { Burst } = {}
local beams: { BeamFX } = {}
local rings: { Ring } = {}
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

local function buildBeam(): BeamFX
	local part = Instance.new("Part")
	part.Name = "BeamAnchor"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = workspace

	local attach0 = Instance.new("Attachment")
	attach0.Name = "Attach0"
	local attach1 = Instance.new("Attachment")
	attach1.Name = "Attach1"

	local beam = Instance.new("Beam")
	beam.Name = "Beam"
	beam.Attachment0 = attach0
	beam.Attachment1 = attach1
	beam.Color = ColorSequence.new(CHAIN)
	beam.Transparency = NumberSequence.new(0.2)
	beam.Width0 = 0.45
	beam.Width1 = 0.45
	beam.FaceCamera = true
	beam.LightEmission = 0.8
	beam.Brightness = 2
	beam.Enabled = false
	beam.Parent = part
	attach0.Parent = part
	attach1.Parent = part

	return {
		Part = part,
		Beam = beam,
		Attach0 = attach0,
		Attach1 = attach1,
		BusyUntil = 0,
		FadeStart = 0,
		FadeDuration = 0,
		FadeFrom = 0,
	}
end

local function buildRing(): Ring
	local part = Instance.new("Part")
	part.Name = "Shockwave"
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = NOVA
	part.Size = Vector3.new(0.3, 0.1, 0.3)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = workspace
	return { Part = part, BusyUntil = 0, StartAt = 0, Radius = 0, FadeFrom = 0 }
end

local CombatFeedback = {}

function CombatFeedback.build()
	for index = 1, POOL_SIZE do
		bursts[index] = buildBurst(BOLT)
	end
	for index = 1, BEAM_POOL_SIZE do
		beams[index] = buildBeam()
	end
	for index = 1, RING_POOL_SIZE do
		rings[index] = buildRing()
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
			if beam.BusyUntil > 0 then
				if now >= beam.BusyUntil then
					beam.Beam.Enabled = false
					beam.BusyUntil = 0
				else
					-- Fade-out manual: TweenService no puede animar NumberSequence.
					local t = (now - beam.FadeStart) / beam.FadeDuration
					local alpha = beam.FadeFrom + (1 - beam.FadeFrom) * t
					beam.Beam.Transparency = NumberSequence.new(alpha)
				end
			end
		end

		for _, ring in rings do
			if ring.BusyUntil > 0 then
				if now >= ring.BusyUntil then
					ring.Part.Transparency = 1
					ring.BusyUntil = 0
				else
					local duration = ring.BusyUntil - ring.StartAt
					local t = (now - ring.StartAt) / math.max(duration, 0.001)
					-- Ease-out quad: crece rápido al contacto y frena, como una onda
					-- que pierde empuje. Deja el anillo en 1 solo perfil robusto.
					local eased = 1 - (1 - t) * (1 - t)
					local diameter = ring.Radius * 2 * eased + 0.3
					ring.Part.Size = Vector3.new(diameter, 0.1, diameter)
					ring.Part.Transparency = ring.FadeFrom + (1 - ring.FadeFrom) * t
				end
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

-- Rayo entre dos puntos (cadena o slash). Empieza con un alfa inicial y se funde
-- hasta opaco antes de apagarse; el beam vuelve al pool al llegar a cero su reloj.
local function beamBetween(from: Vector3, to: Vector3, color: Color3, width: number, fadeDuration: number)
	if (to - from).Magnitude < 0.05 then
		return
	end

	local now = os.clock()
	for _, beam in beams do
		if beam.BusyUntil <= now then
			beam.Beam.Enabled = true
			beam.Beam.Color = ColorSequence.new(color)
			beam.Beam.Width0 = width
			beam.Beam.Width1 = width
			beam.Part.CFrame = CFrame.new((from + to) * 0.5)
			beam.Attach0.CFrame = CFrame.new(from)
			beam.Attach1.CFrame = CFrame.new(to)
			-- Los efectos fugaces (slash) nacen más transparentes que el rayo.
			beam.FadeFrom = if fadeDuration > 0.06 then 0.14 else 0.3
			beam.FadeStart = now
			beam.FadeDuration = fadeDuration
			beam.BusyUntil = now + fadeDuration
			return
		end
	end
end

-- Anillo expansivo sobre un punto del suelo. La Y la manda el servidor (ras de
-- suelo) y el cilindro crece en el plano XZ.
local function playRing(position: Vector3, radius: number, color: Color3, duration: number, fadeFrom: number)
	local now = os.clock()
	for _, ring in rings do
		if ring.BusyUntil <= now then
			ring.BusyUntil = now + duration
			ring.StartAt = now
			ring.Radius = radius
			ring.FadeFrom = fadeFrom
			ring.Part.Color = color
			ring.Part.Transparency = fadeFrom
			ring.Part.Position = Vector3.new(position.X, position.Y + 0.04, position.Z)
			ring.Part.Size = Vector3.new(0.3, 0.1, 0.3)
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

-- El servidor manda `magnitude` como radios o conteos segun el tipo; el cliente solo
-- decide cómo se ve. `target` lo usan los efectos que unen dos puntos.
function CombatFeedback.play(kind: string, position: Vector3, magnitude: number, target: Vector3?)
	if kind == "hit" then
		local crit = magnitude > 1
		emit(position, if crit then 10 else 5, if crit then CRIT else BOLT)
	elseif kind == "death" then
		emit(position, 16, DEATH)
	elseif kind == "explosion" then
		-- Silueta clara primero: núcleo brillante y luego la onda que se expande.
		local scale = math.clamp(magnitude / 8, 0.6, 2)
		emit(position, math.round(22 * scale), BLAST)
		playRing(position, magnitude * 1.1, BLAST, 0.4, 0.12)
	elseif kind == "nova" then
		-- Chispazo central + el anillo de choque que empuja a la horda.
		local scale = math.clamp(magnitude / 8, 0.6, 2)
		emit(position, math.round(14 * scale), NOVA)
		playRing(position, magnitude, NOVA, 0.45, 0.3)
	elseif kind == "chain" then
		-- Eco en el origen del salto y chispazo en el impacto (target); el primer
		-- rayo nace en el arma del jugador, así que siempre hay un segmento visible.
		emit(position, 3, CHAIN)
		if target then
			emit(target, 6, CHAIN)
			beamBetween(position, target, CHAIN, 0.45, 0.24)
		end
	elseif kind == "slash" then
		-- Arco de corte de la cuchilla: rayo fino, breve y brillante.
		emit(position, 4, SLASH)
		if target then
			beamBetween(position, target, SLASH, 0.12, 0.12)
		end
	elseif kind == "playerHurt" then
		playFlash()
	end
end

return CombatFeedback
