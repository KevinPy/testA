import 'package:flutter/material.dart';

/// Les quatre outils de Barbouille. Volontairement peu nombreux : un enfant de
/// 3 ans doit pouvoir tous les essayer en dix secondes.
enum ToolKind { crayon, feutre, pot, gomme }

extension ToolKindX on ToolKind {
  String get label => switch (this) {
        ToolKind.crayon => 'Crayon',
        ToolKind.feutre => 'Feutre',
        ToolKind.pot => 'Pot de peinture',
        ToolKind.gomme => 'Gomme',
      };

  IconData get icon => switch (this) {
        ToolKind.crayon => Icons.create_rounded,
        ToolKind.feutre => Icons.brush_rounded,
        ToolKind.pot => Icons.format_color_fill_rounded,
        ToolKind.gomme => Icons.cleaning_services_rounded,
      };

  /// Le pot pose une couleur d'un coup : il n'a pas d'épaisseur de trait.
  bool get hasSize => this != ToolKind.pot;

  /// La gomme retire de la couleur : le sélecteur de couleurs ne la concerne pas.
  bool get usesColor => this != ToolKind.gomme;
}

/// Trois tailles, pas plus : « petit », « moyen », « grand ».
enum BrushSize { petit, moyen, grand }

extension BrushSizeX on BrushSize {
  /// Épaisseur en coordonnées page (viewBox 1000).
  double get width => switch (this) {
        BrushSize.petit => 18,
        BrushSize.moyen => 46,
        BrushSize.grand => 96,
      };

  String get label => switch (this) {
        BrushSize.petit => 'Petit',
        BrushSize.moyen => 'Moyen',
        BrushSize.grand => 'Grand',
      };

  /// Diamètre de l'aperçu dans la barre d'outils.
  double get preview => switch (this) {
        BrushSize.petit => 12,
        BrushSize.moyen => 22,
        BrushSize.grand => 34,
      };
}
