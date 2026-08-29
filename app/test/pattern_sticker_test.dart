import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barbouille/data/pages.g.dart';
import 'package:barbouille/models/coloring_page.dart';
import 'package:barbouille/models/paint_op.dart';
import 'package:barbouille/models/pattern.dart';
import 'package:barbouille/models/sticker.dart';
import 'package:barbouille/models/tool.dart';
import 'package:barbouille/state/artwork_controller.dart';
import 'package:barbouille/widgets/artwork_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Couleur d'un point de l'œuvre rendue, en coordonnées page.
Future<Color> pixelAt(
  CompiledPage page,
  List<PaintOp> ops,
  Offset pagePoint, {
  double pixels = 500,
}) async {
  final ui.Image img = await renderArtwork(page, ops, pixelWidth: pixels);
  final ui.ImageByteFormat fmt = ui.ImageByteFormat.rawRgba;
  final ByteData data = (await img.toByteData(format: fmt))!;
  final double k = pixels / page.source.size.width;
  final int x = (pagePoint.dx * k).round().clamp(0, img.width - 1);
  final int y = (pagePoint.dy * k).round().clamp(0, img.height - 1);
  final int i = (y * img.width + x) * 4;
  return Color.fromARGB(
      data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
}

/// Un point de la page qui tombe sur le trait noir. Cherché plutôt que codé
/// en dur : les dessins sont générés, et une coordonnée figée finirait par
/// désigner du papier blanc après la moindre retouche du générateur.
Future<Offset> inkPoint(CompiledPage page) async {
  const double pixels = 500;
  final ui.Image img =
      await renderArtwork(page, const <PaintOp>[], pixelWidth: pixels);
  final ByteData d = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final double k = page.source.size.width / pixels;
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      final int i = (y * img.width + x) * 4;
      if (d.getUint8(i) < 60 && d.getUint8(i + 1) < 60 && d.getUint8(i + 2) < 60) {
        return Offset(x * k, y * k);
      }
    }
  }
  throw StateError('aucune encre trouvée sur la page');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ColoringPage poisson =
      kColoringPages.firstWhere((ColoringPage p) => p.id == 'poisson');
  CompiledPage compiled() => CompiledPage.of(poisson);

  // ── Motifs ────────────────────────────────────────────────────────────────

  group('motifs', () {
    test('sans motif, la peinture est un aplat sans nuanceur', () {
      final Paint p = patternBrush(null, const Color(0xFFE23B3B));
      expect(p.shader, isNull);
      expect(p.color.toARGB32(), 0xFFE23B3B);
    });

    test('un motif donne un nuanceur teinté par la couleur choisie', () {
      final Paint p = patternBrush(PatternKind.pois, const Color(0xFF2C7BE5));
      expect(p.shader, isA<ImageShader>());
      expect(p.colorFilter, isNotNull);
    });

    test('la tuile d\'un motif est fabriquée une seule fois', () {
      final Shader a = PatternTiles.instance.shader(PatternKind.rayures);
      final Shader b = PatternTiles.instance.shader(PatternKind.rayures);
      expect(identical(a, b), isTrue);
      // Une autre échelle est un autre nuanceur : la pastille du tiroir
      // montre le motif réduit sans déranger celui de la feuille.
      expect(
        identical(a, PatternTiles.instance.shader(PatternKind.rayures, tileScale: 0.5)),
        isFalse,
      );
    });

    test('les six motifs se fabriquent sans erreur', () {
      for (final PatternKind k in PatternKind.values) {
        expect(PatternTiles.instance.shader(k), isNotNull, reason: k.name);
      }
    });

    test('un remplissage à motif laisse voir ce qu\'il y a dessous', () async {
      final CompiledPage page = compiled();
      final int corps = page.hitTest(const Offset(500, 480));

      // Un aplat jaune, puis des pois bleus par-dessus : le jaune doit
      // subsister entre les pois, sinon le motif ne serait qu'un aplat de plus.
      final List<PaintOp> ops = <PaintOp>[
        FillOp(region: corps, color: 0xFFFFD84D),
        FillOp(region: corps, color: 0xFF2C7BE5, pattern: PatternKind.pois),
      ];
      final ui.Image img = await renderArtwork(page, ops, pixelWidth: 500);
      final ByteData d = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;

      int jaune = 0, bleu = 0;
      // Une bande horizontale au travers du corps du poisson.
      for (int x = 200; x < 300; x++) {
        final int i = ((480 * 500 ~/ 1000) * img.width + x) * 4;
        final int r = d.getUint8(i), g = d.getUint8(i + 1), b = d.getUint8(i + 2);
        if (r > 180 && g > 150 && b < 140) jaune++;
        if (b > 130 && r < 150) bleu++;
      }
      expect(jaune, greaterThan(10), reason: 'le motif a tout recouvert');
      expect(bleu, greaterThan(10), reason: 'le motif ne se voit pas');
    });

    test('un trait à motif diffère d\'un trait uni', () async {
      final CompiledPage page = compiled();
      final List<Offset> trait = <Offset>[
        for (int i = 0; i < 30; i++) Offset(340.0 + i * 10, 480),
      ];
      StrokeOp feutre({PatternKind? pattern}) => StrokeOp(
            tool: ToolKind.feutre,
            color: 0xFF2C7BE5,
            width: 90,
            points: trait,
            clipRegion: null,
            seed: 1,
            pattern: pattern,
          );

      final ui.Image uni =
          await renderArtwork(page, <PaintOp>[feutre()], pixelWidth: 400);
      final ui.Image motif = await renderArtwork(
          page, <PaintOp>[feutre(pattern: PatternKind.carreaux)], pixelWidth: 400);
      final ByteData a = (await uni.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final ByteData b = (await motif.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      expect(a.buffer.asUint8List(), isNot(b.buffer.asUint8List()));
    });
  });

  // ── Sérialisation ─────────────────────────────────────────────────────────

  group('sauvegarde', () {
    test('le motif d\'un trait et d\'un remplissage survit à l\'aller-retour', () {
      final StrokeOp s = StrokeOp(
        tool: ToolKind.crayon,
        color: 0xFF63C132,
        width: 46,
        points: <Offset>[const Offset(10, 20), const Offset(30, 40)],
        clipRegion: 2,
        seed: 7,
        pattern: PatternKind.etoiles,
      );
      final StrokeOp back = PaintOp.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>) as StrokeOp;
      expect(back.pattern, PatternKind.etoiles);

      const FillOp f =
          FillOp(region: 3, color: 0xFF2C7BE5, pattern: PatternKind.zigzag);
      final FillOp fb = PaintOp.fromJson(
          jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>) as FillOp;
      expect(fb.pattern, PatternKind.zigzag);
    });

    test('une œuvre enregistrée avant les motifs se relit en aplat', () {
      // Exactement ce qu'écrivait la version précédente : pas de clé « m ».
      final Map<String, dynamic> vieuxTrait = <String, dynamic>{
        't': 's', 'k': 1, 'c': 0xFFE23B3B, 'w': 46.0, 'r': null, 'd': 3,
        'p': <double>[10, 10, 20, 20],
      };
      final Map<String, dynamic> vieuxPot = <String, dynamic>{
        't': 'f', 'r': 2, 'c': 0xFFE23B3B,
      };
      expect((PaintOp.fromJson(vieuxTrait) as StrokeOp).pattern, isNull);
      expect((PaintOp.fromJson(vieuxPot) as FillOp).pattern, isNull);
    });

    test('un motif inconnu d\'une version future retombe sur l\'aplat', () {
      final Map<String, dynamic> futur = <String, dynamic>{
        't': 'f', 'r': 1, 'c': 0xFF000000, 'm': 99,
      };
      expect((PaintOp.fromJson(futur) as FillOp).pattern, isNull);
    });

    test('un autocollant survit à l\'aller-retour, transformation comprise', () {
      final StickerOp k = StickerOp(
        id: 42,
        kind: StickerKind.fusee,
        center: const Offset(310.5, 620.25),
        scale: 1.75,
        rotation: 0.618,
      );
      final StickerOp back = PaintOp.fromJson(
          jsonDecode(jsonEncode(k.toJson())) as Map<String, dynamic>) as StickerOp;
      expect(back.id, 42);
      expect(back.kind, StickerKind.fusee);
      expect(back.center.dx, closeTo(310.5, 0.1));
      expect(back.center.dy, closeTo(620.3, 0.1));
      expect(back.scale, closeTo(1.75, 0.001));
      expect(back.rotation, closeTo(0.618, 0.001));

      final RemoveStickerOp gone = PaintOp.fromJson(
              jsonDecode(jsonEncode(const RemoveStickerOp(42).toJson()))
                  as Map<String, dynamic>)
          as RemoveStickerOp;
      expect(gone.id, 42);
    });
  });

  // ── Rejeu des autocollants ────────────────────────────────────────────────

  group('rejeu', () {
    StickerOp make(int id) =>
        StickerOp(id: id, kind: StickerKind.coeur, center: Offset(id * 10, 0));

    test('un retrait fait disparaître le bon autocollant, et lui seul', () {
      final StickerOp a = make(1), b = make(2);
      expect(visibleStickers(<PaintOp>[a, b, const RemoveStickerOp(1)]),
          <StickerOp>[b]);
    });

    test('« tout effacer » emporte les autocollants', () {
      expect(visibleStickers(<PaintOp>[make(1), const ClearOp()]), isEmpty);
    });

    test('annuler un retrait ramène l\'autocollant', () {
      final StickerOp a = make(1);
      // La pile sans le marqueur de retrait, c'est exactement ce que voit
      // l'œuvre après un ↩︎.
      expect(visibleStickers(<PaintOp>[a]), <StickerOp>[a]);
    });
  });

  // ── Géométrie du geste ────────────────────────────────────────────────────

  group('geste', () {
    test('la boîte de contact suit l\'échelle et la rotation', () {
      final StickerOp k =
          StickerOp(id: 1, kind: StickerKind.etoile, center: const Offset(500, 500));
      expect(stickerHit(k, const Offset(500, 500)), isTrue);
      expect(stickerHit(k, const Offset(500, 500 + kStickerSize)), isFalse);

      k.scale = 2;
      expect(stickerHit(k, const Offset(500, 500 + kStickerSize * 0.9)), isTrue);

      // Tourné d'un quart de tour, un coin de la boîte se retrouve à l'aplomb
      // d'un côté : le point qui touchait avant doit encore toucher.
      k
        ..scale = 1
        ..rotation = 1.5707963;
      expect(stickerHit(k, const Offset(500 + kStickerSize * 0.45, 500)), isTrue);
    });

    test('la croix de retrait tourne avec l\'autocollant', () {
      final StickerOp k =
          StickerOp(id: 1, kind: StickerKind.etoile, center: const Offset(500, 500));
      final double d = kStickerSize / 2 + kStickerFrameGap;
      // Sans rotation : coin haut droit.
      expect(stickerHandleAt(k).dx, closeTo(500 + d, 0.01));
      expect(stickerHandleAt(k).dy, closeTo(500 - d, 0.01));

      // Un demi-tour l'envoie exactement au coin opposé.
      k.rotation = 3.14159265;
      expect(stickerHandleAt(k).dx, closeTo(500 - d, 0.01));
      expect(stickerHandleAt(k).dy, closeTo(500 + d, 0.01));
    });
  });

  // ── Le contrôleur ─────────────────────────────────────────────────────────

  group('contrôleur', () {
    ArtworkController fresh() => ArtworkController(compiled());

    test('un appui dans le vide pose un autocollant et le sélectionne', () {
      final ArtworkController c = fresh()
        ..setSticker(StickerKind.papillon)
        ..beginSticker(const Offset(400, 400), singleFinger: true)
        ..endSticker();
      expect(c.tool, ToolKind.autocollant);
      expect(c.ops.whereType<StickerOp>().length, 1);
      expect(c.selected, isNotNull);
      expect(c.selected!.kind, StickerKind.papillon);
      expect(c.selected!.center, const Offset(400, 400));
    });

    test('deux doigts dans le vide ne posent rien', () {
      final ArtworkController c = fresh()
        ..setTool(ToolKind.autocollant)
        ..beginSticker(const Offset(400, 400), singleFinger: false)
        ..endSticker();
      expect(c.ops, isEmpty);
      expect(c.selected, isNull);
    });

    test('glisser, pincer et tourner modifient l\'autocollant en place', () {
      final ArtworkController c = fresh()..setTool(ToolKind.autocollant);
      c.beginSticker(const Offset(400, 400), singleFinger: true);
      c.updateSticker(const Offset(600, 500), 1.5, 0.5);
      c.endSticker();

      final StickerOp k = c.ops.whereType<StickerOp>().single;
      expect(k.center, const Offset(600, 500));
      expect(k.scale, closeTo(1.5, 0.001));
      expect(k.rotation, closeTo(0.5, 0.001));
      // Un pincement entier n'a coûté qu'une seule entrée d'historique :
      // un seul ↩︎ doit suffire à tout défaire.
      expect(c.ops.length, 1);
    });

    test('le pincement est borné des deux côtés', () {
      final ArtworkController c = fresh()..setTool(ToolKind.autocollant);
      c.beginSticker(const Offset(400, 400), singleFinger: true);
      c.updateSticker(const Offset(400, 400), 100, 0);
      expect(c.selected!.scale, kStickerMaxScale);
      c.updateSticker(const Offset(400, 400), 0.001, 0);
      expect(c.selected!.scale, kStickerMinScale);
    });

    test('un appui sur un autocollant posé le reprend au lieu d\'en poser un', () {
      final ArtworkController c = fresh()..setTool(ToolKind.autocollant);
      c.beginSticker(const Offset(400, 400), singleFinger: true);
      c.endSticker();
      c.beginSticker(const Offset(420, 410), singleFinger: true);
      c.updateSticker(const Offset(520, 410), 1, 0);
      c.endSticker();

      expect(c.ops.whereType<StickerOp>().length, 1);
      expect(c.ops.whereType<StickerOp>().single.center, const Offset(500, 400));
    });

    test('la croix de retrait enlève l\'autocollant, et ↩︎ le ramène', () {
      final ArtworkController c = fresh()..setTool(ToolKind.autocollant);
      c.beginSticker(const Offset(400, 400), singleFinger: true);
      c.endSticker();
      final StickerOp k = c.selected!;

      c.beginSticker(stickerHandleAt(k), singleFinger: true);
      expect(visibleStickers(c.ops), isEmpty);
      expect(c.selected, isNull);

      c.undo();
      expect(visibleStickers(c.ops), <StickerOp>[k]);
    });

    test('annuler la pose fait aussi disparaître le cadre', () {
      final ArtworkController c = fresh()..setTool(ToolKind.autocollant);
      c.beginSticker(const Offset(400, 400), singleFinger: true);
      c.endSticker();
      expect(c.selected, isNotNull);
      c.undo();
      expect(c.selected, isNull);
    });

    test('un dessin qui n\'a qu\'un autocollant n\'est pas vierge', () {
      final ArtworkController c = fresh()..setTool(ToolKind.autocollant);
      expect(c.isBlank, isTrue);
      c.beginSticker(const Offset(400, 400), singleFinger: true);
      c.endSticker();
      expect(c.isBlank, isFalse);
      c.beginSticker(stickerHandleAt(c.selected!), singleFinger: true);
      expect(c.isBlank, isTrue, reason: 'plus rien de visible');
    });

    test('changer d\'outil retire le cadre de sélection', () {
      final ArtworkController c = fresh()..setTool(ToolKind.autocollant);
      c.beginSticker(const Offset(400, 400), singleFinger: true);
      c.endSticker();
      c.setTool(ToolKind.feutre);
      expect(c.selected, isNull);
    });

    test('le motif courant part avec le trait et avec le pot', () {
      final ArtworkController c = fresh()
        ..setTool(ToolKind.feutre)
        ..setPattern(PatternKind.coeurs)
        ..startStroke(const Offset(400, 400))
        ..endStroke();
      expect(c.ops.whereType<StrokeOp>().single.pattern, PatternKind.coeurs);

      c
        ..setTool(ToolKind.pot)
        ..startStroke(const Offset(500, 480));
      expect(c.ops.whereType<FillOp>().single.pattern, PatternKind.coeurs);
    });

    test('la gomme ignore le motif : elle efface, elle ne peint pas', () {
      final ArtworkController c = fresh()
        ..setPattern(PatternKind.pois)
        ..setTool(ToolKind.gomme)
        ..startStroke(const Offset(400, 400))
        ..endStroke();
      expect(c.ops.whereType<StrokeOp>().single.pattern, isNull);
    });

    test('choisir un motif sort de la gomme et des autocollants', () {
      final ArtworkController c = fresh()..setTool(ToolKind.gomme);
      c.setPattern(PatternKind.rayures);
      expect(c.tool, ToolKind.feutre);

      c.setTool(ToolKind.autocollant);
      c.setPattern(null);
      expect(c.tool, ToolKind.feutre);
    });

    test('un coloriage complet se recharge à l\'identique', () {
      final ArtworkController c = fresh()
        ..setPattern(PatternKind.carreaux)
        ..startStroke(const Offset(400, 400))
        ..extendStroke(const Offset(460, 430))
        ..endStroke()
        ..setSticker(StickerKind.couronne);
      c.beginSticker(const Offset(300, 300), singleFinger: true);
      c.updateSticker(const Offset(320, 340), 1.4, 0.3);
      c.endSticker();

      final List<PaintOp> back = ArtworkController.decodeOps(c.encode());
      expect(back.length, c.ops.length);
      expect(back.whereType<StrokeOp>().single.pattern, PatternKind.carreaux);
      final StickerOp k = back.whereType<StickerOp>().single;
      expect(k.kind, StickerKind.couronne);
      expect(k.scale, closeTo(1.4, 0.001));
      expect(k.rotation, closeTo(0.3, 0.001));
    });
  });

  // ── Rendu ─────────────────────────────────────────────────────────────────

  group('rendu', () {
    test('un autocollant se pose PAR-DESSUS le trait noir', () async {
      final CompiledPage page = compiled();
      final Offset surLeTrait = await inkPoint(page);
      final Color nu = await pixelAt(page, const <PaintOp>[], surLeTrait);
      expect(nu.r + nu.g + nu.b, lessThan(0.9), reason: 'le point n\'est pas de l\'encre');

      final Color couvert = await pixelAt(
        page,
        <PaintOp>[
          StickerOp(id: 1, kind: StickerKind.coeur, center: surLeTrait, scale: 2),
        ],
        surLeTrait,
      );
      expect(couvert.r, greaterThan(0.5),
          reason: 'le cœur rouge devrait couvrir l\'encre');
    });

    test('le cadre de sélection ne part pas à l\'export', () async {
      final CompiledPage page = compiled();
      final StickerOp k =
          StickerOp(id: 1, kind: StickerKind.etoile, center: const Offset(500, 500));
      // renderArtwork ne passe jamais `selected` : au coin du cadre, le papier
      // doit rester du papier.
      final Color coin = await pixelAt(page, <PaintOp>[k], stickerHandleAt(k));
      expect(coin.r, greaterThan(0.9));
      expect(coin.g, greaterThan(0.9));
      expect(coin.b, greaterThan(0.9));
    });

    test('les seize autocollants se dessinent sans erreur', () async {
      final CompiledPage page = compiled();
      for (final StickerKind k in StickerKind.values) {
        final ui.Image img = await renderArtwork(
          page,
          <PaintOp>[StickerOp(id: 1, kind: k, center: const Offset(500, 500))],
          pixelWidth: 240,
        );
        expect(img.width, 240, reason: k.name);
      }
    });
  });
}
