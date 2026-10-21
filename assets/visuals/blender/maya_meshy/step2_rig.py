"""Étape 2 : articulations, bras ramenés à 15° (les animations Roblox partent de bras le long du corps),
poids automatiques de Blender (chaleur), squelette R15 vertical, rendus de contrôle.

Usage : python3 step2_rig.py <out_dir>
"""

import math
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.dirname(__import__("os").path.abspath(__file__))))
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import bc_render  # noqa: E402
import r15_armature as r15  # noqa: E402

OUT = sys.argv[1]
ARM_ANGLE = 15  # degrés entre le bras et la verticale après la remise en pose
HEAD_FROM = 4.52  # au-dessus : 100 % Head (cheveux, visage)

bpy.ops.wm.open_mainfile(filepath=f"{OUT}/maya_step1.blend")
body = bpy.data.objects["Maya"]
import bmesh  # noqa: E402
from mathutils.kdtree import KDTree  # noqa: E402

bm = bmesh.new()
bm.from_mesh(body.data)
before = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)  # coutures de texture : sommets doublés
bm.to_mesh(body.data)
bm.free()
print("SOUDURE", before, "->", len(body.data.vertices))

# (x, z) mesurés sur les coupes du modèle (côté gauche du personnage = +X, face vers -Y)
LEFT = {
    "shoulder": (0.62, 4.28), "elbow": (0.95, 3.68), "wrist": (1.20, 3.08), "hand": (1.42, 2.68),
    "hip": (0.38, 2.85), "knee": (0.46, 1.50), "ankle": (0.55, 0.45), "toe": (0.57, 0.12),
}
CENTER = {"pelvis": (0.0, 2.95), "waist": (0.0, 3.35), "neck": (0.0, 4.45), "headtop": (0.0, 5.50)}

verts = [v.co.copy() for v in body.data.vertices]


def at(x, z, r=0.2):
    near = [v.y for v in verts if (v.x - x) ** 2 + (v.z - z) ** 2 < r * r]
    return Vector((x, sum(near) / len(near) if near else 0.0, z))


joints = {k: at(*xz) for k, xz in CENTER.items()}
for k, (x, z) in LEFT.items():
    joints[k + "L"] = at(x, z)
    joints[k + "R"] = at(-x, z)
for side in "LR":
    toe = joints["toe" + side]
    front = min((v.y for v in verts if abs(v.x - toe.x) < 0.2 and v.z < 0.4), default=toe.y - 0.4)
    joints["toe" + side] = Vector((toe.x, front + 0.12, toe.z))


def select_only(*objs):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[-1]


def auto_weights(obj, arm):
    """Poids par chaleur (Blender), puis tête rigide, 4 os max par sommet, normalisés."""
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
        if (obj.matrix_world @ v.co).z >= HEAD_FROM:
            for g in others:
                g.remove([v.index])
            head.add([v.index], 1.0, "REPLACE")
    select_only(obj)
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    empty = [v.index for v in obj.data.vertices if not v.groups]
    print("SANS POIDS", len(empty))
    if empty:  # recopier les poids du sommet pondéré le plus proche
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


# 1) bras ramenés vers le bas : squelette le long des membres, poids par chaleur, pose appliquée
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

# 2) poids recalculés sur la nouvelle pose, puis squelette R15 définitif (os verticaux) avec les mêmes poids
limb = r15.build_armature(joints, name="Weights", vertical=False)
auto_weights(body, limb)
for m in list(body.modifiers):
    body.modifiers.remove(m)
body.parent = None
bpy.data.objects.remove(limb, do_unlink=True)
rig = r15.build_armature(joints, name="Maya_R15", vertical=True)
r15.bind(body, rig)
print("JOINTS", {k: tuple(round(c, 2) for c in v) for k, v in sorted(joints.items())})

bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/maya_step2.blend")
bc_render.setup()
bc_render.shoot(f"{OUT}/s2_face.png", "face")
bc_render.shoot(f"{OUT}/s2_profil.png", "profil")
# pose de contrôle : bras levés sur le côté (rotation autour de l'axe avant), genou gauche plié
for pb in rig.pose.bones:
    pb.rotation_mode = "XYZ"
rig.pose.bones["LeftUpperArm"].rotation_euler = (0, 0, math.radians(70))
rig.pose.bones["RightUpperArm"].rotation_euler = (0, 0, math.radians(-70))
rig.pose.bones["LeftLowerLeg"].rotation_euler = (math.radians(-60), 0, 0)
bpy.context.view_layer.update()
bc_render.shoot(f"{OUT}/s2_test.png", "face")
