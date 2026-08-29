import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/coloring_page.dart';
import '../models/paint_op.dart';
import '../models/pattern.dart';
import '../models/sticker.dart';
import '../models/tool.dart';

/// Rendu d'un coloriage.
///
/// Le modèle de composition tient en quatre couches, toujours dans cet ordre :
///
///   1. le papier ;
///   2. la COUCHE COULEUR — tout ce que l'enfant a posé ;
///   3. la COUCHE ENCRE — le trait noir du dessin ;
///   4. les AUTOCOLLANTS — collés PAR-DESSUS tout le reste, trait noir
///      compris, parce que c'est ce que fait un autocollant sur du papier.
///
/// L'encre étant redessinée par-dessus la couleur à chaque image, l'enfant
/// « colorie sous le trait noir » en permanence : c'est le comportement par
/// défaut et non une option. Quoi qu'il barbouille, le contour reste net.
///
/// Le confinement aux zones (« Zones magiques ») est une chose différente : il
/// détoure le trait sur la zone touchée au premier contact du doigt.
class ArtworkPainter extends CustomPainter {
  ArtworkPainter({
    required this.page,
    required this.ops,
    required this.live,
    this.showHints = false,
    this.inkScale = 1.0,
    this.selected,
  });

  final CompiledPage page;

  /// Opérations validées, dans l'ordre de pose.
  final List<PaintOp> ops;

  /// Le trait en cours sous le doigt, pas encore validé.
  final StrokeOp? live;

  /// Aperçu « comme sur le modèle » : la galerie s'en sert pour ses vignettes.
  final bool showHints;

  /// Compense l'échelle d'affichage pour que le trait garde une épaisseur
  /// visuellement constante sur une vignette comme en plein écran.
  final double inkScale;

  /// L'autocollant en cours de manipulation, entouré de son cadre et de sa
  /// croix de retrait. Toujours nul à l'export : le cadre est une aide à
  /// l'écran, pas un morceau du dessin.
  final StickerOp? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final Size pageSize = page.source.size;
    final double scale =
        math.min(size.width / pageSize.width, size.height / pageSize.height);

    canvas.save();
    canvas.translate(
      (size.width - pageSize.width * scale) / 2,
      (size.height - pageSize.height * scale) / 2,
    );
    canvas.scale(scale);

    final Rect bounds = Offset.zero & pageSize;
    canvas.drawRect(bounds, Paint()..color = const Color(0xFFFFFFFF));

    // ── Couche couleur ────────────────────────────────────────────────────
    // Isolée dans son propre calque : la gomme y applique BlendMode.clear sans
    // jamais entamer le papier ni le trait noir.
    canvas.saveLayer(bounds, Paint());
    if (showHints) {
      for (int i = 0; i < page.regions.length; i++) {
        final int? hint = page.source.regions[i].hint;
        if (hint != null) {
          _confined(canvas, i, () {
            canvas.drawPath(page.regions[i], Paint()..color = Color(hint));
          });
        }
      }
    }
    _drawSequence(canvas, ops, bounds);
    if (live != null) _drawSequence(canvas, <PaintOp>[live!], bounds);
    canvas.restore();

    // ── Couche encre ──────────────────────────────────────────────────────
    _drawInk(canvas);

    // ── Autocollants ──────────────────────────────────────────────────────
    _drawStickers(canvas);

