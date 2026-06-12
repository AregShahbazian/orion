# scripts/

Dev helper scripts, grouped by target. Run from the repo root.

## `web/` — browser dev loop
- **`run.sh`** — `flutter run -d chrome` (the primary dev loop). Forwards extra args.
- **`e2e.sh`** — run the `integration_test` E2E suite in Chrome via `flutter drive`.
  Auto-starts a chromedriver on `:4444` if one isn't running. Defaults to the
  `moveKm` POC; override with `TARGET=…`. Requires chromedriver on PATH.

Driving interactions on web needs no script: the console bridge exposes
`window.orion` in the browser DevTools console, namespaced to mirror the
controllers (`bus.*`, `map.*`, `settings.*`, `tracks.*`, `webnav.*`) —
`await orion.bus.dispatch('hud.followMe.tap')`,
`await orion.settings.logEvents(true)`, `orion.bus.dump()`, `orion.bus.ids`.

## `mobile/` — on-device (Android) loop + remote control
- **`run.sh`** — `flutter run` with native/GPU log noise filtered out. Also records
  the VM Service URI to `.dart_tool/orion_vmservice` on each launch so `orion.sh`
  can find it with no copy-paste.
- **`orion.sh`** — drive the running app's interactions from your laptop, the
  native counterpart to `window.orion`. Reads the recorded URI automatically:
  The command is the namespaced extension suffix (dotted), matching `window.orion`:
  ```
  ./scripts/mobile/orion.sh bus.dump
  ./scripts/mobile/orion.sh settings.logEvents on=true
  ./scripts/mobile/orion.sh map.move meters=5000 heading=90
  ./scripts/mobile/orion.sh bus.dispatch id=map.zoom.changed payload='{"zoom":12}'
  ./scripts/mobile/orion.sh bus.ids
  ```
  It talks to the app's `ext.orion.*` VM service extensions
  (`lib/core/interaction/console_bridge_io.dart`) over the VM Service via
  `tool/orion_remote.dart`. Everything is localhost-forwarded, so it keeps working
  across Wi-Fi/LAN switches. Service extensions exist only in debug/profile builds.
  - **`orion.sh logs`** — stream `devLog` output (the VM `Logging` stream) as
    plain lines until killed — the headless equivalent of DevTools' Logging tab,
    so you don't have to copy records out of DevTools by hand. Filter to one
    scope with `scope=`:
    ```
    ./scripts/mobile/orion.sh logs                # all orion.* records
    ./scripts/mobile/orion.sh logs scope=location # only orion.location
    ```
- **`e2e.sh`** — run the `integration_test` E2E suite on a connected device/
  emulator via `flutter drive` (no chromedriver). Same suite as `web/e2e.sh`;
  pick a device with `-d <id>`, override the target with `TARGET=…`.
- **`uninstall-from-zenfone.sh`** — adb uninstall from the test Zenfone.

Screenshots (`*.png`) dropped here are gitignored.

## `dev/` — repo / worktree + edge ops
- **`local/edge/`** — VPS edge ops run **from the laptop** (thin SSH wrappers; auth
  via the gitignored key `.secrets/orion_ci`, no manual login):
  - **`setup.sh`** — provision / re-provision the VPS edge (idempotent). Key-first;
    a brand-new box falls back to `deploy.conf` (copy `deploy.conf.example`).
  - **`setup-github.sh`** — wire the deploy key + `VPS_HOST/USER/PORT` into GitHub
    and create the gated `production` environment (tag→prod approval).
  - **`ops.sh <status|start|stop|restart|reload|logs|health>`** — drive `orion-web`
    on the box; `health` curls the public `https://<host>/` end-to-end.
- **`remote/edge/`** — the on-VPS counterparts (`setup.sh`, `ops.sh`, `Caddyfile`,
  `orion-web.service`, `gen-*.sh`) the laptop scripts call. See its
  [`README.md`](dev/remote/edge/README.md) for the hosting model + env/slot table.
- **`delete-working-tree.sh`** — remove the **current** linked worktree
  (`git/orion-*`) and drop you back in the main checkout (`git/orion`). **Source
  it** (a normal run can't cd your shell): `source scripts/dev/delete-working-tree.sh`.
  Refuses from the main checkout or a non-`orion-*` dir; uses plain `git worktree
  remove`, so it aborts on a dirty/untracked tree.
