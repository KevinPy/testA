import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/gallery_screen.dart';
import 'state/palette_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Toutes les orientations : l'application doit suivre la tablette, qu'elle
  // soit posée à plat ou tenue debout.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  final PaletteStore store = await PaletteStore.load();
  runApp(BarbouilleApp(store: store));
}

class BarbouilleApp extends StatelessWidget {
  const BarbouilleApp({super.key, required this.store});

  final PaletteStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barbouille',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: GalleryScreen(store: store),
    );
  }
}
