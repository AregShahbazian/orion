import 'package:go_router/go_router.dart';

import '../core/interaction/interaction_controller.dart';
import '../core/interaction/interaction_ids.dart';
import '../features/map/map_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tracks/track_detail_screen.dart';
import '../features/tracks/tracks_screen.dart';
import 'nav_interaction_observer.dart';

/// The single recorder of screen navigation: logs every push/pop (cog, in-app
/// back, Android system back, or programmatic) as `nav.screen.open/close`. The
/// open/close commands are registered `record: false` (below) so dispatch doesn't
/// double-log — no flag, no race.
final NavInteractionObserver _navObserver = NavInteractionObserver();

/// The app router. The map ([MapScreen]) is the `/` route and screens are its
/// **child routes**, so navigating to one (e.g. `goNamed('settings')` → URL
/// `/settings`) builds the stack `[MapScreen, SettingsScreen]`: the map (the
/// parent route) stays matched and mounted beneath the screen — never disposed or
/// reloaded — while the URL reflects the screen (deep-linkable, refresh-safe,
/// browser-back correct). Popping returns to the same live map. A screen that
/// should *drop* the map would instead be a top-level route, not a child of `/`.
/// See `ai/phase-5/navigation/design.md`.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  observers: [_navObserver],
  routes: [
    GoRoute(
      path: '/',
      name: 'map',
      builder: (context, state) => const MapScreen(),
      routes: [
        GoRoute(
          path: 'settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: 'tracks',
          name: 'tracks',
          builder: (context, state) => const TracksScreen(),
          routes: [
            GoRoute(
              path: ':id',
              name: 'trackDetail',
              // URLs are user-addressable (deep link, typed, refreshed), so a
              // non-numeric id must not reach int.parse — fall back to the list.
              redirect: (context, state) =>
                  int.tryParse(state.pathParameters['id'] ?? '') == null
                      ? '/tracks'
                      : null,
              builder: (context, state) => TrackDetailScreen(
                trackId: int.parse(state.pathParameters['id']!),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// The current screen-navigation state, shared by the web (`orion.webnav`) and
/// native (`ext.orion.webnav.*`) dev bridges so they report identically. Safe
/// before the first route resolves (returns nulls rather than throwing).
Map<String, Object?> routerNavState() {
  final cfg = appRouter.routerDelegate.currentConfiguration;
  if (cfg.matches.isEmpty) {
    return {
      'route': null,
      'name': null,
      'declaredUri': cfg.uri.toString(),
      'canPop': false,
      'stackDepth': 0,
    };
  }
  final state = appRouter.state; // topmost match — the active screen
  return {
    'route': state.matchedLocation, // e.g. /settings
    'name': state.name, // e.g. 'settings'
    'declaredUri': cfg.uri.toString(),
    'canPop': appRouter.canPop(),
    'stackDepth': cfg.matches.length,
  };
}

/// Wire the navigation interaction ids to [router] so screens open/close through
/// the [InteractionController] both ways — captured in the log and drivable
/// programmatically (web `window.orion` / native `ext.orion.*`). App-lifetime;
/// never unregistered. Call once at startup.
///
/// Navigation is logged by [NavInteractionObserver] on the resulting push/pop, so
/// the open/close commands are registered `record: false` — dispatching them
/// navigates without a second log entry (the cog still records its own
/// `hud.settings.tap`). `goNamed`/`pop` return void (unlike `push`, whose Future
/// only completes on pop), so handlers don't await.
void registerNavInteractions(GoRouter router, [InteractionController? ic]) {
  final interactions = ic ?? InteractionController.instance;
  interactions
    ..register(InteractionIds.settingsTap, (_) {
      router.goNamed('settings');
      return null;
    })
    ..register(InteractionIds.navScreenOpen, (payload) {
      final screen = payload?['screen'] as String?;
      if (screen == null) {
        throw ArgumentError('nav.screen.open requires a "screen" payload');
      }
      // Screen key == the GoRoute `name`; goNamed resolves it to the location
      // (and throws if the name is unknown).
      router.goNamed(screen);
      return null;
    }, record: false)
    ..register(InteractionIds.navScreenClose, (_) {
      if (router.canPop()) router.pop();
      return null;
    }, record: false);
}
