import 'dart:typed_data';
import 'dart:ui';

import 'package:barbouille/atelier/zone_tracer.dart';
import 'package:barbouille/widgets/artwork_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_drawing/path_drawing.dart';

/// Fabrique une image RVBA où l'encre est opaque et le reste transparent.
/// `ink(x, y)` décrit le trait, comme le ferait le doigt de l'enfant.
Uint8List canvasOf(int w, int h, bool Function(int x, int y) ink) {
  final Uint8List px = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (ink(x, y)) px[(y * w + x) * 4 + 3] = 255;
    }
  }
  return px;
}

const Size kPage = Size(1000, 1000);

void main() {
  test('une feuille vierge ne donne qu\'une seule zone', () {
    final TracedZones z = traceZones(
      rgba: canvasOf(64, 64, (_, _) => false),
      width: 64,
      height: 64,
      pageSize: kPage,
    );
    expect(z.length, 1);
  });

  test('un trait qui coupe la feuille donne deux zones', () {
    // Une barre verticale épaisse au milieu.
    final TracedZones z = traceZones(
      rgba: canvasOf(64, 64, (int x, int y) => x >= 30 && x <= 33),
      width: 64,
      height: 64,
      pageSize: kPage,
    );
    expect(z.length, 2, reason: 'gauche et droite');
    // Les deux moitiés sont d'aire comparable.
    expect((z.pixels[0] - z.pixels[1]).abs(), lessThan(z.pixels[0] * 0.2));
  });

  // Le test qui manquait : les zones se comptaient bien, mais rien ne
  // vérifiait qu'un chemin tracé CONTIENT sa propre surface. Un contour
  // dégénéré passait donc inaperçu, et toutes les zones rondes de l'Atelier
  // renvoyaient le fond au premier contact du doigt.
  test('chaque zone contient son propre intérieur', () {
    const int side = 128;
    final TracedZones z = traceZones(
      rgba: canvasOf(side, side, (int x, int y) {
        final double d =
            (Offset(x.toDouble(), y.toDouble()) - const Offset(64, 64)).distance;
        return d > 34 && d < 38;
      }),
      width: side,
      height: side,
      pageSize: kPage,
    );
    expect(z.length, 2);

    final Path outside = parseSvgPathData(z.paths[0]);
    final Path disc = parseSvgPathData(z.paths[1]);

    expect(disc.contains(const Offset(500, 500)), isTrue,
        reason: 'le disque doit contenir son centre');
    expect(disc.contains(const Offset(20, 20)), isFalse,
        reason: 'le disque ne doit pas contenir un coin de la page');
    expect(outside.contains(const Offset(20, 20)), isTrue,
        reason: 'le fond doit contenir les coins');

    // Le contour du disque doit couvrir un vrai disque, pas trois points.
    final Rect b = disc.getBounds();
    expect(b.width, greaterThan(400), reason: 'diamètre attendu ≈ 530');
    expect(b.height, greaterThan(400));
  });

  test('deux formes qui se chevauchent restent distinguables', () {
    // Le cas du bonhomme : deux ronds qui se touchent. Chaque intérieur doit
    // être atteignable, sinon le pot de peinture repeint tout le fond.
    const int side = 160;
    bool ring(int x, int y, double cx, double cy, double r) {
      final double d = (Offset(x.toDouble(), y.toDouble()) - Offset(cx, cy)).distance;
      return d > r - 2 && d < r + 2;
    }

    final TracedZones z = traceZones(
      rgba: canvasOf(side, side,
          (int x, int y) => ring(x, y, 80, 50, 30) || ring(x, y, 80, 110, 40)),
      width: side,
      height: side,
      pageSize: kPage,
    );

    final List<Path> paths =
        z.paths.map((String d) => parseSvgPathData(d)).toList();
    const Offset head = Offset(500, 312);   // centre du petit rond
    const Offset body = Offset(500, 687);   // centre du grand rond

    // Le test de contact de l'application parcourt les zones de la plus petite
    // à la plus grande : on reproduit cet ordre.
    int hit(Offset p) {
      for (int i = paths.length - 1; i >= 0; i--) {
        if (paths[i].contains(p)) return i;
      }
      return -1;
    }

    expect(hit(head), isNot(-1));
    expect(hit(body), isNot(-1));
    expect(hit(head), isNot(hit(body)),
        reason: 'la tête et le corps sont deux zones différentes');
    expect(hit(const Offset(20, 20)), 0, reason: 'le coin appartient au fond');
  });

  test('un cercle fermé donne l\'intérieur et le fond', () {
    final TracedZones z = traceZones(
      rgba: canvasOf(96, 96, (int x, int y) {
        final double d = (Offset(x.toDouble(), y.toDouble()) - const Offset(48, 48)).distance;
        return d > 28 && d < 32;
      }),
      width: 96,
      height: 96,
      pageSize: kPage,
    );
    expect(z.length, 2);
    // Trié par aire décroissante : le fond d'abord, le disque ensuite.
    expect(z.pixels[0], greaterThan(z.pixels[1]));
  });

  test('les zones se rejoignent sous le trait : aucun pixel orphelin', () {
    const int side = 64;
    final TracedZones z = traceZones(
      rgba: canvasOf(side, side, (int x, int y) => x >= 30 && x <= 35),
      width: side,
      height: side,
      pageSize: kPage,
    );
    // La dilatation sous l'encre doit répartir TOUS les pixels : sans elle,
    // colorier laisserait un liseré blanc le long de chaque trait.
    expect(z.pixels.reduce((int a, int b) => a + b), side * side);
  });

  test('les miettes sont fusionnées dans leur voisine', () {
    // Un trait vertical, plus une encoche qui isole 4 pixels en haut à gauche.
    final TracedZones z = traceZones(
      rgba: canvasOf(64, 64, (int x, int y) =>
          (x >= 30 && x <= 33) || (y == 2 && x < 3) || (x == 2 && y < 3)),
      width: 64,
      height: 64,
      pageSize: kPage,
      minArea: 50,
    );
    expect(z.length, 2, reason: 'la miette de 4 pixels ne doit pas survivre');
  });

  test('les chemins produits sont analysables et tiennent dans la page', () {
    final TracedZones z = traceZones(
      rgba: canvasOf(96, 96, (int x, int y) => x == 48 || y == 48),
      width: 96,
      height: 96,
      pageSize: kPage,
    );
    expect(z.length, 4, reason: 'quatre quadrants');
    for (final String d in z.paths) {
      final Path p = parseSvgPathData(d);
      final Rect b = p.getBounds();
      expect(b.isEmpty, isFalse);
      expect(b.left, greaterThanOrEqualTo(-1));
      expect(b.top, greaterThanOrEqualTo(-1));
      expect(b.right, lessThanOrEqualTo(kPage.width + 1));
      expect(b.bottom, lessThanOrEqualTo(kPage.height + 1));
    }
  });

  test('les zones sont triées de la plus grande à la plus petite', () {
    // Un grand rectangle et un petit, séparés du fond.
    final TracedZones z = traceZones(
      rgba: canvasOf(128, 128, (int x, int y) {
        final bool big = (x == 10 || x == 70) && y >= 10 && y <= 70 ||
            (y == 10 || y == 70) && x >= 10 && x <= 70;
        final bool small = (x == 90 || x == 110) && y >= 90 && y <= 110 ||
            (y == 90 || y == 110) && x >= 90 && x <= 110;
        return big || small;
      }),
      width: 128,
      height: 128,
      pageSize: kPage,
    );
    expect(z.length, 3, reason: 'fond + grand carré + petit carré');
    for (int i = 1; i < z.pixels.length; i++) {
      expect(z.pixels[i - 1], greaterThanOrEqualTo(z.pixels[i]),
          reason: 'l\'ordre décroissant est ce qui creuse les trous');
    }
  });

  test('le contour est simplifié sans perdre la forme', () {
    final TracedZones z = traceZones(
      rgba: canvasOf(128, 128, (int x, int y) => x >= 62 && x <= 65),
      width: 128,
      height: 128,
      pageSize: kPage,
      epsilon: 1.2,
    );
    for (final String d in z.paths) {
      // Un rectangle simplifié tient en une poignée de sommets ; un contour
      // brut en compterait des centaines.
      expect('L '.allMatches(d).length, lessThan(40), reason: d.length.toString());
    }
  });

  test('les traits enregistrés reprennent le lissage du peintre', () {
    final List<Offset> pts = <Offset>[
      const Offset(10, 10),
      const Offset(40, 60),
      const Offset(90, 20),
      const Offset(140, 80),
    ];
    final Path fromCodec = parseSvgPathData(smoothPathData(pts));
    final Path fromPainter = smoothPathOfPoints(pts);
    final Rect a = fromCodec.getBounds();
    final Rect b = fromPainter.getBounds();
    expect((a.left - b.left).abs(), lessThan(0.5));
    expect((a.top - b.top).abs(), lessThan(0.5));
    expect((a.right - b.right).abs(), lessThan(0.5));
    expect((a.bottom - b.bottom).abs(), lessThan(0.5));
  });

  // Le défaut qui n'apparaissait qu'à l'écran : le fond couvrait tout le
  // dessin. Sa surface doit exclure les formes posées dessus PAR ELLE-MÊME,
  // sans dépendre de la soustraction booléenne — le moteur web ne la rendait
  // pas de la même façon que la machine virtuelle Dart.
  test('une zone trouée exclut son trou, chemin brut à l\'appui', () {
    const int side = 128;
    final TracedZones z = traceZones(
      rgba: canvasOf(side, side, (int x, int y) {
        final double d =
            (Offset(x.toDouble(), y.toDouble()) - const Offset(64, 64)).distance;
        return d > 34 && d < 38;
      }),
      width: side,
      height: side,
      pageSize: kPage,
    );
    expect(z.length, 2);

    // z.paths[0] est le fond : il entoure le disque et doit donc être troué.
    final Path background = parseSvgPathData(z.paths[0]);
    expect(background.contains(const Offset(20, 20)), isTrue,
        reason: 'les coins appartiennent au fond');
    expect(background.contains(const Offset(500, 500)), isFalse,
        reason: 'le centre du disque n\'est pas le fond');

    // Deux sous-chemins : le pourtour de la page et le trou.
    expect('M '.allMatches(z.paths[0]).length, 2);
  });

  test('la surface minimale suit la résolution analysée', () {
    expect(minAreaFor(1024), 200);
    expect(minAreaFor(512), 50);
  });
}
