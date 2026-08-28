import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Téléchargement du fichier par le navigateur.
///
/// L'URL d'objet est libérée juste après : la garder retiendrait plusieurs
/// méga-octets par dessin enregistré, pour toute la durée de la session.
Future<void> saveArtworkImage(Uint8List bytes, String fileName) async {
  final web.Blob blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final String url = web.URL.createObjectURL(blob);
  final web.HTMLAnchorElement anchor =
      web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = fileName;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
