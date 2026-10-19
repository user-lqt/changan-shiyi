"""Editable style-A night-watch monk, +X forward; Blender exports Y-up GLB.

blender --background --factory-startup --python tools/blender/build_night_monk.py
"""
from pathlib import Path
import math
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_night_kit import mat, srgb, sphere, cyl, box


def ellipsoid(name, size, at, material):
    obj = sphere(name, 1, at, material, seg=16)
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def mesh(name, verts, faces, material):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.materials.append(material)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return obj


def tube(name, points, radii, material, count=12):
    verts, faces = [], []
    for i, (point, radius) in enumerate(zip(points, radii)):
        tangent = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])
        tangent.normalize()
        u = tangent.cross(Vector((1, 0, 0))).normalized()
        if u.length < .01:
            u = tangent.cross(Vector((0, 1, 0))).normalized()
        v = tangent.cross(u).normalized()
        for j in range(count):
            a = math.tau * j / count
            verts.append(Vector(point) + radius * (u * math.cos(a) + v * math.sin(a)))
    for i in range(len(points) - 1):
        for j in range(count):
            a, b = i * count + j, i * count + (j + 1) % count
            faces.append((a, b, b + count, a + count))
    faces += [tuple(reversed(range(count))), tuple((len(points) - 1) * count + j for j in range(count))]
    return mesh(name, verts, faces, material)


def group(name, objects, parent=None, pivot=(0, 0, 0)):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    # Runtime idle rotations start from neutral local axes, including the handle torus.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    if parent:
        world = obj.matrix_world.copy()
        obj.parent = parent
        obj.matrix_world = world
    return obj


