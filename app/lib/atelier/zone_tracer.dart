import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Déduit les zones coloriables d'un dessin fait à la main.
///
/// Un dessin de la bibliothèque est vectoriel : ses zones sont connues par
/// construction. Un dessin de l'Atelier ne l'est pas — il faut les retrouver
/// dans les pixels. Le traitement, dans l'ordre :
///
///   1. étiquetage des surfaces blanches fermées par propagation ;
///   2. fusion des miettes — sans quoi le moindre trait tremblant crée des
///      dizaines de zones minuscules, inutilisables au doigt ;
///   3. dilatation des étiquettes SOUS le trait, pour que les zones se
///      rejoignent au milieu de l'encre : c'est ce qui permet de colorier
///      sous le trait noir sans laisser un liseré blanc ;
///   4. suivi du contour extérieur de chaque zone, simplifié, émis en données
///      de chemin SVG.
///
/// Seul le contour EXTÉRIEUR est suivi : les zones sont ensuite triées de la
/// plus grande à la plus petite, et la soustraction des zones supérieures que
/// `CompiledPage` applique déjà creuse les trous toute seule. Une zone
/// contenue est forcément plus petite que celle qui la contient.
class TracedZones {
  const TracedZones(this.paths, this.pixels);

  /// Données de chemin SVG en coordonnées page, de la plus grande zone à la
  /// plus petite.
  final List<String> paths;

  /// Surface de chaque zone, en pixels de l'image analysée. Même ordre.
  final List<int> pixels;

  int get length => paths.length;
}

/// Seuil d'opacité au-delà duquel un pixel est considéré comme de l'encre.
const int _kInkAlpha = 40;

const int _kUnlabelled = -1;

TracedZones traceZones({
  required Uint8List rgba,
  required int width,
  required int height,
  required Size pageSize,
  int minArea = 50,
  double epsilon = 1.2,
}) {
  final int n = width * height;
  final Int32List labels = Int32List(n)..fillRange(0, n, _kUnlabelled);
  final Uint8List isInk = Uint8List(n);
  for (int i = 0; i < n; i++) {
    if (rgba[i * 4 + 3] > _kInkAlpha) isInk[i] = 1;
  }

  final List<int> areas = <int>[];
  final Int32List stack = Int32List(n);

  // ── 1. Propagation sur les surfaces libres ────────────────────────────────
  for (int seed = 0; seed < n; seed++) {
    if (isInk[seed] == 1 || labels[seed] != _kUnlabelled) continue;
    final int label = areas.length;
    int top = 0;
    stack[top++] = seed;
    labels[seed] = label;
    int area = 0;
    while (top > 0) {
      final int p = stack[--top];
      area++;
      final int x = p % width;
      final int y = p ~/ width;
      // Les quatre voisins sont déroulés à la main : la propagation touche
      // chaque pixel de l'image, ce n'est pas l'endroit pour allouer.
      top = _visit(stack, labels, isInk, top, x > 0 ? p - 1 : -1, label);
      top = _visit(stack, labels, isInk, top, x < width - 1 ? p + 1 : -1, label);
      top = _visit(stack, labels, isInk, top, y > 0 ? p - width : -1, label);
      top = _visit(stack, labels, isInk, top, y < height - 1 ? p + width : -1, label);
    }
    areas.add(area);
  }

  // ── 2. Dilatation sous le trait ───────────────────────────────────────────
  // Avant la fusion, et non après : une miette entièrement cernée par l'encre
  // n'a aucune voisine étiquetée tant que le trait n'est pas réparti, et
  // resterait donc une zone à part.
  _growUnderInk(labels, width, height, areas);

  // ── 3. Fusion des miettes ─────────────────────────────────────────────────
  _mergeSmall(labels, areas, width, height, minArea);

  // ── 4. Contours ───────────────────────────────────────────────────────────
  final List<int> order = <int>[
    for (int i = 0; i < areas.length; i++) if (areas[i] > 0) i,
  ]..sort((int a, int b) => areas[b].compareTo(areas[a]));

  final double sx = pageSize.width / width;
  final double sy = pageSize.height / height;

  final List<String> paths = <String>[];
  final List<int> pixels = <int>[];
  for (final int label in order) {
    final List<List<Offset>> loops = _traceContours(labels, width, height, label);
    final List<List<Offset>> simple = <List<Offset>>[
      for (final List<Offset> loop in loops)
        if (_simplify(loop, epsilon).length >= 3) _simplify(loop, epsilon),
    ];
    if (simple.isEmpty) continue;
    paths.add(_toPathData(simple, sx, sy));
    pixels.add(areas[label]);
  }
  return TracedZones(paths, pixels);
}

// Conservé pour la lisibilité de la boucle : empile un voisin s'il est libre.
int _visit(Int32List stack, Int32List labels, Uint8List isInk, int top, int p,
    int label) {
  if (p < 0) return top;
  if (isInk[p] == 1 || labels[p] != _kUnlabelled) return top;
  labels[p] = label;
  stack[top++] = p;
  return top;
}

