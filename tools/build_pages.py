#!/usr/bin/env python3
"""Génère lib/data/pages.g.dart : la bibliothèque de dessins au trait de Barbouille.

Modèle d'un dessin :
  - `regions` : formes fermées, coloriables. L'ordre = ordre de peinture
    (les dernières sont « au-dessus »), et l'ordre inverse sert au test de
    contact (tap) : la zone la plus haute gagne.
  - `details` : traits d'encre seuls (moustaches, sourire...), non coloriables.

Tout le trait noir est redessiné PAR-DESSUS la couleur de l'enfant : c'est ce qui
rend le résultat toujours propre, quoi que l'enfant barbouille.
"""
import sys, os
from math import pi, cos, sin
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shapes import *  # noqa

PAGES = []


def page(pid, title, category, emoji, regions, details=(), width=1000, height=1000):
    """`title` est un couple (français, anglais) ; `category` un identifiant
    dont le libellé est traduit dans AppStrings.category()."""
    PAGES.append(dict(id=pid, title=title, category=category, emoji=emoji,
                      width=width, height=height,
                      regions=[dict(id=r[0], d=r[1], hint=r[2] if len(r) > 2 else None) for r in regions],
                      details=[dict(d=d[0],
                                    w=d[1] if len(d) > 1 else 6.0,
                                    clip=d[2] if len(d) > 2 else None) for d in details]))


# ─────────────────────────────── ANIMAUX ────────────────────────────────────
def chat():
    r, d = [], []
    r.append(("queue", smooth([(700, 782), (872, 800), (950, 686), (900, 556), (806, 572),
                               (866, 664), (836, 748), (700, 730)]), 0xFFF6A93B))
    r.append(("corps", smooth([(500, 470), (700, 520), (760, 720), (720, 860), (500, 890),
                               (280, 860), (240, 720), (300, 520)]), 0xFFF6A93B))
    r.append(("patte_g", ellipse(370, 862, 82, 48), 0xFFF6A93B))
    r.append(("patte_d", ellipse(630, 862, 82, 48), 0xFFF6A93B))
    r.append(("ventre", ellipse(500, 730, 130, 150), 0xFFFDE8C8))
    r.append(("oreille_g", poly([(300, 330), (272, 110), (440, 250)]), 0xFFF6A93B))
    r.append(("oreille_d", poly([(700, 330), (728, 110), (560, 250)]), 0xFFF6A93B))
    # L'oreille interne est l'oreille réduite vers sa pointe : elle reste donc
    # dans la partie qui dépasse de la tête, la seule qui soit visible.
    def _inner(apex, a, b, k=0.62):
        sc = lambda p: (apex[0] + (p[0] - apex[0]) * k, apex[1] + (p[1] - apex[1]) * k)
        return poly([apex, sc(a), sc(b)])
    r.append(("oreille_int_g", _inner((272, 110), (300, 330), (440, 250), 0.42), 0xFFF48FB1))
    r.append(("oreille_int_d", _inner((728, 110), (700, 330), (560, 250), 0.42), 0xFFF48FB1))
    r.append(("tete", ellipse(500, 380, 235, 205), 0xFFF6A93B))
    r.append(("oeil_g", ellipse(415, 355, 45, 55), 0xFF6BC46B))
    r.append(("oeil_d", ellipse(585, 355, 45, 55), 0xFF6BC46B))
    r.append(("museau", ellipse(500, 460, 110, 72), 0xFFFDE8C8))
    r.append(("nez", smooth([(500, 490), (462, 440), (538, 440)]), 0xFFF48FB1))
    d.append((circle(415, 362, 20), 0))       # pupilles pleines
    d.append((circle(585, 362, 20), 0))
    d.append((arc(452, 492, 500, 500, 0.35),))
    d.append((arc(500, 500, 548, 492, 0.35),))
    d.append((line(250, 430, 90, 396),))
    d.append((line(250, 462, 96, 470),))
    d.append((line(252, 494, 104, 542),))
    d.append((line(750, 430, 910, 396),))
    d.append((line(750, 462, 904, 470),))
    d.append((line(748, 494, 896, 542),))
    page("chat", ("Le chat câlin", "The cuddly cat"), "animaux", "🐱", r, d)


