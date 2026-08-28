import 'package:flutter/material.dart';

import '../state/artwork_controller.dart';
import '../state/palette_store.dart';
import '../theme/app_theme.dart';
import 'rgb_dialog.dart';

/// Le nuancier. Grille sur tablette (rail droit), bande défilante sur téléphone.
/// La pastille sélectionnée grossit et prend une bague sombre : lisible même
/// pour un enfant qui distingue mal certaines teintes.
class ColorTray extends StatelessWidget {
  const ColorTray({
    super.key,
    required this.controller,
    required this.store,
    required this.vertical,
  });

  final ArtworkController controller;
  final PaletteStore store;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[controller, store]),
      builder: (BuildContext context, _) {
        final List<Color> colors = <Color>[
          ...store.customColors,
          ...store.defaultColors,
        ];

        Widget swatch(Color c) => _Swatch(
              color: c,
              selected: c.toARGB32() == controller.color.toARGB32(),
              onTap: () => controller.setColor(c),
            );

        final Widget addButton = _AddColorButton(
          onTap: () async {
            final Color? picked =
                await RgbColorDialog.show(context, initial: controller.color);
            if (picked == null) return;
            await store.addCustomColor(picked);
            controller.setColor(picked);
          },
        );

        if (vertical) {
          return Container(
            width: 168,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: kSoftShadow,
            ),
            child: Column(
              children: <Widget>[
                addButton,
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    padding: EdgeInsets.zero,
                    children: colors.map(swatch).toList(),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: kSoftShadow,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(width: 68, child: addButton),
              const SizedBox(width: 8),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    for (final Color c in colors)
                      SizedBox(width: 68, child: swatch(c)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
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
      label: 'Couleur',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            width: selected ? 54 : 44,
            height: selected ? 54 : 44,
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

class _AddColorButton extends StatelessWidget {
  const _AddColorButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Créer une nouvelle couleur',
      child: Tooltip(
        message: 'Je crée ma couleur',
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
                child: Icon(Icons.add_rounded, color: Colors.white, size: 30, shadows: <Shadow>[
                  Shadow(color: Colors.black54, blurRadius: 4),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
