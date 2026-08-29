import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/tool.dart';
import '../state/artwork_controller.dart';
import '../state/palette_store.dart';
import '../theme/app_theme.dart';
import 'rgb_dialog.dart';
import 'tool_controls.dart';

/// Le tiroir qui regroupe outils, taille et couleurs.
///
/// Les rails permanents ont disparu : sur un iPhone en paysage ils mangeaient
/// près de neuf dixièmes de la surface, et le dessin tenait dans un timbre.
/// Tout est ici, et la feuille occupe désormais l'écran entier.
class ToolsDrawer extends StatelessWidget {
  const ToolsDrawer({super.key, required this.controller, required this.store});

  final ArtworkController controller;
  final PaletteStore store;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final double width =
        (MediaQuery.sizeOf(context).width * 0.86).clamp(280.0, 360.0);

    return Drawer(
      width: width,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[controller, store]),
          builder: (BuildContext context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Header(title: s.openTools),
              Expanded(
                // Défilant : en paysage sur téléphone, la hauteur utile
                // descend sous 400 points et le nuancier ne tiendrait pas.
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: <Widget>[
                    _SectionLabel(s.sectionTools),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        for (final ToolKind t in ToolKind.values)
                          ToolIconButton(
                            icon: t.icon,
                            label: s.tool(t),
                            selected: controller.tool == t,
                            onTap: () => controller.setTool(t),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(s.sectionSize),
                    Row(
                      children: <Widget>[
                        for (final BrushSize b in BrushSize.values)
                          BrushSizeButton(
                            diameter: b.preview,
                            label: s.sizeLabel(b),
                            selected: controller.size == b,
                            enabled: controller.tool.hasSize,
                            tint: controller.tool.usesColor
                                ? controller.color
                                : AppColors.ink,
                            onTap: () => controller.setSize(b),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(s.sectionColors),
                    GridView.count(
                      crossAxisCount: 5,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      padding: EdgeInsets.zero,
                      children: <Widget>[
                        AddColorDot(onTap: () => _createColor(context)),
                        for (final Color c in <Color>[
                          ...store.customColors,
                          ...store.defaultColors,
                        ])
                          ColorDot(
                            color: c,
                            selected: c.toARGB32() == controller.color.toARGB32(),
                            onTap: () => controller.setColor(c),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createColor(BuildContext context) async {
    final Color? picked =
        await RgbColorDialog.show(context, initial: controller.color);
    if (picked == null) return;
    await store.addCustomColor(picked);
    controller.setColor(picked);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          IconButton(
            iconSize: 30,
            tooltip: AppStrings.of(context).close,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8A857F),
        ),
      ),
    );
  }
}
