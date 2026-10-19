"""Chapter 4: articulated diorama characters and Tang street props.

Run with Python + NumPy. Reuses the tower's bevelled geometry helpers, without
changing its palette or exports. Character nodes retain explicit joint pivots;
Godot drives the walk/crouch/throw poses from actual displacement.
Coordinates: metres, Y up, characters face +X.
"""
from pathlib import Path
import json
import math
import struct
import numpy as np
from build_tower_models import Model, rotation, rgb

OUT = Path(__file__).resolve().parents[1] / 'assets/models'
PALETTE = {
    'skin': ('ddb69a', .85, 0), 'skin_shadow': ('ba8167', .88, 0),
    'hair': ('252b30', .70, 0), 'hair_edge': ('3d4345', .75, 0),
    'ivory': ('cdc8b6', .92, 0), 'ivory_edge': ('a4a695', .93, 0),
    'teal': ('315b60', .84, 0), 'trouser': ('34454a', .90, 0),
    'leather': ('47352d', .78, 0), 'leather_light': ('88633f', .85, 0),
    'hemp': ('ae9566', .95, 0), 'patch': ('756c4e', .98, 0),
    'rust': ('9d4833', .88, 0), 'rust_dark': ('6e302b', .92, 0),
    'armor': ('4c6267', .43, .52), 'armor_dark': ('293b42', .54, .45),
    'bronze': ('b3975f', .42, .58), 'metal': ('95a6aa', .32, .68),
    'timber': ('825b3c', .86, 0), 'endgrain': ('473a2c', .92, 0),
    'lacquer': ('9b4e38', .76, 0), 'stone': ('969282', .96, 0),
    'plaster': ('b9ad90', .97, 0), 'earth': ('907a5a', .99, 0),
    'earth_line': ('756c59', .99, 0),
    'tile': ('4b5b60', .82, .06), 'tile_edge': ('68787b', .84, .02),
    'cloth': ('4c6a73', .93, 0), 'straw': ('b5a47c', .99, 0),
    'paper': ('f0bc71', .87, 0), 'window': ('b28b52', .95, 0),
}


class Part(Model):
    def ellipsoid(self, radius, pos, material, rot=None, rings=10, segments=16):
        v, n, f = [], [], []
        rr = np.array(radius)
        for i in range(rings+1):
            a = math.pi*i/rings
            for j in range(segments+1):
                b = math.tau*j/segments
                p = np.array([math.sin(a)*math.cos(b), math.cos(a), math.sin(a)*math.sin(b)])
                v.append(p*rr)
                normal = p/rr
                n.append(normal/max(np.linalg.norm(normal), 1e-8))
        for i in range(rings):
            for j in range(segments):
                a = i*(segments+1)+j; b = a+segments+1
                f.extend([(a, a+1, b), (a+1, b+1, b)])
        self.add(v, f, material, pos, rot, n)

    def cloth(self, width, length, material, origin=(-.12, .16, 0), depth=.04, folds=5):
        v, f = [], []
        for row in range(9):
            t = row/8
            for col in range(17):
                s = col/16
                v.append((origin[0]-t*depth+math.sin(s*math.tau*folds)*.012*t,
                          origin[1]-t*length, origin[2]+(s-.5)*width*(.80+.20*t)))
        for i in range(8):
            for j in range(16):
                a=i*17+j; b=a+17
                f += [(a, b, a+1), (a+1, b, b+1)]
        self.add(v, f, material)


