import 'dart:ui';

import 'tool.dart';

/// Une action de coloriage. L'œuvre est la liste ordonnée de ses opérations :
/// annuler/rétablir revient à déplacer un curseur dans cette liste, et la
/// sauvegarde à la sérialiser. Rien n'est jamais rasterisé sur disque, ce qui
/// garde les fichiers minuscules et le rendu net à toute résolution.
sealed class PaintOp {
  const PaintOp();

  Map<String, dynamic> toJson();

  static PaintOp fromJson(Map<String, dynamic> j) => switch (j['t']) {
        'f' => FillOp.fromJson(j),
        'c' => const ClearOp(),
        _ => StrokeOp.fromJson(j),
      };
}

/// Un trait de crayon, de feutre ou de gomme.
class StrokeOp extends PaintOp {
  StrokeOp({
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    required this.clipRegion,
    required this.seed,
  });

  final ToolKind tool;
  final int color;
  final double width;
  final List<Offset> points;

  /// Zone à laquelle le trait est confiné, ou `null` en mode libre.
  final int? clipRegion;

  /// Graine du grain du crayon : le rendu doit être identique à chaque redessin.
  final int seed;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        't': 's',
        'k': tool.index,
        'c': color,
        'w': width,
        'r': clipRegion,
        'd': seed,
        'p': <double>[
          for (final Offset o in points) ...<double>[
            (o.dx * 10).roundToDouble() / 10,
            (o.dy * 10).roundToDouble() / 10,
          ],
        ],
      };

  static StrokeOp fromJson(Map<String, dynamic> j) {
    final List<double> flat =
        (j['p'] as List<dynamic>).map((dynamic e) => (e as num).toDouble()).toList();
    return StrokeOp(
      tool: ToolKind.values[j['k'] as int],
      color: j['c'] as int,
      width: (j['w'] as num).toDouble(),
      clipRegion: j['r'] as int?,
      seed: j['d'] as int? ?? 0,
      points: <Offset>[
        for (int i = 0; i + 1 < flat.length; i += 2) Offset(flat[i], flat[i + 1]),
      ],
    );
  }
}

/// Un coup de pot de peinture : la zone entière prend la couleur.
class FillOp extends PaintOp {
  const FillOp({required this.region, required this.color});

  final int region;
  final int color;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'t': 'f', 'r': region, 'c': color};

  static FillOp fromJson(Map<String, dynamic> j) =>
      FillOp(region: j['r'] as int, color: j['c'] as int);
}

/// « Tout effacer ».
///
/// Marqueur posé dans la pile plutôt que vidage de la liste : effacer devient
/// une opération comme une autre, donc annulable d'un seul appui sur ↩︎. Un
/// enfant qui efface son quart d'heure de travail par mégarde le récupère.
class ClearOp extends PaintOp {
  const ClearOp();

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'t': 'c'};
}