def poisson():
    r, d = [], []
    r.append(("nageoire_haute", smooth([(470, 330), (560, 170), (660, 300)]), 0xFF56B4E9))
    r.append(("nageoire_basse", smooth([(470, 690), (560, 840), (660, 720)]), 0xFF56B4E9))
    r.append(("queue", smooth([(760, 500), (930, 330), (900, 500), (930, 680)]), 0xFF56B4E9))
    r.append(("corps", smooth([(300, 500), (420, 300), (640, 268), (790, 420), (800, 580),
                               (640, 732), (420, 700)]), 0xFFF6A93B))
    r.append(("tete", smooth([(300, 500), (340, 336), (430, 300), (452, 500), (430, 700), (340, 664)]), 0xFFFFD166))
    r.append(("nageoire_laterale", smooth([(520, 560), (620, 600), (560, 690)]), 0xFFEF6F6C))
    r.append(("ecaille1", circle(560, 400, 52), 0xFFEF6F6C))
    r.append(("ecaille2", circle(672, 420, 52), 0xFF9B7BD4))
    r.append(("ecaille3", circle(616, 520, 52), 0xFF6BC46B))
    r.append(("ecaille4", circle(728, 540, 52), 0xFFFFD166))
    r.append(("oeil", circle(372, 452, 46), 0xFFFFFFFF))
    d.append((circle(378, 456, 20), 0))
    d.append((arc(300, 560, 336, 620, -0.3),))
    page("poisson", ("Le poisson rigolo", "The funny fish"), "animaux", "🐠", r, d)


def papillon():
    r, d = [], []
    r.append(("aile_hg", smooth([(470, 430), (300, 250), (140, 300), (150, 470), (300, 520)]), 0xFF9B7BD4))
    r.append(("aile_hd", smooth([(530, 430), (700, 250), (860, 300), (850, 470), (700, 520)]), 0xFF9B7BD4))
    r.append(("aile_bg", smooth([(470, 540), (330, 620), (280, 790), (420, 800), (490, 660)]), 0xFFEF6F6C))
    r.append(("aile_bd", smooth([(530, 540), (670, 620), (720, 790), (580, 800), (510, 660)]), 0xFFEF6F6C))
    r.append(("pois1", circle(280, 380, 48), 0xFFFFD166))
    r.append(("pois2", circle(720, 380, 48), 0xFFFFD166))
    r.append(("pois3", circle(390, 700, 34), 0xFFFFFFFF))
    r.append(("pois4", circle(610, 700, 34), 0xFFFFFFFF))
    r.append(("corps", smooth([(500, 300), (545, 400), (540, 640), (500, 800), (460, 640), (455, 400)]), 0xFF4A4A4A))
    r.append(("tete", circle(500, 268, 56), 0xFF4A4A4A))
    d.append((smooth([(478, 226), (430, 130), (360, 110)], close=False),))
    d.append((smooth([(522, 226), (570, 130), (640, 110)], close=False),))
    d.append((circle(360, 106, 22), 0))
    d.append((circle(640, 106, 22), 0))
    page("papillon", ("Le papillon", "The butterfly"), "animaux", "🦋", r, d)


def dinosaure():
    r, d = [], []
    # Ordre de pose = ordre de profondeur. Queue, pattes, plaques et cou passent
    # AVANT le corps : leurs attaches disparaissent derrière lui, exactement
    # comme dans un album de coloriage où l'on ne dessine pas les jonctions.
    r.append(("queue", smooth([(360, 610), (200, 632), (78, 588), (108, 534), (206, 578), (352, 552)]), 0xFF52A85A))
    r.append(("patte_ar", rrect(346, 640, 118, 216, 52), 0xFF52A85A))
    r.append(("patte_av", rrect(566, 640, 118, 216, 52), 0xFF52A85A))
    r.append(("plaque1", poly([(390, 500), (432, 288), (480, 494)]), 0xFFFFD166))
    r.append(("plaque2", poly([(486, 486), (532, 252), (580, 486)]), 0xFFEF6F6C))
    r.append(("plaque3", poly([(582, 500), (628, 284), (674, 506)]), 0xFFFFD166))
    r.append(("cou", smooth([(668, 520), (706, 344), (796, 296), (846, 372), (764, 458), (730, 560)]), 0xFF6BC46B))
    r.append(("corps", smooth([(300, 604), (376, 452), (556, 412), (700, 452), (766, 588),
                               (706, 720), (492, 762), (334, 714)]), 0xFF6BC46B))
    r.append(("ventre", smooth([(386, 700), (556, 668), (712, 700), (668, 758), (438, 764)]), 0xFFCDEBA6))
    r.append(("tete", smooth([(748, 300), (816, 214), (924, 226), (952, 306), (884, 372), (782, 366)]), 0xFF6BC46B))
    r.append(("oeil", circle(862, 282, 34), 0xFFFFFFFF))
    d.append((circle(868, 286, 15), 0))
    d.append((arc(902, 342, 946, 316, 0.22),))
    d.append((arc(392, 736, 452, 752, -0.12),))
    d.append((arc(600, 748, 660, 736, -0.12),))
    page("dinosaure", ("Le petit dino", "The little dino"), "animaux", "🦕", r, d)


