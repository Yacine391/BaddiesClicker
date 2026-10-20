"""Outils communs aux scripts Blender de Baddie Clicker.

Conventions : 1 unité Blender = 1 stud, Z vers le haut, personnage face à -Y, pieds à Z = 0.
"""

import bpy
import bmesh
from mathutils import Vector


def reset_scene():
    """Vide la scène (objets, maillages, matériaux, armatures) pour reconstruire de zéro."""
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.images, bpy.data.curves):
        for block in list(coll):
            if block.users == 0:
                coll.remove(block)


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(hex_color):
    h = hex_color.lstrip("#")
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


def principled(mat):
    """Nœud Principled BSDF du matériau, créé et relié à la sortie s'il manque (Blender 5 n'en crée plus)."""
    if hasattr(mat, "use_nodes") and not mat.use_nodes:
        mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        out = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None) or nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return bsdf


def material(key, hex_color, roughness=0.6, metallic=0.0):
    """Matériau « M_<key> » (réutilisé s'il existe), couleur de base en hex sRGB."""
    name = f"M_{key}"
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    bsdf = principled(mat)
    bsdf.inputs["Base Color"].default_value = hex_rgba(hex_color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = hex_rgba(hex_color)
    mat["bc_key"] = key
    return mat


def collection(name):
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
    return coll


def link(obj, coll_name):
    coll = collection(coll_name)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    return obj


def set_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def primitive(kind, name, location=(0, 0, 0), scale=(1, 1, 1), rotation=(0, 0, 0), **kwargs):
    """Crée une primitive (uv_sphere, cube, cylinder, torus, ico_sphere, cone), applique l'échelle."""
    ops = {
        "uv_sphere": bpy.ops.mesh.primitive_uv_sphere_add,
        "ico_sphere": bpy.ops.mesh.primitive_ico_sphere_add,
        "cube": bpy.ops.mesh.primitive_cube_add,
        "cylinder": bpy.ops.mesh.primitive_cylinder_add,
        "torus": bpy.ops.mesh.primitive_torus_add,
        "cone": bpy.ops.mesh.primitive_cone_add,
    }
    ops[kind](location=location, rotation=rotation, **kwargs)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def shade_smooth(obj, angle_deg=40):
    for p in obj.data.polygons:
        p.use_smooth = True
    if hasattr(obj.data, "set_sharp_from_angle"):
        import math
        obj.data.set_sharp_from_angle(angle=math.radians(angle_deg))
    return obj


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    return obj


def join(objs, name):
    """Fusionne des objets maillage en un seul (le premier garde le nom)."""
    objs = [o for o in objs if o and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    out = bpy.context.active_object
    out.name = name
    out.data.name = name
    return out


def mirror_x(obj, apply=True):
    m = obj.modifiers.new("MirrorX", "MIRROR")
    m.use_axis[0] = True
    m.use_clip = True
    m.use_mirror_merge = True
    if apply:
        apply_modifiers(obj)
    return obj


def subdivide(obj, levels=1, apply=True):
    m = obj.modifiers.new("Subsurf", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    if apply:
        apply_modifiers(obj)
    return obj


def remove_doubles(obj, dist=0.0005):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def skin_mesh(name, points, edges, root, subsurf=1):
    """Maillage organique : `points` = {nom: ((x, y, z), (rx, ry))}, `edges` = [(a, b)], `root` = nom du point racine.

    Le modificateur Skin habille le squelette de points, puis une subdivision lisse le tout (modificateurs appliqués).
    """
    names = list(points)
    index = {n: i for i, n in enumerate(names)}
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([points[n][0] for n in names], [(index[a], index[b]) for a, b in edges], [])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    for n in names:
        sv = mesh.skin_vertices[0].data[index[n]]
        sv.radius = points[n][1]
        sv.use_root = n == root
    if subsurf:
        sub = obj.modifiers.new("Subsurf", "SUBSURF")
        sub.levels = subsurf
    apply_modifiers(obj)
    return shade_smooth(obj, angle_deg=180)


def assign_material_where(obj, mat, predicate):
    """Ajoute `mat` à l'objet et l'applique aux faces dont le centre (repère monde) vérifie `predicate(Vector)`."""
    if mat.name not in [m.name for m in obj.data.materials if m]:
        obj.data.materials.append(mat)
    slot = [m.name for m in obj.data.materials].index(mat.name)
    mw = obj.matrix_world
    for p in obj.data.polygons:
        if predicate(mw @ p.center):
            p.material_index = slot
    return obj


def delete_faces_where(obj, predicate):
    """Supprime les faces dont le centre (repère monde) vérifie `predicate(Vector)`."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    mw = obj.matrix_world
    doomed = [f for f in bm.faces if predicate(mw @ f.calc_center_median())]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def world_bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return (min(p.x for p in pts), max(p.x for p in pts), min(p.y for p in pts),
            max(p.y for p in pts), min(p.z for p in pts), max(p.z for p in pts))
