# Générateur des icônes « simulateur » de Baddie Clicker (vectoriel, sans Blender).
# Style : chaque forme a son dégradé (clair en haut → sombre en bas), un reflet arrondi en haut à gauche,
# une ombre interne en bas et un contour sombre épais ; ombre portée douce sous l'icône.
# Usage : python icons_sim.py <dossier de sortie>  puis  node export.mjs icons-sim
import math
import os
import sys

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
INK = "#1A1030"


def rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def mix(h, other, t):
    a, b = rgb(h), rgb(other)
    return "#" + "".join(f"{round(a[i] + (b[i] - a[i]) * t):02X}" for i in range(3))


def light(h, t=0.35):
    return mix(h, "#FFFFFF", t)


def dark(h, t=0.3):
    return mix(h, "#000000", t)


class Icon:
    def __init__(self, name):
        self.name = name
        self.shapes = []  # (d, color, gloss)

    def add(self, d, color, gloss=True):
        self.shapes.append((d, color, gloss))
        return self

    def write(self):
        defs, body, shadow, outline = [], [], [], []
        for i, (d, color, gloss) in enumerate(self.shapes):
            gid, cid, hid = f"g{i}", f"c{i}", f"h{i}"
            defs.append(
                f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
                f'<stop offset="0" stop-color="{light(color, 0.28)}"/><stop offset="0.5" stop-color="{color}"/>'
                f'<stop offset="1" stop-color="{dark(color, 0.22)}"/></linearGradient>'
                f'<clipPath id="{cid}"><path d="{d}"/></clipPath>'
                f'<radialGradient id="{hid}" cx="0.3" cy="0.22" r="0.55">'
                f'<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.75"/>'
                f'<stop offset="0.6" stop-color="#FFFFFF" stop-opacity="0.12"/>'
                f'<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>'
            )
            shadow.append(f'<path d="{d}"/>')
            outline.append(f'<path d="{d}"/>')
            body.append(f'<path d="{d}" fill="url(#{gid})"/>')
            if gloss:
                # ombre interne en bas puis reflet arrondi en haut à gauche, limités à la forme
                body.append(f'<g clip-path="url(#{cid})"><path d="{d}" fill="none" stroke="{dark(color, 0.35)}" '
                            f'stroke-width="18" transform="translate(0 -9)" opacity="0.55"/>'
                            f'<rect x="0" y="0" width="256" height="256" fill="url(#{hid})"/></g>')
        svg = (
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">'
            f'<defs>{"".join(defs)}</defs>'
            f'<g fill="{INK}" opacity="0.35" transform="translate(4 9)">{"".join(shadow)}</g>'
            f'<g fill="none" stroke="{INK}" stroke-width="20" stroke-linejoin="round" stroke-linecap="round">{"".join(outline)}</g>'
            f'{"".join(body)}</svg>'
        )
        open(os.path.join(out, self.name + ".svg"), "w", encoding="utf-8").write(svg)


def poly(points):
    return "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in points) + " Z"


def rrect(x, y, w, h, r):
    return (f"M{x + r} {y} H{x + w - r} Q{x + w} {y} {x + w} {y + r} V{y + h - r} Q{x + w} {y + h} {x + w - r} {y + h} "
            f"H{x + r} Q{x} {y + h} {x} {y + h - r} V{y + r} Q{x} {y} {x + r} {y} Z")


def circle(cx, cy, r):
    return f"M{cx - r} {cy} A{r} {r} 0 1 0 {cx + r} {cy} A{r} {r} 0 1 0 {cx - r} {cy} Z"


def ellipse(cx, cy, rx, ry):
    return f"M{cx - rx} {cy} A{rx} {ry} 0 1 0 {cx + rx} {cy} A{rx} {ry} 0 1 0 {cx - rx} {cy} Z"


def star(cx, cy, R, r, n=5, rot=-90):
    return poly([(cx + (R if i % 2 == 0 else r) * math.cos(math.radians(rot + i * 180 / n)),
                  cy + (R if i % 2 == 0 else r) * math.sin(math.radians(rot + i * 180 / n))) for i in range(2 * n)])


# book : livre bleu épais vu de 3/4 (tranche crème), couronne dorée, ruban rose
Icon("book").add(poly([(70, 52), (196, 40), (206, 196), (80, 214)]), "#F4E8D2", gloss=False) \
    .add(rrect(46, 36, 140, 182, 16), "#2F8CFF") \
    .add(rrect(46, 36, 26, 182, 10), "#1F63D6", gloss=False) \
    .add(poly([(92, 118), (86, 78), (110, 98), (126, 68), (142, 98), (166, 78), (160, 118)]), "#FFC93C") \
    .add(poly([(148, 200), (176, 200), (176, 242), (162, 230), (148, 242)]), "#FF4FB4").write()
# style : t-shirt rose avec étoile
Icon("style").add("M84 44 L108 44 Q128 72 148 44 L172 44 L230 82 L206 128 L184 114 L184 218 L72 218 L72 114 "
                  "L50 128 L26 82 Z", "#FF5FC0").add(star(128, 148, 36, 16), "#FFFFFF").write()
