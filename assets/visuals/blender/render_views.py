"""Rendus de validation : face, profil, dos (Workbench, couleurs des matériaux, fond crème)."""

import math
import os
import bpy

VIEWS = {"face": (0.0, -1.0), "profil": (-1.0, 0.0), "dos": (0.0, 1.0)}


def _setup(size):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.film_transparent = False
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_cavity = True
    shading.cavity_type = "WORLD"
    shading.show_object_outline = True
    if hasattr(shading, "background_type"):
        shading.background_type = "VIEWPORT"
        shading.background_color = (0.9, 0.86, 0.8)
    scene.view_settings.view_transform = "Standard"
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.color = (0.9, 0.86, 0.8)
    cam = bpy.data.objects.get("BC_Camera")
    if cam is None:
        cam = bpy.data.objects.new("BC_Camera", bpy.data.cameras.new("BC_Camera"))
        scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 6.4
    scene.camera = cam
    return cam


def render_views(tag, out_dir, size=768, views=("face", "profil", "dos"), target_z=2.85, ortho=6.4):
    cam = _setup(size)
    cam.data.ortho_scale = ortho
    os.makedirs(out_dir, exist_ok=True)
    paths = []
    for view in views:
        dx, dy = VIEWS[view]
        cam.location = (dx * 20, dy * 20, target_z)
        cam.rotation_euler = (math.pi / 2, 0, math.atan2(dx, -dy))
        path = os.path.join(out_dir, f"{tag}_{view}.png")
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths
