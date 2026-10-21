"""Squelette R15, poids et découpe en 15 parties (spec §3, plan Task 4). Générique : sert pour Maya puis les autres.

Repère : 1 unité = 1 stud, Z vers le haut, face à -Y, gauche du personnage = +X.
Un « segment » d'os va d'une articulation à la suivante ; les poids sont calculés par distance aux segments, en ne
mélangeant qu'un os avec son parent ou ses enfants (pas de fuite d'une jambe vers l'autre).
"""

import bpy
import bmesh
from mathutils import Vector, Matrix

# os R15 : (articulation de départ, articulation de fin, parent)
SEGMENTS = {
    "LowerTorso": ("pelvis", "waist", "HumanoidRootNode"),
    "UpperTorso": ("waist", "neck", "LowerTorso"),
    "Head": ("neck", "headtop", "UpperTorso"),
    "LeftUpperArm": ("shoulderL", "elbowL", "UpperTorso"),
    "LeftLowerArm": ("elbowL", "wristL", "LeftUpperArm"),
    "LeftHand": ("wristL", "handL", "LeftLowerArm"),
    "RightUpperArm": ("shoulderR", "elbowR", "UpperTorso"),
    "RightLowerArm": ("elbowR", "wristR", "RightUpperArm"),
    "RightHand": ("wristR", "handR", "RightLowerArm"),
    "LeftUpperLeg": ("hipL", "kneeL", "LowerTorso"),
    "LeftLowerLeg": ("kneeL", "ankleL", "LeftUpperLeg"),
    "LeftFoot": ("ankleL", "toeL", "LeftLowerLeg"),
    "RightUpperLeg": ("hipR", "kneeR", "LowerTorso"),
    "RightLowerLeg": ("kneeR", "ankleR", "RightUpperLeg"),
    "RightFoot": ("ankleR", "toeR", "RightLowerLeg"),
}
PARTS = list(SEGMENTS)


def refine_joints(obj, guesses, radius=0.22):
    """Recentre chaque articulation devinée (x, z) sur les sommets proches dans le plan XZ → (x, y, z)."""
    mw = obj.matrix_world
    verts = [mw @ v.co for v in obj.data.vertices]
    out = {}
    for name, (gx, gz) in guesses.items():
        near = [v for v in verts if (v.x - gx) ** 2 + (v.z - gz) ** 2 < radius ** 2]
        if not near:
            out[name] = Vector((gx, 0.0, gz))
            continue
        c = sum(near, Vector()) / len(near)
        out[name] = Vector((c.x, c.y, c.z))
    return out


def _children():
    kids = {b: [] for b in SEGMENTS}
    for b, (_, _, parent) in SEGMENTS.items():
        if parent in kids:
            kids[parent].append(b)
    return kids


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def compute_weights(obj, joints, rigid_head_objects=(), island_max=250, exclude_head=()):
    """Remplit les groupes de sommets des 15 os.

    - sommet dont l'os le plus proche est Head → 100 % Head ;
    - îlots de moins de `island_max` sommets (poches, bijoux, pièces de baskets) → 100 % sur l'os le plus proche
      de leur centre (Head exclu) ;
    - sinon mélange de l'os le plus proche avec son parent ou ses enfants (2 os max, poids en 1/d⁴).
    """
    kids = _children()
    segs = {b: (joints[a], joints[e]) for b, (a, e, _) in SEGMENTS.items()}
    for name in PARTS:
        if obj.vertex_groups.get(name) is None:
            obj.vertex_groups.new(name=name)
    groups = {g.name: g for g in obj.vertex_groups}
    mw = obj.matrix_world
    world = [mw @ v.co for v in obj.data.vertices]

    def nearest(p, allowed):
        return min(allowed, key=lambda b: _seg_dist(p, *segs[b]))

    # îlots (composantes connexes)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    seen, islands = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, comp = [v], []
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            comp.append(cur.index)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        islands.append(comp)
    bm.free()

    no_head = [b for b in PARTS if b != "Head"]
    rigid = {}
    for comp in islands:
        if len(comp) < island_max:
            c = sum((world[i] for i in comp), Vector()) / len(comp)
            bone = nearest(c, PARTS if _seg_dist(c, *segs["Head"]) < 0.35 else no_head)
            for i in comp:
                rigid[i] = bone
    for i, p in enumerate(world):
        if i in rigid:
            groups[rigid[i]].add([i], 1.0, "REPLACE")
            continue
        b0 = nearest(p, PARTS)
        if b0 == "Head":
            groups["Head"].add([i], 1.0, "REPLACE")
            continue
        parent = SEGMENTS[b0][2]
        cands = [b0] + kids[b0] + ([parent] if parent in SEGMENTS else [])
        cands = [b for b in cands if b != "Head"]
        scored = sorted(((1.0 / (_seg_dist(p, *segs[b]) + 0.03) ** 4, b) for b in cands), reverse=True)[:2]
        total = sum(w for w, _ in scored)
        for w, b in scored:
            groups[b].add([i], w / total, "REPLACE")


