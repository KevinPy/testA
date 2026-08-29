import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Les motifs : peindre avec une texture plutôt qu'avec un aplat.
///
/// Chaque motif est une tuile dessinée UNE fois en blanc sur fond transparent.
/// La couleur choisie par l'enfant est appliquée ensuite par filtre, si bien
/// qu'une seule tuile sert les vingt-quatre couleurs de la palette — et celles
/// qu'il invente.
enum PatternKind { pois, rayures, zigzag, etoiles, coeurs, carreaux }

/// Côté de la tuile en coordonnées page. La page fait 1000 : le motif se
/// répète donc une vingtaine de fois en largeur. Assez gros pour être reconnu,
/// assez petit pour qu'un trait fin en attrape toujours un morceau.
const double kPatternTile = 56;

/// Résolution de la tuile. Généreuse à dessein : à l'export en 2048 points une
/// tuile de 56 unités en couvre 115, et une image plus petite donnerait un
/// motif flou.
const int _kTilePixels = 192;

/// Voile de fond, sous les formes du motif.
///
/// Sans lui, un trait de crayon fin passant entre deux pois ne laisserait
/// aucune trace — l'enfant croirait l'outil cassé. Avec lui, le trait dépose
/// toujours une teinte légère, et le motif s'y détache en pleine couleur.
const double _kWash = 0.30;

/// Les tuiles, rendues à la première demande puis conservées.
class PatternTiles {
  PatternTiles._();

  static final PatternTiles instance = PatternTiles._();

  final Map<PatternKind, ui.Image> _images = <PatternKind, ui.Image>{};
  final Map<String, ImageShader> _shaders = <String, ImageShader>{};

  /// Prépare toutes les tuiles d'avance : appelé au démarrage pour qu'aucun
  /// premier trait ne paie la fabrication de son image.
  void warmUp() {
    for (final PatternKind kind in PatternKind.values) {
      shader(kind);
    }
  }

  ImageShader shader(PatternKind kind, {double tileScale = 1}) {
    return _shaders.putIfAbsent('${kind.index}:$tileScale', () {
      final ui.Image image = _images.putIfAbsent(kind, () => _render(kind));
      final double k = kPatternTile * tileScale / _kTilePixels;
      return ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.diagonal3Values(k, k, 1).storage,
      );
    });
  }

  static ui.Image _render(PatternKind kind) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    paintPatternTile(canvas, kind, _kTilePixels.toDouble());
    return recorder.endRecording().toImageSync(_kTilePixels, _kTilePixels);
  }
}

/// Le dessin d'une tuile de côté [s], en blanc.
///
/// Chaque motif se raccorde à lui-même d'un bord à l'autre : sans cela, la
/// répétition ferait apparaître une grille de coutures.
void paintPatternTile(Canvas canvas, PatternKind kind, double s) {
  const Color white = Color(0xFFFFFFFF);
  final Paint fill = Paint()
    ..color = white
    ..isAntiAlias = true;

  Paint stroke(double w) => Paint()
    ..color = white
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  canvas.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()..color = white.withValues(alpha: _kWash),
  );

  // Quatre exemplaires par tuile, aucun ne touchant un bord : rien à recoller
  // d'une tuile à la suivante.
  const List<Offset> grid = <Offset>[
    Offset(0.25, 0.25), Offset(0.75, 0.25),
    Offset(0.25, 0.75), Offset(0.75, 0.75),
  ];

  switch (kind) {
    case PatternKind.pois:
      for (final Offset g in grid) {
        canvas.drawCircle(Offset(g.dx * s, g.dy * s), s * 0.19, fill);
      }

    case PatternKind.rayures:
      // Rayures à 45°. Le pas horizontal divise le côté : les diagonales
      // sortant à droite rentrent exactement à gauche.
      for (int k = -3; k <= 6; k++) {
        canvas.drawLine(
          Offset(k * s / 3, 0),
          Offset(k * s / 3 + s, s),
          stroke(s * 0.16),
        );
      }

    case PatternKind.zigzag:
      for (int row = 0; row < 2; row++) {
        final double y = s * (0.25 + row * 0.5);
        final Path p = Path()..moveTo(0, y);
        for (int i = 0; i < 4; i++) {
          p.lineTo(s * (i + 0.5) / 4, y - s * 0.13);
          p.lineTo(s * (i + 1) / 4, y);
        }
        canvas.drawPath(p, stroke(s * 0.12));
      }

    case PatternKind.etoiles:
      for (final Offset g in grid) {
        canvas.drawPath(
          starPath(Offset(g.dx * s, g.dy * s), s * 0.22, s * 0.095),
          fill,
        );
      }

    case PatternKind.coeurs:
      for (final Offset g in grid) {
        canvas.drawPath(heartPath(Offset(g.dx * s, g.dy * s), s * 0.20), fill);
      }

    case PatternKind.carreaux:
      canvas.drawRect(Rect.fromLTWH(0, 0, s / 2, s / 2), fill);
      canvas.drawRect(Rect.fromLTWH(s / 2, s / 2, s / 2, s / 2), fill);
  }
}

/// Étoile à cinq branches centrée sur [c]. Partagée avec les autocollants.
Path starPath(Offset c, double outer, double inner) {
  final Path p = Path();
  for (int i = 0; i < 10; i++) {
    final double r = i.isEven ? outer : inner;
    final double a = -math.pi / 2 + i * math.pi / 5;
    final Offset o = c + Offset(math.cos(a) * r, math.sin(a) * r);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// Cœur centré sur [c], de demi-hauteur [r]. Partagé avec les autocollants.
Path heartPath(Offset c, double r) {
  return Path()
    ..moveTo(c.dx, c.dy + r * 0.85)
    ..cubicTo(c.dx - r * 1.7, c.dy - r * 0.25, c.dx - r * 0.62,
        c.dy - r * 1.25, c.dx, c.dy - r * 0.32)
    ..cubicTo(c.dx + r * 0.62, c.dy - r * 1.25, c.dx + r * 1.7,
        c.dy - r * 0.25, c.dx, c.dy + r * 0.85)
    ..close();
}

/// La peinture d'un outil : aplat si [kind] est nul, motif teinté sinon.
///
/// La tuile est ancrée sur LA PAGE, pas sur le geste : un trait de crayon
/// révèle le motif comme on gratte une surface, et deux traits voisins se
/// raccordent au lieu de se contredire.
Paint patternBrush(PatternKind? kind, Color color, {double tileScale = 1}) {
  final Paint paint = Paint()..isAntiAlias = true;
  if (kind == null) return paint..color = color;
  return paint
    ..shader = PatternTiles.instance.shader(kind, tileScale: tileScale)
    // `srcIn` garde la couleur là où la tuile est opaque et la multiplie par
    // l'alpha de la tuile : le voile de fond en ressort atténué d'autant, et
    // l'alpha du crayon de cire continue de jouer.
    ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
}

extension PatternKindX on PatternKind {
  IconData get icon => switch (this) {
        PatternKind.pois => Icons.blur_on_rounded,
        PatternKind.rayures => Icons.line_style_rounded,
        PatternKind.zigzag => Icons.show_chart_rounded,
        PatternKind.etoiles => Icons.star_rounded,
        PatternKind.coeurs => Icons.favorite_rounded,
        PatternKind.carreaux => Icons.grid_view_rounded,
      };
}
