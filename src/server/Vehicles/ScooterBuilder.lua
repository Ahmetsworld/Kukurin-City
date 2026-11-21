--[[
	ScooterBuilder.lua
	------------------------------------------------------------------
	Baut einen Kukurin-E-Scooter aus Parts.

	Aufbau (Namen sind wichtig, Client und Server suchen danach):
	  Model "<Spieler>_Kukurin"          PrimaryPart = Body
	    Body        unsichtbare Hitbox, einziger kollidierender Part,
	                trägt die Masse. Darin:
	      Center (Attachment), Drive (VectorForce), Upright (AlignOrientation),
	      Horn (Sound)
	    Seat        VehicleSeat (liefert Throttle/Steer von Tastatur,
	                Gamepad und Handy-Thumbstick)
	    Visual/...  reine Optik: Trittbrett, Lenker, Räder, Augen ...
	                Massless, keine Kollision (Phase 3 lässt Teile abfallen)

	Lokale Achsen: -Z = vorne (LookVector), +Y = oben.
	Body-Mitte liegt RideHeight Studs über dem Boden (Attribut "RideHeight").

	Asset-Hook: Ein Model "Scooter_<ModelId>" in ServerStorage/Assets
	ersetzt die Optik. Es braucht dieselben Namen (Body, Seat) und wird
	genauso verschweißt.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PartFactory = require(script.Parent.Parent.Map.PartFactory)

local Physics = Config.VehiclePhysics
local Brand = Config.Brand

local ScooterBuilder = {}

local BASE_WHEEL_DIAMETER = 1.8

-- Alle Teile an den Body schweißen und physikalisch vorbereiten
local function finalize(model: Model, body: BasePart)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			if part ~= body then
				part.Massless = true
				part.CanCollide = false
				part.CanQuery = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
end

-- Kraft-Objekte im Body anlegen (der Client-Fahrcontroller steuert sie)
local function addPhysicsObjects(body: BasePart)
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = body

	local drive = Instance.new("VectorForce")
	drive.Name = "Drive"
	drive.Attachment0 = center
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.ApplyAtCenterOfMass = true
	drive.Force = Vector3.zero
	drive.Parent = body

	local upright = Instance.new("AlignOrientation")
	upright.Name = "Upright"
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.Attachment0 = center
	upright.MaxTorque = 1e7
	upright.Responsiveness = Physics.UprightResponsiveness
	upright.CFrame = CFrame.new()
	upright.Parent = body

	local horn = Instance.new("Sound")
	horn.Name = "Horn"
	horn.SoundId = Config.Sounds.Horn
	horn.Volume = Config.Sounds.HornVolume
	horn.RollOffMaxDistance = 250
	horn.Parent = body
end

-- Rad = Reifen + Felge (Zylinder liegen auf der X-Achse = Radachse)
local function wheel(parent: Instance, name: string, center: Vector3, diameter: number, rimColor: Color3)
	PartFactory.part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6 * math.max(1, diameter / BASE_WHEEL_DIAMETER * 0.8), diameter, diameter),
		CFrame = CFrame.new(center),
		Color = Brand.Dark,
		Material = Enum.Material.SmoothPlastic,
	})
	PartFactory.part(parent, {
		Name = name .. "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7 * math.max(1, diameter / BASE_WHEEL_DIAMETER * 0.8), diameter * 0.55, diameter * 0.55),
		CFrame = CFrame.new(center),
		Color = rimColor,
		Material = Enum.Material.SmoothPlastic,
	})
end

