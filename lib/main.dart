import 'package:flutter/material.dart';

import 'app.dart';
import 'app/router.dart';
import 'core/interaction/console_bridge.dart';
import 'core/interaction/interaction_controller.dart';
import 'features/map/map_navigation_controller.dart';
import 'features/settings/settings_controller.dart';
import 'features/tracks/tracks_interactions.dart';

Future<void> main() async {
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
