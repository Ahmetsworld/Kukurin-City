--[[
	TrafficLightService.lua
	------------------------------------------------------------------
	Schaltet alle Ampeln. Der Zustand jeder Kreuzung steht als
	Attribut am Model (NS / EW = "Green" | "Yellow" | "Red"), damit die
	Verkehrs-KI (Phase 4) und Dummies ihn einfach lesen können.

	Zyklus pro Kreuzung:
	  NS grün -> NS gelb -> alle rot -> EW grün -> EW gelb -> alle rot
	Die Zeit kommt von workspace:GetServerTimeNow(). Deshalb könnten
	Clients den Zustand später auch selbst ausrechnen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TL = Config.TrafficLights

local LAMP_ON_COLORS = {
	Red = Color3.fromRGB(255, 50, 50),
	Yellow = Color3.fromRGB(255, 200, 40),
	Green = Color3.fromRGB(60, 235, 90),
}
local LAMP_OFF_COLOR = Color3.fromRGB(40, 40, 40)

type Light = { Axis: string, Lamps: { [string]: BasePart } }
type Intersection = { Model: Model, Offset: number, Lights: { Light }, NS: string?, EW: string? }

local TrafficLightService = {}

local intersections: { Intersection } = {}

-- Zustand beider Achsen zum Zeitpunkt t
local function stateAt(t: number): (string, string)
	local half = TL.GreenTime + TL.YellowTime + TL.AllRedTime
	local phase = t % (2 * half)

	if phase < TL.GreenTime then
		return "Green", "Red"
	elseif phase < TL.GreenTime + TL.YellowTime then
		return "Yellow", "Red"
	elseif phase < half then
		return "Red", "Red"
	end

	phase -= half
	if phase < TL.GreenTime then
		return "Red", "Green"
	elseif phase < TL.GreenTime + TL.YellowTime then
		return "Red", "Yellow"
	end
	return "Red", "Red"
end
TrafficLightService.stateAt = stateAt

local function applyLamps(light: Light, state: string)
	for lampName, lamp in pairs(light.Lamps) do
		local on = lampName == state
		lamp.Color = if on then LAMP_ON_COLORS[lampName] else LAMP_OFF_COLOR
		lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

local function update()
	local now = workspace:GetServerTimeNow()
	for _, inter in ipairs(intersections) do
		local ns, ew = stateAt(now + inter.Offset)
		if ns ~= inter.NS or ew ~= inter.EW then
			inter.NS, inter.EW = ns, ew
			inter.Model:SetAttribute("NS", ns)
			inter.Model:SetAttribute("EW", ew)
			for _, light in ipairs(inter.Lights) do
				applyLamps(light, if light.Axis == "NS" then ns else ew)
			end
		end
	end
end

function TrafficLightService.Start()
	if not TL.Enabled then
		return
	end

	local folder = workspace:WaitForChild("Map"):WaitForChild("TrafficLights")
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") then
			local lights: { Light } = {}
			for _, lightModel in ipairs(model:GetChildren()) do
				local axis = lightModel:GetAttribute("Axis")
				if axis then
					table.insert(lights, {
						Axis = axis,
						Lamps = {
							Red = lightModel:FindFirstChild("Red"),
							Yellow = lightModel:FindFirstChild("Yellow"),
							Green = lightModel:FindFirstChild("Green"),
						},
					})
				end
			end

			local i = model:GetAttribute("I") or 0
			local j = model:GetAttribute("J") or 0
			table.insert(intersections, {
				Model = model,
				Offset = (i + j) * TL.GreenWaveOffset,
				Lights = lights,
			})
		end
	end

	task.spawn(function()
		while true do
			update()
			task.wait(TL.UpdateInterval)
		end
	end)
end

return TrafficLightService
