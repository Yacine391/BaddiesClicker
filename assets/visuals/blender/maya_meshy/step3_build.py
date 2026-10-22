"""Maya v2 : pour un look — texture du look, accessoires, découpe en 15 parties R15, export FBX, rendus.

Usage : python3 step3_build_v2.py <look 1|2|3> <out_dir>
Accessoires : look 2 = bandeau orange, créoles losanges et fine chaîne dorées ; look 3 = grosse chaîne et créoles
losanges dorées.
"""

import math
import os
import sys

import bpy  # noqa: I001 (bpy avant bmesh)
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
import bc_render  # noqa: E402
import r15_armature as r15  # noqa: E402

LOOK, OUT = int(sys.argv[1]), sys.argv[2]
NAME = f"B01_Maya_Look{LOOK:02d}"
ORANGE, GOLD = "#F2A65A", "#D7A746"
MAX_TRIS = 10000

bpy.ops.wm.open_mainfile(filepath=f"{OUT}/maya_step2.blend")
body = bpy.data.objects["Maya"]
rig = bpy.data.objects["Maya_R15"]
me = body.data
verts = [v.co.copy() for v in me.vertices]
uvl = me.uv_layers.active.data

# --- deux pastilles de couleur sous les semelles (jamais visibles) : A pied gauche, B pied droit ---
soles = {"A": (None, 0.0), "B": (None, 0.0)}
for p in me.polygons:
    if p.normal.z < -0.85 and p.center.z < 0.06:
        key = "A" if p.center.x > 0 else "B"
        uv = [uvl[li].uv.copy() for li in p.loop_indices]
        area = abs((uv[1] - uv[0]).cross(uv[2] - uv[0])) / 2
        if area > soles[key][1]:
            soles[key] = (sum(uv, Vector((0, 0))) / len(uv), area)
patch = {k: v[0] for k, v in soles.items()}

tex = np.array(Image.open(f"{OUT}/tex_look{LOOK}.png").convert("RGB"))
paint = {2: {"A": ORANGE, "B": GOLD}, 3: {"B": GOLD}}.get(LOOK, {})
n = tex.shape[0]
for key, h in paint.items():
    px, py = int(patch[key].x * n), int((1 - patch[key].y) * n)
    tex[max(py - 3, 0):py + 4, max(px - 3, 0):px + 4] = [int(h[i:i + 2], 16) for i in (1, 3, 5)]
tex_path = f"{OUT}/{NAME}.png"
Image.fromarray(tex).save(tex_path)
img = bpy.data.images.load(tex_path)
for node in body.active_material.node_tree.nodes:
    if node.type == "TEX_IMAGE":
        node.image = img


def front_y(x, z):
    ok, loc, _, _ = body.ray_cast(Vector((x, -10, z)), Vector((0, 1, 0)))
    return loc.y if ok else 0.0


def slice_box(z, dz=0.05):
    pts = [v for v in verts if abs(v.z - z) < dz]
    xs, ys = [p.x for p in pts], [p.y for p in pts]
    return min(xs), max(xs), min(ys), max(ys)


def ring(name, center, rx, ry, minor, major_seg, minor_seg, rot, bone, uv_key, arc=None):
    """Anneau (tore) en ellipse, ou arc ouvert (`arc` = angles de début et de fin) ; poids 100 % sur `bone` ;
    UV sur la pastille `uv_key`."""
    m = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    count = major_seg + 1 if arc else major_seg
    for i in range(count):
        a = arc[0] + (arc[1] - arc[0]) * i / major_seg if arc else 2 * math.pi * i / major_seg
        c = Vector((math.cos(a), math.sin(a), 0))
        rings.append([
            bm.verts.new(Vector((c.x * rx, c.y * ry, 0)) + c * (minor * math.cos(b)) + Vector((0, 0, minor * math.sin(b))))
            for b in (2 * math.pi * j / minor_seg for j in range(minor_seg))
        ])
    for i in range(major_seg):
        a, b = rings[i], rings[(i + 1) % count]
        for j in range(minor_seg):
            k = (j + 1) % minor_seg
            bm.faces.new((a[j], b[j], b[k], a[k]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(m)
    bm.free()
    o = bpy.data.objects.new(name, m)
    bpy.context.scene.collection.objects.link(o)
    o.matrix_world = Matrix.Translation(center) @ rot
    m.materials.append(body.active_material)
    uv = m.uv_layers.new(name=me.uv_layers.active.name)
    for d in uv.data:
        d.uv = patch[uv_key]
    o.vertex_groups.new(name=bone).add(list(range(len(m.vertices))), 1.0, "REPLACE")
    return o


def necklace(minor, uv_key):
    tilt, cy, cz = math.radians(30), -0.30, 4.40
    ry = (cy - (front_y(0.0, 4.24) - 0.03)) / math.cos(tilt)
    return ring("Chaine", Vector((0, cy, cz)), 0.21, ry, minor, 24, 4, Matrix.Rotation(tilt, 4, "X"), "UpperTorso", uv_key)


def earrings(uv_key):
    out = []
    for side, x in (("G", 0.27), ("D", -0.27)):
        center = Vector((x, front_y(x, 4.47) - 0.03, 4.47))
        rot = Matrix.Rotation(math.radians(90), 4, "X")  # losange dans le plan de face
        out.append(ring(f"Creole{side}", center, 0.065, 0.10, 0.015, 4, 4, rot, "Head", uv_key))
    return out


extras = []
if LOOK == 2:
    x0, x1, _, _ = slice_box(4.85)  # bandeau en arc sur le crâne, d'une oreille à l'autre, un peu incliné vers l'arrière
    extras.append(ring("Bandeau", Vector(((x0 + x1) / 2, -0.35, 4.85)), (x1 - x0) / 2 - 0.05, 0.63, 0.055, 20, 6,
                       Matrix.Rotation(math.radians(75), 4, "X"), "Head", "A", arc=(0.0, math.pi)))
    extras += earrings("B")
    extras.append(necklace(0.018, "B"))
if LOOK == 3:
    extras += earrings("B")
    extras.append(necklace(0.036, "B"))

for o in extras:
    for b in r15.PARTS:
        if o.vertex_groups.get(b) is None:
            o.vertex_groups.new(name=b)
if extras:
    for o in bpy.context.scene.objects:
        o.select_set(o in extras or o == body)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()

tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
assert tris <= MAX_TRIS, f"{tris} triangles > {MAX_TRIS}"
parts = r15.split_parts(body)
empty = [k for k, o in parts.items() if len(o.data.polygons) == 0]
assert not empty, f"parties vides : {empty}"
print("LOOK", LOOK, "TRIS", tris, "PARTS", {k: len(o.data.polygons) for k, o in parts.items()})

sc = bpy.context.scene
sc.unit_settings.system = "METRIC"
sc.unit_settings.scale_length = 0.01
for o in sc.objects:
    o.select_set(o == rig or o.name in parts)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(
    filepath=f"{OUT}/{NAME}.fbx", use_selection=True, object_types={"ARMATURE", "MESH"},
    apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y",
    add_leaf_bones=False, primary_bone_axis="Y", secondary_bone_axis="X", armature_nodetype="NULL",
    use_armature_deform_only=False, bake_anim=False, path_mode="COPY", embed_textures=True,
    mesh_smooth_type="FACE",
)
sc.unit_settings.scale_length = 1.0
bc_render.setup()
for view in ("face", "profil", "dos"):
    bc_render.shoot(f"{OUT}/{NAME}_{view}.png", view)
