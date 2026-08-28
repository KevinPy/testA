import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/coloring_page.dart';
import '../models/paint_op.dart';
import '../widgets/artwork_painter.dart';

/// Encode une œuvre en PNG, prête à être enregistrée.
///
/// Ce n'est volontairement PAS une capture de l'écran : une vraie capture
/// embarquerait les barres d'outils, à la résolution de l'écran. On rend le
/// dessin seul, depuis la liste de ses opérations, donc à la résolution qu'on
/// veut — 2048 points de côté, de quoi imprimer en A4 à 180 dpi.
Future<Uint8List> encodeArtworkPng(
  CompiledPage page,
  List<PaintOp> ops, {
  int pixels = 2048,
  double marginRatio = 0.04,
}) async {
  final double margin = pixels * marginRatio;
  final double inner = pixels - margin * 2;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  // Une marge blanche autour du dessin : sans elle, un trait qui touche le
  // bord se retrouve coupé net contre le cadre de la photo.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, pixels.toDouble(), pixels.toDouble()),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  canvas.save();
  canvas.translate(margin, margin);
  ArtworkPainter(page: page, ops: ops, live: null)
      .paint(canvas, Size(inner, inner));
  canvas.restore();

  final ui.Image image =
      await recorder.endRecording().toImage(pixels, pixels);
  try {
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('encodage PNG vide');
    }
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Nom de fichier tiré du titre du dessin : « Le chat câlin » devient
/// `barbouille-le-chat-calin.png`. Un parent qui vide sa galerie doit pouvoir
/// reconnaître le fichier sans l'ouvrir.
String artworkFileName(String title) {
  const Map<String, String> accents = <String, String>{
    'à': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e',
    'ë': 'e', 'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u',
    'ü': 'u', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
  };
  final StringBuffer b = StringBuffer();
  for (final String c in title.toLowerCase().split('')) {
    final String plain = accents[c] ?? c;
    if (RegExp(r'[a-z0-9]').hasMatch(plain)) {
      b.write(plain);
    } else if (b.isNotEmpty && !b.toString().endsWith('-')) {
      b.write('-');
    }
  }
  final String slug = b.toString().replaceAll(RegExp(r'-+$'), '');
  return 'barbouille-${slug.isEmpty ? 'dessin' : slug}.png';
}
