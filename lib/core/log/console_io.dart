import 'dart:convert';
import 'dart:developer' as developer;

/// Native: no browser console, so emit indented JSON to `dart:developer`
/// (named by [tag]) — copyable and filterable in the Flutter DevTools
/// Logging tab.
void consoleLog(String tag, Object? data) {
  developer.log(
    const JsonEncoder.withIndent('  ').convert(data),
    name: tag,
  );
}
