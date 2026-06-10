// Aggregate entrypoint — runs every E2E suite in one `flutter drive`, so a
// single run reports all suites (each grouped by name). The e2e.sh scripts
// default their TARGET to this; pass TARGET=integration_test/<one>_test.dart to
// run just one.
//
// Adding a suite = import its `main` and add one `group(...)` line below.
//
// Platform split: navigation suites that change the route (go_router updates
// window.location, and a native-back pop drives browser history) break the
// flutter_driver *web* result channel under `-d web-server`
// ($flutterDriverResult lost → hang / DriverError). They run fine on a real
// device, so they're gated behind `!kIsWeb` — web runs the web-safe suites,
// mobile runs everything.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'compass_reset_test.dart' as compass_reset;
import 'settings_nav_test.dart' as settings_nav;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Web-safe (no route/URL change).
  group('compass_reset', compass_reset.main);

  // Navigation suites — mobile only (see header).
  if (!kIsWeb) {
    group('settings_nav', settings_nav.main);
  }
}
