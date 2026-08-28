import 'dart:ui';

import 'package:barbouille/data/pages.g.dart';
import 'package:barbouille/l10n/app_strings.dart';
import 'package:barbouille/models/coloring_page.dart';
import 'package:barbouille/models/tool.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les chaînes de l'interface, une par langue. La liste est tenue à la main :
/// tout getter ajouté à [AppStrings] doit y être inscrit, faute de quoi une
/// traduction manquante passerait inaperçue.
List<String> _allStrings(AppStrings s) => <String>[
      s.galleryTagline, s.categoryAll, s.categoryMine, s.badgeStarted,
      s.emptyMine, s.studio, s.studioSoon,
      s.gallery, s.undo, s.redo, s.eraseAll,
      s.magicZones, s.freeMode, s.magicZonesHint, s.freeModeHint,
      s.magicZonesOn, s.freeModeOn,
      s.eraseAllTitle, s.eraseAllBody, s.eraseAllCancel, s.eraseAllConfirm,
      s.colorSwatch, s.newColor, s.newColorA11y,
      s.channelRed, s.channelGreen, s.channelBlue, s.addToPalette,
      s.settings, s.language, s.languageAuto, s.languageAutoDetail,
      s.close, s.cancel,
      s.parentalTitle, s.parentalInstruction, s.parentalHold,
      for (final ToolKind t in ToolKind.values) s.tool(t),
      for (final BrushSize b in BrushSize.values) s.brushSize(b),
      for (final BrushSize b in BrushSize.values) s.sizeLabel(b),
      for (final String c in <String>['animaux', 'vehicules', 'nature', 'gourmandises'])
        s.category(c),
    ];

void main() {
  test('aucune chaîne vide, dans aucune langue', () {
    for (final AppLocale l in AppLocale.values) {
      for (final String v in _allStrings(AppStrings(l))) {
        expect(v.trim(), isNotEmpty, reason: 'chaîne vide en ${l.code}');
      }
    }
  });

  test('le français et l\'anglais diffèrent réellement', () {
    final List<String> fr = _allStrings(const AppStrings(AppLocale.fr));
    final List<String> en = _allStrings(const AppStrings(AppLocale.en));
    expect(fr.length, en.length);

    // « Nature » et « Crayon » s'écrivent pareil dans les deux langues : on
    // vérifie donc la proportion, pas chaque entrée. Une table oubliée ferait
    // tomber ce seuil d'un coup.
    int different = 0;
    for (int i = 0; i < fr.length; i++) {
      if (fr[i] != en[i]) different++;
    }
    expect(different / fr.length, greaterThan(0.85),
        reason: '$different / ${fr.length} chaînes traduites');
  });

  test('chaque dessin a un titre dans les deux langues', () {
    for (final ColoringPage p in kColoringPages) {
      expect(p.title.fr.trim(), isNotEmpty, reason: p.id);
      expect(p.title.en.trim(), isNotEmpty, reason: p.id);
      expect(p.title.fr, isNot(p.title.en),
          reason: '${p.id} : titre non traduit');
    }
  });

  test('chaque catégorie de la bibliothèque a un libellé traduit', () {
    final Set<String> ids =
        kColoringPages.map((ColoringPage p) => p.category).toSet();
    for (final String id in ids) {
      for (final AppLocale l in AppLocale.values) {
        // Un identifiant inconnu est renvoyé tel quel : c'est le signe qu'une
        // catégorie a été ajoutée au générateur sans l'être à la traduction.
        expect(AppStrings(l).category(id), isNot(id),
            reason: 'catégorie « $id » sans libellé en ${l.code}');
      }
    }
  });

  test('la langue de l\'appareil est suivie quand elle est gérée', () {
    expect(AppStrings.resolve(<Locale>[const Locale('fr', 'FR')], const <Locale>[]),
        const Locale('fr'));
    expect(AppStrings.resolve(<Locale>[const Locale('en', 'GB')], const <Locale>[]),
        const Locale('en'));
  });

  test('une langue non gérée retombe sur l\'anglais', () {
    expect(AppStrings.resolve(<Locale>[const Locale('ja')], const <Locale>[]),
        const Locale('en'));
    expect(AppStrings.resolve(null, const <Locale>[]), const Locale('en'));
  });

  test('la deuxième préférence de l\'appareil est prise en compte', () {
    // Un appareil réglé en japonais puis en français doit donner du français,
    // et non l'anglais du repli.
    expect(
      AppStrings.resolve(
          <Locale>[const Locale('ja'), const Locale('fr')], const <Locale>[]),
      const Locale('fr'),
    );
  });

  test('le délégué ne gère que les langues déclarées', () {
    expect(AppStrings.delegate.isSupported(const Locale('fr')), isTrue);
    expect(AppStrings.delegate.isSupported(const Locale('en')), isTrue);
    expect(AppStrings.delegate.isSupported(const Locale('de')), isFalse);
  });

  test('chaque langue déclare son nom dans sa propre langue', () {
    expect(AppLocale.fr.nativeName, 'Français');
    expect(AppLocale.en.nativeName, 'English');
    expect(AppStrings.supportedLocales.length, AppLocale.values.length);
  });
}
