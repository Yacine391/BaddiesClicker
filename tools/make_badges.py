# Génère les icônes 512x512 des badges Roblox dans assets/badges/ (lancer depuis la racine du repo : python3 tools/make_badges.py)
import math, colorsys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = "assets/badges"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SIZE = 512
C = SIZE // 2

badges = [
    ("first_training", "20", ["PREMIER", "ENTRAÎNEMENT"], (242, 166, 90)),
    ("first_look", "LOOK", ["PREMIER", "LOOK"], (232, 160, 168)),
    ("first_boss", "BOSS", ["PREMIER", "BOSS"], (214, 51, 108)),
    ("first_crew", "DJ", ["PREMIER", "CREW"], (19, 166, 181)),
    ("run_complete", "10", ["PARCOURS", "TERMINÉ"], (215, 167, 70)),
    ("first_rebirth", "R1", ["PREMIÈRE", "RENAISSANCE"], (192, 196, 204)),
    ("book_baddies_v1", "8/8", ["BOOK", "BADDIES V1"], (185, 163, 217)),
    ("book_crew_v1", "6/6", ["BOOK", "CREW V1"], (143, 169, 139)),
    ("mythic_found", "VEGA", ["MYTHIC", "DÉCOUVERTE"], (48, 213, 200)),
    ("collection_v1", "V1", ["COLLECTION", "COMPLÈTE"], (255, 215, 90)),
]

def font(size):
    return ImageFont.truetype(FONT, size)

def centered(draw, y, text, f, fill):
    w = draw.textlength(text, font=f)
    draw.text((C - w / 2, y), text, font=f, fill=fill)

for key, glyph, label, accent in badges:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # anneau arc-en-ciel (thème RGB du jeu)
    for i in range(360):
        r, g, b = colorsys.hsv_to_rgb(i / 360, 0.85, 1.0)
        d.pieslice([8, 8, SIZE - 8, SIZE - 8], i - 90, i - 89 + 1.5, fill=(int(r * 255), int(g * 255), int(b * 255), 255))
    # disque intérieur nuit, dégradé radial
    inner = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    di = ImageDraw.Draw(inner)
    for k in range(200, 0, -2):
        t = k / 200
        col = (int(36 + (58 - 36) * (1 - t)), int(32 + (53 - 32) * (1 - t)), int(54 + (80 - 54) * (1 - t)), 255)
        di.ellipse([C - k * 1.12, C - k * 1.12, C + k * 1.12, C + k * 1.12], fill=col)
    img.alpha_composite(inner)
    d = ImageDraw.Draw(img)
    # cercle d'accent
    d.ellipse([52, 52, SIZE - 52, SIZE - 52], outline=accent + (255,), width=10)
    # halo derrière le symbole
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    dg = ImageDraw.Draw(glow)
    dg.ellipse([C - 120, C - 150, C + 120, C + 60], fill=accent + (110,))
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    # symbole
    size = 170 if len(glyph) <= 2 else (128 if len(glyph) == 3 else 104)
    f = font(size)
    bbox = d.textbbox((0, 0), glyph, font=f)
    h = bbox[3] - bbox[1]
    y = C - 40 - h / 2 - bbox[1]
    centered(d, y + 6, glyph, f, (0, 0, 0, 120))
    centered(d, y, glyph, f, (244, 238, 231, 255))
    # libellé
    lf = font(30)
    centered(d, C + 78, label[0], lf, accent + (255,))
    centered(d, C + 116, label[1], lf, (244, 238, 231, 255))
    img.save(f"{OUT}/{key}.png")
    print("ok", key)
