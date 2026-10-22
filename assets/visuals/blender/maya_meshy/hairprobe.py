"""Classe les sommets 'cheveux' (texture très sombre) et affiche les coupes des autres sommets."""
import bpy, sys, numpy as np
OUT = sys.argv[1]
bpy.ops.wm.open_mainfile(filepath=OUT + "/maya_step1.blend")
o = bpy.data.objects["Maya"]; me = o.data
img = bpy.data.images[0]; W, H = img.size
px = np.array(img.pixels[:], np.float32).reshape(H, W, 4)[..., :3]
uv = me.uv_layers.active.data
acc = np.zeros((len(me.vertices), 3)); n = np.zeros(len(me.vertices))
for p in me.polygons:
    for li in p.loop_indices:
        u, v = uv[li].uv
        acc[me.loops[li].vertex_index] += px[min(int(v * H), H - 1), min(int(u * W), W - 1)]
        n[me.loops[li].vertex_index] += 1
col = acc / np.maximum(n, 1)[:, None]
lum = col @ np.array([0.299, 0.587, 0.114])
co = np.array([v.co[:] for v in me.vertices])
hair = (lum < 0.09) & (co[:, 2] > 2.6)
np.save(OUT + "/hair.npy", hair)
print("HAIR", int(hair.sum()), "/", len(hair), "lum min", float(lum.min()))
for z in np.arange(2.6, 5.5, 0.1):
    m = (~hair) & (abs(co[:, 2] - z) < 0.05)
    xs = np.sort(co[m, 0]); cl = []
    for x in xs:
        if cl and x - cl[-1][1] < 0.08: cl[-1][1] = x
        else: cl.append([x, x])
    hm = hair & (abs(co[:, 2] - z) < 0.05)
    hy = f"hair y[{co[hm,1].min():+.2f},{co[hm,1].max():+.2f}]" if hm.any() else ""
    by = f"body y[{co[m,1].min():+.2f},{co[m,1].max():+.2f}]" if m.any() else ""
    print(f"{z:4.2f}", " ".join(f"[{a:+.2f},{b:+.2f}]" for a, b in cl), "|", by, hy)
