--[[
	Config.lua
	------------------------------------------------------------------
	ALLE Balancing- und Layout-Werte von Kukurin City an einem Ort.

	Regeln:
	  * Andere Module lesen nur aus Config, sie schreiben nie hinein.
	  * Der Server benutzt diese Werte als Wahrheit. Der Client darf sie
	    nur zur Anzeige verwenden (Preise im Menü, Tacho-Skala usw.).
	  * Werte mit dem Kommentar "(Phase X)" werden erst ab der genannten
	    Phase benutzt, stehen aber schon hier, damit alles zentral bleibt.
]]

local Config = {}

Config.Version = "0.1.0 (Phase 1)"

------------------------------------------------------------------------
-- MAP / STADTLAYOUT
------------------------------------------------------------------------
-- Die Stadt ist ein Raster aus Blöcken (Grundstücken), getrennt durch
-- Straßen. Spalten (Col) laufen in +X-Richtung (Osten),
-- Zeilen (Row) in +Z-Richtung (Süden). Der mittlere Block liegt bei (0, 0).
Config.Map = {
	Seed = 1337, -- gleicher Seed = gleiche Stadt bei jedem Start

	BlocksX = 7, -- Anzahl Blöcke in X-Richtung
	BlocksZ = 7, -- Anzahl Blöcke in Z-Richtung
	BlockSize = 120, -- Kantenlänge eines Blocks inkl. Bürgersteig (Studs)
	RoadWidth = 36, -- Fahrbahnbreite (2 Spuren à 18 Studs)
	SidewalkWidth = 10, -- Breite des Bürgersteigs rund um jeden Block
	SidewalkHeight = 0.6, -- Bordsteinhöhe (niedrig genug zum Drüberfahren)
	LotRaise = 0.1, -- Grundstück liegt so viel höher als der Bürgersteig

	GroundSize = 2048, -- Grasfläche rund um die Stadt (max. Part-Größe)

	-- Fahrbahnmarkierungen
	DashLength = 6,
	DashGap = 7,
	DashWidth = 0.8,
	MarkingHeight = 0.05,

	-- Zebrastreifen (nur an Straßen mit Bürgersteig auf beiden Seiten)
	ZebraDepth = 7, -- Länge der Streifen in Fahrtrichtung
	ZebraStripeWidth = 2.5,
	ZebraStripeSpacing = 5, -- Abstand Mitte zu Mitte
	ZebraInset = 1, -- Abstand zur Kreuzung

	-- Stadtteile pro Block. Zeile 1 = Norden (-Z), Spalte 1 = Westen (-X).
	--   D = Innenstadt, W = Wohnviertel, I = Industriegebiet,
	--   P = Park,       S = Stuntzone
	-- Landmarken (siehe Config.Landmarks) überschreiben einzelne Blöcke.
	Districts = {
		{ "W", "W", "W", "P", "P", "I", "I" },
		{ "W", "W", "D", "D", "P", "I", "I" },
		{ "W", "D", "D", "D", "D", "I", "I" },
		{ "W", "D", "D", "D", "D", "D", "I" },
		{ "W", "W", "D", "D", "D", "S", "S" },
		{ "P", "W", "W", "D", "S", "S", "S" },
		{ "P", "P", "W", "W", "S", "S", "S" },
	},
}

-- Aussehen und Gebäude-Parameter je Stadtteil
Config.Districts = {
	D = {
		Name = "Innenstadt",
		LotColor = Color3.fromRGB(190, 190, 195),
		LotMaterial = Enum.Material.Concrete,
		TowerHeight = { 50, 170 }, -- min/max Höhe der Hochhäuser
		TowerColors = {
			Color3.fromRGB(120, 170, 230),
			Color3.fromRGB(240, 200, 90),
			Color3.fromRGB(235, 120, 120),
			Color3.fromRGB(150, 220, 170),
			Color3.fromRGB(200, 160, 230),
			Color3.fromRGB(245, 245, 245),
		},
		WindowColor = Color3.fromRGB(170, 225, 255),
	},
	W = {
		Name = "Wohnviertel",
		LotColor = Color3.fromRGB(110, 190, 90),
		LotMaterial = Enum.Material.Grass,
		HouseColors = {
			Color3.fromRGB(255, 230, 170),
			Color3.fromRGB(255, 190, 190),
			Color3.fromRGB(190, 225, 255),
			Color3.fromRGB(210, 255, 200),
			Color3.fromRGB(255, 255, 255),
		},
		RoofColors = {
			Color3.fromRGB(200, 80, 60),
			Color3.fromRGB(90, 90, 110),
			Color3.fromRGB(150, 90, 60),
		},
	},
	I = {
		Name = "Industriegebiet",
		LotColor = Color3.fromRGB(120, 115, 110),
		LotMaterial = Enum.Material.Asphalt,
		HallColors = {
			Color3.fromRGB(170, 170, 160),
			Color3.fromRGB(140, 160, 175),
			Color3.fromRGB(190, 170, 140),
		},
		ContainerColors = {
			Color3.fromRGB(220, 80, 60),
			Color3.fromRGB(60, 130, 200),
			Color3.fromRGB(70, 170, 90),
			Color3.fromRGB(240, 180, 40),
		},
	},
	P = {
		Name = "Park",
		LotColor = Color3.fromRGB(95, 200, 95),
		LotMaterial = Enum.Material.Grass,
		TreeCount = 9,
	},
	S = {
		Name = "Stuntzone",
		LotColor = Color3.fromRGB(80, 80, 90),
		LotMaterial = Enum.Material.Asphalt,
		RampColor = Color3.fromRGB(255, 170, 40),
	},
}

