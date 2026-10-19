"""Author the tower's reusable detailed meshes as self-contained glTF binaries.

Only NumPy is required. Geometry is in Godot coordinates (Y up), in metres.
Run: python tools/build_tower_models.py
The bevels, turned profiles, joints and reliefs are geometry, not painted decals.
"""
from pathlib import Path
import json
import math
import struct

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/tower_tang'
TAU = math.tau


def rgb(value):
    values = [int(value[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values]


PALETTE = {
    'timber': ('815133', .68, .0),
    'endgrain': ('43291f', .76, .0),
    'lacquer': ('853a2b', .40, .0),
    'stone': ('aaa28c', .88, .0),
    'stone_shadow': ('6f746e', .92, .0),
    'bronze': ('b49859', .43, .62),
    'patina': ('3c6b63', .66, .50),
    'paper': ('e7c895', .85, .0),
    'jade': ('adc8b8', .28, .18),
    'obsidian': ('233c44', .32, .48),
    'spirit_glass': ('233c44', .24, .58),
    'mirror': ('94bfcb', .20, .70),
}


def rotation(x=0, y=0, z=0):
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    return np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1.]]) @ np.array([[cy, 0, sy], [0, 1., 0], [-sy, 0, cy]]) @ np.array([[1., 0, 0], [0, cx, -sx], [0, sx, cx]])


