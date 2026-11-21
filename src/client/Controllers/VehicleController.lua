--[[
	VehicleController.lua
	------------------------------------------------------------------
	Fahrphysik des eigenen Kukurin (der Client ist Network Owner).

	Läuft IMMER, solange der eigene Scooter existiert:
	  * Federung: zwei Raycasts (vorne/hinten) halten den Scooter in
	    RideHeight über dem Boden (auch beim Parken).
	  * Antrieb + Seitenhaftung: eine VectorForce auf den Body.
	  * Aufrecht + Schräglage: AlignOrientation.
	Eingaben nur, wenn man draufsitzt:
	  * Gas/Lenken: VehicleSeat.ThrottleFloat / SteerFloat (kommt von
	    Tastatur, Gamepad und Handy-Thumbstick automatisch)
	  * Handbremse, Hupe, Nitro, Absteigen: ContextActionService
	    (Handy-Buttons baut der HudController und ruft die Funktionen hier)

	Andere Controller lesen den Zustand mit VehicleController.getState()
	und hören auf VehicleController.RidingChanged.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Physics = Config.VehiclePhysics
local KMH = Config.Units.KmhPerStudPerSecond

local player = Players.LocalPlayer

local VehicleController = {}

local ridingChangedEvent = Instance.new("BindableEvent")
VehicleController.RidingChanged = ridingChangedEvent.Event -- (isRiding: boolean)

-- Öffentlicher Zustand (nur lesen!)
local state = {
	Vehicle = nil :: Model?,
	Root = nil :: BasePart?,
	Seat = nil :: VehicleSeat?,
	Stats = nil :: any,
	Riding = false,
	SpeedKmh = 0,
	ForwardSpeed = 0, -- Studs/s, negativ = rückwärts
	Grounded = false,
	NitroActive = false,
	Handbrake = false,
}

local driveForce: VectorForce?
local upright: AlignOrientation?
local heading = 0 -- Gierwinkel (rad), 0 = Blick nach -Z
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local handbrakeHeld = false

local ACTION_HANDBRAKE = "KukurinHandbrake"
local ACTION_HORN = "KukurinHorn"
local ACTION_NITRO = "KukurinNitro"
local ACTION_EXIT = "KukurinExit"
local ACTION_CALL = "KukurinCall"

------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------

local function yawFromVector(v: Vector3): number
	return math.atan2(-v.X, -v.Z)
end

local function vectorFromYaw(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

-- kleinster Winkelabstand a - b im Bereich [-pi, pi]
local function angleDiff(a: number, b: number): number
	return (a - b + math.pi) % (2 * math.pi) - math.pi
end

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function updateRaycastFilter()
	local ignore: { Instance } = {}
	if state.Vehicle then
		table.insert(ignore, state.Vehicle)
	end
	-- Spieler-Figuren sind kein Boden
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	raycastParams.FilterDescendantsInstances = ignore
end

------------------------------------------------------------------------
-- Aktionen (auch von Handy-Buttons im HUD benutzt)
------------------------------------------------------------------------

function VehicleController.setHandbrake(active: boolean)
	handbrakeHeld = active
end

function VehicleController.honk()
	if state.Riding then
		(Remotes.get("Honk") :: RemoteEvent):FireServer()
	end
end

function VehicleController.nitro()
	if state.Riding then
		(Remotes.get("UseNitro") :: RemoteEvent):FireServer()
	end
end

function VehicleController.exit()
	local humanoid = getHumanoid()
	if humanoid and state.Riding then
		humanoid.Jump = true
	end
end

function VehicleController.requestSpawn()
	(Remotes.get("RequestSpawnVehicle") :: RemoteEvent):FireServer()
end

function VehicleController.getState()
	return state
end

------------------------------------------------------------------------
-- Physik-Schritt
------------------------------------------------------------------------

local function step(dt: number)
	local root = state.Root
	local vehicle = state.Vehicle
	if not root or not vehicle or not driveForce or not upright or not root.Parent then
		return
	end
	-- Nur rechnen, wenn wir wirklich Network Owner sind
	if not root:IsDescendantOf(workspace) or root.Anchored then
		return
	end

	local stats = state.Stats
	local mass = root.AssemblyMass
	local gravity = workspace.Gravity
	local rideHeight = vehicle:GetAttribute("RideHeight") or Physics.RideHeight
	local cf = root.CFrame
	local velocity = root.AssemblyLinearVelocity

	-- 1) Federung: Raycasts vorne und hinten
	local halfLength = root.Size.Z * 0.4
	local rayLength = rideHeight + 1.2
	local closest = math.huge
	local normalSum = Vector3.zero
	local hits = 0
	for _, z in ipairs({ -halfLength, halfLength }) do
		local origin = (cf * CFrame.new(0, 0, z)).Position
		local result = workspace:Raycast(origin, Vector3.new(0, -rayLength, 0), raycastParams)
		if result then
			local distance = origin.Y - result.Position.Y
			closest = math.min(closest, distance)
			normalSum += result.Normal
			hits += 1
		end
	end

	local grounded = hits > 0 and closest < rideHeight + 0.4
	local groundNormal = if hits > 0 then (normalSum / hits).Unit else Vector3.yAxis
	if groundNormal.Y < 0.5 then
		groundNormal = Vector3.yAxis -- Wände sind kein Boden
	end

	local upForce = 0
	if grounded then
		local compression = rideHeight - closest
		upForce = mass
			* (gravity + Physics.SuspensionStiffness * compression - Physics.SuspensionDamping * velocity.Y)
		upForce = math.clamp(upForce, 0, mass * gravity * Physics.MaxSuspensionForceG)
	end

	-- 2) Eingaben
	local seat = state.Seat
	local throttle, steer = 0, 0
	if state.Riding and seat then
		throttle = seat.ThrottleFloat
		steer = seat.SteerFloat
	end
	-- Ohne Fahrer: Handbremse an, damit er nicht wegrollt
	local handbrake = handbrakeHeld or not state.Riding
	state.Handbrake = handbrake and state.Riding

	-- 3) Antrieb und Seitenhaftung
	local forward = vectorFromYaw(heading)
	local right = forward:Cross(Vector3.yAxis)
	local forwardSpeed = velocity:Dot(forward)
	local sideSpeed = velocity:Dot(right)

	local nitroActive = (vehicle:GetAttribute("NitroActiveUntil") or 0) > workspace:GetServerTimeNow()
	local baseMaxSpeed = stats.Speed / KMH
	local maxSpeed = baseMaxSpeed * (if nitroActive then Physics.NitroSpeedFactor else 1)
	local acceleration = Physics.BaseAcceleration
		* stats.Acceleration
		* (if nitroActive then Physics.NitroAccelerationFactor else 1)
	local maxReverse = baseMaxSpeed * Physics.ReverseSpeedFactor

	local forwardAccel = 0
	local function slowDown(rate: number)
		forwardAccel = -math.sign(forwardSpeed) * math.min(math.abs(forwardSpeed) / dt, rate)
	end

	if handbrake then
		slowDown(Physics.HandbrakeDeceleration)
	elseif throttle > 0.05 then
		if forwardSpeed < -0.5 then
			forwardAccel = Physics.BrakeDeceleration * throttle
		elseif forwardSpeed > maxSpeed then
			forwardAccel = -(forwardSpeed - maxSpeed) * 2 -- nach Nitro sanft abbremsen
		else
			forwardAccel = acceleration * throttle * (1 - forwardSpeed / maxSpeed)
		end
	elseif throttle < -0.05 then
		if forwardSpeed > 0.5 then
			forwardAccel = -Physics.BrakeDeceleration * -throttle
		else
			forwardAccel = -acceleration * -throttle * math.max(0, 1 + forwardSpeed / maxReverse)
		end
	else
		slowDown(Physics.CoastDeceleration)
	end

	local grip = if handbrake and state.Riding then Physics.HandbrakeGrip else Physics.Grip
	local sideAccel = math.clamp(-sideSpeed * grip, -Physics.MaxLateralAcceleration, Physics.MaxLateralAcceleration)

	local horizontalForce = Vector3.zero
	if grounded then
		horizontalForce = (forward * forwardAccel + right * sideAccel) * mass
	end
	driveForce.Force = Vector3.new(0, upForce, 0) + horizontalForce

	-- 4) Lenken (nur mit Bodenkontakt)
	local speedRatio = math.clamp(math.abs(forwardSpeed) / baseMaxSpeed, 0, 1)
	if grounded then
		local lowSpeedFactor = math.clamp(math.abs(forwardSpeed) / 8, 0, 1)
		local highSpeedFactor = 1 - (1 - Physics.HighSpeedTurnFactor) * speedRatio
		local turnRate = Physics.BaseTurnRate * stats.Handling * lowSpeedFactor * highSpeedFactor
		local direction = if forwardSpeed >= 0 then 1 else -1
		heading -= steer * turnRate * direction * dt
	end

	-- Nach einem Crash: Richtung an die echte Ausrichtung anpassen
	local flatLook = cf.LookVector * Vector3.new(1, 0, 1)
	if flatLook.Magnitude > 0.3 then
		local actualYaw = yawFromVector(flatLook)
		if math.abs(angleDiff(heading, actualYaw)) > 0.7 then
			heading = actualYaw
		end
	end

	-- 5) Aufrecht halten + in die Kurve legen
	local up = if grounded then groundNormal else Vector3.yAxis
	local headingVector = vectorFromYaw(heading)
	local projected = (headingVector - up * headingVector:Dot(up)).Unit
	local lean = -steer * Physics.MaxLean * math.clamp(math.abs(forwardSpeed) / 25, 0, 1)
	upright.CFrame = CFrame.lookAt(Vector3.zero, projected, up) * CFrame.Angles(0, 0, lean)
	upright.Responsiveness = if grounded then Physics.UprightResponsiveness else Physics.AirborneResponsiveness

	-- 6) Zustand für HUD/Kamera
	local horizontalSpeed = (velocity * Vector3.new(1, 0, 1)).Magnitude
	state.SpeedKmh = horizontalSpeed * KMH
	state.ForwardSpeed = forwardSpeed
	state.Grounded = grounded
	state.NitroActive = nitroActive
