import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: hand the browser a live JS object so DevTools renders it
/// collapsable / expandable / copyable. Keyed by [tag] because this
/// `console.log` binding takes a single argument.
void consoleLog(String tag, Object? data) {
  web.console.log(<String, Object?>{tag: data}.jsify());
}
