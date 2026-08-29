import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/coloring_page.dart';
import '../models/paint_op.dart';
import '../models/pattern.dart';
import '../models/sticker.dart';
import '../models/tool.dart';
import '../widgets/artwork_painter.dart'
    show kStickerGrabRadius, stickerHandleAt, stickerHit;

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
  /// Vrai si rien n'est visible : ni couleur, ni autocollant, depuis le
  /// dernier effacement. Poser un autocollant puis le retirer y ramène, si
  /// bien que « garder mon dessin » ne propose jamais une feuille blanche.
  bool get isBlank {
    bool painted = false;
    final Set<int> stickers = <int>{};
    for (final PaintOp op in _ops) {
      switch (op) {
        case ClearOp():
          painted = false;
          stickers.clear();
        case StickerOp():
          stickers.add(op.id);
        case RemoveStickerOp():
          stickers.remove(op.id);
        case StrokeOp():
        case FillOp():
          painted = true;
      }
    }
    return !painted && stickers.isEmpty;
  }

  ToolKind tool = ToolKind.feutre;
  BrushSize size = BrushSize.moyen;
  Color color = const Color(0xFFE23B3B);

  /// Motif courant, ou `null` pour un aplat de couleur.
  PatternKind? pattern;

  /// Autocollant courant : celui que pose le prochain appui.
  StickerKind sticker = StickerKind.etoile;

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
      pattern: tool.usesPattern ? pattern : null,
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
    _ops.add(FillOp(region: region, color: color.toARGB32(), pattern: pattern));
    _redo.clear();
    notifyListeners();
  }

  // ── Autocollants ──────────────────────────────────────────────────────────

  /// Celui qui porte son cadre et sa croix de retrait.
  StickerOp? selected;

  StickerOp? _dragged;
  Offset _grabFocal = Offset.zero;
  Offset _grabCenter = Offset.zero;
  double _grabScale = 1;
  double _grabRotation = 0;

  /// Début d'un geste sur la couche des autocollants.
  ///
  /// Trois issues : la croix de retrait enlève l'autocollant choisi, un appui
  /// sur un autocollant déjà posé le saisit, et un appui dans le vide en pose
  /// un nouveau — que le doigt peut emmener sans se relever.
  void beginSticker(Offset p, {required bool singleFinger}) {
    final StickerOp? sel = selected;
    if (sel != null &&
        (p - stickerHandleAt(sel)).distance <= kStickerGrabRadius) {
      removeSticker(sel);
      return;
    }

    StickerOp? target;
    for (final StickerOp st in visibleStickers(_ops).reversed) {
      if (stickerHit(st, p)) {
        target = st;
        break;
      }
    }

    if (target == null) {
      // Deux doigts posés dans le vide, c'est un pincement mal visé et non une
      // demande d'autocollant : on ne sème pas une étoile pour autant.
      if (!singleFinger) return;
      target = StickerOp(id: _rng.nextInt(1 << 30), kind: sticker, center: p);
      _ops.add(target);
      _redo.clear();
    }

    selected = target;
    _dragged = target;
    _grabFocal = p;
    _grabCenter = target.center;
    _grabScale = target.scale;
    _grabRotation = target.rotation;
    notifyListeners();
  }

  /// Déplacement, pincement et rotation, relatifs au début du geste.
  void updateSticker(Offset focal, double scale, double rotation) {
    final StickerOp? st = _dragged;
    if (st == null) return;
    st.center = _grabCenter + (focal - _grabFocal);
    st.scale = (_grabScale * scale).clamp(kStickerMinScale, kStickerMaxScale);
    st.rotation = _grabRotation + rotation;
    notifyListeners();
  }

  void endSticker() {
    if (_dragged == null) return;
    _dragged = null;
    notifyListeners();
  }

  void removeSticker(StickerOp st) {
    _ops.add(RemoveStickerOp(st.id));
    _redo.clear();
    if (identical(selected, st)) selected = null;
    _dragged = null;
    notifyListeners();
  }

  // ── Historique ────────────────────────────────────────────────────────────

  void undo() {
    if (_ops.isEmpty) return;
    _redo.add(_ops.removeLast());
    _forgetVanishedSelection();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _ops.add(_redo.removeLast());
    _forgetVanishedSelection();
    notifyListeners();
  }

  void clear() {
    if (isBlank) return;
    _ops.add(const ClearOp());
    _redo.clear();
    selected = null;
    notifyListeners();
  }

  /// Un ↩︎ peut faire disparaître l'autocollant sélectionné : son cadre doit
  /// partir avec lui, sinon il resterait à flotter sur le vide.
  void _forgetVanishedSelection() {
    final StickerOp? sel = selected;
    if (sel == null) return;
    if (!visibleStickers(_ops).any((StickerOp s) => identical(s, sel))) {
      selected = null;
      _dragged = null;
    }
  }

  // ── Réglages ──────────────────────────────────────────────────────────────

  void setTool(ToolKind t) {
    tool = t;
    // Le cadre bleu et sa croix n'ont de sens que sous l'outil autocollant :
    // ailleurs, ils barreraient le dessin sans qu'on puisse les enlever.
    if (t != ToolKind.autocollant) selected = null;
    notifyListeners();
  }

  void setPattern(PatternKind? p) {
    pattern = p;
    if (!tool.usesPattern) {
      tool = ToolKind.feutre;
      selected = null;
    }
    notifyListeners();
  }

  /// Choisir un autocollant, c'est vouloir en poser un : l'outil suit.
  void setSticker(StickerKind k) {
    sticker = k;
    tool = ToolKind.autocollant;
    notifyListeners();
  }

  void setSize(BrushSize s) {
    size = s;
    notifyListeners();
  }

  void setColor(Color c) {
    color = c;
    // Choisir une couleur alors que la gomme ou les autocollants sont actifs
    // veut dire « je veux colorier » : on revient à un outil de tracé.
    if (!tool.usesColor) {
      tool = ToolKind.feutre;
      selected = null;
    }
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
