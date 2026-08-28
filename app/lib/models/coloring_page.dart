import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

/// Une zone coloriable du dessin.
///
/// Les dessins de la bibliothèque sont vectoriels : la zone EST un [Path]. Le
/// test de contact et le détourage sont donc exacts, et le rendu reste net sur
/// n'importe quel écran (téléphone comme tablette 12,9").
class RegionData {
  const RegionData(this.id, this.d, {this.hint});

  final String id;

  /// Données de chemin SVG, en coordonnées page.
  final String d;

  /// Couleur « comme sur le modèle », proposée par l'aide au coloriage.
  final int? hint;
}

/// Un trait d'encre seul (moustache, sourire, pupille) : jamais coloriable.
class DetailData {
  const DetailData(this.d, [this.width = 6.0, this.clip]);

  final String d;

  /// Épaisseur du trait. `0` signifie « chemin plein » (pupille, par exemple).
  final double width;

  /// Zone à laquelle le trait est confiné, s'il y en a une : les gaufrages du
  /// cornet de glace ne doivent pas déborder sur les boules.
  final int? clip;
}

class ColoringPage {
  const ColoringPage({
    required this.id,
    required this.title,
    required this.category,
    required this.emoji,
    required this.size,
    required this.regions,
    this.details = const <DetailData>[],
  });

  final String id;
  final String title;
  final String category;
  final String emoji;
  final Size size;
  final List<RegionData> regions;
  final List<DetailData> details;
}

/// Version « compilée » d'une page : chemins analysés une seule fois, puis mis
/// en cache pour toute la durée de vie de l'application.
class CompiledPage {
  CompiledPage._(
    this.source,
    this.regions,
    this.zones,
    this.inkClips,
    this.details,
    this.background,
  );

  final ColoringPage source;

  /// Contours bruts, tels qu'ils sont dessinés à l'encre.
  final List<Path> regions;

  /// Surface RÉELLEMENT coloriable de chaque zone : son contour moins les zones
  /// posées par-dessus. Sans cette soustraction, peindre le corps du chat
  /// ferait apparaître de la couleur derrière sa tête restée blanche.
  final List<Path> zones;

  /// Masque d'encre de chaque zone : la page moins les zones posées par-dessus.
  /// Le trait d'une oreille s'arrête donc net au bord de la tête, comme dans un
  /// vrai album de coloriage, au lieu de la traverser.
  final List<Path> inkClips;

  /// `(chemin, épaisseur, zone de confinement)` — épaisseur 0 = chemin plein.
  final List<(Path, double, int?)> details;

  /// Le fond : la page entière moins toutes les zones. Colorier « à côté » du
  /// personnage sans déborder dessus reste ainsi possible.
  final Path background;

  static final Map<String, CompiledPage> _cache = <String, CompiledPage>{};

  static CompiledPage of(ColoringPage page) {
    return _cache.putIfAbsent(page.id, () {
      final List<Path> regions =
          page.regions.map((RegionData r) => parseSvgPathData(r.d)).toList();
      final List<(Path, double, int?)> details = page.details
          .map((DetailData d) => (parseSvgPathData(d.d), d.width, d.clip))
          .toList();

      final Path full = Path()
        ..addRect(Rect.fromLTWH(0, 0, page.size.width, page.size.height));

      // Unions suffixes : `above[i]` = tout ce qui est peint APRÈS la zone i.
      // Calculé de la fin vers le début, soit une seule opération booléenne par
      // zone au lieu d'une par paire.
      final int n = regions.length;
      final List<Path> above = List<Path>.filled(n + 1, Path(), growable: false);
      above[n] = Path();
      for (int i = n - 1; i >= 0; i--) {
        above[i] = Path.combine(PathOperation.union, above[i + 1], regions[i]);
      }

      final List<Path> zones = <Path>[];
      final List<Path> inkClips = <Path>[];
      for (int i = 0; i < n; i++) {
        zones.add(Path.combine(PathOperation.difference, regions[i], above[i + 1]));
        inkClips.add(Path.combine(PathOperation.difference, full, above[i + 1]));
      }

      final Path background =
          Path.combine(PathOperation.difference, full, above[0]);

      return CompiledPage._(
          page, regions, zones, inkClips, details, background);
    });
  }

  /// Index de la zone sous le point [p], en coordonnées page.
  /// Retourne [kBackgroundRegion] pour le fond.
  ///
  /// Le parcours se fait du haut vers le bas de la pile : l'œil posé sur la
  /// tête l'emporte sur la tête.
  int hitTest(Offset p) {
    for (int i = regions.length - 1; i >= 0; i--) {
      if (regions[i].contains(p)) return i;
    }
    return kBackgroundRegion;
  }

  /// Surface à peindre / à détourer pour la zone [index].
  Path pathForRegion(int index) =>
      index == kBackgroundRegion ? background : zones[index];
}

/// Index conventionnel du fond de page.
const int kBackgroundRegion = -1;