class Scene:
    def __init__(self):
        self.nodes = []

    def node(self, name, parent=None, pos=(0, 0, 0)):
        part = Part()
        self.nodes.append((name, parent, list(pos), part))
        return len(self.nodes)-1, part

    def save(self, name):
        doc = {'asset': {'version': '2.0', 'generator': 'Changan Shiyi / night detail workshop'},
               'scene': 0, 'scenes': [{'nodes': []}], 'nodes': [], 'meshes': [],
               'buffers': [], 'bufferViews': [], 'accessors': [], 'materials': []}
        binary = bytearray()
        def attr(values, kind, component=5126):
            a = np.asarray(values, dtype='<f4' if component == 5126 else '<u4')
            binary.extend(b'\0' * (-len(binary) % 4))
            start = len(binary); binary.extend(a.tobytes())
            doc['bufferViews'].append({'buffer': 0, 'byteOffset': start, 'byteLength': a.nbytes})
            ac = {'bufferView': len(doc['bufferViews'])-1, 'componentType': component,
                  'count': len(a), 'type': kind}
            if kind == 'VEC3': ac.update(min=a.min(axis=0).tolist(), max=a.max(axis=0).tolist())
            doc['accessors'].append(ac)
            return len(doc['accessors'])-1
        mat_ids = {}
        for name_, (color, rough, metal) in PALETTE.items():
            mat_ids[name_] = len(doc['materials'])
            material = {'name': name_, 'pbrMetallicRoughness': {
                'baseColorFactor': rgb(color)+[1], 'roughnessFactor': rough, 'metallicFactor': metal}}
            if name_ in ('rust', 'rust_dark', 'ivory', 'cloth'): material['doubleSided'] = True
            if name_ == 'paper': material['emissiveFactor'] = [c*.32 for c in rgb('ffc57c')]
            if name_ == 'window': material['emissiveFactor'] = [c*.12 for c in rgb('dca25b')]
            doc['materials'].append(material)
        tris = 0
        for index, (label, parent, pos, model) in enumerate(self.nodes):
            node = {'name': label, 'translation': pos}
            doc['nodes'].append(node)
            if parent is None: doc['scenes'][0]['nodes'].append(index)
            else: doc['nodes'][parent].setdefault('children', []).append(index)
            if not model.parts: continue
            primitives=[]
            for material, (v, n, uv, ids) in model.parts.items():
                primitives.append({'attributes': {'POSITION': attr(v, 'VEC3'),
                    'NORMAL': attr(n, 'VEC3'), 'TEXCOORD_0': attr(uv, 'VEC2')},
                    'indices': attr(ids, 'SCALAR', 5125), 'material': mat_ids[material]})
                tris += len(ids)//3
            node['mesh'] = len(doc['meshes'])
            doc['meshes'].append({'name': label, 'primitives': primitives})
        doc['buffers'].append({'byteLength': len(binary)})
        raw = json.dumps(doc, separators=(',', ':')).encode()
        raw += b' ' * (-len(raw) % 4); binary += b'\0' * (-len(binary) % 4)
        size = 28+len(raw)+len(binary)
        path = OUT/f'night_{name}.glb'
        path.write_bytes(struct.pack('<4sII', b'glTF', 2, size)+struct.pack('<I4s', len(raw), b'JSON')+
                         raw+struct.pack('<I4s', len(binary), b'BIN\0')+binary)
        print(f'{path.name}: {tris:,} triangles; {len(self.nodes)} articulated nodes; {size//1024} KiB')


def face(m, kind):
    m.ellipsoid((.088, .118, .092), (.012, .08, 0), 'skin', rings=12, segments=20)
    m.ellipsoid((.022, .026, .027), (.095, .068, 0), 'skin')
    for side in (-1, 1):
        m.ellipsoid((.025, .035, .015), (0, .065, side*.091), 'skin')
        m.ellipsoid((.004, .008, .012), (.093, .096, side*.035), 'hair', rings=6, segments=8)
        m.beam((.092, .118, side*.020), (.089, .120, side*.051), .008, 'hair')
    m.beam((.094, .032, -.019), (.094, .032, .019), .004, 'skin_shadow')
    if kind != 'guard':
        # The back/crown leaves the face exposed; short fringes break the outline.
        m.ellipsoid((.078, .109, .097), (-.033, .105, 0), 'hair')
        m.ellipsoid((.084, .043, .100), (.005, .172, 0), 'hair')
        for i in range(5):
            z=(i-2)*.034
            m.ellipsoid((.037, .045 if i < 3 else .035, .026), (.065, .153-(i%2)*.009, z), 'hair')
        if kind == 'su':
            for side in (-1, 1):
                m.ellipsoid((.060, .070, .023), (-.012, .087, side*.090), 'hair')
                m.beam((.02, .150, side*.102), (-.04, .115, side*.102), .008, 'hair_edge')
        else:
            m.ellipsoid((.048, .049, .047), (-.023, .213, 0), 'hair')
            m.lathe([(.028, 0), (.031, .015)], 'rust', (-.023, .181, 0), 12)
    else:
        m.lathe([(.106, .090), (.112, .138), (.100, .193), (.055, .239), (0, .253)], 'armor_dark', segments=24)
        m.ring(.107, .009, 'bronze', (0, .131, 0), segments=24)
        for side in (-1, 1):
            m.box((.10, .098, .025), (-.015, .06, side*.091), 'armor', .008)
            m.box((.106, .008, .030), (-.015, .017, side*.091), 'bronze', .003)
        m.beam((-.018, .247, 0), (-.085, .355, 0), .027, 'rust')
        for i in range(3): m.ellipsoid((.026, .065, .014), (-.06-i*.016, .300-i*.006, 0), 'rust')


