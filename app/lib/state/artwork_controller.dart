import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/coloring_page.dart';
import '../models/paint_op.dart';
import '../models/tool.dart';

/// L'état d'un coloriage en cours : outils choisis et pile d'opérations.
class ArtworkController extends ChangeNotifier {
  ArtworkController(this.page, {List<PaintOp>? initial}) {
    if (initial != null) _ops.addAll(initial);
  }

  final CompiledPage page;

  final List<PaintOp> _ops = <PaintOp>[];
  final List<PaintOp> _redo = <PaintOp>[];
  final math.Random _rng = math.Random();

  List<PaintOp> get ops => List<PaintOp>.unmodifiable(_ops);
  bool get canUndo => _ops.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  /// Vrai si rien n'est visible : pile vide, ou rien depuis le dernier effacement.
  bool get isBlank =>
      _ops.isEmpty || _ops.last is ClearOp;

  ToolKind tool = ToolKind.feutre;
  BrushSize size = BrushSize.moyen;
  Color color = const Color(0xFFE23B3B);

  /// Zones magiques : le trait reste dans la zone touchée au premier contact.
  /// Activé par défaut — c'est le mode qui met en confiance les plus jeunes.
  bool magicZones = true;

  StrokeOp? _live;
  StrokeOp? get live => _live;

  // ── Geste de dessin ───────────────────────────────────────────────────────

  void startStroke(Offset p) {
    if (tool == ToolKind.pot) {
      _fillAt(p);
      return;
    }
    // La zone est verrouillée au poser du doigt et ne change plus jusqu'au
    // relâcher : l'enfant peut gribouiller franchement sans « fuiter » chez
    // le voisin dès qu'il dépasse.
    final int? clip = magicZones ? page.hitTest(p) : null;
    _live = StrokeOp(
      tool: tool,
      color: color.toARGB32(),
      width: size.width,
      points: <Offset>[p],
      clipRegion: clip,
      seed: _rng.nextInt(1 << 30),
    );
    notifyListeners();
  }

  void extendStroke(Offset p) {
    final StrokeOp? s = _live;
    if (s == null) return;
    // On ignore les micro-déplacements : moins de points, rendu plus doux,
    // fichier de sauvegarde plus léger.
    if ((s.points.last - p).distanceSquared < 6) return;
    s.points.add(p);
    notifyListeners();
  }

  void endStroke() {
    final StrokeOp? s = _live;
    _live = null;
    if (s == null) return;
    _ops.add(s);
    _redo.clear();
    notifyListeners();
  }

  void _fillAt(Offset p) {
    final int region = page.hitTest(p);
    _ops.add(FillOp(region: region, color: color.toARGB32()));
    _redo.clear();
    notifyListeners();
  }

  // ── Historique ────────────────────────────────────────────────────────────

  void undo() {
    if (_ops.isEmpty) return;
    _redo.add(_ops.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _ops.add(_redo.removeLast());
    notifyListeners();
  }

  void clear() {
    if (isBlank) return;
    _ops.add(const ClearOp());
    _redo.clear();
    notifyListeners();
  }

  // ── Réglages ──────────────────────────────────────────────────────────────

  void setTool(ToolKind t) {
    tool = t;
    notifyListeners();
  }

  void setSize(BrushSize s) {
    size = s;
    notifyListeners();
  }

  void setColor(Color c) {
    color = c;
    // Choisir une couleur alors que la gomme est active veut dire « je veux
    // colorier » : on revient au dernier outil de tracé.
    if (tool == ToolKind.gomme) tool = ToolKind.feutre;
    notifyListeners();
  }

  void setMagicZones(bool v) {
    magicZones = v;
    notifyListeners();
  }

  // ── Sérialisation ─────────────────────────────────────────────────────────

  String encode() => jsonEncode(<String, dynamic>{
        'v': 1,
        'page': page.source.id,
        'ops': _ops.map((PaintOp o) => o.toJson()).toList(),
      });

  static List<PaintOp> decodeOps(String raw) {
    final Map<String, dynamic> j = jsonDecode(raw) as Map<String, dynamic>;
    return (j['ops'] as List<dynamic>)
        .map((dynamic e) => PaintOp.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