def hibou():
    r, d = [], []
    r.append(("branche", rrect(120, 830, 760, 46, 22), 0xFF9B6B43))
    r.append(("aile_g", smooth([(310, 470), (250, 620), (300, 760), (380, 700), (370, 520)]), 0xFF9B7BD4))
    r.append(("aile_d", smooth([(690, 470), (750, 620), (700, 760), (620, 700), (630, 520)]), 0xFF9B7BD4))
    r.append(("corps", smooth([(500, 200), (720, 290), (760, 570), (660, 800), (500, 838),
                               (340, 800), (240, 570), (280, 290)]), 0xFF7E5FC0))
    r.append(("plastron", smooth([(500, 470), (620, 590), (600, 780), (500, 820), (400, 780), (380, 590)]), 0xFFFDE8C8))
    r.append(("touffe_g", poly([(300, 260), (270, 130), (400, 210)]), 0xFF7E5FC0))
    r.append(("touffe_d", poly([(700, 260), (730, 130), (600, 210)]), 0xFF7E5FC0))
    r.append(("disque_g", circle(408, 400, 108), 0xFFFFFFFF))
    r.append(("disque_d", circle(592, 400, 108), 0xFFFFFFFF))
    r.append(("oeil_g", circle(408, 400, 62), 0xFFFFD166))
    r.append(("oeil_d", circle(592, 400, 62), 0xFFFFD166))
    r.append(("bec", poly([(500, 452), (462, 512), (538, 512)]), 0xFFF6A93B))
    r.append(("patte_g", rrect(424, 824, 44, 40, 14), 0xFFF6A93B))
    r.append(("patte_d", rrect(532, 824, 44, 40, 14), 0xFFF6A93B))
    d.append((circle(408, 404, 26), 0))
    d.append((circle(592, 404, 26), 0))
    page("hibou", ("Le hibou de nuit", "The night owl"), "animaux", "🦉", r, d)


# ────────────────────────────── VÉHICULES ───────────────────────────────────
def voiture():
    r, d = [], []
    r.append(("route", rrect(40, 820, 920, 40, 20), 0xFFBDBDBD))
    r.append(("carrosserie", smooth([(140, 640), (180, 470), (330, 400), (660, 400),
                                     (830, 470), (880, 640), (860, 730), (140, 730)]), 0xFFEF6F6C))
    r.append(("vitre_g", smooth([(330, 430), (480, 424), (480, 552), (272, 552), (300, 460)]), 0xFF9BD7F0))
    r.append(("vitre_d", smooth([(520, 424), (660, 430), (720, 470), (740, 552), (520, 552)]), 0xFF9BD7F0))
    r.append(("phare_g", ellipse(178, 620, 52, 40), 0xFFFFD166))
    r.append(("phare_d", ellipse(842, 620, 52, 40), 0xFFFFD166))
    r.append(("pneu_g", circle(320, 740, 118), 0xFF4A4A4A))
    r.append(("pneu_d", circle(700, 740, 118), 0xFF4A4A4A))
    r.append(("jante_g", circle(320, 740, 58), 0xFFE0E0E0))
    r.append(("jante_d", circle(700, 740, 58), 0xFFE0E0E0))
    d.append((line(500, 424, 500, 552),))
    d.append((line(140, 668, 880, 668),))
    page("voiture", ("La voiture rapide", "The speedy car"), "vehicules", "🚗", r, d)


