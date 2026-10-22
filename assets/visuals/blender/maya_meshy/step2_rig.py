"""Maya v2 (cheveux longs) : cheveux rapprochés du dos, bras ramenés, poids par chaleur, cheveux rigides sur la tête,
squelette R15 vertical, rendus de contrôle.

Usage : python3 step2_rig_v2.py <out_dir>   (après step1_import.py ; hair.npy produit par hairprobe.py)
"""

import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
import bc_render  # noqa: E402
import r15_armature as r15  # noqa: E402

OUT = sys.argv[1]
ARM_ANGLE = 18  # degrés entre le bras et la verticale après la remise en pose
HEAD_FROM = 4.42  # au-dessus du menton : 100 % Head
HAIR_BACK_Y = 0.0  # dos du buste (vue de profil) ; les cheveux derrière sont rapprochés
HAIR_SQUEEZE = 0.45

bpy.ops.wm.open_mainfile(filepath=f"{OUT}/maya_step1.blend")
body = bpy.data.objects["Maya"]
hair = np.load(f"{OUT}/hair.npy")

# 1) cheveux rapprochés du dos (le haut de la tête garde sa forme)
for v in body.data.vertices:
    if v.co.y > HAIR_BACK_Y + 0.12 and v.co.z > 2.95:
        hair[v.index] = True  # loin derrière le dos : forcément des cheveux (mèches claires comprises)
    if hair[v.index] and v.co.y > HAIR_BACK_Y:
        t = min(max((v.co.z - 4.6) / 0.6, 0.0), 1.0)  # 0 sous 4,6 ; 1 au-dessus de 5,2
        f = HAIR_SQUEEZE + (1 - HAIR_SQUEEZE) * t
        v.co.y = HAIR_BACK_Y + (v.co.y - HAIR_BACK_Y) * f
body.data.update()

# coutures de texture soudées (sommets doublés) ; le masque cheveux suit les sommets fusionnés
bm = bmesh.new()
bm.from_mesh(body.data)
layer = bm.verts.layers.int.new("hair")
bm.verts.ensure_lookup_table()
for v in bm.verts:
    v[layer] = int(hair[v.index])
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
bm.verts.ensure_lookup_table()
hair_idx = {v.index for v in bm.verts if v[layer]}
bm.verts.layers.int.remove(layer)
bm.to_mesh(body.data)
bm.free()
print("SOMMETS", len(body.data.vertices), "CHEVEUX", len(hair_idx))

# articulations (x, y, z) mesurées sur les vues de face et de profil ; gauche du personnage = +X, face vers -Y
C = {"pelvis": (0, -0.22, 3.00), "waist": (0, -0.30, 3.35), "neck": (0, -0.30, 4.35), "headtop": (0, -0.35, 5.50)}
L = {
    "shoulder": (0.55, -0.20, 4.10), "elbow": (0.83, -0.17, 3.50), "wrist": (1.05, -0.15, 2.85),
    "hand": (1.18, -0.15, 2.35), "hip": (0.32, -0.20, 2.85), "knee": (0.42, -0.20, 1.55),
    "ankle": (0.43, -0.15, 0.42), "toe": (0.43, -0.80, 0.12),
}
joints = {k: Vector(v) for k, v in C.items()}
for k, (x, y, z) in L.items():
    joints[k + "L"] = Vector((x, y, z))
    joints[k + "R"] = Vector((-x, y, z))


def select_only(*objs):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[-1]


def auto_weights(obj, arm):
    for g in list(obj.vertex_groups):
        obj.vertex_groups.remove(g)
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    obj.parent = None
    select_only(obj, arm)
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    head = obj.vertex_groups["Head"]
    others = [g for g in obj.vertex_groups if g.name != "Head"]
    for v in obj.data.vertices:
        if v.index in hair_idx or (obj.matrix_world @ v.co).z >= HEAD_FROM:
            for g in others:
                g.remove([v.index])
            head.add([v.index], 1.0, "REPLACE")
    empty = [v.index for v in obj.data.vertices if not v.groups]
    if empty:  # poids du sommet pondéré le plus proche
        filled = [v for v in obj.data.vertices if v.groups]
        kd = KDTree(len(filled))
        for i, v in enumerate(filled):
            kd.insert(v.co, i)
        kd.balance()
        names = {g.index: g for g in obj.vertex_groups}
        for i in empty:
            _, j, _ = kd.find(obj.data.vertices[i].co)
            for ge in filled[j].groups:
                names[ge.group].add([i], ge.weight, "REPLACE")
    select_only(obj)
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("SANS POIDS", len(empty))


# 2) bras ramenés vers le bas, pose appliquée au maillage
arm = r15.build_armature(joints, name="Repose", vertical=False)
auto_weights(body, arm)
a = math.radians(ARM_ANGLE)
r15.aim_bone(arm, "LeftUpperArm", (math.sin(a), 0, -math.cos(a)))
r15.aim_bone(arm, "RightUpperArm", (-math.sin(a), 0, -math.cos(a)))
bpy.context.view_layer.update()
for b, (j0, j1, _) in r15.SEGMENTS.items():
    pb = arm.pose.bones[b]
    joints[j0] = arm.matrix_world @ pb.head
    joints[j1] = arm.matrix_world @ pb.tail
select_only(body)
bpy.ops.object.modifier_apply(modifier="Armature")
body.parent = None
bpy.data.objects.remove(arm, do_unlink=True)

# 3) poids recalculés sur la nouvelle pose, squelette R15 définitif (os verticaux)
limb = r15.build_armature(joints, name="Weights", vertical=False)
auto_weights(body, limb)
for m in list(body.modifiers):
    body.modifiers.remove(m)
body.parent = None
bpy.data.objects.remove(limb, do_unlink=True)
rig = r15.build_armature(joints, name="Maya_R15", vertical=True)
r15.bind(body, rig)
np.save(f"{OUT}/hair_idx.npy", np.array(sorted(hair_idx)))
print("JOINTS", {k: tuple(round(c, 2) for c in v) for k, v in sorted(joints.items())})

bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/maya_step2.blend")
bc_render.setup()
bc_render.shoot(f"{OUT}/s2_face.png", "face")
bc_render.shoot(f"{OUT}/s2_profil.png", "profil")
for pb in rig.pose.bones:
    pb.rotation_mode = "XYZ"
rig.pose.bones["LeftUpperArm"].rotation_euler = (0, 0, math.radians(70))
rig.pose.bones["RightUpperArm"].rotation_euler = (0, 0, math.radians(-70))
rig.pose.bones["LeftLowerLeg"].rotation_euler = (math.radians(-60), 0, 0)
bpy.context.view_layer.update()
bc_render.shoot(f"{OUT}/s2_test.png", "face")
