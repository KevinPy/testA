import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

/// Les réglages de l'application. Un seul pour l'instant : la langue.
///
/// Trois états, et non deux : « Automatique » suit la langue de l'appareil et
/// reste le défaut — c'est presque toujours le bon choix, et l'application ne
/// doit jamais démarrer dans un état que le parent n'a pas choisi.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);

  static const String _kLocale = 'locale';
  static const String _kAuto = 'auto';

  final SharedPreferences _prefs;

  /// La langue choisie explicitement, ou `null` pour « suivre l'appareil ».
  AppLocale? get localeChoice {
    final String? raw = _prefs.getString(_kLocale);
    if (raw == null || raw == _kAuto) return null;
    return AppLocale.forCode(raw);
  }

  bool get isAutomatic => localeChoice == null;

  /// Passée à `MaterialApp.locale` : `null` laisse la résolution au système.
  Locale? get locale => localeChoice?.locale;

  Future<void> setLocaleChoice(AppLocale? choice) async {
    await _prefs.setString(_kLocale, choice?.code ?? _kAuto);
    notifyListeners();
  }
}
