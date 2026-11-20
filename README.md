# Super Hot Imperfect Form Trams

Top-down tram game made with Flutter + Flame. Trams with throttle, overheating brakes, and
SHIFT-controlled track switches race through a European-style city; flip switches and gates to
send rivals into crashes or hazards.

> **Case study:** this repository is a playable work-in-progress case study built with
> **Flutter + Flame + Dart** — Canvas-first rendering, synthesized WAV SFX, 3 levels + track editor,
> pure-Dart game systems with unit tests, and CI (sprite art and music not added yet).

```sh
flutter pub get
flutter run -d windows   # or: -d chrome
flutter test
```

## Tech stack

| Area | Choice |
|------|--------|
| Language / SDK | Dart ^3.13.7 (tested on 3.14.0), Flutter 3.50 |
| Game engine | [Flame](https://flame-engine.org) (`FlameGame`, components, keyboard events) |
| Audio | `flame_audio` |
| Native interop | `dart:ffi` via `ffi` (Windows sticky-keys guard, with a stub for other platforms) |
| Testing | `flutter_test`, `flame_test` |
| Lints | `flutter_lints` |
| CI | GitHub Actions (`.github/workflows/ci.yml`) |
| Targets | Windows, Linux, Web |

## Project structure

```text
lib/
  main.dart                  App entry point (MaterialApp, campaign & editor navigation)
  audio/                     Mute control and cooldown-gated SFX playback (AudioService)
  core/                      Logging (GameLog), cross-platform JSON file dialogs (JsonFileService),
                             and StickyKeysGuard (conditional import: ffi / stub)
  input/                     Keyboard controls
  ui/                        Menus, race/result/pause overlays, and track editor UI
  game/
    tram_game.dart           Root FlameGame: loads a level and wires world & systems
    tram_world_builder.dart  Assembles world layers and tram/hazard/crossover components
    components/              Flame components (track, trams, signals, HUD, atmosphere, ...)
    editor/                  Pure-Dart track editor model, validator, and level builder
    graphics/                Render layers (depth -> ground -> track -> entities -> canopy -> HUD)
                             and Canvas / pixel-art helpers
    levels/                  Level data models + repository (JSON in assets/data/levels)
    systems/                 Pure-Dart logic: track graph, paths, physics, AI, gates, zones, switching
assets/                      Level JSON + synthesized .wav SFX (image/music dirs are placeholders;
                             Canvas rendering is active by default)
test/                        Unit, widget, and component tests mirroring lib/
tools/                       Helper scripts (web build, sprite export/render)
```

## Design notes

- **Data-driven levels** – track layout, props and crossovers are described as data
  (`levels/`), not hard-coded in components.
- **Logic separated from rendering** – `systems/` (track graph, paths, turntable rules) has no
  Flame dependency, so it is covered by plain unit tests.
- **Explicit render layers** – `RenderLayer` defines the draw order from depth to HUD, so
  components never rely on ad-hoc priorities.
- **Platform code behind conditional imports** – the FFI-based sticky-keys guard has a stub
  implementation so the same code builds for web.

## License

Code: MIT ([LICENSE](LICENSE)). Art assets: all rights reserved.