-- Optik aus Parts. Alle Positionen relativ zur Body-Mitte (0, 0, 0).
local function buildVisual(model: Model, stats, rideHeight: number)
	local colors = stats.Colors
	local visual = PartFactory.folder(model, "Visual")

	local diameter = BASE_WHEEL_DIAMETER * stats.WheelScale
	local radius = diameter / 2
	local groundY = -rideHeight
	local axleY = groundY + radius
	local wheelZ = math.max(2.6, radius + 1.7)

	-- Räder
	wheel(visual, "FrontWheel", Vector3.new(0, axleY, -wheelZ), diameter, colors.Rim)
	wheel(visual, "RearWheel", Vector3.new(0, axleY, wheelZ), diameter, colors.Rim)

	-- Trittbrett mit Zierstreifen
	local deckLength = wheelZ * 2 - 0.4
	PartFactory.box(visual, "Deck", Vector3.new(1.8, 0.35, deckLength), CFrame.new(0, axleY, 0), colors.Body)
	PartFactory.box(
		visual,
		"DeckStripe",
		Vector3.new(0.6, 0.05, deckLength - 0.8),
		CFrame.new(0, axleY + 0.2, 0),
		colors.Accent
	)

	-- Schutzbleche
	for _, z in ipairs({ -wheelZ, wheelZ }) do
		PartFactory.box(
			visual,
			"Fender",
			Vector3.new(0.9, 0.2, diameter * 0.8),
			CFrame.new(0, axleY + radius + 0.15, z),
			colors.Accent
		)
	end

	-- Lenkstange und Lenker
	local stemZ = -wheelZ + 0.2
	local barY = axleY + 3.3
	local stemHeight = barY - axleY
	PartFactory.box(
		visual,
		"Stem",
		Vector3.new(0.4, stemHeight, 0.4),
		CFrame.new(0, axleY + stemHeight / 2, stemZ),
		colors.Body
	)
	PartFactory.box(visual, "Handlebar", Vector3.new(3, 0.3, 0.3), CFrame.new(0, barY, stemZ), colors.Body)
	for _, x in ipairs({ -1.4, 1.4 }) do
		PartFactory.box(visual, "Grip", Vector3.new(0.6, 0.4, 0.4), CFrame.new(x, barY, stemZ), colors.Accent)
	end

	-- Markenzeichen: das Kukurin-Gesicht (Scheinwerfer-Augen + Grinsen)
	local faceY = barY - 0.9
	local faceZ = stemZ - 0.3
	PartFactory.box(visual, "FacePlate", Vector3.new(1.4, 1.1, 0.2), CFrame.new(0, faceY, faceZ + 0.05), colors.Accent)
	for _, x in ipairs({ -0.33, 0.33 }) do
		local eye = PartFactory.ball(visual, "Eye", 0.55, Vector3.new(x, faceY + 0.15, faceZ - 0.1), Brand.Light)
		eye.Material = Enum.Material.Neon
		PartFactory.ball(visual, "Pupil", 0.25, Vector3.new(x, faceY + 0.15, faceZ - 0.33), Brand.Dark)
	end
	PartFactory.box(visual, "Smile", Vector3.new(0.6, 0.12, 0.1), CFrame.new(0, faceY - 0.3, faceZ - 0.05), Brand.Dark)

	-- Sitzstange (der Sitz selbst ist der VehicleSeat)
	local seatZ = wheelZ * 0.55
	local seatTopY = axleY + 1.7
	PartFactory.box(
		visual,
		"SeatPost",
		Vector3.new(0.3, seatTopY - axleY, 0.3),
		CFrame.new(0, (seatTopY + axleY) / 2, seatZ),
		Brand.Dark
	)

	-- Rücklicht
	PartFactory.part(visual, {
		Name = "TailLight",
		Size = Vector3.new(0.6, 0.25, 0.1),
		CFrame = CFrame.new(0, axleY + radius + 0.15, wheelZ + diameter * 0.4),
		Color = Color3.fromRGB(255, 60, 90),
		Material = Enum.Material.Neon,
	})

	return seatZ, seatTopY, wheelZ, radius
end

--[[
	Baut den Scooter am Ursprung. Aufrufer setzt danach PivotTo + Parent.
	modelId = Schlüssel in Config.Vehicles
]]
function ScooterBuilder.build(modelId: string): Model
	local stats = Config.Vehicles[modelId]
	assert(stats, "[ScooterBuilder] Unbekanntes Modell " .. tostring(modelId))

	local diameter = BASE_WHEEL_DIAMETER * stats.WheelScale
	local rideHeight = Physics.RideHeight + (diameter - BASE_WHEEL_DIAMETER) / 2

	local model = Instance.new("Model")
	model.Name = "Kukurin_" .. modelId
	model:SetAttribute("ModelId", modelId)
	model:SetAttribute("RideHeight", rideHeight)

	-- Hitbox (Länge passt sich der Radgröße an)
	local wheelZ = math.max(2.6, diameter / 2 + 1.7)
	local body = PartFactory.part(model, {
		Name = "Body",
		Size = Vector3.new(2.2, 1.4, wheelZ * 2 + diameter * 0.8),
		CFrame = CFrame.new(),
		Transparency = 1,
	})
	body.CustomPhysicalProperties = PhysicalProperties.new(2, 0.05, 0.2, 1, 1)
	model.PrimaryPart = body

	local seatZ, seatTopY
	local assets = ServerStorage:FindFirstChild("Assets")
	local asset = assets and assets:FindFirstChild("Scooter_" .. modelId)
	if asset then
		-- Fertige Optik aus Assets: alles außer Body/Seat übernehmen
		local visual = asset:Clone()
		visual.Name = "Visual"
		visual:PivotTo(CFrame.new())
		visual.Parent = model
		local seatMarker = visual:FindFirstChild("Seat", true)
		seatZ = seatMarker and seatMarker.Position.Z or 1.4
		seatTopY = seatMarker and seatMarker.Position.Y or 0.8
		if seatMarker then
			seatMarker:Destroy()
		end
	else
		seatZ, seatTopY = buildVisual(model, stats, rideHeight)
	end

	-- Sitz (VehicleSeat). Torque/MaxSpeed = 0: Er treibt nichts selbst an,
	-- er liefert nur die Eingaben (ThrottleFloat / SteerFloat).
	local seat = PartFactory.part(model, {
		Name = "Seat",
		ClassName = "VehicleSeat",
		Size = Vector3.new(1.4, 0.3, 1.6),
		CFrame = CFrame.new(0, seatTopY, seatZ),
		Color = stats.Colors.Accent,
	}) :: VehicleSeat
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false

	addPhysicsObjects(body)
	finalize(model, body)
	-- Der Sitz muss Berührungen erkennen, damit man sich draufsetzen kann
	seat.CanTouch = true

	return model
end

return ScooterBuilder
