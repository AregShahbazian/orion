/// Platform-specific console sink for [consoleLog]: browser console on web,
/// `dart:developer` on native. Selected at compile time.
library;

export 'console_io.dart' if (dart.library.js_interop) 'console_web.dart';
