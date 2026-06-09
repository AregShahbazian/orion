// Proof-of-concept end-to-end test for the dev/testing strategy
// (~/ai/orion/dev/testing/prd.md).
//
// It boots the *real* app (real MapLibre map), reads the live camera centre,
// moves it a known distance through the same controller the UI/bridge use, and
// asserts the camera ended up that far away. This exercises the whole stack
// in-process — no console bridge — and demonstrates the controller + ring-buffer
// pattern the PRD describes.
//
// Run (web, watch it live in Chrome):
//   chromedriver --port=4444 &
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/move_km_test.dart \
//     -d chrome
//
// Mobile: same flutter-drive invocation with `-d <device-id>`.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:orion/app.dart';
import 'package:orion/app/router.dart';
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
    registerNavInteractions(appRouter);
    registerTracksInteractions(appRouter);
    await tester.pumpWidget(const OrionApp());

    // Wait for the map to report its first camera position (it needs the style
    // loaded + a frame). Poll instead of pumpAndSettle — the map animates tiles
    // forever, so settle would time out.
    final nav = MapNavigationController.instance;
    CameraSnapshot? start;
    for (var i = 0; i < 100 && start == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      start = nav.camera;
    }
    expect(start, isNotNull, reason: 'map never reported a camera position');

    // Move 5 km due east (heading 90°) — same path a UI gesture/bridge call takes.
    const distanceMeters = 5000.0;
    await nav.moveBy(meters: distanceMeters, headingDegrees: 90);
    await tester.pump(const Duration(milliseconds: 500));

    final end = nav.camera!;
    final moved = _haversineMeters(start!.lat, start.lng, end.lat, end.lng);

    // Within 2% of the requested distance, and it went east (longitude grew).
    expect(moved, closeTo(distanceMeters, distanceMeters * 0.02));
    expect(end.lng, greaterThan(start.lng));
  });
}

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
