import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../models/tool.dart';
import '../state/artwork_controller.dart';
import '../state/palette_store.dart';
import '../theme/app_theme.dart';
import '../widgets/coloring_canvas.dart';
import '../widgets/sheet_layout.dart';
import '../widgets/tool_controls.dart';
import '../widgets/tools_drawer.dart';
import 'capture_screen.dart';

/// L'écran de coloriage.
///
/// La feuille occupe tout ce que l'écran peut lui donner ; les commandes
/// flottent dans les bandes que laisse une feuille carrée sur un écran qui ne
/// l'est pas. Outils, taille et couleurs vivent dans un tiroir, ouvert par un
/// seul bouton.
class ColoringScreen extends StatefulWidget {
  const ColoringScreen({super.key, required this.page, required this.store});

  final ColoringPage page;
  final PaletteStore store;

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen> {
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();
  late final ArtworkController _controller;

  @override
  void initState() {
    super.initState();
    final String? saved = widget.store.artworkFor(widget.page.id);
    _controller = ArtworkController(
      CompiledPage.of(widget.page),
      initial: saved == null ? null : ArtworkController.decodeOps(saved),
    )..addListener(_autosave);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_autosave)
      ..dispose();
    super.dispose();
  }

  /// Sauvegarde automatique : un enfant ne cherchera jamais un bouton
  /// « Enregistrer », et fermer l'application ne doit rien coûter.
  void _autosave() {
    if (_controller.live != null) return; // on attend la fin du trait
    widget.store.saveArtwork(widget.page.id, _controller.encode());
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final String title = widget.page.title.resolve(s.locale);

    return Scaffold(
      key: _scaffold,
      backgroundColor: AppColors.surface,
      drawer: ToolsDrawer(controller: _controller, store: widget.store),
      // Sans cela, un trait commencé au bord gauche de la feuille ouvrirait le
      // tiroir au lieu de colorier.
      drawerEnableOpenDragGesture: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final SheetLayout layout =
                SheetLayout.of(widget.page.size, c.biggest);
            return Stack(
              children: <Widget>[
                Positioned.fromRect(
                  rect: layout.page,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: kSoftShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ColoringCanvas(controller: _controller),
                  ),
                ),
                ..._controls(context, layout, c.biggest, title),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _controls(
      BuildContext context, SheetLayout layout, Size body, String title) {
    final AppStrings s = AppStrings.of(context);

    Widget menu() => ListenableBuilder(
          listenable: _controller,
          builder: (BuildContext context, _) => ToolsMenuButton(
            tool: _controller.tool,
            color: _controller.tool.usesColor ? _controller.color : null,
            onTap: () => _scaffold.currentState?.openDrawer(),
          ),
        );

    Widget home() => RoundActionButton(
          icon: Icons.home_rounded,
          label: s.gallery,
          onTap: () => Navigator.of(context).pop(),
        );

    List<Widget> actions() => <Widget>[
          _MagicZonesToggle(controller: _controller, compact: true),
          RoundActionButton(
            icon: Icons.undo_rounded,
            label: s.undo,
            enabled: _controller.canUndo,
            onTap: _controller.undo,
          ),
          RoundActionButton(
            icon: Icons.redo_rounded,
            label: s.redo,
            enabled: _controller.canRedo,
            onTap: _controller.redo,
          ),
          RoundActionButton(
            icon: Icons.delete_outline_rounded,
            label: s.eraseAll,
            enabled: !_controller.isBlank,
            onTap: _confirmClear,
          ),
          RoundActionButton(
            icon: Icons.photo_camera_rounded,
            label: s.capture,
            enabled: !_controller.isBlank,
            onTap: () => _openCapture(title),
          ),
        ];

    return <Widget>[
      ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, _) => switch (layout.placement) {
          // Paysage : deux colonnes dans les bandes latérales, la feuille
          // garde toute la hauteur.
          ControlPlacement.sides => Stack(
              children: <Widget>[
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[home(), const SizedBox(height: 14), menu()],
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (final Widget w in actions()) ...<Widget>[
                            w,
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          // Portrait : une rangée en haut, le bouton d'outils en bas.
          // Les commandes se collent à la feuille plutôt qu'aux bords de
          // l'écran : sur un téléphone en portrait, une feuille carrée laisse
          // de grandes bandes vides, et des boutons plaqués aux extrémités
          // donneraient une page qui flotte.
          ControlPlacement.stacked => Stack(
              children: <Widget>[
                Positioned(
                  left: 10,
                  right: 10,
                  top: math.max(8, layout.page.top - 68),
                  child: Row(
                    children: <Widget>[
                      home(),
                      const Spacer(),
                      for (final Widget w in actions()) ...<Widget>[
                        w,
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  top: math.min(body.height - 88, layout.page.bottom + 12),
                  child: menu(),
                ),
              ],
            ),
        },
      ),
    ];
  }

  void _openCapture(String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CaptureScreen(
          page: _controller.page,
          ops: _controller.ops,
          title: title,
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final AppStrings s = AppStrings.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(s.eraseAllTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.eraseAllBody,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.eraseAllCancel,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.eraseAllConfirm,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok ?? false) _controller.clear();
  }
}

/// L'interrupteur qui décide du confinement du trait.
///
/// « Zones magiques » (par défaut) : le trait ne sort pas de la zone touchée.
/// « Libre » : le trait va partout — mais toujours SOUS le trait noir.
class _MagicZonesToggle extends StatelessWidget {
  const _MagicZonesToggle({required this.controller, required this.compact});

  final ArtworkController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool on = controller.magicZones;
    final AppStrings s = AppStrings.of(context);
    return Semantics(
      button: true,
      toggled: on,
      label: on ? s.magicZonesOn : s.freeModeOn,
      child: Tooltip(
        message: on ? s.magicZonesHint : s.freeModeHint,
        child: GestureDetector(
          onTap: () => controller.setMagicZones(!on),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: on ? AppColors.mint : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: on ? AppColors.mint : AppColors.ink.withValues(alpha: 0.15),
                width: 3,
              ),
              boxShadow: kSoftShadow,
            ),
            child: Icon(
              on ? Icons.auto_fix_high_rounded : Icons.gesture_rounded,
              size: 26,
              color: on ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
