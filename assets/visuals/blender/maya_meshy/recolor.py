"""Maya v2 : textures des 3 looks. Crop top (ventre en peau + nombril) sur les 3 ; looks 2 (image 4) et 3 (image 3)
par recoloration de zone en gardant plis et ombres."""
import sys
import numpy as np
from PIL import Image

OUT = sys.argv[1]
H = lambda h: np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.float32)
base = np.array(Image.open(OUT + "/base_1024.png").convert("RGB"), np.float32)
L = np.load(OUT + "/labels.npy")
F = np.load(OUT + "/faces.npy")
N = base.shape[0]
CENTERS = {"denim": np.array([58, 82, 109.]), "marine": np.array([40, 55, 70.]),
           "creme": np.array([242, 225, 198.]), "orange": np.array([235, 122, 35.]),
           "peau": np.array([197, 134, 91.])}
SKIN = CENTERS["peau"]
SIGMA = 34.0
lum = lambda c: c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114

# --- crop top : zone 9 (ventre) en peau, plis atténués ; nombril ---
crop = L == 9
r = np.clip(lum(base) / lum(CENTERS["creme"]), 0.8, 1.08)
base[crop] = SKIN * r[crop][:, None]
z9 = [f for f in F if 3.30 <= f[2] < 3.62 and abs(f[0]) < 0.2 and f[1] < -0.45]
navel = min(z9, key=lambda f: abs(f[0]) + abs(f[2] - 3.44))
u, v = navel[3:9].reshape(3, 2).mean(0)
px, py = int(u * N), int((1 - v) * N)
yy, xx = np.mgrid[-4:5, -4:5]
for dy, dx, w in zip(yy.ravel(), xx.ravel(), np.exp(-((xx / 1.6) ** 2 + (yy / 2.6) ** 2)).ravel()):
    if 0 <= py + dy < N and 0 <= px + dx < N and L[py + dy, px + dx] == 9:
        base[py + dy, px + dx] = base[py + dy, px + dx] * (1 - 0.45 * w)
print("NOMBRIL uv", round(float(u), 3), round(float(v), 3))
Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).save(OUT + "/tex_look1.png")

DARK = ("denim", "marine")
LOOKS = {  # (zone, classe) -> couleur ; zones : 1 veste, 2 t-shirt, 3/8 cargo D/G, 4 baskets, 6 mains, 7 manches
    2: {**{(1, c): "#F4EEE7" for c in DARK}, (7, "creme"): "#F2A65A", (8, "creme"): "#2E3566"},
    3: {**{(z, c): "#242036" for z in (1, 7) for c in DARK}, (1, "creme"): "#2E2944", (7, "creme"): "#2E2944", (10, "creme"): "#2E2944",
        **{(10, c): "#242036" for c in DARK},
        (1, "orange"): "#D7A746", (7, "orange"): "#D7A746", (2, "creme"): "#F2A65A",
        (3, "creme"): "#2B2640", (8, "creme"): "#2B2640", (3, "orange"): "#D7A746", (8, "orange"): "#D7A746",
        **{(4, c): "#242036" for c in DARK}, (6, "orange"): "#D7A746"},
}
names = list(CENTERS)
C = np.stack([CENTERS[n] for n in names])
d2 = ((base[:, :, None, :] - C[None, None]) ** 2).sum(-1)
w = np.exp(-d2 / (2 * SIGMA ** 2))
keep = np.exp(-(64.0 ** 2) / (2 * SIGMA ** 2))
total = w.sum(-1) + keep
ratio = lum(base)[..., None] / np.maximum(lum(C)[None, None, :], 1)
for look, table in LOOKS.items():
    out = base * (keep / total)[..., None]
    for k, n in enumerate(names):
        tgt = base.copy()
        for (zone, cls), hexc in table.items():
            if cls == n:
                m = L == zone
                tgt[m] = H(hexc) * np.clip(ratio[..., k][m], 0.45, 1.12)[:, None]
        out += tgt * (w[..., k] / total)[..., None]
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(OUT + f"/tex_look{look}.png")
print("ok")
