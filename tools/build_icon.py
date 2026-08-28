#!/usr/bin/env python3
"""Génère l'icône de Barbouille et toutes ses déclinaisons iOS et Android.

L'icône dit ce que fait l'application en deux éléments : un gribouillage
multicolore, et le crayon qui vient de le tracer. Rien d'autre — une icône se
lit à 40 points sur un écran d'accueil encombré.

    python3 tools/build_icon.py
"""
import os
from math import cos, sin, radians

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")

S = 4096          # rendu supersamplé, réduit ensuite : bords propres sans SVG
MASTER = 1024

INK = (27, 25, 23)
PAPER_TOP = (255, 249, 236)
PAPER_BOTTOM = (255, 231, 193)
BODY = (91, 75, 214)        # l'indigo de l'application
BAND = (255, 252, 246)
TIP = (255, 216, 77)

# Les cinq couleurs du gribouillage, prises dans la palette livrée.
SCRIBBLE = [(226, 59, 59), (255, 138, 61), (255, 216, 77),
            (99, 193, 50), (44, 123, 229)]


def k(v):
    """Coordonnée exprimée sur 1024, ramenée à l'échelle de rendu."""
    return v * S / 1024


def background(img):
    """Dégradé chaud vertical : le papier sur lequel on colorie."""
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / S
        d.line(
            [(0, y), (S, y)],
            fill=tuple(
                round(a + (b - a) * t) for a, b in zip(PAPER_TOP, PAPER_BOTTOM)
            ),
        )


def scribble_points():
    """Une courbe en S, du bas-gauche vers le haut-droit."""
    pts = []
    for i in range(121):
        t = i / 120
        x = 168 + t * 660
        y = 660 - t * 400 + sin(radians(t * 360 - 40)) * 96
        pts.append((k(x), k(y)))
    return pts


def draw_scribble(d):
    pts = scribble_points()
    width = k(112)

    # Contour d'encre, posé d'abord : la couleur vient ensuite par-dessus,
    # comme dans l'application où le trait noir borde chaque zone.
    d.line(pts, fill=INK, width=int(width + k(30)), joint="curve")
    for p in (pts[0], pts[-1]):
        r = (width + k(30)) / 2
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=INK)

    # Cinq segments colorés qui se recouvrent, sans couture visible.
    n = len(pts)
    step = n / len(SCRIBBLE)
    for i, color in enumerate(SCRIBBLE):
        a = max(0, int(i * step) - 2)
        b = min(n, int((i + 1) * step) + 3)
        d.line(pts[a:b], fill=color, width=int(width), joint="curve")
    for p, color in ((pts[0], SCRIBBLE[0]), (pts[-1], SCRIBBLE[-1])):
        r = width / 2
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)


def rotate_about(points, cx, cy, deg):
    a = radians(deg)
    return [
        (cx + (x - cx) * cos(a) - (y - cy) * sin(a),
         cy + (x - cx) * sin(a) + (y - cy) * cos(a))
        for x, y in points
    ]


def draw_crayon(img):
    """Le crayon, dessiné à plat puis pivoté : le calque séparé évite que la
    rotation ne crénèle le fond."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    cx, cy = k(672), k(648)
    w, h = k(224), k(524)
    left, right = cx - w / 2, cx + w / 2
    top, bottom = cy - h / 2, cy + h / 2
    tip_len = k(168)
    out = int(k(26))

    body = [(left, top + tip_len), (right, top + tip_len),
            (right, bottom), (left, bottom)]
    tip = [(left, top + tip_len), (cx, top), (right, top + tip_len)]
    band = [(left, top + tip_len + k(74)), (right, top + tip_len + k(74)),
            (right, top + tip_len + k(196)), (left, top + tip_len + k(196))]

    d.polygon(body, fill=BODY, outline=INK, width=out)
    d.polygon(tip, fill=TIP, outline=INK, width=out)
    d.polygon(band, fill=BAND, outline=INK, width=out)
    # Le trait de pointe redessiné : la jonction cône/corps doit rester franche.
    d.line([(left, top + tip_len), (right, top + tip_len)], fill=INK, width=out)

    layer = layer.rotate(-28, resample=Image.BICUBIC, center=(cx, cy))
    img.alpha_composite(layer)


def build_master(content_scale=1.0):
    """Icône complète.

    `content_scale` réduit le dessin sans toucher au fond : les icônes
    « maskable » d'Android peuvent être rognées jusqu'à leur cercle intérieur,
    et le crayon doit y survivre.
    """
    bg = Image.new("RGBA", (S, S), PAPER_TOP + (255,))
    background(bg)

    content = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_scribble(ImageDraw.Draw(content))
    draw_crayon(content)

    if content_scale != 1.0:
        n = int(S * content_scale)
        content = content.resize((n, n), Image.LANCZOS)
        placed = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        placed.paste(content, ((S - n) // 2, (S - n) // 2), content)
        content = placed

    bg.alpha_composite(content)
    return bg.resize((MASTER, MASTER), Image.LANCZOS).convert("RGB")


IOS = [
    ("Icon-App-20x20@1x.png", 20), ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60), ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58), ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40), ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120), ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180), ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152), ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

ANDROID = [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
           ("xxhdpi", 144), ("xxxhdpi", 192)]

# Le web sert aussi d'installation sur l'écran d'accueil d'un iPhone : les
# icônes doivent donc être les vraies, pas celles de démonstration de Flutter.
WEB = [("Icon-192.png", 192, False), ("Icon-512.png", 512, False),
       ("Icon-maskable-192.png", 192, True), ("Icon-maskable-512.png", 512, True),
       ("apple-touch-icon.png", 180, False)]


def main():
    master = build_master()
    # iOS applique son propre masque arrondi : le dessin va bord à bord.
    maskable = build_master(content_scale=0.70)
    master.save(os.path.join(ROOT, "docs", "icon-1024.png"))

    ios_dir = os.path.join(ROOT, "app", "ios", "Runner",
                           "Assets.xcassets", "AppIcon.appiconset")
    for name, size in IOS:
        # iOS n'accepte aucune transparence dans une icône d'application, et
        # applique lui-même le masque arrondi : on livre un carré plein.
        master.resize((size, size), Image.LANCZOS).save(
            os.path.join(ios_dir, name))

    res = os.path.join(ROOT, "app", "android", "app", "src", "main", "res")
    for folder, size in ANDROID:
        master.resize((size, size), Image.LANCZOS).save(
            os.path.join(res, f"mipmap-{folder}", "ic_launcher.png"))

    web = os.path.join(ROOT, "app", "web")
    for name, size, is_maskable in WEB:
        src = maskable if is_maskable else master
        src.resize((size, size), Image.LANCZOS).save(
            os.path.join(web, "icons", name))
    master.resize((32, 32), Image.LANCZOS).save(os.path.join(web, "favicon.png"))

    print(f"icône générée : {len(IOS)} tailles iOS, "
          f"{len(ANDROID)} densités Android, {len(WEB)} déclinaisons web")


if __name__ == "__main__":
    main()
