import 'dart:ui';

import 'package:barbouille/data/pages.g.dart';
import 'package:barbouille/models/coloring_page.dart';
import 'package:barbouille/models/paint_op.dart';
import 'package:barbouille/models/tool.dart';
import 'package:barbouille/state/artwork_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chaque dessin de la bibliothèque se compile en chemins valides', () {
    for (final ColoringPage page in kColoringPages) {
      final CompiledPage c = CompiledPage.of(page);
      expect(c.regions.length, page.regions.length, reason: page.id);
      expect(c.regions, isNotEmpty, reason: page.id);
      for (int i = 0; i < c.regions.length; i++) {
        final Rect b = c.regions[i].getBounds();
        expect(b.isEmpty, isFalse,
            reason: '${page.id}/${page.regions[i].id} : zone vide');
        expect(b.width, lessThanOrEqualTo(page.size.width * 1.5),
            reason: '${page.id}/${page.regions[i].id} : zone hors page');
      }
    }
  });

  test('les identifiants de zone sont uniques dans un dessin', () {
    for (final ColoringPage page in kColoringPages) {
      final Set<String> ids =
          page.regions.map((RegionData r) => r.id).toSet();
      expect(ids.length, page.regions.length, reason: page.id);
    }
  });

  test('le test de contact renvoie la zone du dessus', () {
    // Le chat : l'œil gauche est posé sur la tête. Un doigt sur l'œil doit
    // sélectionner l'œil, pas la tête — sinon le pot de peinture repeindrait
    // tout le visage.
    final ColoringPage chat =
        kColoringPages.firstWhere((ColoringPage p) => p.id == 'chat');
    final CompiledPage c = CompiledPage.of(chat);
    final int oeil = chat.regions.indexWhere((RegionData r) => r.id == 'oeil_g');
    expect(c.hitTest(const Offset(415, 355)), oeil);
  });

  test('un point hors du dessin tombe dans le fond', () {
    final CompiledPage c = CompiledPage.of(kColoringPages.first);
    expect(c.hitTest(const Offset(6, 6)), kBackgroundRegion);
  });

  test('zones magiques : le trait est détouré sur la zone touchée', () {
    final ColoringPage chat =
        kColoringPages.firstWhere((ColoringPage p) => p.id == 'chat');
    final ArtworkController ctrl = ArtworkController(CompiledPage.of(chat));
    final int tete = chat.regions.indexWhere((RegionData r) => r.id == 'tete');

    ctrl.setTool(ToolKind.feutre);
    ctrl.startStroke(const Offset(500, 380)); // au milieu de la tête
    ctrl.extendStroke(const Offset(980, 980)); // on file loin hors du chat
    ctrl.endStroke();

    final StrokeOp op = ctrl.ops.single as StrokeOp;
    expect(op.clipRegion, tete,
        reason: 'la zone doit être verrouillée au poser du doigt');
  });

  test('mode libre : aucun détourage', () {
    final CompiledPage c = CompiledPage.of(kColoringPages.first);
    final ArtworkController ctrl = ArtworkController(c)..setMagicZones(false);
    ctrl.startStroke(const Offset(500, 380));
    ctrl.endStroke();
    expect((ctrl.ops.single as StrokeOp).clipRegion, isNull);
  });

  test('le pot de peinture remplit la zone touchée', () {
    final ColoringPage chat =
        kColoringPages.firstWhere((ColoringPage p) => p.id == 'chat');
    final CompiledPage c = CompiledPage.of(chat);
    final ArtworkController ctrl = ArtworkController(c)..setTool(ToolKind.pot);
    ctrl.startStroke(const Offset(500, 380));
    final FillOp op = ctrl.ops.single as FillOp;
    expect(op.region, chat.regions.indexWhere((RegionData r) => r.id == 'tete'));
  });

  test('annuler / rétablir parcourt la pile dans les deux sens', () {
    final ArtworkController ctrl =
        ArtworkController(CompiledPage.of(kColoringPages.first));
    ctrl
      ..startStroke(const Offset(500, 380))
      ..endStroke()
      ..startStroke(const Offset(510, 390))
      ..endStroke();
    expect(ctrl.ops.length, 2);

    ctrl.undo();
    expect(ctrl.ops.length, 1);
    expect(ctrl.canRedo, isTrue);

    ctrl.redo();
    expect(ctrl.ops.length, 2);
    expect(ctrl.canRedo, isFalse);
  });

  test('« tout effacer » reste annulable', () {
    final ArtworkController ctrl =
        ArtworkController(CompiledPage.of(kColoringPages.first));
    ctrl
      ..startStroke(const Offset(500, 380))
      ..endStroke()
      ..startStroke(const Offset(400, 300))
      ..endStroke()
      ..clear();
    expect(ctrl.isBlank, isTrue);

    // Un seul appui sur ↩︎ doit tout ramener : un enfant qui efface son
    // quart d'heure de travail par mégarde ne comprendrait pas d'avoir à
    // annuler trait par trait.
    ctrl.undo();
    expect(ctrl.isBlank, isFalse);
    expect(ctrl.ops.length, 2);
  });

  test('choisir une couleur sort de la gomme', () {
    final ArtworkController ctrl =
        ArtworkController(CompiledPage.of(kColoringPages.first))
          ..setTool(ToolKind.gomme)
          ..setColor(const Color(0xFF00FF00));
    expect(ctrl.tool, ToolKind.feutre);
  });

  test('une œuvre survit à un aller-retour de sérialisation', () {
    final CompiledPage c = CompiledPage.of(kColoringPages.first);
    final ArtworkController ctrl = ArtworkController(c)
      ..setTool(ToolKind.crayon)
      ..setColor(const Color(0xFF123456));
    ctrl
      ..startStroke(const Offset(500, 380))
      ..extendStroke(const Offset(520, 400))
      ..endStroke()
      ..setTool(ToolKind.pot);
    ctrl.startStroke(const Offset(500, 380));

    final List<PaintOp> restored = ArtworkController.decodeOps(ctrl.encode());
    expect(restored.length, 2);

    final StrokeOp s = restored[0] as StrokeOp;
    expect(s.tool, ToolKind.crayon);
    expect(s.color, 0xFF123456);
    expect(s.points.length, 2);
    expect(s.seed, (ctrl.ops[0] as StrokeOp).seed,
        reason: 'le grain du crayon doit se redessiner à l\'identique');
    expect(restored[1], isA<FillOp>());
  });

  test('les micro-déplacements du doigt sont filtrés', () {
    final ArtworkController ctrl =
        ArtworkController(CompiledPage.of(kColoringPages.first));
    ctrl.startStroke(const Offset(500, 380));
    for (int i = 0; i < 20; i++) {
      ctrl.extendStroke(Offset(500 + i * 0.1, 380));
    }
    ctrl.endStroke();
    expect((ctrl.ops.single as StrokeOp).points.length, 1);
  });
}
