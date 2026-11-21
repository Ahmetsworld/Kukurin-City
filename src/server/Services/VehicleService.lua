--[[
	VehicleService.lua
	------------------------------------------------------------------
	Verwaltet die Kukurin-Scooter aller Spieler (serverseitig).

	* Jeder Spieler hat genau einen Scooter in Workspace.Vehicles.
	* Spawnen/Rufen, Hupe und Nitro laufen über Remotes und werden
	  hier geprüft (Cooldowns, Besitz, Nitro-Ladungen).
	* Die Fahrphysik rechnet der Client des Besitzers (Network Owner),
	  damit das Fahren ohne Verzögerung reagiert. Der Server überwacht
	  aber das Tempo und nimmt dem Client bei Schummeln die Kontrolle ab.

	Attribute am Fahrzeug-Model (Client liest sie, nur Server schreibt):
	  OwnerUserId, ModelId, RideHeight, HP, MaxHP, MaxSpeed (km/h),
	  NitroCharges, NitroMax, NitroActiveUntil (Serverzeit)

	Welches Modell gefahren wird, steht im Spieler-Attribut
	"EquippedVehicle" (ab Phase 5/6 aus den gespeicherten Daten).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ScooterBuilder = require(script.Parent.Parent.Vehicles.ScooterBuilder)

local Physics = Config.VehiclePhysics

type VehicleRecord = {
	Player: Player,
	Model: Model,
	Root: BasePart,
	Seat: VehicleSeat,
	ModelId: string,
	Stats: any,
	Violations: number,
	NitroRecharge: number,
}

local VehicleService = {}

-- Signal für andere Systeme (Phase 4: KI weicht beim Hupen aus)
local honkedEvent = Instance.new("BindableEvent")
VehicleService.Honked = honkedEvent.Event -- (player, vehicleModel)

local vehiclesFolder: Folder
local records: { [Player]: VehicleRecord } = {}
local lastSpawn: { [Player]: number } = {}
local lastHonk: { [Player]: number } = {}

------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------

local function notify(player: Player, text: string)
	local remote = Remotes.get("Notify") :: RemoteEvent
	remote:FireClient(player, text)
end

local function getEquippedModelId(player: Player): string
	local id = player:GetAttribute("EquippedVehicle")
	if type(id) == "string" and Config.Vehicles[id] then
		return id
	end
	return "Classic"
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- Sitzt der Spieler gerade auf seinem eigenen Scooter?
local function isRiding(player: Player, record: VehicleRecord?): boolean
	if not record then
		return false
	end
	local occupant = record.Seat.Occupant
	return occupant ~= nil and occupant.Parent == player.Character
end

-- Spawnpunkt vor dem Spieler auf dem Boden
local function findSpawnCFrame(player: Player, rideHeight: number): CFrame?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end

	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local spot = root.Position + look * 7

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { vehiclesFolder }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore

	local result = workspace:Raycast(spot + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	local groundY = if result then result.Position.Y else root.Position.Y - 3
	local position = Vector3.new(spot.X, groundY + rideHeight + 0.5, spot.Z)
	return CFrame.lookAt(position, position + look)
end

local function despawn(player: Player)
	local record = records[player]
	if record then
		records[player] = nil
		record.Model:Destroy()
	end
end

-- Nur der Besitzer darf aufsitzen
local function guardSeat(record: VehicleRecord)
	local seat = record.Seat
	local prompt = seat:FindFirstChild("EnterPrompt") :: ProximityPrompt?

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		if prompt then
			prompt.Enabled = occupant == nil
		end
		if not occupant then
			return
		end
		local sitter = Players:GetPlayerFromCharacter(occupant.Parent)
		if sitter ~= record.Player then
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			if sitter then
				notify(sitter, "Das ist nicht dein Kukurin!")
			end
		end
	end)
end

local function addEnterPrompt(record: VehicleRecord)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = "Aufsteigen"
	prompt.ObjectText = Config.Vehicles[record.ModelId].DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = record.Seat

	prompt.Triggered:Connect(function(player)
		if player ~= record.Player then
			notify(player, "Das ist nicht dein Kukurin!")
			return
		end
		local humanoid = getHumanoid(player)
		if humanoid and not humanoid.SeatPart then
			record.Seat:Sit(humanoid)
		end
	end)
end

------------------------------------------------------------------------
-- Spawnen
------------------------------------------------------------------------

-- Erzeugt (oder ersetzt) den Scooter eines Spielers.
-- sitDown = Spieler direkt draufsetzen
function VehicleService.spawnFor(player: Player, sitDown: boolean?): Model?
	local modelId = getEquippedModelId(player)
	local stats = Config.Vehicles[modelId]

	local model = ScooterBuilder.build(modelId)
	local rideHeight = model:GetAttribute("RideHeight") :: number
	local cframe = findSpawnCFrame(player, rideHeight)
	if not cframe then
		model:Destroy()
		return nil
	end

	despawn(player)

	model.Name = player.Name .. "_Kukurin"
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("HP", stats.HP)
	model:SetAttribute("MaxHP", stats.HP)
	model:SetAttribute("MaxSpeed", stats.Speed)
	model:SetAttribute("NitroCharges", stats.Nitro)
	model:SetAttribute("NitroMax", stats.Nitro)
	model:SetAttribute("NitroActiveUntil", 0)

	-- Der Besitzer bekommt sein Fahrzeug immer gestreamt, egal wie weit weg
	model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	model:PivotTo(cframe)
	model.Parent = vehiclesFolder
	model:AddPersistentPlayer(player)

	local root = model.PrimaryPart :: BasePart
	root:SetNetworkOwner(player)

	local record: VehicleRecord = {
		Player = player,
		Model = model,
		Root = root,
		Seat = model:FindFirstChild("Seat") :: VehicleSeat,
		ModelId = modelId,
		Stats = stats,
		Violations = 0,
		NitroRecharge = 0,
	}
	records[player] = record

	addEnterPrompt(record)
	guardSeat(record)

	if sitDown then
		local humanoid = getHumanoid(player)
		if humanoid then
			-- kurz warten, bis der Sitz repliziert ist
			task.delay(0.1, function()
				if records[player] == record and humanoid.Parent then
					record.Seat:Sit(humanoid)
				end
			end)
		end
	end

	return model
end

function VehicleService.getVehicle(player: Player): Model?
	local record = records[player]
	return record and record.Model
end

------------------------------------------------------------------------
-- Remote-Handler
------------------------------------------------------------------------

local function onRequestSpawn(player: Player)
	local now = os.clock()
	if lastSpawn[player] and now - lastSpawn[player] < Physics.SpawnCooldown then
		notify(player, ("Kukurin kommt gleich! (%ds)"):format(math.ceil(Physics.SpawnCooldown - (now - lastSpawn[player]))))
		return
	end
	if not getHumanoid(player) then
		return
	end
	lastSpawn[player] = now
	VehicleService.spawnFor(player, true)
end

local function onHonk(player: Player)
	local record = records[player]
	if not isRiding(player, record) then
		return
	end
	local now = os.clock()
	if lastHonk[player] and now - lastHonk[player] < Config.Sounds.HornCooldown then
		return
	end
	lastHonk[player] = now

	local horn = record.Root:FindFirstChild("Horn") :: Sound?
	if horn then
		horn:Play()
	end
	honkedEvent:Fire(player, record.Model)
end

local function onUseNitro(player: Player)
	local record = records[player]
	if not isRiding(player, record) then
		return
	end
	local model = record.Model
	local now = workspace:GetServerTimeNow()
	local charges = model:GetAttribute("NitroCharges") or 0
	if charges <= 0 or (model:GetAttribute("NitroActiveUntil") or 0) > now then
		return
	end
	model:SetAttribute("NitroCharges", charges - 1)
	model:SetAttribute("NitroActiveUntil", now + Physics.NitroDuration)
end

------------------------------------------------------------------------
-- Überwachung (Anti-Cheat, Nitro nachladen, aus der Welt gefallen)
------------------------------------------------------------------------

local CHECK_INTERVAL = 0.5

local function checkVehicle(record: VehicleRecord)
	local root = record.Root
	local model = record.Model
	if not root.Parent then
		return
	end

	-- Aus der Welt gefallen? Neu rufen.
	if root.Position.Y < Physics.KillY then
		VehicleService.spawnFor(record.Player, isRiding(record.Player, record))
		return
	end

	-- Nitro nachladen
	local charges = model:GetAttribute("NitroCharges") or 0
	local maxCharges = model:GetAttribute("NitroMax") or 0
	if charges < maxCharges then
		record.NitroRecharge += CHECK_INTERVAL
		if record.NitroRecharge >= Physics.NitroRechargeTime then
			record.NitroRecharge = 0
			model:SetAttribute("NitroCharges", charges + 1)
		end
	else
		record.NitroRecharge = 0
	end

	-- Tempo-Check: Der Client rechnet die Physik, also prüfen wir sie hier
	local nitroActive = (model:GetAttribute("NitroActiveUntil") or 0) > workspace:GetServerTimeNow()
	local maxStuds = record.Stats.Speed / Config.Units.KmhPerStudPerSecond
	if nitroActive then
		maxStuds *= Physics.NitroSpeedFactor
	end
	local allowed = maxStuds * Physics.SpeedCheckTolerance + Physics.SpeedCheckSlack
	local horizontal = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)

	if horizontal.Magnitude > allowed then
		record.Violations += 1
		if record.Violations >= 3 then
			warn(("[VehicleService] %s ist zu schnell (%.0f > %.0f), Server übernimmt kurz"):format(
				record.Player.Name,
				horizontal.Magnitude,
				allowed
			))
			record.Violations = 0
			root:SetNetworkOwner(nil)
			root.AssemblyLinearVelocity = Vector3.zero
			task.delay(1.5, function()
				if root.Parent and records[record.Player] == record then
					root:SetNetworkOwner(record.Player)
				end
			end)
		end
	else
		record.Violations = 0
	end
end

------------------------------------------------------------------------
-- Lebenszyklus
------------------------------------------------------------------------

function VehicleService.Init()
	vehiclesFolder = workspace:FindFirstChild("Vehicles") :: Folder
	if not vehiclesFolder then
		vehiclesFolder = Instance.new("Folder")
		vehiclesFolder.Name = "Vehicles"
		vehiclesFolder.Parent = workspace
	end
end

function VehicleService.Start()
	Remotes.onServerEvent("RequestSpawnVehicle", onRequestSpawn, { rate = 1, burst = 2 })
	Remotes.onServerEvent("Honk", onHonk, { rate = 4, burst = 4 })
	Remotes.onServerEvent("UseNitro", onUseNitro, { rate = 2, burst = 2 })

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- Erster Spawn: Scooter neben den Spieler stellen (nicht draufsetzen)
			if records[player] then
				return
			end
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(1)
			if player.Parent and not records[player] then
				VehicleService.spawnFor(player, false)
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		despawn(player)
		lastSpawn[player] = nil
		lastHonk[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			-- Kopie, weil checkVehicle die Tabelle ändern kann (Neu-Spawn)
			local snapshot = {}
			for _, record in pairs(records) do
				table.insert(snapshot, record)
			end
			for _, record in ipairs(snapshot) do
				local ok, err = pcall(checkVehicle, record)
				if not ok then
					warn("[VehicleService] Prüfung fehlgeschlagen: " .. tostring(err))
				end
			end
		end
	end)
end

return VehicleService