def fusee():
    r, d = [], []
    r.append(("flamme_ext", smooth([(430, 760), (500, 960), (570, 760), (500, 800)]), 0xFFF6A93B))
    r.append(("flamme_int", smooth([(468, 770), (500, 880), (532, 770), (500, 796)]), 0xFFFFD166))
    r.append(("aile_g", smooth([(400, 560), (250, 700), (250, 790), (400, 740)]), 0xFFEF6F6C))
    r.append(("aile_d", smooth([(600, 560), (750, 700), (750, 790), (600, 740)]), 0xFFEF6F6C))
    r.append(("corps", smooth([(500, 90), (620, 320), (640, 620), (600, 770), (400, 770),
                               (360, 620), (380, 320)]), 0xFFEDEDED))
    r.append(("nez", smooth([(500, 90), (600, 290), (400, 290)]), 0xFFEF6F6C))
    r.append(("hublot_ext", circle(500, 430, 108), 0xFF56B4E9))
    r.append(("hublot_int", circle(500, 430, 70), 0xFF9BD7F0))
    r.append(("bande", rrect(372, 630, 256, 62, 18), 0xFF56B4E9))
    r.append(("etoile1", star(160, 200, 52, 22), 0xFFFFD166))
    r.append(("etoile2", star(850, 300, 40, 17), 0xFFFFD166))
    r.append(("etoile3", star(800, 120, 30, 13), 0xFFFFD166))
    page("fusee", ("La fusée de l'espace", "The space rocket"), "vehicules", "🚀", r, d)


def bateau():
    r, d = [], []
    r.append(("ciel_soleil", circle(830, 190, 96), 0xFFFFD166))
    r.append(("voile_g", smooth([(480, 160), (480, 620), (200, 620)], tension=0.35), 0xFFEF6F6C))
    r.append(("voile_d", smooth([(520, 240), (760, 620), (520, 620)], tension=0.35), 0xFFFFD166))
    r.append(("fanion", poly([(512, 128), (660, 168), (512, 208)]), 0xFF6BC46B))
    r.append(("mat", rrect(486, 118, 28, 522, 12), 0xFF9B6B43))
    r.append(("coque", smooth([(140, 650), (860, 650), (760, 810), (240, 810)], tension=0.2), 0xFF9B6B43))
    r.append(("bande_coque", rrect(196, 690, 608, 44, 20), 0xFFEF6F6C))
    r.append(("vague1", smooth([(60, 850), (240, 812), (420, 850), (600, 812), (780, 850),
                                (960, 820), (960, 960), (60, 960)]), 0xFF56B4E9))
    r.append(("vague2", smooth([(60, 910), (250, 878), (450, 912), (650, 878), (860, 912),
                                (960, 890), (960, 980), (60, 980)]), 0xFF9BD7F0))
    page("bateau", ("Le bateau à voile", "The sailing boat"), "vehicules", "⛵", r, d)


def train():
    r, d = [], []
    r.append(("rail", rrect(20, 840, 960, 34, 16), 0xFF9B6B43))
    r.append(("fumee1", circle(250, 180, 62), 0xFFEDEDED))
    r.append(("fumee2", circle(350, 120, 46), 0xFFEDEDED))
    r.append(("fumee3", circle(438, 84, 34), 0xFFEDEDED))
    r.append(("wagon", rrect(560, 470, 380, 300, 34), 0xFFFFD166))
    r.append(("fenetre_w1", rrect(610, 520, 120, 110, 22), 0xFF9BD7F0))
    r.append(("fenetre_w2", rrect(770, 520, 120, 110, 22), 0xFF9BD7F0))
    r.append(("loco", rrect(80, 400, 460, 370, 34), 0xFFEF6F6C))
    r.append(("cheminee", rrect(200, 250, 108, 160, 20), 0xFF4A4A4A))
    r.append(("cabine", rrect(340, 440, 170, 170, 26), 0xFF9BD7F0))
    r.append(("phare", circle(140, 640, 56), 0xFFFFD166))
    r.append(("roue1", circle(180, 790, 76), 0xFF4A4A4A))
    r.append(("roue2", circle(420, 790, 76), 0xFF4A4A4A))
    r.append(("roue3", circle(650, 790, 62), 0xFF4A4A4A))
    r.append(("roue4", circle(860, 790, 62), 0xFF4A4A4A))
    d.append((line(540, 620, 560, 620),))
    page("train", ("Le train qui siffle", "The whistling train"), "vehicules", "🚂", r, d)


