import 'dart:convert';
import 'dart:developer' as developer;

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
/// ```
///
/// Service extensions only exist where the VM Service is attached — debug and
/// profile builds. In a release AOT build these registrations are inert.
void installInteractionConsoleBridge(InteractionController bus) {
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
}

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
