import 'package:flutter/material.dart';

import 'app.dart';
import 'core/interaction/console_bridge.dart';
import 'core/interaction/interaction_controller.dart';

void main() {
  // Install the interaction console bridge on every build — all platforms,
  // including release/prod (`orion.dispatch/dump/logEvents/...`). No-op on
  // native until the service-extension path lands.
  installInteractionConsoleBridge(InteractionController.instance);
  runApp(const OrionApp());
}
