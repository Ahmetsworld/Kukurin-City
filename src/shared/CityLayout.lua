--[[
	CityLayout.lua
	------------------------------------------------------------------
	Reine Raster-Mathematik der Stadt. Erzeugt KEINE Instanzen.
	Läuft auf Server und Client und wird benutzt von:
	  * den Map-Buildern (Server, Phase 1)
	  * der Stadtteil-Anzeige / Minimap (Client)
	  * Verkehrs-KI und Dummies (Phase 3/4): Wegpunkte, Kreuzungen

	Koordinaten:
	  * Straßen-Index i = 0..BlocksX (X-Richtung), j = 0..BlocksZ (Z)
	  * Block-Index col = 1..BlocksX, row = 1..BlocksZ
	  * Kreuzung (i, j) = Schnittpunkt von Straße i (Nord-Süd) und j (Ost-West)
	  * Y = 0 ist die Oberkante des Asphalts.
]]

local Config = require(script.Parent.Config)

local M = Config.Map

local CityLayout = {}

CityLayout.Pitch = M.BlockSize + M.RoadWidth -- Abstand von Straße zu Straße
CityLayout.Width = M.BlocksX * M.BlockSize + (M.BlocksX + 1) * M.RoadWidth
CityLayout.Depth = M.BlocksZ * M.BlockSize + (M.BlocksZ + 1) * M.RoadWidth
CityLayout.LotSize = M.BlockSize - 2 * M.SidewalkWidth
CityLayout.LotTopY = M.SidewalkHeight + M.LotRaise

local MIN_X = -CityLayout.Width / 2
local MIN_Z = -CityLayout.Depth / 2

