import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pattern.dart' show heartPath, starPath;

/// Les autocollants.
///
/// Ils sont DESSINÉS, pas importés : ni fichier d'image dans le paquet, ni
/// police d'émojis à télécharger au premier affichage. Ce sont des chemins
/// vectoriels, donc nets sur une vignette de tiroir comme dans un export en
/// 2048 points, et identiques sur iOS, Android et le web.
enum StickerKind {
  etoile, coeur, arcenciel, soleil,
  lune, nuage, fleur, papillon,
  coccinelle, poisson, ballon, fusee,
  voiture, glace, cupcake, couronne,
}

/// Côté d'un autocollant posé, en coordonnées page, à l'échelle 1.
/// La page fait 1000 : un autocollant occupe donc environ un sixième du côté.
const double kStickerSize = 170;

/// Bornes du pincement. En dessous, l'autocollant devient impossible à
/// rattraper du doigt ; au-dessus, il mange le dessin entier.
const double kStickerMinScale = 0.4;
const double kStickerMaxScale = 3.0;

/// Dessine [kind] dans le carré `0..s`.
void paintSticker(Canvas canvas, StickerKind kind, double s) {
  Paint fill(int argb) => Paint()
    ..color = Color(argb)
    ..isAntiAlias = true;

  Paint line(int argb, double w) => Paint()
    ..color = Color(argb)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * s
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Offset p(double x, double y) => Offset(x * s, y * s);

  void circle(double x, double y, double r, int argb) =>
      canvas.drawCircle(p(x, y), r * s, fill(argb));

  void oval(double x, double y, double rx, double ry, int argb) =>
      canvas.drawOval(
        Rect.fromCenter(center: p(x, y), width: rx * 2 * s, height: ry * 2 * s),
        fill(argb),
      );

  /// Polygone donné en couples `x, y` — la forme la plus courte pour décrire
  /// une silhouette anguleuse.
  Path poly(List<double> xy) {
    final Path path = Path()..moveTo(xy[0] * s, xy[1] * s);
    for (int i = 2; i + 1 < xy.length; i += 2) {
      path.lineTo(xy[i] * s, xy[i + 1] * s);
    }
    return path..close();
  }

  switch (kind) {
    case StickerKind.etoile:
      final Path star = starPath(p(0.5, 0.53), 0.45 * s, 0.19 * s);
      canvas.drawPath(star, fill(0xFFFFC531));
      canvas.drawPath(star, line(0xFFE09000, 0.035));

    case StickerKind.coeur:
      final Path heart = heartPath(p(0.5, 0.5), 0.4 * s);
      canvas.drawPath(heart, fill(0xFFE23B3B));
      canvas.drawPath(heart, line(0xFFA82020, 0.035));

    case StickerKind.arcenciel:
      const List<int> bands = <int>[
        0xFFE23B3B, 0xFFFF9A2B, 0xFFFFD233, 0xFF63C132, 0xFF3C8CE8,
      ];
      for (int i = 0; i < bands.length; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: p(0.5, 0.86), radius: (0.42 - i * 0.085) * s),
          math.pi, math.pi, false,
          line(bands[i], 0.085),
        );
      }

    case StickerKind.soleil:
      for (int i = 0; i < 8; i++) {
        final double a = i * math.pi / 4;
        final Offset u = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          p(0.5, 0.5) + u * 0.32 * s,
          p(0.5, 0.5) + u * 0.47 * s,
          line(0xFFFFB020, 0.075),
        );
      }
      circle(0.5, 0.5, 0.27, 0xFFFFD233);

    case StickerKind.lune:
      // Croissant creusé à la gomme dans un calque : le même procédé que pour
      // les zones du coloriage, et pour la même raison — les opérations
      // booléennes sur les chemins ne donnent pas le même résultat partout.
      canvas.saveLayer(Rect.fromLTWH(0, 0, s, s), Paint());
      circle(0.46, 0.5, 0.42, 0xFFFFD98A);
      canvas.drawCircle(
        p(0.68, 0.4),
        0.38 * s,
        Paint()
          ..blendMode = BlendMode.clear
          ..isAntiAlias = true,
      );
      canvas.restore();

    case StickerKind.nuage:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.14 * s, 0.54 * s, 0.72 * s, 0.22 * s),
          Radius.circular(0.11 * s),
        ),
        fill(0xFFBCE0FA),
      );
      circle(0.34, 0.54, 0.20, 0xFFBCE0FA);
      circle(0.53, 0.44, 0.25, 0xFFBCE0FA);
      circle(0.70, 0.56, 0.17, 0xFFBCE0FA);

    case StickerKind.fleur:
      for (int i = 0; i < 6; i++) {
        final double a = i * math.pi / 3;
        circle(0.5 + math.cos(a) * 0.26, 0.5 + math.sin(a) * 0.26, 0.17,
            0xFFFF8FB1);
      }
      circle(0.5, 0.5, 0.155, 0xFFFFD233);

    case StickerKind.papillon:
      canvas.drawLine(p(0.47, 0.30), p(0.36, 0.13), line(0xFF4A3F35, 0.026));
      canvas.drawLine(p(0.53, 0.30), p(0.64, 0.13), line(0xFF4A3F35, 0.026));
      canvas.drawCircle(p(0.36, 0.13), 0.035 * s, fill(0xFF4A3F35));
      canvas.drawCircle(p(0.64, 0.13), 0.035 * s, fill(0xFF4A3F35));
      // Des ovales, pas des ronds : quatre cercles agrandis trois fois ne
      // ressemblent plus à un papillon mais à une grappe de raisin.
      oval(0.30, 0.35, 0.21, 0.165, 0xFFB07BE8);
      oval(0.70, 0.35, 0.21, 0.165, 0xFFB07BE8);
      oval(0.34, 0.66, 0.165, 0.135, 0xFF8B5FD6);
      oval(0.66, 0.66, 0.165, 0.135, 0xFF8B5FD6);
      circle(0.28, 0.34, 0.055, 0x66FFFFFF);
      circle(0.72, 0.34, 0.055, 0x66FFFFFF);
      oval(0.5, 0.5, 0.045, 0.27, 0xFF4A3F35);

    case StickerKind.coccinelle:
      circle(0.5, 0.55, 0.36, 0xFFE23B3B);
      circle(0.5, 0.22, 0.17, 0xFF2A2521);
      canvas.drawLine(p(0.5, 0.21), p(0.5, 0.90), line(0xFF2A2521, 0.045));
      for (final Offset d in <Offset>[
        Offset(0.34, 0.44), Offset(0.66, 0.44),
        Offset(0.30, 0.62), Offset(0.70, 0.62),
        Offset(0.39, 0.78), Offset(0.61, 0.78),
      ]) {
        circle(d.dx, d.dy, 0.062, 0xFF2A2521);
      }

    case StickerKind.poisson:
      canvas.drawPath(
          poly(<double>[0.70, 0.5, 0.96, 0.28, 0.96, 0.72]), fill(0xFFF07A22));
      oval(0.45, 0.5, 0.32, 0.23, 0xFFFF9138);
      canvas.drawPath(
          poly(<double>[0.44, 0.29, 0.58, 0.13, 0.60, 0.32]), fill(0xFFF07A22));
      circle(0.32, 0.44, 0.075, 0xFFFFFFFF);
      circle(0.32, 0.44, 0.038, 0xFF2A2521);

    case StickerKind.ballon:
      canvas.drawPath(
        Path()
          ..moveTo(0.5 * s, 0.76 * s)
          ..quadraticBezierTo(0.60 * s, 0.86 * s, 0.56 * s, 0.96 * s),
        line(0xFF8A7A66, 0.022),
      );
      oval(0.5, 0.42, 0.27, 0.33, 0xFFE23B3B);
      canvas.drawPath(
          poly(<double>[0.44, 0.73, 0.56, 0.73, 0.5, 0.81]), fill(0xFFB32222));
      oval(0.40, 0.30, 0.07, 0.10, 0x66FFFFFF);

    case StickerKind.fusee:
      canvas.drawPath(
          poly(<double>[0.36, 0.72, 0.5, 0.98, 0.64, 0.72]), fill(0xFFFF9A2B));
      canvas.drawPath(
          poly(<double>[0.43, 0.72, 0.5, 0.90, 0.57, 0.72]), fill(0xFFFFD233));
      canvas.drawPath(
          poly(<double>[0.32, 0.48, 0.12, 0.76, 0.32, 0.70]), fill(0xFFE23B3B));
      canvas.drawPath(
          poly(<double>[0.68, 0.48, 0.88, 0.76, 0.68, 0.70]), fill(0xFFE23B3B));
      final Path body = Path()
        ..moveTo(0.5 * s, 0.05 * s)
        ..cubicTo(0.72 * s, 0.28 * s, 0.72 * s, 0.55 * s, 0.68 * s, 0.72 * s)
        ..lineTo(0.32 * s, 0.72 * s)
        ..cubicTo(0.28 * s, 0.55 * s, 0.28 * s, 0.28 * s, 0.5 * s, 0.05 * s)
        ..close();
      canvas.drawPath(body, fill(0xFFF2F0EA));
      canvas.drawPath(body, line(0xFF9C958C, 0.03));
      circle(0.5, 0.36, 0.11, 0xFF56B7E8);
      canvas.drawCircle(p(0.5, 0.36), 0.11 * s, line(0xFF9C958C, 0.03));

    case StickerKind.voiture:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.22 * s, 0.26 * s, 0.50 * s, 0.26 * s),
          Radius.circular(0.09 * s),
        ),
        fill(0xFFE23B3B),
      );
      canvas.drawRect(
          Rect.fromLTWH(0.28 * s, 0.32 * s, 0.17 * s, 0.15 * s),
          fill(0xFFBCE0FA));
      canvas.drawRect(
          Rect.fromLTWH(0.49 * s, 0.32 * s, 0.17 * s, 0.15 * s),
          fill(0xFFBCE0FA));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.05 * s, 0.46 * s, 0.90 * s, 0.27 * s),
          Radius.circular(0.10 * s),
        ),
        fill(0xFFE23B3B),
      );
      circle(0.28, 0.76, 0.135, 0xFF2A2521);
      circle(0.72, 0.76, 0.135, 0xFF2A2521);
      circle(0.28, 0.76, 0.06, 0xFFD8D3CC);
      circle(0.72, 0.76, 0.06, 0xFFD8D3CC);

    case StickerKind.glace:
      final Path cone = poly(<double>[0.33, 0.50, 0.67, 0.50, 0.5, 0.97]);
      canvas.drawPath(cone, fill(0xFFE0A85C));
      canvas.drawPath(cone, line(0xFFB98741, 0.028));
      circle(0.38, 0.44, 0.19, 0xFFFF8FB1);
      circle(0.62, 0.44, 0.19, 0xFF7FD9B0);
      circle(0.50, 0.25, 0.19, 0xFFFFD233);

    case StickerKind.cupcake:
      canvas.drawPath(
          poly(<double>[0.24, 0.54, 0.76, 0.54, 0.66, 0.94, 0.34, 0.94]),
          fill(0xFFF2A65A));
      circle(0.35, 0.46, 0.17, 0xFFFFB3C8);
      circle(0.65, 0.46, 0.17, 0xFFFFB3C8);
      circle(0.50, 0.30, 0.19, 0xFFFFB3C8);
      circle(0.50, 0.12, 0.075, 0xFFE23B3B);

    case StickerKind.couronne:
      final Path crown = poly(<double>[
        0.09, 0.78, 0.15, 0.26, 0.32, 0.52, 0.5, 0.18,
        0.68, 0.52, 0.85, 0.26, 0.91, 0.78,
      ]);
      canvas.drawPath(crown, fill(0xFFFFC531));
      canvas.drawPath(crown, line(0xFFE09000, 0.035));
      circle(0.29, 0.66, 0.055, 0xFFE23B3B);
      circle(0.50, 0.66, 0.055, 0xFF56B7E8);
      circle(0.71, 0.66, 0.055, 0xFF63C132);
  }
}
