import 'package:flutter/material.dart';

import '../models/tool.dart';
import '../state/artwork_controller.dart';
import '../theme/app_theme.dart';

/// Barre d'outils. Verticale sur tablette (rail latéral), horizontale sur
/// téléphone. Cibles tactiles de 72 dp : bien au-delà des 44 dp habituels,
/// parce qu'un doigt de 4 ans vise mal.
class ToolRail extends StatelessWidget {
  const ToolRail({
    super.key,
    required this.controller,
    required this.vertical,
    this.showSizes = true,
  });

  final ArtworkController controller;
  final bool vertical;

  /// Sur téléphone, les tailles n'entrent pas dans la même rangée que les
  /// outils sans devenir trop petites pour un doigt d'enfant : elles passent
  /// alors dans un sélecteur flottant au bord de la feuille ([SizeSelector]).
  final bool showSizes;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final List<Widget> tools = <Widget>[
          for (final ToolKind t in ToolKind.values)
            _ToolButton(
              tool: t,
              selected: controller.tool == t,
              tint: t.usesColor ? controller.color : AppColors.ink,
              onTap: () => controller.setTool(t),
            ),
        ];
        final List<Widget> sizes = <Widget>[
          for (final BrushSize s in showSizes ? BrushSize.values : <BrushSize>[])
            _SizeButton(
              size: s,
              selected: controller.size == s,
              enabled: controller.tool.hasSize,
              tint: controller.tool.usesColor ? controller.color : AppColors.ink,
              onTap: () => controller.setSize(s),
            ),
        ];

        final Widget divider = vertical
            ? Container(height: 2, width: 44, margin: const EdgeInsets.symmetric(vertical: 10), color: AppColors.surface)
            : Container(width: 2, height: 44, margin: const EdgeInsets.symmetric(horizontal: 10), color: AppColors.surface);

        final List<Widget> children = showSizes
            ? <Widget>[...tools, divider, ...sizes]
            : tools;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: kSoftShadow,
          ),
          child: vertical
              ? Column(mainAxisSize: MainAxisSize.min, children: children)
              : Row(mainAxisSize: MainAxisSize.min, children: children),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  final ToolKind tool;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Semantics(
        button: true,
        selected: selected,
        label: tool.label,
        child: Tooltip(
          message: tool.label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: selected
                    ? Border.all(color: AppColors.primary, width: 3)
                    : null,
              ),
              child: Icon(
                tool.icon,
                size: 36,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de taille flottant, posé sur le bord gauche de la feuille.
/// Il ne prend aucune hauteur à la zone de dessin, ce qui compte sur téléphone.
class SizeSelector extends StatelessWidget {
  const SizeSelector({super.key, required this.controller});

  final ArtworkController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) => Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          boxShadow: kSoftShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final BrushSize s in BrushSize.values)
              _SizeButton(
                size: s,
                selected: controller.size == s,
                enabled: controller.tool.hasSize,
                tint: controller.tool.usesColor ? controller.color : AppColors.ink,
                onTap: () => controller.setSize(s),
              ),
          ],
        ),
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.size,
    required this.selected,
    required this.enabled,
    required this.tint,
    required this.onTap,
  });

  final BrushSize size;
  final bool selected;
  final bool enabled;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Taille ${size.label}',
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 72,
              height: 56,
              decoration: BoxDecoration(
                color: selected && enabled ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: selected && enabled
                    ? Border.all(color: AppColors.primary, width: 3)
                    : Border.all(color: Colors.transparent, width: 3),
              ),
              child: Center(
                child: Container(
                  width: size.preview,
                  height: size.preview,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink.withValues(alpha: 0.25), width: 2),
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
