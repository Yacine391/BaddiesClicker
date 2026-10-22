"""Maya v2 : carte des zones de texture. 1 veste (buste), 2 t-shirt, 3 cargo droite (x<0), 4 baskets,
5 tête/cheveux, 6 mains, 7 manches, 8 cargo gauche (x>0), 9 ventre du crop top, 10 col de la veste.
Zones calculées pixel par pixel (position 3D interpolée dans chaque triangle) pour des limites nettes."""
import os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.cluster.vq import kmeans2

OUT = sys.argv[1]; N = 1024
F = np.load(OUT + "/faces.npy")
SH, WR = np.array([0.55, 4.10]), np.array([0.966, 2.82])  # épaule, poignet après remise en pose (18°)

def seg_dist(p, a, b):
    ab = b - a; t = np.clip(np.dot(p - a, ab) / np.dot(ab, ab), 0, 1)
    return np.linalg.norm(a + ab * t - p)

def region(x, y, z, h):
    if h: return 5
    if z >= 4.42:
        return 10 if (z < 4.62 and abs(x) > 0.10) else 5
    if z < 0.60: return 4
    if abs(x) > 0.45 and seg_dist(np.array([abs(x), z]), SH, WR) < 0.24:
        return 7 if z > 2.90 else 6
    if abs(x) > 0.80 and z < 2.90: return 6
    if z >= 3.30:
        if abs(x) < 0.20 and y < -0.45:
            return 9 if z < 3.62 else 2
        return 1
    return 3 if x < 0 else 8

L = np.zeros((N, N), np.uint8)
for r in F:
    uv = r[3:9].reshape(3, 2) * [N, -N] + [0, N]  # pixels (x, y)
    P = r[10:19].reshape(3, 3)
    x0, y0 = np.floor(uv.min(0)).astype(int); x1, y1 = np.ceil(uv.max(0)).astype(int)
    xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1 + 1, N)), np.arange(max(y0, 0), min(y1 + 1, N)))
    pts = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], 1)
    a, b, c = uv
    m = np.array([b - a, c - a]).T
    if abs(np.linalg.det(m)) < 1e-9: continue
    l12 = np.linalg.solve(m, (pts - a).T).T
    bary = np.column_stack([1 - l12.sum(1), l12])
    inside = (bary >= -0.02).all(1)
    for (px, py), w in zip(pts[inside].astype(int), bary[inside]):
        L[py, px] = region(*(w @ P), r[9] > 0.5)
idx = ndimage.distance_transform_edt(L == 0, return_distances=False, return_indices=True)
L = L[idx[0], idx[1]]
np.save(OUT + "/labels.npy", L)
base = Image.open(OUT + "/base_2048.png").convert("RGB").resize((N, N), Image.LANCZOS)
base.save(OUT + "/base_1024.png")
A = np.array(base).reshape(-1, 3).astype(np.float32)
for r, name in [(1, "veste"), (7, "manches"), (2, "tshirt"), (9, "ventre"), (3, "cargo"), (4, "baskets"), (6, "mains")]:
    S = A[L.reshape(-1) == r]
    c, k = kmeans2(S[::5], 4, seed=0, minit="++")
    cnt = np.bincount(k, minlength=4)
    print(name, [(tuple(int(v) for v in c[i]), int(cnt[i])) for i in np.argsort(-cnt)])
