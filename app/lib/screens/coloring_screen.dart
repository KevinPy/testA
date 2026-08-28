import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../state/artwork_controller.dart';
import '../state/palette_store.dart';
import '../theme/app_theme.dart';
import '../widgets/color_tray.dart';
import '../widgets/coloring_canvas.dart';
import '../widgets/tool_rail.dart';

/// L'écran de coloriage.
///
/// Disposition adaptative, une seule bascule : au-delà de 900 dp de large
/// (tablette, ou téléphone en paysage), les outils passent en rails latéraux et
/// la feuille occupe tout le centre. En dessous, barres haute et basse.
class ColoringScreen extends StatefulWidget {
  const ColoringScreen({super.key, required this.page, required this.store});

  final ColoringPage page;
  final PaletteStore store;

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen> {
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final bool wide = c.maxWidth >= 900;
            final Widget canvas = _CanvasCard(controller: _controller);

            if (wide) {
              return Column(
                children: <Widget>[
                  _TopBar(
                    controller: _controller,
                    title: widget.page.title.resolve(AppStrings.of(context).locale),
                    onClear: _confirmClear,
                    compact: false,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          ToolRail(controller: _controller, vertical: true),
                          const SizedBox(width: 14),
                          Expanded(child: canvas),
                          const SizedBox(width: 14),
                          ColorTray(
                            controller: _controller,
                            store: widget.store,
                            vertical: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: <Widget>[
                _TopBar(
                  controller: _controller,
                  title: widget.page.title.resolve(AppStrings.of(context).locale),
                  onClear: _confirmClear,
                  compact: true,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(child: canvas),
                        // Les tailles flottent sur la feuille : sur un écran de
                        // téléphone, chaque rangée de barre d'outils prise à la
                        // zone de dessin se paie cher.
                        Positioned(
                          left: 6,
                          top: 0,
                          bottom: 0,
                          child: Center(child: SizeSelector(controller: _controller)),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Center(
                    child: ToolRail(
                      controller: _controller,
                      vertical: false,
                      showSizes: false,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: ColorTray(
                    controller: _controller,
                    store: widget.store,
                    vertical: false,
                  ),
                ),
              ],
            );
          },
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
        content: Text(
          s.eraseAllBody,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
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

class _CanvasCard extends StatelessWidget {
  const _CanvasCard({required this.controller});

  final ArtworkController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: kSoftShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: ColoringCanvas(controller: controller),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.title,
    required this.onClear,
    required this.compact,
  });

  final ArtworkController controller;
  final String title;
  final VoidCallback onClear;

  /// Sur téléphone, le titre s'efface et la bascule passe en icône seule :
  /// l'enfant vient de choisir son dessin, il sait lequel c'est.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final AppStrings s = AppStrings.of(context);
        return Padding(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 10, compact ? 12 : 14, 6),
          child: Row(
            children: <Widget>[
              _RoundButton(
                icon: Icons.home_rounded,
                label: s.gallery,
                compact: compact,
                onTap: () => Navigator.of(context).pop(),
              ),
              if (compact)
                const Spacer()
              else ...<Widget>[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              _MagicZonesToggle(controller: controller, compact: compact),
              SizedBox(width: compact ? 8 : 10),
              _RoundButton(
                icon: Icons.undo_rounded,
                label: s.undo,
                enabled: controller.canUndo,
                compact: compact,
                onTap: controller.undo,
              ),
              const SizedBox(width: 8),
              _RoundButton(
                icon: Icons.redo_rounded,
                label: s.redo,
                enabled: controller.canRedo,
                compact: compact,
                onTap: controller.redo,
              ),
              const SizedBox(width: 8),
              _RoundButton(
                icon: Icons.delete_outline_rounded,
                label: s.eraseAll,
                enabled: !controller.isBlank,
                compact: compact,
                onTap: onClear,
              ),
            ],
          ),
        );
      },
    );
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
            height: compact ? 52 : 60,
            width: compact ? 52 : null,
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 18),
            decoration: BoxDecoration(
              color: on ? AppColors.mint : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: on ? AppColors.mint : AppColors.ink.withValues(alpha: 0.15),
                width: 3,
              ),
              boxShadow: kSoftShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  on ? Icons.auto_fix_high_rounded : Icons.gesture_rounded,
                  size: 26,
                  color: on ? Colors.white : AppColors.ink,
                ),
                if (!compact) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    on ? s.magicZones : s.freeMode,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: on ? Colors.white : AppColors.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool compact;

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
              width: compact ? 52 : 60,
              height: compact ? 52 : 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: kSoftShadow,
              ),
              child: Icon(icon, size: compact ? 26 : 30, color: AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}
