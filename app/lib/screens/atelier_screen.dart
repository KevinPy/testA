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
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final bool compact = c.maxWidth < 620;
                return Column(
                  children: <Widget>[
                    _TopBar(
                      controller: _sketch,
                      compact: compact,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _Sheet(controller: _sketch, onPointer: _onPointer),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Center(child: _Tools(controller: _sketch)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: _TransformButton(
                        label: s.atelierTransform,
                        onPressed: _working ? null : _transform,
                      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: kSoftShadow,
      ),
      clipBehavior: Clip.antiAlias,
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
              builder: (BuildContext context, _) => CustomPaint(
                size: box,
                painter: SketchPainter(controller: controller),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.compact,
    required this.onClose,
  });

  final SketchController controller;
  final bool compact;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(
          children: <Widget>[
            _Round(icon: Icons.home_rounded, label: s.gallery, onTap: onClose),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.atelierTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  if (!compact)
                    Text(
                      s.atelierHint,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A857F),
                      ),
                    ),
                ],
              ),
            ),
            _Round(
              icon: Icons.undo_rounded,
              label: s.undo,
              enabled: controller.canUndo,
              onTap: controller.undo,
            ),
            const SizedBox(width: 8),
            _Round(
              icon: Icons.redo_rounded,
              label: s.redo,
              enabled: controller.canRedo,
              onTap: controller.redo,
            ),
            const SizedBox(width: 8),
            _Round(
              icon: Icons.delete_outline_rounded,
              label: s.eraseAll,
              enabled: controller.canUndo,
              onTap: controller.clear,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({required this.controller});

  final SketchController controller;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: kSoftShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ToolButton(
              icon: Icons.brush_rounded,
              label: s.atelierPen,
              selected: !controller.erasing,
              onTap: () => controller.setErasing(false),
            ),
            _ToolButton(
              icon: Icons.cleaning_services_rounded,
              label: s.tool(ToolKind.gomme),
              selected: controller.erasing,
              onTap: () => controller.setErasing(true),
            ),
            Container(
              width: 2,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: AppColors.surface,
            ),
            for (int i = 0; i < SketchController.widths.length; i++)
              _SizeButton(
                diameter: SketchController.widths[i] * 0.62,
                selected: controller.sizeIndex == i,
                onTap: () => controller.setSizeIndex(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon,
                  size: 34, color: selected ? Colors.white : AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.diameter,
    required this.selected,
    required this.onTap,
  });

  final double diameter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
          child: Center(
            child: Container(
              width: diameter,
              height: diameter,
              decoration: const BoxDecoration(
                color: SketchPainter.ink,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransformButton extends StatelessWidget {
  const _TransformButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
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

class _Round extends StatelessWidget {
  const _Round({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: kSoftShadow,
              ),
              child: Icon(icon, size: 28, color: AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}
