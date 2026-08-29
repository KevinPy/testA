import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/pattern.dart';
import '../models/sticker.dart';
import '../models/tool.dart';

/// Les langues proposées.
///
/// L'ajout d'une langue se fait en trois temps : une valeur ici, un paramètre
/// nommé **obligatoire** de plus dans [AppStrings._t], puis la traduction de
/// chaque chaîne — que l'analyseur signale une par une. C'est volontaire :
/// mieux vaut une erreur de compilation qu'une chaîne oubliée qui s'affiche
/// en français dans une application anglaise.
enum AppLocale {
  fr('fr', 'Français'),
  en('en', 'English');

  const AppLocale(this.code, this.nativeName);

  /// Code ISO 639-1.
  final String code;

  /// Nom de la langue **dans cette langue** : c'est ainsi qu'on la reconnaît
  /// quand l'application est affichée dans une langue qu'on ne lit pas.
  final String nativeName;

  static AppLocale? forCode(String code) {
    for (final AppLocale l in AppLocale.values) {
      if (l.code == code) return l;
    }
    return null;
  }

  Locale get locale => Locale(code);
}

/// Un même texte dans toutes les langues gérées. Sert aux données de la
/// bibliothèque de dessins, dont les titres sont générés.
@immutable
class L10nText {
  const L10nText({required this.fr, required this.en});

  final String fr;
  final String en;

  String resolve(AppLocale l) => switch (l) {
        AppLocale.fr => fr,
        AppLocale.en => en,
      };
}

/// Toutes les chaînes de l'interface.
///
/// Environ soixante-dix chaînes : une table écrite à la main reste plus lisible
/// qu'une chaîne de génération, et rien dans le parcours de l'enfant n'exige la
/// lecture — c'est le parent qui lit.
class AppStrings {
  const AppStrings(this.locale);

  final AppLocale locale;

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  static const List<Locale> supportedLocales = <Locale>[Locale('fr'), Locale('en')];

  /// Résout la langue à partir des préférences de l'appareil.
  /// Une langue non gérée retombe sur l'anglais, convention internationale —
  /// et non sur le français, qui n'est le bon défaut que sur un appareil français.
  static Locale resolve(List<Locale>? preferred, Iterable<Locale> supported) {
    for (final Locale want in preferred ?? const <Locale>[]) {
      final AppLocale? match = AppLocale.forCode(want.languageCode);
      if (match != null) return match.locale;
    }
    return AppLocale.en.locale;
  }

  String _t({required String fr, required String en}) => switch (locale) {
        AppLocale.fr => fr,
        AppLocale.en => en,
      };

  // ── Galerie ───────────────────────────────────────────────────────────────
  String get appName => 'Barbouille'; // le nom du produit ne se traduit pas
  String get galleryTagline =>
      _t(fr: 'Choisis ton dessin !', en: 'Pick your picture!');
  String get categoryAll => _t(fr: 'Tout', en: 'All');
  String get categoryMine => _t(fr: 'Mes coloriages', en: 'My pictures');
  String get badgeStarted => _t(fr: 'Commencé', en: 'Started');
  String get emptyMine => _t(
        fr: 'Aucun coloriage commencé.\nChoisis un dessin pour démarrer !',
        en: 'No pictures started yet.\nPick a drawing to begin!',
      );
  String get studio => _t(fr: 'Atelier', en: 'Studio');
  String get studioSoon =>
      _t(fr: 'Atelier — bientôt disponible', en: 'Studio — coming soon');

  /// Libellé d'une catégorie de la bibliothèque, à partir de son identifiant.
  String category(String id) => switch (id) {
        'animaux' => _t(fr: 'Animaux', en: 'Animals'),
        'vehicules' => _t(fr: 'Véhicules', en: 'Vehicles'),
        'nature' => _t(fr: 'Nature', en: 'Nature'),
        'gourmandises' => _t(fr: 'Gourmandises', en: 'Treats'),
        _ => id,
      };

  // ── Écran de coloriage ────────────────────────────────────────────────────
  String get gallery => _t(fr: 'Galerie', en: 'Gallery');
  String get undo => _t(fr: 'Annuler', en: 'Undo');
  String get redo => _t(fr: 'Refaire', en: 'Redo');
  String get eraseAll => _t(fr: 'Tout effacer', en: 'Erase all');
  String get magicZones => _t(fr: 'Zones magiques', en: 'Magic zones');
  String get freeMode => _t(fr: 'Libre', en: 'Free');
  String get magicZonesHint => _t(
        fr: 'Zones magiques : impossible de dépasser',
        en: 'Magic zones: you cannot go outside the lines',
      );
  String get freeModeHint => _t(
        fr: 'Mode libre : je colorie partout',
        en: 'Free mode: colour anywhere',
      );
  String get magicZonesOn =>
      _t(fr: 'Zones magiques activées', en: 'Magic zones on');
  String get freeModeOn => _t(fr: 'Mode libre activé', en: 'Free mode on');