def build_armature(joints, name="R15Rig", vertical=True):
    """Armature R15 : Root → HumanoidRootNode → 15 os. `vertical` : os courts vers +Z (pièces alignées, comme un
    R15 Roblox) ; sinon os le long des membres (utile pour reposer le modèle)."""
    arm_data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    root = eb.new("Root")
    root.head, root.tail = Vector((0, 0, 0)), Vector((0, 0, 0.3))
    hrn = eb.new("HumanoidRootNode")
    hrn.head = joints["pelvis"].copy()
    hrn.tail = joints["pelvis"] + Vector((0, 0, 0.3))
    hrn.parent = root
    for b in PARTS:  # ordre de SEGMENTS : parents avant enfants
        a, e, parent = SEGMENTS[b]
        bone = eb.new(b)
        bone.head = joints[a].copy()
        bone.tail = joints[a] + Vector((0, 0, 0.3)) if vertical else joints[e].copy()
        bone.roll = 0.0
        bone.parent = eb[parent]
        bone.use_connect = False
    for b in ("Root", "HumanoidRootNode"):
        eb[b].use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def bind(obj, arm):
    obj.parent = arm
    mod = obj.modifiers.get("Armature") or obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return obj


def aim_bone(arm, bone_name, target_dir):
    """Tourne l'os (en pose) autour de sa tête pour que sa direction monde devienne `target_dir`."""
    pb = arm.pose.bones[bone_name]
    bpy.context.view_layer.update()
    m = arm.matrix_world @ pb.matrix
    head = m.translation.copy()
    cur = (arm.matrix_world @ pb.tail) - (arm.matrix_world @ pb.head)
    q = cur.normalized().rotation_difference(Vector(target_dir).normalized())
    world = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ m
    pb.matrix = arm.matrix_world.inverted() @ world
    bpy.context.view_layer.update()


def apply_pose(obj, arm):
    """Applique la pose courante au maillage (modificateur Armature appliqué) et renvoie les articulations posées."""
    joints = {}
    for b, (a, e, _) in SEGMENTS.items():
        pb = arm.pose.bones[b]
        joints[a] = arm.matrix_world @ pb.head
        joints[e] = arm.matrix_world @ pb.tail
    joints["pelvis"] = arm.matrix_world @ arm.pose.bones["LowerTorso"].head
    bpy.context.view_layer.objects.active = obj
    mw = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = mw
    bpy.ops.object.modifier_apply(modifier="Armature")
    obj.vertex_groups.clear()
    return joints


def split_parts(obj):
    """Découpe le maillage en 15 objets nommés comme les parties R15 (chaque face va à l'os dominant de ses sommets).
    Les groupes de sommets sont conservés : le maillage reste skinné, sans trou aux jointures."""
    names = {g.index: g.name for g in obj.vertex_groups}
    dominant = []
    for poly in obj.data.polygons:
        score = {}
        for vi in poly.vertices:
            for g in obj.data.vertices[vi].groups:
                score[names[g.group]] = score.get(names[g.group], 0.0) + g.weight
        dominant.append(max(score, key=score.get) if score else "LowerTorso")
    parts = {}
    for b in PARTS:
        dup = obj.copy()
        dup.data = obj.data.copy()
        dup.name = b
        dup.data.name = b
        bpy.context.scene.collection.objects.link(dup)
        bm = bmesh.new()
        bm.from_mesh(dup.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if dominant[f.index] != b], context="FACES")
        bm.to_mesh(dup.data)
        bm.free()
        parts[b] = dup
    bpy.data.objects.remove(obj, do_unlink=True)
    return parts


def test_pose(arm, on=True):
    """Pose de contrôle : bras levés de côté (80°), genou gauche plié (60°)."""
    import math
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
    if on:
        arm.pose.bones["LeftUpperArm"].rotation_euler = (0, math.radians(80), 0)
        arm.pose.bones["RightUpperArm"].rotation_euler = (0, math.radians(-80), 0)
        arm.pose.bones["LeftLowerLeg"].rotation_euler = (math.radians(-60), 0, 0)
    bpy.context.view_layer.update()
