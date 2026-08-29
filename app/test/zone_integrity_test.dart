import 'dart:ui';

import 'package:barbouille/data/pages.g.dart';
import 'package:barbouille/models/coloring_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que le pot de peinture promet : un appui dans une zone ne colorie que
/// cette zone.
///
/// Le défaut qui a motivé ces tests ne se voyait qu'à l'écran — sur le poisson,
/// peindre le corps coloriait aussi deux écailles et une nageoire. La surface
/// peinte se calculait par géométrie booléenne, le test de contact par
/// parcours des contours : deux vérités différentes, qui divergeaient sur le
/// moteur web. Il n'y en a plus qu'une, et elle est vérifiée ici.
void main() {
  /// Quelques points intérieurs d'une zone, échantillonnés dans son cadre.
  List<Offset> samples(Path p, {int steps = 11}) {
    final Rect b = p.getBounds();
    final List<Offset> inside = <Offset>[];
    for (int i = 1; i < steps; i++) {
      for (int j = 1; j < steps; j++) {
        final Offset o = Offset(
          b.left + b.width * i / steps,
          b.top + b.height * j / steps,
        );
        if (p.contains(o)) inside.add(o);
      }
    }
    return inside;
  }

  test('aucune zone ne revendique un point qui appartient à une autre', () {
    for (final ColoringPage page in kColoringPages) {
      final CompiledPage c = CompiledPage.of(page);
      for (int i = 0; i < c.regions.length; i++) {
        for (final Offset p in samples(c.regions[i])) {
          final int owner = c.hitTest(p);
          // Le propriétaire est toujours la zone la plus haute qui contient le
          // point : jamais une zone posée en dessous.
          expect(c.zoneContains(owner, p), isTrue,
              reason: '${page.id} : point $p sans propriétaire cohérent');
          expect(owner, greaterThanOrEqualTo(i),
              reason: '${page.id} : la zone $i revendique un point de $owner');
        }
      }
    }
  });

  test('le poisson : le corps ne revendique ni écailles ni nageoire', () {
    // Le cas signalé, figé. Les points sont les centres des formes concernées.
    final ColoringPage poisson =
        kColoringPages.firstWhere((ColoringPage p) => p.id == 'poisson');
    final CompiledPage c = CompiledPage.of(poisson);
    final int corps =
        poisson.regions.indexWhere((RegionData r) => r.id == 'corps');
    expect(c.zoneContains(corps, const Offset(600, 460)), isTrue,
        reason: 'le corps doit revendiquer son propre centre');

    for (final (String name, Offset centre) in <(String, Offset)>[
      ('ecaille1', Offset(560, 400)),
      ('ecaille2', Offset(672, 420)),
      ('ecaille3', Offset(616, 520)),
      ('ecaille4', Offset(728, 540)),
      ('nageoire_laterale', Offset(570, 615)),
      ('tete', Offset(370, 500)),
      ('oeil', Offset(372, 452)),
    ]) {
      expect(c.zoneContains(corps, centre), isFalse,
          reason: 'peindre le corps ne doit pas colorier $name');
    }
  });

  test('le fond ne revendique aucun point du dessin', () {
    for (final ColoringPage page in kColoringPages) {
      final CompiledPage c = CompiledPage.of(page);
      for (int i = 0; i < c.regions.length; i++) {
        for (final Offset p in samples(c.regions[i], steps: 7)) {
          expect(c.zoneContains(kBackgroundRegion, p), isFalse,
              reason: '${page.id} : peindre le fond déborderait sur le dessin');
        }
      }
    }
  });

  test('chaque zone garde au moins un point à elle', () {
    // Une zone entièrement recouverte serait injoignable au doigt : autant le
    // savoir, c'est un défaut de dessin.
    for (final ColoringPage page in kColoringPages) {
      final CompiledPage c = CompiledPage.of(page);
      for (int i = 0; i < c.regions.length; i++) {
        final bool reachable = samples(c.regions[i], steps: 15)
            .any((Offset p) => c.hitTest(p) == i);
        expect(reachable, isTrue,
            reason: '${page.id}/${page.regions[i].id} : zone injoignable');
      }
    }
  });
}
