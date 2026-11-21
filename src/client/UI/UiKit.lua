--[[
	UiKit.lua
	------------------------------------------------------------------
	Kleine Helfer für einheitliche, cartoonige UI im Kukurin-Markenlook.

	UiKit.new("Frame", { Size = ..., Parent = ... }, { Kind1, Kind2 })
	UiKit.panel(...), UiKit.label(...), UiKit.button(...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Brand = Config.Brand

local UiKit = {}

UiKit.Colors = {
	Panel = Brand.Dark,
	Text = Brand.Light,
	Primary = Brand.Primary,
	Secondary = Brand.Secondary,
	Accent = Brand.Accent,
	Good = Color3.fromRGB(90, 220, 110),
	Warn = Color3.fromRGB(255, 200, 60),
	Bad = Color3.fromRGB(255, 80, 90),
}

-- Erzeugt eine Instanz mit Eigenschaften und Kindern. "Parent" wird zuletzt gesetzt.
function UiKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UiKit.corner(radius: number?): UICorner
	return UiKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UiKit.stroke(thickness: number?, color: Color3?): UIStroke
	return UiKit.new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Color3.new(0, 0, 0),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UiKit.textStroke(thickness: number?): UIStroke
	return UiKit.new("UIStroke", { Thickness = thickness or 2, Color = Color3.new(0, 0, 0) })
end

-- Abgerundete, halbtransparente Fläche
function UiKit.panel(props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or UiKit.Colors.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.15
	props.BorderSizePixel = 0
	return UiKit.new("Frame", props, { UiKit.corner(14), UiKit.stroke(3, Brand.Primary) })
end

function UiKit.label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Brand.Font
	props.TextColor3 = props.TextColor3 or UiKit.Colors.Text
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return UiKit.new("TextLabel", props, { UiKit.textStroke(2) })
end

-- props.Corner (optional) = Eckenradius in Pixeln
function UiKit.button(props: { [string]: any }): TextButton
	local cornerRadius = props.Corner or 14
	props.Corner = nil
	props.Font = props.Font or Brand.Font
	props.TextColor3 = props.TextColor3 or UiKit.Colors.Text
	props.TextScaled = true
	props.AutoButtonColor = true
	props.BorderSizePixel = 0
	return UiKit.new("TextButton", props, {
		UiKit.corner(cornerRadius),
		UiKit.stroke(3),
		UiKit.new("UIPadding", {
			PaddingTop = UDim.new(0.15, 0),
			PaddingBottom = UDim.new(0.15, 0),
			PaddingLeft = UDim.new(0.08, 0),
			PaddingRight = UDim.new(0.08, 0),
		}),
	})
end

return UiKit
