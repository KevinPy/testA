import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Un trait de l'Atelier : le contour noir que l'enfant dessine.
class SketchStroke {
  SketchStroke({required this.width, required this.erase, required this.points});

  final double width;

  /// La gomme retire de l'encre au lieu d'en poser.
  final bool erase;

  final List<Offset> points;
}

/// L'état d'un dessin en cours de création.
///
/// Volontairement plus simple qu'[ArtworkController] : ici il n'y a ni zone,
/// ni couleur, ni détourage — seulement du trait noir et une gomme.
class SketchController extends ChangeNotifier {
  SketchController({required this.size});

  /// Taille de la feuille, en coordonnées page.
  final Size size;

  final List<SketchStroke> _strokes = <SketchStroke>[];
  final List<SketchStroke> _redo = <SketchStroke>[];

  List<SketchStroke> get strokes => List<SketchStroke>.unmodifiable(_strokes);
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Vrai tant qu'aucun trait ne subsiste : rien à transformer.
  bool get isBlank => _strokes.every((SketchStroke s) => s.erase);

  /// Trois épaisseurs, plus larges que celles du coloriage : un contour trop
  /// fin donne des zones que le doigt n'atteint pas.
  static const List<double> widths = <double>[10, 22, 44];

  int sizeIndex = 1;
  bool erasing = false;

  double get strokeWidth => widths[sizeIndex];

  SketchStroke? _live;
  SketchStroke? get live => _live;

  void setSizeIndex(int i) {
    sizeIndex = i.clamp(0, widths.length - 1);
    notifyListeners();
  }

  void setErasing(bool v) {
    erasing = v;
    notifyListeners();
  }

  void start(Offset p) {
    _live = SketchStroke(
      // La gomme travaille plus large que le feutre : effacer doit être facile.
      width: erasing ? strokeWidth * 2.2 : strokeWidth,
      erase: erasing,
      points: <Offset>[p],
    );
    notifyListeners();
  }

  void extend(Offset p) {
    final SketchStroke? s = _live;
    if (s == null) return;
    if ((s.points.last - p).distanceSquared < 6) return;
    s.points.add(p);
    notifyListeners();
  }

  void end() {
    final SketchStroke? s = _live;
    _live = null;
    if (s == null) return;
    _strokes.add(s);
    _redo.clear();
    notifyListeners();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _redo.add(_strokes.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _strokes.add(_redo.removeLast());
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _redo
      ..clear()
      ..addAll(_strokes.reversed);
    _strokes.clear();
    notifyListeners();
  }

  /// Cadre englobant les traits posés, en coordonnées page.
  /// Sert à savoir si le dessin occupe assez de place pour être exploitable.
  Rect get inkBounds {
    double l = double.infinity, t = double.infinity;
    double r = -double.infinity, b = -double.infinity;
    for (final SketchStroke s in _strokes) {
      if (s.erase) continue;
      for (final Offset p in s.points) {
        l = math.min(l, p.dx);
        t = math.min(t, p.dy);
        r = math.max(r, p.dx);
        b = math.max(b, p.dy);
      }
    }
    if (l > r) return Rect.zero;
    return Rect.fromLTRB(l, t, r, b);
  }
}
