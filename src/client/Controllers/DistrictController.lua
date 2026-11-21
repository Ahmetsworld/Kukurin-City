--[[
	DistrictController.lua
	------------------------------------------------------------------
	Zeigt oben am Bildschirm kurz an, in welchem Stadtteil bzw. an
	welchem Ort man gerade ist ("Innenstadt", "Kukurin-Händler" ...).
	Nützlich zum Testen der Map. Ab Phase 2 wird das Teil des HUDs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CityLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CityLayout"))

local CHECK_INTERVAL = 0.5
local VISIBLE_TIME = 3

local player = Players.LocalPlayer

local DistrictController = {}

local label: TextLabel
local currentName: string? = nil
local showToken = 0

local function createGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DistrictGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	label = Instance.new("TextLabel")
	label.Name = "DistrictName"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.new(0.5, 0, 0, 44)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 1
	label.Text = ""

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 36
	constraint.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 3
	stroke.Transparency = 1
	stroke.Parent = label

	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function show(text: string)
	showToken += 1
	local token = showToken
	label.Text = "📍 " .. text

	local fadeIn = TweenInfo.new(0.3)
	TweenService:Create(label, fadeIn, { TextTransparency = 0 }):Play()
	TweenService:Create(label.Stroke, fadeIn, { Transparency = 0 }):Play()

	task.delay(VISIBLE_TIME, function()
		if token ~= showToken then
			return -- inzwischen neuer Ort angezeigt
		end
		local fadeOut = TweenInfo.new(0.6)
		TweenService:Create(label, fadeOut, { TextTransparency = 1 }):Play()
		TweenService:Create(label.Stroke, fadeOut, { Transparency = 1 }):Play()
	end)
end

function DistrictController.Init()
	createGui()
end

function DistrictController.Start()
	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local name = CityLayout.describePosition(root.Position)
				if name and name ~= currentName then
					currentName = name
					show(name)
				end
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return DistrictController
