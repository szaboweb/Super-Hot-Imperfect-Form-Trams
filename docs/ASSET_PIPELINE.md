# Asset pipeline

```
Blender 3D  ──render──▶  PNG frames  ──Aseprite──▶  sprite sheet + JSON  ──▶  Flame
art/blender              art/aseprite/export       assets/images/**
```

1. **Model** in Blender: `art/blender/scenes/*.blend` (source `.blend` files are committed; consider Git LFS).
2. **Render** top-down, orthographic, N rotation frames (default 32):
   `blender -b art/blender/scenes/tram.blend -P tools/render_sprites.py -- --object Tram --frames 32 --size 128 --out art/aseprite/export/tram_raw`
3. **Clean up** in Aseprite: palette reduction, outline, dithering, hand-touched "imperfect" pixels.
   Keep `.aseprite` sources in `art/aseprite/source/`.
4. **Export** the sheet into the game: `./tools/export_aseprite.ps1 -Name tram -Source art/aseprite/export/tram_raw`
   → `assets/images/trams/tram.png` + `tram.json`.
5. **Load** in Flame with `SpriteSheet`/`SpriteAnimation`, picking the frame nearest to the tram's heading.

## Rendering modes
- **Canvas** (default fallback): components draw themselves with `Canvas` shapes, so the game runs without any art.
- **Pixel-art textures**: set a `Sprite` on a component; it is drawn with `pixelArtPaint()`
  (`lib/game/graphics/pixel_art.dart`, nearest-neighbour, no anti-aliasing).
  Use integer zoom factors to keep pixels crisp.

## Conventions
- Top-down, light from the top-left, consistent across all assets.
- Tile size: 64 px; tram sprite frames: 128×128 px.
- File names: `snake_case`, frame order = clockwise from "nose up".
