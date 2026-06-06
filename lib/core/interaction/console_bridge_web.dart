import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'interaction.dart';
import 'interaction_controller.dart';
import 'interaction_ids.dart';

/// Completes once the map style has loaded and the camera is usable. Lets console
/// automation `await orion.ready` before driving the map, instead of guessing a
/// fixed delay. Signalled by the map via [signalMapReady].
final Completer<void> _mapReady = Completer<void>();

/// Called by the map once its style is loaded — resolves `orion.ready`. No-op
/// after the first call (stubbed to nothing on non-web builds).
void signalMapReady() {
  if (!_mapReady.isCompleted) _mapReady.complete();
}

/// Web: expose `window.orion` so interactions can be fired from the browser
/// console as programmatic dispatches:
///
/// ```js
/// await orion.ready                 // resolves when the map is usable
/// await orion.dispatch('hud.followMe.tap')
/// await orion.dispatch('map.zoom.changed', { zoom: 12 })   // resolves when the move settles
/// orion.ids                         // → the valid interaction ids
/// orion.logEvents(true)             // start echoing each interaction to the log
/// orion.dump()                      // print the captured buffer; returns the records
/// ```
///
/// [dispatch] returns a Promise that resolves when the handler finishes (e.g. a
/// camera animation completes), so scripts can sequence steps with `await`.
///
/// Dev-only — the caller gates this on [kDebugMode], so it's never installed in
/// a release build.
void installInteractionConsoleBridge(InteractionController bus) {
  final api = JSObject();

  api.setProperty('dispatch'.toJS, ((JSString id, [JSAny? payload]) {
    final dartId = id.toDart;
    if (!InteractionIds.all.contains(dartId)) {
      web.console.warn(
          'orion: unknown interaction "$dartId" — see orion.ids'.toJS);
      return null;
    }
    final data = payload?.dartify();
    Future<JSAny?> run() async {
      await bus.dispatch(
        dartId,
        origin: InteractionOrigin.programmatic,
        payload: data is Map ? data.cast<String, Object?>() : null,
      );
      return null;
    }

    return run().toJS;
  }).toJS);

  api.setProperty(
      'ids'.toJS, [for (final id in InteractionIds.all) id.toJS].toJS);

  // Toggle the per-event log line at runtime: `orion.logEvents(true)`. Called
  // with no arg, just reports the current state.
  api.setProperty('logEvents'.toJS, ((JSBoolean? on) {
    if (on != null) bus.logEvents = on.toDart;
    return bus.logEvents.toJS;
  }).toJS);

  // `orion.dump()` — log the captured buffer as readable lines and return the
  // records as JS objects ({id, origin, at, payload}) so they can be inspected
  // or replayed via orion.dispatch(rec.id, rec.payload).
  api.setProperty('dump'.toJS, (() {
    web.console.log(bus.dump().toJS);
    return [
      for (final r in bus.recent())
        {
          'id': r.id,
          'origin': r.origin.name,
          'at': r.at.toIso8601String(),
          'payload': r.payload,
        }.jsify(),
    ].toJS;
  }).toJS);

  // A Promise resolving once the map is usable: `await orion.ready`.
  Future<JSAny?> ready() async {
    await _mapReady.future;
    return null;
  }

  api.setProperty('ready'.toJS, ready().toJS);

  web.window.setProperty('orion'.toJS, api);
}
