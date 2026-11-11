# Icônes 3D du HUD. Dans Blender : exec(open(icon_kit.py).read()); exec(open(icons.py).read()); build("book")
# Rendus PNG 512 × 512 transparents dans assets/ui/icons-3d/. Une fonction build_<nom> par icône.
import math


def build_book():
    blue = mat("BookBlue", "#2F8CFF")
    pages = mat("Pages", "#FFF6E6", rough=0.6, coat=0)
    gold = mat("Gold", "#FFC93C", rough=0.25, metal=0.6)
    pink = mat("Ribbon", "#FF4FB4")
    objs = [
        prim("cube", "Cover", blue, loc=(0, 0.12, 0), scale=(0.78, 0.1, 1.0), bevel=0.08),
        prim("cube", "Pages", pages, loc=(0.06, -0.02, 0), scale=(0.7, 0.16, 0.93), bevel=0.03, ol=0.03),
        prim("cube", "Back", blue, loc=(0, -0.16, 0), scale=(0.78, 0.06, 1.0), bevel=0.06),
        puffy("Crown", [(-0.42, -0.18), (-0.48, 0.3), (-0.22, 0.08), (0, 0.42), (0.22, 0.08), (0.48, 0.3), (0.42, -0.18)],
              gold, depth=0.04, bevel=0.04, loc=(-0.02, -0.25, 0.18), ol=0.03),
        puffy("Ribbon", [(-0.1, 0.2), (0.1, 0.2), (0.1, -0.35), (0, -0.25), (-0.1, -0.35)], pink,
              depth=0.02, bevel=0.03, loc=(0.42, -0.24, -0.95), ol=0.025),
    ]
    group("Book", objs, rot=(8, 0, -38))


def build_style():
    # t-shirt rose gonflé avec étoile blanche
    pink = mat("Shirt", "#FF5FC0")
    white = mat("White", "#FFFFFF", rough=0.4)
    shirt = [(-0.35, 0.75), (-0.15, 0.75), (0, 0.6), (0.15, 0.75), (0.35, 0.75), (0.9, 0.42), (0.68, 0.05),
             (0.48, 0.18), (0.48, -0.8), (-0.48, -0.8), (-0.48, 0.18), (-0.68, 0.05), (-0.9, 0.42)]
    objs = [
        puffy("Shirt", shirt, pink, depth=0.16, bevel=0.1),
        puffy("Star", star_pts(0.32, 0.14, cy=-0.12), white, depth=0.02, bevel=0.04, loc=(0, -0.3, 0), ol=0.03),
    ]
    group("Style", objs, rot=(0, 0, -14))


def build_crew():
    v1, v2 = mat("Crew1", "#9C6BFF"), mat("Crew2", "#C7A6FF")
    skin = mat("Skin", "#FFC9A3", rough=0.5, coat=0)
    objs = [
        prim("sphere", "BodyBack", v2, loc=(0.42, 0.35, -0.42), scale=(0.42, 0.36, 0.42), segments=48, ring_count=24),
        prim("sphere", "HeadBack", skin, loc=(0.42, 0.35, 0.28), scale=(0.27, 0.27, 0.27), segments=48, ring_count=24),
        prim("sphere", "HairBack", v2, loc=(0.42, 0.37, 0.42), scale=(0.29, 0.29, 0.2), segments=48, ring_count=24),
        prim("sphere", "BodyFront", v1, loc=(-0.25, 0, -0.55), scale=(0.52, 0.44, 0.48), segments=48, ring_count=24),
        prim("sphere", "HeadFront", skin, loc=(-0.25, -0.02, 0.25), scale=(0.33, 0.33, 0.33), segments=48, ring_count=24),
        prim("sphere", "HairFront", v1, loc=(-0.25, 0.02, 0.42), scale=(0.36, 0.36, 0.24), segments=48, ring_count=24),
    ]
    group("Crew", objs, rot=(0, 0, -10))


def build_slots():
    gold, gold2 = mat("Card", "#FFC93C", rough=0.3), mat("Card2", "#F29A12", rough=0.3)
    white = mat("White", "#FFFFFF", rough=0.4)
    card = rrect_pts(0.9, 1.25, 0.12)
    objs = [
        puffy("CardL", card, gold2, depth=0.05, bevel=0.04, loc=(-0.45, 0.25, -0.05), rot=(90, -18, 0)),
        puffy("CardR", card, gold2, depth=0.05, bevel=0.04, loc=(0.45, 0.25, -0.05), rot=(90, 18, 0)),
        puffy("CardC", card, gold, depth=0.06, bevel=0.05, loc=(0, -0.05, 0.08)),
        puffy("Star", star_pts(0.28, 0.12), white, depth=0.02, bevel=0.04, loc=(0, -0.2, 0.08), ol=0.03),
    ]
    group("Slots", objs)


