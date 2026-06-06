import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/interaction/console_bridge.dart';
import 'core/interaction/interaction_controller.dart';

void main() {
  // Dev-only: let interactions be fired from the browser console
  // (`orion.dispatch(...)`). No-op on native and in release builds.
  if (kDebugMode) {
    installInteractionConsoleBridge(InteractionController.instance);
  }
  runApp(const OrionApp());
}