# ─────────────────────────────── NATURE ─────────────────────────────────────
def fleur():
    r, d = [], []
    r.append(("tige", smooth([(486, 520), (470, 700), (500, 900), (530, 700), (514, 520)]), 0xFF6BC46B))
    r.append(("feuille_g", smooth([(480, 700), (330, 640), (270, 720), (400, 780)]), 0xFF52A85A))
    r.append(("feuille_d", smooth([(520, 780), (660, 720), (720, 800), (580, 850)]), 0xFF52A85A))
    for i in range(6):
        a = -pi / 2 + 2 * pi * i / 6
        r.append((f"petale{i}", petal(500, 380, a, 260, 118), [0xFFEF6F6C, 0xFFF6A93B, 0xFFFFD166,
                                                               0xFF9B7BD4, 0xFF56B4E9, 0xFFF48FB1][i]))
    r.append(("coeur", circle(500, 380, 108), 0xFFFFD166))
    r.append(("herbe", smooth([(60, 900), (300, 870), (560, 902), (820, 868), (960, 896),
                               (960, 990), (60, 990)]), 0xFF6BC46B))
    d.append((circle(500, 380, 60), 0))
    page("fleur", ("La grande fleur", "The big flower"), "nature", "🌸", r, d)


def arbre():
    r, d = [], []
    r.append(("colline", smooth([(20, 880), (300, 826), (620, 884), (980, 836), (980, 1000), (20, 1000)]), 0xFF6BC46B))
    r.append(("tronc", smooth([(430, 430), (420, 700), (370, 880), (630, 880), (580, 700), (570, 430)]), 0xFF9B6B43))
    r.append(("feuillage_g", circle(320, 400, 168), 0xFF52A85A))
    r.append(("feuillage_d", circle(680, 400, 168), 0xFF52A85A))
    r.append(("feuillage_h", circle(500, 280, 196), 0xFF6BC46B))
    r.append(("feuillage_c", circle(500, 450, 190), 0xFF6BC46B))
    r.append(("pomme1", circle(360, 320, 44), 0xFFEF6F6C))
    r.append(("pomme2", circle(640, 350, 44), 0xFFEF6F6C))
    r.append(("pomme3", circle(510, 190, 44), 0xFFEF6F6C))
    r.append(("soleil", circle(140, 160, 88), 0xFFFFD166))
    d.append((arc(452, 620, 548, 640, 0.12),))
    d.append((arc(440, 740, 560, 760, 0.1),))
    page("arbre", ("Le grand arbre", "The tall tree"), "nature", "🌳", r, d)


def maison():
    r, d = [], []
    r.append(("ciel_soleil", circle(150, 160, 82), 0xFFFFD166))
    r.append(("herbe", smooth([(20, 830), (320, 800), (660, 838), (980, 806), (980, 1000), (20, 1000)]), 0xFF6BC46B))
    r.append(("mur", rrect(200, 450, 600, 400, 18), 0xFFFDE8C8))
    r.append(("toit", poly([(500, 190), (880, 470), (120, 470)]), 0xFFEF6F6C))
    r.append(("cheminee", rrect(660, 240, 90, 150, 12), 0xFF9B6B43))
    r.append(("porte", rrect(430, 620, 150, 230, 16), 0xFF9B6B43))
    r.append(("fenetre_g", rrect(250, 540, 140, 140, 16), 0xFF9BD7F0))
    r.append(("fenetre_d", rrect(620, 540, 140, 140, 16), 0xFF9BD7F0))
    r.append(("lucarne", circle(500, 380, 58), 0xFF9BD7F0))
    r.append(("poignee", circle(552, 736, 16), 0xFFFFD166))
    d.append((line(320, 540, 320, 680),))
    d.append((line(250, 610, 390, 610),))
    d.append((line(690, 540, 690, 680),))
    d.append((line(620, 610, 760, 610),))
    page("maison", ("Ma jolie maison", "My pretty house"), "nature", "🏡", r, d)


# ───────────────────────────── GOURMANDISES ─────────────────────────────────
def glace():
    r, d = [], []
    r.append(("cornet", poly([(340, 520), (660, 520), (500, 930)]), 0xFFF6A93B))
    r.append(("boule_bas", circle(500, 470, 175), 0xFFFDE8C8))
    r.append(("boule_mid", circle(390, 330, 150), 0xFFF48FB1))
    r.append(("boule_haut", circle(610, 310, 150), 0xFF9BD7F0))
    r.append(("cerise", circle(520, 140, 62), 0xFFEF6F6C))
    r.append(("pepite1", circle(430, 470, 26), 0xFFEF6F6C))
    r.append(("pepite2", circle(560, 520, 26), 0xFF6BC46B))
    r.append(("pepite3", circle(505, 400, 24), 0xFF9B7BD4))
    d.append((smooth([(520, 82), (560, 20), (650, 30)], close=False),))
    # Gaufrage : deux familles de parallèles, confinées au cornet (« clip »)
    # pour ne pas venir barrer les boules de glace.
    for t in (-1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75, 1.0):
        d.append((line(340 + 320 * t, 520, 340 + 320 * (t + 0.9), 940), 5, "cornet"))
        d.append((line(660 - 320 * t, 520, 660 - 320 * (t + 0.9), 940), 5, "cornet"))
    page("glace", ("La glace géante", "The giant ice cream"), "gourmandises", "🍦", r, d)


