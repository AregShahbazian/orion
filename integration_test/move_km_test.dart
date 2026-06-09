// Proof-of-concept end-to-end test for the dev/testing strategy
// (~/ai/orion/dev/testing/prd.md).
//
// It boots the *real* app (real MapLibre map), reads the live camera centre,
// moves it a known distance through the same controller the UI/bridge use, and
// asserts the camera ended up that far away. This exercises the whole stack
// in-process — no console bridge — and demonstrates the controller + ring-buffer
// pattern the PRD describes.
//
// Run: ./scripts/web/e2e.sh   (web)   ·   ./scripts/mobile/e2e.sh -d <id>  (mobile)

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:orion/app.dart';
import 'package:orion/app/router.dart';
import 'package:orion/core/interaction/console_bridge.dart';
import 'package:orion/core/interaction/interaction_controller.dart';
import 'package:orion/features/map/map_navigation_controller.dart';
import 'package:orion/features/settings/settings_controller.dart';
import 'package:orion/features/tracks/tracks_interactions.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('moveBy moves the camera centre the requested distance',
      (tester) async {
    // Mirror main()'s essential boot so the real app + map come up. This runs on
    // a real device/browser, so SharedPreferences/Drift/etc. are the real impls.
    await SettingsController.instance.load();
    registerSettingsInteractions(SettingsController.instance);
    applyEdgeToEdgeSystemUi();
    // Install the console bridge so `window.orion` is available in the E2E
    // browser window (e.g. to poke the running app during a `hold`), just like
    // the real main(). The test itself drives the controller in-process; this is
    // for the human watching.
    installInteractionConsoleBridge(
        InteractionController.instance, MapNavigationController.instance);
    registerNavInteractions(appRouter);
    registerTracksInteractions(appRouter);
    await tester.pumpWidget(const OrionApp());

    // *** Do not touch the browser window while this runs — it's automated. ***
    // Manual taps/scrolls move the camera underneath the test and corrupt the
    // measurement.
    final nav = MapNavigationController.instance;

    // Baseline: wait until the app has loaded AND the startup view has stopped
    // moving. The map reports a transient position, then flies to its real
    // default / the user's location, then tiles stream in. Rather than guess a
    // fixed delay (`orion.ready` only marks *style loaded* — the fly-to happens
    // after), poll until the camera is stable for a stretch. Deterministic and
    // self-adjusting to slow tile loads.
    final start = await _pumpUntilSettled(tester, nav);

    // Move 5 km due east (heading 90°) — same path a UI gesture/bridge call takes.
    const distanceMeters = 5000.0;
    await nav.moveBy(meters: distanceMeters, headingDegrees: 90);

    // Wait until the move animation itself has finished (camera stable again).
    final end = await _pumpUntilSettled(tester, nav);

    final moved = _haversineMeters(start.lat, start.lng, end.lat, end.lng);

    // Within 2% of the requested distance, and it went east (longitude grew).
    expect(moved, closeTo(distanceMeters, distanceMeters * 0.02));
    expect(end.lng, greaterThan(start.lng));

    // Optional watch hold: keep the final state on screen indefinitely while the
    // driver session (and so the browser window) is still open, so a human can
    // look for as long as they like and close it with Ctrl-C. Set by
    // `./scripts/web/e2e.sh hold` (→ --dart-define=ORION_E2E_HOLD=true); off by
    // default. The assertions above have already run, so the run is effectively
    // green — it just never reaches "All tests passed" until you kill it.
    const hold = bool.fromEnvironment('ORION_E2E_HOLD');
    while (hold) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}

/// Pump in 100 ms slices until the camera stops moving — non-null and unchanged
/// for [stableSlices] consecutive reads — or [timeout] elapses. The deterministic
/// "loaded and settled" / "animation finished" signal: it waits out the startup
/// fly-to and slow tiles, and returns the instant motion ends. Not
/// `pumpAndSettle` — the map schedules frames forever, so settle never returns.
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
    (a.zoom - b.zoom).abs() < 1e-4;

double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180;
