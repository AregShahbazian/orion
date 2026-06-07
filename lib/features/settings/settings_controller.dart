import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/interaction/interaction_controller.dart';
import '../../core/interaction/interaction_ids.dart';

/// App settings, persisted on-device via [SharedPreferences] (no backend). One
/// [ChangeNotifier] singleton the UI listens to and the features read; every
/// change is written through immediately. Loaded once at startup ([load]).
class SettingsController extends ChangeNotifier {
  SettingsController._();

  /// The app-global instance. (Private ctor — there's only one settings store.)
  static final SettingsController instance = SettingsController._();

  static const String _kLongPressZoom = 'settings.longPressZoom.enabled';
  static const String _kLogEvents = 'settings.logEvents.enabled';

  SharedPreferences? _prefs;

  bool _longPressZoomEnabled = true;

  /// Whether a long-press on the follow FAB centers + zooms (mobile). When off,
  /// the FAB behaves as it did before the feature (long-press does nothing).
  /// Default on.
  bool get longPressZoomEnabled => _longPressZoomEnabled;

  bool _logEventsEnabled = false;

  /// Whether each interaction is echoed to the dev log. Default off. The
  /// authoritative, persisted owner of [InteractionController.logEvents] — kept
  /// in sync on [load] and on change.
  bool get logEventsEnabled => _logEventsEnabled;

  /// Read persisted values (falling back to defaults) and apply the side effects
  /// (push `logEvents` into the interaction bus). Call once before `runApp`.
  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    _longPressZoomEnabled = prefs.getBool(_kLongPressZoom) ?? true;
    _logEventsEnabled = prefs.getBool(_kLogEvents) ?? false;
    InteractionController.instance.logEvents = _logEventsEnabled;
    notifyListeners();
  }

  Future<void> setLongPressZoomEnabled(bool value) async {
    if (_longPressZoomEnabled == value) return;
    _longPressZoomEnabled = value;
    await _prefs?.setBool(_kLongPressZoom, value);
    notifyListeners();
  }

  Future<void> setLogEventsEnabled(bool value) async {
    if (_logEventsEnabled == value) return;
    _logEventsEnabled = value;
    InteractionController.instance.logEvents = value;
    await _prefs?.setBool(_kLogEvents, value);
    notifyListeners();
  }
}

/// Wire the settings toggles to the interaction bus (both ways), so the switches
/// dispatch through it and they're re-dispatchable from the dev bridges
/// (`orion.dispatch('settings.logEvents.set', {enabled: true})`). Called from
/// `main`, mirroring `registerNavInteractions`.
void registerSettingsInteractions(SettingsController settings) {
  InteractionController.instance
    ..register(InteractionIds.settingsLongPressZoomSet,
        (p) => settings.setLongPressZoomEnabled(_enabled(p)))
    ..register(InteractionIds.settingsLogEventsSet,
        (p) => settings.setLogEventsEnabled(_enabled(p)));
}

bool _enabled(Map<String, Object?>? payload) => payload?['enabled'] == true;
