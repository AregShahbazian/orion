# Orion

Mapping app.

## Architecture

Flutter app — Android and Web from one codebase (iOS deferred) — for GPS
tracking and offline maps. Offline-first, no backend. Full map in
`docs/architecture.md`; read it before non-trivial work in `lib/`. The essentials:

- **No state framework.** Hand-rolled `ChangeNotifier` singletons + one command bus.
- **`InteractionController` is the spine** (`lib/core/interaction/`). Every user
  action routes through it both ways — `dispatch` (run + record a handler) and
  `observe` (record only). It makes the app console-drivable and every flow
  auditable via a ring buffer. Never bypass it with an inline handler.
- **Map:** `maplibre_gl` (MapLibre Native on mobile, GL JS on web), OpenFreeMap
  `liberty` style, no API key.
- **Persistence:** Drift/SQLite for tracks (`lib/core/db/`), SharedPreferences for
  settings. GPX import/export lives in `lib/features/tracks/`.
- **Platform split is compile-time** via conditional imports (`_io.dart` /
  `_web.dart`), not runtime `kIsWeb` branches.
- **Layout:** `lib/core/` (db, interaction, log, ui), `lib/features/`
  (map, tracks, settings), `lib/app/` (router, observers), `main.dart` entry.

## Docs in this repo

- `README.md` — what the app is, how to run and test it, project status.
- `docs/architecture.md` — the full architecture map (read first).
- `docs/deploy.md` — CI, per-branch previews, staging/prod deploys.
- `docs/playwright-testing.md` — how to launch the web dev server and drive the
  running app with the Playwright MCP (console bridge, screenshots, what works /
  doesn't). Follow this when asked to "debug with Playwright".
- `scripts/README.md` — dev helper scripts (web/mobile run + E2E, the `orion.sh`
  remote-control bridge, edge/VPS ops).

Planning docs (PRDs, design notes, task lists, reviews, discussion summaries,
bug-investigation notes, the feature backlog) are kept outside this repo. Test
file headers refer to the "dev/testing strategy" — that is one of those
external docs; the test categories it defines are unit, widget, golden, and
end-to-end (see `README.md` → Testing).

## Rules

- **Never push unless explicitly told to.** Do not run `git push` on your own.
