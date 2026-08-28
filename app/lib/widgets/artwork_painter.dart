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
          canvas.drawPath(page.zones[i], Paint()..color = Color(hint));
        }
      }
    }
    for (final PaintOp op in ops) {
      _drawOp(canvas, op, bounds);
    }
    if (live != null) _drawOp(canvas, live!, bounds);
    canvas.restore();

    // ── Couche encre ──────────────────────────────────────────────────────
    _drawInk(canvas);

    canvas.restore();
  }

  void _drawOp(Canvas canvas, PaintOp op, Rect bounds) {
    switch (op) {
      case ClearOp():
        // Efface la couche couleur, pas le papier ni l'encre : le calque isolé
        // ouvert dans `paint` garantit que le trait noir survit.
        canvas.drawRect(bounds, Paint()..blendMode = BlendMode.clear);
      case FillOp():
        canvas.drawPath(
          page.pathForRegion(op.region),
          Paint()
            ..color = Color(op.color)
            ..isAntiAlias = true,
        );
      case StrokeOp():
        final int? clip = op.clipRegion;
        if (clip != null) {
          canvas.save();
          canvas.clipPath(page.pathForRegion(clip), doAntiAlias: true);
        }
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
        if (clip != null) canvas.restore();
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

    for (int i = 0; i < page.regions.length; i++) {
      canvas.save();
      canvas.clipPath(page.inkClips[i], doAntiAlias: true);
      canvas.drawPath(page.regions[i], ink);
      canvas.restore();
    }
    for (final (Path p, double w, int? clip) in page.details) {
      if (clip != null) {
        canvas.save();
        canvas.clipPath(page.pathForRegion(clip), doAntiAlias: true);
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

  /// Lisse la suite de points du doigt en courbes quadratiques passant par les
  /// milieux de segments : c'est ce qui évite l'aspect « polygone » d'un geste
  /// rapide sur tablette.
  static Path _smoothPath(List<Offset> pts) {
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

  @override
  bool shouldRepaint(ArtworkPainter old) =>
      old.page != page ||
      old.ops.length != ops.length ||
      !identical(old.ops, ops) ||
      old.live != live ||
      old.live?.points.length != live?.points.length ||
      old.showHints != showHints;
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