/// Réaffecte les zones trop petites à leur voisine la plus partagée.
///
/// Traité de la plus petite à la plus grande : une miette collée à une autre
/// miette finit ainsi dans la zone qui les absorbe toutes les deux. Les
/// membres sont indexés en une seule passe — relire l'image entière pour
/// chaque miette coûterait cher sur un tracé tremblant, qui en produit
/// justement beaucoup.
void _mergeSmall(
    Int32List labels, List<int> areas, int width, int height, int minArea) {
  final Map<int, List<int>> members = <int, List<int>>{};
  for (int p = 0; p < labels.length; p++) {
    final int label = labels[p];
    if (label >= 0 && areas[label] < minArea) {
      (members[label] ??= <int>[]).add(p);
    }
  }

  final List<int> small = members.keys.toList()
    ..sort((int a, int b) => areas[a].compareTo(areas[b]));

  for (final int label in small) {
    if (areas[label] == 0 || areas[label] >= minArea) continue;
    final Map<int, int> neighbours = <int, int>{};
    for (final int p in members[label]!) {
      if (labels[p] != label) continue; // déjà absorbée par une fusion passée
      final int x = p % width;
      final int y = p ~/ width;
      for (final int q in <int>[
        if (x > 0) p - 1,
        if (x < width - 1) p + 1,
        if (y > 0) p - width,
        if (y < height - 1) p + width,
      ]) {
        final int other = labels[q];
        if (other >= 0 && other != label) {
          neighbours[other] = (neighbours[other] ?? 0) + 1;
        }
      }
    }
    if (neighbours.isEmpty) continue;
    int best = neighbours.keys.first;
    for (final MapEntry<int, int> e in neighbours.entries) {
      if (e.value > (neighbours[best] ?? 0)) best = e.key;
    }
    for (final int p in members[label]!) {
      if (labels[p] == label) labels[p] = best;
    }
    areas[best] += areas[label];
    areas[label] = 0;
  }
}

/// Étend les étiquettes sous le trait, en largeur d'abord depuis toutes les
/// zones à la fois : chaque pixel d'encre rejoint la zone la plus proche, donc
/// deux zones voisines se rencontrent au milieu du trait.
void _growUnderInk(
    Int32List labels, int width, int height, List<int> areas) {
  final List<int> frontier = <int>[];
  for (int p = 0; p < labels.length; p++) {
    if (labels[p] >= 0) frontier.add(p);
  }
  while (frontier.isNotEmpty) {
    final List<int> next = <int>[];
    for (final int p in frontier) {
      final int label = labels[p];
      final int x = p % width;
      final int y = p ~/ width;
      for (final int q in <int>[
        if (x > 0) p - 1,
        if (x < width - 1) p + 1,
        if (y > 0) p - width,
        if (y < height - 1) p + width,
      ]) {
        if (labels[q] == _kUnlabelled) {
          labels[q] = label;
          areas[label]++;
          next.add(q);
        }
      }
    }
    frontier
      ..clear()
      ..addAll(next);
  }
}

