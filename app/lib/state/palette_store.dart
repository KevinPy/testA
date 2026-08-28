import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Les couleurs personnalisées créées via la modale RVB, plus les coloriages
/// en cours. Stockage local uniquement : aucun compte, aucune donnée envoyée.
class PaletteStore extends ChangeNotifier {
  PaletteStore(this._prefs);

  static const String _kCustom = 'custom_colors';
  static const String _kArtworkPrefix = 'artwork_';
  static const int _kMaxCustom = 24;

  final SharedPreferences _prefs;

  static Future<PaletteStore> load() async =>
      PaletteStore(await SharedPreferences.getInstance());

  List<Color> get customColors {
    final String? raw = _prefs.getString(_kCustom);
    if (raw == null) return <Color>[];
    return (jsonDecode(raw) as List<dynamic>)
        .map((dynamic e) => Color(e as int))
        .toList();
  }

  List<Color> get defaultColors =>
      kDefaultPalette.map((int c) => Color(c)).toList();

  Future<void> addCustomColor(Color c) async {
    final List<Color> list = customColors;
    final int argb = c.toARGB32();
    list.removeWhere((Color e) => e.toARGB32() == argb);
    list.insert(0, c);
    if (list.length > _kMaxCustom) list.removeRange(_kMaxCustom, list.length);
    await _prefs.setString(
      _kCustom,
      jsonEncode(list.map((Color e) => e.toARGB32()).toList()),
    );
    notifyListeners();
  }

  Future<void> removeCustomColor(Color c) async {
    final List<Color> list = customColors
      ..removeWhere((Color e) => e.toARGB32() == c.toARGB32());
    await _prefs.setString(
      _kCustom,
      jsonEncode(list.map((Color e) => e.toARGB32()).toList()),
    );
    notifyListeners();
  }

  String? artworkFor(String pageId) => _prefs.getString('$_kArtworkPrefix$pageId');

  bool hasArtwork(String pageId) => _prefs.containsKey('$_kArtworkPrefix$pageId');

  Future<void> saveArtwork(String pageId, String encoded) async {
    await _prefs.setString('$_kArtworkPrefix$pageId', encoded);
    notifyListeners();
  }

  Future<void> deleteArtwork(String pageId) async {
    await _prefs.remove('$_kArtworkPrefix$pageId');
    notifyListeners();
  }
}
