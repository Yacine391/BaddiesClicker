"""Textures des looks 2 et 3 : recoloration par zone (veste, t-shirt, pantalon, baskets, mains) en gardant
import os
OUT = os.environ.get("MAYA_OUT", "out")  # dossier de travail des étapes Blender
les plis et ombres (rapport de luminance au centre de la classe de couleur d'origine)."""
import numpy as np
from PIL import Image

H = lambda h: np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], np.float32)
base = np.array(Image.open(OUT + "/base_1024.png").convert("RGB"), np.float32)
L = np.load(OUT + "/labels.npy")
# classes de couleur d'origine (mesurées par k-means sur la texture)
CENTERS = {"fonce": H("#273443"), "creme": H("#EBDDC8"), "orange": H("#F4923B")}
SIGMA = 38.0

def lum(c):
    return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114

# (zone, classe) -> couleur cible ; zones : 1 veste, 2 t-shirt, 3 pantalon, 4 baskets, 6 mains
LOOKS = {
    2: {(1, "fonce"): "#F4EEE7", (1, "creme"): "#F2A65A", (1, "orange"): "#3B5B8C",
        (3, "creme"): "#3B5B8C",
        (4, "fonce"): "#F2A65A"},
    3: {(1, "fonce"): "#242036", (1, "creme"): "#3A3355", (1, "orange"): "#D7A746",
        (2, "creme"): "#F2A65A",
        (3, "creme"): "#2B2640", (3, "orange"): "#D7A746",
        (4, "fonce"): "#242036", (4, "creme"): "#3A3355", (4, "orange"): "#D7A746",
        (6, "orange"): "#D7A746"},
}

names = list(CENTERS)
C = np.stack([CENTERS[n] for n in names])
d2 = ((base[:, :, None, :] - C[None, None]) ** 2).sum(-1)
w = np.exp(-d2 / (2 * SIGMA ** 2))
keep = np.exp(-(70.0 ** 2) / (2 * SIGMA ** 2))  # poids « ne pas toucher » (peau, cheveux, gris)
total = w.sum(-1) + keep
ratio = lum(base)[..., None] / np.maximum(lum(C)[None, None, :], 1)

for look, table in LOOKS.items():
    out = base * (keep / total)[..., None]
    for k, n in enumerate(names):
        tgt = np.zeros_like(base)
        hit = np.zeros(L.shape, bool)
        for (zone, cls), hexc in table.items():
            if cls == n:
                m = L == zone
                tgt[m] = H(hexc) * np.clip(ratio[..., k][m], 0.35, 1.25)[:, None]
                hit |= m
        tgt[~hit] = base[~hit]
        out += tgt * (w[..., k] / total)[..., None]
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(OUT + f"/tex_look{look}.png")
print("ok")
