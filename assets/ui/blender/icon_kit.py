# Kit de rendu des icônes 3D du HUD (Baddie Clicker, refonte simulateur).
# Exécuté dans Blender : exec(open(<ce fichier>).read()) puis build_<nom>() et render_icon("<nom>").
# Style : volumes gonflés (courbes extrudées + biseau), matériaux brillants saturés, contour sombre
# par coque inversée (solidify + backface culling), lumière clé + contre-jour, fond transparent.
import bpy
import math
from mathutils import Vector

INK = (0.04, 0.02, 0.09, 1)
OUT_DIR = None  # défini par l'appelant
OUTLINE_SCALE = 1.0  # épaisseur de la coque de contour (1,8 crée du grain)


def hexc(h, a=1.0):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (lin[0], lin[1], lin[2], a)


def reset():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    sc.render.resolution_x = 512
    sc.render.resolution_y = 512
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    try:
        sc.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    sc.render.use_freestyle = False  # Freestyle déforme la coque de contour : on ne s'en sert pas
    world = bpy.data.worlds.get("IconWorld") or bpy.data.worlds.new("IconWorld")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes.get("Background") or next((n for n in nt.nodes if n.type == "BACKGROUND"), None)
    if bg is None:
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        bg = nt.nodes.new("ShaderNodeBackground")
        out = nt.nodes.new("ShaderNodeOutputWorld")
        nt.links.new(bg.outputs[0], out.inputs[0])
    bg.inputs[0].default_value = (0.55, 0.55, 0.62, 1)
    bg.inputs[1].default_value = 0.9
    sc.world = world
    # caméra orthographique de face, légèrement plongeante
    cam_data = bpy.data.cameras.new("IconCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.6
    cam = bpy.data.objects.new("IconCam", cam_data)
    sc.collection.objects.link(cam)
    cam.location = (0, -10, 2.2)
    cam.rotation_euler = (math.radians(77.5), 0, 0)
    sc.camera = cam
    # lumières : clé (haut gauche), remplissage (droite), contre-jour (derrière, liseré)
    def light(name, kind, loc, energy, rot=None, size=None, color=(1, 1, 1)):
        d = bpy.data.lights.new(name, kind)
        d.energy = energy
        d.color = color
        if size is not None and hasattr(d, "size"):
            d.size = size
        o = bpy.data.objects.new(name, d)
        o.location = loc
        if rot:
            o.rotation_euler = rot
        sc.collection.objects.link(o)
        return o
    light("Key", "SUN", (0, 0, 0), 3.2, rot=(math.radians(50), math.radians(-35), math.radians(-25)))
    light("Fill", "SUN", (0, 0, 0), 0.9, rot=(math.radians(70), math.radians(40), math.radians(30)), color=(0.85, 0.9, 1))
    light("Rim", "SUN", (0, 0, 0), 2.4, rot=(math.radians(-60), 0, 0), color=(1, 0.95, 0.9))


def mat(name, color, rough=0.32, metal=0.0, emit=0.0, coat=0.35):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes.get("Principled BSDF")
    if p is None:
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        p = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(p.outputs[0], out.inputs[0])
    c = hexc(color) if isinstance(color, str) else color
    p.inputs["Base Color"].default_value = c
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    for key in ("Coat Weight", "Clearcoat"):
        if key in p.inputs:
            p.inputs[key].default_value = coat
            break
    if emit > 0:
        for key in ("Emission Color", "Emission"):
            if key in p.inputs:
                p.inputs[key].default_value = c
                break
        p.inputs["Emission Strength"].default_value = emit
    return m


def ink_mat():
    m = bpy.data.materials.get("Ink")
    if m:
        return m
    m = bpy.data.materials.new("Ink")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = INK
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], out.inputs[0])
    m.use_backface_culling = True
    return m


