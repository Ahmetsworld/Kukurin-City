--[[
	BlockBuilder.lua
	------------------------------------------------------------------
	Baut alle Stadtblöcke: Bürgersteig, Grundstück und die
	Platzhalter-Bebauung passend zum Stadtteil.
	Blöcke mit einer Landmarke werden an LandmarkBuilder übergeben.

	Jeder Block wird ein Model "Block_<col>_<row>" mit den Attributen
	Col, Row, District (und Landmark, falls vorhanden). KI und Minimap
	können sich daran orientieren.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CityLayout = require(ReplicatedStorage.Shared.CityLayout)
local PartFactory = require(script.Parent.PartFactory)
local BuildingKit = require(script.Parent.BuildingKit)
local LandmarkBuilder = require(script.Parent.LandmarkBuilder)

local M = Config.Map
local pick = BuildingKit.pick

local COLOR_SIDEWALK = Color3.fromRGB(205, 200, 190)

local BlockBuilder = {}

------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------

-- Richtung von der Blockmitte zur nächsten Straße, damit Häuser
-- mit der Vorderseite zur Straße zeigen.
local function facingToStreet(localOffset: Vector3): Vector3
	if math.abs(localOffset.X) > math.abs(localOffset.Z) then
		return Vector3.new(math.sign(localOffset.X), 0, 0)
	end
	return Vector3.new(0, 0, if localOffset.Z == 0 then 1 else math.sign(localOffset.Z))
end

-- CFrame am Boden, Vorderseite (LookVector) zeigt in Richtung facing
local function groundCFrame(position: Vector3, facing: Vector3): CFrame
	return CFrame.lookAt(position, position + facing)
end

-- 2x2-Raster von Zellmitten (relativ zur Grundstücksmitte)
local function quadrantOffsets(spacing: number): { Vector3 }
	local h = spacing / 2
	return {
		Vector3.new(-h, 0, -h),
		Vector3.new(h, 0, -h),
		Vector3.new(-h, 0, h),
		Vector3.new(h, 0, h),
	}
end

------------------------------------------------------------------------
-- Stadtteile
------------------------------------------------------------------------

local function buildDowntown(model: Model, lotCenter: Vector3, rng: Random)
	local d = Config.Districts.D
	local cell = CityLayout.LotSize / 2
	for _, offset in ipairs(quadrantOffsets(cell)) do
		local footprint = Vector2.new(rng:NextNumber(cell * 0.6, cell * 0.8), rng:NextNumber(cell * 0.6, cell * 0.8))
		local height = rng:NextInteger(d.TowerHeight[1], d.TowerHeight[2])
		local pos = lotCenter + offset
		BuildingKit.tower(
			model,
			groundCFrame(pos, facingToStreet(offset)),
			footprint,
			height,
			pick(rng, d.TowerColors),
			d.WindowColor
		)
	end
end

local function buildResidential(model: Model, lotCenter: Vector3, rng: Random)
	local d = Config.Districts.W
	local cell = CityLayout.LotSize / 2
	for _, offset in ipairs(quadrantOffsets(cell)) do
		-- Haus Richtung Straße schieben, dahinter bleibt Platz für den Garten
		local facing = facingToStreet(offset)
		local pos = lotCenter + offset + facing * 6
		BuildingKit.house(model, groundCFrame(pos, facing), pick(rng, d.HouseColors), pick(rng, d.RoofColors))

		-- Gartenbaum hinter dem Haus
		local treePos = lotCenter + offset - facing * 14 + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
		BuildingKit.tree(model, treePos, rng)
	end
end

local function buildIndustrial(model: Model, lotCenter: Vector3, rng: Random)
	local d = Config.Districts.I
	local size = Vector3.new(rng:NextNumber(55, 75), rng:NextNumber(18, 26), rng:NextNumber(35, 45))
	local hallPos = lotCenter + Vector3.new(0, 0, -18)
	BuildingKit.warehouse(model, groundCFrame(hallPos, Vector3.new(0, 0, 1)), size, pick(rng, d.HallColors))

	-- Container-Reihe im Hof
	for n = 0, 3 do
		local pos = lotCenter + Vector3.new(-30 + n * 12, 0, 30)
		BuildingKit.container(model, groundCFrame(pos, Vector3.new(0, 0, 1)), pick(rng, d.ContainerColors))
	end
end

local function buildPark(model: Model, lotCenter: Vector3, rng: Random)
	local d = Config.Districts.P
	local half = CityLayout.LotSize / 2

	-- Wege als Kreuz
	for _, size in ipairs({ Vector3.new(CityLayout.LotSize, 0.1, 8), Vector3.new(8, 0.1, CityLayout.LotSize) }) do
		PartFactory.part(model, {
			Name = "Path",
			Size = size,
			CFrame = CFrame.new(lotCenter + Vector3.new(0, 0.05, 0)),
			Color = Color3.fromRGB(225, 205, 150),
			Material = Enum.Material.Sand,
			Decor = true,
		})
	end

	-- Teich in einem zufälligen Viertel
	local pondOffset = quadrantOffsets(half)[rng:NextInteger(1, 4)]
	PartFactory.part(model, {
		Name = "Pond",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 26, 26),
		CFrame = CFrame.new(lotCenter + pondOffset + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(80, 170, 230),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		Decor = true,
	})

	-- Bäume, nicht auf Wegen und nicht im Teich
	local placed = 0
	local attempts = 0
	while placed < d.TreeCount and attempts < 100 do
		attempts += 1
		local offset = Vector3.new(rng:NextNumber(-half + 6, half - 6), 0, rng:NextNumber(-half + 6, half - 6))
		local onPath = math.abs(offset.X) < 8 or math.abs(offset.Z) < 8
		local inPond = (offset - pondOffset).Magnitude < 18
		if not onPath and not inPond then
			BuildingKit.tree(model, lotCenter + offset, rng)
			placed += 1
		end
	end
end

local function buildStuntZone(model: Model, lotCenter: Vector3, rng: Random)
	local d = Config.Districts.S
	-- Ein paar Rampen mit zufälliger Ausrichtung (Platzhalter, Phase 9 baut aus)
	local directions = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }
	for _, offset in ipairs(quadrantOffsets(CityLayout.LotSize / 2)) do
		local size = Vector3.new(14, rng:NextNumber(4, 9), rng:NextNumber(18, 26))
		BuildingKit.ramp(model, groundCFrame(lotCenter + offset, pick(rng, directions)), size, d.RampColor)
	end
end

local DISTRICT_BUILDERS = {
	D = buildDowntown,
	W = buildResidential,
	I = buildIndustrial,
	P = buildPark,
	S = buildStuntZone,
}

------------------------------------------------------------------------
-- Block (Bürgersteig + Grundstück + Inhalt)
------------------------------------------------------------------------

local function buildBlock(parent: Instance, col: number, row: number, rng: Random)
	local districtKey = CityLayout.getDistrictKey(col, row)
	local landmark = CityLayout.getLandmarkAt(col, row)
	local district = Config.Districts[districtKey]

	local model = PartFactory.model(parent, ("Block_%d_%d"):format(col, row))
	model:SetAttribute("Col", col)
	model:SetAttribute("Row", row)
	model:SetAttribute("District", districtKey)
	if landmark then
		model:SetAttribute("Landmark", landmark)
	end

	local center = CityLayout.blockCenter(col, row)

	-- Bürgersteig: eine Platte über den ganzen Block
	PartFactory.part(model, {
		Name = "Sidewalk",
		Size = Vector3.new(M.BlockSize, M.SidewalkHeight, M.BlockSize),
		CFrame = CFrame.new(center + Vector3.new(0, M.SidewalkHeight / 2, 0)),
		Color = COLOR_SIDEWALK,
		Material = Enum.Material.Concrete,
	})

	-- Grundstück: etwas höher als der Bürgersteig, darum kein Flimmern
	local lotHeight = CityLayout.LotTopY
	local lotColor = if landmark then Color3.fromRGB(215, 210, 200) else district.LotColor
	local lotMaterial = if landmark then Enum.Material.Slate else district.LotMaterial
	PartFactory.part(model, {
		Name = "Lot",
		Size = Vector3.new(CityLayout.LotSize, lotHeight, CityLayout.LotSize),
		CFrame = CFrame.new(center + Vector3.new(0, lotHeight / 2, 0)),
		Color = lotColor,
		Material = lotMaterial,
	})

	local lotCenter = CityLayout.lotCenter(col, row)
	if landmark then
		LandmarkBuilder.build(landmark, model, lotCenter)
	else
		DISTRICT_BUILDERS[districtKey](model, lotCenter, rng)
	end
end

function BlockBuilder.build(parent: Instance)
	local blocks = PartFactory.folder(parent, "Blocks")
	local rng = Random.new(M.Seed)

	for row = 1, M.BlocksZ do
		for col = 1, M.BlocksX do
			buildBlock(blocks, col, row, rng)
		end
	end

	return blocks
end

return BlockBuilder
