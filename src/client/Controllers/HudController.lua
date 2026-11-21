--[[
	HudController.lua
	------------------------------------------------------------------
	HUD für Phase 2:
	  * oben links:  Name des Kukurin + HP-Balken (HP kommt vom Server)
	  * unten Mitte: Tacho (km/h), Nitro-Ladungen, Handbremsen-Anzeige
	  * unten Mitte: Knopf "Kukurin rufen" (wenn man nicht fährt)
	  * rechts:      Handy-Buttons (Bremse, Nitro, Hupe, Absteigen)
	  * oben Mitte:  kurze Meldungen vom Server (Remote "Notify")

	Später kommen hier Geld, Wanted-Sterne, Combo und Minimap dazu.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local VehicleController = require(script.Parent.VehicleController)
local UiKit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UiKit"))

local Colors = UiKit.Colors

local player = Players.LocalPlayer

local HudController = {}

local gui: ScreenGui
local ui = {} :: { [string]: any }
local toastToken = 0

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

------------------------------------------------------------------------
-- Aufbau
------------------------------------------------------------------------

local function buildHealthPanel()
	local panel = UiKit.panel({
		Name = "HealthPanel",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(230, 66),
		Parent = gui,
	})
	ui.VehicleName = UiKit.label({
		Name = "VehicleName",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Kukurin",
		Parent = panel,
	})
	local barBack = UiKit.new("Frame", {
		Name = "BarBack",
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 20),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		BorderSizePixel = 0,
		Parent = panel,
	}, { UiKit.corner(8) })
	ui.HealthFill = UiKit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.Good,
		BorderSizePixel = 0,
		Parent = barBack,
	}, { UiKit.corner(8) })
	ui.HealthText = UiKit.label({
		Name = "HealthText",
		Size = UDim2.fromScale(1, 1),
		Text = "100 / 100",
		ZIndex = 2,
		Parent = barBack,
	})
	ui.HealthPanel = panel
end

local function buildSpeedometer()
	local panel = UiKit.panel({
		Name = "Speedometer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(180, 104),
		Visible = false,
		Parent = gui,
	})
	ui.Speed = UiKit.label({
		Name = "Speed",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 54),
		Text = "0",
		Parent = panel,
	})
	UiKit.label({
		Name = "Unit",
		Position = UDim2.fromOffset(10, 56),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "km/h",
		TextColor3 = Colors.Primary,
		Parent = panel,
	})
	ui.Nitro = UiKit.label({
		Name = "Nitro",
		Position = UDim2.fromOffset(10, 76),
		Size = UDim2.new(1, -20, 0, 20),
		Text = "",
		TextColor3 = Colors.Secondary,
		Parent = panel,
	})
	ui.Handbrake = UiKit.label({
		Name = "Handbrake",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.fromOffset(160, 24),
		Text = "HANDBREMSE",
		TextColor3 = Colors.Bad,
		Visible = false,
		Parent = panel,
	})
	ui.Speedometer = panel
end

local function buildCallButton()
	local button = UiKit.button({
		Name = "CallButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(250, 56),
		BackgroundColor3 = Colors.Primary,
		Text = if isTouch() then "🛴 Kukurin rufen" else "🛴 Kukurin rufen [R]",
		Parent = gui,
	})
	button.Activated:Connect(function()
		VehicleController.requestSpawn()
	end)
	ui.CallButton = button
end

local function touchButton(parent: Instance, name: string, text: string, color: Color3, order: number): TextButton
	return UiKit.button({
		Name = name,
		Size = UDim2.fromOffset(78, 78),
		BackgroundColor3 = color,
		Text = text,
		LayoutOrder = order,
		Corner = 39,
		Parent = parent,
	})
end