class Model:
    def __init__(self):
        self.parts = {}

    def add(self, vertices, faces, material, pos=(0, 0, 0), rot=None, normals=None, uv=None):
        v = np.asarray(vertices, dtype=float)
        f = np.asarray(faces, dtype=np.uint32)
        # Flat shading unless a turned or swept surface supplies analytic normals.
        if normals is None:
            tri = v[f].reshape(-1, 3, 3)
            n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
            n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
            v = tri.reshape(-1, 3)
            normals = np.repeat(n, 3, axis=0)
            f = np.arange(len(v), dtype=np.uint32).reshape(-1, 3)
            uv = v[:, (0, 1)] if uv is None else np.asarray(uv)[np.asarray(faces).ravel()]
        if rot is not None:
            v = v @ rot.T
            normals = np.asarray(normals) @ rot.T
        v += np.asarray(pos)
        if uv is None:
            uv = v[:, (0, 1)]
        part = self.parts.setdefault(material, [[], [], [], []])
        offset = len(part[0])
        part[0].extend(v.tolist())
        part[1].extend(np.asarray(normals).tolist())
        part[2].extend(np.asarray(uv).tolist())
        part[3].extend((f + offset).ravel().tolist())

    def box(self, size, pos, material='timber', bevel=.01, rot=None):
        # A chamfered cube: six octagonal faces, twelve edge strips, eight corners.
        h = np.array(size) / 2
        b = min(bevel, min(h) * .45)
        faces = []
        for axis in range(3):
            u, w = [a for a in range(3) if a != axis]
            for sign in (-1, 1):
                polygon = []
                for a, c in [(-h[u]+b, -h[w]), (h[u]-b, -h[w]), (h[u], -h[w]+b), (h[u], h[w]-b), (h[u]-b, h[w]), (-h[u]+b, h[w]), (-h[u], h[w]-b), (-h[u], -h[w]+b)]:
                    p = np.zeros(3); p[axis] = sign*h[axis]; p[u] = a; p[w] = c
                    polygon.append(p)
                normal = np.zeros(3); normal[axis] = sign
                faces.append((polygon, normal))
        for free in range(3):
            a, c = [x for x in range(3) if x != free]
            for sa in (-1, 1):
                for sc in (-1, 1):
                    poly = []
                    for t, chamfer in [(-1, 0), (1, 0), (1, 1), (-1, 1)]:
                        p = np.zeros(3); p[free] = t*(h[free]-b)
                        p[a] = sa*(h[a]-(b if chamfer else 0))
                        p[c] = sc*(h[c]-(0 if chamfer else b))
                        poly.append(p)
                    normal = np.zeros(3); normal[a] = sa; normal[c] = sc
                    faces.append((poly, normal))
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    p = h*np.array([sx, sy, sz])
                    poly = [p-np.eye(3)[i]*b*[sx, sy, sz][i] for i in range(3)]
                    faces.append((poly, np.array([sx, sy, sz])))
        verts, tris = [], []
        for poly, normal in faces:
            if np.dot(np.cross(poly[1]-poly[0], poly[2]-poly[0]), normal) < 0:
                poly.reverse()
            start = len(verts); verts.extend(poly)
            tris.extend((start, start+i, start+i+1) for i in range(1, len(poly)-1))
        self.add(verts, tris, material, pos, rot)

    def lathe(self, profile, material, pos=(0, 0, 0), segments=40, rot=None, lobes=0, ripple=0):
        vertices, faces, normals, uvs = [], [], [], []
        for i in range(segments+1):
            a = TAU*i/segments
            for j, (r, h) in enumerate(profile):
                radius = r*(1 + math.cos(a*lobes)*ripple) if lobes else r
                vertices.append((radius*math.cos(a), h, radius*math.sin(a)))
                before = profile[max(j-1, 0)]; after = profile[min(j+1, len(profile)-1)]
                dr, dy = after[0]-before[0], after[1]-before[1]
                normal = np.array([dy*math.cos(a), -dr, dy*math.sin(a)])
                normals.append(normal/max(np.linalg.norm(normal), 1e-8))
                uvs.append((i/segments, h))
        m = len(profile)
        for i in range(segments):
            for j in range(m-1):
                a = i*m+j; b = a+m
                faces += [(a, a+1, b), (a+1, b+1, b)]
        self.add(vertices, faces, material, pos, rot, normals, uvs)

    def ring(self, radius, tube, material, pos=(0, 0, 0), rot=None, segments=64, sides=8, lobes=0, ripple=0):
        verts, normals, faces = [], [], []
        for i in range(segments+1):
            a = TAU*i/segments
            r = radius*(1+math.cos(lobes*a)*ripple) if lobes else radius
            for j in range(sides+1):
                b = TAU*j/sides
                verts.append(((r+tube*math.cos(b))*math.cos(a), tube*math.sin(b), (r+tube*math.cos(b))*math.sin(a)))
                normals.append((math.cos(b)*math.cos(a), math.sin(b), math.cos(b)*math.sin(a)))
        m = sides+1
        for i in range(segments):
            for j in range(sides):
                a = i*m+j; b = a+m
                faces += [(a, a+1, b), (a+1, b+1, b)]
        self.add(verts, faces, material, pos, rot, normals)

    def beam(self, a, b, width, material='timber', depth=None):
        a, b = np.array(a), np.array(b)
        d = b-a; length = np.linalg.norm(d); y = d/length
        x = np.cross(y, [0, 0, 1])
        if np.linalg.norm(x) < .01: x = np.cross(y, [0, 1, 0])
        x /= np.linalg.norm(x); z = np.cross(x, y)
        self.box((width, length, depth or width), (a+b)/2, material, min(width/4, .012), np.column_stack((x, y, z)))

    def tube(self, points, radius, material, sides=6):
        for a, b in zip(points[:-1], points[1:]):
            a, b = np.array(a), np.array(b); d = b-a
            y = d/np.linalg.norm(d); x = np.cross(y, [0, 0, 1])
            if np.linalg.norm(x) < .01: x = np.cross(y, [0, 1, 0])
            x /= np.linalg.norm(x)
            self.lathe([(radius, 0), (radius, float(np.linalg.norm(d)))], material, a, sides, np.column_stack((x, y, np.cross(x, y))))

    def shard(self, size, pos, material='mirror', rot=None):
        w, h, d = size
        polygon = [(-w*.47, -h*.25), (-w*.12, -h*.50), (w*.48, -h*.20), (w*.27, h*.44), (-w*.30, h*.32)]
        vertices = [(x, y, z) for z in (-d/2, d/2) for x, y in polygon]
        faces = [(0, i+1, i) for i in range(1, 4)] + [(5, 5+i, 6+i) for i in range(1, 4)]
        for i in range(5):
            j = (i+1)%5
            faces += [(i, j, 5+i), (j, 5+j, 5+i)]
        self.add(vertices, faces, material, pos, rot)

    def save(self, name):
        OUT.mkdir(parents=True, exist_ok=True)
        doc = {'asset': {'version': '2.0', 'generator': 'Changan Shiyi / tower mesh workshop'}, 'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'name': name, 'mesh': 0}], 'meshes': [{'primitives': []}], 'buffers': [], 'bufferViews': [], 'accessors': [], 'materials': []}
        binary = bytearray()
        def attribute(values, kind, component=5126):
            arr = np.asarray(values, dtype='<f4' if component == 5126 else '<u4')
            while len(binary) % 4: binary.append(0)
            start = len(binary); binary.extend(arr.tobytes())
            doc['bufferViews'].append({'buffer': 0, 'byteOffset': start, 'byteLength': arr.nbytes})
            ac = {'bufferView': len(doc['bufferViews'])-1, 'componentType': component, 'count': len(arr), 'type': kind}
            if kind == 'VEC3': ac.update(min=arr.min(axis=0).tolist(), max=arr.max(axis=0).tolist())
            doc['accessors'].append(ac)
            return len(doc['accessors'])-1
        for material, (verts, normals, uv, indices) in self.parts.items():
            color, rough, metal = PALETTE[material]
            pbr = {'baseColorFactor': rgb(color)+[1], 'metallicFactor': metal, 'roughnessFactor': rough}
            mat = {'name': material, 'pbrMetallicRoughness': pbr}
            if material == 'paper': mat['emissiveFactor'] = [c*.52 for c in rgb('ffc977')]
            if material == 'mirror': mat['emissiveFactor'] = [c*.12 for c in rgb('6ca3b4')]
            doc['materials'].append(mat)
            doc['meshes'][0]['primitives'].append({'attributes': {'POSITION': attribute(verts, 'VEC3'), 'NORMAL': attribute(normals, 'VEC3'), 'TEXCOORD_0': attribute(uv, 'VEC2')}, 'indices': attribute(indices, 'SCALAR', 5125), 'material': len(doc['materials'])-1})
        doc['buffers'].append({'byteLength': len(binary)})
        metadata = json.dumps(doc, separators=(',', ':')).encode()
        metadata += b' ' * (-len(metadata) % 4)
        binary += b'\0' * (-len(binary) % 4)
        total = 12+8+len(metadata)+8+len(binary)
        (OUT/f'{name}.glb').write_bytes(struct.pack('<4sII', b'glTF', 2, total)+struct.pack('<I4s', len(metadata), b'JSON')+metadata+struct.pack('<I4s', len(binary), b'BIN\0')+binary)
        triangles = sum(len(p[3])//3 for p in self.parts.values())
        print(f'{name}: {triangles:,} triangles, {total//1024:,} KiB')


def lotus(model, radius, height, material, y=0, petals=12):
    for i in range(petals):
        a = TAU*i/petals
        # Layered raised petals around a turned stone or bronze base.
        model.lathe([(0, 0), (.044, .018), (.060, height*.45), (.035, height*.85), (0, height)], material, (radius*math.sin(a), y, radius*math.cos(a)), 12, rotation(z=-.24) @ rotation(y=a))


def column():
    m = Model()
    m.box((.52, .09, .52), (0, .045, 0), 'stone', .025)
    m.lathe([(0, 0), (.23, 0), (.24, .04), (.21, .09), (.19, .16), (.145, .22), (.145, .27)], 'stone', (0, .08, 0), 40)
    lotus(m, .17, .12, 'stone', .17)
    m.lathe([(.14, .32), (.145, .38), (.127, 2.68), (.13, 2.89), (.16, 2.93), (.16, 3.02)], 'lacquer', segments=40)
    for y in (.39, 2.72, 2.91): m.ring(.14, .013, 'bronze', (0, y, 0), segments=40)
    # Stacked interlocking bracket arms on both axes, with raised ends.
    for level, span in [(2.98, .58), (3.13, .88), (3.30, 1.16)]:
        for yaw in (0, math.pi/2):
            m.box((span, .105, .16), (0, level, 0), 'timber', .018, rotation(y=yaw))
            for sign in (-1, 1):
                a = rotation(y=yaw) @ np.array([sign*(span/2-.07), 0, 0])
                m.box((.14, .14, .22), (a[0], level+.08, a[2]), 'lacquer', .015, rotation(y=yaw))
                m.box((.18, .045, .26), (a[0], level+.16, a[2]), 'bronze', .01, rotation(y=yaw))
    m.box((1.38, .15, .26), (0, 3.48, 0), 'timber', .02)
    m.save('column_dougong')


def baluster(m, x, y=0, z=0):
    m.lathe([(0, 0), (.07, 0), (.07, .06), (.043, .10), (.037, .38), (.06, .44), (.06, .50), (.036, .54), (.034, .69), (.055, .72), (.055, .78), (0, .78)], 'timber', (x, y, z), 16)
    m.ring(.055, .008, 'bronze', (x, y+.48, z), segments=16)


def rails():
    m = Model()
    m.box((1.07, .085, .13), (0, .84, 0), 'timber', .02)
    m.box((1.07, .055, .09), (0, .22, 0), 'timber')
    m.box((1.07, .04, .095), (0, .70, 0), 'lacquer')
    for x in (-.53, .53): baluster(m, x, .02)
    for x in (-.25, .25):
        for a, b in [((x-.22, .46, 0), (x, .68, 0)), ((x, .68, 0), (x+.22, .46, 0)), ((x+.22, .46, 0), (x, .24, 0)), ((x, .24, 0), (x-.22, .46, 0))]: m.beam(a, b, .027)
        m.box((.055, .055, .10), (x, .46, 0), 'bronze', .009, rotation(z=math.pi/4))
    m.save('rail_panel')


def window():
    m = Model()
    # Open central view, ornament confined to lintel and flanking panels.
    for x in (-1.83, 1.83):
        m.box((.16, 2.24, .25), (x, 1.12, 0), 'timber', .025)
        m.box((.04, 2.0, .28), (x-.055, 1.12, -.02), 'bronze', .007)
    for y in (0, 2.24): m.box((3.88, .17, .30), (0, y, 0), 'timber', .028)
    m.box((3.84, .035, .32), (0, .11, 0), 'lacquer')
    m.box((3.84, .035, .32), (0, 2.13, 0), 'bronze')
    for center in (-1.43, 1.43):
        for x in (-.30, .30): m.box((.05, 1.91, .10), (center+x, 1.12, .015), 'timber')
        for y in (.23, .69, 1.15, 1.61, 2.01):
            m.box((.60, .036, .10), (center, y, .015), 'timber')
        for row in range(4):
            y = .47+row*.44
            for a, b in [((center-.22, y, 0), (center, y+.20, 0)), ((center, y+.20, 0), (center+.22, y, 0)), ((center+.22, y, 0), (center, y-.20, 0)), ((center, y-.20, 0), (center-.22, y, 0))]: m.beam(a, b, .026)
    # Short fretwork band above the unobstructed central opening.
    for x in np.linspace(-1, 1, 9):
        m.box((.025, .25, .09), (x, 2.0, 0), 'timber')
    m.box((2.10, .04, .10), (0, 1.87, 0), 'timber')
    m.save('lattice_window')


def lantern():
    m = Model()
    m.lathe([(.009, .80), (.009, 1.10)], 'bronze', segments=8)
    m.lathe([(.10, .20), (.23, .25), (.245, .34), (.245, .63), (.22, .72), (.10, .76)], 'paper', segments=8)
    for y, r in [(.24, .23), (.29, .245), (.67, .235), (.73, .19)]: m.ring(r, .015, 'timber', (0, y, 0), segments=8)
    for i in range(8):
        a = TAU*(i+.0)/8
        m.beam((.242*math.cos(a), .27, .242*math.sin(a)), (.242*math.cos(a), .68, .242*math.sin(a)), .018)
    m.lathe([(.29, .72), (.29, .75), (.16, .81), (.09, .84), (0, .88)], 'endgrain', segments=8)
    m.lathe([(.19, .19), (.24, .22), (.26, .25)], 'lacquer', segments=8)
    m.lathe([(.02, .18), (.02, .05)], 'bronze', segments=12)
    for i in range(12):
        a = i*TAU/12
        m.tube([(.024*math.cos(a), .08, .024*math.sin(a)), (.035*math.cos(a), -.12, .035*math.sin(a)), (.026*math.cos(a), -.23, .026*math.sin(a))], .005, 'lacquer')
    m.save('paper_lantern')


def stairs():
    m = Model()
    for i in range(20):
        z = -i*5.8/20
        y = (i+1)*1.9/20
        m.box((1.82, .065, .33), (0, y-.033, z-.12), 'timber', .012)
        m.box((1.77, .026, .032), (0, y+.002, z+.043), 'endgrain', .007)
        m.box((1.74, .09, .025), (0, y-.075, z+.01), 'endgrain', .005)
        for x in (-.80, .80):
            m.lathe([(.012, 0), (.012, .005)], 'bronze', (x, y+.001, z-.1), 8)
    for x in (-.78, .78): m.beam((x, -.15, .06), (x, 1.73, -5.77), .14, depth=.24)
    for x in (-.94, .94):
        m.beam((x, .88, .05), (x, 2.78, -5.8), .09, depth=.12)
        m.beam((x, .26, .05), (x, 2.16, -5.8), .045, depth=.06)
        for i in range(11):
            h = i*1.9/10; z = -i*5.8/10
            baluster(m, x, h+.04, z)
            if i < 10:
                m.beam((x, h+.30, z-.03), (x, h+.80+.19, z-.55), .026, depth=.03)
    m.save('timber_stairs')


def mirror():
    m = Model()
    m.box((.82, .09, .50), (0, .045, 0), 'timber', .025)
    for x in (-.32, .32):
        m.box((.10, .27, .34), (x, .18, 0), 'lacquer', .02)
        m.beam((x, .25, 0), (x*.7, .57, 0), .09)
    m.box((.73, .09, .24), (0, .38, 0), 'timber', .02)
    c = (0, 1.02, 0)
    vertical = rotation(x=math.pi/2)
    m.lathe([(0, -.025), (.49, -.025), (.50, 0), (.49, .025), (0, .025)], 'obsidian', c, 80, vertical)
    for r, tube in [(.46, .012), (.50, .028), (.57, .035)]: m.ring(r, tube, 'bronze', c, vertical, 96, 8, 8, .035 if r > .5 else 0)
    for i in range(32):
        a = TAU*i/32
        m.box((.018, .045, .018), (.535*math.sin(a), 1.02+.535*math.cos(a), -.018), 'patina', .004, rotation(z=-a))
    for i in range(8):
        a = i*TAU/8
        m.lathe([(0, 0), (.07, .012), (.052, .024), (0, .035)], 'bronze', (.58*math.sin(a), 1.02+.58*math.cos(a), -.015), 12, vertical)
    m.save('bronze_mirror')


def bell():
    m = Model()
    m.lathe([(.19, .04), (.20, .065), (.17, .10), (.13, .19), (.12, .32), (.08, .38), (0, .39)], 'bronze', segments=48)
    for y, r in [(.065, .19), (.12, .16), (.29, .12), (.33, .11)]: m.ring(r, .009, 'patina', (0, y, 0), segments=48)
    for i in range(8):
        a = TAU*i/8
        m.beam((.125*math.cos(a), .16, .125*math.sin(a)), (.105*math.cos(a), .29, .105*math.sin(a)), .012, 'patina')
    m.ring(.04, .012, 'bronze', (0, .42, 0), rotation(x=math.pi/2), segments=24)
    m.lathe([(.012, -.04), (.012, .065)], 'endgrain', segments=12)
    m.lathe([(0, -.07), (.025, -.06), (.025, -.04), (0, -.025)], 'bronze', segments=16)
    m.save('ritual_bell')


def altar():
    m = Model()
    m.lathe([(0, 0), (.77, 0), (.81, .06), (.81, .12), (.74, .17), (.67, .20), (.62, .29), (.59, .40), (.65, .48), (.76, .54), (.79, .61), (.79, .67), (0, .67)], 'stone', segments=64)
    lotus(m, .61, .19, 'stone', .30, petals=24)
    for y, r in [(.09, .81), (.18, .70), (.53, .74), (.65, .79)]: m.ring(r, .013, 'bronze', (0, y, 0), segments=80)
    m.lathe([(0, .67), (.57, .67), (.61, .69), (.61, .72), (.54, .75), (.47, .72), (0, .72)], 'bronze', segments=64)
    for r in (.21, .35, .47, .54): m.ring(r, .008, 'patina', (0, .74, 0), segments=80)
    for i in range(24):
        a = TAU*i/24
        m.beam((.48*math.sin(a), .744, .48*math.cos(a)), (.54*math.sin(a), .744, .54*math.cos(a)), .009, 'bronze')
    m.save('lotus_altar')


def spirit():
    m = Model()
    v = rotation(x=math.pi/2)
    # Preserve the eight-lobed copper mirror, giving its rim a thick turned profile.
    m.lathe([(0, .065), (.30, .065), (.43, .048), (.49, .018), (.49, -.025),
             (.46, -.048), (.37, -.060), (.33, -.048)], 'bronze', segments=96,
            rot=v, lobes=8, ripple=.068)
    m.lathe([(0, .069), (.31, .069), (.34, .054)], 'obsidian', segments=64, rot=v)
    # Planar radial UVs allow a reflection in the glass without wrapping around the rim.
    vertices = [(0, 0, -.062)]
    vertices += [(.334*math.cos(i*TAU/96), .334*math.sin(i*TAU/96), -.062) for i in range(97)]
    faces = [(0, i+2, i+1) for i in range(96)]
    uvs = [(.5+x/.668, .5-y/.668) for x, y, _ in vertices]
    m.add(vertices, faces, 'spirit_glass', normals=[(0, 0, -1)]*len(vertices), uv=uvs)
    for r, tube, mat, z in [(.335, .012, 'bronze', -.062), (.365, .012, 'patina', -.056),
                             (.392, .018, 'bronze', -.048), (.473, .018, 'patina', -.032),
                             (.493, .009, 'bronze', -.025)]:
        m.ring(r, tube, mat, (0, 0, z), rot=v, segments=96, lobes=8 if r > .35 else 0, ripple=.068)
    # Small raised cloud curls, worn bosses and clips are merged by material on export.
    for i in range(16):
        a = i*TAU/16
        points = []
        for j in range(9):
            k = j/8
            r = .424 + math.sin(k*TAU)*.017
            angle = a + (k-.5)*.19
            points.append((r*math.sin(angle), r*math.cos(angle), -.052 - .006*math.sin(k*math.pi)))
        m.tube(points, .0045, 'patina', sides=5)
    for i in range(8):
        a = i*TAU/8
        m.shard((.13, .21, .045), (.565*math.sin(a), .565*math.cos(a), math.sin(i)*.035), 'mirror', rotation(.2*math.sin(i), .3*math.cos(i), -a+.35))
        m.box((.024, .075, .046), (.35*math.sin(a), .35*math.cos(a), -.072), 'bronze', .006, rotation(z=-a))
        m.lathe([(0, 0), (.012, 0), (.015, .007), (0, .016)], 'bronze',
                (.449*math.sin(a), .449*math.cos(a), -.049), 10, v)
    # The familiar fractured surface stays in front of the gradually emerging image.
    m.tube([(-.27, .18, -.073), (-.10, .09, -.075), (-.04, -.04, -.076), (.14, -.12, -.075), (.23, -.24, -.073)], .0038, 'mirror')
    m.tube([(-.04, -.04, -.076), (.09, .13, -.075), (.15, .27, -.073)], .003, 'jade')
    m.save('mirror_spirit_core')
    m = Model()
    for i in range(11):
        a = i*2.399
        r = .65+(i%3)*.13
        m.shard((.10+(i%3)*.035, .17+(i%4)*.035, .025), (math.sin(a)*r, math.cos(a)*r*.82, math.sin(i*1.8)*.17), 'mirror', rotation(.2*math.sin(i), .4*math.cos(i), -a+.25))
    m.save('mirror_spirit_shards')


def coffer():
    m = Model()
    for r, y in [(1.25, 0), (.98, .07), (.70, .14), (.42, .21)]:
        for i in range(4):
            a = math.pi/4+i*math.pi/2
            p = np.array([math.cos(a)*r, y, math.sin(a)*r])
            q = np.array([math.cos(a+math.pi/2)*r, y, math.sin(a+math.pi/2)*r])
            m.beam(p, q, .075, 'lacquer', .12)
    m.lathe([(0, .23), (.30, .23), (.33, .28), (.22, .34), (0, .38)], 'bronze', segments=32, lobes=8, ripple=.10)
    m.save('ceiling_coffer')


if __name__ == '__main__':
    for builder in (column, rails, window, lantern, stairs, mirror, bell, altar, spirit, coffer): builder()
    (OUT/'SOURCE.md').write_text('# 唐风塔内模型\n\n为《长安拾遗》第六章制作的原创程序化模型。\n生成源文件：`tools/build_tower_models.py`（NumPy + Python 标准库）。\n\n包含倒角木阶、斗拱柱、莲瓣柱础、菱格栏杆、花格窗、纸灯笼、铜镜架、铜铃、莲台、铜镜形态镜魅和藻井。\n模型以唐式木构和铜镜纹样为美术参考，供游戏场景使用。\n\nGLB 文件自包含，可在 Godot 中直接导入，无需额外建模软件。\n', encoding='utf-8')
