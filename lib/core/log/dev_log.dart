import 'console.dart';

/// Root tag on every Orion log line.
const String kLogRoot = 'orion';

/// The one sanctioned logging call in app code. Keeps debug output structured
/// and inspectable on both platforms — collapsable/copyable in the browser
/// console on web, filterable in the DevTools Logging tab on native — and
/// consistently tagged.
///
/// [scope] is the feature area (e.g. `'map'`, `'location'`); pass `''` for
/// app-wide logs. The emitted tag is `orion` or `orion.<scope>`.
///
/// No level/filtering by design: log anything that might help future debugging.
void devLog(String scope, Object? data) {
  consoleLog(scope.isEmpty ? kLogRoot : '$kLogRoot.$scope', data);
}