local function buildTouchControls()
	local column = UiKit.new("Frame", {
		Name = "TouchControls",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.42, 0),
		Size = UDim2.fromOffset(78, 4 * 78 + 3 * 10),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		UiKit.new("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local nitro = touchButton(column, "Nitro", "NITRO", Colors.Secondary, 1)
	local horn = touchButton(column, "Horn", "HUPE", Colors.Accent, 2)
	local brake = touchButton(column, "Brake", "BREMSE", Colors.Bad, 3)
	local exit = touchButton(column, "Exit", "AB", Colors.Panel, 4)

	nitro.Activated:Connect(VehicleController.nitro)
	horn.Activated:Connect(VehicleController.honk)
	exit.Activated:Connect(VehicleController.exit)

	-- Bremse muss gehalten werden
	brake.MouseButton1Down:Connect(function()
		VehicleController.setHandbrake(true)
	end)
	brake.MouseButton1Up:Connect(function()
		VehicleController.setHandbrake(false)
	end)
	brake.MouseLeave:Connect(function()
		VehicleController.setHandbrake(false)
	end)

	ui.TouchControls = column
	ui.NitroButton = nitro
end

local function buildToast()
	ui.Toast = UiKit.label({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.new(0.6, 0, 0, 34),
		Text = "",
		TextColor3 = Colors.Accent,
		TextTransparency = 1,
		Parent = gui,
	}, nil)
	ui.ToastStroke = ui.Toast:FindFirstChildOfClass("UIStroke")
	ui.ToastStroke.Transparency = 1
end

------------------------------------------------------------------------
-- Aktualisieren
------------------------------------------------------------------------

function HudController.toast(text: string)
	toastToken += 1
	local token = toastToken
	ui.Toast.Text = text
	ui.Toast.TextTransparency = 0
	ui.ToastStroke.Transparency = 0
	task.delay(2.5, function()
		if token == toastToken then
			local info = TweenInfo.new(0.5)
			TweenService:Create(ui.Toast, info, { TextTransparency = 1 }):Play()
			TweenService:Create(ui.ToastStroke, info, { Transparency = 1 }):Play()
		end
	end)
end

local function healthColor(ratio: number): Color3
	if ratio > 0.5 then
		return Colors.Good
	elseif ratio > 0.3 then
		return Colors.Warn
	end
	return Colors.Bad
end

local function update()
	local state = VehicleController.getState()
	local vehicle = state.Vehicle
	local riding = state.Riding

	ui.HealthPanel.Visible = vehicle ~= nil
	ui.Speedometer.Visible = riding
	ui.CallButton.Visible = not riding
	ui.TouchControls.Visible = riding and UserInputService.TouchEnabled

	if not vehicle then
		return
	end

	-- HP (Server-Wert)
	local hp = vehicle:GetAttribute("HP") or 0
	local maxHp = vehicle:GetAttribute("MaxHP") or 1
	local ratio = math.clamp(hp / maxHp, 0, 1)
	ui.HealthFill.Size = UDim2.fromScale(ratio, 1)
	ui.HealthFill.BackgroundColor3 = healthColor(ratio)
	ui.HealthText.Text = ("%d / %d"):format(math.ceil(hp), math.floor(maxHp))
	ui.VehicleName.Text = state.Stats and state.Stats.DisplayName or "Kukurin"

	if not riding then
		return
	end

	ui.Speed.Text = tostring(math.floor(state.SpeedKmh + 0.5))
	ui.Speed.TextColor3 = if state.NitroActive then Colors.Secondary else Colors.Text
	ui.Handbrake.Visible = state.Handbrake

	-- Nitro-Ladungen als Symbole, nur wenn das Modell Nitro hat
	local charges = vehicle:GetAttribute("NitroCharges") or 0
	local maxCharges = vehicle:GetAttribute("NitroMax") or 0
	if maxCharges > 0 then
		local text = if state.NitroActive then "NITRO!" else string.rep("⚡", charges) .. string.rep("·", maxCharges - charges)
		ui.Nitro.Text = text
		ui.NitroButton.Visible = true
	else
		ui.Nitro.Text = ""
		ui.NitroButton.Visible = false
	end
end

------------------------------------------------------------------------
-- Lebenszyklus
------------------------------------------------------------------------

function HudController.Init()
	gui = UiKit.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	buildHealthPanel()
	buildSpeedometer()
	buildCallButton()
	buildTouchControls()
	buildToast()
	gui.Parent = player:WaitForChild("PlayerGui")
end

function HudController.Start()
	local notifyRemote = Remotes.get("Notify") :: RemoteEvent
	notifyRemote.OnClientEvent:Connect(function(text)
		if type(text) == "string" then
			HudController.toast(text)
		end
	end)

	RunService.RenderStepped:Connect(update)
end

return HudController