end

------------------------------------------------------------------------
-- Eigenes Fahrzeug finden / verlieren
------------------------------------------------------------------------

local function setRiding(riding: boolean)
	if state.Riding == riding then
		return
	end
	state.Riding = riding
	handbrakeHeld = false

	if riding then
		-- Leertaste = Handbremse (statt Springen/Absteigen)
		ContextActionService:BindActionAtPriority(ACTION_HANDBRAKE, function(_, inputState)
			handbrakeHeld = inputState == Enum.UserInputState.Begin
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonX)

		ContextActionService:BindAction(ACTION_HORN, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				VehicleController.honk()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.H, Enum.KeyCode.ButtonY)

		ContextActionService:BindAction(ACTION_NITRO, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				VehicleController.nitro()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB)

		ContextActionService:BindAction(ACTION_EXIT, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				VehicleController.exit()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.F)
	else
		ContextActionService:UnbindAction(ACTION_HANDBRAKE)
		ContextActionService:UnbindAction(ACTION_HORN)
		ContextActionService:UnbindAction(ACTION_NITRO)
		ContextActionService:UnbindAction(ACTION_EXIT)
	end

	updateRaycastFilter()
	ridingChangedEvent:Fire(riding)
end

local function checkRiding()
	local humanoid = getHumanoid()
	setRiding(humanoid ~= nil and state.Seat ~= nil and humanoid.SeatPart == state.Seat)
