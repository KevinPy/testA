import 'package:flutter/material.dart';

/// Palette de l'interface. Contrastée, joyeuse, mais jamais criarde : c'est le
/// dessin de l'enfant qui doit attirer l'œil, pas les boutons.
abstract final class AppColors {
  static const Color paper = Color(0xFFFFFDF7);
  static const Color ink = Color(0xFF2E2A26);
  static const Color primary = Color(0xFF5B4BD6);
  static const Color accent = Color(0xFFFF8A3D);
  static const Color mint = Color(0xFF3FC6A0);
  static const Color sky = Color(0xFF56B4E9);
  static const Color surface = Color(0xFFF3EEFF);
  static const Color shadow = Color(0x1A2E2A26);
}

/// Les 24 couleurs livrées d'origine. Choisies pour être nommables par un
/// enfant et distinctes les unes des autres, y compris pour un daltonien.
const List<int> kDefaultPalette = <int>[
  0xFFE23B3B, 0xFFFF6B4A, 0xFFFF8A3D, 0xFFFFB01F,
  0xFFFFD84D, 0xFFF6E27A, 0xFFB6D94C, 0xFF63C132,
  0xFF2E9B57, 0xFF17B9A4, 0xFF56B4E9, 0xFF2C7BE5,
  0xFF3B4DB8, 0xFF7B5BD6, 0xFFB57EDC, 0xFFF48FB1,
  0xFFE8508D, 0xFF8C4A2F, 0xFFC08552, 0xFFF2C6A0,
  0xFF2E2A26, 0xFF6E6A66, 0xFFC4C0BC, 0xFFFFFFFF,
];

ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    surface: AppColors.paper,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    fontFamily: 'Nunito',
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
      bodyMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
      labelLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
    ),
  );
}

/// Ombre douce, unique dans toute l'application.
List<BoxShadow> get kSoftShadow => const <BoxShadow>[
      BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 6)),
    ];
