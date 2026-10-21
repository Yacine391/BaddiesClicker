"""Rendus de contrôle (Cycles CPU, éclairage uniforme) : face, profil, dos, en orthographique."""

import math

import bpy
from mathutils import Vector


def setup(res=(420, 640), samples=12):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    world = sc.world or bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.95, 0.93, 0.9, 1)
    bg.inputs[1].default_value = 1.6
    sc.view_settings.view_transform = "Standard"


def camera(height=5.5):
    cam = bpy.data.objects.get("BC_Cam")
    if cam is None:
        cam = bpy.data.objects.new("BC_Cam", bpy.data.cameras.new("BC_Cam"))
        bpy.context.scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = height * 1.12
    bpy.context.scene.camera = cam
    return cam


def shoot(path, view, height=5.5, center_x=0.0):
    """view : 'face' (caméra en -Y regardant +Y), 'dos', 'profil' (caméra en +X)."""
    cam = camera(height)
    z = height / 2
    d = 20
    if view == "face":
        cam.location = Vector((center_x, -d, z))
        cam.rotation_euler = (math.radians(90), 0, 0)
    elif view == "dos":
        cam.location = Vector((center_x, d, z))
        cam.rotation_euler = (math.radians(90), 0, math.radians(180))
    else:
        cam.location = Vector((d, 0, z))
        cam.rotation_euler = (math.radians(90), 0, math.radians(90))
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
