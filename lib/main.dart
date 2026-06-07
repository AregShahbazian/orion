import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/interaction/console_bridge.dart';
import 'core/interaction/interaction_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw under the status/navigation bars and make them transparent, so the map
  // fills the screen and HUD insets are driven by SafeArea instead of an opaque
  // system bar. Nav buttons stay usable over the map.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));

  // Install the interaction console bridge on every build — all platforms,
  // including release/prod (`orion.dispatch/dump/logEvents/...`). No-op on
  // native until the service-extension path lands.
  installInteractionConsoleBridge(InteractionController.instance);
  runApp(const OrionApp());
}
