// Web Worker entrypoint: parses GPX off the UI thread (dart2js has no isolates).
// Compiled to web/gpx_worker.dart.js — see scripts/build_web_worker.sh. Rebuild
// after changing the parser. Pure Dart only (no Flutter), so it compiles to JS.
import 'dart:convert';
import 'dart:js_interop';

import 'package:orion/features/tracks/gpx_parser.dart';

@JS('self')
external _WorkerScope get _self;

extension type _WorkerScope(JSObject _) implements JSObject {
  external set onmessage(JSFunction value);
  external void postMessage(JSAny? message);
}

extension type _MessageEvent(JSObject _) implements JSObject {
  external JSAny? get data;
}

void main() {
  _self.onmessage = ((_MessageEvent e) {
    final bytes = (e.data as JSUint8Array).toDart;
    final tracks = parseGpxBytes(bytes);
    final json = jsonEncode([
      for (final t in tracks)
        {
          'n': t.name,
          'd': t.description,
          'c': t.color,
          'p': [
            for (final p in t.points)
              [p.lat, p.lon, p.ele, p.time.millisecondsSinceEpoch],
          ],
        },
    ]);
    _self.postMessage(json.toJS);
  }).toJS;
}
