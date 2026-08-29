import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/tool.dart';
import '../theme/app_theme.dart';

/// Les briques de commande, sans hypothèse de disposition : la barre d'outils
/// a disparu au profit d'un tiroir, mais les boutons eux-mêmes n'ont pas de
/// raison de changer.

class ToolIconButton extends StatelessWidget {
  const ToolIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.size = 72,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              icon,
              size: size * 0.48,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class BrushSizeButton extends StatelessWidget {
  const BrushSizeButton({
    super.key,
    required this.diameter,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.tint,
    required this.onTap,
  });

  final double diameter;
  final String label;
  final bool selected;
  final bool enabled;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 72,
            height: 64,
            decoration: BoxDecoration(
              color: selected && enabled ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected && enabled ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
            child: Center(
              child: Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.ink.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ColorDot extends StatelessWidget {
  const ColorDot({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: AppStrings.of(context).colorSwatch,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            width: selected ? 54 : 46,
            height: selected ? 54 : 46,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.ink : AppColors.ink.withValues(alpha: 0.18),
                width: selected ? 5 : 2,
              ),
              boxShadow: selected ? kSoftShadow : null,
            ),
          ),
        ),
      ),
    );
  }
}

class AddColorDot extends StatelessWidget {
  const AddColorDot({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Semantics(
      button: true,
      label: s.newColorA11y,
      child: Tooltip(
        message: s.newColor,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: <Color>[
                    Color(0xFFE23B3B), Color(0xFFFFB01F), Color(0xFFFFD84D),
                    Color(0xFF63C132), Color(0xFF17B9A4), Color(0xFF2C7BE5),
                    Color(0xFF7B5BD6), Color(0xFFE8508D), Color(0xFFE23B3B),
                  ],
                ),
                border: Border.all(color: AppColors.ink, width: 3),
              ),
              child: const Center(
                child: Icon(Icons.add_rounded, color: Colors.white, size: 30,
                    shadows: <Shadow>[Shadow(color: Colors.black54, blurRadius: 4)]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton rond des actions flottantes (accueil, annuler, capture…).
class RoundActionButton extends StatelessWidget {
  const RoundActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.size = 56,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        child: Opacity(
          opacity: enabled ? 1 : 0.32,
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                // Opaque : ces boutons peuvent se retrouver au-dessus du
                // dessin sur un écran presque carré, il faut qu'ils restent
                // lisibles quelle que soit la couleur posée dessous.
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: kSoftShadow,
              ),
              child: Icon(icon, size: size * 0.5, color: AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le bouton qui ouvre le tiroir. Il porte l'outil courant et la couleur
/// courante : l'enfant sait avec quoi il dessine sans rien ouvrir.
class ToolsMenuButton extends StatelessWidget {
  const ToolsMenuButton({
    super.key,
    required this.tool,
    required this.color,
    required this.onTap,
  });

  final ToolKind tool;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Semantics(
      button: true,
      label: s.openTools,
      child: Tooltip(
        message: s.openTools,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: kSoftShadow,
              border: Border.all(color: AppColors.primary, width: 3),
            ),
            child: Stack(
              children: <Widget>[
                Center(child: Icon(tool.icon, size: 34, color: AppColors.ink)),
                if (color != null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
