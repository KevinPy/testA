import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/tool.dart';
import '../state/artwork_controller.dart';
import 'artwork_painter.dart';

/// La surface de coloriage.
///
/// Deux gestes bien séparés, selon l'outil :
///
///  * dessiner — un seul pointeur est suivi à la fois, car sur tablette la
///    main posée sur l'écran ne doit pas produire un second trait à l'autre
///    bout du dessin ;
///  * poser un autocollant — là, il faut au contraire accepter DEUX doigts,
///    pour le pincer et le faire tourner.
class ColoringCanvas extends StatefulWidget {
  const ColoringCanvas({super.key, required this.controller});

  final ArtworkController controller;

  @override
  State<ColoringCanvas> createState() => _ColoringCanvasState();
}

class _ColoringCanvasState extends State<ColoringCanvas> {
  int? _activePointer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size box = constraints.biggest;
        final Size pageSize = widget.controller.page.source.size;
        final double scale =
            math.min(box.width / pageSize.width, box.height / pageSize.height);
        final Offset origin = Offset(
          (box.width - pageSize.width * scale) / 2,
          (box.height - pageSize.height * scale) / 2,
        );

        Offset toPage(Offset local) => (local - origin) / scale;

        return ListenableBuilder(
          listenable: widget.controller,
          builder: (BuildContext context, _) {
            final Widget surface = CustomPaint(
              size: box,
              painter: ArtworkPainter(
                page: widget.controller.page,
                ops: widget.controller.ops,
                live: widget.controller.live,
                selected: widget.controller.selected,
              ),
            );
            return widget.controller.tool == ToolKind.autocollant
                ? _stickerGestures(toPage, surface)
                : _drawGestures(toPage, surface);
          },
        );
      },
    );
  }

  Widget _drawGestures(Offset Function(Offset) toPage, Widget child) {
    return Listener(
      onPointerDown: (PointerDownEvent e) {
        if (_activePointer != null) return;
        _activePointer = e.pointer;
        widget.controller.startStroke(toPage(e.localPosition));
      },
      onPointerMove: (PointerMoveEvent e) {
        if (e.pointer != _activePointer) return;
        widget.controller.extendStroke(toPage(e.localPosition));
      },
      onPointerUp: (PointerUpEvent e) {
        if (e.pointer != _activePointer) return;
        _activePointer = null;
        widget.controller.endStroke();
      },
      onPointerCancel: (PointerCancelEvent e) {
        if (e.pointer != _activePointer) return;
        _activePointer = null;
        widget.controller.endStroke();
      },
      child: child,
    );
  }

  /// Un seul reconnaisseur pour les trois gestes : un déplacement à un doigt
  /// n'est qu'un pincement d'échelle 1 et de rotation nulle. Les enchaîner
  /// dans le même geste — poser, glisser, écarter les doigts, tourner — se
  /// fait alors sans lever la main.
  Widget _stickerGestures(Offset Function(Offset) toPage, Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (ScaleStartDetails d) => widget.controller.beginSticker(
        toPage(d.localFocalPoint),
        singleFinger: d.pointerCount <= 1,
      ),
      onScaleUpdate: (ScaleUpdateDetails d) => widget.controller.updateSticker(
        toPage(d.localFocalPoint),
        d.scale,
        d.rotation,
      ),
      onScaleEnd: (ScaleEndDetails d) => widget.controller.endSticker(),
      child: child,
    );
  }
}