------------------------------------------------------------------------
-- Konsistenz prüfen (Tippfehler in Config fallen sofort auf)
------------------------------------------------------------------------
assert(#M.Districts == M.BlocksZ, "[CityLayout] Districts braucht BlocksZ Zeilen")
for row, line in ipairs(M.Districts) do
	assert(#line == M.BlocksX, ("[CityLayout] Districts-Zeile %d braucht BlocksX Einträge"):format(row))
	for _, key in ipairs(line) do
		assert(Config.Districts[key], ("[CityLayout] Unbekannter Stadtteil '%s'"):format(key))
	end
end
assert(CityLayout.Width <= M.GroundSize, "[CityLayout] Stadt ist größer als GroundSize")

-- Landmarken nach Block-Koordinate nachschlagen können
local landmarkByBlock: { [string]: string } = {}
for name, data in pairs(Config.Landmarks) do
	local key = data.Col .. "," .. data.Row
	assert(not landmarkByBlock[key], "[CityLayout] Zwei Landmarken im selben Block: " .. key)
	landmarkByBlock[key] = name
end

------------------------------------------------------------------------
-- Straßen & Kreuzungen
------------------------------------------------------------------------

-- X-Mitte der Nord-Süd-Straße i (0..BlocksX)
function CityLayout.roadX(i: number): number
	return MIN_X + M.RoadWidth / 2 + i * CityLayout.Pitch
end

-- Z-Mitte der Ost-West-Straße j (0..BlocksZ)
function CityLayout.roadZ(j: number): number
	return MIN_Z + M.RoadWidth / 2 + j * CityLayout.Pitch
end

function CityLayout.intersection(i: number, j: number): Vector3
	return Vector3.new(CityLayout.roadX(i), 0, CityLayout.roadZ(j))
end

-- Liegt die Nord-Süd-Straße i zwischen zwei Blöcken (nicht am Rand)?
function CityLayout.isInteriorRoadX(i: number): boolean
	return i > 0 and i < M.BlocksX
end

function CityLayout.isInteriorRoadZ(j: number): boolean
	return j > 0 and j < M.BlocksZ
end

--[[
	Liefert alle Straßenabschnitte zwischen zwei Kreuzungen.
	Jeder Abschnitt: {
		Center   = Vector3 (Mitte, y = 0),
		Dir      = Vector3 (Einheitsvektor entlang der Straße),
		Length   = Länge zwischen den Kreuzungsflächen,
		Interior = true, wenn auf beiden Seiten Blöcke liegen,
		From/To  = { i, j } der beiden Kreuzungen
	}
]]
function CityLayout.getRoadSegments()
	local segments = {}

	-- Ost-West-Straßen (entlang X)
	for j = 0, M.BlocksZ do
		for i = 0, M.BlocksX - 1 do
			local a = CityLayout.intersection(i, j)
			local b = CityLayout.intersection(i + 1, j)
			table.insert(segments, {
				Center = (a + b) / 2,
				Dir = Vector3.xAxis,
				Length = M.BlockSize,
				Interior = CityLayout.isInteriorRoadZ(j),
				From = { i, j },
				To = { i + 1, j },
			})
		end
	end

	-- Nord-Süd-Straßen (entlang Z)
	for i = 0, M.BlocksX do
		for j = 0, M.BlocksZ - 1 do
			local a = CityLayout.intersection(i, j)
			local b = CityLayout.intersection(i, j + 1)
			table.insert(segments, {
				Center = (a + b) / 2,
				Dir = Vector3.zAxis,
				Length = M.BlockSize,
				Interior = CityLayout.isInteriorRoadX(i),
				From = { i, j },
				To = { i, j + 1 },
			})
		end
	end

	return segments
end

------------------------------------------------------------------------
-- Blöcke
------------------------------------------------------------------------

-- Mitte des Blocks (col, row) auf Asphalthöhe (y = 0)
function CityLayout.blockCenter(col: number, row: number): Vector3
	local x = MIN_X + M.RoadWidth + M.BlockSize / 2 + (col - 1) * CityLayout.Pitch
	local z = MIN_Z + M.RoadWidth + M.BlockSize / 2 + (row - 1) * CityLayout.Pitch
	return Vector3.new(x, 0, z)
end

-- Mitte des Grundstücks auf dessen Oberkante (dort stehen Gebäude)
function CityLayout.lotCenter(col: number, row: number): Vector3
	return CityLayout.blockCenter(col, row) + Vector3.new(0, CityLayout.LotTopY, 0)
end

function CityLayout.getDistrictKey(col: number, row: number): string
	return M.Districts[row][col]
end

function CityLayout.getLandmarkAt(col: number, row: number): string?
	return landmarkByBlock[col .. "," .. row]
end

-- Weltposition der Landmarke (Grundstücksmitte)
function CityLayout.getLandmarkPosition(name: string): Vector3
	local data = Config.Landmarks[name]
	assert(data, "[CityLayout] Unbekannte Landmarke " .. tostring(name))
	return CityLayout.lotCenter(data.Col, data.Row)
end

-- Welcher Block liegt an dieser Position? nil = Straße oder außerhalb.
function CityLayout.blockFromPosition(position: Vector3): (number?, number?)
	local function axis(localValue: number, count: number): number?
		if localValue < 0 then
			return nil
		end
		local index = math.floor(localValue / CityLayout.Pitch)
		local within = localValue - index * CityLayout.Pitch
		if within < M.RoadWidth then
			return nil -- auf der Straße
		end
		local blockIndex = index + 1
		if blockIndex > count then
			return nil
		end
		return blockIndex
	end

	local col = axis(position.X - MIN_X, M.BlocksX)
	local row = axis(position.Z - MIN_Z, M.BlocksZ)
	if col and row then
		return col, row
	end
	return nil, nil
end

function CityLayout.isInsideCity(position: Vector3): boolean
	return math.abs(position.X) <= CityLayout.Width / 2 and math.abs(position.Z) <= CityLayout.Depth / 2
end

-- Anzeigename für eine Position (Landmarke > Stadtteil).
-- nil, wenn man auf einer Straße steht (Anzeige behält dann den alten Namen).
function CityLayout.describePosition(position: Vector3): string?
	if not CityLayout.isInsideCity(position) then
		return "Stadtrand"
	end
	local col, row = CityLayout.blockFromPosition(position)
	if not col or not row then
		return nil
	end
	local landmark = CityLayout.getLandmarkAt(col, row)
	if landmark then
		return Config.Landmarks[landmark].DisplayName
	end
	return Config.Districts[CityLayout.getDistrictKey(col, row)].Name
end

return CityLayout
