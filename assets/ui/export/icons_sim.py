# Générateur des icônes « simulateur » de Baddie Clicker (style plein, contour épais, reflet, ombre)
import math, os, sys
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
INK = "#1A1030"

def svg(name, top, bottom, shapes, extra=""):
    # shapes : liste de (d, fill?) ; le premier utilise le dégradé principal
    body = []
    for d, fill in shapes:
        body.append(f'<path d="{d}" fill="{fill or "url(#g)"}"/>')
    shadow = "".join(f'<path d="{d}"/>' for d, _ in shapes)
    outline = "".join(f'<path d="{d}"/>' for d, _ in shapes)
    s = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>
<clipPath id="c">{outline}</clipPath></defs>
<g fill="{INK}" opacity="0.45" transform="translate(0 10)">{shadow}</g>
<g fill="none" stroke="{INK}" stroke-width="22" stroke-linejoin="round" stroke-linecap="round">{outline}</g>
{"".join(body)}
<rect x="0" y="0" width="256" height="104" fill="#FFFFFF" opacity="0.22" clip-path="url(#c)"/>
{extra}
</svg>'''
    open(os.path.join(out, name + ".svg"), "w", encoding="utf-8").write(s)

def poly(points):
    return "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in points) + " Z"

def rrect(x, y, w, h, r):
    return f"M{x+r} {y} H{x+w-r} Q{x+w} {y} {x+w} {y+r} V{y+h-r} Q{x+w} {y+h} {x+w-r} {y+h} H{x+r} Q{x} {y+h} {x} {y+h-r} V{y+r} Q{x} {y} {x+r} {y} Z"

def circle(cx, cy, r):
    return f"M{cx-r} {cy} A{r} {r} 0 1 0 {cx+r} {cy} A{r} {r} 0 1 0 {cx-r} {cy} Z"

def star(cx, cy, R, r, n=5, rot=-90):
    pts = []
    for i in range(2 * n):
        a = math.radians(rot + i * 180 / n)
        rad = R if i % 2 == 0 else r
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return poly(pts)

W = "#FFFFFF"
# book : couverture bleue, tranche crème, ruban rose, couronne
svg("book", "#5CC2FF", "#1B6FE0", [
    (rrect(52, 40, 150, 180, 18), None),
    (rrect(170, 52, 28, 156, 8), "#F4EEE7"),
    (poly([(80, 200), (80, 240), (96, 226), (112, 240), (112, 200)]), "#FF5FD2"),
    (poly([(82, 118), (90, 86), (110, 106), (124, 78), (138, 106), (158, 86), (166, 118)]), "#FFD54A"),
])
# style : haut à bretelles rose avec étoile
svg("style", "#FF9BDD", "#E0369E", [
    ("M86 40 L106 40 Q128 70 150 40 L170 40 L170 86 Q206 120 200 220 L56 220 Q50 120 86 86 Z", None),
    (star(128, 150, 34, 15), "#FFFFFF"),
])
# crew : deux silhouettes violettes
svg("crew", "#C9A8FF", "#6E44D9", [
    (circle(170, 80, 30), "#9A72F0"),
    ("M124 140 Q140 124 170 124 Q226 124 226 200 L160 200 Q160 160 124 140 Z", "#9A72F0"),
    (circle(92, 92, 34), None),
    ("M30 214 Q30 140 92 140 Q154 140 154 214 Z", None),
])
# slots (équipe) : trois cartes en éventail dorées
def card(cx, cy, ang, w=84, h=124):
    a = math.radians(ang)
    pts = [(-w/2, -h/2), (w/2, -h/2), (w/2, h/2), (-w/2, h/2)]
    return poly([(cx + x*math.cos(a) - y*math.sin(a), cy + x*math.sin(a) + y*math.cos(a)) for x, y in pts])
svg("slots", "#FFE27A", "#E39A12", [
    (card(86, 140, -18), "#F2B530"),
    (card(170, 140, 18), "#F2B530"),
    (card(128, 128, 0), None),
    (star(128, 128, 30, 13), "#FFFFFF"),
])
# bonus : roue à segments orange/jaune + pointeur
segs = []
cols = ["#FFB347", "#F2552C", "#FFD54A", "#FF7A3C", "#FFC93C", "#F2552C"]
for i in range(6):
    a0, a1 = math.radians(-90 + i * 60), math.radians(-90 + (i + 1) * 60)
    r = 92
    segs.append((f"M128 136 L{128 + r*math.cos(a0):.1f} {136 + r*math.sin(a0):.1f} A{r} {r} 0 0 1 {128 + r*math.cos(a1):.1f} {136 + r*math.sin(a1):.1f} Z", cols[i]))
svg("bonus", "#FFB347", "#F2552C", [(circle(128, 136, 96), None)] + segs + [
    (circle(128, 136, 20), "#FFFFFF"),
    (poly([(108, 20), (148, 20), (128, 56)]), "#FF2E4D"),
])
# settings : engrenage gris
pts = []
for i in range(16):
    a = math.radians(i * 22.5)
    rad = 98 if i % 2 == 0 else 74
    for da in (-7, 7):
        b = a + math.radians(da)
        pts.append((128 + rad * math.cos(b), 128 + rad * math.sin(b)))
svg("settings", "#C4CBE6", "#5A6386", [(poly(pts), None), (circle(128, 128, 30), "#2B1F4A")])
# power : éclair jaune
svg("power", "#FFF07A", "#FFB300", [(poly([(150, 24), (62, 146), (118, 146), (100, 232), (194, 104), (136, 104)]), None)])
# ticket baddie (rose) et compagnon (violet)
tk = "M36 76 H220 V112 Q200 128 220 144 V180 H36 V144 Q56 128 36 112 Z"
svg("ticket", "#FF9BDD", "#E0369E", [(tk, None), (star(128, 128, 30, 13), "#FFFFFF")])
svg("companionTicket", "#C9A8FF", "#6E44D9", [(tk, None), (circle(128, 116, 14), "#FFFFFF"), ("M100 160 Q100 136 128 136 Q156 136 156 160 Z", "#FFFFFF")])
# coin : pièce dorée avec étoile
svg("coin", "#FFE27A", "#D7A746", [(circle(128, 128, 96), None), (circle(128, 128, 70), "#F2B530"), (star(128, 130, 40, 17), "#FFF4C2")])
# gift : boîte orange, ruban rose
svg("gift", "#FFB347", "#F2552C", [
    (rrect(48, 112, 160, 112, 14), None),
    (rrect(36, 84, 184, 44, 12), "#FF9A3C"),
    (rrect(112, 84, 32, 140, 4), "#FF5FD2"),
    ("M128 86 Q84 36 72 64 Q64 90 128 86 Z", "#FF5FD2"),
    ("M128 86 Q172 36 184 64 Q192 90 128 86 Z", "#FF5FD2"),
])
# lock : cadenas
svg("lock", "#C4CBE6", "#5A6386", [
    ("M80 120 V88 Q80 40 128 40 Q176 40 176 88 V120 H148 V90 Q148 66 128 66 Q108 66 108 90 V120 Z", "#8C95B8"),
    (rrect(56, 116, 144, 108, 18), None),
    (circle(128, 162, 16), INK),
])
# door : arche cyan lumineuse
svg("door", "#7FF5E2", "#13A6B5", [
    ("M56 228 V104 Q56 32 128 32 Q200 32 200 104 V228 Z", None),
    ("M84 228 V108 Q84 62 128 62 Q172 62 172 108 V228 Z", "#2B1F4A"),
    (star(128, 150, 30, 13), "#7FF5E2"),
])
# crown : couronne dorée
svg("crown", "#FFE27A", "#D7A746", [
    (poly([(36, 196), (28, 76), (84, 128), (128, 52), (172, 128), (228, 76), (220, 196)]), None),
    (rrect(36, 188, 184, 34, 10), "#F2B530"),
    (circle(128, 150, 14), "#FF5FD2"),
])
print("ok", len(os.listdir(out)))
