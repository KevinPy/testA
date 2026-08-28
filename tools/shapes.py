"""Primitives géométriques pour composer les dessins au trait (line art) de Barbouille.

Chaque dessin est décrit en coordonnées « page » (viewBox 1000x1000) et exporté
en données de chemin SVG, consommées à l'exécution par `path_drawing`.
Le vectoriel garantit des zones exactes et une netteté indépendante de l'écran.
"""
from math import cos, sin, pi

K = 0.5522847498307936  # constante de Bézier pour approcher un quart de cercle


def _f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0"


def ellipse(cx, cy, rx, ry):
    ox, oy = rx * K, ry * K
    return (
        f"M {_f(cx - rx)} {_f(cy)} "
        f"C {_f(cx - rx)} {_f(cy - oy)} {_f(cx - ox)} {_f(cy - ry)} {_f(cx)} {_f(cy - ry)} "
        f"C {_f(cx + ox)} {_f(cy - ry)} {_f(cx + rx)} {_f(cy - oy)} {_f(cx + rx)} {_f(cy)} "
        f"C {_f(cx + rx)} {_f(cy + oy)} {_f(cx + ox)} {_f(cy + ry)} {_f(cx)} {_f(cy + ry)} "
        f"C {_f(cx - ox)} {_f(cy + ry)} {_f(cx - rx)} {_f(cy + oy)} {_f(cx - rx)} {_f(cy)} Z"
    )


def circle(cx, cy, r):
    return ellipse(cx, cy, r, r)


def rrect(x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    o = r * K
    x2, y2 = x + w, y + h
    return (
        f"M {_f(x + r)} {_f(y)} L {_f(x2 - r)} {_f(y)} "
        f"C {_f(x2 - r + o)} {_f(y)} {_f(x2)} {_f(y + r - o)} {_f(x2)} {_f(y + r)} "
        f"L {_f(x2)} {_f(y2 - r)} "
        f"C {_f(x2)} {_f(y2 - r + o)} {_f(x2 - r + o)} {_f(y2)} {_f(x2 - r)} {_f(y2)} "
        f"L {_f(x + r)} {_f(y2)} "
        f"C {_f(x + r - o)} {_f(y2)} {_f(x)} {_f(y2 - r + o)} {_f(x)} {_f(y2 - r)} "
        f"L {_f(x)} {_f(y + r)} "
        f"C {_f(x)} {_f(y + r - o)} {_f(x + r - o)} {_f(y)} {_f(x + r)} {_f(y)} Z"
    )


def poly(points, close=True):
    d = f"M {_f(points[0][0])} {_f(points[0][1])}"
    for p in points[1:]:
        d += f" L {_f(p[0])} {_f(p[1])}"
    return d + (" Z" if close else "")


def smooth(points, close=True, tension=1.0):
    """Catmull-Rom converti en Béziers cubiques : contours organiques et doux."""
    n = len(points)
    d = f"M {_f(points[0][0])} {_f(points[0][1])}"
    last = n if close else n - 1
    for i in range(last):
        p0 = points[(i - 1) % n] if close else points[max(i - 1, 0)]
        p1 = points[i % n]
        p2 = points[(i + 1) % n]
        p3 = points[(i + 2) % n] if close else points[min(i + 2, n - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6 * tension, p1[1] + (p2[1] - p0[1]) / 6 * tension)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6 * tension, p2[1] - (p3[1] - p1[1]) / 6 * tension)
        d += f" C {_f(c1[0])} {_f(c1[1])} {_f(c2[0])} {_f(c2[1])} {_f(p2[0])} {_f(p2[1])}"
    return d + (" Z" if close else "")


def blob(cx, cy, rx, ry, n=10, wobble=0.0, phase=0.0, seed=0):
    """Forme fermée organique : un ovale légèrement irrégulier."""
    import random
    rng = random.Random(seed)
    pts = []
    for i in range(n):
        a = phase + 2 * pi * i / n
        k = 1 + (rng.uniform(-wobble, wobble) if wobble else 0)
        pts.append((cx + cos(a) * rx * k, cy + sin(a) * ry * k))
    return smooth(pts)


def star(cx, cy, r_out, r_in, branches=5, phase=-pi / 2):
    pts = []
    for i in range(branches * 2):
        r = r_out if i % 2 == 0 else r_in
        a = phase + pi * i / branches
        pts.append((cx + cos(a) * r, cy + sin(a) * r))
    return poly(pts)


def petal(cx, cy, angle, length, width):
    """Pétale en goutte, orientée depuis le centre (cx, cy)."""
    ax, ay = cos(angle), sin(angle)
    px, py = -ay, ax
    tip = (cx + ax * length, cy + ay * length)
    base = (cx + ax * length * 0.12, cy + ay * length * 0.12)
    c1 = (cx + ax * length * 0.25 + px * width, cy + ay * length * 0.25 + py * width)
    c2 = (cx + ax * length * 0.85 + px * width * 0.75, cy + ay * length * 0.85 + py * width * 0.75)
    c3 = (cx + ax * length * 0.85 - px * width * 0.75, cy + ay * length * 0.85 - py * width * 0.75)
    c4 = (cx + ax * length * 0.25 - px * width, cy + ay * length * 0.25 - py * width)
    return (
        f"M {_f(base[0])} {_f(base[1])} "
        f"C {_f(c1[0])} {_f(c1[1])} {_f(c2[0])} {_f(c2[1])} {_f(tip[0])} {_f(tip[1])} "
        f"C {_f(c3[0])} {_f(c3[1])} {_f(c4[0])} {_f(c4[1])} {_f(base[0])} {_f(base[1])} Z"
    )


def arc(x1, y1, x2, y2, bow=0.3):
    """Arc ouvert simple entre deux points (trait de détail)."""
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    dx, dy = x2 - x1, y2 - y1
    cx, cy = mx - dy * bow, my + dx * bow
    return f"M {_f(x1)} {_f(y1)} Q {_f(cx)} {_f(cy)} {_f(x2)} {_f(y2)}"


def line(x1, y1, x2, y2):
    return f"M {_f(x1)} {_f(y1)} L {_f(x2)} {_f(y2)}"
