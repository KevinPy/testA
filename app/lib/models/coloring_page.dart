import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

import '../l10n/app_strings.dart';

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
    this.drawRegionOutlines = true,
  });

  final String id;

  /// Le titre dans chaque langue. Traduire l'interface sans traduire « Le chat
  /// câlin » n'aurait produit qu'une application à moitié anglaise.
  final L10nText title;

  /// Identifiant de catégorie (`animaux`, `vehicules`…). Le libellé affiché
  /// vient de [AppStrings.category].
  final String category;

  final String emoji;
  final Size size;

  /// Les contours de zone servent-ils aussi d'encre ?
  ///
  /// Vrai pour la bibliothèque, où la zone EST le dessin. Faux pour l'Atelier,
  /// où les zones sont déduites des pixels : y repasser à l'encre doublerait
  /// le trait de l'enfant d'un liseré tremblant.
  final bool drawRegionOutlines;
  final List<RegionData> regions;
  final List<DetailData> details;
}

/// Version « compilée » d'une page : chemins analysés une seule fois, puis mis
/// en cache pour toute la durée de vie de l'application.
class CompiledPage {
  CompiledPage._(this.source, this.regions, this.regionBounds, this.details);

  final ColoringPage source;

  /// Contours bruts, tels qu'ils sont dessinés à l'encre.
  ///
  /// Il n'existe volontairement AUCUNE géométrie booléenne ici. La surface
  /// réellement coloriable d'une zone — son contour moins les zones posées
  /// par-dessus — n'est plus un chemin calculé, mais un résultat de rendu :
  /// [ArtworkPainter] peint la zone puis découpe les zones supérieures au
  /// pinceau.
  ///
  /// Ce choix vient d'un défaut visible : `Path.combine` ne donne pas le même
  /// résultat sur le moteur web que sur la machine virtuelle Dart. Sur le
  /// poisson, deux écailles et une nageoire se retrouvaient dans la zone du
  /// corps, que le pot de peinture coloriait avec lui — alors que les tests
  /// étaient au vert. Le test de contact, lui, n'a jamais utilisé de booléens :
  /// rendu et test de contact reposent désormais sur la même vérité.
  final List<Path> regions;

  /// Cadre de chaque contour, pour n'examiner que les zones qui se recoupent.
  final List<Rect> regionBounds;

  /// `(chemin, épaisseur, zone de confinement)` — épaisseur 0 = chemin plein.
  final List<(Path, double, int?)> details;

  static final Map<String, CompiledPage> _cache = <String, CompiledPage>{};

  /// Oublie une page compilée : une création supprimée ou refaite ne doit pas
  /// ressortir du cache.
  static void evict(String id) => _cache.remove(id);

  static CompiledPage of(ColoringPage page) {
    return _cache.putIfAbsent(page.id, () {
      final List<Path> regions =
          page.regions.map((RegionData r) => parseSvgPathData(r.d)).toList();
      final List<(Path, double, int?)> details = page.details
          .map((DetailData d) => (parseSvgPathData(d.d), d.width, d.clip))
          .toList();

      return CompiledPage._(
        page,
        regions,
        <Rect>[for (final Path p in regions) p.getBounds()],
        details,
      );
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

  /// Les zones posées APRÈS [index] qui recoupent son cadre — celles qu'il
  /// faut découper pour ne garder que sa surface visible. Pour le fond, ce
  /// sont toutes les zones.
  Iterable<int> above(int index) sync* {
    final int start = index == kBackgroundRegion ? 0 : index + 1;
    for (int j = start; j < regions.length; j++) {
      if (index != kBackgroundRegion &&
          !regionBounds[index].overlaps(regionBounds[j])) {
        continue;
      }
      yield j;
    }
  }

  /// Le point [p] appartient-il à la surface visible de la zone [region] ?
  ///
  /// Défini à partir de [hitTest], donc rigoureusement identique à ce que le
  /// doigt de l'enfant désigne — et à ce que le peintre colorie.
  bool zoneContains(int region, Offset p) => hitTest(p) == region;
}

/// Index conventionnel du fond de page.
const int kBackgroundRegion = -1;
