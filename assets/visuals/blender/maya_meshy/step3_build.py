"""Étape 3 : pour un look — texture du look, accessoires, découpe en 15 parties R15, export FBX, rendus.

Usage : python3 step3_build.py <look 1|2|3> <out_dir>
"""

import math
import sys

import bpy  # noqa: I001 (bpy avant bmesh)
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from PIL import Image

sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.dirname(__import__("os").path.abspath(__file__))))
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import bc_render  # noqa: E402
import r15_armature as r15  # noqa: E402

LOOK, OUT = int(sys.argv[1]), sys.argv[2]
NAME = f"B01_Maya_Look{LOOK:02d}"
ACCENT = {2: "#F2A65A", 3: "#D7A746"}  # couleur des accessoires (bandeau orange ; chaîne et créoles dorées)
MAX_TRIS = 10000

bpy.ops.wm.open_mainfile(filepath=f"{OUT}/maya_step2.blend")
body = bpy.data.objects["Maya"]
rig = bpy.data.objects["Maya_R15"]
me = body.data
mw = body.matrix_world
verts = [mw @ v.co for v in me.vertices]

# --- pastille de couleur pour les accessoires : sous la semelle (jamais visible) ---
uvl = me.uv_layers.active.data
best, best_area = None, 0.0
for p in me.polygons:
    n = (mw.to_3x3() @ p.normal).normalized()
    if n.z < -0.85 and (mw @ p.center).z < 0.06:
        uv = [uvl[li].uv.copy() for li in p.loop_indices]
        area = abs((uv[1] - uv[0]).cross(uv[2] - uv[0])) / 2
        if area > best_area:
            best, best_area = sum(uv, Vector((0, 0))) / len(uv), area
patch_uv = best

tex_src = f"{OUT}/base_1024.png" if LOOK == 1 else f"{OUT}/tex_look{LOOK}.png"
tex = np.array(Image.open(tex_src).convert("RGB"))
if LOOK in ACCENT:
    h = ACCENT[LOOK]
    col = [int(h[i:i + 2], 16) for i in (1, 3, 5)]
    n = tex.shape[0]
    px, py = int(patch_uv.x * n), int((1 - patch_uv.y) * n)
    tex[max(py - 3, 0):py + 4, max(px - 3, 0):px + 4] = col
tex_path = f"{OUT}/{NAME}.png"
Image.fromarray(tex).save(tex_path)
img = bpy.data.images.load(tex_path)
for node in body.active_material.node_tree.nodes:
    if node.type == "TEX_IMAGE":
        node.image = img


def front_y(x, z):
    """Profondeur de la surface vue de face (rayon tiré depuis -Y)."""
    ok, loc, _, _ = body.ray_cast(Vector((x, -10, z)), Vector((0, 1, 0)))
    return loc.y if ok else 0.0


def slice_box(z, dz=0.05, xmax=None):
    pts = [v for v in verts if abs(v.z - z) < dz and (xmax is None or abs(v.x) < xmax)]
    xs, ys = [p.x for p in pts], [p.y for p in pts]
    return min(xs), max(xs), min(ys), max(ys)


def ring(name, center, rx, ry, minor, major_seg, minor_seg, tilt_x=0.0, rot=None, bone="Head"):
    """Anneau (tore) déformé en ellipse, poids 100 % sur `bone`, UV sur la pastille de couleur."""
    m = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for i in range(major_seg):
        a = 2 * math.pi * i / major_seg
        c = Vector((math.cos(a), math.sin(a), 0))
        loop = []
        for j in range(minor_seg):
            b = 2 * math.pi * j / minor_seg
            off = c * (minor * math.cos(b)) + Vector((0, 0, minor * math.sin(b)))
            p = Vector((c.x * rx, c.y * ry, 0)) + off
            loop.append(bm.verts.new(p))
        rings.append(loop)
    for i in range(major_seg):
        a, b = rings[i], rings[(i + 1) % major_seg]
        for j in range(minor_seg):
            k = (j + 1) % minor_seg
            bm.faces.new((a[j], b[j], b[k], a[k]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(m)
    bm.free()
    o = bpy.data.objects.new(name, m)
    bpy.context.scene.collection.objects.link(o)
    o.matrix_world = Matrix.Translation(center) @ (rot or Matrix.Rotation(tilt_x, 4, "X"))
    m.materials.append(body.active_material)
    uv = m.uv_layers.new(name=me.uv_layers.active.name)
    for d in uv.data:
        d.uv = patch_uv
    g = o.vertex_groups.new(name=bone)
    g.add(list(range(len(m.vertices))), 1.0, "REPLACE")
    return o


extras = []
if LOOK == 2:  # bandeau orange sur les cheveux, plus bas devant
    x0, x1, y0, y1 = slice_box(5.22)
    extras.append(ring("Bandeau", Vector(((x0 + x1) / 2, (y0 + y1) / 2, 5.22)), (x1 - x0) / 2 - 0.02,
                       (y1 - y0) / 2 - 0.02, 0.05, 28, 6, tilt_x=math.radians(10)))
if LOOK == 3:  # chaîne dorée autour du cou, créoles géométriques (hexagones) sous les cheveux
    tilt, cy, cz = math.radians(25), 0.05, 4.40
    front = front_y(0.0, 4.2)
    ry = (cy - (front - 0.03)) / math.cos(tilt)
    extras.append(ring("Chaine", Vector((0, cy, cz)), 0.24, ry, 0.038, 24, 4, tilt_x=tilt, bone="UpperTorso"))
    print("CHAINE devant z", round(cz - ry * math.sin(tilt), 2), "y", round(cy - ry * math.cos(tilt), 2))
    for side, x in (("G", 0.40), ("D", -0.40)):
        y = front_y(x, 4.56) + 0.05
        extras.append(ring(f"Creole{side}", Vector((x, y, 4.56)), 0.07, 0.07, 0.016, 6, 4,
                           rot=Matrix.Rotation(math.radians(90), 4, "X")))

for o in extras:  # fusion dans le corps (les groupes de sommets fusionnent par nom)
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
empty = [n for n, o in parts.items() if len(o.data.polygons) == 0]
assert not empty, f"parties vides : {empty}"
print("LOOK", LOOK, "TRIS", tris, "PARTS", {n: len(o.data.polygons) for n, o in parts.items()})

# --- export FBX (1 unité Blender = 1 stud ; échelle 0,01 comme le gabarit Roblox) ---
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
