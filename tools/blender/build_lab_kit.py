"""Builds the two artifact models for the epilogue lab and exports one GLB each.

Run:  blender --background --factory-startup --python tools/blender/build_lab_kit.py
Output: assets/models/lab_bowl.glb, assets/models/lab_mirror.glb  (1 unit = 1 m)

The lab room itself is simple boxes built in Godot; these two artifacts carry the detail:
  lab_bowl    越窑青瓷刻莲纹碗 (restored): thick-walled lathe body with foot ring, twelve
              incised lotus petals on the outside, an incised eight-petal rosette in the
              well, and gold 金缮 seams tracing the four repaired fragments.
  lab_mirror  海兽葡萄纹铜镜: raised rim, saw-tooth band, grape clusters and leaves in the
              outer zone, a ridge ring, six crouching sea beasts among vines in the inner
              zone, and a crouching-beast knob. Lies face down, decorated back up.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
from build_night_kit import reset, mat, srgb  # noqa: E402

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
    path = os.path.join(OUT, "lab_%s.glb" % name)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    print("EXPORTED", path, len(joined.data.polygons), "faces")


def densify(profile, steps):
    out = []
    for i in range(len(profile) - 1):
        (r0, z0), (r1, z1) = profile[i], profile[i + 1]
        for k in range(steps):
            t = k / steps
            out.append((r0 + (r1 - r0) * t, z0 + (z1 - z0) * t))
    out.append(profile[-1])
    return out


def lathe(name, profile, material, segments=96, displace=None):
    """Revolves (r, z) points around Z. displace(r, z, angle, index) -> (dr, dz) adds relief."""
    mesh = bpy.data.meshes.new(name)
    verts, faces = [], []
    n = len(profile)
    for s in range(segments):
        a = 2 * math.pi * s / segments
        for i, (r, z) in enumerate(profile):
            dr, dz = displace(r, z, a, i) if displace else (0.0, 0.0)
            verts.append(((r + dr) * math.cos(a), (r + dr) * math.sin(a), z + dz))
    for s in range(segments):
        s2 = (s + 1) % segments
        for i in range(n - 1):
            faces.append((s * n + i, s2 * n + i, s2 * n + i + 1, s * n + i + 1))
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def tube(name, points, radius, material):
    """A thin round tube along a 3D polyline (gold seams, vines)."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for i, p in enumerate(points):
        spline.points[i].co = (p[0], p[1], p[2], 1.0)
    o = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def blob(name, size, loc, material, rot=(0, 0, 0), seg=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(4, seg // 2), radius=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    o.data.materials.append(material)
    return o


# ------------------------------------------------------------------ bowl
BOWL_OUTER = [(0.030, 0.000), (0.036, 0.000), (0.037, 0.006), (0.034, 0.009), (0.040, 0.012),
              (0.055, 0.020), (0.068, 0.032), (0.077, 0.045), (0.082, 0.058), (0.0855, 0.069),
              (0.0862, 0.071)]
BOWL_INNER = [(0.0835, 0.0715), (0.0805, 0.066), (0.076, 0.054), (0.068, 0.040), (0.056, 0.027),
              (0.040, 0.017), (0.024, 0.0130), (0.0, 0.0122)]
BOWL_FOOT = [(0.0, 0.004), (0.028, 0.004)]


def bowl_radius(z):
    pts = BOWL_OUTER[4:]
    for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return pts[-1][0]


def petal_relief(r, z, a, _i):
    """Incised (刻花) lotus: twelve outer petals on the body, an eight-petal rosette in the well."""
    if 0.013 < z < 0.060 and r > 0.039 and r < bowl_radius(z) + 0.0005:
        v = (z - 0.013) / 0.047
        u = (a * 12 / (2 * math.pi)) % 1.0 * 2.0 - 1.0
        width = math.sin(math.pi * min(1.0, v * 1.05)) ** 0.7 * 0.92
        line = math.exp(-((abs(u) - width) / 0.13) ** 2)
        vein = math.exp(-(u / 0.09) ** 2) * (0.25 < v < 0.8) * 0.5
        return (-0.0016 * max(line, vein), 0.0)
    if r < 0.030 and z > 0.011 and z < 0.0135:
        v = r / 0.028
        u = (a * 8 / (2 * math.pi)) % 1.0 * 2.0 - 1.0
        width = math.sin(math.pi * min(1.0, v)) ** 0.6 * 0.9
        line = math.exp(-((abs(u) - width) / 0.14) ** 2) * (v > 0.12)
        ring = math.exp(-((v - 0.18) / 0.07) ** 2)
        return (0.0, -0.0011 * max(line, ring))
    return (0.0, 0.0)


def seam_outer(path, rnd):
    """(angle, z) waypoints on the outer wall -> jagged 3D seam slightly proud of the glaze."""
    pts = []
    for (a0, z0), (a1, z1) in zip(path, path[1:]):
        steps = 10
        for k in range(steps):
            t = k / steps
            a = a0 + (a1 - a0) * t + rnd.uniform(-0.025, 0.025)
            z = z0 + (z1 - z0) * t + rnd.uniform(-0.0012, 0.0012)
            z = min(z, 0.0705)
            r = bowl_radius(z) + 0.0009
            pts.append((r * math.cos(a), r * math.sin(a), z))
    a, z = path[-1]
    r = bowl_radius(z) + 0.0009
    pts.append((r * math.cos(a), r * math.sin(a), z))
    return pts


def inner_radius(z):
    pts = list(reversed(BOWL_INNER[:-1]))
    for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return pts[-1][0]


def seam_inner(path, rnd):
    """The rim fragment's crack seen from inside: the path's mirror on the inner wall,
    joined to the outer seam ends by a short run over the rounded lip."""
    pts = []
    for (a0, z0), (a1, z1) in zip(path, path[1:]):
        for k in range(10):
            t = k / 10
            a = a0 + (a1 - a0) * t + rnd.uniform(-0.02, 0.02)
            z = min(0.0705, z0 + (z1 - z0) * t + 0.004 + rnd.uniform(-0.001, 0.001))
            r = inner_radius(z) - 0.0009
            pts.append((r * math.cos(a), r * math.sin(a), z))
    lip_a = [path[0][0], path[-1][0]]
    head = [((0.0862 + 0.0006) * math.cos(lip_a[0]), (0.0862 + 0.0006) * math.sin(lip_a[0]), 0.0712),
            (0.0849 * math.cos(lip_a[0]), 0.0849 * math.sin(lip_a[0]), 0.0721)]
    tail = [(0.0849 * math.cos(lip_a[1]), 0.0849 * math.sin(lip_a[1]), 0.0721),
            ((0.0862 + 0.0006) * math.cos(lip_a[1]), (0.0862 + 0.0006) * math.sin(lip_a[1]), 0.0712)]
    return head + pts + tail


def build_bowl():
    reset()
    celadon = mat("celadon_glaze", srgb("93b89a"), 0.16)
    gold = mat("kintsugi_gold", srgb("d8ae55"), 0.22, 1.0)
    profile = densify(BOWL_FOOT + BOWL_OUTER, 8) + densify(BOWL_INNER, 8)[1:]
    parts = [lathe("bowl", profile, celadon, 384, petal_relief)]
    rnd = random.Random(11)
    # Four repaired fragments (left rim, right rim, belly, lotus centre), as in the finale.
    seams = [
        [(2.3, 0.0705), (2.45, 0.050), (2.8, 0.044), (3.15, 0.052), (3.3, 0.0705)],
        [(5.6, 0.0705), (5.75, 0.054), (6.1, 0.047), (6.45, 0.053), (6.55, 0.0705)],
        [(0.6, 0.036), (0.85, 0.028), (1.3, 0.026), (1.55, 0.034), (1.3, 0.044), (0.85, 0.045), (0.6, 0.036)],
    ]
    for i, s in enumerate(seams):
        parts.append(tube("seam_%d" % i, seam_outer(s, rnd), 0.0011, gold))
        if s[0][1] > 0.07:
            # The same crack shows on the inside wall, continuous over the lip.
            parts.append(tube("seam_in_%d" % i, seam_inner(s, rnd), 0.0010, gold))
    # The lotus-centre fragment: a jagged loop in the well.
    loop = []
    for k in range(33):
        a = 2 * math.pi * k / 32
        r = 0.019 + 0.004 * math.sin(a * 3 + 0.7) + rnd.uniform(-0.0015, 0.0015)
        loop.append((r * math.cos(a), r * math.sin(a), 0.0129 + (r - 0.019) * 0.06))
    loop[-1] = loop[0]
    parts.append(tube("seam_centre", loop, 0.0008, gold))
    export("bowl", parts)


# ------------------------------------------------------------------ mirror
MIRROR_R = 0.105


def build_mirror():
    reset()
    bronze = mat("bronze", srgb("5d5a3c"), 0.5, 0.7)
    worn = mat("bronze_worn", srgb("a28b55"), 0.35, 0.85)
    patina = mat("patina", srgb("44503e"), 0.8, 0.35)
    profile = [(0.0, 0.0), (MIRROR_R, 0.0), (MIRROR_R, 0.009), (0.103, 0.0115), (0.099, 0.0118),
               (0.095, 0.0095), (0.094, 0.0062), (0.073, 0.0060), (0.0715, 0.0098), (0.0685, 0.0098),
               (0.067, 0.0055), (0.020, 0.0052), (0.0, 0.0052)]
    parts = [lathe("disc", densify(profile, 2), bronze, 128)]
    # Worn high points of the rim and ridge.
    parts.append(lathe("rim_hi", [(0.0995, 0.0119), (0.1025, 0.0117)], worn, 128))
    parts.append(lathe("ridge_hi", [(0.0712, 0.0099), (0.0688, 0.0099)], worn, 96))
    # Saw-tooth band just inside the rim.
    for k in range(64):
        a = 2 * math.pi * k / 64
        tip = (0.091 * math.cos(a + 0.05), 0.091 * math.sin(a + 0.05), 0.0068)
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.0024, radius2=0.0, depth=0.0016,
                                        location=(0.0925 * math.cos(a), 0.0925 * math.sin(a), 0.0070))
        tooth = bpy.context.active_object
        tooth.rotation_euler = (0, 0, a)
        tooth.data.materials.append(bronze)
        parts.append(tooth)
        del tip
    rnd = random.Random(5)
    # Outer zone: grape clusters alternating with vine leaves.
    for k in range(18):
        a = 2 * math.pi * k / 18
        cx, cy = 0.083 * math.cos(a), 0.083 * math.sin(a)
        if k % 2 == 0:
            for row, count in enumerate((3, 2, 1)):
                for j in range(count):
                    off = (j - (count - 1) / 2) * 0.0058
                    radial = 0.0045 - row * 0.0045
                    px = cx + math.cos(a) * radial - math.sin(a) * off
                    py = cy + math.sin(a) * radial + math.cos(a) * off
                    parts.append(blob("grape", (0.0029, 0.0029, 0.0024), (px, py, 0.0078), bronze, seg=8))
        else:
            parts.append(blob("leaf", (0.0085, 0.0045, 0.0013), (cx, cy, 0.0068), patina, rot=(0, 0, a + 0.6), seg=8))
    # Vine ring weaving through the inner zone.
    vine = []
    for k in range(97):
        a = 2 * math.pi * k / 96
        r = 0.056 + 0.0035 * math.sin(a * 12)
        vine.append((r * math.cos(a), r * math.sin(a), 0.0062))
    parts.append(tube("vine", vine, 0.0011, bronze))
    # Six crouching sea beasts (海兽) between the knob and the ridge.
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        bx, by = 0.042 * math.cos(a), 0.042 * math.sin(a)
        heading = a + math.pi / 2
        hx, hy = math.cos(heading), math.sin(heading)
        parts.append(blob("beast_body", (0.0115, 0.0062, 0.0042), (bx, by, 0.0080), bronze, rot=(0, 0, heading), seg=12))
        parts.append(blob("beast_head", (0.0048, 0.0042, 0.0040), (bx + hx * 0.012, by + hy * 0.012, 0.0095), worn, seg=10))
        for side in (-1, 1):
            # Ears / mane tufts and four paws.
            parts.append(blob("ear", (0.0016, 0.0012, 0.0018), (bx + hx * 0.013 - hy * side * 0.003, by + hy * 0.013 + hx * side * 0.003, 0.0128), bronze, seg=6))
            for fore in (0.007, -0.007):
                px = bx + hx * fore - hy * side * 0.0058
                py = by + hy * fore + hx * side * 0.0058
                parts.append(blob("paw", (0.0022, 0.0018, 0.0016), (px, py, 0.0062), bronze, seg=6))
        tail = [(bx - hx * 0.010, by - hy * 0.010, 0.0085),
                (bx - hx * 0.015 + math.cos(a) * 0.004, by - hy * 0.015 + math.sin(a) * 0.004, 0.0095),
                (bx - hx * 0.017 + math.cos(a) * 0.009, by - hy * 0.017 + math.sin(a) * 0.009, 0.0080)]
        parts.append(tube("tail", tail, 0.0012, bronze))
        # A small grape cluster between beasts.
        ga = a + math.pi / 6
        for j in range(4):
            parts.append(blob("grape_in", (0.0024, 0.0024, 0.002), (0.030 * math.cos(ga) + rnd.uniform(-0.003, 0.003),
                                                                     0.030 * math.sin(ga) + rnd.uniform(-0.003, 0.003), 0.0068), bronze, seg=8))
    # Crouching-beast knob (伏兽钮) with a cord hole.
    parts.append(blob("knob_body", (0.017, 0.0135, 0.0095), (0, 0, 0.0100), bronze, seg=16))
    parts.append(blob("knob_head", (0.0072, 0.0068, 0.0062), (0.0135, 0, 0.0142), worn, seg=12))
    parts.append(blob("knob_ridge", (0.011, 0.0028, 0.0024), (-0.002, 0, 0.0190), worn, seg=10))
    for side in (-1, 1):
        parts.append(blob("knob_leg", (0.0045, 0.0032, 0.0030), (0.007, side * 0.010, 0.0062), bronze, seg=8))
        parts.append(blob("knob_leg", (0.0045, 0.0032, 0.0030), (-0.009, side * 0.010, 0.0062), bronze, seg=8))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.0045, minor_radius=0.0011, location=(0, 0, 0.0115), rotation=(math.pi / 2, 0, 0))
    hole = bpy.context.active_object
    hole.data.materials.append(patina)
    parts.append(hole)
    export("mirror", parts)


if __name__ == "__main__":
    build_bowl()
    build_mirror()
