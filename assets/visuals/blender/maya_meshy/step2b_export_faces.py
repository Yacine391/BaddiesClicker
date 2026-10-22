"""Exporte la texture de base et, par face : centre 3D, UV, drapeau cheveux (pour regions_v2.py)."""
import sys
import bpy, numpy as np
OUT = sys.argv[1]
bpy.ops.wm.open_mainfile(filepath=OUT + "/maya_step2.blend")
img = bpy.data.images[0]
img.filepath_raw = OUT + "/base_2048.png"; img.file_format = "PNG"; img.save()
o = bpy.data.objects["Maya"]; me = o.data; uv = me.uv_layers.active.data
hair = set(np.load(OUT + "/hair_idx.npy").tolist())
rows = []
for p in me.polygons:
    c = p.center
    uvs = [x for li in p.loop_indices for x in uv[li].uv]
    h = sum(v in hair for v in p.vertices) * 2 > len(p.vertices)
    xyz = [x for vi in p.vertices for x in me.vertices[vi].co]
    rows.append((c.x, c.y, c.z, *uvs[:6], float(h), *xyz[:9]))
np.save(OUT + "/faces.npy", np.array(rows, np.float32))
print("FACES", len(rows), "polys>3", sum(len(p.vertices) > 3 for p in me.polygons))
