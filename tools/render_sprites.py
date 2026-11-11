"""Render a Blender object from a top-down orthographic camera into N rotation frames.

Usage (headless):
  blender -b art/blender/scenes/tram.blend -P tools/render_sprites.py -- \
      --object Tram --frames 32 --size 128 --out art/aseprite/export/tram_raw

Each frame rotates the object around Z, so the game can pick the closest
frame for the current heading. Frames are then cleaned up / palette-reduced
in Aseprite (see tools/export_aseprite.ps1 and docs/ASSET_PIPELINE.md).
"""
import argparse
import math
import sys

import bpy


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--object", required=True)
    p.add_argument("--frames", type=int, default=32)
    p.add_argument("--size", type=int, default=128)
    p.add_argument("--ortho-scale", type=float, default=8.0)
    p.add_argument("--out", required=True)
    return p.parse_args(argv)


def main():
    args = parse_args()
    scene = bpy.context.scene
    obj = bpy.data.objects[args.object]

    cam_data = bpy.data.cameras.new("TopDownCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = args.ortho_scale
    cam = bpy.data.objects.new("TopDownCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (obj.location.x, obj.location.y, 20)
    cam.rotation_euler = (0, 0, 0)  # looks straight down -Z
    scene.camera = cam

    scene.render.resolution_x = scene.render.resolution_y = args.size
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"

    for i in range(args.frames):
        obj.rotation_euler.z = math.radians(360.0 * i / args.frames)
        scene.render.filepath = f"{args.out}/frame_{i:03d}.png"
        bpy.ops.render.render(write_still=True)


main()
