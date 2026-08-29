import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/coloring_page.dart';
import '../models/paint_op.dart';
import '../models/tool.dart';

/// Rendu d'un coloriage.
///
/// Le modèle de composition tient en trois couches, toujours dans cet ordre :
///
///   1. le papier ;
///   2. la COUCHE COULEUR — tout ce que l'enfant a posé ;
///   3. la COUCHE ENCRE — le trait noir du dessin.
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

    canvas.restore();
  }

  /// Zone à laquelle une opération est confinée, ou `null` si elle va partout.
  static int? _regionOf(PaintOp op) => switch (op) {
        FillOp(:final int region) => region,
        StrokeOp(:final int? clipRegion) => clipRegion,
        ClearOp() => null,
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
      if (op is ClearOp) {
        canvas.drawRect(bounds, Paint()..blendMode = BlendMode.clear);
        i++;
        continue;
      }
      final int? region = _regionOf(op);
      int j = i + 1;
      while (j < list.length &&
          list[j] is! ClearOp &&
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
        break; // traité par _drawSequence
      case FillOp():
        // Le contour brut suffit : _confined a déjà posé le détourage et
        // retirera les zones supérieures.
        canvas.drawPath(
          op.region == kBackgroundRegion
              ? (Path()..addRect(Offset.zero & page.source.size))
              : page.regions[op.region],
          Paint()
            ..color = Color(op.color)
            ..isAntiAlias = true,
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
            break; // le pot n'émet jamais de StrokeOp
        }
    }
  }

  /// Feutre : opaque, régulier, franc. L'outil « qui remplit vite ».
  void _drawMarker(Canvas canvas, StrokeOp op) {
    canvas.drawPath(
      _smoothPath(op.points),
      Paint()
        ..color = Color(op.color)
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
      Paint()
        ..color = base.withValues(alpha: 0.45)
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
        Paint()
          ..color = base.withValues(alpha: 0.20)
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

  static Path _smoothPath(List<Offset> pts) => smoothPathOfPoints(pts);

  @override
  bool shouldRepaint(ArtworkPainter old) =>
      old.page != page ||
      old.ops.length != ops.length ||
      !identical(old.ops, ops) ||
      old.live != live ||
      old.live?.points.length != live?.points.length ||
      old.showHints != showHints;
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
