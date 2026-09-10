// Widget test (dev/testing strategy — widget
// category). Mounts the real SettingsScreen headless (no map, no navigation, no
// device) and verifies a toggle goes through the bus and flips persisted state:
// tap the switch → its settings.*.set interaction dispatches → SettingsController
// updates → the switch reflects the new value.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orion/features/settings/settings_controller.dart';
import 'package:orion/features/settings/settings_screen.dart';

void main() {
  testWidgets('toggling "Log interaction events" dispatches and persists',
      (tester) async {
    // Fake the on-device store, load defaults (logEvents = false), and wire the
    // toggles to the bus exactly as main() does.
    SharedPreferences.setMockInitialValues({});
    await SettingsController.instance.load();
    registerSettingsInteractions(SettingsController.instance);
    expect(SettingsController.instance.logEventsEnabled, isFalse);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    final logEvents =
        find.widgetWithText(SwitchListTile, 'Log interaction events');
    expect(logEvents, findsOneWidget);
    expect(tester.widget<SwitchListTile>(logEvents).value, isFalse);

    await tester.tap(logEvents);
    await tester.pumpAndSettle();

    // The tap dispatched settings.logEvents.set → controller flipped + persisted,
    // and the switch rebuilt to the new value.
    expect(SettingsController.instance.logEventsEnabled, isTrue);
    expect(tester.widget<SwitchListTile>(logEvents).value, isTrue);
  });
}
