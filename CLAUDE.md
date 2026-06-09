# Orion

Mapping app.

## Architecture

Flutter app — Android, iOS, and Web from one codebase — for GPS tracking and
offline maps. Offline-first, no backend. Full map in `docs/architecture.md`; read
it before non-trivial work in `lib/`. The essentials:

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

## Workflow docs

Planning and workflow docs (MVP, phases, tasks, discussions, bug notes, the
feature backlog, dependency references) live in `ai/`, which resolves to
`~/ai/orion/` — not in this repo. Start there for context:

- `ai/README.md` — root overview (phases, discussions, ideas backlog).
- `ai/mvp.md` — first-release MVP definition.
- `ai/phase-<N>/<task>/` — per-task `prd.md` → `design.md` → `tasks.md` → `review.md`.
- `ai/discussions/` — dated discussion summaries.
- `ai/backlog.md` — captured feature ideas.
- `ai/bugfix/` — `.fix.md` bug investigation notes.

See `~/.claude/programming.md` for the centralized `~/ai/<repo>/` layout and rules.

## Debugging the web app

- `docs/playwright-testing.md` — how to launch the web dev server and drive the
  running app with the Playwright MCP (console bridge, screenshots, what works /
  doesn't). Follow this when asked to "debug with Playwright".

## Rules

- **Never push unless explicitly told to.** Do not run `git push` on your own.
