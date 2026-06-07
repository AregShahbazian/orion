import 'dart:convert';
import 'dart:developer' as developer;

import '../../features/map/map_navigation_controller.dart';
import 'interaction.dart';
import 'interaction_controller.dart';
import 'interaction_ids.dart';

/// Native: no browser console, so there's nothing to signal readiness to. The
/// web bridge uses this to resolve `orion.ready`; here it's a no-op so the shared
/// map_screen call compiles on both platforms.
void signalMapReady() {}

/// Native: there's no browser console, so the same controls are exposed as VM
/// service extensions instead. Drive them from a laptop over the (USB- or
/// Wi-Fi-forwarded) VM Service via `scripts/mobile/orion.sh`:
///
/// ```
/// ext.orion.ids                                  // → valid interaction ids
/// ext.orion.dispatch  { id, payload }            // fire one interaction
/// ext.orion.logEvents { on }                     // toggle per-event logging
/// ext.orion.dump                                 // → the captured buffer
/// ext.orion.camera                               // → the live camera | null
/// ext.orion.moveBy    { meters, heading }        // relative move (heading 0=N,90=E)
/// ext.orion.zoomBy    { delta }                  // relative zoom (+in / -out)
/// ext.orion.rotateBy  { degrees }                // relative rotate
/// ext.orion.tiltBy    { degrees }                // relative tilt
/// ```
///
/// Service extensions only exist where the VM Service is attached — debug and
/// profile builds. In a release AOT build these registrations are inert.
void installInteractionConsoleBridge(
    InteractionController bus, MapNavigationController nav) {
  _register('ext.orion.ids', (_, _) async => _ok({'ids': InteractionIds.all.toList()}));

  _register('ext.orion.dispatch', (_, params) async {
    final id = params['id'] ?? '';
    if (!InteractionIds.all.contains(id)) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'unknown interaction "$id" — see ext.orion.ids',
      );
    }
    await bus.dispatch(id,
        origin: InteractionOrigin.programmatic, payload: _payload(params));
    return _ok({'dispatched': id});
  });

  _register('ext.orion.logEvents', (_, params) async {
    final on = params['on'];
    if (on != null) bus.logEvents = on == 'true';
    return _ok({'logEvents': bus.logEvents});
  });

  _register('ext.orion.dump', (_, _) async => _ok({
        'records': [
          for (final r in bus.recent())
            {
              'id': r.id,
              'origin': r.origin.name,
              'at': r.at.toIso8601String(),
              'payload': r.payload,
            },
        ],
      }));

  // --- Map navigation (MapNavigationController) ---

  _register('ext.orion.camera', (_, _) async => _ok({'camera': nav.camera?.toMap()}));

  _register('ext.orion.moveBy', (_, params) async {
    await nav.moveBy(
      meters: _double(params, 'meters'),
      headingDegrees: _double(params, 'heading'),
    );
    return _ok({'camera': nav.camera?.toMap()});
  });

  _register('ext.orion.zoomBy', (_, params) async {
    await nav.zoomBy(_double(params, 'delta'));
    return _ok({'camera': nav.camera?.toMap()});
  });

  _register('ext.orion.rotateBy', (_, params) async {
    await nav.rotateBy(_double(params, 'degrees'));
    return _ok({'camera': nav.camera?.toMap()});
  });

  _register('ext.orion.tiltBy', (_, params) async {
    await nav.tiltBy(_double(params, 'degrees'));
    return _ok({'camera': nav.camera?.toMap()});
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

/// Register tolerantly: a hot restart re-runs `main` against an isolate that
/// already has the extension, which would otherwise throw.
void _register(String name, developer.ServiceExtensionHandler handler) {
  try {
    developer.registerExtension(name, handler);
  } catch (_) {
    // Already registered this isolate — fine.
  }
}