# crew : deux personnages (tête + buste), violet
Icon("crew").add("M136 214 Q136 142 184 142 Q232 142 232 214 Z", "#B48CF0") \
    .add(circle(184, 100, 36), "#FFC9A3") \
    .add("M148 96 Q150 58 184 58 Q218 58 220 96 Q200 80 184 82 Q166 80 148 96 Z", "#7A4BE0") \
    .add("M24 224 Q24 140 92 140 Q160 140 160 224 Z", "#8A5CF6") \
    .add(circle(92, 92, 42), "#FFC9A3") \
    .add("M50 90 Q52 46 92 46 Q132 46 134 90 Q110 70 92 72 Q72 70 50 90 Z", "#5B2FC2").write()
# slots (équipe) : trois cartes en éventail dorées
def card(cx, cy, ang, w=96, h=136):
    a = math.radians(ang)
    pts = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    return poly([(cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)) for x, y in pts])
Icon("slots").add(card(80, 136, -20), "#F29A12").add(card(176, 136, 20), "#F29A12") \
    .add(rrect(80, 56, 96, 140, 12), "#FFC93C").add(star(128, 126, 32, 14), "#FFFFFF").write()
# bonus : roue à segments, jante dorée, moyeu blanc, pointeur rouge
wheel = Icon("bonus").add(circle(128, 140, 100), "#FFC93C")
cols = ["#FF8A3C", "#FFE066", "#FF5A8A", "#7FE3FF", "#FF8A3C", "#FFE066", "#FF5A8A", "#8CF07F"]
for i, c in enumerate(cols):
    a0, a1 = math.radians(-90 + i * 45), math.radians(-90 + (i + 1) * 45)
    r = 80
    wheel.add(f"M128 140 L{128 + r * math.cos(a0):.1f} {140 + r * math.sin(a0):.1f} A{r} {r} 0 0 1 "
              f"{128 + r * math.cos(a1):.1f} {140 + r * math.sin(a1):.1f} Z", c, gloss=False)
wheel.add(circle(128, 140, 20), "#FFFFFF").add(poly([(106, 18), (150, 18), (128, 60)]), "#FF2E4D").write()
# settings : engrenage acier
pts = []
for i in range(9 * 4):
    a = 2 * math.pi * i / 36
    rad = 104 if (i % 4) in (1, 2) else 80
    pts.append((128 + rad * math.cos(a), 128 + rad * math.sin(a)))
Icon("settings").add(poly(pts), "#AEB6D4").add(circle(128, 128, 34), "#5A6386", gloss=False).write()
# gift : boîte orange, couvercle, ruban et nœud roses
Icon("gift").add(rrect(46, 110, 164, 116, 14), "#FF8A3C").add(rrect(32, 82, 192, 46, 12), "#FFA14F") \
    .add(rrect(112, 82, 32, 144, 4), "#FF4FB4", gloss=False) \
    .add("M128 84 Q80 30 66 62 Q58 92 128 84 Z", "#FF4FB4").add("M128 84 Q176 30 190 62 Q198 92 128 84 Z", "#FF4FB4").write()
# power : éclair jaune
Icon("power").add(poly([(152, 20), (58, 148), (116, 148), (96, 236), (198, 100), (138, 100)]), "#FFD93C").write()
# tickets : rose (baddie) et violet (compagnon), encoches latérales, étoile
tk = "M30 74 H226 V110 Q204 128 226 146 V182 H30 V146 Q52 128 30 110 Z"
Icon("ticket").add(tk, "#FF5FC0").add(star(128, 128, 32, 14), "#FFFFFF").write()
Icon("companionTicket").add(tk, "#9C6BFF").add(circle(128, 114, 16), "#FFFFFF") \
    .add("M98 162 Q98 136 128 136 Q158 136 158 162 Z", "#FFFFFF").write()
# coin : pièce dorée à double bord et étoile
Icon("coin").add(circle(128, 128, 100), "#F2B530").add(circle(128, 128, 76), "#FFC93C").add(star(128, 132, 44, 19), "#FFE88A").write()
# crown : couronne dorée à gemmes
Icon("crown").add(poly([(32, 196), (24, 72), (82, 124), (128, 44), (174, 124), (232, 72), (224, 196)]), "#FFC93C") \
    .add(rrect(32, 186, 192, 36, 10), "#F2A520") \
    .add(circle(82, 166, 13), "#FF4FB4").add(circle(128, 160, 15), "#3EE6C8").add(circle(174, 166, 13), "#FF4FB4").write()
# lock : cadenas
Icon("lock").add("M80 120 V90 Q80 40 128 40 Q176 40 176 90 V120 H148 V92 Q148 68 128 68 Q108 68 108 92 V120 Z", "#8C95B8") \
    .add(rrect(54, 114, 148, 112, 18), "#C4CBE6").add(circle(128, 162, 16), INK, gloss=False).write()
# door : arche cyan lumineuse
Icon("door").add("M54 228 V104 Q54 30 128 30 Q202 30 202 104 V228 Z", "#3EE6C8") \
    .add("M82 228 V108 Q82 60 128 60 Q174 60 174 108 V228 Z", "#2B1F4A", gloss=False) \
    .add(star(128, 150, 32, 14), "#7FF5E2").write()
print("ok", len([f for f in os.listdir(out) if f.endswith(".svg")]))
