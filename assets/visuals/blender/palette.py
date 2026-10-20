"""Palettes des trois looks de Maya (spec §4) et cuisson en texture-palette.

Pendant la modélisation, chaque pièce porte un matériau « M_<clé> ». `apply_palette(look)` remplace ensuite tous ces
matériaux par une seule texture 256 px (une case de 16 px par clé) : une seule texture par MeshPart dans Roblox,
et changer de look revient à changer de palette.
"""

import bpy

KEYS = [
    "skin", "hair", "eye", "eye_white", "brow", "lip",
    "tshirt", "jacket", "panel", "piping", "pants",
    "shoe_main", "shoe_sole", "shoe_accent", "bracelet", "headband", "gold",
]

_FACE = {
    "skin": "#E2B18E", "hair": "#1C1512", "eye": "#4A2C1D", "eye_white": "#FFFFFF",
    "brow": "#24180F", "lip": "#B8665A", "gold": "#D7A746",
}

PALETTES = {
    # 1 · Street Start : le concept (foncé en haut, clair en bas)
    "Look01": dict(_FACE, tshirt="#F4EEE7", jacket="#3B5B8C", panel="#F4EEE7", piping="#F2A65A", pants="#F4EEE7",
                   shoe_main="#F4EEE7", shoe_sole="#3B5B8C", shoe_accent="#F2A65A", bracelet="#F2A65A",
                   headband="#F2A65A"),
    # 2 · Street Match : l'inverse (clair en haut, denim en bas), ensemble orange assorti
    "Look02": dict(_FACE, tshirt="#F4EEE7", jacket="#F4EEE7", panel="#F2A65A", piping="#3B5B8C", pants="#3B5B8C",
                   shoe_main="#F2A65A", shoe_sole="#F4EEE7", shoe_accent="#F4EEE7", bracelet="#F2A65A",
                   headband="#F2A65A"),
    # 3 · Street Signature : nuit et or, t-shirt orange
    "Look03": dict(_FACE, tshirt="#F2A65A", jacket="#242036", panel="#2F2945", piping="#D7A746", pants="#242036",
                   shoe_main="#242036", shoe_sole="#D7A746", shoe_accent="#D7A746", bracelet="#D7A746",
                   headband="#D7A746"),
}

CELL = 16
SIZE = 256


def materials_for(look):
    """Crée/actualise les matériaux M_<clé> avec les couleurs du look (aperçu dans Blender)."""
    import bc_common
    out = {}
    for key, hex_color in PALETTES[look].items():
        metallic = 0.8 if key == "gold" or (look == "Look03" and key in ("piping", "bracelet", "headband")) else 0.0
        out[key] = bc_common.material(key, hex_color, roughness=0.35 if metallic else 0.6, metallic=metallic)
    return out


def cell_uv(key):
    """Centre de la case de `key` dans la texture-palette (coordonnées UV)."""
    i = KEYS.index(key)
    col, row = i % (SIZE // CELL), i // (SIZE // CELL)
    return ((col + 0.5) * CELL / SIZE, 1 - (row + 0.5) * CELL / SIZE)


def palette_image(look, out_path=None):
    """Image 256 px : une case unie par clé, dans l'ordre de KEYS. Sauvegardée en PNG si `out_path`."""
    name = f"Palette_{look}"
    img = bpy.data.images.get(name) or bpy.data.images.new(name, SIZE, SIZE, alpha=False)
    px = [0.0] * (SIZE * SIZE * 4)
    for key in KEYS:
        # image générée en sRGB : on écrit directement la valeur sRGB du hex
        sr, sg, sb = (int(PALETTES[look][key].lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4))
        i = KEYS.index(key)
        cx, cy = (i % (SIZE // CELL)) * CELL, SIZE - ((i // (SIZE // CELL)) + 1) * CELL
        for y in range(cy, cy + CELL):
            for x in range(cx, cx + CELL):
                o = (y * SIZE + x) * 4
                px[o:o + 4] = [sr, sg, sb, 1.0]
    img.pixels = px
    if out_path:
        img.filepath_raw = out_path
        img.file_format = "PNG"
        img.save()
    return img


def apply_palette(objs, look):
    """Remplace les matériaux M_<clé> par une seule texture-palette : UV de chaque face au centre de sa case."""
    img = palette_image(look)
    import bc_common
    mat = bpy.data.materials.get(f"M_Palette_{look}") or bpy.data.materials.new(f"M_Palette_{look}")
    bsdf = bc_common.principled(mat)
    nodes = mat.node_tree.nodes
    tex = nodes.get("PaletteTex") or nodes.new("ShaderNodeTexImage")
    tex.name = "PaletteTex"
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    for obj in objs:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        keys = [m.get("bc_key") if m else None for m in mesh.materials]
        uv = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
        for poly in mesh.polygons:
            key = keys[poly.material_index] if poly.material_index < len(keys) else None
            u, v = cell_uv(key or "skin")
            for li in poly.loop_indices:
                uv.data[li].uv = (u, v)
        mesh.materials.clear()
        mesh.materials.append(mat)
    return mat
