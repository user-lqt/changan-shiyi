"""Install the approved Blender A characters into chapter 4's existing rig space.

Source GLBs are Y-up/front +Z, with independent node pivots. Convert all meshes
and local transforms to front +X, normalize the diorama scale, and align soles.
Rebuilds never depend on the temporary preview project or on Blender being open.
"""
from pathlib import Path
import json
import math
import struct
import numpy as np
from night_garment_panels import refine as refine_garment_panels

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art'/'characters'/'ch4-style-a'
DEST=ROOT/'assets'/'models'
SCALE=.68
AXIS=np.array([[0.,0.,1.],[0.,1.,0.],[-1.,0.,0.]])
JOINT_NAMES={'Hips':'Body','Thigh_L':'Leg_L','Thigh_R':'Leg_R'}


def quaternion_multiply(a,b):
    ax,ay,az,aw=a; bx,by,bz,bw=b
    return [aw*bx+ax*bw+ay*bz-az*by,
            aw*by-ax*bz+ay*bw+az*bx,
            aw*bz+ax*by-ay*bx+az*bw,
            aw*bw-ax*bx-ay*by-az*bz]


def rotation_matrix(q):
    x,y,z,w=q
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                     [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                     [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])


def install(role):
    raw=(SOURCE/f'{role}.glb').read_bytes()
    assert raw[:4]==b'glTF' and struct.unpack_from('<I',raw,4)[0]==2
    json_length,kind=struct.unpack_from('<I4s',raw,12)
    assert kind==b'JSON'
    doc=json.loads(raw[20:20+json_length])
    binary_length,kind=struct.unpack_from('<I4s',raw,20+json_length)
    assert kind==b'BIN\0'
    binary=bytearray(raw[28+json_length:28+json_length+binary_length])
    assert not doc.get('animations') and not doc.get('skins'),'Expected independent node rig'
    assert len(doc['buffers'])==1 and not doc['buffers'][0].get('uri')

    def accessor(index):
        item=doc['accessors'][index]; view=doc['bufferViews'][item['bufferView']]
        assert item['componentType']==5126 and not item.get('sparse')
        size={'VEC3':3,'VEC4':4}[item['type']]
        return np.ndarray((item['count'],size),dtype='<f4',buffer=binary,
                          offset=view.get('byteOffset',0)+item.get('byteOffset',0),
                          strides=(view.get('byteStride',size*4),4))

    transformed=set()
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            for semantic,index in primitive['attributes'].items():
                if semantic not in ('POSITION','NORMAL','TANGENT') or index in transformed: continue
                values=accessor(index)
                values[:,:3]=values[:,:3].copy()@AXIS.T*(SCALE if semantic=='POSITION' else 1)
                assert np.all(np.isfinite(values))
                item=doc['accessors'][index]
                if 'min' in item: item['min']=values.min(axis=0).tolist()
                if 'max' in item: item['max']=values.max(axis=0).tolist()
                transformed.add(index)

    q=[0.,math.sqrt(.5),0.,math.sqrt(.5)]
    inverse=[0.,-math.sqrt(.5),0.,math.sqrt(.5)]
    for node in doc['nodes']:
        assert 'matrix' not in node,'Unexpected matrix transform'
        if 'translation' in node:
            node['translation']=(AXIS@np.array(node['translation'])*SCALE).tolist()
        if 'rotation' in node:
            rot=quaternion_multiply(quaternion_multiply(q,node['rotation']),inverse)
            node['rotation']=(np.array(rot)/np.linalg.norm(rot)).tolist()
        node['name']=JOINT_NAMES.get(node.get('name'),node.get('name','Part'))

    def local_matrix(node):
        mat=np.eye(4)
        mat[:3,:3]=rotation_matrix(node.get('rotation',[0,0,0,1]))@np.diag(node.get('scale',[1,1,1]))
        mat[:3,3]=node.get('translation',[0,0,0])
        return mat

    feet=[]
    def visit(index,parent):
        node=doc['nodes'][index]; world=parent@local_matrix(node)
        if node.get('name') in ('Foot_L','Foot_R'):
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                points=accessor(primitive['attributes']['POSITION'])
                feet.append(points@world[:3,:3].T+world[:3,3])
        for child in node.get('children',[]): visit(child,world)
    roots=doc['scenes'][doc.get('scene',0)]['nodes']
    for index in roots: visit(index,np.eye(4))
    assert len(feet)>=2,'Missing feet for ground alignment'
    floor=float(min(points[:,1].min() for points in feet))
    for index in roots:
        node=doc['nodes'][index]
        node.setdefault('translation',[0.,0.,0.])[1]+=.006-floor
        node.setdefault('extras',{}).update({'art_style':'A','role':role,'front_axis':'+X'})

    names={n['name'] for n in doc['nodes']}
    assert {'Body','Chest','Head','Leg_L','Leg_R','Shin_L','Shin_R','Arm_L','Arm_R','Fore_L','Fore_R'}.issubset(names)
    if role == 'su':
        # Pale warm-grey trousers reduce contrast against the ivory coat.
        # Only trouser nodes use this material; the dark shoe soles stay intact.
        color=np.array([201,199,187],dtype=float)/255.0
        linear=np.where(color<=.04045,color/12.92,((color+.055)/1.055)**2.4)
        pants_id=next(i for i,m in enumerate(doc['materials']) if m.get('name')=='pants')
        light=json.loads(json.dumps(doc['materials'][pants_id]))
        light['name']='pants_light_warm_grey'
        light['pbrMetallicRoughness']['baseColorFactor']=linear.tolist()+[1.0]
        doc['materials'].append(light)
        for node in doc['nodes']:
            if node['name'] in ('Leg_L','Leg_R','Shin_L','Shin_R'):
                for primitive in doc['meshes'][node['mesh']]['primitives']:
                    if primitive['material']==pants_id:
                        primitive['material']=len(doc['materials'])-1
    if role in ('su', 'ashi'):
        binary=bytearray(binary)  # Detach live NumPy accessor views before appending.
        refine_garment_panels(doc, binary)
    doc['asset']['generator']='Changan Shiyi / approved Blender style A / runtime axis adaptation'
    metadata=json.dumps(doc,ensure_ascii=False,separators=(',',':')).encode('utf-8')
    metadata+=b' '*(-len(metadata)%4)
    binary+=b'\0'*(-len(binary)%4)
    total=28+len(metadata)+len(binary)
    path=DEST/f'night_{role}.glb'
    path.write_bytes(struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(metadata),b'JSON')+
                     metadata+struct.pack('<I4s',len(binary),b'BIN\0')+binary)
    print(f'{path.name}: Blender style A, +X forward, {len(names)} nodes, soles aligned, {total//1024} KiB')


def install_all():
    for role in ('su','ashi','guard'): install(role)


if __name__=='__main__': install_all()
