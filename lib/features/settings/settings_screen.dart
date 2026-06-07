import 'package:flutter/material.dart';

import '../../core/interaction/interaction_controller.dart';
import '../../core/interaction/interaction_ids.dart';

/// Phase 5 placeholder destination. Its only job is to prove navigate-away /
/// navigate-back keeps the map alive (the body is intentionally empty for now —
/// real settings arrive later). Opaque, so it covers the persistent map while
/// it stays mounted underneath.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        // Back goes through the interaction bus (no inline pop), so it's the same
        // action as the Android hardware back — both end in a pop.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => InteractionController.instance
              .dispatch(InteractionIds.navScreenClose),
        ),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