def build():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    robe = mat('monk_taupe_robe', srgb('938776'), .96)
    robe_edge = mat('monk_robe_folds', srgb('786d5d'), .97)
    mantle = mat('monk_umber_mantle', srgb('695446'), .97)
    mantle_edge = mat('monk_mantle_seams', srgb('8b7158'), .94)
    collar = mat('monk_ivory_collar', srgb('d4c9b1'), .95)
    skin = mat('monk_skin', srgb('cba183'), .86)
    shadow = mat('monk_skin_shadow', srgb('9b7259'), .9)
    ink = mat('monk_eyes', srgb('342e28'), .85)
    wood = mat('monk_lantern_wood', srgb('533b28'), .88)
    paper = mat('monk_lantern_paper', srgb('e8c38a'), .9, emit=srgb('ffce85'), strength=.45)
    shoes = mat('monk_cloth_shoes', srgb('38352f'), .96)
    rope = mat('monk_hemp_tie', srgb('b2a082'), .96)
    root = bpy.data.objects.new('MonkRoot', None)
    bpy.context.collection.objects.link(root)
    root['character'] = '大慈恩寺值夜僧'
    root['art_style'] = 'A / restrained low-poly'

    body_parts = []
    rings = [(.105, .16, .225), (.19, .162, .23), (.40, .145, .21),
             (.63, .12, .18), (.83, .139, .19), (.96, .105, .185), (1.005, .072, .105)]
    verts, faces = [], []
    count = 32
    for z, rx, ry in rings:
        for i in range(count):
            a = math.tau * i / count
            fold = 1 + .037 * math.cos(a * 10) * max(0, 1 - z)
            verts.append((rx * math.cos(a) * fold, ry * math.sin(a) * fold, z))
    for i in range(len(rings) - 1):
        for j in range(count):
            faces.append((i * count + j, i * count + (j + 1) % count,
                          (i + 1) * count + (j + 1) % count, (i + 1) * count + j))
    faces.append(tuple(reversed(range(count))))
    body_parts.append(mesh('Continuous_Long_Robe', verts, faces, robe))
    for side in [-1, 1]:
        body_parts.append(ellipsoid('Cloth_Shoe', (.125, .067, .045), (.03, side * .105, .048), shoes))
    # A continuous draped shoulder mantle, with a diagonal upper edge.
    verts, faces = [], []
    rows, cols = 9, 16
    for row in range(rows):
        t = row / (rows - 1)
        for col in range(cols):
            s = col / (cols - 1)
            y = -.19 + .39 * s
            top = .76 + .22 * s
            z = top * (1 - t) + (.37 + .04 * math.cos(s * math.pi)) * t
            x = .045 + .13 * math.sqrt(max(0, 1 - (y / .245) ** 2))
            x += .009 * math.cos(s * math.tau * 4) * t
            verts.append((x, y, z))
    for row in range(rows - 1):
        for col in range(cols - 1):
            a = row * cols + col
            faces.append((a, a + 1, a + cols + 1, a + cols))
    shawl = mesh('Diagonal_Shoulder_Mantle', verts, faces, mantle)
    solid = shawl.modifiers.new('Cloth edge thickness', 'SOLIDIFY')
    solid.thickness = .007
    body_parts.append(shawl)
    body_parts.append(tube('Mantle_Border', [(.151, -.18, .765), (.183, -.08, .82),
                       (.182, .05, .895), (.142, .185, .974)], [.008] * 4, mantle_edge, 8))
    body_parts.append(tube('Crossed_Collar_Left', [(.066, .073, 1.005), (.124, .015, .933),
                       (.153, -.045, .88)], [.016] * 3, collar, 8))
    body_parts.append(tube('Crossed_Collar_Right', [(.071, -.070, 1.002), (.121, -.016, .948)], [.013] * 2, collar, 8))
    # Hem lines and a modest hemp knot remain readable at the overhead camera scale.
    body_parts.append(tube('Hemp_Tie', [(.139, -.145, .635), (.159, -.03, .63), (.135, .13, .64)], [.008] * 3, rope, 8))
    body_parts.append(tube('Hemp_Knot_End', [(.151, -.10, .63), (.17, -.12, .53), (.166, -.09, .48)], [.008, .007, .006], rope, 8))
    for y in [-.135, -.045, .055, .145]:
        x = .166 * math.sqrt(max(.2, 1 - (y / .25) ** 2))
        body_parts.append(tube('Lower_Fabric_Fold', [(x * .89, y * .85, .45), (x, y, .27), (x * .99, y, .12)], [.004, .006, .004], robe_edge, 6))
    body = group('Body', body_parts, root, (0, 0, .64))

    head_parts = [cyl('Neck', .052, .09, (0, 0, 1.015), skin, 12),
                  ellipsoid('Bald_Head', (.102, .10, .125), (.005, 0, 1.115), skin),
                  ellipsoid('Nose', (.029, .025, .028), (.102, 0, 1.108), skin)]
    for side in [-1, 1]:
        head_parts += [ellipsoid('Ear', (.027, .021, .037), (0, side * .098, 1.105), skin),
                       ellipsoid('Kind_Eye', (.007, .016, .005), (.099, side * .041, 1.139), ink),
                       tube('Eyebrow', [(.098, side * .023, 1.164), (.095, side * .045, 1.17),
                           (.086, side * .064, 1.16)], [.004, .005, .003], ink, 6)]
    head_parts.append(tube('Mouth', [(.099, -.025, 1.071), (.108, 0, 1.067), (.099, .025, 1.071)], [.0025] * 3, shadow, 6))
    group('Head', head_parts, body, (0, 0, 1.02))

    for side in [-1, 1]:
        points = [(0, side * .166, .93), (.015, side * .248, .848),
                  (.035, side * .268, .75), (.12, side * (.15 if side > 0 else .30), .69)]
        parts = [tube('Continuous_Sleeve', points, [.078, .090, .088, .069], robe),
                 ellipsoid('Cuff', (.063, .069, .049), points[-1], robe_edge),
                 ellipsoid('Hand', (.042, .032, .047), (.16, points[-1][1], .674), skin),
                 ellipsoid('Thumb', (.022, .017, .029), (.185, points[-1][1] + .018, .684), skin)]
        if side > 0:
            for i in range(11):
                a = math.tau * i / 11
                parts.append(ellipsoid('Wooden_Prayer_Bead', (.012, .012, .012),
                    (.12 + .048 * math.cos(a), .15 + .05 * math.sin(a), .704), wood))
        group('Arm_Left' if side > 0 else 'Arm_Right', parts, body, points[0])

    # Hand lantern: a real octagonal cage with paper, ribs, handle and a small tassel.
    at = Vector((.16, -.30, .665))
    parts = []
    bpy.ops.mesh.primitive_torus_add(major_radius=.046, minor_radius=.007,
        major_segments=16, minor_segments=6, location=at + Vector((0, 0, -.045)), rotation=(math.pi / 2, 0, 0))
    obj = bpy.context.active_object
    obj.name = 'Lantern_Handle'
    obj.data.materials.append(wood)
    parts.append(obj)
    parts.append(cyl('Lantern_Paper', .084, .19, at + Vector((0, 0, -.19)), paper, 8))
    for z in [-.087, -.29]:
        parts.append(cyl('Lantern_Cap', .101, .026, at + Vector((0, 0, z)), wood, 8))
    for i in range(8):
        a = math.tau * i / 8
        parts.append(cyl('Lantern_Rib', .005, .196,
            at + Vector((.086 * math.cos(a), .086 * math.sin(a), -.19)), wood, 6))
    parts.append(cyl('Lantern_Tassel', .009, .065, at + Vector((0, 0, -.332)), rope, 6))
    group('HandLantern', parts, body, at)

    bpy.context.scene.cursor.location = (0, 0, 0)
    art = ROOT / 'art/characters/ch4-style-a'
    art.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(art / 'A-寺僧.blend'))
    bpy.ops.object.select_all(action='SELECT')
    path = ROOT / 'assets/models/night_monk.glb'
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                             export_apply=True, export_yup=True, export_cameras=False, export_lights=False)
    triangles = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
    print('EXPORTED_MONK', path, 'polygons', triangles)


if __name__ == '__main__':
    build()
