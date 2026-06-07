import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: trigger a browser download of the GPX via an object-URL anchor click.
Future<void> exportGpx(String filename, String gpx) async {
  final blob = web.Blob(
    [gpx.toJS].toJS,
    web.BlobPropertyBag(type: 'application/gpx+xml'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
