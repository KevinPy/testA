import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Feuille de partage du système, qui propose « Enregistrer l'image ».
///
/// Passer par elle plutôt que par un accès direct à la photothèque évite de
/// réclamer la permission « Photos » : une application de coloriage qui la
/// demande inquiète à juste titre, et Apple la scrute dans la catégorie Enfants.
Future<void> saveArtworkImage(Uint8List bytes, String fileName) async {
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(files: <XFile>[XFile(file.path, mimeType: 'image/png')]),
  );
}
