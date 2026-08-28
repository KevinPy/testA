import 'dart:typed_data';
import 'dart:ui';

import 'package:barbouille/data/pages.g.dart';
import 'package:barbouille/export/artwork_export.dart';
import 'package:barbouille/models/coloring_page.dart';
import 'package:barbouille/models/paint_op.dart';
import 'package:flutter_test/flutter_test.dart';

/// En-tête PNG : signature, puis le bloc IHDR qui porte les dimensions.
({int width, int height}) readPngSize(Uint8List b) {
  const List<int> signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  for (int i = 0; i < signature.length; i++) {
    expect(b[i], signature[i], reason: 'ce n\'est pas un PNG');
  }
  final ByteData d = ByteData.sublistView(b);
  expect(String.fromCharCodes(b.sublist(12, 16)), 'IHDR');
  return (width: d.getUint32(16), height: d.getUint32(20));
}

void main() {
  final ColoringPage chat =
      kColoringPages.firstWhere((ColoringPage p) => p.id == 'chat');

  test('l\'export produit un vrai PNG aux dimensions demandées', () async {
    final Uint8List png = await encodeArtworkPng(
      CompiledPage.of(chat),
      const <PaintOp>[],
      pixels: 512,
    );
    final ({int width, int height}) size = readPngSize(png);
    expect(size.width, 512);
    expect(size.height, 512);
    expect(png.length, greaterThan(1000), reason: 'image manifestement vide');
  });

  test('le dessin colorié pèse plus lourd que la page vierge', () async {
    final CompiledPage page = CompiledPage.of(chat);
    final Uint8List blank =
        await encodeArtworkPng(page, const <PaintOp>[], pixels: 512);
    final Uint8List filled = await encodeArtworkPng(
      page,
      <PaintOp>[
        for (int i = 0; i < chat.regions.length; i++)
          if (chat.regions[i].hint != null)
            FillOp(region: i, color: chat.regions[i].hint!),
      ],
      pixels: 512,
    );
    // Une image couleur se compresse moins bien qu'un trait noir sur blanc :
    // si les deux pesaient pareil, c'est que le coloriage n'a pas été rendu.
    expect(filled.length, greaterThan(blank.length));
  });

  test('la marge blanche entoure le dessin', () async {
    // Sans marge, un trait qui touche le bord serait coupé net contre le cadre.
    final Uint8List withMargin = await encodeArtworkPng(
      CompiledPage.of(chat),
      const <PaintOp>[],
      pixels: 256,
      marginRatio: 0.2,
    );
    final Uint8List without = await encodeArtworkPng(
      CompiledPage.of(chat),
      const <PaintOp>[],
      pixels: 256,
      marginRatio: 0,
    );
    // Plus de marge = plus de blanc uni = fichier plus léger.
    expect(withMargin.length, lessThan(without.length));
    expect(readPngSize(withMargin).width, 256);
  });

  test('le nom de fichier est lisible et sans accent', () {
    expect(artworkFileName('Le chat câlin'), 'barbouille-le-chat-calin.png');
    expect(artworkFileName('La fusée de l\'espace'),
        'barbouille-la-fusee-de-l-espace.png');
    expect(artworkFileName('Mon dessin 3'), 'barbouille-mon-dessin-3.png');
    expect(artworkFileName('The cuddly cat'), 'barbouille-the-cuddly-cat.png');
  });

  test('un titre sans lettre exploitable donne quand même un nom', () {
    expect(artworkFileName('🎨'), 'barbouille-dessin.png');
    expect(artworkFileName('   '), 'barbouille-dessin.png');
  });

  test('une création de l\'Atelier s\'exporte comme les autres', () async {
    // Une page dont les zones viennent des pixels doit passer par le même
    // chemin d'export, sans traitement particulier.
    final ColoringPage creation = ColoringPage(
      id: 'export_atelier',
      title: chat.title,
      category: 'atelier',
      emoji: '✏️',
      size: const Size(1000, 1000),
      regions: const <RegionData>[
        RegionData('z0', 'M 0 0 L 1000 0 L 1000 1000 L 0 1000 Z'),
        RegionData('z1', 'M 300 300 L 700 300 L 700 700 L 300 700 Z'),
      ],
      details: const <DetailData>[DetailData('M 300 300 L 700 700', 12)],
      drawRegionOutlines: false,
    );
    addTearDown(() => CompiledPage.evict('export_atelier'));

    final Uint8List png = await encodeArtworkPng(
      CompiledPage.of(creation),
      <PaintOp>[const FillOp(region: 1, color: 0xFF2C7BE5)],
      pixels: 256,
    );
    expect(readPngSize(png).width, 256);
  });
}
