import 'package:flutter/material.dart';

/// Les outils de Barbouille. Volontairement peu nombreux : un enfant de 3 ans
/// doit pouvoir tous les essayer en dix secondes.
///
/// L'ordre est figé : la sauvegarde d'un coloriage stocke l'indice de l'outil,
/// et une valeur intercalée relirait les anciens fichiers de travers. Toute
/// nouvelle valeur s'ajoute donc À LA FIN.
enum ToolKind { crayon, feutre, pot, gomme, autocollant }

extension ToolKindX on ToolKind {
  IconData get icon => switch (this) {
        ToolKind.crayon => Icons.create_rounded,
        ToolKind.feutre => Icons.brush_rounded,
        ToolKind.pot => Icons.format_color_fill_rounded,
        ToolKind.gomme => Icons.cleaning_services_rounded,
        ToolKind.autocollant => Icons.emoji_emotions_rounded,
      };

  /// Le pot pose une couleur d'un coup, l'autocollant est une image que l'on
  /// pince : ni l'un ni l'autre n'a d'épaisseur de trait.
  bool get hasSize => this != ToolKind.pot && this != ToolKind.autocollant;

  /// La gomme retire de la couleur, l'autocollant apporte la sienne : le
  /// sélecteur de couleurs ne les concerne ni l'une ni l'autre.
  bool get usesColor =>
      this == ToolKind.crayon || this == ToolKind.feutre || this == ToolKind.pot;

  /// Les outils qui peuvent peindre un motif au lieu d'un aplat.
  bool get usesPattern => usesColor;
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

  /// Diamètre de l'aperçu dans la barre d'outils.
  double get preview => switch (this) {
        BrushSize.petit => 12,
        BrushSize.moyen => 22,
        BrushSize.grand => 34,
      };
}
