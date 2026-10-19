"""Model the chapter-one casket and bake its hinged opening into transparent frames.

Blender --background --factory-startup --python tools/blender/build_workshop_casket.py
Add -- --preview to render only the closed and opened poses for art review.
The game plays the baked frames; Blender is only an authoring dependency.
"""
from pathlib import Path
import json
import math
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tmp/ch1-casket-render'
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW = '--preview' in sys.argv
FRAME_COUNT = 49
WIDTH, HEIGHT = 640, 576


def rgb(value):
    channels = [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in channels)


def material(name, color, rough=.7, metal=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb(color), 1)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    return mat


def wood_material():
    mat = material('Old chestnut lacquer and fine grain', '51301e', .62)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    tex = nodes.new('ShaderNodeTexNoise')
    tex.inputs['Scale'].default_value = 3
    tex.inputs['Detail'].default_value = 3
    coord = nodes.new('ShaderNodeTexCoord')
    mapping = nodes.new('ShaderNodeVectorMath')
    mapping.operation = 'MULTIPLY'
    mapping.inputs[1].default_value = (2, 45, 5)
    links.new(coord.outputs['Generated'], mapping.inputs[0])
    links.new(mapping.outputs['Vector'], tex.inputs['Vector'])
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = .16
    ramp.color_ramp.elements[0].color = (*rgb('21130e'), 1)
    ramp.color_ramp.elements[1].position = .85
    ramp.color_ramp.elements[1].color = (*rgb('795034'), 1)
    links.new(tex.outputs['Fac'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], nodes['Principled BSDF'].inputs['Base Color'])
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .19
    bump.inputs['Distance'].default_value = .035
    links.new(tex.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], nodes['Principled BSDF'].inputs['Normal'])
    return mat


