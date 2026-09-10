// Web/mobile E2E for the dev/testing strategy.
//
// Waits for the app to be ready, rotates the map, confirms the rotation via a
// direct controller read, presses the real compass reset button (located by its
// interaction-id Key), and verifies the orientation snapped back to north-up.
// Mixes both worlds on purpose: drive/confirm in-process via the controller,
// but tap the actual widget so the button + its handler are exercised end-to-end.
//
// Run: ./scripts/web/e2e.sh   (web)   ·   ./scripts/mobile/e2e.sh -d <id>  (mobile)

import 'dart:math' as math;

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

  testWidgets('compass reset button restores north-up after a rotation',
      (tester) async {
    // Mirror main()'s essential boot so the real app + map come up, and install
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
    final nav = MapNavigationController.instance;

    // 1) Ready: wait until the app has loaded and the (fixed, under ORION_E2E)
    //    startup view has stopped moving. Baseline should be north-up.
    final start = await _pumpUntilSettled(tester, nav);
    expect(_bearingOffNorth(start.bearing), lessThan(1),
        reason: 'expected a north-up baseline');

    // 2) Rotate the map 45° via the controller (same path the UI/bridge use).
    await nav.rotateTo(45);
    final rotated = await _pumpUntilSettled(tester, nav);

    // 3) Confirm the rotation took (direct controller read).
    expect(rotated.bearing, closeTo(45, 1));

    // 4) Press the *real* compass reset button — it only mounts once the map is
    //    off-north, located by the same id the bus/bridge use.
    final resetButton =
        find.byKey(const ValueKey(InteractionIds.resetOrientationTap));
    expect(resetButton, findsOneWidget,
        reason: 'compass button should appear once rotated off north');
    await tester.tap(resetButton);

    // 5) Verify the reset: orientation snaps back to north-up.
    final reset = await _pumpUntilSettled(tester, nav);
    expect(_bearingOffNorth(reset.bearing), lessThan(1),
        reason: 'compass reset should restore bearing 0');
  });
}

/// Degrees off true north, handling the 0/360 wrap (359° is 1° off, not 359°).
double _bearingOffNorth(double bearing) {
  final b = bearing % 360;
  return math.min(b, 360 - b);
}

/// Pump in 100 ms slices until the camera stops moving — non-null and unchanged
/// (incl. bearing/tilt) for [stableSlices] consecutive reads — or [timeout]
/// elapses. The deterministic "loaded and settled" / "animation finished" signal:
/// it waits out the startup load and any in-flight camera animation. Not
/// pumpAndSettle — the map schedules frames forever, so settle never returns.
Future<CameraSnapshot> _pumpUntilSettled(
  WidgetTester tester,
  MapNavigationController nav, {
  Duration timeout = const Duration(seconds: 60),
  int stableSlices = 8,
}) async {
  final slices = timeout.inMilliseconds ~/ 100;
  CameraSnapshot? prev;
  var stable = 0;
  for (var i = 0; i < slices; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final c = nav.camera;
    if (c == null) {
      prev = null;
      stable = 0;
      continue;
    }
    if (prev != null && _sameCamera(c, prev)) {
      if (++stable >= stableSlices) return c;
    } else {
      stable = 0;
    }
    prev = c;
  }
  throw StateError('camera never settled within $timeout');
}

bool _sameCamera(CameraSnapshot a, CameraSnapshot b) =>
    (a.lat - b.lat).abs() < 1e-7 &&
    (a.lng - b.lng).abs() < 1e-7 &&
    (a.zoom - b.zoom).abs() < 1e-4 &&
    (a.bearing - b.bearing).abs() < 1e-3 &&
    (a.tilt - b.tilt).abs() < 1e-3;
