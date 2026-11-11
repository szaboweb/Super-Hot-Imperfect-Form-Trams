# Project structure (source of truth)

**Rule:** if you add, move or remove a folder or a top-level file, update this file in the same commit.
Status: ✅ exists · 🔲 planned (create when needed, at exactly this path).
Naming rules: [NAMING_CONVENTIONS.md](NAMING_CONVENTIONS.md). Business-confidential docs go in `docs/private/` (git-ignored).

## Tree

```text
Super-Hot-Imperfect-Form-Trams/
├── AGENTS.md                         ✅ entry point for AI agents
├── README.md                         ✅
├── pubspec.yaml                      ✅ deps + asset folders (register new asset dirs here)
├── analysis_options.yaml             ✅ lints
├── lib/
│   ├── main.dart                     ✅ app entry only (MaterialApp + GameWidget)
│   ├── game/
│   │   ├── tram_game.dart            ✅ TramGame (FlameGame): wires world, camera, systems
│   │   ├── components/               Flame components (render + update themselves)
│   │   │   ├── tram_component.dart       ✅ TramComponent
│   │   │   ├── player_component.dart     🔲 PlayerComponent (runs along the tracks)
│   │   │   ├── switch_component.dart     🔲 SwitchComponent (visual + interaction zone of a Switch)
│   │   │   ├── hazard_component.dart     🔲 HazardComponent (dead end / river / construction visuals)
│   │   │   └── crash_effect_component.dart 🔲 CrashEffectComponent
│   │   ├── systems/                  game logic, no rendering
│   │   │   ├── track_graph.dart          ✅ TrackGraph, SwitchNode, TrackSegment, TrackEnd
│   │   │   ├── spawn_system.dart         🔲 SpawnSystem (reads LevelData.spawns)
│   │   │   ├── tram_movement_system.dart 🔲 moves trams along segments via TrackGraph
│   │   │   ├── crash_system.dart         🔲 tram-vs-tram and hazard crashes
│   │   │   └── score_system.dart         🔲 crash count, combos, win/lose
│   │   ├── levels/                   level data
│   │   │   ├── level_data.dart           ✅ LevelData (+ validation), SpawnData
│   │   │   ├── level_repository.dart     ✅ LevelRepository (levels.json manifest)
│   │   │   └── level_loader_system.dart  🔲 builds components from LevelData into the world
│   │   └── graphics/
│   │       └── pixel_art.dart            ✅ pixelArtPaint() (nearest-neighbour)
│   ├── input/                        🔲 GameAction enum, KeyboardInputMapper, GamepadInputMapper
│   ├── audio/                        🔲 AudioService (flame_audio wrapper)
│   ├── ui/
│   │   ├── screens/                  🔲 MainMenuScreen, LevelSelectScreen, ResultScreen
│   │   └── widgets/                  🔲 HudOverlay, PauseOverlay
│   └── core/                         🔲 shared utils, constants, save data (…Service)
├── assets/                           game-ready files (registered in pubspec.yaml)
│   ├── data/levels/                  ✅ levels.json (manifest) + <city>_<nn>_<slug>.json
│   ├── images/{trams,tiles,props,ui,fx}/   🔲 PNG sprite sheets (+ .json from Aseprite)
│   ├── audio/{sfx,music}/            🔲 .ogg
│   └── fonts/                        🔲
├── art/                              sources, never loaded by the game
│   ├── blender/{scenes,scripts}/     .blend files, Blender helper scripts
│   ├── aseprite/{source,export}/     .aseprite files; export/ holds raw renders (git-ignored *_raw/)
│   └── reference/                    reference images
├── tools/                            build/art scripts
│   ├── render_sprites.py             ✅ Blender → rotation frames
│   ├── export_aseprite.ps1           ✅ frames → sheet + JSON in assets/images/
│   └── build_web.ps1                 ✅ web build + itch.io zip (build/itch/web.zip)
├── test/                             mirrors lib/ one-to-one
│   └── game/{components,systems,levels}/   ✅ *_test.dart
├── docs/
│   ├── PROJECT_STRUCTURE.md          ✅ this file
│   ├── NAMING_CONVENTIONS.md         ✅
│   ├── GAME_DESIGN.md                ✅ rules, hazards, open questions
│   ├── ASSET_PIPELINE.md             ✅ Blender → Aseprite → Flame
│   └── DISTRIBUTION.md               ✅ itch.io / Steam / Steam Deck
├── distribution/{itch,steam}/        🔲 butler / SteamPipe files, store art
├── .github/workflows/ci.yml          ✅ analyze, test, web/windows/linux builds
└── windows/ linux/ web/              ✅ generated Flutter platform runners (don't hand-edit unless needed)
```

## Where do I implement…?

| Task | Put it in | Also touch |
|------|-----------|------------|
| New hazard type | add value to `TrackEnd` in `systems/track_graph.dart`; visuals in `components/hazard_component.dart` | `crash_system.dart`, `GAME_DESIGN.md`, level JSON docs |
| Switch behaviour (flip rules) | `SwitchNode` in `systems/track_graph.dart` | `track_graph_test.dart` |
| How a tram moves / follows rails | `systems/tram_movement_system.dart` | `components/tram_component.dart` |
| Tram look (canvas or sprite) | `components/tram_component.dart` (`sprite` or Canvas fallback) | `assets/images/trams/` |
| Tram-vs-tram collision | `systems/crash_system.dart` (+ Flame hitboxes on `TramComponent`) | |
| New level | new `assets/data/levels/<city>_<nn>_<slug>.json` + entry in `levels.json` | `level_data_test.dart` passes = valid |
| New level JSON field | `levels/level_data.dart` (parse + `validate`) | level JSONs, `NAMING_CONVENTIONS.md` §5 |
| Spawning schedule | `systems/spawn_system.dart` | `SpawnData` in `level_data.dart` |
| Keyboard / gamepad / Steam Deck input | `lib/input/` (map to `GameAction`) | `components/player_component.dart` |
| Score, win/lose | `systems/score_system.dart` | `ui/widgets/hud_overlay.dart`, `ui/screens/result_screen.dart` |
| Menus, HUD | `lib/ui/screens/`, `lib/ui/widgets/` | `main.dart` / `TramGame.overlays` |
| Sounds | `lib/audio/audio_service.dart` | `assets/audio/` |
| New sprite/tile | Blender (`art/blender/`) → `tools/render_sprites.py` → Aseprite → `tools/export_aseprite.ps1` | `ASSET_PIPELINE.md` |
| New asset folder | create folder, add it to `pubspec.yaml` assets | this file |
| Packaging / release | `tools/`, `distribution/`, `.github/workflows/ci.yml` | `DISTRIBUTION.md` |

## Dependency direction

`main.dart` → `ui` → `game` → `core`. `game/systems` and `game/levels` must not import `package:flame` rendering
types (keep them pure Dart + unit-testable); only `game/components`, `game/graphics` and `tram_game.dart` render.