def box(name, loc, scale, mat, bevel=.025, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('Soft worn edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        obj.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
    if parent:
        obj.parent = parent
    return obj


def sphere(name, loc, radius, mat, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    if parent:
        obj.parent = parent
    return obj


def path(name, points, mat, thickness=.014, parent=None):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = thickness
    curve.bevel_resolution = 2
    spline = curve.splines.new('POLY')
    spline.points.add(len(points) - 1)
    for point, xyz in zip(spline.points, points):
        point.co = (*xyz, 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if parent:
        obj.parent = parent
    return obj


def outline(name, x, y, z, width, height, mat, parent=None):
    # Panel in an X/Z plane, facing the viewer.
    return path(name, [(x - width / 2, y, z - height / 2), (x + width / 2, y, z - height / 2),
                       (x + width / 2, y, z + height / 2), (x - width / 2, y, z + height / 2),
                       (x - width / 2, y, z - height / 2)], mat, .016, parent)


def smooth(a, b, value):
    v = min(1, max(0, (value - a) / (b - a)))
    return v * v * (3 - 2 * v)


bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
wood = wood_material()
bronze = material('Patinated warm bronze', '8b7244', .43, .72)
gold = material('Worn brass highlights', 'b49a62', .4, .62)
dark = material('Incised recesses', '24332b', .93)
lining = material('Deep moss silk lining', '334a38', .98)
seam = material('Silk stitched folds', '4c5d44', .95)

# The hollow walls leave a real cavity underneath the hinged lid.
box('Bottom', (0, 0, .16), (4.5, 2.12, .26), wood)
box('Front wall', (0, -1, .83), (4.5, .18, 1.36), wood)
box('Rear wall', (0, 1, .83), (4.5, .18, 1.36), wood)
for x in (-2.16, 2.16):
    box('Side wall', (x, 0, .83), (.18, 1.88, 1.36), wood)
box('Silk cushion', (0, 0, .34), (4.08, 1.76, .12), lining, .07)
for x in range(-7, 8):
    path('Subtle silk folds', [(x * .26, -.81, .41), (x * .26 + .06, -.1, .425), (x * .26 - .025, .81, .41)], seam, .006)
for z in (.2, 1.44):
    box('Front rim', (0, -1.105, z), (4.52, .045, .07), bronze, .012)
    for x in (-2.26, 2.26):
        box('Side rim', (x, 0, z), (.045, 2.16, .07), bronze, .012)
for x in (-2.05, 2.05):
    box('Corner binding', (x, -1.115, .83), (.16, .046, 1.24), bronze, .018)
    for z in (.31, .57, 1.05, 1.33):
        sphere('Hand-forged corner rivet', (x, -1.151, z), .033, gold)

# Three panels match the existing mountain / moon / water lock solution.
for i, x in enumerate((-1.08, 0, 1.08)):
    box('Glyph bronze mount', (x, -1.12, .79), (.79, .055, .76), bronze, .045)
    box('Glyph dark inlay', (x, -1.158, .79), (.64, .026, .61), dark, .03)
    outline('Fine panel edging', x, -1.179, .79, .60, .57, gold)
    y = -1.19
    if i == 0:
        path('Mountain', [(x - .21, y, .64), (x - .11, y, .87), (x, y, .72), (x + .09, y, 1.0), (x + .22, y, .64), (x - .21, y, .64)], gold, .018)
    elif i == 1:
        points = [(x + .16 * math.cos(t), y, .81 + .21 * math.sin(t)) for t in [math.radians(-75 + j * 255 / 32) for j in range(33)]]
        points += [(x - .025, y, .93), (x - .035, y, .74), points[0]]
        path('Crescent moon', points, gold, .018)
    else:
        for z in (.65, .79, .93):
            path('Water wave', [(x - .23 + j * .46 / 20, y, z + math.sin(j / 20 * math.tau) * .026) for j in range(21)], gold, .014)

# Side handle and fittings add depth without covering the three front panels.
for x in (-2.29, 2.29):
    box('Handle mount', (x, 0, .86), (.045, .64, .43), bronze, .04)
    path('Hanging side ring', [(x + math.copysign(.06, x), math.cos(t) * .23, .8 + math.sin(t) * .19) for t in [j / 40 * math.tau for j in range(41)]], gold, .03)

# Sliding opposed bolts are fixed to the body, independent of the lid.
bolts = []
for side in (-1, 1):
    obj = box('Sliding bolt', (side * .34, -1.172, 1.39), (.65, .13, .09), gold, .027)
    bolts.append((side, obj))
    box('Bolt guide', (side * .78, -1.16, 1.39), (.16, .14, .2), bronze, .022)

hinge = bpy.data.objects.new('Hinge pivot: fixed at the rear edge', None)
bpy.context.collection.objects.link(hinge)
hinge.location = (0, .99, 1.53)
box('Solid lid', (0, -1.02, .075), (4.57, 2.21, .18), wood, .055, hinge)
box('Lid recessed silk underside', (0, -1.02, -.029), (4.07, 1.75, .028), lining, .015, hinge)
for x in (-2.12, 2.12):
    box('Lid corner band', (x, -1.02, .178), (.14, 2.13, .04), bronze, .012, hinge)
    for y in (-1.94, -1.5, -.58, -.13):
        sphere('Lid rivet', (x, y, .205), .03, gold, hinge)
for y in (-2.07, .035):
    box('Lid brass rim', (0, y, .07), (4.5, .05, .19), bronze, .013, hinge)
for x in (-1.58, 1.58):
    box('Hinge foot', (x, .95, 1.47), (.43, .3, .09), bronze)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=.075, depth=.5, location=(x, .99, 1.55), rotation=(0, math.pi / 2, 0))
    bpy.context.object.data.materials.append(gold)
    bpy.context.object.name = 'Fixed bronze hinge barrel'

# The front clasp falls free before the cover rotates about the rear hinge.
hasp = bpy.data.objects.new('Falling clasp pivot', None)
bpy.context.collection.objects.link(hasp)
hasp.parent = hinge
hasp.location = (0, -2.145, .08)
box('Clasp', (0, -.02, -.14), (.23, .055, .33), bronze, .035, hasp)
outline('Clasp slot', 0, -.054, -.18, .09, .09, dark, hasp)

# Small lotus scroll engraving on the top and inside the lid.
for side in (-1, 1):
    for j in range(3):
        points = []
        for k in range(41):
            angle = k / 40 * math.tau
            radius = .12 + k / 40 * .1
            points.append((side * (.6 + j * .37) + math.cos(angle) * radius, -1.02 + math.sin(angle) * radius, .172))
        path('Engraved lid cloud scroll', points, bronze, .009, hinge)
for radius in (.26, .31):
    path('Inner circular mirror motif', [(math.cos(j / 64 * math.tau) * radius, -1.02 + math.sin(j / 64 * math.tau) * radius, -.048) for j in range(65)], bronze, .011, hinge)

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 4
scene.cycles.transparent_max_bounces = 4
try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'OPTIX'
    prefs.get_devices()
    for device in prefs.devices:
        device.use = device.type == 'OPTIX'
    if any(d.type == 'OPTIX' for d in prefs.devices):
        scene.cycles.device = 'GPU'
except Exception:
    pass
scene.render.resolution_x, scene.render.resolution_y = WIDTH, HEIGHT
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
scene.render.image_settings.compression = 35
scene.view_settings.view_transform = 'AgX'
scene.world.color = (.28, .28, .28)
scene.render.fps = 15

def light(name, loc, energy, color, size):
    bpy.ops.object.light_add(type='AREA', location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.energy = energy
    obj.data.color = color
    obj.data.shape = 'DISK'
    obj.data.size = size
    obj.rotation_euler = (Vector((0, 0, 1.0)) - obj.location).to_track_quat('-Z', 'Y').to_euler()

light('Lantern key light', (-3.5, -5, 7), 950, (1, .79, .52), 5)
light('Soft front fill', (5, -4, 5), 500, (.73, .85, 1), 4)
light('Warm rear rim', (0, 4, 6), 1100, (1, .76, .45), 3)
bpy.ops.object.camera_add(location=(5.4, -10.8, 7.0))
camera = bpy.context.object
camera.name = 'Locked three-quarter orthographic camera'
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 7.55
camera.rotation_euler = (Vector((0, .15, 1.5)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.camera = camera
bpy.context.view_layer.update()

# A measured screen-space position for the game's existing celadon-shard sprite.
from bpy_extras.object_utils import world_to_camera_view
anchor = world_to_camera_view(scene, camera, Vector((0, -.05, 1.21)))
metadata = {'frame_count': FRAME_COUNT, 'duration': 3.2, 'width': WIDTH, 'height': HEIGHT,
            'shard_anchor': [anchor.x * WIDTH, (1 - anchor.y) * HEIGHT]}
(OUT / 'render.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')

def pose(time):
    opening = smooth(1.5, 3.2, time)
    hinge.rotation_euler.x = -math.radians(102) * opening
    for side, bolt in bolts:
        bolt.location.x = side * (.34 + .55 * smooth(.65 if side < 0 else .94, 1.16 if side < 0 else 1.45, time))
    hasp.rotation_euler.x = math.radians(102) * smooth(1.3, 1.52, time)
    bpy.context.view_layer.update()

scene.frame_start, scene.frame_end = 0, FRAME_COUNT - 1
for index in range(FRAME_COUNT):
    t = 3.2 * index / (FRAME_COUNT - 1)
    pose(t)
    hinge.keyframe_insert(data_path='rotation_euler', frame=index)
    hasp.keyframe_insert(data_path='rotation_euler', frame=index)
    for _, bolt in bolts:
        bolt.keyframe_insert(data_path='location', frame=index)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'workshop-casket.blend'))
indices = [0, 34, FRAME_COUNT - 1] if PREVIEW else range(FRAME_COUNT)
for index in indices:
    scene.frame_set(index)
    scene.render.filepath = str(OUT / f'casket-{index:03}.png')
    bpy.ops.render.render(write_still=True)
    print(f'CASKET_RENDER {index + 1}/{FRAME_COUNT}', flush=True)
print('CASKET_RENDER_DONE', OUT, flush=True)
