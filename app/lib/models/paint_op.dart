import 'dart:ui';

import 'pattern.dart';
import 'sticker.dart';
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
        'k' => StickerOp.fromJson(j),
        'x' => RemoveStickerOp.fromJson(j),
        _ => StrokeOp.fromJson(j),
      };
}

/// Motif porté par une opération, relu depuis une sauvegarde.
/// Clé absente = œuvre d'avant les motifs, donc un aplat.
PatternKind? _patternFromJson(Object? raw) {
  if (raw is! int || raw < 0 || raw >= PatternKind.values.length) return null;
  return PatternKind.values[raw];
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
    this.pattern,
  });

  final ToolKind tool;
  final int color;
  final double width;
  final List<Offset> points;

  /// Motif appliqué au trait, ou `null` pour un aplat de couleur.
  final PatternKind? pattern;

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
        if (pattern != null) 'm': pattern!.index,
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
      pattern: _patternFromJson(j['m']),
      points: <Offset>[
        for (int i = 0; i + 1 < flat.length; i += 2) Offset(flat[i], flat[i + 1]),
      ],
    );
  }
}

/// Un coup de pot de peinture : la zone entière prend la couleur.
class FillOp extends PaintOp {
  const FillOp({required this.region, required this.color, this.pattern});

  final int region;
  final int color;

  /// Motif appliqué au remplissage, ou `null` pour un aplat.
  ///
  /// Un remplissage à motif ne recouvre pas toute la zone : les creux de la
  /// tuile restent translucides, si bien qu'un enfant peut poser un aplat puis
  /// semer des pois d'une autre couleur par-dessus.
  final PatternKind? pattern;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        't': 'f',
        'r': region,
        'c': color,
        if (pattern != null) 'm': pattern!.index,
      };

  static FillOp fromJson(Map<String, dynamic> j) => FillOp(
        region: j['r'] as int,
        color: j['c'] as int,
        pattern: _patternFromJson(j['m']),
      );
}

/// Un autocollant posé sur le dessin.
///
/// Seule opération mutable : déplacer, tourner ou agrandir un autocollant
/// modifie celui qui est déjà posé plutôt que d'en empiler un nouveau. Sans
/// cela, un seul pincement remplirait l'historique de cent états et le bouton
/// « annuler » deviendrait inutilisable.
class StickerOp extends PaintOp {
  StickerOp({
    required this.id,
    required this.kind,
    required this.center,
    this.scale = 1,
    this.rotation = 0,
  });

  /// Identifiant stable : c'est par lui que [RemoveStickerOp] le désigne.
  final int id;
  final StickerKind kind;

  Offset center;
  double scale;
  double rotation;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        't': 'k',
        'i': id,
        'g': kind.index,
        'x': (center.dx * 10).roundToDouble() / 10,
        'y': (center.dy * 10).roundToDouble() / 10,
        's': (scale * 1000).roundToDouble() / 1000,
        'r': (rotation * 1000).roundToDouble() / 1000,
      };

  static StickerOp fromJson(Map<String, dynamic> j) {
    final int g = j['g'] as int;
    return StickerOp(
      id: j['i'] as int? ?? 0,
      kind: StickerKind.values[g < StickerKind.values.length ? g : 0],
      center: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
      scale: (j['s'] as num?)?.toDouble() ?? 1,
      rotation: (j['r'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Le retrait d'un autocollant.
///
/// Marqueur plutôt que suppression dans la liste, exactement comme [ClearOp] :
/// enlever un autocollant reste une opération de l'historique, donc annulable.
class RemoveStickerOp extends PaintOp {
  const RemoveStickerOp(this.id);

  final int id;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'t': 'x', 'i': id};

  static RemoveStickerOp fromJson(Map<String, dynamic> j) =>
      RemoveStickerOp(j['i'] as int? ?? 0);
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

/// Les autocollants encore visibles après rejeu de [ops], dans l'ordre de pose.
List<StickerOp> visibleStickers(List<PaintOp> ops) {
  final List<StickerOp> live = <StickerOp>[];
  for (final PaintOp op in ops) {
    switch (op) {
      case ClearOp():
        live.clear();
      case StickerOp():
        live.add(op);
      case RemoveStickerOp():
        live.removeWhere((StickerOp s) => s.id == op.id);
      case StrokeOp():
      case FillOp():
        break;
    }
  }
  return live;
}