    canvas.restore();
  }

  /// Zone à laquelle une opération est confinée, ou `null` si elle va partout.
  static int? _regionOf(PaintOp op) => switch (op) {
        FillOp(:final int region) => region,
        StrokeOp(:final int? clipRegion) => clipRegion,
        ClearOp() || StickerOp() || RemoveStickerOp() => null,
      };

  /// Exécute [draw] en ne laissant subsister que la surface visible de [region].
  ///
  /// La zone est d'abord détourée sur son contour brut, puis les zones posées
  /// par-dessus sont RETIRÉES AU PINCEAU dans le calque. Aucune géométrie
  /// booléenne n'intervient : c'est le rasteriseur qui tranche, et il donne le
  /// même résultat sur toutes les plateformes — ce que `Path.combine` ne
  /// garantissait pas.
  void _confined(Canvas canvas, int region, void Function() draw) {
    final Rect scope = region == kBackgroundRegion
        ? (Offset.zero & page.source.size)
        : page.regionBounds[region];

    canvas.saveLayer(scope, Paint());
    canvas.save();
    if (region != kBackgroundRegion) {
      canvas.clipPath(page.regions[region], doAntiAlias: true);
    }
    draw();
    canvas.restore(); // on lève le détourage, on garde le calque

    final Paint erase = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;
    for (final int j in page.above(region)) {
      canvas.drawPath(page.regions[j], erase);
    }
    canvas.restore();
  }

  /// Dessine la suite d'opérations en regroupant celles qui se suivent dans une
  /// même zone : un calque par groupe, et non par opération.
  ///
  /// Deux opérations de zones différentes ne se recouvrent jamais une fois les
  /// zones supérieures découpées : leur ordre relatif est donc sans effet, et
  /// le regroupement ne change rien à ce que voit l'enfant.
  void _drawSequence(Canvas canvas, List<PaintOp> list, Rect bounds) {
    int i = 0;
    while (i < list.length) {
      final PaintOp op = list[i];
      if (op is StickerOp || op is RemoveStickerOp) {
        i++; // couche du dessus, posée après l'encre
        continue;
      }
      if (op is ClearOp) {
        canvas.drawRect(bounds, Paint()..blendMode = BlendMode.clear);
        i++;
        continue;
      }
      final int? region = _regionOf(op);
      int j = i + 1;
      while (j < list.length &&
          (list[j] is StrokeOp || list[j] is FillOp) &&
          _regionOf(list[j]) == region) {
        j++;
      }
      if (region == null) {
        for (int k = i; k < j; k++) {
          _drawOne(canvas, list[k]);
        }
      } else {
        final int from = i, to = j;
        _confined(canvas, region, () {
          for (int k = from; k < to; k++) {
            _drawOne(canvas, list[k]);
          }
        });
      }
      i = j;
    }
  }

  void _drawOne(Canvas canvas, PaintOp op) {
    switch (op) {
      case ClearOp():
      case StickerOp():
      case RemoveStickerOp():
        break; // traités ailleurs
      case FillOp():
        // Le contour brut suffit : _confined a déjà posé le détourage et
        // retirera les zones supérieures.
        canvas.drawPath(
          op.region == kBackgroundRegion
              ? (Path()..addRect(Offset.zero & page.source.size))
              : page.regions[op.region],
          patternBrush(op.pattern, Color(op.color)),
        );
      case StrokeOp():
        switch (op.tool) {
          case ToolKind.feutre:
            _drawMarker(canvas, op);
          case ToolKind.crayon:
            _drawCrayon(canvas, op);
          case ToolKind.gomme:
            _drawEraser(canvas, op);
          case ToolKind.pot:
          case ToolKind.autocollant:
            break; // ni le pot ni l'autocollant n'émettent de StrokeOp
        }
    }
  }

  /// Feutre : opaque, régulier, franc. L'outil « qui remplit vite ».
  void _drawMarker(Canvas canvas, StrokeOp op) {
    canvas.drawPath(
      _smoothPath(op.points),
      patternBrush(op.pattern, Color(op.color))
        ..style = PaintingStyle.stroke
        ..strokeWidth = op.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  /// Crayon de cire : translucide et granuleux, il se superpose à lui-même.
  /// Trois passes décalées de façon déterministe (graine stockée dans l'op)
  /// donnent le grain sans coûter de texture ni casser le rejeu à l'identique.
  void _drawCrayon(Canvas canvas, StrokeOp op) {
    final Color base = Color(op.color);
    final math.Random rng = math.Random(op.seed);
    final Path path = _smoothPath(op.points);

    canvas.drawPath(
      path,
      patternBrush(op.pattern, base.withValues(alpha: 0.45))
        ..style = PaintingStyle.stroke
        ..strokeWidth = op.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    for (int pass = 0; pass < 3; pass++) {
      final double dx = (rng.nextDouble() - 0.5) * op.width * 0.42;
      final double dy = (rng.nextDouble() - 0.5) * op.width * 0.42;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.drawPath(
        path,
        patternBrush(op.pattern, base.withValues(alpha: 0.20))
          ..style = PaintingStyle.stroke
          ..strokeWidth = op.width * (0.42 + rng.nextDouble() * 0.34)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
      canvas.restore();
    }
  }

  /// Gomme : efface la couche couleur, jamais le trait noir — impossible
  /// d'abîmer le dessin de départ.
  void _drawEraser(Canvas canvas, StrokeOp op) {
    canvas.drawPath(
      _smoothPath(op.points),
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = op.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  void _drawInk(Canvas canvas) {
    final Paint ink = Paint()
      ..color = const Color(0xFF1B1917)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * inkScale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    if (page.source.drawRegionOutlines) {
      for (int i = 0; i < page.regions.length; i++) {
        // Le trait d'une oreille doit s'arrêter net au bord de la tête, comme
        // dans un vrai album. On le pose dans un calque, puis on retire les
        // zones supérieures — même mécanique que pour la couleur.
        canvas.saveLayer(page.regionBounds[i].inflate(ink.strokeWidth), Paint());
        canvas.drawPath(page.regions[i], ink);
        final Paint erase = Paint()
          ..blendMode = BlendMode.clear
          ..isAntiAlias = true;
        for (final int j in page.above(i)) {
          canvas.drawPath(page.regions[j], erase);
        }
        canvas.restore();
      }
    }
    for (final (Path p, double w, int? clip) in page.details) {
      if (clip != null) {
        canvas.save();
        canvas.clipPath(page.regions[clip], doAntiAlias: true);
      }
      if (w == 0) {
        canvas.drawPath(p, Paint()..color = const Color(0xFF1B1917)..isAntiAlias = true);
      } else {
        canvas.drawPath(
          p,
          Paint()
            ..color = const Color(0xFF1B1917)
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * inkScale
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true,
        );
      }
      if (clip != null) canvas.restore();
    }
  }

  /// Les autocollants encore posés, puis le cadre de celui qu'on manipule.
  void _drawStickers(Canvas canvas) {
    for (final StickerOp st in visibleStickers(ops)) {
      final double side = kStickerSize * st.scale;
      canvas.save();
      canvas.translate(st.center.dx, st.center.dy);
      canvas.rotate(st.rotation);
      canvas.translate(-side / 2, -side / 2);
      paintSticker(canvas, st.kind, side);
      canvas.restore();
    }

    final StickerOp? sel = selected;
    if (sel == null) return;

    // Le cadre et sa croix gardent une taille constante quelle que soit celle
    // de l'autocollant : sur un tout petit soleil, une croix minuscule serait
    // impossible à viser avec un doigt d'enfant.
    final double half = kStickerSize * sel.scale / 2 + kStickerFrameGap;
    canvas.save();
    canvas.translate(sel.center.dx, sel.center.dy);
    canvas.rotate(sel.rotation);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCircle(center: Offset.zero, radius: half),
        const Radius.circular(18),
      ),
      Paint()
        ..color = const Color(0xFF2C7BE5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..isAntiAlias = true,
    );

    final Offset cross = Offset(half, -half);
    canvas.drawCircle(
      cross,
      kStickerHandleRadius,
      Paint()
        ..color = const Color(0xFFE23B3B)
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      cross,
      kStickerHandleRadius,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..isAntiAlias = true,
    );
    final Paint bar = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    const double a = kStickerHandleRadius * 0.42;
    canvas.drawLine(cross + const Offset(-a, -a), cross + const Offset(a, a), bar);
    canvas.drawLine(cross + const Offset(-a, a), cross + const Offset(a, -a), bar);
    canvas.restore();
  }

  static Path _smoothPath(List<Offset> pts) => smoothPathOfPoints(pts);

  @override
  bool shouldRepaint(ArtworkPainter old) =>
      old.page != page ||
      old.ops.length != ops.length ||
      !identical(old.ops, ops) ||
      old.live != live ||
      old.live?.points.length != live?.points.length ||
      !identical(old.selected, selected) ||
      old.showHints != showHints;
}

/// Écart entre l'autocollant et son cadre de sélection, en coordonnées page.
const double kStickerFrameGap = 16;

/// Rayon de la croix de retrait. Large : la page fait 1000 unités pour environ
/// 700 points à l'écran, une pastille de 30 unités en occupe une vingtaine.
const double kStickerHandleRadius = 30;

/// Rayon de la CIBLE de la croix, plus généreux que la pastille elle-même :
/// un doigt de trois ans vise mal.
const double kStickerGrabRadius = 44;

/// Position de la croix de retrait de [st], en coordonnées page.
///
/// Le peintre la dessine et le geste doit la viser : une seule formule pour
/// les deux, sinon la croix finirait par ne plus être là où l'on appuie.
Offset stickerHandleAt(StickerOp st) {
  final double d = kStickerSize * st.scale / 2 + kStickerFrameGap;
  final double c = math.cos(st.rotation), s = math.sin(st.rotation);
  return st.center + Offset(d * c + d * s, d * s - d * c);
}

/// Vrai si [p] (coordonnées page) touche [st].
///
/// Boîte carrée plutôt que silhouette exacte : un enfant vise le voisinage
/// d'un autocollant, pas le creux entre deux branches d'une étoile.
bool stickerHit(StickerOp st, Offset p) {
  final Offset d = p - st.center;
  final double c = math.cos(-st.rotation), s = math.sin(-st.rotation);
  final Offset local = Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
  final double half = kStickerSize * st.scale / 2;
  return local.dx.abs() <= half && local.dy.abs() <= half;
}

/// Lisse la suite de points du doigt en courbes quadratiques passant par les
/// milieux de segments : c'est ce qui évite l'aspect « polygone » d'un geste
/// rapide sur tablette.
///
/// Exposé parce que l'Atelier doit enregistrer exactement le trait que l'enfant
/// a vu se former ; `smoothPathData` en produit la version sérialisée.
Path smoothPathOfPoints(List<Offset> pts) {
  final Path path = Path();
  if (pts.isEmpty) return path;
  if (pts.length == 1) {
    // Un simple tap doit poser un point : segment nul + StrokeCap.round.
    path.moveTo(pts.first.dx, pts.first.dy);
    path.lineTo(pts.first.dx, pts.first.dy);
    return path;
  }
  path.moveTo(pts.first.dx, pts.first.dy);
  for (int i = 1; i < pts.length - 1; i++) {
    final Offset mid = Offset(
      (pts[i].dx + pts[i + 1].dx) / 2,
      (pts[i].dy + pts[i + 1].dy) / 2,
    );
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

/// Rend une œuvre en image PNG — export, partage, vignette de « Mes coloriages ».
Future<ui.Image> renderArtwork(
  CompiledPage page,
  List<PaintOp> ops, {
  double pixelWidth = 1400,
}) async {
  final double scale = pixelWidth / page.source.size.width;
  final Size target = page.source.size * scale;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  ArtworkPainter(page: page, ops: ops, live: null).paint(canvas, target);
  return recorder.endRecording().toImage(target.width.round(), target.height.round());
}
