--[[
	Main.server.lua
	------------------------------------------------------------------
	Einstiegspunkt des Servers. Lädt alle Services in fester
	Reihenfolge und ruft erst bei allen Init() und dann bei allen
	Start() auf.

	  Init()  – Dinge vorbereiten, die andere brauchen (Map bauen, ...)
	  Start() – Loops/Events starten (darf sich auf andere verlassen)

	Neue Services: Datei in Services/ anlegen und hier in SERVICE_ORDER
	eintragen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SERVICE_ORDER = {
	"WorldService",
	"MapService",
	"TrafficLightService",
	"VehicleService",
}

print(("[Kukurin City] Server startet – %s"):format(Config.Version))

-- Remotes zuerst, damit Clients sie so früh wie möglich finden
Remotes.setup()

local servicesFolder = script.Parent:WaitForChild("Services")
local services = {}

for _, name in ipairs(SERVICE_ORDER) do
	local module = servicesFolder:FindFirstChild(name)
	if not module then
		warn("[Kukurin City] Service fehlt: " .. name)
		continue
	end
	local ok, result = pcall(require, module)
	if ok then
		services[name] = result
	else
		warn(("[Kukurin City] %s konnte nicht geladen werden: %s"):format(name, tostring(result)))
	end
end

local function runPhase(methodName: string)
	for _, name in ipairs(SERVICE_ORDER) do
		local service = services[name]
		if service and type(service[methodName]) == "function" then
			local ok, err = pcall(service[methodName])
			if not ok then
				warn(("[Kukurin City] %s.%s fehlgeschlagen: %s"):format(name, methodName, tostring(err)))
			end
		end
	end
end

runPhase("Init")
runPhase("Start")

print("[Kukurin City] Server bereit")
