--[[
	PartFactory.lua
	------------------------------------------------------------------
	Kleine Helfer zum Erzeugen von Parts, Models und Schildern.
	Alle Map-Builder benutzen NUR diese Funktionen, damit alle Parts
	einheitliche Standardwerte haben (verankert, glatte Oberflächen ...).

	Asset-Hook (später Meshes statt Parts):
	  PartFactory.tryAsset("Name", cframe, parent) sucht in
	  ServerStorage/Assets ein Model mit diesem Namen. Wenn es eins
	  gibt, wird es geklont und an die Position gesetzt. Dann baut der
	  Builder den Part-Platzhalter NICHT.
]]

local ServerStorage = game:GetService("ServerStorage")

local PartFactory = {}

export type PartProps = {
	Name: string?,
	ClassName: string?, -- "Part" (Standard), "WedgePart", "CornerWedgePart", "SpawnLocation"
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	CanCollide: boolean?,
	Decor: boolean?, -- true = rein optisch: keine Kollision, keine Touch-/Raycast-Abfragen, kein Schatten
	CastShadow: boolean?,
}

-- Erzeugt einen verankerten Part mit Standardwerten.
function PartFactory.part(parent: Instance, props: PartProps): BasePart
	local part = Instance.new(props.ClassName or "Part") :: BasePart
	part.Name = props.Name or "Part"
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(200, 200, 200)
	part.Transparency = props.Transparency or 0

	if props.Shape and part:IsA("Part") then
		part.Shape = props.Shape
	end

	part.Size = props.Size
	part.CFrame = props.CFrame

	if props.Decor then
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
	else
		part.CanCollide = if props.CanCollide == nil then true else props.CanCollide
		if props.CastShadow ~= nil then
			part.CastShadow = props.CastShadow
		end
	end

	part.Parent = parent
	return part
end

-- Kurzform für einfache Quader
function PartFactory.box(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	return PartFactory.part(parent, {
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material,
	})
end

-- Leeres Model. "Atomic" = wird beim Streaming als Ganzes geladen,
-- damit Gebäude nie halb sichtbar sind.
function PartFactory.model(parent: Instance, name: string, atomic: boolean?): Model
	local model = Instance.new("Model")
	model.Name = name
	if atomic then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	model.Parent = parent
	return model
end

function PartFactory.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Asset-Hook, siehe Kopfkommentar. Gibt das geklonte Model zurück oder nil.
function PartFactory.tryAsset(assetName: string, cframe: CFrame, parent: Instance): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local source = assets and assets:FindFirstChild(assetName)
	if not source or not source:IsA("Model") then
		return nil
	end
	local clone = source:Clone()
	clone:PivotTo(cframe)
	clone.Parent = parent
	return clone
end

-- Senkrechter Zylinder (Roblox-Zylinder liegen standardmäßig auf der X-Achse)
function PartFactory.cylinder(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	bottomCenter: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	return PartFactory.part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(bottomCenter + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material,
	})
end

function PartFactory.ball(parent: Instance, name: string, diameter: number, center: Vector3, color: Color3): BasePart
	return PartFactory.part(parent, {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = CFrame.new(center),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
end

-- Text auf einer Fläche (Vorder- und Rückseite), z. B. für Schilder.
function PartFactory.addSurfaceText(part: BasePart, text: string, textColor: Color3, bothSides: boolean?)
	local faces = { Enum.NormalId.Front }
	if bothSides then
		table.insert(faces, Enum.NormalId.Back)
	end

	for _, face in ipairs(faces) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Text_" .. face.Name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 0 -- leuchtet auch nachts
		gui.MaxDistance = 600

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = textColor

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.04, 0)
		padding.PaddingRight = UDim.new(0.04, 0)
		padding.PaddingTop = UDim.new(0.1, 0)
		padding.PaddingBottom = UDim.new(0.1, 0)
		padding.Parent = label

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = label

		label.Parent = gui
		gui.Parent = part
	end
end

--[[
	Schild-Tafel. Die Vorderseite (mit Text) zeigt in Richtung facing.
	cframe-Position = Mitte der Tafel.
]]
function PartFactory.sign(
	parent: Instance,
	text: string,
	center: Vector3,
	facing: Vector3,
	size: Vector2,
	backgroundColor: Color3,
	textColor: Color3?
): BasePart
	local board = PartFactory.part(parent, {
		Name = "Sign",
		Size = Vector3.new(size.X, size.Y, 0.6),
		CFrame = CFrame.lookAt(center, center + facing),
		Color = backgroundColor,
		Material = Enum.Material.SmoothPlastic,
	})
	PartFactory.addSurfaceText(board, text, textColor or Color3.new(1, 1, 1), true)
	return board
end

-- Schwebendes Namensschild über einem Ort (aus der Ferne sichtbar).
function PartFactory.billboard(adornee: BasePart, text: string, color: Color3, offsetY: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Billboard"
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 450
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = color
	label.BackgroundTransparency = 0.1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label

	label.Parent = gui
	gui.Adornee = adornee
	gui.Parent = adornee
end

return PartFactory
