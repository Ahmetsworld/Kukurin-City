--[[
	TrafficLightBuilder.lua
	------------------------------------------------------------------
	Stellt an jede Innen-Kreuzung vier Ampeln (eine pro Zufahrt).
	Rechtsverkehr: Die Ampel steht aus Sicht des Fahrers vorne rechts
	auf dem Bürgersteig und zeigt ihm entgegen.

	Struktur (TrafficLightService und später die KI lesen das):
	  Map.TrafficLights.Intersection_<i>_<j>   (Model)
	    Attribute: I, J, NS = "Red"|"Yellow"|"Green", EW = ...
	    Light_<Richtung>  (Model, Attribut Axis = "NS" | "EW")
	      Red, Yellow, Green  (Lampen-Parts)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CityLayout = require(ReplicatedStorage.Shared.CityLayout)
local PartFactory = require(script.Parent.PartFactory)

local M = Config.Map

local POLE_HEIGHT = 11
local SIDEWALK_INSET = 3 -- wie weit die Ampel auf dem Bürgersteig steht
local LAMP_ORDER = { "Red", "Yellow", "Green" } -- von oben nach unten

-- Fahrtrichtungen der Zufahrten (Richtung, in die das Auto fährt)
local APPROACHES = {
	{ Name = "FromNorth", Dir = Vector3.zAxis, Axis = "NS" },
	{ Name = "FromSouth", Dir = -Vector3.zAxis, Axis = "NS" },
	{ Name = "FromWest", Dir = Vector3.xAxis, Axis = "EW" },
	{ Name = "FromEast", Dir = -Vector3.xAxis, Axis = "EW" },
}

local TrafficLightBuilder = {}

local function buildLight(parent: Instance, center: Vector3, approach)
	local dir: Vector3 = approach.Dir
	local right = dir:Cross(Vector3.yAxis).Unit
	local offset = M.RoadWidth / 2 + SIDEWALK_INSET

	-- vorne rechts aus Sicht des Fahrers (vor der Kreuzung)
	local foot = center - dir * offset + right * offset + Vector3.new(0, M.SidewalkHeight, 0)

	local model = PartFactory.model(parent, "Light_" .. approach.Name, true)
	model:SetAttribute("Axis", approach.Axis)

	PartFactory.cylinder(model, "Pole", POLE_HEIGHT, 0.8, foot, Color3.fromRGB(60, 60, 65), Enum.Material.Metal)

	-- Gehäuse schaut dem Fahrer entgegen (-dir)
	local housingPos = foot + Vector3.new(0, POLE_HEIGHT + 3, 0)
	local housingCF = CFrame.lookAt(housingPos, housingPos - dir)
	PartFactory.box(model, "Housing", Vector3.new(2.2, 6.6, 1.6), housingCF, Color3.fromRGB(35, 35, 40))

	for index, lampName in ipairs(LAMP_ORDER) do
		local y = 2.1 - (index - 1) * 2.1
		PartFactory.part(model, {
			Name = lampName,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.7, 1.7, 1.7),
			CFrame = housingCF * CFrame.new(0, y, -0.6),
			Color = Color3.fromRGB(40, 40, 40),
			Decor = true,
		})
	end

	model.PrimaryPart = model:FindFirstChild("Pole") :: BasePart
	return model
end

function TrafficLightBuilder.build(parent: Instance)
	local folder = PartFactory.folder(parent, "TrafficLights")
	if not Config.TrafficLights.Enabled then
		return folder
	end

	for i = 1, M.BlocksX - 1 do
		for j = 1, M.BlocksZ - 1 do
			local center = CityLayout.intersection(i, j)
			local model = PartFactory.model(folder, ("Intersection_%d_%d"):format(i, j))
			model:SetAttribute("I", i)
			model:SetAttribute("J", j)
			model:SetAttribute("NS", "Red")
			model:SetAttribute("EW", "Red")

			for _, approach in ipairs(APPROACHES) do
				buildLight(model, center, approach)
			end
		end
	end

	return folder
end

return TrafficLightBuilder
