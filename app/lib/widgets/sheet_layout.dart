import 'dart:math' as math;
import 'dart:ui';

/// Où poser les commandes flottantes autour de la feuille.
enum ControlPlacement {
  /// Colonnes dans les marges gauche et droite — cas du paysage, où la feuille
  /// carrée occupe toute la hauteur et laisse de larges bandes sur les côtés.
  sides,

  /// Rangée en haut, bouton d'outils en bas — cas du portrait.
  stacked,
}

/// Géométrie de l'écran de dessin.
///
/// La feuille est carrée et l'écran ne l'est jamais : il reste donc toujours
/// des bandes vides. Y loger les commandes ne coûte pas un point de surface de
/// dessin — c'est tout l'objet de ce calcul.
class SheetLayout {
  const SheetLayout({required this.page, required this.placement});

  /// L'emplacement de la feuille dans le corps de l'écran.
  final Rect page;

  final ControlPlacement placement;

  /// Largeur minimale d'une marge pour qu'une colonne de commandes y tienne.
  static const double _sideRoom = 92;

  factory SheetLayout.of(Size pageSize, Size body) {
    final double scale =
        math.min(body.width / pageSize.width, body.height / pageSize.height);
    final double w = pageSize.width * scale;
    final double h = pageSize.height * scale;
    final Rect page = Rect.fromLTWH(
      (body.width - w) / 2,
      (body.height - h) / 2,
      w,
      h,
    );

    final double sideMargin = (body.width - w) / 2;
    return SheetLayout(
      page: page,
      placement: sideMargin >= _sideRoom
          ? ControlPlacement.sides
          : ControlPlacement.stacked,
    );
  }

  /// Part de l'écran occupée par la feuille — ce que la refonte cherchait à
  /// maximiser, et ce que vérifient les tests.
  double coverage(Size body) =>
      (page.width * page.height) / (body.width * body.height);
}
