import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/coloring_page.dart';

/// Identifiant de la catégorie des dessins créés dans l'Atelier.
const String kAtelierCategory = 'atelier';

/// Les dessins créés par l'enfant.
///
/// Ils sont enregistrés sous la même forme que la bibliothèque livrée — des
/// zones et des traits en données de chemin SVG — pour qu'une création se
/// colorie exactement comme un dessin d'origine : mêmes outils, mêmes zones
/// magiques, même pot de peinture, sans une ligne de rendu en plus.
class CreationStore extends ChangeNotifier {
  CreationStore(this._prefs);

  static const String _kIndex = 'atelier_index';
  static const String _kPrefix = 'atelier_page_';

  /// Au-delà, le stockage local devient un mauvais endroit pour des dessins :
  /// l'export de fichiers, prévu avec le partage, prendra le relais.
  static const int maxCreations = 40;

  final SharedPreferences _prefs;

  List<String> get _ids =>
      (jsonDecode(_prefs.getString(_kIndex) ?? '[]') as List<dynamic>)
          .cast<String>();

  bool get isFull => _ids.length >= maxCreations;

  /// Les créations, de la plus récente à la plus ancienne.
  List<ColoringPage> get pages {
    final List<ColoringPage> out = <ColoringPage>[];
    for (final String id in _ids) {
      final String? raw = _prefs.getString('$_kPrefix$id');
      if (raw == null) continue;
      try {
        out.add(_decode(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Une entrée illisible ne doit pas emporter toute la galerie.
        continue;
      }
    }
    return out;
  }

  bool contains(String id) => _ids.contains(id);

  /// Numéro à donner au prochain dessin : « Mon dessin 4 ».
  int get nextNumber {
    int best = 0;
    for (final String id in _ids) {
      final int? n = int.tryParse(id.split('_').last);
      if (n != null && n > best) best = n;
    }
    return best + 1;
  }

  Future<ColoringPage> save({
    required int number,
    required Size size,
    required List<String> regionPaths,
    required List<({String d, double width})> ink,
  }) async {
    final String id = 'atelier_$number';
    final Map<String, dynamic> json = <String, dynamic>{
      'v': 1,
      'id': id,
      'n': number,
      'w': size.width,
      'h': size.height,
      'regions': regionPaths,
      'ink': <Map<String, dynamic>>[
        for (final ({String d, double width}) s in ink)
          <String, dynamic>{'d': s.d, 'w': s.width},
      ],
    };
    await _prefs.setString('$_kPrefix$id', jsonEncode(json));
    final List<String> ids = _ids;
    ids.remove(id);
    ids.insert(0, id);
    await _prefs.setString(_kIndex, jsonEncode(ids));
    notifyListeners();
    return _decode(json);
  }

  Future<void> delete(String id) async {
    await _prefs.remove('$_kPrefix$id');
    await _prefs.remove('artwork_$id'); // le coloriage associé part avec
    final List<String> ids = _ids..remove(id);
    await _prefs.setString(_kIndex, jsonEncode(ids));
    CompiledPage.evict(id);
    notifyListeners();
  }

  static ColoringPage _decode(Map<String, dynamic> j) {
    final int number = j['n'] as int;
    return ColoringPage(
      id: j['id'] as String,
      // Le titre est numéroté plutôt que saisi : à 4 ans on ne tape pas au
      // clavier, et l'enfant reconnaît son dessin à la vignette.
      title: L10nText(fr: 'Mon dessin $number', en: 'My drawing $number'),
      category: kAtelierCategory,
      emoji: '✏️',
      size: Size((j['w'] as num).toDouble(), (j['h'] as num).toDouble()),
      regions: <RegionData>[
        for (int i = 0; i < (j['regions'] as List<dynamic>).length; i++)
          RegionData('z$i', (j['regions'] as List<dynamic>)[i] as String),
      ],
      details: <DetailData>[
        for (final dynamic s in j['ink'] as List<dynamic>)
          DetailData((s as Map<String, dynamic>)['d'] as String,
              (s['w'] as num).toDouble()),
      ],
      drawRegionOutlines: false,
    );
  }
}
