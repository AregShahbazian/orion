import 'package:flutter/widgets.dart';

import '../core/interaction/interaction_controller.dart';
import '../core/interaction/interaction_ids.dart';

/// Records screen navigation the app *observed* but didn't dispatch — most
/// importantly the **system back** (Android hardware / edge-swipe), which
/// go_router pops directly without going through the [InteractionController].
///
/// Navigation the UI or automation *dispatches* (the settings cog, the in-app
/// back button, console `nav.screen.*`) is already recorded by that dispatch, so
/// the dispatch handler calls [markDispatched] and this observer skips the
/// matching push/pop to avoid a double entry — the same guard the map uses for
/// camera moves it drives itself.
///
/// (Note: on web, browser back/forward is a declarative route rebuild and may
/// not surface as a `didPop` here; Android hardware back does.)
class NavInteractionObserver extends NavigatorObserver {
  NavInteractionObserver([InteractionController? interactions])
      : _interactions = interactions ?? InteractionController.instance;

  final InteractionController _interactions;
  bool _fromDispatch = false;

  /// Called by a dispatch handler right before it navigates, so the resulting
  /// push/pop isn't recorded a second time here.
  void markDispatched() => _fromDispatch = true;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The app opening on the map (no previous route) isn't a navigation.
    if (previousRoute == null) return;
    if (_consume()) return;
    _interactions.observe(InteractionIds.navScreenOpen,
        payload: {'screen': route.settings.name});
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_consume()) return;
    _interactions.observe(InteractionIds.navScreenClose,
        payload: {'screen': route.settings.name});
  }

  bool _consume() {
    if (_fromDispatch) {
      _fromDispatch = false;
      return true;
    }
    return false;
  }
}
