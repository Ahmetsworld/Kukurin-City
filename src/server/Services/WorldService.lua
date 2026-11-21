--[[
	WorldService.lua
	------------------------------------------------------------------
	Globale Welt-Einstellungen: bunte, cartoonige Beleuchtung.
	(StreamingEnabled wird in default.project.json bzw. in Studio
	gesetzt, das geht nicht per Script.)
]]

local Lighting = game:GetService("Lighting")

local WorldService = {}

local function getOrCreate(className: string, name: string, parent: Instance): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

function WorldService.Init()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(110, 110, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true

	-- Kräftige, fröhliche Farben
	local cc = getOrCreate("ColorCorrectionEffect", "KukurinColors", Lighting) :: ColorCorrectionEffect
	cc.Saturation = 0.25
	cc.Contrast = 0.05
	cc.Brightness = 0.02

	local atmosphere = getOrCreate("Atmosphere", "KukurinAtmosphere", Lighting) :: Atmosphere
	atmosphere.Density = 0.25
	atmosphere.Haze = 1
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Decay = Color3.fromRGB(110, 150, 210)

	local bloom = getOrCreate("BloomEffect", "KukurinBloom", Lighting) :: BloomEffect
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 1.5
end

return WorldService
