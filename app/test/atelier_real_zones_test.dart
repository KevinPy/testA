import 'dart:ui';

import 'package:barbouille/l10n/app_strings.dart';
import 'package:barbouille/models/coloring_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les zones telles que l'Atelier les a réellement produites pour un bonhomme
/// dessiné à la main (tête + corps). Figées ici parce que les contours
/// synthétiques d'un test ne reproduisaient pas le défaut observé à l'écran.
const List<String> kRealZones = <String>[
        'M 0 0 L 1000 0 L 1000 1000 L 0 1000 L 0 2 Z',
        'M 402.3 468.8 L 427.7 470.7 L 445.3 484.4 L 490.2 492.2 L 541 488.3 L 554.7 484.4 L 572.3 470.7 L 597.7 468.8 L 613.3 482.4 L 632.8 490.2 L 636.7 496.1 L 664.1 513.7 L 687.5 537.1 L 724.6 593.8 L 738.3 630.9 L 748 695.3 L 744.1 742.2 L 732.4 787.1 L 705.1 839.8 L 679.7 867.2 L 679.7 871.1 L 646.5 900.4 L 599.6 927.7 L 564.5 939.5 L 511.7 947.3 L 453.1 943.4 L 400.4 927.7 L 353.5 900.4 L 332 878.9 L 328.1 878.9 L 298.8 845.7 L 273.4 800.8 L 261.7 769.5 L 253.9 730.5 L 253.9 669.9 L 267.6 615.2 L 291 566.4 L 296.9 562.5 L 314.5 535.2 L 335.9 513.7 L 363.3 496.1 L 367.2 490.2 L 386.7 482.4 L 390.6 476.6 L 402.3 470.7 Z',
        'M 474.6 117.2 L 537.1 119.1 L 597.7 142.6 L 619.1 158.2 L 646.5 185.5 L 669.9 220.7 L 677.7 240.2 L 687.5 283.2 L 687.5 324.2 L 677.7 369.1 L 652.3 416 L 597.7 468.8 L 568.4 470.7 L 548.8 457 L 523.4 453.1 L 460.9 455.1 L 439.5 462.9 L 431.6 470.7 L 402.3 468.8 L 347.7 416 L 322.3 367.2 L 312.5 324.2 L 312.5 283.2 L 322.3 242.2 L 341.8 201.2 L 380.9 158.2 L 402.3 142.6 L 455.1 121.1 L 474.6 119.1 Z',
        'M 476.6 453.1 L 523.4 453.1 L 548.8 457 L 572.3 472.7 L 548.8 486.3 L 509.8 492.2 L 451.2 486.3 L 427.7 472.7 L 451.2 457 L 476.6 455.1 Z',
];

void main() {
  ColoringPage build() => ColoringPage(
        id: 'atelier_reel',
        title: const L10nText(fr: 'Mon dessin 1', en: 'My drawing 1'),
        category: 'atelier',
        emoji: '✏️',
        size: const Size(1000, 1000),
        regions: <RegionData>[
          for (int i = 0; i < kRealZones.length; i++)
            RegionData('z$i', kRealZones[i]),
        ],
        drawRegionOutlines: false,
      );

  test('le fond réel exclut les formes posées dessus', () {
    final CompiledPage c = CompiledPage.of(build());
    addTearDown(() => CompiledPage.evict('atelier_reel'));

    expect(c.zoneContains(0, const Offset(30, 30)), isTrue,
        reason: 'le coin appartient au fond');
    expect(c.zoneContains(0, const Offset(500, 300)), isFalse,
        reason: 'peindre le fond ne doit pas repeindre la tête');
    expect(c.zoneContains(0, const Offset(500, 700)), isFalse,
        reason: 'peindre le fond ne doit pas repeindre le corps');
  });

  test('chaque forme se peint chez elle', () {
    final CompiledPage c = CompiledPage.of(build());
    addTearDown(() => CompiledPage.evict('atelier_reel'));

    for (final Offset p in <Offset>[const Offset(500, 300), const Offset(500, 700)]) {
      final int hit = c.hitTest(p);
      expect(hit, isNot(kBackgroundRegion));
      expect(c.zoneContains(hit, p), isTrue);
    }
  });
}
