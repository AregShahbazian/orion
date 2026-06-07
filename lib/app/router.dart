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

/// Records system-initiated navigation (Android hardware/edge-swipe back) that
/// go_router pops without going through the bus. Dispatched navigation marks
/// itself (below) so it isn't double-recorded.
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
  final interactions = ic ?? InteractionController.instance;
  interactions
    ..register(InteractionIds.settingsTap, (_) {
      _navObserver.markDispatched();
      return router.push('/settings');
    })
    ..register(InteractionIds.navScreenOpen, (payload) {
      final screen = payload?['screen'] as String?;
      final path = _screenPaths[screen];
      if (path == null) {
        throw ArgumentError('Unknown screen: $screen');
      }
      _navObserver.markDispatched();
      return router.push(path);
    })
    ..register(InteractionIds.navScreenClose, (_) {
      // Only mark when we'll actually pop, else the flag would wrongly swallow
      // the next system-initiated pop.
      if (router.canPop()) {
        _navObserver.markDispatched();
        router.pop();
      }
      return null;
    });
}
