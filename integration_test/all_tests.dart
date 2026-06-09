// Aggregate entrypoint — runs every E2E suite in one `flutter drive`, so a
// single run reports all suites (each grouped by name). The e2e.sh scripts
// default their TARGET to this; pass TARGET=integration_test/<one>_test.dart to
// run just one.
//
// Adding a suite = import its `main` and add one `group(...)` line below.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'compass_reset_test.dart' as compass_reset;
import 'settings_nav_test.dart' as settings_nav;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('compass_reset', compass_reset.main);
  group('settings_nav', settings_nav.main);
}
