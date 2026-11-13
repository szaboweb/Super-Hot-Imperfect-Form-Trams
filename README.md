# Super Hot Imperfect Form Trams

Top-down tram game made with Flutter + Flame. Brakeless trams race through a European-style city;
flip the switches behind them to send the next ones into crashes.

> **Case study:** this repository is a small but complete example of a game built with
> **Flutter + Flame + Dart** — data-driven levels, a layered render pipeline, pure-Dart game
> systems with unit tests, and CI.

```sh
flutter pub get
flutter run -d windows   # or: -d chrome
flutter test
```

## Tech stack

| Area | Choice |
|------|--------|
| Language / SDK | Dart 3.13, Flutter 3.47 |
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
  main.dart                  App entry point
  core/                      Logging, platform guard (conditional import: ffi / stub)
  input/                     Keyboard controls
  game/
    tram_game.dart           Root FlameGame: loads a level and builds the world layer by layer
    components/              Flame components (track, trams, signals, HUD, atmosphere, ...)
    graphics/                Render layers (depth -> ground -> track -> entities -> canopy -> HUD)
                             and pixel-art helpers
    levels/                  Level data models + repository (JSON in assets/data/levels)
    systems/                 Pure-Dart logic: track graph, paths, turntable switching/turning
assets/                      Images, audio, level JSON
test/                        Unit and component tests mirroring lib/
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
