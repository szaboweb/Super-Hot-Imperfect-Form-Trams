# Naming conventions

Goal: an agent (or human) can guess the file, class and asset name from the *role* alone, and
`grep`/glob for a role finds every instance. Where things live: [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md).

## 1. Domain glossary (use exactly these words)

| Term | Meaning | Do **not** use |
|------|---------|----------------|
| `Tram` | a brakeless vehicle on the rails | train, vehicle, car |
| `Switch` | rail switch the player flips | points, turnout, junction (a junction is just a place with a switch) |
| `Segment` | one directed piece of track between nodes | edge, rail, piece |
| `TrackGraph` | all segments + switches of a level | map, network |
| `TrackEnd` / `Hazard` | what ends a segment: `deadEnd`, `river`, `construction` | obstacle, trap |
| `Crash` | a tram destroyed (collision or hazard) | hit, wreck |
| `Spawn` | scheduled appearance of a tram | emit, create |
| `Level` | one playable map (JSON + tiles) | stage, map, track (as a level) |
| `Player` | the character who flips switches | user, runner |

## 2. Dart: role suffix = folder

File name is the class name in `snake_case`; **one primary class per file**. The suffix tells the role and
therefore the folder:

| Suffix | Role | Folder | Example (file → class) |
|--------|------|--------|------------------------|
| `...Component` | Flame component (renders and/or updates itself) | `lib/game/components/` | `tram_component.dart` → `TramComponent` |
| `...System` | game logic with `update(dt)`, no rendering | `lib/game/systems/` | `spawn_system.dart` → `SpawnSystem` |
| `...Data` | immutable model parsed from JSON | `lib/game/levels/` | `level_data.dart` → `LevelData` |
| `...Repository` | loads data from assets | `lib/game/levels/` | `level_repository.dart` → `LevelRepository` |
| `...Screen` | full-screen Flutter widget | `lib/ui/screens/` | `main_menu_screen.dart` → `MainMenuScreen` |
| `...Overlay` | Flame overlay widget (HUD, pause) | `lib/ui/widgets/` | `hud_overlay.dart` → `HudOverlay` |
| `...Widget` | reusable Flutter widget | `lib/ui/widgets/` | `score_label_widget.dart` → `ScoreLabelWidget` |
| `...InputMapper` | device input → `GameAction` | `lib/input/` | `keyboard_input_mapper.dart` → `KeyboardInputMapper` |
| `...Service` | cross-cutting service (audio, save data) | `lib/audio/`, `lib/core/` | `audio_service.dart` → `AudioService` |
| *(none)* | pure graph/logic model, enums | `lib/game/systems/` | `track_graph.dart` → `TrackGraph`, `TrackEnd` |

Top-level game class is `TramGame` (`lib/game/tram_game.dart`); entry point is `lib/main.dart` only.

## 3. Members

- Types `UpperCamelCase`, members/variables `lowerCamelCase`, constants `lowerCamelCase` (Dart lint), files/dirs `snake_case`.
- Flame lifecycle overrides keep Flame names (`onLoad`, `update`, `render`, `onCollisionStart`).
- Verb prefixes: `spawnX`, `toggleX`, `applyX`, `buildX`, `loadX`, `advanceX`, `validateX`, `handleX` (input), `onX` (callback/event).
- Booleans: `isX` / `hasX` / `canX`. Counts: `xCount`. Time in seconds, distance in px: say it in the doc comment, and in
  new code name it (`speedPxPerSec`, `delaySec`).
- Every public class gets a one-line `///` saying **what it is and where it fits** (agents read this first).

## 4. Tests

Mirror the `lib/` path, add `_test`: `lib/game/systems/track_graph.dart` → `test/game/systems/track_graph_test.dart`.

## 5. Level JSON

- File = id = `<city>_<nn>_<slug>.json`, e.g. `budapest_01_danube_quay.json` (the current `example_junction` is a placeholder).
- Registered in `assets/data/levels/levels.json` (order = play order).
- Keys `lowerCamelCase`; ids `snake_case`; switch ids prefixed `sw_` (`sw_quay`), segment ids describe the place (`quay_main`, `river_spur`).
- Enum values match Dart names exactly (`deadEnd`, `river`, `construction`).

## 6. Art and audio assets

| Kind | Pattern | Example |
|------|---------|---------|
| Sprite sheet | `<subject>[_<variant>][_<N>f].png` + same-name `.json` | `assets/images/trams/tram_red_32f.png` |
| Tile | `tile_<city>_<name>.png` | `assets/images/tiles/tile_budapest_cobble.png` |
| Prop | `prop_<name>.png` | `assets/images/props/prop_barrier.png` |
| UI | `ui_<name>.png` | `assets/images/ui/ui_switch_icon.png` |
| FX | `fx_<name>_<N>f.png` | `assets/images/fx/fx_explosion_8f.png` |
| SFX | `sfx_<event>_<nn>.ogg` | `assets/audio/sfx/sfx_crash_01.ogg` |
| Music | `music_<name>.ogg` | `assets/audio/music/music_menu.ogg` |
| Blender scene | `art/blender/scenes/<subject>.blend` (object named like the subject) | `tram.blend` → object `Tram` |
| Aseprite source | `art/aseprite/source/<subject>.aseprite` | `tram.aseprite` |

`<N>f` = number of frames (rotation frames for vehicles, animation frames for fx). All lowercase, no spaces.

## 7. Git

Conventional commits, scope = top-level area: `feat(game): ...`, `fix(levels): ...`, `art(trams): ...`,
`docs: ...`, `chore(ci): ...`.
