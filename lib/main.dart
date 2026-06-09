import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'app/router.dart';
import 'core/interaction/console_bridge.dart';
import 'core/interaction/interaction_controller.dart';
import 'core/log/dev_log.dart';
import 'features/map/map_navigation_controller.dart';
import 'features/settings/settings_controller.dart';
import 'features/tracks/tracks_interactions.dart';

Future<void> main() async {
  // Capture every uncaught error — both Flutter framework errors and anything
  // that escapes to the zone — as a single structured `orion.error` line, so a
  // failure around a freeze/crash leaves a tagged, timestamped trail instead of
  // a bare stack dump. Chain to the previous handler to keep Flutter's own
  // red-screen/console reporting.
  final priorOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    devLog('error', {
      'kind': 'flutter',
      'message': details.exceptionAsString(),
      'library': details.library,
      'stack': details.stack?.toString(),
    });
    priorOnError?.call(details);
  };

  runZonedGuarded(_run, (error, stack) {
    devLog('error', {
      'kind': 'uncaught',
      'message': error.toString(),
      'stack': stack.toString(),
    });
  });
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted settings before the first frame so the toggles (long-press
  // zoom, logEvents) are in effect from the start.
  await SettingsController.instance.load();
  registerSettingsInteractions(SettingsController.instance);

  // Edge-to-edge transparent system bars; [OrionApp] re-applies this on resume.
  applyEdgeToEdgeSystemUi();

  // Install the interaction console bridge on every build — all platforms,
  // including release/prod (`orion.dispatch/dump/logEvents/...`). No-op on
  // native until the service-extension path lands.
  installInteractionConsoleBridge(
      InteractionController.instance, MapNavigationController.instance);
  // Wire screen-navigation ids (settings cog, open/close) to the router so they
  // dispatch both ways — captured in the log and drivable from the bridges.
  registerNavInteractions(appRouter);
  // Wire the Phase 6 track ids (HUD button, import, open, export).
  registerTracksInteractions(appRouter);
  runApp(const OrionApp());
}
