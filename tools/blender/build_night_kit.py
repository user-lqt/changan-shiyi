"""Builds the low-poly kit for chapter 4 (夜行) and exports one GLB per prop.

Run:  blender --background --factory-startup --python tools/blender/build_night_kit.py
Output: assets/models/night_*.glb   (1 Blender unit = 1 grid tile = 1 Godot metre)
"""
import math
import os
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models")
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes,):
        for item in list(block):
            block.remove(item)


def mat(name, rgb, rough=0.85, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    return m


def srgb(hexstr):
    v = [int(hexstr[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in v)


def box(name, size, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    return o


def cyl(name, r, h, loc, material, verts=12, r2=None, rot=(0, 0, 0)):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


def sphere(name, r, loc, material, seg=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2 + 1, radius=r, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


def roof(name, w, d, h, loc, material, overhang=0.12):
    """Hip roof with slightly upturned eaves (a squashed pyramid on a thin slab)."""
    parts = [box(name + "_eave", (w + overhang * 2, d + overhang * 2, 0.05), loc, material)]
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.0, radius2=0.25, depth=h,
                                    location=(loc[0], loc[1], loc[2] + h * 0.5), rotation=(0, 0, math.pi / 4))
    o = bpy.context.active_object
    o.scale = ((w + overhang) / 1.414, (d + overhang) / 1.414, 1)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    parts.append(o)
    return parts


def export(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    # Blender is Z-up; the glTF exporter converts to Godot's Y-up.
    path = os.path.join(OUT, "night_%s.glb" % name)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    print("EXPORTED", path, len(joined.data.polygons), "faces")


def build():
    earth = mat("rammed_earth", srgb("8a6f52"), 0.95)
    earth_dark = mat("earth_dark", srgb("5e4936"), 0.95)
    tile = mat("roof_tile", srgb("2c3436"), 0.7)
    wood = mat("wood", srgb("6b3a24"), 0.8)
    red = mat("vermilion", srgb("9a2f22"), 0.7)
    plaster = mat("plaster", srgb("cbbd9f"), 0.9)
    paper = mat("lantern_paper", srgb("e8a24a"), 0.6, emit=srgb("ffb050"), strength=4.0)
    bronze = mat("bronze", srgb("7a6034"), 0.45, 0.8)
    armor = mat("armor", srgb("4c4f4a"), 0.5, 0.6)
    cloth_red = mat("cloth_red", srgb("7e2a20"), 0.9)
    skin = mat("skin", srgb("d8b08c"), 0.8)
    hair = mat("hair", srgb("1a1512"), 0.7)
    su_coat = mat("su_coat", srgb("e9ecef"), 0.8)
    su_pants = mat("su_pants", srgb("2d3b55"), 0.8)
    ashi_cloth = mat("ashi_cloth", srgb("8c7a52"), 0.95)
    straw = mat("straw", srgb("b49a5a"), 0.95)
    cloth_blue = mat("cloth_blue", srgb("2f4a6a"), 0.9)

    # Ward wall: one tile of rammed earth with a tiled coping. Height 1.1.
    reset()
    parts = [box("w", (1.0, 1.0, 1.0), (0, 0, 0.5), earth)]
    parts.append(box("band", (1.02, 1.02, 0.06), (0, 0, 0.18), earth_dark))
    parts += roof("cap", 1.0, 1.0, 0.12, (0, 0, 1.03), tile, overhang=0.04)
    export("wall", parts)

    # Ward house behind walls: plaster walls, red columns, hip roof. Footprint 2x2.
    reset()
    parts = [box("body", (1.6, 1.3, 0.9), (0, 0, 0.45), plaster)]
    for x in (-0.78, 0.78):
        for y in (-0.63, 0.63):
            parts.append(cyl("col", 0.05, 0.9, (x, y, 0.45), red, 8))
    parts += roof("roof", 1.6, 1.3, 0.55, (0, 0, 0.92), tile, overhang=0.2)
    export("house", parts)

    # Ward gate frame (doors are separate so Godot can swing them). Spans one tile in X.
    reset()
    parts = []
    for x in (-0.52, 0.52):
        parts.append(box("post", (0.16, 0.3, 1.5), (x, 0, 0.75), red))
        parts.append(box("base", (0.24, 0.38, 0.12), (x, 0, 0.06), earth_dark))
    parts.append(box("lintel", (1.3, 0.34, 0.14), (0, 0, 1.45), red))
    parts += roof("roof", 1.4, 0.6, 0.35, (0, 0, 1.55), tile, overhang=0.18)
    parts.append(box("plaque", (0.4, 0.04, 0.18), (0, -0.2, 1.25), bronze))
    export("gate", parts)

    reset()
    door = [box("door", (0.5, 0.06, 1.25), (0.25, 0, 0.63), wood)]
    for z in (0.3, 0.63, 0.96):
        for x in (0.12, 0.25, 0.38):
            door.append(sphere("nail", 0.025, (x, -0.04, z), bronze, 6))
    export("door", door)

    # Lantern post.
    reset()
    parts = [cyl("pole", 0.04, 1.5, (0, 0, 0.75), wood, 8),
             box("arm", (0.45, 0.04, 0.04), (0.2, 0, 1.45), wood),
             cyl("lantern", 0.13, 0.28, (0.38, 0, 1.25), paper, 10),
             cyl("cap", 0.08, 0.04, (0.38, 0, 1.41), wood, 8),
             cyl("foot", 0.12, 0.08, (0, 0, 0.04), earth_dark, 8)]
    export("lantern", parts)

    # Ox cart / merchant cart with a cloth cover — a hiding spot.
    reset()
    parts = [box("bed", (0.85, 0.55, 0.08), (0, 0, 0.36), wood)]
    for y in (-0.32, 0.32):
        parts.append(cyl("wheel", 0.3, 0.06, (0, y, 0.3), wood, 14, rot=(math.pi / 2, 0, 0)))
    parts.append(box("load", (0.75, 0.5, 0.35), (0, 0, 0.58), straw))
    parts.append(box("cover", (0.8, 0.58, 0.05), (0, 0, 0.78), cloth_blue, rot=(0, 0.05, 0)))
    parts.append(box("shaft", (0.7, 0.04, 0.04), (0.75, 0.14, 0.38), wood))
    parts.append(box("shaft2", (0.7, 0.04, 0.04), (0.75, -0.14, 0.38), wood))
    export("cart", parts)

    # 金吾卫 guard: lamellar armour, red cloak, helmet, halberd. Faces +X.
    reset()
    parts = [cyl("legs", 0.11, 0.42, (0, 0, 0.21), cloth_red, 8),
             cyl("torso", 0.15, 0.36, (0, 0, 0.6), armor, 8, r2=0.12),
             box("cloak", (0.06, 0.32, 0.5), (-0.13, 0, 0.55), cloth_red),
             sphere("head", 0.1, (0, 0, 0.88), skin, 10),
             cyl("helm", 0.11, 0.12, (0, 0, 0.96), armor, 10, r2=0.04),
             cyl("plume", 0.015, 0.12, (0, 0, 1.06), cloth_red, 6),
             cyl("halberd", 0.018, 1.3, (0.05, 0.2, 0.65), wood, 6),
             cyl("blade", 0.05, 0.16, (0.05, 0.2, 1.36), bronze, 4, r2=0.0)]
    export("guard", parts)

    # 苏晴: modern lab coat, dark trousers, ponytail.
    reset()
    parts = [cyl("legs", 0.09, 0.4, (0, 0, 0.2), su_pants, 8),
             cyl("coat", 0.14, 0.42, (0, 0, 0.58), su_coat, 8, r2=0.1),
             sphere("head", 0.1, (0, 0, 0.88), skin, 10),
             sphere("hair", 0.105, (-0.015, 0, 0.9), hair, 10),
             cyl("tail", 0.03, 0.18, (-0.11, 0, 0.82), hair, 6)]
    export("su", parts)

    # 阿拾: barefoot street boy in a patched hemp tunic, topknot.
    reset()
    parts = [cyl("legs", 0.08, 0.3, (0, 0, 0.15), skin, 8),
             cyl("tunic", 0.12, 0.34, (0, 0, 0.46), ashi_cloth, 8, r2=0.09),
             box("sash", (0.25, 0.25, 0.04), (0, 0, 0.4), cloth_red),
             sphere("head", 0.09, (0, 0, 0.72), skin, 10),
             sphere("bun", 0.04, (0, 0, 0.82), hair, 8)]
    export("ashi", parts)


if __name__ == "__main__":
    build()
