--[[
	Remotes.lua
	------------------------------------------------------------------
	Zentrale Verwaltung aller RemoteEvents und RemoteFunctions.

	* Alle Remotes werden NUR hier definiert (DEFINITIONS).
	* Der Server ruft einmal Remotes.setup() auf und erzeugt sie in
	  ReplicatedStorage/Remotes.
	* Client und Server holen sie mit Remotes.get("Name").
	* Serverseitige Handler werden mit Remotes.onServerEvent /
	  Remotes.onServerInvoke angemeldet. Dabei gibt es automatisch
	  ein Rate-Limit pro Spieler und Fehler im Handler werden
	  abgefangen. Die Argumente MUSS der Handler trotzdem selbst
	  prüfen: Dem Client wird nichts geglaubt.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Remotes = {}

local FOLDER_NAME = "Remotes"
local CLIENT_WAIT_TIMEOUT = 30

-- Name -> Klasse. Richtung im Kommentar: S->C = Server an Client.
local DEFINITIONS = {
	-- Allgemein
	Notify = "RemoteEvent", -- S->C: kurze Meldung/Toast

	-- Phase 2: Fahrzeug
	RequestSpawnVehicle = "RemoteEvent", -- C->S: "Ich möchte mein Auto"
	Honk = "RemoteEvent", -- C->S: Hupe (KI weicht aus, Phase 4)

	-- Phase 3/4: Chaos
	ChaosPopup = "RemoteEvent", -- S->C: "CRASH! +50"

	-- Phase 5: Reparatur-Minigame & Daten
	RepairStart = "RemoteFunction", -- C->S: Minigame starten, Server liefert Schadstellen
	RepairHit = "RemoteEvent", -- C->S: Hammerschlag auf Schadstelle
	RepairFinish = "RemoteFunction", -- C->S: Minigame beendet, Server rechnet Belohnung
	DataChanged = "RemoteEvent", -- S->C: Geld/Inventar haben sich geändert

	-- Phase 6/7: Händler & Werkstatt
	BuyVehicle = "RemoteFunction",
	EquipVehicle = "RemoteFunction",
	BuyUpgrade = "RemoteFunction",
	InstantRepair = "RemoteFunction",

	-- Phase 8: Polizei
	WantedChanged = "RemoteEvent", -- S->C: neue Sternzahl
}

local folder: Folder? = nil

-- Rate-Limit-Speicher: buckets[player][remoteName] = { tokens, lastTime }
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

------------------------------------------------------------------------
-- Interne Helfer
------------------------------------------------------------------------

local function assertKnown(name: string)
	if DEFINITIONS[name] == nil then
		error(("[Remotes] Unbekanntes Remote '%s'. Erst in DEFINITIONS eintragen."):format(tostring(name)), 3)
	end
end

-- Token-Bucket: true = Aufruf erlaubt
local function consumeToken(player: Player, name: string, rate: number, burst: number): boolean
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end

	local now = os.clock()
	local bucket = perPlayer[name]
	if not bucket then
		bucket = { tokens = burst, last = now }
		perPlayer[name] = bucket
	end

	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.last) * rate)
	bucket.last = now

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

------------------------------------------------------------------------
-- Öffentliche API
------------------------------------------------------------------------

-- Nur auf dem Server, einmal beim Start aufrufen.
function Remotes.setup()
	assert(RunService:IsServer(), "[Remotes] setup() darf nur der Server aufrufen")
	if folder then
		return
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME

	for name, className in pairs(DEFINITIONS) do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = newFolder
	end

	-- Erst nach dem Befüllen parenten, damit Clients alles auf einmal sehen.
	newFolder.Parent = ReplicatedStorage
	folder = newFolder

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

-- Gibt das Remote-Objekt zurück (Client wartet, bis es existiert).
function Remotes.get(name: string): Instance
	assertKnown(name)

	if RunService:IsServer() then
		assert(folder, "[Remotes] setup() wurde noch nicht aufgerufen")
		return folder:FindFirstChild(name) :: Instance
	end

	local remoteFolder = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_WAIT_TIMEOUT)
	assert(remoteFolder, "[Remotes] Ordner 'Remotes' nicht gefunden")
	local remote = remoteFolder:WaitForChild(name, CLIENT_WAIT_TIMEOUT)
	assert(remote, ("[Remotes] Remote '%s' nicht gefunden"):format(name))
	return remote
end

type HandlerOptions = {
	rate: number?, -- Aufrufe pro Sekunde
	burst: number?,
}

-- Server: RemoteEvent-Handler mit Rate-Limit und Fehlerschutz anmelden.
function Remotes.onServerEvent(name: string, handler: (Player, ...any) -> (), options: HandlerOptions?)
	assert(RunService:IsServer(), "[Remotes] onServerEvent nur auf dem Server")
	local remote = Remotes.get(name) :: RemoteEvent
	assert(remote:IsA("RemoteEvent"), ("[Remotes] '%s' ist kein RemoteEvent"):format(name))

	local rate = (options and options.rate) or Config.Security.DefaultRemoteRate
	local burst = (options and options.burst) or Config.Security.DefaultRemoteBurst

	return remote.OnServerEvent:Connect(function(player, ...)
		if not consumeToken(player, name, rate, burst) then
			return -- Spam ignorieren
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(("[Remotes] Fehler in '%s' (%s): %s"):format(name, player.Name, tostring(err)))
		end
	end)
end

-- Server: RemoteFunction-Handler anmelden. Bei Spam/Fehler kommt nil zurück.
function Remotes.onServerInvoke(name: string, handler: (Player, ...any) -> ...any, options: HandlerOptions?)
	assert(RunService:IsServer(), "[Remotes] onServerInvoke nur auf dem Server")
	local remote = Remotes.get(name) :: RemoteFunction
	assert(remote:IsA("RemoteFunction"), ("[Remotes] '%s' ist keine RemoteFunction"):format(name))

	local rate = (options and options.rate) or Config.Security.DefaultRemoteRate
	local burst = (options and options.burst) or Config.Security.DefaultRemoteBurst

	remote.OnServerInvoke = function(player, ...)
		if not consumeToken(player, name, rate, burst) then
			return nil
		end
		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			warn(("[Remotes] Fehler in '%s' (%s): %s"):format(name, player.Name, tostring(results[2])))
			return nil
		end
		return table.unpack(results, 2, results.n)
	end
end

return Remotes
