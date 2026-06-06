/// Dev-only browser-console bridge for the [InteractionController]. On web it
/// exposes `window.orion.dispatch(id, [payload])` so interactions can be fired
/// from the console as programmatic dispatches; on native it's a no-op.
/// Selected at compile time, mirroring `lib/core/log/console.dart`.
library;

export 'console_bridge_io.dart'
    if (dart.library.js_interop) 'console_bridge_web.dart';