def outline(obj, thickness=0.045):
    thickness *= OUTLINE_SCALE
    """Contour sombre : coque inversée (solidify, normales retournées, faces arrière masquées)."""
    if obj.type != "MESH":
        return
    obj.data.materials.append(ink_mat())
    sol = obj.modifiers.new("Outline", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = 1
    sol.use_flip_normals = True
    sol.use_rim = False
    sol.material_offset = len(obj.data.materials) - 1


def to_mesh(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.view_layer.objects.active


def smooth(obj, angle=40):
    if obj.type == "MESH":
        for p in obj.data.polygons:
            p.use_smooth = True
        try:
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
        except Exception:
            pass


def puffy(name, points, material, depth=0.12, bevel=0.07, z=0.0, rot=(90, 0, 0), loc=(0, 0, 0), holes=(), ol=0.045):
    """Forme 2D (x, y) extrudée et biseautée : volume « gonflé ». Le plan XY est tourné face caméra."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "BOTH"
    cu.extrude = depth
    cu.bevel_depth = bevel
    cu.bevel_resolution = 4
    for pts in (points,) + tuple(holes):
        sp = cu.splines.new("POLY")
        sp.points.add(len(pts) - 1)
        for i, (x, y) in enumerate(pts):
            sp.points[i].co = (x, y, z, 1)
        sp.use_cyclic_u = True
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(material)
    o.rotation_euler = tuple(math.radians(a) for a in rot)
    o.location = loc
    o = to_mesh(o)
    smooth(o)
    outline(o, ol)
    return o


def prim(kind, name, material, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), bevel=0.0, ol=0.045, **kw):
    ops = {
        "cube": bpy.ops.mesh.primitive_cube_add,
        "sphere": bpy.ops.mesh.primitive_uv_sphere_add,
        "cyl": bpy.ops.mesh.primitive_cylinder_add,
        "torus": bpy.ops.mesh.primitive_torus_add,
        "cone": bpy.ops.mesh.primitive_cone_add,
    }
    ops[kind](location=loc, rotation=tuple(math.radians(a) for a in rot), **kw)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if bevel > 0:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 4
        b.limit_method = "ANGLE"
    smooth(o)
    if ol > 0:
        outline(o, ol)
    return o


def circle_pts(r, n=48, cx=0, cy=0, start=0):
    return [(cx + r * math.cos(start + 2 * math.pi * i / n), cy + r * math.sin(start + 2 * math.pi * i / n)) for i in range(n)]


def star_pts(R, r, n=5, cx=0, cy=0, rot=90):
    return [(cx + (R if i % 2 == 0 else r) * math.cos(math.radians(rot + i * 180 / n)),
             cy + (R if i % 2 == 0 else r) * math.sin(math.radians(rot + i * 180 / n))) for i in range(2 * n)]


def rrect_pts(w, h, r, n=6, cx=0, cy=0):
    pts = []
    for (sx, sy, a0) in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        ccx, ccy = cx + sx * (w / 2 - r), cy + sy * (h / 2 - r)
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((ccx + r * math.cos(a), ccy + r * math.sin(a)))
    return pts


def group(name, objs, rot=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    for o in objs:
        o.parent = e
    e.rotation_euler = tuple(math.radians(a) for a in rot)
    return e


def frame(margin=1.12):
    """Cadre la caméra orthographique sur tout ce qui est visible (bbox projetée sur X/Z)."""
    bpy.context.view_layer.update()
    xs, zs = [], []
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            xs.append(w.x)
            zs.append(w.z)
    cam = bpy.context.scene.camera
    cx, cz = (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2
    size = max(max(xs) - min(xs), max(zs) - min(zs)) * margin
    cam.data.ortho_scale = size
    cam.location = (cx, -10, cz + 10 * math.tan(math.radians(12.5)))


def render_icon(name):
    frame()
    sc = bpy.context.scene
    sc.render.filepath = f"{OUT_DIR}/{name}.png"
    bpy.ops.render.render(write_still=True)
    return sc.render.filepath
