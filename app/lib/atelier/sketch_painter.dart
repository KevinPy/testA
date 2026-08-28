import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../widgets/artwork_painter.dart';
import 'sketch_controller.dart';

/// Rend le dessin de l'Atelier : de l'encre noire sur une feuille blanche.
///
/// La gomme retire réellement de l'encre — `BlendMode.clear` dans un calque
/// isolé — parce que c'est cette image qui servira ensuite à déduire les zones.
/// Une gomme qui se contenterait de peindre en blanc laisserait un trait
/// invisible à l'œil mais bien présent pour l'analyse.
class SketchPainter extends CustomPainter {
  SketchPainter({
    required this.controller,
    this.background = const Color(0xFFFFFFFF),
  });

  final SketchController controller;
  final Color background;

  static const Color ink = Color(0xFF1B1917);

  @override
  void paint(Canvas canvas, Size size) {
    final Size page = controller.size;
    final double scale = math.min(size.width / page.width, size.height / page.height);
    canvas.save();
    canvas.translate(
      (size.width - page.width * scale) / 2,
      (size.height - page.height * scale) / 2,
    );
    canvas.scale(scale);

    final Rect bounds = Offset.zero & page;
    if (background.a > 0) {
      canvas.drawRect(bounds, Paint()..color = background);
    }

    canvas.saveLayer(bounds, Paint());
    for (final SketchStroke s in controller.strokes) {
      _stroke(canvas, s);
    }
    final SketchStroke? live = controller.live;
    if (live != null) _stroke(canvas, live);
    canvas.restore();

    canvas.restore();
  }

  void _stroke(Canvas canvas, SketchStroke s) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    if (s.erase) {
      paint.blendMode = BlendMode.clear;
    } else {
      paint.color = ink;
    }
    canvas.drawPath(smoothPathOfPoints(s.points), paint);
  }

  @override
  bool shouldRepaint(SketchPainter old) =>
      old.controller != controller ||
      old.controller.strokes.length != controller.strokes.length ||
      old.controller.live?.points.length != controller.live?.points.length;
}

/// Rasterise l'encre seule, fond transparent, pour l'analyse des zones.
///
/// Le fond doit rester transparent : le traceur distingue l'encre du vide par
/// l'alpha, et une feuille blanche opaque rendrait tout le dessin « plein ».
Future<ui.Image> rasterizeInk(SketchController controller, int side) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  SketchPainter(controller: controller, background: const Color(0x00000000))
      .paint(canvas, Size(side.toDouble(), side.toDouble()));
  return recorder.endRecording().toImage(side, side);
}
