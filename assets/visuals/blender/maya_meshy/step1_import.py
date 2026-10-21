"""Étape 1 : importer le GLB Meshy, tout fusionner, mettre à l'échelle (5,5 studs, pieds en z=0), rendus de contrôle.

Usage : python3 step1_import.py <glb> <out_dir>
"""

import sys

import bpy
from mathutils import Vector

sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import bc_render  # noqa: E402

HEIGHT = 5.5

glb, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(o in meshes)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = "Maya"
# détacher des éventuels parents (nœuds vides du glTF) en gardant la transformation
mw = body.matrix_world.copy()
body.parent = None
body.matrix_world = mw
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o != body:
        bpy.data.objects.remove(o, do_unlink=True)

pts = [v.co for v in body.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
s = HEIGHT / (hi.z - lo.z)
center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for v in body.data.vertices:
    v.co = (v.co - center) * s
body.data.update()

tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
imgs = [(i.name, tuple(i.size)) for i in bpy.data.images]
print("TRIS", tris, "VERTS", len(body.data.vertices), "IMAGES", imgs)
print("SIZE", tuple(round((hi[i] - lo[i]) * s, 3) for i in range(3)))
print("MATERIALS", [m.name for m in body.data.materials])

bpy.ops.wm.save_as_mainfile(filepath=f"{out}/maya_step1.blend")
bc_render.setup()
for view in ("face", "profil", "dos"):
    bc_render.shoot(f"{out}/s1_{view}.png", view, HEIGHT)
