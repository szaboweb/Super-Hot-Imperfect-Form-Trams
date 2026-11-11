# Game design

## Concept
Top-down, European-city-inspired maps. Runaway trams **without brakes** race along the rails.
The player runs along the tracks, passes the **switches**, and flips them *right behind* a
speeding tram so the **next** tram is sent onto a different route.

Goal: make trams **collide** with each other or end up in **dead ends, the river, or a construction site**.

## Core loop
1. Trams spawn on schedule (see `spawns` in level JSON) and follow the track graph at fixed speed.
2. The player moves on foot (keyboard / gamepad) and interacts with a switch when close to it.
3. Timing matters: a switch flipped under a tram is ignored/derails (design TBD); flip it after the tram has passed.
4. Crashes score points; combos for multi-tram pile-ups. Too many trams reaching their station = fail.

## Hazards (`TrackEnd`)
| Type | Result |
|------|--------|
| `deadEnd` | buffer-stop crash |
| `river` | tram plunges off a broken bridge / quay |
| `construction` | tram hits a construction site |
| tram vs. tram | collision on shared segment / crossing |

## Maps
Scope for now: **one level** (`assets/data/levels/example_junction.json`), a stylised European-city district
with a river embankment, a ring boulevard junction and a building site. More cities (Budapest, Prague, Vienna,
Amsterdam, Lisbon) are possible later: tilesets in `assets/images/tiles/<city>/`, levels in `assets/data/levels/`.

## Code map
- `lib/game/systems/track_graph.dart` – segments, switches, hazards (pure Dart, unit-tested)
- `lib/game/levels/` – `LevelData` (JSON parsing + validation) and `LevelRepository` (loads `levels.json` manifest)
- `lib/game/components/` – tram, player, switch, hazards (Flame components)
- `assets/data/levels/*.json` – level definitions (see `example_junction.json`)

## Open questions
- Free-roaming player vs. cursor/click-to-switch (Steam Deck: stick + button)?
- Switch flipped under a moving tram: ignore, derail, or split?
- Win/lose conditions per level (crash quota vs. time).
