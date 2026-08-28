@Tags(<String>['art'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:barbouille/data/pages.g.dart';
import 'package:barbouille/models/coloring_page.dart';
import 'package:barbouille/models/paint_op.dart';
import 'package:barbouille/widgets/artwork_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Planche de contrôle : rend chaque dessin de la bibliothèque en PNG, à vide
/// puis colorié avec les couleurs du modèle. Sert à relire les traits sans
/// lancer l'application. `flutter test test/render_pages_test.dart`
void main() {
  test('planche de contrôle des dessins', () async {
    final Directory dir = Directory('/tmp/pages')..createSync(recursive: true);
    for (final ColoringPage page in kColoringPages) {
      final CompiledPage c = CompiledPage.of(page);

      final ui.Image blank = await renderArtwork(c, const <PaintOp>[], pixelWidth: 640);
      File('${dir.path}/${page.id}.png')
          .writeAsBytesSync((await blank.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List());

      final List<PaintOp> hinted = <PaintOp>[
        for (int i = 0; i < page.regions.length; i++)
          if (page.regions[i].hint != null)
            FillOp(region: i, color: page.regions[i].hint!),
      ];
      final ui.Image filled = await renderArtwork(c, hinted, pixelWidth: 640);
      File('${dir.path}/${page.id}_couleur.png')
          .writeAsBytesSync((await filled.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List());
    }
    expect(dir.listSync().length, kColoringPages.length * 2);
  });
}
