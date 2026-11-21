--[[
	BuildingKit.lua
	------------------------------------------------------------------
	Platzhalter-Gebäude aus Parts. Jede Funktion bekommt:
	  parent  – wohin das Model kommt
	  base    – CFrame am BODEN in der Mitte des Gebäudes (Blickrichtung = Vorderseite)
	  ...     – Maße/Farben

	Jede Funktion versucht zuerst PartFactory.tryAsset(<Asset-Name>).
	Wer später ein Mesh-Model "Tower" in ServerStorage/Assets legt,
	ersetzt damit automatisch alle Hochhäuser.
]]

local PartFactory = require(script.Parent.PartFactory)

local BuildingKit = {}

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end
BuildingKit.pick = pick

-- Hochhaus mit Fensterbändern
function BuildingKit.tower(
	parent: Instance,
	base: CFrame,
	footprint: Vector2,
	height: number,
	color: Color3,
	windowColor: Color3
): Model
	local asset = PartFactory.tryAsset("Tower", base, parent)
	if asset then
		return asset
	end

	local model = PartFactory.model(parent, "Tower", true)
	PartFactory.box(
		model,
		"Body",
		Vector3.new(footprint.X, height, footprint.Y),
		base * CFrame.new(0, height / 2, 0),
		color,
		Enum.Material.SmoothPlastic
	)

	-- Fensterbänder: etwas breiter als der Körper, damit sie herausstehen
	local bandSpacing = 12
	local bandCount = math.min(10, math.floor((height - 8) / bandSpacing))
	for n = 1, bandCount do
		local y = n * bandSpacing
		PartFactory.part(model, {
			Name = "Windows",
			Size = Vector3.new(footprint.X + 0.4, 4, footprint.Y + 0.4),
			CFrame = base * CFrame.new(0, y, 0),
			Color = windowColor,
			Material = Enum.Material.Glass,
			CastShadow = false,
		})
	end

	-- Dachaufbau
	PartFactory.box(
		model,
		"Roof",
		Vector3.new(footprint.X * 0.5, 4, footprint.Y * 0.5),
		base * CFrame.new(0, height + 2, 0),
		Color3.fromRGB(90, 90, 100),
		Enum.Material.Metal
	)

	model.PrimaryPart = model:FindFirstChild("Body") :: BasePart
	return model
end

-- Einfamilienhaus mit Satteldach und Tür (Tür zeigt in Blickrichtung von base)
function BuildingKit.house(parent: Instance, base: CFrame, wallColor: Color3, roofColor: Color3): Model
	local asset = PartFactory.tryAsset("House", base, parent)
	if asset then
		return asset
	end

	local width, depth, wallHeight, roofHeight = 22, 18, 12, 7
	local model = PartFactory.model(parent, "House", true)

	PartFactory.box(
		model,
		"Walls",
		Vector3.new(width, wallHeight, depth),
		base * CFrame.new(0, wallHeight / 2, 0),
		wallColor,
		Enum.Material.SmoothPlastic
	)

	-- Satteldach aus zwei Keilen, Rücken an Rücken.
	-- Ein WedgePart ist hinten (+Z) hoch und fällt nach vorne (-Z) ab.
	local roofSize = Vector3.new(width + 1, roofHeight, depth / 2 + 0.5)
	local roofY = wallHeight + roofHeight / 2
	PartFactory.part(model, {
		Name = "RoofFront",
		ClassName = "WedgePart",
		Size = roofSize,
		CFrame = base * CFrame.new(0, roofY, -roofSize.Z / 2),
		Color = roofColor,
	})
	PartFactory.part(model, {
		Name = "RoofBack",
		ClassName = "WedgePart",
		Size = roofSize,
		CFrame = base * CFrame.new(0, roofY, roofSize.Z / 2) * CFrame.Angles(0, math.pi, 0),
		Color = roofColor,
	})

	-- Tür auf der Vorderseite (-Z in Objektkoordinaten)
	PartFactory.part(model, {
		Name = "Door",
		Size = Vector3.new(4, 7, 0.4),
		CFrame = base * CFrame.new(0, 3.5, -depth / 2 - 0.2),
		Color = Color3.fromRGB(120, 75, 45),
		Decor = true,
	})
	for _, x in ipairs({ -6.5, 6.5 }) do
		PartFactory.part(model, {
			Name = "Window",
			Size = Vector3.new(4, 4, 0.4),
			CFrame = base * CFrame.new(x, 6.5, -depth / 2 - 0.2),
			Color = Color3.fromRGB(170, 225, 255),
			Material = Enum.Material.Glass,
			Decor = true,
		})
	end

	model.PrimaryPart = model:FindFirstChild("Walls") :: BasePart
	return model
