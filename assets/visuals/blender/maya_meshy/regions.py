"""Carte des zones de la texture (veste, t-shirt, pantalon, baskets, reste) d'après la position 3D des faces."""
import os
OUT = os.environ.get("MAYA_OUT", "out")  # dossier de travail des étapes Blender
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

N = 1024
F = np.load(OUT + "/faces.npy")
SH, WR = np.array([0.62, 4.28]), np.array([0.90, 2.98])  # épaule, poignet (bras à 15°)

def seg_dist(p, a, b):
    ab = b - a; t = np.clip(np.dot(p - a, ab) / np.dot(ab, ab), 0, 1)
    return np.linalg.norm(a + ab * t - p)

def region(x, y, z):
    if z >= 4.52: return 5
    if z < 0.45: return 4
    p = np.array([abs(x), z])
    if seg_dist(p, SH, WR) < 0.32 and abs(x) > 0.45:
        return 1 if z > 3.05 else 6          # manche, sinon main / bracelet
    if z < 2.95 and abs(x) > 0.8: return 6   # mains
    if z >= 3.30:
        return 2 if (abs(x) < 0.22 and y < 0.05) else 1
    return 3

lab = Image.new("L", (N, N), 0); d = ImageDraw.Draw(lab)
for row in F:
    x, y, z = row[:3]; uv = row[3:].reshape(-1, 2)
    d.polygon([(u * N, (1 - v) * N) for u, v in uv], fill=int(region(x, y, z)))
L = np.array(lab)
idx = ndimage.distance_transform_edt(L == 0, return_distances=False, return_indices=True)
L = L[idx[0], idx[1]]
np.save(OUT + "/labels.npy", L)
pal = np.array([[0,0,0],[59,91,140],[255,255,255],[230,200,120],[242,166,90],[120,120,120],[255,200,170]], np.uint8)
Image.fromarray(pal[L]).save(OUT + "/labels.png")
base = Image.open(OUT + "/base_2048.png").convert("RGB").resize((N, N), Image.LANCZOS)
base.save(OUT + "/base_1024.png")
A = np.array(base).reshape(-1, 3).astype(np.float32)
from scipy.cluster.vq import kmeans2
for r, name in [(1, "veste"), (2, "tshirt"), (3, "pantalon"), (4, "baskets")]:
    S = A[L.reshape(-1) == r]
    np.random.seed(0)
    c, k = kmeans2(S[::7], 4, seed=0, minit="++")
    cnt = np.bincount(k, minlength=4)
    print(name, [(tuple(int(v) for v in c[i]), int(cnt[i])) for i in np.argsort(-cnt)])
