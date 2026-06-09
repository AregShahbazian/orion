import 'dart:convert';
import 'dart:developer' as developer;

import '../../app/router.dart';
import '../../features/map/map_navigation_controller.dart';
import '../../features/settings/settings_controller.dart';
import 'interaction.dart';
import 'interaction_controller.dart';
import 'interaction_ids.dart';

/// Native: no browser console, so there's nothing to signal readiness to. The
/// web bridge uses this to resolve `orion.ready`; here it's a no-op so the shared
/// map_screen call compiles on both platforms.
void signalMapReady() {}

/// Native: there's no browser console, so the same namespaced contract as the web
/// `window.orion` is exposed as VM service extensions. VM extensions are a flat
/// registry, so the namespace is encoded in the extension name
/// (`ext.orion.<namespace>.<call>`) — but the vocabulary matches the web bridge
/// one-to-one. Drive them from a laptop over the (USB/Wi-Fi-forwarded) VM Service
/// via `scripts/mobile/orion.sh` (`ext.orion.$cmd` accepts dotted names):
///
/// ```
/// ext.orion.bus.ids                                  // → valid interaction ids
/// ext.orion.bus.dispatch       { id, payload }       // fire one interaction
/// ext.orion.bus.dump                                 // → the captured buffer
/// ext.orion.bus.hud.followMe                         // tap the location FAB
/// ext.orion.bus.hud.resetOrientation                 // tap the compass (north-up)
/// ext.orion.map.camera                               // → the live camera | null
/// ext.orion.map.move           { meters, heading }   // relative move (0=N,90=E)
/// ext.orion.map.moveKm         { km, heading }       // relative move in km
/// ext.orion.map.zoomBy         { delta }             // relative zoom (+in/-out)
/// ext.orion.map.rotateBy       { degrees }           // relative rotate
/// ext.orion.map.tiltBy         { degrees }           // relative tilt
/// ext.orion.map.panTo          { lat, lng }          // absolute center
/// ext.orion.settings.logEvents { on }                // dispatch settings.logEvents.set
/// ext.orion.tracks.clearTracks                       // delete ALL tracks (destructive)
/// ext.orion.webnav.dump                              // → screen route + nav state
/// ext.orion.webnav.location                          // → active route only
/// ext.orion.webnav.to          { screen }            // open a screen
/// ext.orion.webnav.back                              // close the current screen
/// ```
///
/// Commands route through the interaction bus (origin = programmatic) so they're
/// recorded/replayable; reads call the controller/getter directly. A handler
/// never lets an exception escape — a bad call (map not ready, bad param) returns
/// a structured `invalidParams` error response.
///
/// Service extensions only exist where the VM Service is attached — debug and
/// profile builds. In a release AOT build these registrations are inert.
void installInteractionConsoleBridge(
    InteractionController bus, MapNavigationController nav) {
  Future<void> fire(String id, [Map<String, Object?>? payload]) => bus.dispatch(
      id,
      origin: InteractionOrigin.programmatic,
      payload: payload);

  // === bus → InteractionController ========================================
  _cmd('ext.orion.bus.ids', (_) async => {'ids': InteractionIds.all.toList()});

  _cmd('ext.orion.bus.dispatch', (params) async {
    final id = params['id'] ?? '';
    if (!InteractionIds.all.contains(id)) {
      throw 'unknown interaction "$id" — see ext.orion.bus.ids';
    }
    await fire(id, _payload(params));
    return {'dispatched': id};
  });

  _cmd('ext.orion.bus.dump', (_) async => {
        'records': [
          for (final r in bus.recent())
            {
              'id': r.id,
              'origin': r.origin.name,
              'at': r.at.toIso8601String(),
              'payload': r.payload,
            },
        ],
      });

  _cmd('ext.orion.bus.hud.followMe', (_) async {
    await fire(InteractionIds.followMeTap);
    return {'dispatched': InteractionIds.followMeTap};
  });

  _cmd('ext.orion.bus.hud.resetOrientation', (_) async {
    await fire(InteractionIds.resetOrientationTap);
    return {'dispatched': InteractionIds.resetOrientationTap};
  });

  // === map → MapNavigationController ======================================
  _cmd('ext.orion.map.camera', (_) async => {'camera': nav.camera?.toMap()});

  _cmd('ext.orion.map.move', (params) async {
    await nav.moveBy(
        meters: _double(params, 'meters'),
        headingDegrees: _double(params, 'heading'));
    return {'camera': nav.camera?.toMap()};
  });

  _cmd('ext.orion.map.moveKm', (params) async {
    await nav.moveBy(
        meters: _double(params, 'km') * 1000,
        headingDegrees: _double(params, 'heading'));
    return {'camera': nav.camera?.toMap()};
  });

  _cmd('ext.orion.map.zoomBy', (params) async {
    await nav.zoomBy(_double(params, 'delta'));
    return {'camera': nav.camera?.toMap()};
  });

  _cmd('ext.orion.map.rotateBy', (params) async {
    await nav.rotateBy(_double(params, 'degrees'));
    return {'camera': nav.camera?.toMap()};
  });

  _cmd('ext.orion.map.tiltBy', (params) async {
    await nav.tiltBy(_double(params, 'degrees'));
    return {'camera': nav.camera?.toMap()};
  });

  _cmd('ext.orion.map.panTo', (params) async {
    await nav.panTo(_double(params, 'lat'), _double(params, 'lng'));
    return {'camera': nav.camera?.toMap()};
  });

  // === settings → SettingsController ======================================
  _cmd('ext.orion.settings.logEvents', (params) async {
    // Dispatch settings.logEvents.set (recorded/replayable + persisted) instead
    // of poking SettingsController directly; no arg = read current value.
    final on = params['on'];
    if (on != null) {
      await fire(InteractionIds.settingsLogEventsSet, {'enabled': on == 'true'});
    }
    return {'logEvents': SettingsController.instance.logEventsEnabled};
  });

  // === tracks → tracks data layer =========================================
  _cmd('ext.orion.tracks.clearTracks', (_) async {
    await fire(InteractionIds.dataTracksClear);
    return {'dispatched': InteractionIds.dataTracksClear};
  });

  // === webnav → go_router =================================================
  // Shared with the web bridge via routerNavState() (no browser URL on native).
  _cmd('ext.orion.webnav.dump', (_) async => routerNavState());
  _cmd('ext.orion.webnav.location',
      (_) async => {'route': routerNavState()['route']});

  _cmd('ext.orion.webnav.to', (params) async {
    final screen = (params['screen'] ?? '').replaceFirst(RegExp(r'^/'), '');
    await fire(InteractionIds.navScreenOpen, {'screen': screen});
    return {'dispatched': InteractionIds.navScreenOpen, 'screen': screen};
  });

  _cmd('ext.orion.webnav.back', (_) async {
    await fire(InteractionIds.navScreenClose);
    return {'dispatched': InteractionIds.navScreenClose};
  });
}

