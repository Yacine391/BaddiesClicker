"""Vérifications de la chaîne Maya (exécutées dans Blender via le MCP).

Chaque fonction lève AssertionError avec un message en français, ou renvoie un petit résumé.
"""

import bpy

R15_PARTS = [
    "Head", "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
]
MAX_TRIS = 10000


def check_palette():
    import palette
    p = palette.PALETTES
    assert set(p) == {"Look01", "Look02", "Look03"}, f"looks attendus Look01..03, reçu {sorted(p)}"
    keys = set(p["Look01"])
    for look, colors in p.items():
        assert set(colors) == keys, f"{look} n'a pas les mêmes matériaux que Look01"
    # valeurs fixées par la spec §4
    assert p["Look01"]["jacket"] == "#3B5B8C", "Look01 : veste denim #3B5B8C"
    assert p["Look01"]["panel"] == "#F4EEE7", "Look01 : empiècements crème"
    assert p["Look01"]["piping"] == "#F2A65A", "Look01 : passepoils orange"
    assert p["Look01"]["pants"] == "#F4EEE7", "Look01 : cargo crème"
    assert p["Look02"]["jacket"] == "#F4EEE7", "Look02 : veste crème"
    assert p["Look02"]["panel"] == "#F2A65A", "Look02 : empiècements orange"
    assert p["Look02"]["pants"] == "#3B5B8C", "Look02 : cargo denim"
    assert p["Look03"]["jacket"] == "#242036", "Look03 : veste nuit"
    assert p["Look03"]["piping"] == "#D7A746", "Look03 : passepoils or"
    assert p["Look03"]["tshirt"] == "#F2A65A", "Look03 : t-shirt orange"
    assert p["Look03"]["pants"] == "#242036", "Look03 : cargo nuit"
    return {"looks": 3, "materials": len(keys)}


def tri_count(objs):
    deps = bpy.context.evaluated_depsgraph_get()
    total = 0
    for o in objs:
        if o.type != "MESH":
            continue
        mesh = o.evaluated_get(deps).to_mesh()
        total += sum(len(poly.vertices) - 2 for poly in mesh.polygons)
        o.evaluated_get(deps).to_mesh_clear()
    return total


def _bounds(objs):
    import mathutils
    xs, ys, zs = [], [], []
    deps = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        if o.type != "MESH":
            continue
        ev = o.evaluated_get(deps)
        for corner in ev.bound_box:
            w = o.matrix_world @ mathutils.Vector(corner)
            xs.append(w.x); ys.append(w.y); zs.append(w.z)
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def check_body(objs, with_shoes=False):
    x0, x1, _, _, z0, z1 = _bounds(objs)
    height = z1 - z0
    assert (5.2 <= height <= 5.8) if with_shoes else (5.0 <= height <= 5.8), f"hauteur {height:.2f} hors limites"
    assert abs(z0) <= 0.05, f"les pieds doivent être à Z = 0 (bas = {z0:.3f})"
    assert abs(x0 + x1) <= 0.05, f"corps non symétrique en X ({x0:.2f}, {x1:.2f})"
    tris = tri_count(objs)
    assert tris <= 5000, f"corps trop lourd : {tris} triangles (max 5000)"
    return {"height": round(height, 2), "tris": tris}


def check_outfit(objs, look):
    import palette
    tris = tri_count(objs)
    assert tris <= MAX_TRIS, f"{look} trop lourd : {tris} triangles (max {MAX_TRIS})"
    _, _, _, _, z0, z1 = _bounds(objs)
    assert z0 >= -0.05, f"un objet passe sous le sol (Z = {z0:.3f})"
    assert 5.2 <= z1 - z0 <= 5.8, f"hauteur totale {z1 - z0:.2f} hors 5,5 ± 0,3"
    used = {m.name for o in objs if o.type == "MESH" for m in o.data.materials if m}
    missing = [k for k in ("skin", "hair", "tshirt", "jacket", "panel", "piping", "pants", "shoe_main", "shoe_sole")
               if f"M_{k}" not in used]
    assert not missing, f"matériaux absents : {missing}"
    return {"tris": tris, "height": round(z1 - z0, 2)}


def check_rig(arm, parts):
    names = {b.name for b in arm.data.bones}
    expected = {"Root", "HumanoidRootNode", *R15_PARTS}
    assert names == expected, f"os inattendus : en trop {sorted(names - expected)}, manquants {sorted(expected - names)}"
    assert set(parts) == set(R15_PARTS), f"parties : manquantes {sorted(set(R15_PARTS) - set(parts))}"
    for name, obj in parts.items():
        groups = {g.index: g.name for g in obj.vertex_groups}
        for v in obj.data.vertices:
            total = sum(g.weight for g in v.groups if groups.get(g.group) in expected)
            assert abs(total - 1.0) <= 0.01, f"{name} : sommet {v.index} poids total {total:.3f}"
        if name == "Head":
            for v in obj.data.vertices:
                head = sum(g.weight for g in v.groups if groups.get(g.group) == "Head")
                assert head >= 0.99, f"Head : sommet {v.index} pas lié à 100 % à l'os Head"
    return {"bones": len(names), "parts": len(parts)}
