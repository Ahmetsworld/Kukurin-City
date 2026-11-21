--[[
	Main.client.lua
	------------------------------------------------------------------
	Einstiegspunkt des Clients. Lädt alle Controller in fester
	Reihenfolge: erst Init() bei allen, dann Start() bei allen.

	Der Client zeigt nur an und schickt Eingaben. Entscheidungen
	(Geld, Schaden, Käufe ...) trifft immer der Server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CONTROLLER_ORDER = {
	"VehicleController",
	"CameraController",
	"HudController",
	"DistrictController",
}

print(("[Kukurin City] Client startet – %s"):format(Config.Version))

local controllersFolder = script.Parent:WaitForChild("Controllers")
local controllers = {}

for _, name in ipairs(CONTROLLER_ORDER) do
	local module = controllersFolder:WaitForChild(name, 10)
	if not module then
		warn("[Kukurin City] Controller fehlt: " .. name)
		continue
	end
	local ok, result = pcall(require, module)
	if ok then
		controllers[name] = result
	else
		warn(("[Kukurin City] %s konnte nicht geladen werden: %s"):format(name, tostring(result)))
	end
end

for _, methodName in ipairs({ "Init", "Start" }) do
	for _, name in ipairs(CONTROLLER_ORDER) do
		local controller = controllers[name]
		if controller and type(controller[methodName]) == "function" then
			local ok, err = pcall(controller[methodName])
			if not ok then
				warn(("[Kukurin City] %s.%s fehlgeschlagen: %s"):format(name, methodName, tostring(err)))
			end
		end
	end
end