end

local function attachVehicle(model: Model)
	local root = model:WaitForChild("Body", 10) :: BasePart?
	local seat = model:WaitForChild("Seat", 10) :: VehicleSeat?
	if not root or not seat then
		return
	end

	state.Vehicle = model
	state.Root = root
	state.Seat = seat
	state.Stats = Config.Vehicles[model:GetAttribute("ModelId")] or Config.Vehicles.Classic
	driveForce = root:WaitForChild("Drive", 10) :: VectorForce?
	upright = root:WaitForChild("Upright", 10) :: AlignOrientation?
	heading = yawFromVector(root.CFrame.LookVector * Vector3.new(1, 0, 1))

	updateRaycastFilter()
	checkRiding()

	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) and state.Vehicle == model then
			state.Vehicle, state.Root, state.Seat = nil, nil, nil
			driveForce, upright = nil, nil
			setRiding(false)
		end
	end)
end

-- Fremde Fahrzeuge: deren "Aufsteigen"-Prompt lokal ausblenden
local function onVehicleAdded(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local ownerId = model:GetAttribute("OwnerUserId")
	if ownerId == nil then
		model:GetAttributeChangedSignal("OwnerUserId"):Wait()
		ownerId = model:GetAttribute("OwnerUserId")
	end

	if ownerId == player.UserId then
		attachVehicle(model)
	else
		local seat = model:WaitForChild("Seat", 10)
		local prompt = seat and seat:WaitForChild("EnterPrompt", 10)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = false
		end
	end
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(checkRiding)
	checkRiding()
	updateRaycastFilter()
end

------------------------------------------------------------------------
-- Lebenszyklus
------------------------------------------------------------------------

function VehicleController.Init() end

function VehicleController.Start()
	local vehiclesFolder = workspace:WaitForChild("Vehicles")
	vehiclesFolder.ChildAdded:Connect(function(child)
		task.spawn(onVehicleAdded, child)
	end)
	for _, child in ipairs(vehiclesFolder:GetChildren()) do
		task.spawn(onVehicleAdded, child)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	-- Figuren anderer Spieler respawnen ständig: Filter regelmäßig erneuern
	task.spawn(function()
		while true do
			task.wait(2)
			updateRaycastFilter()
		end
	end)

	-- Kukurin rufen: R (immer verfügbar)
	ContextActionService:BindAction(ACTION_CALL, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			VehicleController.requestSpawn()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.R)

	RunService.PreSimulation:Connect(step)
end

return VehicleController
