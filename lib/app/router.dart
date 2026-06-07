import 'dart:async';

import 'package:go_router/go_router.dart';

import '../core/interaction/interaction_controller.dart';
import '../core/interaction/interaction_ids.dart';
import '../features/map/map_screen.dart';
import '../features/settings/settings_screen.dart';
import 'nav_interaction_observer.dart';

/// Maps a `nav.screen.open` payload `screen` key to its route path. The closed
/// set of navigable screens lives here next to the routes.
const Map<String, String> _screenPaths = {
  'settings': '/settings',
};

/// The single recorder of screen navigation: logs every push/pop (cog, in-app
/// back, Android system back, or programmatic) as `nav.screen.open/close`. The
/// open/close commands are registered `record: false` (below) so dispatch doesn't
/// double-log — no flag, no race.
final NavInteractionObserver _navObserver = NavInteractionObserver();

/// The app router. The map ([MapScreen]) is the home route; screens are
/// `push`ed over it. `Navigator` keeps the route beneath a pushed page alive
/// (`maintainState`), so the map — its controller, camera, follow mode, future
/// layers — is never disposed or reloaded while a screen is open (the Phase 5
/// pillar). Popping returns to the exact same live map. See
/// `ai/phase-5/navigation/design.md`.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  observers: [_navObserver],
  routes: [
    GoRoute(
      path: '/',
      name: 'map',
      builder: (context, state) => const MapScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

/// Wire the navigation interaction ids to [router] so screens open/close through
/// the [InteractionController] both ways — captured in the log and drivable
/// programmatically (web `window.orion` / native `ext.orion.*`). App-lifetime;
/// never unregistered. Call once at startup.
void registerNavInteractions(GoRouter router, [InteractionController? ic]) {
  // Navigation is logged by [NavInteractionObserver] on the resulting push/pop,
  // so the open/close commands are registered `record: false` — dispatching them
  // executes the navigation without a second log entry (the cog still records its
  // own `hud.settings.tap`). `push` returns a Future that completes only when the
  // pushed screen is *popped*, so handlers must NOT return/await it, or the
  // dispatch (and any remote RPC waiting on it) would hang until the user goes
  // back. Fire it and return immediately; the screen is shown synchronously.
  final interactions = ic ?? InteractionController.instance;
  interactions
    ..register(InteractionIds.settingsTap, (_) {
      unawaited(router.push('/settings'));
      return null;
    })
    ..register(InteractionIds.navScreenOpen, (payload) {
      final screen = payload?['screen'] as String?;
      final path = _screenPaths[screen];
      if (path == null) {
        throw ArgumentError('Unknown screen: $screen');
      }
      unawaited(router.push(path));
      return null;
    }, record: false)
    ..register(InteractionIds.navScreenClose, (_) {
      if (router.canPop()) router.pop();
      return null;
    }, record: false);
}
