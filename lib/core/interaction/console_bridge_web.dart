import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'interaction.dart';
import 'interaction_controller.dart';
import 'interaction_ids.dart';

/// Web: expose `window.orion` so interactions can be fired from the browser
/// console as programmatic dispatches:
///
/// ```js
/// orion.dispatch('hud.followMe.tap')
/// orion.dispatch('hud.followMe.tap', { from: 'console' })
/// orion.ids   // → the valid interaction ids
/// ```
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
      return;
    }
    final data = payload?.dartify();
    bus.dispatch(
      dartId,
      origin: InteractionOrigin.programmatic,
      payload: data is Map ? data.cast<String, Object?>() : null,
    );
  }).toJS);

  api.setProperty(
      'ids'.toJS, [for (final id in InteractionIds.all) id.toJS].toJS);

  web.window.setProperty('orion'.toJS, api);
}
