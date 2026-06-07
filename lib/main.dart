import 'package:flutter/material.dart';

import 'app.dart';
import 'core/interaction/console_bridge.dart';
import 'core/interaction/interaction_controller.dart';
import 'features/map/map_navigation_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge transparent system bars; [OrionApp] re-applies this on resume.
  applyEdgeToEdgeSystemUi();

  // Install the interaction console bridge on every build — all platforms,
  // including release/prod (`orion.dispatch/dump/logEvents/...`). No-op on
  // native until the service-extension path lands.
  installInteractionConsoleBridge(
      InteractionController.instance, MapNavigationController.instance);
  runApp(const OrionApp());
}
