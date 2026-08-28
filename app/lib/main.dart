import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'atelier/creation_store.dart';
import 'l10n/app_strings.dart';
import 'screens/gallery_screen.dart';
import 'state/palette_store.dart';
import 'state/settings_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Toutes les orientations : l'application doit suivre la tablette, qu'elle
  // soit posée à plat ou tenue debout.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  runApp(
    BarbouilleApp(
      store: PaletteStore(prefs),
      settings: SettingsStore(prefs),
      creations: CreationStore(prefs),
    ),
  );
}

class BarbouilleApp extends StatelessWidget {
  const BarbouilleApp({
    super.key,
    required this.store,
    required this.settings,
    required this.creations,
  });

  final PaletteStore store;
  final SettingsStore settings;
  final CreationStore creations;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, _) => MaterialApp(
        title: 'Barbouille',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),

        // `null` = suivre l'appareil, et c'est le défaut.
        locale: settings.locale,
        supportedLocales: AppStrings.supportedLocales,
        localeListResolutionCallback: AppStrings.resolve,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          AppStrings.delegate,
          // Les trois délégués du SDK traduisent aussi ce que l'application ne
          // rédige pas elle-même : intitulés d'accessibilité des boîtes de
          // dialogue, indications d'appui long, sens de lecture.
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        home: GalleryScreen(
          store: store,
          settings: settings,
          creations: creations,
        ),
      ),
    );
  }
}
