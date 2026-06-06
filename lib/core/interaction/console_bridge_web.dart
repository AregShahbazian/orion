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
/// orion.demo()                      // run the built-in Manila demo flow
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

  // A Promise resolving once the map is usable: `await orion.ready`.
  Future<JSAny?> ready() async {
    await _mapReady.future;
    return null;
  }

  api.setProperty('ready'.toJS, ready().toJS);

  // Built-in demo flow: `orion.demo()` (optional pause in ms between steps).
  // Waits for the map, zooms in on Manila, pans a short walk, then focuses the
  // current location. Returns a Promise resolving when the flow finishes.
  api.setProperty('demo'.toJS, (([JSNumber? pauseMs]) {
    final pause = Duration(milliseconds: pauseMs?.toDartInt ?? 800);
    return _runDemo(bus, pause).toJS;
  }).toJS);

  web.window.setProperty('orion'.toJS, api);
}

/// Manila and a short Metro-Manila pan walk for the [_runDemo] flow.
const Map<String, double> _manila = {'lat': 14.5995, 'lng': 121.0219};
const List<Map<String, double>> _walk = [
  {'lat': 14.5610, 'lng': 120.9947}, // Rizal Park
  {'lat': 14.5764, 'lng': 121.0851}, // Pasig
  {'lat': 14.6537, 'lng': 121.0687}, // Quezon City
  {'lat': 14.5547, 'lng': 121.0244}, // Makati
];

/// The built-in demo: each step awaits the previous, so timing follows the real
/// camera animations; [pause] just adds breathing room so the walk is watchable.
Future<JSAny?> _runDemo(InteractionController bus, Duration pause) async {
  Future<void> go(String id, [Map<String, Object?>? payload]) =>
      bus.dispatch(id, origin: InteractionOrigin.programmatic, payload: payload);

  await _mapReady.future;

  await go(InteractionIds.mapScroll, _manila);
  await go(InteractionIds.mapZoom, {'zoom': 12.0});
  await Future<void>.delayed(pause);

  for (final p in _walk) {
    await go(InteractionIds.mapScroll, p);
    await Future<void>.delayed(pause);
  }

  await go(InteractionIds.followMeTap);
  return null;
}
