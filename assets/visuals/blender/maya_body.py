"""Corps, visage et cheveux de Maya (spec §3). Repère : face à -Y, gauche du personnage = +X, pieds à Z = 0.

Le corps est un « squelette de points » habillé par le modificateur Skin, puis lissé. La tête et le visage sont des
primitives arrondies ; la chevelure bouclée est une coiffe + des grappes de boucles (icosphères).
"""

import math
import bpy
import bc_common as C

HEAD_CENTER = (0.0, 0.0, 4.78)
HEAD_RADII = (0.6, 0.57, 0.64)

# Points du corps : (nom, position, rayons de peau (x, y))
_SKELETON = [
    ("pelvis", (0.0, 0.0, 2.75), (0.32, 0.24)),
    ("waist", (0.0, 0.0, 3.15), (0.28, 0.21)),
    ("chest", (0.0, 0.0, 3.65), (0.34, 0.23)),
    ("shoulders", (0.0, 0.0, 4.00), (0.30, 0.21)),
    ("neck", (0.0, 0.0, 4.22), (0.11, 0.11)),
]
_LIMB = [  # côté gauche (+X) ; le droit est le miroir
    ("hip", (0.24, 0.0, 2.62), (0.17, 0.17)),
    ("knee", (0.26, 0.0, 1.55), (0.15, 0.15)),
    ("ankle", (0.26, 0.0, 0.35), (0.10, 0.10)),
    ("toe", (0.26, -0.30, 0.12), (0.10, 0.08)),
    ("shoulder", (0.62, 0.0, 3.95), (0.14, 0.14)),
    ("elbow", (0.82, 0.0, 2.95), (0.11, 0.11)),
    ("wrist", (0.88, 0.0, 2.05), (0.09, 0.08)),
    ("hand", (0.90, -0.02, 1.78), (0.17, 0.15)),
]
_EDGES = [("pelvis", "waist"), ("waist", "chest"), ("chest", "shoulders"), ("shoulders", "neck")]
for side in ("L", "R"):
    _EDGES += [("pelvis", f"hip{side}"), (f"hip{side}", f"knee{side}"), (f"knee{side}", f"ankle{side}"),
               (f"ankle{side}", f"toe{side}"), ("shoulders", f"shoulder{side}"), (f"shoulder{side}", f"elbow{side}"),
               (f"elbow{side}", f"wrist{side}"), (f"wrist{side}", f"hand{side}")]

# Points utiles aux autres scripts (articulations du rig, placement des vêtements)
JOINTS = {}


def _points():
    pts = list(_SKELETON)
    for name, (x, y, z), r in _LIMB:
        pts.append((f"{name}L", (x, y, z), r))
        pts.append((f"{name}R", (-x, y, z), r))
    return pts


