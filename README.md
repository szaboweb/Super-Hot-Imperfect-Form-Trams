# Super Hot Imperfect Form Trams

Top-down tram racing game built with **Flutter + Flame + Dart**.
Brakeless trams race through European-style city maps; you flip the switches behind them to send the
next ones into collisions, dead ends, the river or construction sites (see [game design](docs/GAME_DESIGN.md)).
Art is modelled in **Blender 3D**, rendered to sprites and finished in **Aseprite**.
Targets: Windows, Linux / Steam Deck (itch.io and Steam later).

## Run

```sh
flutter pub get
flutter run -d windows     # or: -d linux, -d chrome
flutter test
```

Controls: arrows / WASD.

## Structure

| Path | Purpose |
|------|---------|
| `lib/game/` | Flame game, components, systems, levels |
| `lib/ui/`, `lib/input/`, `lib/audio/`, `lib/core/` | Menus/HUD, input mapping (keyboard + gamepad), audio, shared utils |
| `assets/` | Game-ready assets (images, audio, level data, fonts) |
| `art/` | Sources: Blender scenes, Aseprite files, references |
| `tools/` | Render / export scripts (Blender → Aseprite → game) |
| `docs/` | [Game design](docs/GAME_DESIGN.md), [asset pipeline](docs/ASSET_PIPELINE.md), [distribution](docs/DISTRIBUTION.md) |
| `distribution/` | itch.io / Steam packaging files |
| `test/` | Unit and Flame tests |

## License

Code: MIT (see [LICENSE](LICENSE)). Art assets: all rights reserved unless stated otherwise.
