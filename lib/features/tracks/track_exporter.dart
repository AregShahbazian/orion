/// Deliver an exported GPX string to the user: a share sheet on mobile, a
/// browser download on web. Conditional-import (mirrors `core/log/console.dart`
/// and `core/interaction/console_bridge.dart`).
library;

export 'track_exporter_io.dart'
    if (dart.library.js_interop) 'track_exporter_web.dart';
