// Web/mobile E2E for the dev/testing strategy (~/ai/orion/dev/testing/prd.md).
//
// Taps the real settings HUD button (found by its interaction-id Key) and
// asserts the route became /settings, then fires the platform back action (the
// Android hardware/gesture back, and the same pop go_router handles on web) and
// asserts it returned home. Route is read from appRouter — the same accessor the
// console bridge's webnav.location() exposes.
//
// MOBILE ONLY. This drives go_router navigation, which changes window.location
// and (on native-back) browser history — that breaks the flutter_driver web
// result channel under `flutter drive -d web-server` ($flutterDriverResult lost
// → hang / DriverError). It runs fine on a real device. all_tests.dart gates it
// behind `!kIsWeb`; run it directly only on mobile:
//   TARGET=integration_test/settings_nav_test.dart ./scripts/mobile/e2e.sh -d <id>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:orion/app.dart';
import 'package:orion/app/router.dart';
import 'package:orion/core/interaction/console_bridge.dart';
import 'package:orion/core/interaction/interaction_controller.dart';
import 'package:orion/core/interaction/interaction_ids.dart';
import 'package:orion/features/map/map_navigation_controller.dart';
import 'package:orion/features/settings/settings_controller.dart';
import 'package:orion/features/tracks/tracks_interactions.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings button opens /settings; native back returns home',
      (tester) async {
    // Mirror main()'s essential boot so the real app + HUD come up, and install
    // the console bridge so window.orion is available in the E2E window too.
    await SettingsController.instance.load();
    registerSettingsInteractions(SettingsController.instance);
    applyEdgeToEdgeSystemUi();
    installInteractionConsoleBridge(
        InteractionController.instance, MapNavigationController.instance);
    registerNavInteractions(appRouter);
    registerTracksInteractions(appRouter);
    await tester.pumpWidget(const OrionApp());

    // *** Do not touch the window while this runs — it's automated. ***
    final settingsButton =
        find.byKey(const ValueKey(InteractionIds.settingsTap));

    // Ready: the HUD's settings cog is mounted and we're on the home route.
    await _pumpUntil(tester, () => settingsButton.evaluate().isNotEmpty);
    expect(_route(), '/', reason: 'should start on the home (map) route');

    // 1) Tap the real settings button → open /settings.
    await tester.tap(settingsButton);
    await _pumpUntil(tester, () => _route() == '/settings');
    expect(_route(), '/settings');

    // 2) Fire the platform back action (Android hardware/gesture back; the same
    //    pop go_router handles on web) → return home.
    await tester.binding.handlePopRoute();
    await _pumpUntil(tester, () => _route() == '/');
    expect(_route(), '/');
  });
}

/// The active route, e.g. "/" or "/settings" — read from go_router, the same
/// source the console bridge's webnav exposes.
String _route() =>
    appRouter.routerDelegate.currentConfiguration.uri.toString();

/// Pump in 100 ms slices until [cond] holds or [timeout] elapses (then returns;
/// the following expect reports the actual state). Not pumpAndSettle — the map
/// platform view schedules frames forever, so settle never returns.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() cond, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final slices = timeout.inMilliseconds ~/ 100;
  for (var i = 0; i < slices && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