-- Wichtige Orte. Col/Row = Block im Raster (1-basiert).
-- Die Builder-Module legen dort ein eigenes Gebäude + Schild an.
Config.Landmarks = {
	Spawn = {
		Col = 4,
		Row = 4,
		DisplayName = "Spawn-Platz",
		SignText = "WILLKOMMEN IN KUKURIN CITY",
		Color = Color3.fromRGB(255, 200, 60),
	},
	Dealer = {
		Col = 3,
		Row = 4,
		DisplayName = "Kukurin-Händler",
		SignText = "KUKURIN-HÄNDLER",
		Color = Color3.fromRGB(60, 170, 255),
	},
	RepairShop = {
		Col = 5,
		Row = 4,
		DisplayName = "Kukurin Repair Shop",
		SignText = "KUKURIN REPAIR SHOP",
		Color = Color3.fromRGB(255, 120, 40),
	},
	Police = {
		Col = 4,
		Row = 6,
		DisplayName = "Polizeistation",
		SignText = "POLIZEI",
		Color = Color3.fromRGB(40, 80, 200),
	},
}

------------------------------------------------------------------------
-- AMPELN
------------------------------------------------------------------------
Config.TrafficLights = {
	Enabled = true, -- Ampeln stehen an allen Innen-Kreuzungen (nicht am Stadtrand)
	GreenTime = 8, -- Sekunden
	YellowTime = 2,
	AllRedTime = 1, -- Sicherheitspause, in der alle Richtungen Rot haben
	GreenWaveOffset = 2, -- Versatz pro Kreuzung, ergibt eine leichte "grüne Welle"
	UpdateInterval = 0.25, -- wie oft der Server den Ampelzustand prüft
}

------------------------------------------------------------------------
-- FAHRZEUGE (Phase 2 und 6)
------------------------------------------------------------------------
-- Speed = Höchstgeschwindigkeit in "Tacho-km/h" (Anzeige-Einheit).
-- Price = nil bedeutet: Startfahrzeug, gehört jedem Spieler.
Config.VehicleOrder = { "Classic", "Sport", "Panzer", "TurboX", "Monster", "Gold" }

Config.Vehicles = {
	Classic = {
		DisplayName = "Kukurin Classic",
		Price = nil,
		Speed = 80,
		Acceleration = 1.0,
		Handling = 1.0,
		HP = 100,
		RamDamage = 10,
		Nitro = 0, -- Anzahl Nitro-Ladungen (0 = kein Nitro)
		Knockback = 1.0, -- Rückstoß-Faktor bei Crashs
		ChaosMultiplier = 1,
	},
	Sport = {
		DisplayName = "Kukurin Sport",
		Price = 2500,
		Speed = 130,
		Acceleration = 1.4,
		Handling = 1.3,
		HP = 80,
		RamDamage = 12,
		Nitro = 1,
		Knockback = 1.0,
		ChaosMultiplier = 1,
	},
	Panzer = {
		DisplayName = "Kukurin Panzer",
		Price = 6000,
		Speed = 70,
		Acceleration = 0.8,
		Handling = 0.8,
		HP = 300,
		RamDamage = 25,
		Nitro = 0,
		Knockback = 0.2, -- kaum Rückstoß
		ChaosMultiplier = 1,
	},
	TurboX = {
		DisplayName = "Kukurin Turbo X",
		Price = 12000,
		Speed = 180,
		Acceleration = 1.8,
		Handling = 1.2,
		HP = 120,
		RamDamage = 18,
		Nitro = 2, -- doppeltes Nitro
		Knockback = 1.0,
		ChaosMultiplier = 1,
	},
	Monster = {
		DisplayName = "Kukurin Monster",
		Price = 25000,
		Speed = 110,
		Acceleration = 1.1,
		Handling = 0.9,
		HP = 250,
		RamDamage = 40,
		Nitro = 0,
		Knockback = 0.5,
		ChaosMultiplier = 1,
		GiantWheels = true, -- Riesenreifen, fährt über Autos
	},
	Gold = {
		DisplayName = "Kukurin Gold",
		Price = 100000,
		Speed = 160,
		Acceleration = 1.5,
		Handling = 1.3,
		HP = 200,
		RamDamage = 30,
		Nitro = 1,
		Knockback = 0.8,
		ChaosMultiplier = 2, -- Chaos-Punkte x2
	},
}

------------------------------------------------------------------------
-- WIRTSCHAFT & SPEICHERN (Phase 5)
------------------------------------------------------------------------
Config.Economy = {
	StartMoney = 500,
	InstantRepairCostPerHP = 5, -- Sofort-Reparatur in der Werkstatt
}

Config.DataStore = {
	Name = "KukurinCity_PlayerData_v1",
	AutosaveInterval = 120, -- Sekunden
	MaxRetries = 3,
}

------------------------------------------------------------------------
-- PERFORMANCE (Phase 3, 4, 10)
------------------------------------------------------------------------
Config.Performance = {
	MaxTrafficCars = 20,
	MaxDummies = 30,
	MaxPoliceCars = 6,
	DummyRespawnTime = 5,
}

------------------------------------------------------------------------
-- SICHERHEIT
------------------------------------------------------------------------
Config.Security = {
	DefaultRemoteRate = 10, -- erlaubte Aufrufe pro Sekunde und Remote je Spieler
	DefaultRemoteBurst = 20, -- kurzer Puffer für Spitzen
}

return Config
