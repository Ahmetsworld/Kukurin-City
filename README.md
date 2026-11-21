# Kukurin City

Open-World-Chaos-Fahrspiel für Roblox (Luau + Rojo).

## Projektstruktur

```
default.project.json        Rojo-Projekt (Ordner -> Roblox-Services)
aftman.toml                 Tool-Versionen (Rojo 7.4.4)
src/
  shared/   -> ReplicatedStorage.Shared
    Config.lua              ALLE Balancing-/Layout-Werte
    Remotes.lua             Alle RemoteEvents/Functions + Rate-Limit
    CityLayout.lua          Raster-Mathematik der Stadt (Server + Client)
  server/   -> ServerScriptService.Server
    Main.server.lua         Startet Services (Init -> Start)
    Services/               WorldService, MapService, TrafficLightService, VehicleService
    Vehicles/               ScooterBuilder (Kukurin-E-Scooter aus Parts)
    Map/                    Map-Builder (Straßen, Blöcke, Landmarken, Ampeln)
  client/   -> StarterPlayerScripts.Client
    Main.client.lua         Startet Controller
    Controllers/            VehicleController (Fahrphysik), CameraController,
                            HudController, DistrictController
    UI/UiKit.lua            UI-Helfer im Markenlook
ServerStorage.Assets        Ordner für spätere Mesh-Models (siehe unten)
```

## Steuerung (Kukurin E-Scooter)

| Aktion | Tastatur | Gamepad | Handy |
|---|---|---|---|
| Gas / Bremsen / Lenken | WASD oder Pfeiltasten | linker Stick, R2/L2 | Thumbstick |
| Handbremse (Drift) | Leertaste | X | BREMSE (halten) |
| Hupe | H | Y | HUPE |
| Nitro (Modelle mit Nitro) | Shift links | B | NITRO |
| Aufsteigen | E (am Scooter) | Y | antippen |
| Absteigen | F | A | AB |
| Kukurin rufen | R | – | Knopf unten |

## Marke & Look

Kukurin ist eine **eigene, ausgedachte Cartoon-Marke**. Damit es keinen
Ärger mit Markenrechten oder der Roblox-Moderation gibt:

- **keine** Logos, Schriftzüge oder Modellnamen echter E-Scooter-Hersteller
- **kein** Orange-Schwarz-Farbschema, das an echte Roller erinnert
- Markenfarben nur aus `Config.Brand`: Türkis, Pink, Sonnengelb, Dunkelblau
- Markenzeichen ist das **Kukurin-Gesicht** (Scheinwerfer-Augen + Grinsen vorne am Lenker)
- Fotos echter Roller nicht als Texturen/Decals verwenden

## Einrichtung (einmalig)

1. **Rojo installieren** (Version 7.4.x)
   - mit [Aftman](https://github.com/LPGhatguy/aftman): im Projektordner `aftman install`
   - oder in VS Code die Erweiterung **Rojo** installieren
2. **Rojo-Plugin in Studio installieren**: `rojo plugin install` oder in Studio
   unter *Toolbox → Plugins* nach „Rojo“ suchen (von *rojo-rbx*/Lpghatguy).
3. In Studio eine neue **Baseplate**-Vorlage öffnen.
4. Im Projektordner `rojo serve` starten.
5. In Studio: *Plugins → Rojo → Connect*. Die Scripts erscheinen in
   ServerScriptService, StarterPlayerScripts und ReplicatedStorage.
6. **StreamingEnabled prüfen**: Explorer → *Workspace* → Properties →
   `StreamingEnabled` muss angehakt sein. Rojo kann diese Eigenschaft beim
   Live-Sync nicht immer setzen.

Alternative ohne Live-Sync: `rojo build -o KukurinCity.rbxlx` und die Datei in
Studio öffnen.

## Wichtig: Die Map entsteht erst beim Spielstart

Die Stadt wird vom Server **per Script** gebaut (`MapService`). Im
Edit-Modus von Studio sieht man deshalb nur die leere Baseplate. Erst mit
**Play (F5)** oder **Run (F8)** steht die Stadt.

## Mesh-Platzhalter ersetzen (später)

Lege in `ServerStorage/Assets` ein Model mit einem dieser Namen ab. Der
Builder benutzt es dann statt der Parts. Der Pivot des Models ist der
Bodenmittelpunkt, die Vorderseite zeigt nach -Z.

| Asset-Name | ersetzt |
|---|---|
| `Tower` | Hochhäuser |
| `House` | Wohnhäuser |
| `Warehouse` | Lagerhallen |
| `Tree` | Bäume |
| `Ramp` | Stunt-Rampen |
| `Scooter_<ModelId>` (z. B. `Scooter_Classic`) | Optik eines Kukurin; ein Part namens `Seat` darin markiert die Sitzposition |
| `Landmark_Spawn`, `Landmark_Dealer`, `Landmark_RepairShop`, `Landmark_Police` | komplette Landmarken |
