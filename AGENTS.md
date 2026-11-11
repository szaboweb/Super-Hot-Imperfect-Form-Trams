# Agent instructions

Top-down tram game: **Flutter + Flame + Dart**; art from Blender → Aseprite. Read before coding:

1. [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md) – source of truth for *where* code and assets go. Update it when you add/move folders.
2. [docs/NAMING_CONVENTIONS.md](docs/NAMING_CONVENTIONS.md) – role suffixes (`...Component`, `...System`, `...Data`…), domain glossary, asset names.
3. [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) – what the game is.

Rules:
- Levels are data-driven JSON in `assets/data/levels/` (listed in `levels.json`); don't hard-code level content in Dart.
- Keep `game/systems` and `game/levels` free of rendering code so they stay unit-testable.
- Every graphic must work in Canvas mode (no art needed); sprites are optional and drawn with `pixelArtPaint()`.
- Mirror `lib/` in `test/`; add a test for new logic.

Before finishing: `dart format lib test`, `flutter analyze`, `flutter test` must be clean.

Local-only guardrail skills (git-ignored) live in `.github/skills/`; if present, follow them:
`verify-before-done`, `respect-project-structure`, `verify-apis-and-scope`, `data-driven-levels`, `protect-secrets`.
The repo is public: never commit secrets or business-confidential material (`private/`, `business/`, `docs/private/` are ignored).
