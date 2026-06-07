import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/interaction/interaction_controller.dart';
import '../../core/interaction/interaction_ids.dart';
import 'settings_controller.dart';

/// The settings page. Lives over the persistent map (Phase 5). Each control
/// dispatches its change through the interaction bus; [SettingsController] holds
/// the persisted values and this rebuilds when they change.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsController.instance;
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
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            // Long-press-to-zoom is a native-only feature (web already
            // center+zooms on a tap), so its toggle is hidden on web.
            if (!kIsWeb)
              SwitchListTile(
                title: const Text('Long-press to zoom'),
                subtitle: const Text(
                    'Long-press the location button to center and zoom in.'),
                value: settings.longPressZoomEnabled,
                onChanged: (v) => InteractionController.instance.dispatch(
                    InteractionIds.settingsLongPressZoomSet,
                    payload: {'enabled': v}),
              ),
            SwitchListTile(
              title: const Text('Log interaction events'),
              subtitle: const Text(
                  'Echo every interaction to the dev log (debugging).'),
              value: settings.logEventsEnabled,
              onChanged: (v) => InteractionController.instance.dispatch(
                  InteractionIds.settingsLogEventsSet, payload: {'enabled': v}),
            ),
          ],
        ),
      ),
    );
  }
}
