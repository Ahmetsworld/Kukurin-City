--[[
	LandmarkBuilder.lua
	------------------------------------------------------------------
	Baut die wichtigen Orte: Spawn-Platz, Kukurin-Händler,
	Kukurin Repair Shop und Polizeistation.

	Alles wird in lokalen Koordinaten eines "base"-CFrames gebaut:
	  * Ursprung = Grundstücksmitte (Oberkante)
	  * -Z (LookVector) = Vorderseite, zeigt Richtung Spawn-Platz
	  * +Z = hinterer Teil des Grundstücks

	Spätere Phasen finden ihre Ankerpunkte über Namen:
	  Workspace.Map.Blocks.Block_x_y.<Landmark>.Zone       (Phase 6/7)
	  ...Dealer.Turntable                                  (Phase 6)
	  ...Police.RespawnPoint                               (Phase 8)
	Zusätzlich hat jede Zone das Attribut "Landmark" = Name.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CityLayout = require(ReplicatedStorage.Shared.CityLayout)
local PartFactory = require(script.Parent.PartFactory)
local BuildingKit = require(script.Parent.BuildingKit)

local LandmarkBuilder = {}

------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------

-- Vorderseite zeigt zum Spawn-Platz (auf eine Achse gerundet).
-- Der Spawn-Platz selbst zeigt nach Süden (+Z).
local function computeBase(lotCenter: Vector3): CFrame
	local spawnPos = CityLayout.getLandmarkPosition("Spawn")
	local delta = spawnPos - lotCenter
	local facing
	if delta.Magnitude < 1 then
		facing = Vector3.zAxis
	elseif math.abs(delta.X) >= math.abs(delta.Z) then
		facing = Vector3.new(math.sign(delta.X), 0, 0)
	else
		facing = Vector3.new(0, 0, math.sign(delta.Z))
	end
	return CFrame.lookAt(lotCenter, lotCenter + facing)
end

-- Unsichtbare Zone (später für "Betreten"-Erkennung / ProximityPrompts)
local function zone(parent: Instance, name: string, landmark: string, cframe: CFrame, size: Vector3): BasePart
	local part = PartFactory.part(parent, {
		Name = name,
		Size = size,
		CFrame = cframe,
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	})
	part.CanQuery = false
	part:SetAttribute("Landmark", landmark)
	return part
end

-- Schild auf zwei Pfosten, Text zeigt nach vorne
local function postSign(parent: Instance, base: CFrame, localPos: Vector3, text: string, color: Color3)
	local width, height, postHeight = 34, 7, 10
	for _, x in ipairs({ -width / 2 + 2, width / 2 - 2 }) do
		local foot = (base * CFrame.new(localPos + Vector3.new(x, 0, 0))).Position
		PartFactory.cylinder(parent, "SignPost", postHeight, 1, foot, Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
	end
	local center = (base * CFrame.new(localPos + Vector3.new(0, postHeight + height / 2 - 1, 0))).Position
	PartFactory.sign(parent, text, center, base.LookVector, Vector2.new(width, height), color)
end

-- Schild oben an der Vorderkante eines Gebäudes
local function roofSign(parent: Instance, base: CFrame, frontCenterTop: Vector3, text: string, color: Color3, width: number)
	local center = (base * CFrame.new(frontCenterTop + Vector3.new(0, 4, 0))).Position
	PartFactory.sign(parent, text, center, base.LookVector, Vector2.new(width, 8), color)
end

------------------------------------------------------------------------
-- Einzelne Landmarken
------------------------------------------------------------------------

local function buildSpawn(model: Model, base: CFrame, data)
	-- Springbrunnen in der Mitte
	local center = base.Position
	PartFactory.cylinder(model, "FountainRim", 2.5, 22, center, Color3.fromRGB(200, 200, 210), Enum.Material.Marble)
	PartFactory.part(model, {
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 19, 19),
		CFrame = CFrame.new(center + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(90, 180, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Decor = true,
	})
	PartFactory.cylinder(
		model,
		"FountainPillar",
		7,
		3,
		center + Vector3.new(0, 2.5, 0),
		Color3.fromRGB(200, 200, 210),
		Enum.Material.Marble
	)

	-- Spawnpunkt vor dem Brunnen (Richtung Süden)
	local spawnPart = PartFactory.part(model, {
		Name = "SpawnPoint",
		ClassName = "SpawnLocation",
		Size = Vector3.new(14, 1, 14),
		CFrame = base * CFrame.new(0, 0.5, -28) * CFrame.Angles(0, math.pi, 0),
		Color = data.Color,
		Material = Enum.Material.Neon,
	}) :: SpawnLocation
	spawnPart.Neutral = true
	spawnPart.Duration = 0 -- kein Kraftfeld

	postSign(model, base, Vector3.new(0, 0, -44), data.SignText, data.Color)

	-- Bäume in den Ecken
	local rng = Random.new(Config.Map.Seed + 1)
	for _, offset in ipairs({
		Vector3.new(-38, 0, -38),
		Vector3.new(38, 0, -38),
		Vector3.new(-38, 0, 38),
		Vector3.new(38, 0, 38),
	}) do
		BuildingKit.tree(model, (base * CFrame.new(offset)).Position, rng)
	end

	local marker = zone(model, "Zone", "Spawn", base * CFrame.new(0, 10, 0), Vector3.new(80, 20, 80))
	PartFactory.billboard(marker, data.DisplayName, data.Color, 18)
end

local function buildDealer(model: Model, base: CFrame, data)
	-- Glas-Showroom hinten auf dem Grundstück
	local w, h, d = 64, 20, 36
	local buildingZ = 24
	PartFactory.part(model, {
		Name = "Showroom",
		Size = Vector3.new(w, h, d),
		CFrame = base * CFrame.new(0, h / 2, buildingZ),
		Color = Color3.fromRGB(170, 220, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
	})
	PartFactory.box(
		model,
		"ShowroomRoof",
		Vector3.new(w + 2, 2, d + 2),
		base * CFrame.new(0, h + 1, buildingZ),
		data.Color,
		Enum.Material.SmoothPlastic
	)
	roofSign(model, base, Vector3.new(0, h + 2, buildingZ - d / 2), data.SignText, data.Color, 44)

	-- Drehende Präsentations-Plattform (dreht sich ab Phase 6)
	local turntable = PartFactory.cylinder(
		model,
		"Turntable",
		1,
		26,
		(base * CFrame.new(0, 0, -20)).Position,
		Color3.fromRGB(240, 240, 245),
		Enum.Material.Marble
	)
	turntable:SetAttribute("Landmark", "Dealer")

	local marker = zone(model, "Zone", "Dealer", base * CFrame.new(0, 8, -15), Vector3.new(60, 16, 40))
	PartFactory.billboard(marker, data.DisplayName, data.Color, 22)
end

local function buildRepairShop(model: Model, base: CFrame, data)
	-- Werkstatt mit zwei offenen Toren, in die man hineinfahren kann
	local w, h, d = 60, 18, 40
	local z = 22
	local wallColor = Color3.fromRGB(235, 235, 230)
	local thickness = 2

	-- Rückwand, Seitenwände, Dach
	PartFactory.box(model, "BackWall", Vector3.new(w, h, thickness), base * CFrame.new(0, h / 2, z + d / 2), wallColor)
	for _, x in ipairs({ -w / 2, w / 2 }) do
		PartFactory.box(model, "SideWall", Vector3.new(thickness, h, d), base * CFrame.new(x, h / 2, z), wallColor)
	end
	PartFactory.box(
		model,
		"Roof",
		Vector3.new(w + 2, 2, d + 2),
		base * CFrame.new(0, h + 1, z),
		data.Color,
		Enum.Material.SmoothPlastic
	)

	-- Vorderseite: 3 Pfeiler + Sturz => 2 Tore à 20 Studs
	local pillarWidth = (w - 40) / 3
	for n = 0, 2 do
		local x = -w / 2 + pillarWidth / 2 + n * (pillarWidth + 20)
		PartFactory.box(
			model,
			"Pillar",
			Vector3.new(pillarWidth, h, thickness),
			base * CFrame.new(x, h / 2, z - d / 2),
			data.Color
		)
	end
	PartFactory.box(
		model,
		"Lintel",
		Vector3.new(w, 4, thickness),
		base * CFrame.new(0, h - 2, z - d / 2),
		data.Color
	)
	roofSign(model, base, Vector3.new(0, h + 2, z - d / 2), data.SignText, data.Color, 48)

	-- Ölfleck-Boden in den Toren als Hinweis "hier reinfahren"
	for _, x in ipairs({ -13.3, 13.3 }) do
		PartFactory.part(model, {
			Name = "BayFloor",
			Size = Vector3.new(16, 0.1, d - 4),
			CFrame = base * CFrame.new(x, 0.05, z),
			Color = Color3.fromRGB(90, 90, 100),
			Material = Enum.Material.DiamondPlate,
			Decor = true,
		})
	end

	local marker = zone(model, "Zone", "RepairShop", base * CFrame.new(0, 8, z), Vector3.new(w - 4, 16, d - 4))
	PartFactory.billboard(marker, data.DisplayName, data.Color, 18)
end

local function buildPolice(model: Model, base: CFrame, data)
	local w, h, d = 54, 22, 30
	local z = 26
	PartFactory.box(
		model,
		"Station",
		Vector3.new(w, h, d),
		base * CFrame.new(0, h / 2, z),
		Color3.fromRGB(240, 240, 245),
		Enum.Material.SmoothPlastic
	)
	PartFactory.box(
		model,
		"Stripe",
		Vector3.new(w + 0.4, 3, d + 0.4),
		base * CFrame.new(0, 8, z),
		data.Color,
		Enum.Material.SmoothPlastic
	)
	-- Blaulicht auf dem Dach
	PartFactory.part(model, {
		Name = "RoofLight",
		Size = Vector3.new(6, 2, 3),
		CFrame = base * CFrame.new(0, h + 1, z),
		Color = Color3.fromRGB(40, 120, 255),
		Material = Enum.Material.Neon,
	})
	roofSign(model, base, Vector3.new(0, h, z - d / 2), data.SignText, data.Color, 30)

	-- Parkplatz-Markierungen
	for n = -2, 2 do
		PartFactory.part(model, {
			Name = "ParkingLine",
			Size = Vector3.new(0.6, 0.05, 16),
			CFrame = base * CFrame.new(n * 12, 0.025, -6),
			Color = Color3.new(1, 1, 1),
			Decor = true,
		})
	end

	-- Respawn-Punkt nach Festnahme (Phase 8)
	local respawn = PartFactory.part(model, {
		Name = "RespawnPoint",
		Size = Vector3.new(4, 1, 4),
		CFrame = base * CFrame.new(0, 0.5, -30),
		Transparency = 1,
		CanCollide = false,
		Decor = true,
	})
	respawn:SetAttribute("Landmark", "Police")

	local marker = zone(model, "Zone", "Police", base * CFrame.new(0, 8, -10), Vector3.new(60, 16, 40))
	PartFactory.billboard(marker, data.DisplayName, data.Color, 22)
end

local BUILDERS = {
	Spawn = buildSpawn,
	Dealer = buildDealer,
	RepairShop = buildRepairShop,
	Police = buildPolice,
}

------------------------------------------------------------------------
-- Öffentliche API
------------------------------------------------------------------------

function LandmarkBuilder.build(name: string, blockModel: Model, lotCenter: Vector3)
	local data = Config.Landmarks[name]
	local builder = BUILDERS[name]
	assert(data and builder, "[LandmarkBuilder] Unbekannte Landmarke " .. tostring(name))

	local base = computeBase(lotCenter)

	-- Asset-Hook: ein fertiges Model "Landmark_<Name>" ersetzt den Platzhalter
	local asset = PartFactory.tryAsset("Landmark_" .. name, base, blockModel)
	if asset then
		asset.Name = name
		return asset
	end

	local model = PartFactory.model(blockModel, name)
	model:SetAttribute("Landmark", name)
	builder(model, base, data)
	return model
end

return LandmarkBuilder
