# Orion architecture

Orion is a Flutter app — Android, iOS, and Web from one codebase — for GPS
tracking and offline maps. This doc orients an agent (or new contributor) before
touching `lib/`. For the always-loaded summary see the `## Architecture` section
in `CLAUDE.md`.

## Big picture

- **No state-management framework.** State lives in hand-rolled `ChangeNotifier`
  singletons plus one central command bus. No BLoC/Riverpod/Provider.
- **Everything meaningful flows through the `InteractionController`** — a single
  command bus that records and dispatches every user action. This is the spine of
  the app; understand it first (see below).
- **Offline-first.** No backend. Map tiles come from a public style; tracks and
  settings live on-device.
- **Platform differences are resolved at compile time** via conditional imports,
  not runtime `kIsWeb` branches.

## Directory layout (`lib/`)

```
lib/
├── main.dart                  # entry: load settings, install bridges, register interactions, runApp
├── app.dart                   # OrionApp: MaterialApp.router + lifecycle (edge-to-edge)
├── app/
│   ├── router.dart            # go_router config; map is root, screens are child routes
│   └── nav_interaction_observer.dart  # logs every push/pop as nav.screen.open/close
├── core/
│   ├── db/app_database.dart   # Drift DB: Tracks + TrackPoints tables
│   ├── interaction/           # the command bus (see below) + dev console bridges
│   ├── log/                   # devLog facade + platform console sinks
│   └── ui/app_messenger.dart  # global ScaffoldMessenger for transient messages
└── features/
    ├── map/                   # MapLibre map screen, follow-me, HUD, location
    ├── tracks/                # GPX import/export/parse, track model, repo, screens
    └── settings/              # SharedPreferences-backed toggles + screen
```

## The InteractionController (read this first)

File: `lib/core/interaction/interaction_controller.dart`. IDs are a closed
taxonomy in `interaction_ids.dart`.

Every user action routes through this bus, **both ways**:

- **dispatch** — UI (or the dev console / automation) calls
  `interactions.dispatch(id, origin: ...)`. The bus records the interaction to a
  ~200-event ring buffer, then runs the registered handler.
- **observe** — for things the app didn't initiate (native map gestures that
  already settled): `interactions.observe(id, payload: ...)` records without
  running a handler.

Features register handlers at startup (`registerNavInteractions`,
`registerSettingsInteractions`, `registerTracksInteractions`, and map/location
handlers in `MapScreen.initState`). The same handler runs whether a tap or a
`window.orion.dispatch(...)` console call triggers it — so the app is fully
drivable from a console and every flow is auditable via the ring buffer
(`dump()` for bug reports).

**Convention:** every new user action must route through the bus (capture +
dispatch) — never wire an inline handler that bypasses it.

## Map stack

- Package: `maplibre_gl` — MapLibre Native on mobile, MapLibre GL JS on web.
- Style: OpenFreeMap `liberty` (open data, no API key). Constants in
  `features/map/map_constants.dart`.
- `MapLibreMapController` (plugin) is low-level camera/layers/gestures;
  `MapNavigationController` (app-owned singleton) wraps programmatic moves through
  the interaction bus; `LocationController` is the follow-me state machine.

## Tracks & persistence

- **Model** (`features/tracks/track_model.dart`): `ParsedTrack` →
  `List<ParsedPoint>`; `TrackStats` computed once at import and stored on the row
  so list/detail never recompute.
- **DB** (`core/db/app_database.dart`): Drift over SQLite. `Tracks` (metadata +
  stats) and `TrackPoints` (full-resolution geometry, indexed on
  `(track_id, seq)`). On web, Drift runs on WASM + OPFS (`web/sqlite3.wasm`,
  `web/drift_worker.js`).
- **Repository** (`tracks_repository.dart`): transactional import, reactive
  `watchSummaries()` stream, `getPoints`, `deleteAll`.
- **Settings**: `SharedPreferences` via `SettingsController` (no repository).

## Platform-conditional code

Pattern — a base file re-exports the platform impl:

```dart
export 'gpx_offthread_io.dart' if (dart.library.js_interop) 'gpx_offthread_web.dart';
```

Sites that use it:

| Concern        | Native (`_io`)               | Web (`_web`)                  |
|----------------|------------------------------|-------------------------------|
| GPX parsing    | `compute()` isolate          | real Web Worker (no isolates) |
| File read      | `dart:io` File               | no-op (picker yields bytes)   |
| Track export   | `share_plus` share sheet     | blob + browser download       |
| Log sink       | `dart:developer`             | browser console               |
| Console bridge | VM service ext `ext.orion.*` | `window.orion` JS API         |

## Initialization flow (`main.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `SettingsController.instance.load()` + register its interactions (before first frame — gates toggles)
3. edge-to-edge system UI
4. install console bridges (web `window.orion` / native VM service extensions)
5. register nav + tracks interactions against the router
6. `runApp(OrionApp())` — DB opens lazily on first use

## Routing

`go_router` (`app/router.dart`). The map is the **root** route and stays mounted;
`/settings`, `/tracks`, `/tracks/:id` are child routes pushed over it, so browser
back/refresh work and popping returns to the same live map. Navigation happens by
dispatching interaction IDs; `NavInteractionObserver` is the single source of
truth for nav records.

## Diagnostics

- `devLog()` structured logging — collapsible in the web console, DevTools
  Logging tab on native (see `docs/playwright-testing.md` for web debugging).
- Interaction ring buffer — `dump()` for a human-readable recent-actions trace.
