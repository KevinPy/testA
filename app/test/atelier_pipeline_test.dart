import 'dart:typed_data';
import 'dart:ui';

import 'package:barbouille/atelier/creation_store.dart';
import 'package:barbouille/atelier/zone_tracer.dart';
import 'package:barbouille/l10n/app_strings.dart';
import 'package:barbouille/models/coloring_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rejoue la chaîne complète de l'Atelier — encre rasterisée, zones déduites,
/// page compilée — et vérifie qu'un doigt posé dans une forme y trouve bien sa
/// zone. C'est le contrat que voit l'enfant : un pot de peinture dans la tête
/// remplit la tête.
void main() {
  const int side = 256;
  const Size page = Size(1000, 1000);

  Uint8List twoCircles() {
    final Uint8List px = Uint8List(side * side * 4);
    bool ring(int x, int y, double cx, double cy, double r) {
      final double d = (Offset(x.toDouble(), y.toDouble()) - Offset(cx, cy)).distance;
      return d > r - 3 && d < r + 3;
    }

    for (int y = 0; y < side; y++) {
      for (int x = 0; x < side; x++) {
        if (ring(x, y, 128, 77, 49) || ring(x, y, 128, 179, 64)) {
          px[(y * side + x) * 4 + 3] = 255;
        }
      }
    }
    return px;
  }

  ColoringPage build(TracedZones z) => ColoringPage(
        id: 'atelier_test',
        title: const L10nText(fr: 'Mon dessin 1', en: 'My drawing 1'),
        category: kAtelierCategory,
        emoji: '✏️',
        size: page,
        regions: <RegionData>[
          for (int i = 0; i < z.length; i++) RegionData('z$i', z.paths[i]),
        ],
        drawRegionOutlines: false,
      );

  test('un doigt posé dans une forme trouve sa zone, pas le fond', () {
    final TracedZones z = traceZones(
      rgba: twoCircles(),
      width: side,
      height: side,
      pageSize: page,
      minArea: minAreaFor(side),
    );
    final CompiledPage c = CompiledPage.of(build(z));
    addTearDown(() => CompiledPage.evict('atelier_test'));

    const Offset head = Offset(500, 300);
    const Offset body = Offset(500, 700);
    const Offset corner = Offset(30, 30);

    final int hHead = c.hitTest(head);
    final int hBody = c.hitTest(body);
    final int hCorner = c.hitTest(corner);

    expect(hHead, isNot(kBackgroundRegion));
    expect(hBody, isNot(kBackgroundRegion));
    expect(hHead, isNot(hBody), reason: 'tête et corps sont deux zones');
    expect(hCorner, isNot(hHead), reason: 'le coin est le fond, pas la tête');
  });

  test('la surface peinte d\'une zone couvre bien la forme touchée', () {
    final TracedZones z = traceZones(
      rgba: twoCircles(),
      width: side,
      height: side,
      pageSize: page,
      minArea: minAreaFor(side),
    );
    final CompiledPage c = CompiledPage.of(build(z));
    addTearDown(() => CompiledPage.evict('atelier_test'));

    const Offset head = Offset(500, 300);
    final Path painted = c.pathForRegion(c.hitTest(head));
    expect(painted.contains(head), isTrue,
        reason: 'le pot doit peindre là où le doigt s\'est posé');

    // Et cette surface ne doit pas déborder sur le corps.
    expect(painted.contains(const Offset(500, 700)), isFalse);
  });

  test('la zone du fond exclut les formes posées dessus', () {
    final TracedZones z = traceZones(
      rgba: twoCircles(),
      width: side,
      height: side,
      pageSize: page,
      minArea: minAreaFor(side),
    );
    final CompiledPage c = CompiledPage.of(build(z));
    addTearDown(() => CompiledPage.evict('atelier_test'));

    // Le fond est la plus grande zone : l'index 0 après le tri décroissant.
    final Path background = c.pathForRegion(0);
    expect(background.contains(const Offset(30, 30)), isTrue);
    expect(background.contains(const Offset(500, 300)), isFalse,
        reason: 'sinon peindre le fond repeindrait tout le dessin');
  });
}
