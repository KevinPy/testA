import 'dart:ui';

import 'package:barbouille/widgets/sheet_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// La feuille est carrée ; l'écran ne l'est jamais. Ces tests fixent la règle
/// qui décide où poser les commandes, et surtout la part de l'écran que le
/// dessin doit conserver.
void main() {
  const Size page = Size(1000, 1000);

  test('iPhone en paysage : commandes sur les côtés, feuille pleine hauteur', () {
    const Size body = Size(852, 393);
    final SheetLayout l = SheetLayout.of(page, body);

    expect(l.placement, ControlPlacement.sides);
    expect(l.page.height, body.height, reason: 'la feuille prend toute la hauteur');
    expect(l.page.width, body.height, reason: 'elle reste carrée');
    // Avant la refonte, les barres laissaient environ 12 % de l'écran au
    // dessin. La feuille en occupe désormais la plus grande part possible.
    expect(l.coverage(body), greaterThan(0.45));
  });

  test('iPhone en portrait : commandes empilées', () {
    const Size body = Size(393, 852);
    final SheetLayout l = SheetLayout.of(page, body);

    expect(l.placement, ControlPlacement.stacked);
    expect(l.page.width, body.width);
    // Les marges haute et basse accueillent les commandes sans rogner la feuille.
    expect(l.page.top, greaterThan(200));
  });

  test('tablette en paysage : commandes sur les côtés', () {
    const Size body = Size(1194, 834);
    final SheetLayout l = SheetLayout.of(page, body);

    expect(l.placement, ControlPlacement.sides);
    expect(l.page.height, 834);
    expect(l.page.left, greaterThan(SheetLayout.of(page, body).page.left - 1));
  });

  test('écran presque carré : on empile plutôt que de serrer les côtés', () {
    const Size body = Size(700, 660);
    final SheetLayout l = SheetLayout.of(page, body);

    // 20 points de marge de chaque côté : une colonne de boutons n'y tiendrait
    // pas, on repasse donc en disposition empilée.
    expect(l.placement, ControlPlacement.stacked);
  });

  test('la feuille reste centrée et dans le cadre', () {
    for (final Size body in <Size>[
      const Size(852, 393),
      const Size(393, 852),
      const Size(1194, 834),
      const Size(320, 480),
      const Size(1024, 1024),
    ]) {
      final SheetLayout l = SheetLayout.of(page, body);
      expect(l.page.left, greaterThanOrEqualTo(-0.01), reason: '$body');
      expect(l.page.top, greaterThanOrEqualTo(-0.01), reason: '$body');
      expect(l.page.right, lessThanOrEqualTo(body.width + 0.01), reason: '$body');
      expect(l.page.bottom, lessThanOrEqualTo(body.height + 0.01), reason: '$body');
      expect((l.page.center.dx - body.width / 2).abs(), lessThan(0.01));
      expect((l.page.center.dy - body.height / 2).abs(), lessThan(0.01));
      expect(l.page.width, closeTo(l.page.height, 0.01), reason: 'feuille carrée');
    }
  });

  test('un écran carré donne une feuille qui remplit tout', () {
    const Size body = Size(800, 800);
    final SheetLayout l = SheetLayout.of(page, body);
    expect(l.coverage(body), closeTo(1.0, 0.001));
  });
}
