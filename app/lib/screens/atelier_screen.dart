import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../atelier/creation_store.dart';
import '../atelier/sketch_controller.dart';
import '../atelier/sketch_painter.dart';
import '../atelier/zone_tracer.dart';
import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';
import '../models/tool.dart';
import '../state/palette_store.dart';
import '../theme/app_theme.dart';
import '../widgets/sheet_layout.dart';
import '../widgets/tool_controls.dart';
import 'coloring_screen.dart';

/// L'Atelier : l'enfant dessine un contour noir, l'application en fait un
/// coloriage.
class AtelierScreen extends StatefulWidget {
  const AtelierScreen({
    super.key,
    required this.store,
    required this.creations,
  });

  final PaletteStore store;
  final CreationStore creations;

  /// Côté de l'image analysée pour déduire les zones.
  ///
  /// 512 plutôt que 1024 : quatre fois moins de pixels à parcourir, pour une
  /// précision de deux unités de page une fois les contours remis à l'échelle —
  /// invisible une fois simplifiés, et le web n'a pas d'isolat pour absorber
  /// le calcul.
  static const int analysisSide = 512;

  @override
  State<AtelierScreen> createState() => _AtelierScreenState();
}

class _AtelierScreenState extends State<AtelierScreen> {
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();
  final SketchController _sketch = SketchController(size: const Size(1000, 1000));
  bool _working = false;
  int? _activePointer;

