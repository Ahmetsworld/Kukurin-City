--[[
	CameraController.lua
	------------------------------------------------------------------
	Verfolgerkamera, solange man auf dem eigenen Kukurin sitzt:
	  * folgt weich hinter dem Scooter (in Fahrtrichtung)
	  * zoomt bei Tempo etwas heraus und weitet das Sichtfeld (FOV)
	  * rutscht vor Wände, statt durch sie hindurchzuschauen
	Ohne Scooter: normale Roblox-Kamera.

	Kamerawackeln für Crashs (ab Phase 3):
	  CameraController.shake(0.5)   -- 0..1, mehrere Aufrufe addieren sich
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VehicleController = require(script.Parent.VehicleController)

local RENDER_NAME = "KukurinChaseCamera"

local BASE_FOV = 70
local MAX_FOV_BONUS = 18
local NITRO_FOV_BONUS = 8
local DISTANCE = 13
local DISTANCE_SPEED_BONUS = 5
local HEIGHT = 5
local LOOK_AHEAD = 6
local FOLLOW_SHARPNESS = 7 -- höher = Kamera klebt enger am Scooter
local TURN_SHARPNESS = 4

local SHAKE_DECAY = 1.6 -- wie schnell das Wackeln abklingt (pro Sekunde)
local SHAKE_MAX_ANGLE = math.rad(4)
local SHAKE_MAX_OFFSET = 0.8

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraController = {}

local trauma = 0
local cameraPosition: Vector3? = nil
local followDirection = Vector3.new(0, 0, -1)
local currentFov = BASE_FOV
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude

function CameraController.shake(intensity: number)
	trauma = math.clamp(trauma + intensity, 0, 1)
end

local function shakeOffset(time: number): CFrame
	if trauma <= 0 then
		return CFrame.new()
	end
	local amount = trauma * trauma -- quadratisch: kleine Stöße kaum, große deutlich
	local function n(seed: number): number
		return math.noise(time * 25, seed)
	end
	return CFrame.new(n(1) * SHAKE_MAX_OFFSET * amount, n(2) * SHAKE_MAX_OFFSET * amount, 0)
		* CFrame.Angles(n(3) * SHAKE_MAX_ANGLE * amount, n(4) * SHAKE_MAX_ANGLE * amount, n(5) * SHAKE_MAX_ANGLE * amount)
end

local function update(dt: number)
	local state = VehicleController.getState()
	local root = state.Root
	if not root then
		return
	end

	trauma = math.max(0, trauma - SHAKE_DECAY * dt)

	-- Richtung: bei Fahrt die Bewegungsrichtung, sonst die Blickrichtung des Scooters
	local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local target = if velocity.Magnitude > 6 and state.ForwardSpeed > 0 then velocity.Unit
		elseif look.Magnitude > 0.1 then look.Unit
		else followDirection
	local turnAlpha = 1 - math.exp(-TURN_SHARPNESS * dt)
	followDirection = followDirection:Lerp(target, turnAlpha)
	if followDirection.Magnitude < 0.01 then
		followDirection = target
	end
	followDirection = followDirection.Unit

	local maxSpeed = (state.Stats and state.Stats.Speed) or 80
	local speedRatio = math.clamp(state.SpeedKmh / maxSpeed, 0, 1.5)

	local focus = root.Position + Vector3.new(0, 2, 0)
	local desired = focus - followDirection * (DISTANCE + DISTANCE_SPEED_BONUS * speedRatio) + Vector3.new(0, HEIGHT, 0)

	local followAlpha = 1 - math.exp(-FOLLOW_SHARPNESS * dt)
	cameraPosition = if cameraPosition then cameraPosition:Lerp(desired, followAlpha) else desired

	-- Nicht durch Wände schauen
	local finalPosition = cameraPosition :: Vector3
	local toCamera = finalPosition - focus
	local hit = workspace:Raycast(focus, toCamera, wallParams)
	if hit then
		finalPosition = hit.Position - toCamera.Unit * 0.8
	end

	local lookAt = root.Position + followDirection * LOOK_AHEAD + Vector3.new(0, 1.5, 0)
	camera.CFrame = CFrame.lookAt(finalPosition, lookAt) * shakeOffset(os.clock())

	local targetFov = BASE_FOV + MAX_FOV_BONUS * math.min(speedRatio, 1) + (if state.NitroActive then NITRO_FOV_BONUS else 0)
	currentFov += (targetFov - currentFov) * (1 - math.exp(-5 * dt))
	camera.FieldOfView = currentFov
end

local function onRidingChanged(riding: boolean)
	camera = workspace.CurrentCamera
	if riding then
		local state = VehicleController.getState()
		local ignore: { Instance } = {}
		if state.Vehicle then
			table.insert(ignore, state.Vehicle)
		end
		if player.Character then
			table.insert(ignore, player.Character)
		end
		wallParams.FilterDescendantsInstances = ignore

		cameraPosition = camera.CFrame.Position
		camera.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, update)
	else
		RunService:UnbindFromRenderStep(RENDER_NAME)
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		camera.FieldOfView = BASE_FOV
		currentFov = BASE_FOV
	end
end

function CameraController.Init() end

function CameraController.Start()
	VehicleController.RidingChanged:Connect(onRidingChanged)
	if VehicleController.getState().Riding then
		onRidingChanged(true)
	end
end

return CameraController
