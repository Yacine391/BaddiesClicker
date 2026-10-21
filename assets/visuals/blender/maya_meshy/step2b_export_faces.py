import sys
OUT = sys.argv[1]  # usage : python3 step2b_export_faces.py OUT
import bpy, numpy as np
bpy.ops.wm.open_mainfile(filepath=OUT + "/maya_step2.blend")
img = bpy.data.images[0]
img.filepath_raw = OUT + "/base_2048.png"; img.file_format = "PNG"; img.save()
o = bpy.data.objects["Maya"]
me = o.data
uv = me.uv_layers.active.data
rows = []
for p in me.polygons:
    c = sum((me.vertices[v].co for v in p.vertices), p.center*0) / len(p.vertices)
    uvs = [tuple(uv[li].uv) for li in p.loop_indices]
    rows.append((c.x, c.y, c.z, *[x for t in uvs for x in t]))
np.save(OUT + "/faces.npy", np.array(rows, dtype=np.float32))
print("FACES", len(rows), "UV layers", len(me.uv_layers))
