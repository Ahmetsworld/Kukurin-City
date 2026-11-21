--[[
	MapService.lua
	------------------------------------------------------------------
	Baut beim Serverstart die komplette Stadt aus Parts:
	  Workspace.Map
	    Roads          – Asphalt, Gras, Markierungen, Zebrastreifen
	    Blocks         – Bürgersteige, Grundstücke, Gebäude, Landmarken
	    TrafficLights  – Ampeln

	Wenn alles steht, wird workspace:SetAttribute("MapReady", true)
	gesetzt. Andere Systeme können darauf warten.
]]

local MapFolder = script.Parent.Parent.Map
local PartFactory = require(MapFolder.PartFactory)
local RoadBuilder = require(MapFolder.RoadBuilder)
local BlockBuilder = require(MapFolder.BlockBuilder)
local TrafficLightBuilder = require(MapFolder.TrafficLightBuilder)

local MapService = {}

function MapService.Init()
	-- Falls in Studio schon eine alte Map liegt (z. B. manuell gespeichert): weg damit
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end

	-- Standard-Baseplate aus dem Template entfernen, wir haben eigenen Boden
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local startTime = os.clock()

	-- Erst komplett in einem Ordner außerhalb von Workspace bauen und
	-- dann auf einmal einfügen. Das ist schneller und Clients sehen keine halbe Stadt.
	local map = Instance.new("Folder")
	map.Name = "Map"

	RoadBuilder.build(map)
	BlockBuilder.build(map)
	TrafficLightBuilder.build(map)

	map.Parent = workspace
	workspace:SetAttribute("MapReady", true)

	local partCount = 0
	for _, descendant in ipairs(map:GetDescendants()) do
		if descendant:IsA("BasePart") then
			partCount += 1
		end
	end
	print(("[MapService] Kukurin City gebaut: %d Parts in %.2f s"):format(partCount, os.clock() - startTime))
end

-- Für spätere Phasen: einfacher Zugriff auf Landmarken-Models
function MapService.getLandmarkModel(name: string): Instance?
	local map = workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	for _, descendant in ipairs(map.Blocks:GetChildren()) do
		if descendant:GetAttribute("Landmark") == name then
			return descendant:FindFirstChild(name)
		end
	end
	return nil
end

-- PartFactory für andere Services verfügbar machen (z. B. zerstörbare Objekte in Phase 9)
MapService.PartFactory = PartFactory

return MapService