def character(kind):
    s = Scene()
    root, _ = s.node('Rig')
    child = kind == 'ashi'
    guard = kind == 'guard'
    hip = .44 if child else .55
    leg_len = .18 if child else .23
    body, m = s.node('Body', root, (0, hip, 0))
    fabric = 'rust_dark' if guard else ('hemp' if child else 'teal')
    m.box((.18, .14, .23), (0, .035, 0), 'trouser' if not child else 'patch', .028)
    chest, m = s.node('Chest', body, (0, .08, 0))
    height = .25 if child else .29
    width = .26 if child else .29
    m.ellipsoid((.105, height*.60, width*.48), (0, height*.48, 0), fabric)
    if guard:
        m.box((.22, .27, .29), (0, .145, 0), 'armor_dark', .035)
        for x in (-.121, .121):
            for row in range(5):
                for col in range(6):
                    z=(col-2.5)*.043; y=.045+row*.043
                    m.box((.018, .053, .039), (x, y, z), 'armor', .004)
                    if row % 2 == 0: m.ellipsoid((.004, .005, .005), (x*1.09, y+.014, z), 'bronze', rings=4, segments=6)
        m.box((.235, .047, .30), (0, -.018, 0), 'leather', .008)
        m.box((.018, .054, .060), (.13, -.018, 0), 'bronze', .005)
        cape, p = s.node('Cape', chest, (-.04, height, 0))
        p.cloth(.34, .52, 'rust', (-.105, -.025, 0), .09)
    elif kind == 'su':
        m.ellipsoid((.106, .164, .15), (-.008, .14, 0), 'ivory')
        # Teal opening, two folded lapels and a readable diagonal satchel strap.
        m.box((.018, .24, .09), (.101, .153, 0), 'teal', .008)
        for side in (-1, 1):
            m.beam((.113, .28, side*.09), (.118, .11, side*.032), .030, 'ivory', .018)
            m.box((.018, .066, .055), (.106, .039, side*.085), 'ivory_edge', .005)
        m.beam((.125, .28, -.10), (.125, -.11, .125), .025, 'leather_light', .018)
        m.box((.09, .12, .14), (.02, -.073, .17), 'leather_light', .016)
        m.box((.018, .052, .146), (.073, -.055, .17), 'leather', .006)
        for y in (.06, .12): m.ellipsoid((.005, .007, .007), (.117, y, .031), 'bronze', rings=4, segments=6)
    else:
        m.beam((.10, .25, -.085), (.112, .03, .055), .023, 'patch', .016)
        m.box((.018, .088, .065), (.105, .106, .078), 'patch', .003)
        for y in (.080, .114, .145): m.beam((.119, y, .046), (.119, y+.005, .108), .004, 'straw')
        m.box((.24, .040, .25), (0, -.015, 0), 'rust', .01)
        m.beam((.117, .24, -.10), (.117, -.035, .11), .020, 'leather', .014)
        m.ellipsoid((.06, .08, .07), (-.025, -.015, .16), 'leather_light')
        for i in range(3): m.ring(.014, .004, 'bronze', (.12, -.06-i*.021, -.08), rotation(z=math.pi/2), segments=12, sides=4)
    head, p = s.node('Head', chest, (0, height+.015, 0))
    face(p, kind)
    # Split hems can lag behind a turn without deforming the body mesh.
    for side, label in ((-1, 'L'), (1, 'R')):
        skirt, p = s.node('Hem_'+label, body, (0, .03, side*.068))
        if guard:
            for row in range(3):
                for col in range(3):
                    p.box((.02, .060, .046), (.105+row*.008, -.06-row*.048, (col-1)*.047), 'armor', .004)
        else:
            p.cloth(.145, .20 if child else .28, 'hemp' if child else 'ivory', (.10, .01, 0), -.025, 2)
            p.cloth(.145, .19 if child else .27, 'hemp' if child else 'ivory', (-.11, .01, 0), .035, 2)
        leg, p = s.node('Leg_'+label, body, (0, 0, side*(.071 if child else .080)))
        p.ellipsoid((.055, leg_len*.60, .053), (0, -leg_len*.46, 0), 'patch' if child else 'trouser')
        shin, p = s.node('Shin_'+label, leg, (0, -leg_len, 0))
        p.ellipsoid((.040, leg_len*.52, .043), (0, -leg_len*.46, 0), 'skin' if child else 'trouser')
        if guard:
            p.box((.022, .15, .075), (.035, -.10, 0), 'armor', .008)
            for y in (-.04, -.15): p.box((.091, .016, .091), (0, y, 0), 'leather', .003)
        shoe = 'straw' if child else 'leather'
        p.box((.16 if child else .18, .042, .095), (.034, -leg_len-.013, 0), shoe, .014)
        if child:
            for x in (.005, .048): p.beam((x, -leg_len+.016, -.046), (x+.018, -leg_len+.018, .046), .012, 'leather_light')
        else:
            p.box((.10, .10, .087), (-.004, -leg_len+.042, 0), 'leather', .012)
        arm, p = s.node('Arm_'+label, chest, (0, height*.83, side*(width*.48+.025)))
        arm_len = .14 if child else .18
        p.ellipsoid((.055, arm_len*.68, .058), (0, -arm_len*.42, side*.012), fabric if kind != 'su' else 'ivory')
        if guard:
            p.box((.19, .060, .14), (0, -.008, side*.020), 'armor', .022)
            for i in range(3): p.box((.16, .022, .12), (0, -.025-i*.020, side*.025), 'armor_dark', .005)
        fore, p = s.node('Fore_'+label, arm, (0, -arm_len, 0))
        p.ellipsoid((.045, arm_len*.57, .047), (.008, -arm_len*.40, 0), 'ivory' if kind == 'su' else fabric)
        p.box((.083, .030, .088), (.006, -arm_len*.75, 0), 'ivory_edge' if kind == 'su' else 'leather_light', .008)
        p.ellipsoid((.037, .052, .033), (.014, -arm_len-.016, 0), 'skin')
        if guard and label == 'R':
            _, weapon = s.node('Weapon', fore, (.045, -arm_len, .020))
            weapon.lathe([(.014, -.39), (.014, .94)], 'timber', segments=12)
            for y in (-.28, .17, .72): weapon.lathe([(.018, y), (.018, y+.026)], 'bronze', segments=12)
            weapon.lathe([(0, .85), (.036, .88), (.045, .97), (0, 1.15)], 'metal', segments=4)
            weapon.beam((0, .86, 0), (.12, .96, 0), .025, 'bronze')
            weapon.shard((.13, .19, .018), (.14, .98, 0), 'metal', rotation(z=-.35))
    s.save(kind)


