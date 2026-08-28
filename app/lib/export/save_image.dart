import 'dart:typed_data';

export 'save_image_io.dart' if (dart.library.js_interop) 'save_image_web.dart';

/// Comment l'image quitte l'application, selon la plateforme :
///
///  * sur le web, un téléchargement — c'est le geste que le navigateur connaît ;
///  * sur téléphone et tablette, la feuille de partage du système, seule voie
///    pour déposer une image dans la photothèque sans réclamer une permission
///    d'accès aux photos que l'application n'a aucune autre raison de demander.
typedef SaveImage = Future<void> Function(Uint8List bytes, String fileName);
