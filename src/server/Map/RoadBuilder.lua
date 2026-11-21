--[[
	RoadBuilder.lua
	------------------------------------------------------------------
	Baut den Boden der Stadt:
	  * Grasfläche rund um die Stadt
	  * eine große Asphaltplatte unter dem ganzen Stadtgebiet
	    (die Straßen sind einfach die Lücken zwischen den Blöcken)
	  * gestrichelte Mittellinien
	  * Zebrastreifen vor jeder Kreuzung (nur Innenstraßen)

	Markierungen sind "Decor": keine Kollision, keine Abfragen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CityLayout = require(ReplicatedStorage.Shared.CityLayout)
local PartFactory = require(script.Parent.PartFactory)

local M = Config.Map

local COLOR_ASPHALT = Color3.fromRGB(55, 55, 62)
local COLOR_GRASS = Color3.fromRGB(100, 180, 80)
local COLOR_MARKING = Color3.fromRGB(245, 245, 245)

local RoadBuilder = {}

local function buildGround(parent: Instance)
	-- Gras: etwas tiefer als der Asphalt, damit nichts flimmert (Z-Fighting)
	PartFactory.part(parent, {
		Name = "Grass",
		Size = Vector3.new(M.GroundSize, 2, M.GroundSize),
		CFrame = CFrame.new(0, -1.05, 0),
		Color = COLOR_GRASS,
		Material = Enum.Material.Grass,
	})

	-- Asphalt: Oberkante exakt bei y = 0
	PartFactory.part(parent, {
		Name = "Asphalt",
		Size = Vector3.new(CityLayout.Width, 2, CityLayout.Depth),
		CFrame = CFrame.new(0, -1, 0),
		Color = COLOR_ASPHALT,
		Material = Enum.Material.Asphalt,
	})
end

-- Flache Markierung auf der Fahrbahn. dir = Längsrichtung der Markierung.
local function marking(parent: Instance, name: string, position: Vector3, dir: Vector3, width: number, length: number)
	local pos = position + Vector3.new(0, M.MarkingHeight / 2, 0)
	PartFactory.part(parent, {
		Name = name,
		Size = Vector3.new(width, M.MarkingHeight, length),
		CFrame = CFrame.lookAt(pos, pos + dir),
		Color = COLOR_MARKING,
		Material = Enum.Material.SmoothPlastic,
		Decor = true,
	})
end

local function buildCenterLine(parent: Instance, segment)
	-- Platz für die Zebrastreifen an beiden Enden freilassen
	local margin = M.ZebraInset + M.ZebraDepth + 2
	local usable = segment.Length - 2 * margin
	local period = M.DashLength + M.DashGap
	local count = math.max(1, math.floor((usable + M.DashGap) / period))
	local totalLength = count * period - M.DashGap
	local start = -totalLength / 2 + M.DashLength / 2

	for n = 0, count - 1 do
		local offset = start + n * period
		marking(parent, "Dash", segment.Center + segment.Dir * offset, segment.Dir, M.DashWidth, M.DashLength)
	end
end

local function buildZebra(parent: Instance, endPoint: Vector3, inwardDir: Vector3)
	-- Rechts-Vektor quer zur Straße
	local across = inwardDir:Cross(Vector3.yAxis).Unit
	local stripes = math.floor(M.RoadWidth / M.ZebraStripeSpacing)
	local firstOffset = -((stripes - 1) * M.ZebraStripeSpacing) / 2
	local middle = endPoint + inwardDir * (M.ZebraInset + M.ZebraDepth / 2)

	for n = 0, stripes - 1 do
		local pos = middle + across * (firstOffset + n * M.ZebraStripeSpacing)
		marking(parent, "Zebra", pos, inwardDir, M.ZebraStripeWidth, M.ZebraDepth)
	end
end

function RoadBuilder.build(parent: Instance)
	local roads = PartFactory.model(parent, "Roads")
	buildGround(roads)

	local markings = PartFactory.folder(roads, "Markings")
	local crossings = PartFactory.folder(roads, "Crosswalks")

	for _, segment in ipairs(CityLayout.getRoadSegments()) do
		buildCenterLine(markings, segment)

		if segment.Interior then
			local half = segment.Length / 2
			buildZebra(crossings, segment.Center - segment.Dir * half, segment.Dir)
			buildZebra(crossings, segment.Center + segment.Dir * half, -segment.Dir)
		end
	end

	return roads
end

return RoadBuilder
