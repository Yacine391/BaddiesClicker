"""Tenue de Maya (spec §4) : t-shirt, veste oversize ouverte, cargo large à poches, baskets épaisses, accessoires.

Même géométrie pour les trois looks ; seuls les accessoires changent (`look`), les couleurs viennent de la palette.
Les positions s'appuient sur `maya_body.JOINTS` (articulations après la pose au sol). Les extrémités des chaînes Skin
s'arrondissent : on les prolonge dans le vêtement voisin (t-shirt rentré dans le cargo, veste qui le recouvre).
"""

import bc_common as C
import maya_body


def _j(name, dx=0.0, dy=0.0, dz=0.0):
    x, y, z = maya_body.JOINTS[name]
    return (x + dx, y + dy, z + dz)


def build_tshirt(mats):
    pts = {
        "tuck": (_j("pelvis", dz=-0.1), (0.38, 0.32)),
        "belly": (_j("waist"), (0.39, 0.32)),
        "chest": (_j("chest"), (0.44, 0.34)),
        "top": (_j("shoulders", dz=0.04), (0.36, 0.25)),
    }
    shirt = C.skin_mesh("Tshirt", pts, [("tuck", "belly"), ("belly", "chest"), ("chest", "top")], "tuck")
    return C.set_material(shirt, mats["tshirt"])


def build_pants(mats):
    pts = {"waist": (_j("pelvis", dz=0.42), (0.46, 0.38)), "seat": (_j("pelvis", dz=-0.12), (0.5, 0.4))}
    edges = [("waist", "seat")]
    for s in ("L", "R"):
        sx = 1 if s == "L" else -1
        pts[f"hip{s}"] = (_j(f"hip{s}", dx=0.04 * sx, dz=-0.15), (0.32, 0.32))
        pts[f"knee{s}"] = (_j(f"knee{s}", dx=0.06 * sx), (0.32, 0.31))
        pts[f"hem{s}"] = (_j(f"ankle{s}", dx=0.07 * sx, dz=0.02), (0.35, 0.33))
        edges += [("seat", f"hip{s}"), (f"hip{s}", f"knee{s}"), (f"knee{s}", f"hem{s}")]
    pants = C.skin_mesh("Pants", pts, edges, "waist")
    C.set_material(pants, mats["pants"])
    parts = [pants]
    # poches cargo latérales (cuisse et mollet) posées sur la jambe, rabat en passepoil
    for s in ("L", "R"):
        sx = 1 if s == "L" else -1
        for name, joint, dz, size in (("Thigh", f"knee{s}", 0.55, (0.06, 0.2, 0.22)),
                                      ("Calf", f"ankle{s}", 0.7, (0.05, 0.17, 0.17))):
            x, y, z = _j(joint, dx=0.07 * sx, dz=dz)
            pocket = C.primitive("cube", f"Pocket{name}{s}", location=(x + 0.25 * sx, y, z), scale=size)
            C.set_material(pocket, mats["pants"])
            flap = C.primitive("cube", f"Flap{name}{s}", location=(x + 0.27 * sx, y, z + size[2]),
                               scale=(size[0] * 0.9, size[1] * 1.08, 0.03))
            C.set_material(flap, mats["piping"])
            parts += [pocket, flap]
    return C.join(parts, "Pants")


def build_jacket(mats):
    pts = {
        "hem": (_j("pelvis", dz=0.05), (0.53, 0.44)),
        "mid": (_j("chest", dz=-0.2), (0.55, 0.44)),
        "top": (_j("shoulders", dz=0.04), (0.45, 0.37)),
    }
    edges = [("hem", "mid"), ("mid", "top")]
    for s in ("L", "R"):
        sx = 1 if s == "L" else -1
        pts[f"sh{s}"] = (_j(f"shoulder{s}", dx=0.06 * sx), (0.27, 0.27))
        pts[f"el{s}"] = (_j(f"elbow{s}", dx=0.04 * sx), (0.29, 0.28))
        pts[f"cuff{s}"] = (_j(f"wrist{s}", dz=0.02), (0.22, 0.21))
        edges += [("top", f"sh{s}"), (f"sh{s}", f"el{s}"), (f"el{s}", f"cuff{s}")]
    jacket = C.skin_mesh("Jacket", pts, edges, "hem")
    C.set_material(jacket, mats["jacket"])
    chest_z, shoulder_z = _j("chest")[2], _j("shoulders")[2]
    elbow_z, hem_z = _j("elbowL")[2], _j("pelvis")[2] + 0.12

    def torso(c):
        return abs(c.x) < 0.62

    # veste ouverte : bande retirée devant pour laisser voir le t-shirt
    C.delete_faces_where(jacket, lambda c: c.y < -0.22 and abs(c.x) < 0.17 and c.z < shoulder_z - 0.02)
    # empiècements crème : empiècement du haut (épaules, haut du dos et du buste) et avant-bras
    C.assign_material_where(jacket, mats["panel"],
                            lambda c: (torso(c) and c.z > chest_z + 0.15) or (not torso(c) and c.z < elbow_z - 0.12))
    # passepoils orange : fines bandes aux limites des empiècements
    C.assign_material_where(jacket, mats["piping"],
                            lambda c: (torso(c) and abs(c.z - (chest_z + 0.15)) < 0.05)
                            or (not torso(c) and abs(c.z - (elbow_z - 0.12)) < 0.06))
    # bas de veste et poignets en denim plus net : bande « jacket » déjà par défaut
    collar = C.primitive("torus", "Collar", location=_j("neck", dz=-0.1), major_radius=0.27, minor_radius=0.08,
                         major_segments=16, minor_segments=6)
    C.set_material(collar, mats["jacket"])
    C.shade_smooth(collar, angle_deg=180)
    return C.join([jacket, collar], "Jacket")


