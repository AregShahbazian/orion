import 'package:flutter/widgets.dart';

import '../core/interaction/interaction_controller.dart';
import '../core/interaction/interaction_ids.dart';

/// The **single source of truth** for screen-navigation records: every push/pop
/// on the router's `Navigator` is recorded here as `nav.screen.open`/`close`, no
/// matter what triggered it — the settings cog, the in-app back button, Android
/// system back, or a programmatic dispatch.
///
/// The navigation interaction ids are registered `record: false` (see
/// `registerNavInteractions`), so dispatching them executes the navigation but
/// does NOT log here — this observer logs the resulting push/pop instead. One
/// recorder, so there's no double entry and no timing-dependent guard/race.
///
/// (On web, browser back/forward is a declarative route rebuild and may not
/// surface as `didPop`; Android hardware back does.)
class NavInteractionObserver extends NavigatorObserver {
  NavInteractionObserver([InteractionController? interactions])
      : _interactions = interactions ?? InteractionController.instance;

  final InteractionController _interactions;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The app opening on the map (no previous route) isn't a navigation.
    if (previousRoute == null) return;
    _interactions.observe(InteractionIds.navScreenOpen,
        payload: {'screen': route.settings.name});
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _interactions.observe(InteractionIds.navScreenClose,
        payload: {'screen': route.settings.name});
  }
}
