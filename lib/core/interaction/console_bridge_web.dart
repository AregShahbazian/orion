import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../app/router.dart';
import '../../features/map/map_navigation_controller.dart';
import '../../features/settings/settings_controller.dart';
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
/// await orion.followMe()            // tap the location FAB (cycle follow mode)
/// await orion.resetOrientation()    // tap the compass (north-up, flat)
/// await orion.dispatch('hud.followMe.tap')                 // same, by raw id
/// await orion.dispatch('map.zoom.changed', { zoom: 12 })   // resolves when the move settles
/// orion.ids                         // → the valid interaction ids
/// orion.logEvents(true)             // start echoing each interaction to the log
/// orion.dump()                      // print the captured buffer; returns the records
/// ```
///
/// Map navigation lives under `orion.mapnav` (a [MapNavigationController]) — read
/// the live camera and make relative moves the raw ids can't express. Each move
/// reads the current center, converts heading + distance to a target, and applies
/// it:
///
/// ```js
/// orion.mapnav.camera()             // → {lat, lng, zoom, bearing, tilt} | null
/// await orion.mapnav.move(90, 5000) // move(heading°, metres): 5 km east
/// await orion.mapnav.moveKm(90, 5)  // moveKm(heading°, km): same, in km
/// await orion.mapnav.zoomBy(1)      // zoom in one level (negative = out)
/// await orion.mapnav.rotateBy(45)   // rotate 45° clockwise
/// await orion.mapnav.tiltBy(30)     // pitch 30°
/// await orion.mapnav.panTo(13.75, 100.5)   // absolute center
/// ```
///
/// Heading is compass degrees: 0 = N, 90 = E, 180 = S, 270 = W (east ≈ screen
/// "right" when north-up). [dispatch] (and the move helpers) return a Promise so
/// scripts can `await` and sequence steps; re-read `mapnav.camera()` once the map
/// settles to see the result.
///
/// Screen navigation state lives under `orion.webnav` — the router's location vs.
/// the browser URL (which `push` doesn't always rewrite):
///
/// ```js
/// orion.webnav.dump()       // → {route, name, declaredUri, canPop, stackDepth, browserUrl, browserPath}
/// orion.webnav.location()   // → the active route, e.g. "/settings"
/// await orion.webnav.to('settings')   // open a screen (name or '/settings' path)
/// await orion.webnav.back()           // close the current screen (back to the map)
/// ```
///
/// Installed on every build, all platforms including release/prod.
void installInteractionConsoleBridge(
    InteractionController bus, MapNavigationController nav) {
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

  // Named shortcuts for the common HUD taps, so callers don't hand-type the id:
  // `await orion.followMe()`, `await orion.resetOrientation()`. Each is just
  // `dispatch(id)` (origin=programmatic) and returns its Promise.
  JSPromise<JSAny?> tap(String id) {
    Future<JSAny?> run() async {
      await bus.dispatch(id, origin: InteractionOrigin.programmatic);
      return null;
    }

    return run().toJS;
  }

  // Toggle/cycle follow-me (the location FAB).
  api.setProperty(
      'followMe'.toJS, (() => tap(InteractionIds.followMeTap)).toJS);
  // Reset orientation — north-up, flat (the compass button).
  api.setProperty('resetOrientation'.toJS,
      (() => tap(InteractionIds.resetOrientationTap)).toJS);

  api.setProperty(
      'ids'.toJS, [for (final id in InteractionIds.all) id.toJS].toJS);

  // Toggle the per-event log line at runtime: `orion.logEvents(true)`. Called
  // with no arg, just reports the current state. Goes through the persisted
  // setting now, so it survives restarts like the in-app switch.
  api.setProperty('logEvents'.toJS, ((JSBoolean? on) {
    if (on != null) SettingsController.instance.setLogEventsEnabled(on.toDart);
    return SettingsController.instance.logEventsEnabled.toJS;
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

  // --- orion.mapnav: live-camera reads + relative moves (MapNavigationController).

  final mapnav = JSObject();

  // `orion.mapnav.camera()` — the live camera as a flat object, or null if the
  // map isn't ready yet.
  mapnav.setProperty('camera'.toJS, (() => nav.camera?.toMap().jsify()).toJS);

  // Each move returns a Promise resolving (best-effort to the current camera)
  // once the dispatch handler runs, so callers can `await`. Re-read camera() after
  // the map settles for the final position.
  JSPromise<JSAny?> afterMove(Future<void> move) {
    Future<JSAny?> run() async {
      await move;
      return nav.camera?.toMap().jsify();
    }

    return run().toJS;
  }

  // move(heading°, metres) / moveKm(heading°, km): travel from the current center
  // along the compass heading. 0 = N, 90 = E, 180 = S, 270 = W.
  mapnav.setProperty(
      'move'.toJS,
      ((JSNumber heading, JSNumber meters) => afterMove(nav.moveBy(
          meters: meters.toDartDouble,
          headingDegrees: heading.toDartDouble))).toJS);
  mapnav.setProperty(
      'moveKm'.toJS,
      ((JSNumber heading, JSNumber km) => afterMove(nav.moveBy(
          meters: km.toDartDouble * 1000,
          headingDegrees: heading.toDartDouble))).toJS);

  mapnav.setProperty('zoomBy'.toJS,
      ((JSNumber delta) => afterMove(nav.zoomBy(delta.toDartDouble))).toJS);
  mapnav.setProperty(
      'rotateBy'.toJS,
      ((JSNumber degrees) => afterMove(nav.rotateBy(degrees.toDartDouble)))
          .toJS);
  mapnav.setProperty('tiltBy'.toJS,
      ((JSNumber degrees) => afterMove(nav.tiltBy(degrees.toDartDouble))).toJS);
  mapnav.setProperty(
      'panTo'.toJS,
      ((JSNumber lat, JSNumber lng) =>
          afterMove(nav.panTo(lat.toDartDouble, lng.toDartDouble))).toJS);

  api.setProperty('mapnav'.toJS, mapnav);

  // --- orion.webnav: inspect/drive screen navigation. dump() shows the router's
  // state next to the browser URL side by side.

  final webnav = JSObject();

  // Router state (shared with native via routerNavState) + the browser URL.
  Map<String, Object?> navState() => {
        ...routerNavState(),
        'browserUrl': web.window.location.href,
        'browserPath': web.window.location.pathname,
      };

  // `orion.webnav.dump()` — log the nav state and return it as a JS object.
  webnav.setProperty('dump'.toJS, (() {
    final state = navState();
    web.console.log(state.jsify());
    return state.jsify();
  }).toJS);

  // `orion.webnav.location()` — the active route, e.g. "/settings" (null before
  // the first route resolves).
  webnav.setProperty(
      'location'.toJS, (() => (routerNavState()['route'] as String?)?.toJS).toJS);

  // Dispatch a known id programmatically, returning its Promise (shares the
  // origin/await wiring with the top-level orion.dispatch).
  JSPromise<JSAny?> dispatchProgrammatic(String id,
      [Map<String, Object?>? payload]) {
    Future<JSAny?> run() async {
      await bus.dispatch(id,
          origin: InteractionOrigin.programmatic, payload: payload);
      return null;
    }

    return run().toJS;
  }

  // `orion.webnav.to(screen)` — open a screen (dispatches nav.screen.open).
  // Accepts the route name ('settings') or the path ('/settings', as dump()
  // reports — the leading slash is stripped). Returns a Promise.
  webnav.setProperty('to'.toJS, ((JSString screen) {
    final s = screen.toDart.replaceFirst(RegExp(r'^/'), '');
    return dispatchProgrammatic(
        InteractionIds.navScreenOpen, {'screen': s});
  }).toJS);

  // `orion.webnav.back()` — close the current screen (dispatches nav.screen.close).
  webnav.setProperty('back'.toJS,
      (() => dispatchProgrammatic(InteractionIds.navScreenClose)).toJS);

  api.setProperty('webnav'.toJS, webnav);

  // --- orion.data: destructive data ops.

  final data = JSObject();

  // `orion.data.clearTracks()` — delete ALL stored tracks (imported or not).
  // Destructive; returns a Promise that resolves once the DB is cleared.
  data.setProperty('clearTracks'.toJS,
      (() => dispatchProgrammatic(InteractionIds.dataTracksClear)).toJS);

  api.setProperty('data'.toJS, data);

  web.window.setProperty('orion'.toJS, api);
}
