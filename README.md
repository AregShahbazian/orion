# Orion

Orion is a GPS-tracking and offline-maps app for Android and the web, built with
Flutter and MapLibre. It exists because the outdoor-mapping apps I actually use
are either closed and subscription-gated or fall over on long, screen-off
recordings. Orion is offline-first and has no backend: map tiles come from an
open vector-tile style, and tracks and settings live on the device. It is also
a deliberate exercise in building a non-trivial Flutter app without a
state-management framework — one command bus, hand-rolled `ChangeNotifier`
singletons, and an architecture where every user action is recorded and
replayable.

## Features

- **Vector map** — MapLibre (Native on Android, GL JS on web) with the
  OpenFreeMap `liberty` style; open data, no API key.
- **My location and follow-me** — blue dot with heading cone and accuracy
  circle; a location button cycles Off → Follow → Follow + Heading, with
  long-press-to-zoom on native. Manual pan exits follow mode.
- **Map HUD** — shared button base for compass reset (appears on rotate or
  tilt), tracks, settings; safe-area aware, edge-to-edge system bars.
- **GPX import and export** — imports Gaia and MyTracks GPX files (multi-track
  files become one entry per track; name, description and colour preserved),
  computes stats once at import (distance, duration, avg/max speed, elevation
  gain/loss), and re-exports any track as GPX via the share sheet (Android) or
  a browser download (web).
- **Persistence** — Drift over SQLite; on web it runs on WASM + OPFS.
  Settings via SharedPreferences.
- **Offline indicator** — connectivity-aware banner.
- **Interaction bus** — every user action is dispatched through a single
  `InteractionController` and recorded to a ring buffer, so the app is fully
  drivable from a console (`window.orion` in the browser, VM-service
  extensions + `scripts/mobile/orion.sh` on Android) and every flow is
  auditable for bug reports.
- **Structured dev logging** — one `devLog(scope, data)` facade, collapsible in
  the web console and visible in the DevTools Logging tab on Android.

## Architecture

Flutter, one codebase for Android and web (iOS is not built yet). No BLoC,
Riverpod or Provider: state lives in `ChangeNotifier` singletons plus one
command bus. Platform differences are resolved at compile time via conditional
imports (`_io.dart` / `_web.dart`), never with runtime `kIsWeb` branches —
GPX parsing runs in an isolate on native and a real Web Worker on web, for
example.

```
lib/
├── main.dart, app.dart      # entry, MaterialApp.router
├── app/                     # go_router config, nav observer
├── core/
│   ├── interaction/         # the command bus + dev console bridges
│   ├── db/                  # Drift schema (Tracks, TrackPoints)
│   ├── log/                 # devLog facade + platform sinks
│   └── ui/                  # global messenger
└── features/
    ├── map/                 # map screen, follow-me, HUD, location
    ├── tracks/              # GPX parse/import/export, model, repo, screens
    └── settings/            # persisted toggles + screen
```

The full picture — the bus, the map stack, persistence, routing and the
platform split — is in [`docs/architecture.md`](docs/architecture.md).

## Running it

Prerequisites: Flutter (stable channel, Dart SDK ≥ 3.10), Chrome for web,
an Android SDK plus a device or emulator for Android.

```bash
flutter pub get

# Web (the primary dev loop)
flutter run -d chrome            # or ./scripts/web/run.sh

# Android
flutter run -d <device-id>       # or ./scripts/mobile/run.sh (filters native log noise)
```

Two generated artifacts are committed and only need rebuilding when their
sources change:

- `lib/core/db/app_database.g.dart` — `dart run build_runner build` after a
  schema change.
- `web/gpx_worker.dart.js` — `./scripts/build_web_worker.sh` after a change to
  the GPX parser or track model (the worker is a separate Dart entrypoint that
  `flutter build` does not compile).

Release APKs are debug-signed unless you provide a keystore; copy
`android/key.properties.example` to `android/key.properties` to sign properly.

## Testing

```bash
flutter test                         # unit + widget + golden
flutter test --exclude-tags golden   # what CI runs (goldens are pixel-pinned, local only)
flutter test --update-goldens        # re-pin goldens after an intentional UI change

./scripts/web/e2e.sh                 # integration_test suite in Chrome (needs chromedriver)
./scripts/mobile/e2e.sh -d <device>  # same suite on a connected Android device
```

Tests are organised by category: unit (`test/gpx_roundtrip_test.dart`, real
GPX fixtures for both supported exporters), widget
(`test/settings_screen_test.dart`, exercising the bus end to end),
golden (`test/golden/`), and end-to-end (`integration_test/`, driving the real
app through the interaction bus). `docs/playwright-testing.md` covers driving
the running web app from a browser-automation session.

CI runs the unit/widget suite and the headless web E2E suite on every push, and
builds and deploys web + APK previews per branch — see
[`docs/deploy.md`](docs/deploy.md).

## Status

Work in progress towards a first release; not on any app store. Done so far:
map shell, location and follow-me, the interaction bus and console bridges,
the shared HUD, navigation and persisted settings, GPX import/export with
local storage, and the CI/preview pipeline. Still to come for the MVP:
rendering imported tracks on the map, live track recording (including
screen-off background recording, which is the acceptance gate), and
downloading map regions for offline use.

## License

[MIT](LICENSE)
