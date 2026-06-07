# scripts/

Dev helper scripts, grouped by target. Run from the repo root.

## `web/` — browser dev loop
- **`run.sh`** — `flutter run -d chrome` (the primary dev loop). Forwards extra args.

Driving interactions on web needs no script: the console bridge exposes
`window.orion` in the browser DevTools console —
`await orion.dispatch('hud.followMe.tap')`, `orion.logEvents(true)`,
`orion.dump()`, `orion.ids`.

## `mobile/` — on-device (Android) loop + remote control
- **`run.sh`** — `flutter run` with native/GPU log noise filtered out. Also records
  the VM Service URI to `.dart_tool/orion_vmservice` on each launch so `orion.sh`
  can find it with no copy-paste.
- **`orion.sh`** — drive the running app's interactions from your laptop, the
  native counterpart to `window.orion`. Reads the recorded URI automatically:
  ```
  ./scripts/mobile/orion.sh dump
  ./scripts/mobile/orion.sh logEvents on=true
  ./scripts/mobile/orion.sh dispatch id=map.zoom.changed payload='{"zoom":12}'
  ./scripts/mobile/orion.sh ids
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
- **`uninstall-from-zenfone.sh`** — adb uninstall from the test Zenfone.

Screenshots (`*.png`) dropped here are gitignored.