def curved_roof(m, width, depth, y, height):
    # Curved gable surfaces, tiled rows, round ridge and eave-end caps.
    for side in (-1, 1):
        def level(z): return y+height*(1-z/(depth*.5))**1.65
        vertices=[]; faces=[]
        for row in range(9):
            z=depth*.5*row/8
            vertices.extend([(-width/2,level(z),side*z),(width/2,level(z),side*z)])
        for row in range(8):
            a=row*2
            tri=[(a,a+2,a+1),(a+1,a+2,a+3)]
            if side < 0: tri=[tuple(reversed(t)) for t in tri]
            faces.extend(tri)
        m.add(vertices,faces,'tile')
        for row in range(5):
            z0=depth*.5*row/5; z1=depth*.5*(row+1)/5
            for col in range(max(5, int(width/.14))):
                n=max(5, int(width/.14)); x=-width/2+(col+.5)*width/n
                m.beam((x, level(z0)+.013, side*z0), (x, level(z1)+.013, side*z1), .025, 'tile_edge', .022)
        m.beam((-width/2, y, side*depth/2), (width/2, y, side*depth/2), .055, 'tile')
        for col in range(max(5, int(width/.14))):
            n=max(5, int(width/.14)); x=-width/2+(col+.5)*width/n
            m.ellipsoid((.027, .032, .014), (x, y-.015, side*(depth/2+.020)), 'tile_edge', rings=4, segments=8)
    m.beam((-width/2-.02, y+height, 0), (width/2+.02, y+height, 0), .070, 'tile')


def wall():
    s=Scene(); _, m=s.node('WardWall')
    m.box((1, .53, 1), (0, .265, 0), 'earth', .018)
    m.box((1.01, .12, 1.01), (0, .065, 0), 'stone', .008)
    # Fine horizontal rammed-earth courses; subdued, not heavy bricks.
    for y in (.19, .32, .45):
        for z in (-.503, .503): m.box((.97, .006, .003), (0, y, z), 'earth_line', .001)
        for x in (-.503, .503): m.box((.003, .006, .97), (x, y, 0), 'earth_line', .001)
    curved_roof(m, 1.06, 1.06, .56, .10)
    s.save('wall')


def house():
    s=Scene(); _, m=s.node('WardHouse')
    m.box((1.40, .12, 1.1), (0, .06, 0), 'stone')
    m.box((1.30, .75, 1.0), (0, .49, 0), 'plaster', .022)
    for x in (-.64, .64):
        for z in (-.49, .49): m.lathe([(.035, .12), (.035, .89)], 'lacquer', (x,0,z), 12)
    for z in (-.51, .51):
        for x in (-.36, .36):
            m.box((.38, .38, .018), (x,.54,z), 'endgrain', .006)
            m.box((.33, .33, .020), (x,.54,z*1.012), 'window', .004)
            for dx in (-.1, 0, .1): m.box((.018,.35,.025), (x+dx,.54,z*1.04), 'timber', .003)
            for y in (.44,.55,.65): m.box((.35,.015,.025), (x,y,z*1.04), 'timber', .003)
        m.box((1.43,.09,.10), (0,.86,z), 'timber', .01)
    curved_roof(m, 1.65, 1.40, .91, .32)
    s.save('house')


def lantern():
    s=Scene(); root,m=s.node('LanternPost')
    m.lathe([(.10,0),(.11,.07),(.07,.12),(.035,.14),(.035,1.48)], 'endgrain', segments=16)
    m.beam((-.02,1.46,0),(.41,1.46,0), .045, 'timber')
    m.beam((0,1.20,0),(.24,1.46,0), .030, 'timber')
    joint,m=s.node('LanternSwing', root, (.36,1.46,0))
    m.lathe([(.009,-.10),(.009,0)], 'bronze', segments=8)
    m.lathe([(.07,-.42),(.115,-.39),(.134,-.33),(.134,-.19),(.109,-.13),(.06,-.11)], 'paper', segments=16)
    for y,r in ((-.40,.104),(-.36,.130),(-.16,.121),(-.115,.07)):
        m.ring(r,.009, 'endgrain',(0,y,0),segments=16, sides=6)
    for i in range(8):
        a=math.tau*i/8
        m.beam((.12*math.cos(a),-.38,.12*math.sin(a)),(.12*math.cos(a),-.16,.12*math.sin(a)),.008,'timber')
    m.lathe([(.025,-.48),(.025,-.41)], 'bronze',segments=8)
    for z in (-.018,0,.018): m.beam((0,-.48,z),(-.008,-.61,z),.007,'rust')
    s.save('lantern')