/// Suit TOUS les contours d'une zone — son pourtour et ses trous — en longeant
/// les ARÊTES entre pixels plutôt que les centres de pixels.
///
/// Deux raisons de tracer aussi les trous plutôt que de s'en remettre à la
/// soustraction des zones supérieures :
///
///  * cette soustraction repose sur `Path.combine`, dont le moteur web ne
///    renvoie pas toujours le résultat attendu sur des contours tremblants —
///    le fond se retrouvait alors à couvrir tout le dessin ;
///  * une zone trouée est de toute façon la vérité : le test de contact et le
///    détourage deviennent exacts sans dépendre de l'ordre des zones.
///
/// Les trous sont parcourus dans le sens inverse du pourtour, ce qui suffit à
/// les creuser avec la règle de remplissage par défaut.
///
/// À chaque sommet, on regarde les quatre pixels qui l'entourent :
///
///   A B      A = (x-1, y-1)   B = (x, y-1)
///   C D      C = (x-1, y)     D = (x, y)
///
/// Renvoie les boucles du contour, en coordonnées d'arête (0..width).
List<List<Offset>> _traceContours(
    Int32List labels, int width, int height, int label) {
  bool inside(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height && labels[y * width + x] == label;

  // 0 = droite, 1 = bas, 2 = gauche, 3 = haut — dans le sens horaire.
  const List<int> vx = <int>[1, 0, -1, 0];
  const List<int> vy = <int>[0, 1, 0, -1];

  bool canGo(int dir, int x, int y) {
    final bool a = inside(x - 1, y - 1);
    final bool b = inside(x, y - 1);
    final bool c = inside(x - 1, y);
    final bool d = inside(x, y);
    return switch (dir) {
      0 => d && !b,
      1 => c && !d,
      2 => a && !c,
      _ => b && !a,
    };
  }

  final int stride = width + 1;
  final Set<int> seen = <int>{};
  int edgeKey(int x, int y, int dir) => (y * stride + x) * 4 + dir;

  final List<List<Offset>> loops = <List<Offset>>[];
  final int maxSteps = (width + 1) * (height + 1) * 4;

  // Toute boucle de contour — pourtour comme trou — possède au moins une arête
  // parcourue vers la droite : le balayage en ordre de lecture les trouve donc
  // toutes, sans avoir à distinguer les cas.
  for (int y = 0; y <= height; y++) {
    for (int x = 0; x <= width; x++) {
      if (!canGo(0, x, y) || seen.contains(edgeKey(x, y, 0))) continue;

      final List<Offset> loop = <Offset>[Offset(x.toDouble(), y.toDouble())];
      int cx = x, cy = y, dir = 0;

      for (int step = 0; step < maxSteps; step++) {
        // On tourne le plus serré possible dans le sens horaire, ce qui lève
        // sans ambiguïté les pincements en diagonale.
        int? chosen;
        for (final int candidate in <int>[
          (dir + 1) % 4,
          dir,
          (dir + 3) % 4,
          (dir + 2) % 4,
        ]) {
          if (canGo(candidate, cx, cy)) {
            chosen = candidate;
            break;
          }
        }
        if (chosen == null) break;
        dir = chosen;
        seen.add(edgeKey(cx, cy, dir));
        cx += vx[dir];
        cy += vy[dir];
        if (cx == x && cy == y) break; // boucle bouclée
        loop.add(Offset(cx.toDouble(), cy.toDouble()));
      }
      if (loop.length >= 3) loops.add(loop);
    }
  }
  return loops;
}

/// Ramer–Douglas–Peucker : réduit le contour sans en changer la forme.
/// Un contour brut de 512×512 compte des milliers de points ; détourer un
/// trait sur un chemin pareil coûterait cher à chaque image.
List<Offset> _simplify(List<Offset> pts, double epsilon) {
  if (pts.length < 3) return pts;
  final List<bool> keep = List<bool>.filled(pts.length, false);
  keep[0] = true;
  keep[pts.length - 1] = true;
  final List<List<int>> work = <List<int>>[
    <int>[0, pts.length - 1]
  ];

  while (work.isNotEmpty) {
    final List<int> seg = work.removeLast();
    final int a = seg[0], b = seg[1];
    if (b <= a + 1) continue;
    double best = -1;
    int bestIndex = -1;
    for (int i = a + 1; i < b; i++) {
      final double d = _pointSegmentDistance(pts[i], pts[a], pts[b]);
      if (d > best) {
        best = d;
        bestIndex = i;
      }
    }
    if (best > epsilon && bestIndex > 0) {
      keep[bestIndex] = true;
      work.add(<int>[a, bestIndex]);
      work.add(<int>[bestIndex, b]);
    }
  }
  return <Offset>[
    for (int i = 0; i < pts.length; i++)
      if (keep[i]) pts[i],
  ];
}

double _pointSegmentDistance(Offset p, Offset a, Offset b) {
  final double dx = b.dx - a.dx;
  final double dy = b.dy - a.dy;
  final double len2 = dx * dx + dy * dy;
  if (len2 == 0) return (p - a).distance;
  double t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
}

/// Une zone donne UN chemin, dont chaque boucle est un sous-chemin : le
/// pourtour d'abord, puis les trous, parcourus en sens inverse.
String _toPathData(List<List<Offset>> loops, double sx, double sy) {
  final StringBuffer b = StringBuffer();
  String f(double v) {
    final double r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? '${r.toInt()}' : '$r';
  }

  for (final List<Offset> pts in loops) {
    if (b.isNotEmpty) b.write(' ');
    b.write('M ${f(pts.first.dx * sx)} ${f(pts.first.dy * sy)}');
    for (int i = 1; i < pts.length; i++) {
      b.write(' L ${f(pts[i].dx * sx)} ${f(pts[i].dy * sy)}');
    }
    b.write(' Z');
  }
  return b.toString();
}

/// Convertit une suite de points du doigt en données de chemin SVG lissées.
///
/// Le lissage reprend celui d'`ArtworkPainter.smoothPath` — quadratiques par
/// les milieux de segments — pour que le trait enregistré soit exactement
/// celui qu'a vu l'enfant en dessinant.
String smoothPathData(List<Offset> pts) {
  if (pts.isEmpty) return '';
  String f(double v) => ((v * 10).round() / 10).toString();
  if (pts.length == 1) {
    return 'M ${f(pts.first.dx)} ${f(pts.first.dy)} '
        'L ${f(pts.first.dx)} ${f(pts.first.dy)}';
  }
  final StringBuffer b = StringBuffer('M ${f(pts.first.dx)} ${f(pts.first.dy)}');
  for (int i = 1; i < pts.length - 1; i++) {
    final Offset mid = Offset(
      (pts[i].dx + pts[i + 1].dx) / 2,
      (pts[i].dy + pts[i + 1].dy) / 2,
    );
    b.write(' Q ${f(pts[i].dx)} ${f(pts[i].dy)} ${f(mid.dx)} ${f(mid.dy)}');
  }
  b.write(' L ${f(pts.last.dx)} ${f(pts.last.dy)}');
  return b.toString();
}

/// Surface minimale d'une zone, exprimée pour une image de [side] pixels.
/// La spécification retient 200 pixels sur une image de 1024 de côté.
int minAreaFor(int side) => math.max(8, (200 * side * side / (1024 * 1024)).round());