def build_shoes(mats):
    parts = []
    for s in ("L", "R"):
        x, y, _ = _j(f"ankle{s}")
        sole = C.primitive("cube", f"Sole{s}", location=(x, y - 0.12, 0.09), scale=(0.27, 0.44, 0.09))
        C.subdivide(sole, 1)
        C.set_material(sole, mats["shoe_sole"])
        upper = C.primitive("uv_sphere", f"Upper{s}", location=(x, y - 0.1, 0.28), scale=(0.27, 0.44, 0.21),
                            segments=16, ring_count=8)
        C.set_material(upper, mats["shoe_main"])
        stripe = C.primitive("cube", f"Stripe{s}", location=(x, y - 0.06, 0.24), scale=(0.275, 0.26, 0.04))
        C.set_material(stripe, mats["shoe_accent"])
        tongue = C.primitive("cube", f"Tongue{s}", location=(x, y - 0.28, 0.42), scale=(0.12, 0.14, 0.07),
                             rotation=(0.4, 0, 0))
        C.set_material(tongue, mats["shoe_main"])
        for p in (sole, upper, tongue):
            C.shade_smooth(p, angle_deg=180)
        parts += [sole, upper, stripe, tongue]
    return C.join(parts, "Shoes")


def build_accessories(mats, look):
    parts = []
    x, y, z = _j("wristL", dz=-0.08)
    bracelet = C.primitive("torus", "Bracelet", location=(x, y, z), major_radius=0.14, minor_radius=0.04,
                           major_segments=16, minor_segments=6)
    C.set_material(bracelet, mats["bracelet"])
    parts.append(bracelet)
    hx, hy, hz = maya_body.HEAD_CENTER
    if look == "Look02":
        band = C.primitive("torus", "Headband", location=(hx, hy + 0.05, hz + 0.4), rotation=(0.35, 0, 0),
                           major_radius=0.66, minor_radius=0.07, major_segments=24, minor_segments=6)
        C.set_material(band, mats["headband"])
        x2, y2, z2 = _j("wristR", dz=-0.08)
        twin = C.primitive("torus", "Bracelet2", location=(x2, y2, z2), major_radius=0.14, minor_radius=0.04,
                           major_segments=16, minor_segments=6)
        C.set_material(twin, mats["bracelet"])
        parts += [band, twin]
    if look == "Look03":
        chain = C.primitive("torus", "Chain", location=_j("neck", dz=-0.3), rotation=(0.5, 0, 0),
                            major_radius=0.3, minor_radius=0.035, major_segments=24, minor_segments=4)
        C.set_material(chain, mats["gold"])
        parts.append(chain)
        for side in (1, -1):
            hoop = C.primitive("torus", f"Hoop{side}", location=(hx + 0.64 * side, hy - 0.08, hz - 0.3),
                               rotation=(0, 1.5708, 0), major_radius=0.11, minor_radius=0.025,
                               major_segments=6, minor_segments=4)  # hexagone : créole géométrique
            C.set_material(hoop, mats["gold"])
            parts.append(hoop)
    for p in parts:
        C.shade_smooth(p, angle_deg=180)
    return C.join(parts, "Accessories")


def build_outfit(mats, look="Look01"):
    """Construit la tenue du look sur le corps déjà construit. Renvoie la liste des objets."""
    return [build_tshirt(mats), build_pants(mats), build_jacket(mats), build_shoes(mats),
            build_accessories(mats, look)]
