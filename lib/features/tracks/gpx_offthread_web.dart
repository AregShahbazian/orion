import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'track_model.dart';

/// One long-lived worker (parse calls are serial — import processes files one at
/// a time), spun up lazily on first import.
web.Worker? _worker;
web.Worker _ensureWorker() => _worker ??= web.Worker('gpx_worker.dart.js'.toJS);

/// Web: parse in a real Web Worker so the UI thread stays free. Sends the raw
/// bytes, gets back the tracks as JSON, reconstructs them.
Future<List<ParsedTrack>> parseGpxOffThread(Uint8List bytes) async {
  final worker = _ensureWorker();
  final completer = Completer<String>();
  late final JSFunction onMessage;
  late final JSFunction onError;
  void cleanup() {
    worker.removeEventListener('message', onMessage);
    worker.removeEventListener('error', onError);
  }

  onMessage = ((web.MessageEvent e) {
    cleanup();
    completer.complete((e.data as JSString).toDart);
  }).toJS;
  onError = ((web.Event e) {
    cleanup();
    completer.completeError(StateError('gpx worker failed'));
  }).toJS;

  worker.addEventListener('message', onMessage);
  worker.addEventListener('error', onError);
  worker.postMessage(bytes.toJS);
  return _decode(await completer.future);
}

/// Rebuild the parsed tracks from the worker's compact JSON
/// (`{n,d,c,p:[[lat,lon,ele,millis]…]}`).
List<ParsedTrack> _decode(String json) {
  final list = jsonDecode(json) as List<dynamic>;
  return [
    for (final t in list)
      ParsedTrack(
        name: t['n'] as String,
        description: t['d'] as String?,
        color: t['c'] as String,
        points: [
          for (final p in (t['p'] as List<dynamic>))
            ParsedPoint(
              lat: (p[0] as num).toDouble(),
              lon: (p[1] as num).toDouble(),
              ele: (p[2] as num?)?.toDouble(),
              time:
                  DateTime.fromMillisecondsSinceEpoch(p[3] as int, isUtc: true),
            ),
        ],
      ),
  ];
}
