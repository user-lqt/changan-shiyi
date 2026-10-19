"""Add waist loops and separate left/right garment panels to runtime GLBs.

Preserves the approved silhouette, normals, UVs and original materials. UV2.x
selects the thigh followed by each panel; the seam remains closed at the waist.
"""
import numpy as np


def refine(doc, binary):
    def read(index):
        item = doc['accessors'][index]
        view = doc['bufferViews'][item['bufferView']]
        dims = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[item['type']]
        dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2', 5121: 'u1'}[item['componentType']]
        width = np.dtype(dtype).itemsize
        return np.ndarray((item['count'], dims), dtype=dtype, buffer=binary,
                          offset=view.get('byteOffset', 0) + item.get('byteOffset', 0),
                          strides=(view.get('byteStride', dims * width), width)).copy()

    def write(values, kind, indices=False):
        values = np.asarray(values, dtype='<u4' if indices else '<f4')
        binary.extend(b'\0' * (-len(binary) % 4))
        offset = len(binary)
        binary.extend(values.tobytes())
        doc['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': values.nbytes})
        item = {'bufferView': len(doc['bufferViews']) - 1, 'componentType': 5125 if indices else 5126,
                'count': len(values), 'type': kind}
        if kind == 'VEC3':
            item.update(min=values.min(axis=0).tolist(), max=values.max(axis=0).tolist())
        doc['accessors'].append(item)
        return len(doc['accessors']) - 1

    def cut(tri, axis, height):
        distances = [v['POSITION'][axis] - height for v in tri]
        if min(distances) >= -1e-7 or max(distances) <= 1e-7:
            return [tri]
        pieces = []
        for side in [-1, 1]:
            polygon = []
            for j in range(3):
                a, b = tri[j], tri[(j + 1) % 3]
                da, db = distances[j] * side, distances[(j + 1) % 3] * side
                if da >= -1e-7:
                    polygon.append(a)
                if (da > 1e-7 and db < -1e-7) or (da < -1e-7 and db > 1e-7):
                    t = da / (da - db)
                    polygon.append({key: a[key] + (b[key] - a[key]) * t for key in a})
            for j in range(1, len(polygon) - 1):
                face = [polygon[0], polygon[j], polygon[j + 1]]
                a, b, c = [v['POSITION'] for v in face]
                if np.linalg.norm(np.cross(b - a, c - a)) > 1e-10:
                    pieces.append(face)
        return pieces

    mesh_ids = {n['mesh'] for n in doc['nodes']
                if n.get('name') in ('CoatHem', 'Chest') and 'mesh' in n}
    # Only Ashi's chest has a tunic below the waist. Su's chest stays original.
    has_coat = any(n.get('name') == 'CoatHem' for n in doc['nodes'])
    if has_coat:
        mesh_ids = {n['mesh'] for n in doc['nodes'] if n.get('name') == 'CoatHem'}
    for mesh_id in mesh_ids:
        for primitive in doc['meshes'][mesh_id]['primitives']:
            arrays = {name: read(index) for name, index in primitive['attributes'].items()}
            indices = read(primitive['indices']).reshape(-1, 3)
            triangles = [[{name: values[i] for name, values in arrays.items()} for i in face]
                         for face in indices]
            for axis, height in [(1, -0.06), (1, -0.04), (1, -0.02), (1, 0.0), (2, 0.0)]:
                triangles = [piece for face in triangles for piece in cut(face, axis, height)]
            packed = {name: [] for name in arrays}
            sides = []
            for face in triangles:
                side = 1.0 if sum(v['POSITION'][2] for v in face) >= 0 else 0.0
                for vertex in face:
                    for name in packed:
                        value = vertex[name]
                        if name in ('NORMAL', 'TANGENT'):
                            value = value.copy()
                            value[:3] /= max(np.linalg.norm(value[:3]), 1e-8)
                        packed[name].append(value)
                    sides.append([side, 0.0])
            attributes = {}
            for name, values in packed.items():
                attributes[name] = write(values, {2: 'VEC2', 3: 'VEC3', 4: 'VEC4'}[len(values[0])])
            attributes['TEXCOORD_1'] = write(sides, 'VEC2')
            primitive['attributes'] = attributes
            primitive['indices'] = write(np.arange(len(sides)), 'SCALAR', True)
    doc['buffers'][0]['byteLength'] = len(binary)
