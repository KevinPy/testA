import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/artwork_controller.dart';
import 'artwork_painter.dart';

/// La surface de coloriage.
///
/// Un seul pointeur est suivi à la fois : sur tablette, la main posée sur
/// l'écran ne doit pas produire un second trait à l'autre bout du dessin.
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
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (BuildContext context, _) => CustomPaint(
              size: box,
              painter: ArtworkPainter(
                page: widget.controller.page,
                ops: widget.controller.ops,
                live: widget.controller.live,
              ),
            ),
          ),
        );
      },
    );
  }
}