def build_skin_body(mats):
    pts = _points()
    index = {name: i for i, (name, _, _) in enumerate(pts)}
    JOINTS.clear()
    JOINTS.update({name: pos for name, pos, _ in pts})
    mesh = bpy.data.meshes.new("MayaBody")
    mesh.from_pydata([p for _, p, _ in pts], [(index[a], index[b]) for a, b in _EDGES], [])
    obj = bpy.data.objects.new("MayaBody", mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    for i, (name, _, (rx, ry)) in enumerate(pts):
        sv = mesh.skin_vertices[0].data[i]
        sv.radius = (rx, ry)
        sv.use_root = name == "pelvis"
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 1
    C.apply_modifiers(obj)
    # poings : les extrémités du Skin sont trop fines, on ajoute une sphère par main
    fists = [obj]
    for side in ("L", "R"):
        x, y, z = JOINTS[f"hand{side}"]
        fists.append(C.primitive("uv_sphere", f"Fist{side}", location=(x, y, z), scale=(0.19, 0.19, 0.2),
                                 segments=12, ring_count=8))
    obj = C.join(fists, "MayaBody")
    C.set_material(obj, mats["skin"])
    return C.shade_smooth(obj, angle_deg=180)


def build_head(mats):
    head = C.primitive("uv_sphere", "MayaHead", location=HEAD_CENTER, scale=HEAD_RADII, segments=24, ring_count=16)
    C.set_material(head, mats["skin"])
    C.shade_smooth(head)
    parts = [head]
    hx, hy, hz = HEAD_CENTER

    def on_face(x, dz, inset=0.0):
        # point de la surface avant de la tête à (x, z = centre + dz)
        rx, ry, rz = HEAD_RADII
        k = max(0.0, 1 - (x / rx) ** 2 - (dz / rz) ** 2)
        return (x, hy - ry * math.sqrt(k) + inset, hz + dz)

    for side in (1, -1):
        eye = C.primitive("uv_sphere", f"Eye{side}", location=on_face(0.21 * side, 0.0, 0.015),
                          scale=(0.13, 0.045, 0.16), segments=12, ring_count=8)
        C.set_material(eye, mats["eye"])
        glint = C.primitive("uv_sphere", f"Glint{side}", location=on_face(0.21 * side + 0.045 * side, 0.06, -0.025),
                            scale=(0.03, 0.015, 0.03), segments=8, ring_count=6)
        C.set_material(glint, mats["eye_white"])
        lid = C.primitive("cube", f"Lid{side}", location=on_face(0.21 * side, 0.15, -0.005),
                          scale=(0.14, 0.02, 0.02), rotation=(0, 0.12 * side, 0))
        lash = C.primitive("cube", f"Lash{side}", location=on_face(0.35 * side, 0.15, 0.0),
                           scale=(0.05, 0.015, 0.016), rotation=(0, -0.6 * side, 0))
        C.set_material(lash, mats["brow"])
        parts.append(lash)
        C.set_material(lid, mats["brow"])
        brow = C.primitive("cube", f"Brow{side}", location=on_face(0.22 * side, 0.27, -0.01),
                           scale=(0.11, 0.02, 0.024), rotation=(0, 0.14 * side, 0))
        C.set_material(brow, mats["brow"])
        parts += [eye, glint, lid, brow]
    nose = C.primitive("uv_sphere", "Nose", location=on_face(0.0, -0.12, -0.01), scale=(0.05, 0.04, 0.05),
                       segments=10, ring_count=6)
    C.set_material(nose, mats["skin"])
    mouth = C.primitive("torus", "Mouth", location=on_face(0.0, -0.26, 0.02), rotation=(1.5708, 0, 0),
                        major_radius=0.1, minor_radius=0.022, major_segments=16, minor_segments=4)
    C.delete_faces_where(mouth, lambda c: c.z > HEAD_CENTER[2] - 0.27)  # garde l'arc du bas : sourire
    C.set_material(mouth, mats["lip"])
    parts += [nose, mouth]
    for p in parts[1:]:
        C.shade_smooth(p)
    return C.join(parts, "MayaHead")


def build_hair(mats, target_tris=2200):
    """Chevelure bouclée : boules de métaball fusionnées (masse continue et bosselée), converties en maillage."""
    hx, hy, hz = HEAD_CENTER
    mb = bpy.data.metaballs.new("MayaHairMB")
    mb.resolution = 0.07
    mb.render_resolution = 0.07
    mb.threshold = 0.6
    obj = bpy.data.objects.new("MayaHair", mb)
    bpy.context.scene.collection.objects.link(obj)

    def ball(x, y, z, r):
        e = mb.elements.new(type="BALL")
        e.co = (x, y, z)
        e.radius = r

    shell = (0.8, 0.72, 0.74)
    center = (hx, hy + 0.03, hz + 0.08)
    rings = [(-0.8, 11), (-0.45, 14), (-0.1, 16), (0.3, 15), (0.7, 12), (1.1, 8), (1.45, 3)]
    n = 0
    for elev, count in rings:
        for k in range(count):
            az = 2 * math.pi * k / count + (0.13 if count % 2 else 0)
            dx, dy = math.cos(az - math.pi / 2), math.sin(az - math.pi / 2)  # az = 0 : face (-Y)
            front = math.degrees(abs(math.atan2(dx, -dy)))
            if front < 64 and elev < 0.32:
                continue  # le visage reste dégagé
            ce = math.cos(min(elev, math.pi / 2))
            vary = ((k * 7 + n * 3) % 5) / 4
            ball(center[0] + shell[0] * ce * dx, center[1] + shell[1] * ce * dy,
                 center[2] + shell[2] * math.sin(elev), 0.25 + 0.1 * vary)
            n += 1
    for i, x in enumerate((-0.4, -0.2, 0.0, 0.2, 0.4)):  # frange bouclée
        ball(x, hy - 0.44 + 0.08 * abs(x), hz + 0.44 + 0.05 * (i % 2), 0.16)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    hair = bpy.context.active_object
    hair.name = "MayaHair"
    tris = sum(len(p.vertices) - 2 for p in hair.data.polygons)
    if tris > target_tris:
        dec = hair.modifiers.new("Decimate", "DECIMATE")
        dec.ratio = target_tris / tris
        C.apply_modifiers(hair)
    C.set_material(hair, mats["hair"])
    return C.shade_smooth(hair, angle_deg=180)


def build_body(mats):
    """Construit Maya sans vêtements de dessus. Renvoie [corps, tête, cheveux], pieds posés à Z = 0."""
    objs = [build_skin_body(mats), build_head(mats), build_hair(mats)]
    floor_to_zero(objs)
    return objs


def floor_to_zero(objs):
    """Décale tous les objets pour que le point le plus bas soit à Z = 0 (le Skin rétrécit les pointes)."""
    low = min(C.world_bounds(o)[4] for o in objs if o.type == "MESH")
    for o in objs:
        o.location.z -= low
    bpy.context.view_layer.update()
    for name, (x, y, z) in list(JOINTS.items()):
        JOINTS[name] = (x, y, z - low)
    return low