  String get eraseAllTitle => _t(fr: 'Tout effacer ?', en: 'Erase everything?');
  String get eraseAllBody => _t(
        fr: 'Ton dessin redeviendra tout blanc.\nTu pourras l\'annuler avec la flèche ↩︎.',
        en: 'Your picture will go all white again.\nYou can undo it with the ↩︎ arrow.',
      );
  String get eraseAllCancel =>
      _t(fr: 'Non, je continue', en: 'No, keep going');
  String get eraseAllConfirm => _t(fr: 'Oui, effacer', en: 'Yes, erase');

  // ── Outils ────────────────────────────────────────────────────────────────
  String tool(ToolKind t) => switch (t) {
        ToolKind.crayon => _t(fr: 'Crayon', en: 'Crayon'),
        ToolKind.feutre => _t(fr: 'Feutre', en: 'Marker'),
        ToolKind.pot => _t(fr: 'Pot de peinture', en: 'Paint bucket'),
        ToolKind.gomme => _t(fr: 'Gomme', en: 'Eraser'),
        ToolKind.autocollant => _t(fr: 'Autocollants', en: 'Stickers'),
      };

  String brushSize(BrushSize s) => switch (s) {
        BrushSize.petit => _t(fr: 'Petit', en: 'Small'),
        BrushSize.moyen => _t(fr: 'Moyen', en: 'Medium'),
        BrushSize.grand => _t(fr: 'Grand', en: 'Large'),
      };

  String sizeLabel(BrushSize s) =>
      _t(fr: 'Taille ${brushSize(s)}', en: '${brushSize(s)} size');

  // ── Motifs ────────────────────────────────────────────────────────────────
  String get sectionPatterns => _t(fr: 'Motifs', en: 'Patterns');
  String get patternNone => _t(fr: 'Uni', en: 'Plain');
  String get patternNoneA11y =>
      _t(fr: 'Sans motif, couleur unie', en: 'No pattern, plain colour');
  String get patternsHint => _t(
        fr: 'Le motif suit le crayon, le feutre et le pot.',
        en: 'The pattern follows the crayon, the marker and the bucket.',
      );
  String pattern(PatternKind p) => switch (p) {
        PatternKind.pois => _t(fr: 'Pois', en: 'Dots'),
        PatternKind.rayures => _t(fr: 'Rayures', en: 'Stripes'),
        PatternKind.zigzag => _t(fr: 'Zigzag', en: 'Zigzag'),
        PatternKind.etoiles => _t(fr: 'Étoiles', en: 'Stars'),
        PatternKind.coeurs => _t(fr: 'Cœurs', en: 'Hearts'),
        PatternKind.carreaux => _t(fr: 'Carreaux', en: 'Checks'),
      };

  // ── Autocollants ──────────────────────────────────────────────────────────
  String get sectionStickers => _t(fr: 'Autocollants', en: 'Stickers');
  String get stickersHint => _t(
        fr: 'Appuie sur le dessin pour le coller. Fais-le glisser, tourne-le, '
            'écarte deux doigts pour l\'agrandir.',
        en: 'Tap the picture to stick it on. Drag it, spin it, pinch with two '
            'fingers to make it bigger.',
      );
  String get stickerRemove =>
      _t(fr: 'Enlever l\'autocollant', en: 'Remove the sticker');
  String sticker(StickerKind k) => switch (k) {
        StickerKind.etoile => _t(fr: 'Étoile', en: 'Star'),
        StickerKind.coeur => _t(fr: 'Cœur', en: 'Heart'),
        StickerKind.arcenciel => _t(fr: 'Arc-en-ciel', en: 'Rainbow'),
        StickerKind.soleil => _t(fr: 'Soleil', en: 'Sun'),
        StickerKind.lune => _t(fr: 'Lune', en: 'Moon'),
        StickerKind.nuage => _t(fr: 'Nuage', en: 'Cloud'),
        StickerKind.fleur => _t(fr: 'Fleur', en: 'Flower'),
        StickerKind.papillon => _t(fr: 'Papillon', en: 'Butterfly'),
        StickerKind.coccinelle => _t(fr: 'Coccinelle', en: 'Ladybird'),
        StickerKind.poisson => _t(fr: 'Poisson', en: 'Fish'),
        StickerKind.ballon => _t(fr: 'Ballon', en: 'Balloon'),
        StickerKind.fusee => _t(fr: 'Fusée', en: 'Rocket'),
        StickerKind.voiture => _t(fr: 'Voiture', en: 'Car'),
        StickerKind.glace => _t(fr: 'Glace', en: 'Ice cream'),
        StickerKind.cupcake => _t(fr: 'Petit gâteau', en: 'Cupcake'),
        StickerKind.couronne => _t(fr: 'Couronne', en: 'Crown'),
      };