def cart():
    s=Scene(); _,m=s.node('MerchantCart')
    for i in range(6): m.box((.82,.055,.079), (0,.36,(i-2.5)*.087),'timber',.006)
    for z in (-.26,.26): m.beam((-.41,.33,z),(.66,.33,z),.046,'endgrain')
    for z in (-.33,.33):
        m.ring(.255,.027,'endgrain',(0,.28,z),rotation(x=math.pi/2),segments=32)
        m.ring(.274,.009,'metal',(0,.28,z),rotation(x=math.pi/2),segments=32)
        m.ellipsoid((.054,.054,.045),(0,.28,z),'bronze')
        for i in range(10):
            a=i*math.tau/10
            m.beam((0,.28,z),(.245*math.cos(a),.28+.245*math.sin(a),z),.018,'timber')
    for x,y,z in ((-.22,.55,-.08),(.15,.57,.06),(-.19,.70,.08)):
        m.ellipsoid((.18,.14,.15),(x,y,z),'straw')
        m.ring(.105,.007,'leather_light',(x,y+.04,z),segments=16)
    # Sagging fabric over the merchandise, shaped geometry rather than a box.
    v=[]; f=[]
    for row in range(11):
        x=-.44+row*.085
        for col in range(13):
            z=-.31+col*.052
            y=.73+.06*math.cos(x*5)-.15*(abs(z)/.32)**3+.012*math.sin(z*38+x*9)
            v.append((x,y,z))
    for row in range(10):
        for col in range(12):
            a=row*13+col; f += [(a,a+13,a+1),(a+1,a+13,a+14)]
    m.add(v,f,'cloth')
    for x in (-.29,.27): m.tube([(x,.55,-.30),(x,.80,-.12),(x,.80,.12),(x,.55,.30)],.009,'leather_light')
    s.save('cart')


def gate():
    s=Scene(); _,m=s.node('WardGate')
    for x in (-.54,.54):
        m.box((.22,.12,.36),(x,.06,0),'stone',.02)
        m.box((.14,1.32,.24),(x,.76,0),'lacquer',.016)
        m.box((.22,.075,.30),(x,1.38,0),'timber',.009)
    m.box((1.38,.14,.33),(0,1.46,0),'lacquer',.02)
    curved_roof(m,1.60,.82,1.60,.23)
    m.box((.39,.16,.045),(0,1.34,.20),'endgrain',.012)
    m.box((.32,.10,.006),(0,1.34,.225),'bronze',.007)
    s.save('gate')
    s=Scene(); _,m=s.node('GateLeaf')
    for i in range(5): m.box((.096,1.24,.06),(.05+i*.10,.64,0),'timber',.006)
    for y in (.20,.65,1.09):
        m.box((.50,.075,.082),(.25,y,0),'endgrain',.008)
        for x in (.10,.25,.40): m.ellipsoid((.014,.014,.013),(x,y,.048),'bronze',rings=6,segments=8)
    m.ring(.045,.008,'bronze',(.41,.68,.061),rotation(x=math.pi/2),segments=20)
    s.save('door')


if __name__ == '__main__':
    # The approved characters are editable Blender assets. Rebuilding street
    # props must not silently replace them with the earlier procedural people.
    from install_night_style_a import install_all
    install_all()
    for builder in (wall,house,lantern,cart,gate): builder()
    from build_night_pagoda import build as build_pagoda
    build_pagoda()
