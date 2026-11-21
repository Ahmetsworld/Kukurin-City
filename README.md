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
    Services/               WorldService, MapService, TrafficLightService
    Map/                    Map-Builder (Straßen, Blöcke, Landmarken, Ampeln)
  client/   -> StarterPlayerScripts.Client
    Main.client.lua         Startet Controller
    Controllers/            DistrictController (Stadtteil-Anzeige)
ServerStorage.Assets        Ordner für spätere Mesh-Models (siehe unten)
```

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
| `Landmark_Spawn`, `Landmark_Dealer`, `Landmark_RepairShop`, `Landmark_Police` | komplette Landmarken |