  // ── Couleurs ──────────────────────────────────────────────────────────────
  String get colorSwatch => _t(fr: 'Couleur', en: 'Colour');
  String get newColor => _t(fr: 'Je crée ma couleur', en: 'Make my own colour');
  String get newColorA11y =>
      _t(fr: 'Créer une nouvelle couleur', en: 'Create a new colour');
  String get channelRed => _t(fr: 'Rouge', en: 'Red');
  String get channelGreen => _t(fr: 'Vert', en: 'Green');
  String get channelBlue => _t(fr: 'Bleu', en: 'Blue');
  String get addToPalette =>
      _t(fr: 'Ajouter à ma palette', en: 'Add to my palette');
  String channelValue(String channel, int value) =>
      _t(fr: '$channel $value sur 255', en: '$channel $value of 255');

  // ── Atelier ───────────────────────────────────────────────────────────────
  String get atelierTitle => _t(fr: 'Mon atelier', en: 'My studio');
  String get atelierHint => _t(
        fr: 'Dessine ton contour au feutre noir',
        en: 'Draw your outline with the black marker',
      );
  String get atelierTransform =>
      _t(fr: 'En faire un coloriage', en: 'Turn it into a colouring page');
  String get atelierWorking => _t(
        fr: 'Je prépare ton coloriage…',
        en: 'Getting your colouring page ready…',
      );
  String get atelierBlank => _t(
        fr: 'Ta feuille est encore toute blanche.\nDessine quelque chose !',
        en: 'Your sheet is still blank.\nDraw something first!',
      );
  String get atelierFull => _t(
        fr: 'Tu as déjà beaucoup de dessins.\nSupprimes-en un pour en créer un nouveau.',
        en: 'You already have a lot of drawings.\nDelete one to make room.',
      );
  String get atelierPen => _t(fr: 'Feutre noir', en: 'Black marker');
  String get categoryAtelier => _t(fr: 'Mes dessins', en: 'My drawings');
  String get deleteDrawingTitle =>
      _t(fr: 'Supprimer ce dessin ?', en: 'Delete this drawing?');
  String get deleteDrawingBody => _t(
        fr: 'Il partira pour de bon, avec son coloriage.',
        en: 'It will be gone for good, along with its colouring.',
      );
  String get delete => _t(fr: 'Supprimer', en: 'Delete');
  String get keep => _t(fr: 'Non, je le garde', en: 'No, keep it');

  // ── Tiroir d'outils ───────────────────────────────────────────────────────
  String get openTools => _t(fr: 'Mes outils', en: 'My tools');
  String get sectionTools => _t(fr: 'Outils', en: 'Tools');
  String get sectionSize => _t(fr: 'Taille du trait', en: 'Line size');
  String get sectionColors => _t(fr: 'Couleurs', en: 'Colours');

  // ── Capture ───────────────────────────────────────────────────────────────
  String get capture => _t(fr: 'Garder mon dessin', en: 'Keep my drawing');
  String get captureTitle => _t(fr: 'Mon dessin', en: 'My drawing');
  String get captureSave => _t(fr: 'Enregistrer l\'image', en: 'Save the picture');
  String get captureWorking =>
      _t(fr: 'Je prépare l\'image…', en: 'Getting the picture ready…');
  String get captureDone => _t(fr: 'Image enregistrée !', en: 'Picture saved!');
  String get captureFailed => _t(
        fr: 'L\'image n\'a pas pu être enregistrée.',
        en: 'The picture could not be saved.',
      );
  String captureSize(int px) =>
      _t(fr: '$px × $px points', en: '$px × $px pixels');

  // ── Réglages ──────────────────────────────────────────────────────────────
  String get settings => _t(fr: 'Réglages', en: 'Settings');
  String get language => _t(fr: 'Langue', en: 'Language');
  String get languageAuto => _t(fr: 'Automatique', en: 'Automatic');
  String get languageAutoDetail => _t(
        fr: 'Suit la langue de l\'appareil',
        en: 'Follows the device language',
      );
  String get close => _t(fr: 'Fermer', en: 'Close');
  String get cancel => _t(fr: 'Annuler', en: 'Cancel');

  // ── Contrôle parental ─────────────────────────────────────────────────────
  String get parentalTitle => _t(fr: 'Espace parents', en: 'Grown-ups only');
  String get parentalInstruction => _t(
        fr: 'Maintiens le bouton appuyé pendant 2 secondes.',
        en: 'Press and hold the button for 2 seconds.',
      );
  String get parentalHold => _t(fr: 'Maintenir appuyé', en: 'Press and hold');
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocale.forCode(locale.languageCode) != null;

  @override
  Future<AppStrings> load(Locale locale) => SynchronousFuture<AppStrings>(
        AppStrings(AppLocale.forCode(locale.languageCode) ?? AppLocale.en),
      );

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