def build_bonus():
    colors = ["#FFB347", "#FF5A3C", "#FFE066", "#FF7FB0", "#FFC93C", "#FF5A3C", "#7FE3FF", "#FFB347"]
    objs = []
    n = len(colors)
    for i, c in enumerate(colors):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        pts = [(0, 0)] + [(0.88 * math.cos(a0 + (a1 - a0) * k / 8), 0.88 * math.sin(a0 + (a1 - a0) * k / 8)) for k in range(9)]
        objs.append(puffy(f"Seg{i}", pts, mat(f"Seg{i}", c), depth=0.04, bevel=0.015, ol=0.02))
    gold = mat("Gold", "#FFC93C", rough=0.25, metal=0.6)
    objs.append(prim("torus", "Rim", gold, loc=(0, 0, 0), rot=(90, 0, 0), major_radius=0.95, minor_radius=0.09,
                     major_segments=64, minor_segments=16))
    objs.append(prim("cyl", "Hub", mat("White", "#FFFFFF", rough=0.4), loc=(0, -0.1, 0), rot=(90, 0, 0),
                     scale=(0.18, 0.18, 0.08), vertices=32))
    objs.append(puffy("Pointer", [(-0.17, 0.2), (0.17, 0.2), (0, -0.16)], mat("Pointer", "#FF2E4D"),
                      depth=0.05, bevel=0.04, loc=(0, -0.15, 1.02)))
    group("Bonus", objs, rot=(0, 0, -12))


def build_settings():
    pts = []
    teeth = 9
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        r = 0.92 if (i % 4) in (1, 2) else 0.7
        pts.append((r * math.cos(a), r * math.sin(a)))
    grey = mat("Steel", "#AEB6D4", rough=0.25, metal=0.7)
    objs = [puffy("Gear", pts, grey, depth=0.16, bevel=0.05, holes=(circle_pts(0.3, 32)[::-1],))]
    objs.append(prim("torus", "Ring", mat("SteelDark", "#6B7396", rough=0.3, metal=0.6), rot=(90, 0, 0),
                     loc=(0, -0.12, 0), major_radius=0.33, minor_radius=0.05, major_segments=48, minor_segments=12, ol=0.02))
    group("Settings", objs, rot=(0, 0, -15))


def build_gift():
    orange = mat("Box", "#FF8A3C")
    lid = mat("Lid", "#FFA14F")
    pink = mat("Bow", "#FF4FB4")
    objs = [
        prim("cube", "Box", orange, loc=(0, 0, -0.35), scale=(0.72, 0.72, 0.55), bevel=0.06),
        prim("cube", "Lid", lid, loc=(0, 0, 0.27), scale=(0.82, 0.82, 0.14), bevel=0.05),
        prim("cube", "RibbonV", pink, loc=(0, 0, -0.1), scale=(0.16, 0.84, 0.86), bevel=0.02, ol=0.02),
        prim("cube", "RibbonH", pink, loc=(0, 0, -0.1), scale=(0.84, 0.16, 0.86), bevel=0.02, ol=0.02),
        prim("torus", "LoopL", pink, loc=(-0.24, 0, 0.62), rot=(90, 0, 25), major_radius=0.22, minor_radius=0.07),
        prim("torus", "LoopR", pink, loc=(0.24, 0, 0.62), rot=(90, 0, -25), major_radius=0.22, minor_radius=0.07),
    ]
    group("Gift", objs, rot=(12, 0, -30))


def build_power():
    bolt = [(0.18, 1.0), (-0.55, -0.1), (-0.05, -0.1), (-0.25, -1.0), (0.55, 0.15), (0.05, 0.15)]
    objs = [puffy("Bolt", bolt, mat("Bolt", "#FFD93C", rough=0.25, emit=0.15), depth=0.14, bevel=0.07)]
    group("Power", objs, rot=(0, 0, -10))


def _ticket(color):
    body = rrect_pts(1.7, 0.95, 0.12)
    objs = [puffy("Ticket", body, mat("Ticket" + color, color), depth=0.1, bevel=0.05)]
    objs.append(puffy("Star", star_pts(0.28, 0.12), mat("White", "#FFFFFF", rough=0.4), depth=0.02, bevel=0.035,
                      loc=(0, -0.18, 0), ol=0.03))
    group("TicketGroup", objs, rot=(0, 0, -16))


def build_ticket():
    _ticket("#FF5FC0")


def build_companionTicket():
    _ticket("#9C6BFF")


def build_coin():
    gold = mat("Gold", "#FFC93C", rough=0.22, metal=0.75)
    objs = [
        prim("cyl", "Coin", gold, rot=(90, 0, 0), scale=(0.95, 0.95, 0.16), vertices=64, bevel=0.05),
        puffy("Star", star_pts(0.45, 0.2), mat("GoldLight", "#FFE27A", rough=0.2, metal=0.6), depth=0.02, bevel=0.04,
              loc=(0, -0.2, 0), ol=0.03),
    ]
    group("Coin", objs, rot=(0, 0, -25))


def build_crown():
    gold = mat("Gold", "#FFC93C", rough=0.25, metal=0.6)
    crown = [(-0.85, -0.5), (-0.95, 0.55), (-0.45, 0.1), (0, 0.8), (0.45, 0.1), (0.95, 0.55), (0.85, -0.5)]
    objs = [puffy("Crown", crown, gold, depth=0.14, bevel=0.07)]
    for x, c in ((-0.45, "#FF4FB4"), (0, "#3EE6C8"), (0.45, "#FF4FB4")):
        objs.append(prim("sphere", "Gem", mat("Gem" + c, c, rough=0.1), loc=(x, -0.2, -0.22), scale=(0.11, 0.11, 0.11),
                         segments=24, ring_count=12, ol=0.02))
    group("CrownG", objs)


ALL = ["book", "style", "crew", "slots", "bonus", "settings", "gift", "power", "ticket", "companionTicket", "coin", "crown"]


def build(name):
    reset()
    globals()["build_" + name]()
    return render_icon(name)
