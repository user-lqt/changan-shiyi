"""Builds the 3D props for chapter 5 (曲江诗牌) and exports one GLB per prop.

Run:  blender --background --factory-startup --python tools/blender/build_poem_kit.py
Output: assets/models/poem_*.glb   (1 Blender unit = 1 Godot metre)
Scene props stay low-poly; the wine cup and the bronze tally (酒筹筒) are the "artifact"
pieces and get smoother profiles.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
from build_night_kit import reset, mat, srgb, box, cyl  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models")


def export(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    path = os.path.join(OUT, "poem_%s.glb" % name)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    print("EXPORTED", path, len(joined.data.polygons), "faces")


def lathe(name, profile, material, segments=48, smooth=True):
    """Revolves a list of (radius, height) points around Z — for cups and vessels."""
    mesh = bpy.data.meshes.new(name)
    verts, faces = [], []
    n = len(profile)
    for s in range(segments):
        a = 2 * math.pi * s / segments
        for r, z in profile:
            verts.append((r * math.cos(a), r * math.sin(a), z))
    for s in range(segments):
        s2 = (s + 1) % segments
        for i in range(n - 1):
            faces.append((s * n + i, s2 * n + i, s2 * n + i + 1, s * n + i + 1))
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    return o


def build():
    lacquer = mat("lacquer", srgb("5a1d17"), 0.35)
    lacquer_black = mat("lacquer_black", srgb("1a1210"), 0.3)
    gold = mat("gold_inlay", srgb("c9a24f"), 0.3, 0.9)
    bronze = mat("bronze_patina", srgb("6f6a45"), 0.45, 0.75)
    celadon = mat("celadon", srgb("9cc2a6"), 0.18)
    wine = mat("wine", srgb("6b1f22"), 0.08)
    silk = mat("silk_red", srgb("8c2a22"), 0.85)
    bamboo = mat("bamboo", srgb("c9b07a"), 0.7)
    ink = mat("ink", srgb("15110f"), 0.6)

    # Low lacquered banquet table (案): top 3.2 x 1.6, legs curve slightly outward.
    reset()
    parts = [box("top", (3.2, 1.6, 0.08), (0, 0, 0.42), lacquer)]
    parts.append(box("rim", (3.26, 1.66, 0.03), (0, 0, 0.385), lacquer_black))
    parts.append(box("band_f", (3.0, 0.02, 0.02), (0, -0.81, 0.43), gold))
    parts.append(box("band_b", (3.0, 0.02, 0.02), (0, 0.81, 0.43), gold))
    for x in (-1.45, 1.45):
        for y in (-0.65, 0.65):
            parts.append(box("leg", (0.12, 0.12, 0.38), (x, y, 0.19), lacquer_black, rot=(0, 0.06 * (1 if x > 0 else -1), 0)))
    parts.append(box("stretcher_l", (0.08, 1.3, 0.05), (-1.45, 0, 0.06), lacquer_black))
    parts.append(box("stretcher_r", (0.08, 1.3, 0.05), (1.45, 0, 0.06), lacquer_black))
    export("table", parts)

    # Celadon wine cup with a foot ring — the artifact-level piece.
    reset()
    cup = [lathe("cup", [(0.0, 0.0), (0.05, 0.0), (0.055, 0.012), (0.045, 0.02), (0.06, 0.03),
                         (0.095, 0.06), (0.12, 0.1), (0.13, 0.13), (0.125, 0.135),
                         (0.11, 0.11), (0.08, 0.07), (0.04, 0.045), (0.0, 0.04)], celadon)]
    cup.append(lathe("wine", [(0.0, 0.1), (0.105, 0.1), (0.0, 0.1001)], wine, 32))
    export("cup", cup)

    # Bronze tally tube (酒筹筒) holding bamboo drinking-game slips.
    reset()
    tube = [lathe("tube", [(0.0, 0.0), (0.09, 0.0), (0.1, 0.02), (0.085, 0.05), (0.08, 0.3),
                           (0.095, 0.33), (0.1, 0.36), (0.09, 0.36), (0.075, 0.33), (0.0, 0.33)], bronze, 40)]
    for i, (dx, dy, tilt) in enumerate([(0.02, 0.0, 0.08), (-0.025, 0.015, -0.1), (0.0, -0.03, 0.12),
                                        (0.03, 0.03, -0.05), (-0.03, -0.02, 0.15)]):
        tube.append(box("slip", (0.018, 0.006, 0.42), (dx, dy, 0.38), bamboo, rot=(tilt, tilt * 0.6, i)))
    tube.append(cyl("band", 0.083, 0.02, (0, 0, 0.17), gold, 40))
    export("tube", tube)

    # Ink stone and a brush on its rest.
    reset()
    stone = [box("stone", (0.36, 0.24, 0.05), (0, 0, 0.025), lacquer_black)]
    stone.append(box("well", (0.12, 0.16, 0.012), (0.1, 0, 0.051), ink))
    stone.append(cyl("brush", 0.008, 0.32, (-0.05, 0.2, 0.04), bamboo, 8, rot=(0, math.pi / 2, 0.15)))
    stone.append(cyl("tip", 0.012, 0.05, (-0.23, 0.17, 0.04), ink, 8, r2=0.0, rot=(0, -math.pi / 2, 0.15)))
    export("inkstone", stone)

    # Red silk table runner under the play area.
    reset()
    export("runner", [box("runner", (2.4, 0.9, 0.006), (0, 0, 0.003), silk)])


build()