/// Parse a numeric service-extension param (all params arrive as strings).
double _double(Map<String, String> params, String key) =>
    double.parse(params[key] ?? '0');

/// `payload` arrives as a JSON string (service-extension params are all
/// strings); decode it to the map the bus expects.
Map<String, Object?>? _payload(Map<String, String> params) {
  final raw = params['payload'];
  if (raw == null || raw.isEmpty) return null;
  return (jsonDecode(raw) as Map).cast<String, Object?>();
}

developer.ServiceExtensionResponse _ok(Object? data) =>
    developer.ServiceExtensionResponse.result(jsonEncode(data));

/// Register a command handler that never lets an exception escape: any throw
/// (map not ready, bad param, decode failure) becomes a clean `invalidParams`
/// response instead of an opaque RPC failure.
void _cmd(String name,
    Future<Map<String, Object?>> Function(Map<String, String> params) body) {
  _register(name, (_, params) async {
    try {
      return _ok(await body(params));
    } catch (e) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        '$e',
      );
    }
  });
}

/// Register tolerantly: a hot restart re-runs `main` against an isolate that
/// already has the extension, which would otherwise throw.
void _register(String name, developer.ServiceExtensionHandler handler) {
  try {
    developer.registerExtension(name, handler);
  } catch (_) {
    // Already registered this isolate — fine.
  }
}