  @override
  void dispose() {
    _sketch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Scaffold(
      key: _scaffold,
      backgroundColor: AppColors.surface,
      drawer: _SketchDrawer(controller: _sketch),
      // Un trait commencé au bord gauche ne doit pas ouvrir le tiroir.
      drawerEnableOpenDragGesture: false,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final SheetLayout layout =
                    SheetLayout.of(_sketch.size, c.biggest);
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
                        child: _Sheet(controller: _sketch, onPointer: _onPointer),
                      ),
                    ),
                    _AtelierControls(
                      controller: _sketch,
                      layout: layout,
                      body: c.biggest,
                      onClose: () => Navigator.of(context).pop(),
                      onOpenTools: () => _scaffold.currentState?.openDrawer(),
                      onTransform: _working ? null : _transform,
                    ),
                  ],
                );
              },
            ),
            if (_working) _WorkingOverlay(message: s.atelierWorking),
          ],
        ),
      ),
    );
  }

  void _onPointer(PointerEvent e, Offset page) {
    if (_working) return;
    if (e is PointerDownEvent) {
      if (_activePointer != null) return;
      _activePointer = e.pointer;
      _sketch.start(page);
    } else if (e is PointerMoveEvent) {
      if (e.pointer != _activePointer) return;
      _sketch.extend(page);
    } else {
      if (e.pointer != _activePointer) return;
      _activePointer = null;
      _sketch.end();
    }
  }

  Future<void> _transform() async {
    final AppStrings s = AppStrings.of(context);
    if (_sketch.isBlank) {
      _tell(s.atelierBlank);
      return;
    }
    if (widget.creations.isFull) {
      _tell(s.atelierFull);
      return;
    }

    setState(() => _working = true);
    try {
      final int side = AtelierScreen.analysisSide;
      final ui.Image image = await rasterizeInk(_sketch, side);
      final ByteData? bytes =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (bytes == null) throw StateError('rasterisation vide');

      final TracedZones zones = traceZones(
        rgba: bytes.buffer.asUint8List(),
        width: side,
        height: side,
        pageSize: _sketch.size,
        minArea: minAreaFor(side),
      );

      final ColoringPage page = await widget.creations.save(
        number: widget.creations.nextNumber,
        size: _sketch.size,
        regionPaths: zones.paths,
        // Les traits sont enregistrés en vectoriel, pas en pixels : l'encre
        // reste nette sur n'importe quel écran, alors que seules les ZONES
        // ont eu besoin de passer par l'image.
        ink: <({String d, double width})>[
          for (final SketchStroke stroke in _sketch.strokes)
            if (!stroke.erase && stroke.points.isNotEmpty)
              (d: smoothPathData(stroke.points), width: stroke.width),
        ],
      );

      if (!mounted) return;
      // On enchaîne directement sur le coloriage : c'est la récompense du
      // travail qui vient d'être fait.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              ColoringScreen(page: page, store: widget.store),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _tell(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.controller, required this.onPointer});

  final SketchController controller;
  final void Function(PointerEvent, Offset) onPointer;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final Size box = c.biggest;
          final Size page = controller.size;
          final double scale =
              math.min(box.width / page.width, box.height / page.height);
          final Offset origin = Offset(
            (box.width - page.width * scale) / 2,
            (box.height - page.height * scale) / 2,
          );
          Offset toPage(Offset local) => (local - origin) / scale;

          return Listener(
            onPointerDown: (PointerDownEvent e) => onPointer(e, toPage(e.localPosition)),
            onPointerMove: (PointerMoveEvent e) => onPointer(e, toPage(e.localPosition)),
            onPointerUp: (PointerUpEvent e) => onPointer(e, toPage(e.localPosition)),
            onPointerCancel: (PointerCancelEvent e) =>
                onPointer(e, toPage(e.localPosition)),
            child: ListenableBuilder(
              listenable: controller,
              builder: (BuildContext context, _) => Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      size: box,
                      painter: SketchPainter(controller: controller),
                    ),
                  ),
                  // La consigne vivait dans l'ancien en-tête, supprimé avec les
                  // barres. Sur une feuille vierge, elle est ce qui dit quoi
                  // faire — elle s'efface au premier trait.
                  if (controller.strokes.isEmpty && controller.live == null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              AppStrings.of(context).atelierHint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB9B4AE),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Commandes flottantes de l'Atelier, posées dans les bandes que laisse la
/// feuille carrée — même principe que l'écran de coloriage.
class _AtelierControls extends StatelessWidget {
  const _AtelierControls({
    required this.controller,
    required this.layout,
    required this.body,
    required this.onClose,
    required this.onOpenTools,
    required this.onTransform,
  });

  final SketchController controller;
  final SheetLayout layout;
  final Size body;
  final VoidCallback onClose;
  final VoidCallback onOpenTools;
  final VoidCallback? onTransform;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final Widget home = RoundActionButton(
          icon: Icons.home_rounded,
          label: s.gallery,
          onTap: onClose,
        );
        final Widget tools = ToolsMenuButton(
          tool: controller.erasing ? ToolKind.gomme : ToolKind.feutre,
          color: null,
          onTap: onOpenTools,
        );
        final List<Widget> actions = <Widget>[
          RoundActionButton(
            icon: Icons.undo_rounded,
            label: s.undo,
            enabled: controller.canUndo,
            onTap: controller.undo,
          ),
          RoundActionButton(
            icon: Icons.redo_rounded,
            label: s.redo,
            enabled: controller.canRedo,
            onTap: controller.redo,
          ),
          RoundActionButton(
            icon: Icons.delete_outline_rounded,
            label: s.eraseAll,
            enabled: controller.canUndo,
            onTap: controller.clear,
          ),
        ];
        final Widget transform = _TransformButton(
          label: s.atelierTransform,
          onPressed: onTransform,
          compact: layout.placement == ControlPlacement.sides,
        );

        return switch (layout.placement) {
          ControlPlacement.sides => Stack(
              children: <Widget>[
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        home,
                        const SizedBox(height: 14),
                        tools,
                        const SizedBox(height: 14),
                        transform,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final Widget w in actions) ...<Widget>[
                          w,
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ControlPlacement.stacked => Stack(
              children: <Widget>[
                Positioned(
                  left: 10,
                  right: 10,
                  top: math.max(8, layout.page.top - 68),
                  child: Row(
                    children: <Widget>[
                      home,
                      const Spacer(),
                      for (final Widget w in actions) ...<Widget>[
                        w,
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  top: math.min(body.height - 88, layout.page.bottom + 12),
                  child: tools,
                ),
                Positioned(
                  right: 14,
                  top: math.min(body.height - 88, layout.page.bottom + 12),
                  child: transform,
                ),
              ],
            ),
        };
      },
    );
  }
}

/// Le tiroir de l'Atelier : feutre, gomme, trois épaisseurs. Pas de couleur —
/// on y dessine le contour noir, la couleur vient après.
class _SketchDrawer extends StatelessWidget {
  const _SketchDrawer({required this.controller});

  final SketchController controller;

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
          listenable: controller,
          builder: (BuildContext context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      s.openTools,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 30,
                    tooltip: s.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                s.atelierHint,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8A857F),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  ToolIconButton(
                    icon: Icons.brush_rounded,
                    label: s.atelierPen,
                    selected: !controller.erasing,
                    onTap: () => controller.setErasing(false),
                  ),
                  ToolIconButton(
                    icon: Icons.cleaning_services_rounded,
                    label: s.tool(ToolKind.gomme),
                    selected: controller.erasing,
                    onTap: () => controller.setErasing(true),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                s.sectionSize,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A857F),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  for (int i = 0; i < SketchController.widths.length; i++)
                    BrushSizeButton(
                      diameter: SketchController.widths[i] * 0.62,
                      label: s.sectionSize,
                      selected: controller.sizeIndex == i,
                      enabled: true,
                      tint: SketchPainter.ink,
                      onTap: () => controller.setSizeIndex(i),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransformButton extends StatelessWidget {
  const _TransformButton({
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// En paysage, le bouton se réduit à son icône : la bande latérale est
  /// étroite, et le libellé y tiendrait mal.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        child: Tooltip(
          message: label,
          child: Opacity(
            opacity: onPressed == null ? 0.45 : 1,
            child: GestureDetector(
              onTap: onPressed,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: kSoftShadow,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 36, color: Colors.white),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 68,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mint,
          disabledBackgroundColor: AppColors.mint.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.auto_awesome_rounded, size: 30),
        label: Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _WorkingOverlay extends StatelessWidget {
  const _WorkingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xAA2E2A26),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
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