def cupcake():
    r, d = [], []
    r.append(("assiette", ellipse(500, 900, 380, 54), 0xFF9BD7F0))
    r.append(("caissette", smooth([(280, 540), (720, 540), (660, 870), (340, 870)], tension=0.15), 0xFFF48FB1))
    r.append(("creme_bas", smooth([(260, 545), (330, 400), (500, 350), (670, 400), (740, 545)]), 0xFFFDE8C8))
    r.append(("creme_mid", smooth([(330, 410), (400, 290), (520, 260), (640, 300), (680, 410)]), 0xFFFDE8C8))
    r.append(("creme_haut", smooth([(410, 300), (470, 200), (580, 220), (610, 310)]), 0xFFFDE8C8))
    r.append(("cerise", circle(510, 165, 60), 0xFFEF6F6C))
    r.append(("bonbon1", circle(370, 470, 22), 0xFF6BC46B))
    r.append(("bonbon2", circle(620, 460, 22), 0xFF56B4E9))
    r.append(("bonbon3", circle(500, 400, 22), 0xFFFFD166))
    r.append(("bonbon4", circle(430, 350, 20), 0xFF9B7BD4))
    d.append((smooth([(512, 106), (550, 40), (640, 46)], close=False),))
    for x in (360, 440, 520, 600, 680):
        d.append((line(x - (x - 500) * 0.06, 545, x - (x - 500) * 0.28, 868), 6, "caissette"))
    page("cupcake", ("Le cupcake sucré", "The sweet cupcake"), "gourmandises", "🧁", r, d)


for fn in (chat, poisson, papillon, dinosaure, hibou, voiture, fusee, bateau,
           train, fleur, arbre, maison, glace, cupcake):
    fn()


# ─────────────────────────────── ÉMISSION DART ──────────────────────────────
def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


out = ["// GÉNÉRÉ PAR tools/build_pages.py — NE PAS ÉDITER À LA MAIN.",
       "// Régénérer : python3 tools/build_pages.py",
       "",
       "import 'dart:ui' show Size;",
       "",
       "import '../l10n/app_strings.dart';",
       "import '../models/coloring_page.dart';",
       "",
       "const List<ColoringPage> kColoringPages = <ColoringPage>["]

for p in PAGES:
    out.append("  ColoringPage(")
    out.append(f"    id: '{p['id']}',")
    out.append(f"    title: L10nText(fr: '{esc(p['title'][0])}', "
               f"en: '{esc(p['title'][1])}'),")
    out.append(f"    category: '{esc(p['category'])}',")
    out.append(f"    emoji: '{p['emoji']}',")
    out.append(f"    size: Size({p['width']}, {p['height']}),")
    out.append("    regions: <RegionData>[")
    for r in p["regions"]:
        hint = f", hint: 0x{r['hint']:08X}" if r["hint"] else ""
        out.append(f"      RegionData('{r['id']}', '{esc(r['d'])}'{hint}),")
    out.append("    ],")
    if p["details"]:
        out.append("    details: <DetailData>[")
        for dd in p["details"]:
            if dd["clip"] is not None:
                names = [r["id"] for r in p["regions"]]
                out.append(f"      DetailData('{esc(dd['d'])}', {dd['w']}, "
                           f"{names.index(dd['clip'])}),")
            else:
                w = f", {dd['w']}" if dd["w"] else ""
                out.append(f"      DetailData('{esc(dd['d'])}'{w}),")
        out.append("    ],")
    out.append("  ),")
out.append("];")
out.append("")

target = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "app", "lib", "data", "pages.g.dart")
os.makedirs(os.path.dirname(target), exist_ok=True)
with open(target, "w") as f:
    f.write("\n".join(out))
print(f"{len(PAGES)} dessins → {os.path.relpath(target)}")
print("régions totales :", sum(len(p["regions"]) for p in PAGES))