end

-- Lagerhalle mit Rolltor und Schornstein
function BuildingKit.warehouse(parent: Instance, base: CFrame, size: Vector3, color: Color3): Model
	local asset = PartFactory.tryAsset("Warehouse", base, parent)
	if asset then
		return asset
	end

	local model = PartFactory.model(parent, "Warehouse", true)
	PartFactory.box(model, "Hall", size, base * CFrame.new(0, size.Y / 2, 0), color, Enum.Material.Metal)
	PartFactory.box(
		model,
		"RoofRim",
		Vector3.new(size.X + 1, 1.5, size.Z + 1),
		base * CFrame.new(0, size.Y + 0.75, 0),
		Color3.fromRGB(80, 80, 85),
		Enum.Material.Metal
	)
	PartFactory.part(model, {
		Name = "Gate",
		Size = Vector3.new(size.X * 0.4, size.Y * 0.6, 0.4),
		CFrame = base * CFrame.new(0, size.Y * 0.3, -size.Z / 2 - 0.2),
		Color = Color3.fromRGB(230, 190, 40),
		Material = Enum.Material.DiamondPlate,
		Decor = true,
	})
	local chimneyBase = (base * CFrame.new(size.X * 0.3, size.Y, size.Z * 0.25)).Position
	PartFactory.cylinder(model, "Chimney", 18, 5, chimneyBase, Color3.fromRGB(160, 70, 60), Enum.Material.Brick)

	model.PrimaryPart = model:FindFirstChild("Hall") :: BasePart
	return model
end

function BuildingKit.container(parent: Instance, base: CFrame, color: Color3): BasePart
	return PartFactory.box(
		parent,
		"Container",
		Vector3.new(8, 8.5, 20),
		base * CFrame.new(0, 4.25, 0),
		color,
		Enum.Material.CorrodedMetal
	)
end

-- Baum: Stamm + Krone (Kugel). groundPos = Fußpunkt.
function BuildingKit.tree(parent: Instance, groundPos: Vector3, rng: Random): Model
	local base = CFrame.new(groundPos)
	local asset = PartFactory.tryAsset("Tree", base, parent)
	if asset then
		return asset
	end

	local model = PartFactory.model(parent, "Tree", true)
	local trunkHeight = rng:NextNumber(6, 10)
	local crown = rng:NextNumber(9, 14)
	PartFactory.cylinder(model, "Trunk", trunkHeight, 2, groundPos, Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	local green = Color3.fromHSV(rng:NextNumber(0.25, 0.35), 0.65, rng:NextNumber(0.55, 0.75))
	PartFactory.ball(model, "Crown", crown, groundPos + Vector3.new(0, trunkHeight + crown * 0.35, 0), green)
	model.PrimaryPart = model:FindFirstChild("Trunk") :: BasePart
	return model
end

-- Rampe: niedrige Kante vorne (-Z = LookVector von base), hohe Kante hinten.
-- Man kommt also von dort, wohin base "schaut", und fährt GEGEN die
-- Blickrichtung die Rampe hinauf.
function BuildingKit.ramp(parent: Instance, base: CFrame, size: Vector3, color: Color3): BasePart
	local asset = PartFactory.tryAsset("Ramp", base, parent)
	if asset then
		return asset.PrimaryPart or (asset:FindFirstChildWhichIsA("BasePart") :: BasePart)
	end
	return PartFactory.part(parent, {
		Name = "Ramp",
		ClassName = "WedgePart",
		Size = size,
		CFrame = base * CFrame.new(0, size.Y / 2, 0),
		Color = color,
		Material = Enum.Material.DiamondPlate,
	})
end

return BuildingKit
