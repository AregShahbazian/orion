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

/// Web: expose `window.orion` — a stable, namespaced bridge for driving and
/// inspecting the app from the browser console or a script. The namespaces mirror
/// the Dart controllers/areas behind each call; the same vocabulary is exposed on
/// native as `ext.orion.<namespace>.<call>`.
///
/// **Commands** route through the interaction bus (`bus.dispatch`, origin =
/// programmatic), so every state change is recorded in the ring buffer and
/// replayable. **Reads** call the controller/getter directly and are not recorded.
///
/// ```js
/// await orion.ready                         // resolves when the map is usable
///
/// // bus → InteractionController
/// orion.bus.ids                             // valid interaction ids (read)
/// await orion.bus.dispatch('map.zoom.changed', { zoom: 12 })
/// orion.bus.dump()                          // ring buffer records (read)
/// await orion.bus.hud.followMe()            // tap the location FAB (cycle follow)
/// await orion.bus.hud.resetOrientation()    // tap the compass (north-up, flat)
///
/// // map → MapNavigationController (live-camera reads + relative moves)
/// orion.map.camera()                        // {lat,lng,zoom,bearing,tilt} | null (read)
/// await orion.map.move(90, 5000)            // move(heading°, metres): 5 km east
/// await orion.map.moveKm(90, 5)             // moveKm(heading°, km): same
/// await orion.map.zoomBy(1)                 // +in / -out one level
/// await orion.map.rotateBy(45)              // clockwise degrees
/// await orion.map.tiltBy(30)                // pitch degrees
/// await orion.map.panTo(13.75, 100.5)       // absolute center
///
/// // settings → SettingsController
/// await orion.settings.logEvents(true)      // dispatch settings.logEvents.set
/// orion.settings.logEvents()                // current value (read)
///
/// // tracks → tracks data layer
/// await orion.tracks.clearTracks()          // delete ALL stored tracks (destructive)
///
/// // webnav → go_router
/// orion.webnav.dump()                       // {route,name,…,browserUrl} (read)
/// orion.webnav.location()                   // active route, e.g. "/settings" (read)
/// await orion.webnav.to('settings')         // open a screen
/// await orion.webnav.back()                 // close the current screen
/// ```
///
/// Heading is compass degrees: 0 = N, 90 = E, 180 = S, 270 = W. Commands return a
/// Promise so scripts can `await` and sequence; map moves resolve to the camera
/// after the move settles. A command can never throw across the interop boundary
/// — a bad call (e.g. a relative move before `ready`) warns and resolves `null`.
///
/// Installed on every build, all platforms including release/prod.
void installInteractionConsoleBridge(
    InteractionController bus, MapNavigationController nav) {
  // --- Shared wrappers: commands never throw across interop / leave an unhandled
  // rejection; reads tolerate a not-ready map/router. `body` runs INSIDE the async
  // closure, so a synchronous controller throw becomes a caught rejection.
  JSPromise<JSAny?> command(Future<JSAny?> Function() body) {
    Future<JSAny?> run() async {
      try {
        return await body();
      } catch (e) {
        web.console.warn('orion: $e'.toJS);
        return null;
      }
    }

    return run().toJS;
  }

  JSAny? read(JSAny? Function() fn) {
    try {
      return fn();
    } catch (e) {
      web.console.warn('orion: $e'.toJS);
      return null;
    }
  }

  JSPromise<JSAny?> dispatch(String id, [Map<String, Object?>? payload]) =>
      command(() async {
        await bus.dispatch(id,
            origin: InteractionOrigin.programmatic, payload: payload);
        return null;
      });

  final api = JSObject();

  // === orion.bus → InteractionController ===================================
  final busApi = JSObject();

  // bus.dispatch(id, payload?) — fire any registered id. Unknown id warns and is
  // a no-op (returns null, not a Promise).
  busApi.setProperty('dispatch'.toJS, ((JSString id, [JSAny? payload]) {
    final dartId = id.toDart;
    if (!InteractionIds.all.contains(dartId)) {
      web.console.warn(
          'orion: unknown interaction "$dartId" — see orion.bus.ids'.toJS);
      return null;
    }
    final data = payload?.dartify();
    return dispatch(
        dartId, data is Map ? data.cast<String, Object?>() : null);
  }).toJS);

  busApi.setProperty(
      'ids'.toJS, [for (final id in InteractionIds.all) id.toJS].toJS);

  // bus.dump() — log the buffer as readable lines and return the records as JS
  // objects ({id, origin, at, payload}) for inspection or replay.
  busApi.setProperty('dump'.toJS, (() => read(() {
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
      })).toJS);

  // bus.hud.* — convenience shortcuts for the common HUD taps (each just
  // dispatches its id, so it's still recorded).
  final hud = JSObject();
  hud.setProperty(
      'followMe'.toJS, (() => dispatch(InteractionIds.followMeTap)).toJS);
  hud.setProperty('resetOrientation'.toJS,
      (() => dispatch(InteractionIds.resetOrientationTap)).toJS);
  busApi.setProperty('hud'.toJS, hud);

  api.setProperty('bus'.toJS, busApi);

  // === orion.map → MapNavigationController =================================
  final mapApi = JSObject();

  // map.camera() — the live camera as a flat object, or null if not ready (read).
  mapApi.setProperty(
      'camera'.toJS, (() => read(() => nav.camera?.toMap().jsify())).toJS);

  // Each move resolves (best-effort to the current camera) once the dispatch
  // handler runs. nav.* is invoked inside `command`, so a not-ready map yields a
  // warned, resolved null rather than a raw thrown StateError.
  JSPromise<JSAny?> move(Future<void> Function() body) =>
      command(() async {
        await body();
        return nav.camera?.toMap().jsify();
      });

  mapApi.setProperty(
      'move'.toJS,
      ((JSNumber heading, JSNumber meters) => move(() => nav.moveBy(
          meters: meters.toDartDouble,
          headingDegrees: heading.toDartDouble))).toJS);
  mapApi.setProperty(
      'moveKm'.toJS,
      ((JSNumber heading, JSNumber km) => move(() => nav.moveBy(
          meters: km.toDartDouble * 1000,
          headingDegrees: heading.toDartDouble))).toJS);
  mapApi.setProperty('zoomBy'.toJS,
      ((JSNumber delta) => move(() => nav.zoomBy(delta.toDartDouble))).toJS);
  mapApi.setProperty('rotateBy'.toJS,
      ((JSNumber degrees) => move(() => nav.rotateBy(degrees.toDartDouble)))
          .toJS);
  mapApi.setProperty('tiltBy'.toJS,
      ((JSNumber degrees) => move(() => nav.tiltBy(degrees.toDartDouble))).toJS);
  mapApi.setProperty(
      'panTo'.toJS,
      ((JSNumber lat, JSNumber lng) =>
          move(() => nav.panTo(lat.toDartDouble, lng.toDartDouble))).toJS);

  api.setProperty('map'.toJS, mapApi);

  // === orion.settings → SettingsController ================================
  final settingsApi = JSObject();

  // settings.logEvents(on?) — with an arg, dispatch settings.logEvents.set (so the
  // toggle is recorded/replayable and persisted); with no arg, read the current
  // value. Returns a Promise resolving to the resulting value.
  settingsApi.setProperty('logEvents'.toJS, ((JSBoolean? on) {
    if (on == null) {
      return SettingsController.instance.logEventsEnabled.toJS;
    }
    return command(() async {
      await bus.dispatch(InteractionIds.settingsLogEventsSet,
          origin: InteractionOrigin.programmatic,
          payload: {'enabled': on.toDart});
      return SettingsController.instance.logEventsEnabled.toJS;
    });
  }).toJS);

  api.setProperty('settings'.toJS, settingsApi);

  // === orion.tracks → tracks data layer ===================================
  final tracksApi = JSObject();

  // tracks.clearTracks() — delete ALL stored tracks (imported or not). Destructive.
  tracksApi.setProperty('clearTracks'.toJS,
      (() => dispatch(InteractionIds.dataTracksClear)).toJS);

  api.setProperty('tracks'.toJS, tracksApi);

  // === orion.webnav → go_router ===========================================
  final webnavApi = JSObject();

  // Router state (shared with native via routerNavState) + the browser URL.
  Map<String, Object?> navState() => {
        ...routerNavState(),
        'browserUrl': web.window.location.href,
        'browserPath': web.window.location.pathname,
      };

  webnavApi.setProperty('dump'.toJS, (() => read(() {
        final state = navState();
        web.console.log(state.jsify());
        return state.jsify();
      })).toJS);

  webnavApi.setProperty(
      'location'.toJS,
      (() => read(() => (routerNavState()['route'] as String?)?.toJS)).toJS);

  // webnav.to(screen) — open a screen (dispatches nav.screen.open). Accepts the
  // route name ('settings') or path ('/settings'; leading slash stripped).
  webnavApi.setProperty('to'.toJS, ((JSString screen) {
    final s = screen.toDart.replaceFirst(RegExp(r'^/'), '');
    return dispatch(InteractionIds.navScreenOpen, {'screen': s});
  }).toJS);

  // webnav.back() — close the current screen (dispatches nav.screen.close).
  webnavApi.setProperty(
      'back'.toJS, (() => dispatch(InteractionIds.navScreenClose)).toJS);

  api.setProperty('webnav'.toJS, webnavApi);

  // === top-level: ready (backs no controller) =============================
  Future<JSAny?> ready() async {
    await _mapReady.future;
    return null;
  }

  api.setProperty('ready'.toJS, ready().toJS);

  web.window.setProperty('orion'.toJS, api);
}
