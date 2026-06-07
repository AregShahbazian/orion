# Debugging Orion (web) with Playwright

How Claude drives the running web app with the Playwright MCP. When the user says
"debug with Playwright", follow this.

## Roles

- **Claude** launches the dev server and drives the browser (navigate, evaluate,
  screenshot, console bridge).
- **The user** sets the screen size. Claude does **not** call `browser_resize` —
  the user picks the viewport (e.g. via Chrome responsive view on the Playwright
  window). Calling `browser_resize` or re-navigating can override the user's
  manual viewport, so avoid it.

## Launching the dev server

Orion is a **Flutter** app, not npm. Launch the web server **without** letting
Flutter open its own browser:

```bash
flutter run -d web-server --web-port 8090
```

Run it as a background task. Wait for this line before navigating:

```
lib/main.dart is being served at http://localhost:8090
```

Notes:
- **Use `-d web-server`, not `-d chrome`.** `-d chrome` opens a *second*,
  Flutter-owned Chrome window in addition to Playwright's. `web-server` only
  serves; Playwright then opens the single window Claude controls.
- `scripts/web/run.sh` exists but uses `-d chrome` — don't use it for Playwright
  debugging (it causes the two-window problem).
- **Port 8090** is the convention here. 8080 is often taken by another local
  server (returns a directory listing, not the app). If 8090 is busy, pick the
  next free port.
- The background task may later report "completed" / "Application finished" if the
  served app session ends — re-check the port is still listening if navigation
  fails.

## Opening the app

```
browser_navigate  http://localhost:8090/
```

Page title is **"Orion"** when it's the real app (a "Directory listing for /"
title means you hit the wrong server/port).

Give the map a moment to render, then `browser_take_screenshot`. **Always save
screenshots into `.playwright-screenshots/`** (gitignored) — pass a `filename`
like `.playwright-screenshots/status.png`. Do not write images to the repo root.
The tool result may quote an `ai/playwright-mcp/...` path, but the file lands at
the path you passed — read it back from `.playwright-screenshots/`.

Flutter web paints to a **canvas**: there is no meaningful DOM/HTML to inspect.
Screenshots show the real rendered pixels (HUD buttons, positioning, etc.), but
DOM/CSS inspection and element-targeted clicks do not work.

## Driving the app — the console bridge (preferred)

The app exposes `window.orion`. Use `browser_evaluate` to call it. This is the
**reliable** way to trigger user actions:

```js
await window.orion.dispatch('hud.followMe.tap')   // fire an action by ID
window.orion.ids                                  // list known action IDs
window.orion.logEvents(true)                      // stream events to console
window.orion.dump()                               // dump current state
```

Known action IDs seen so far: `hud.followMe.tap`, `hud.resetOrientation.tap`,
`map.follow.dismissed`, `map.zoom.changed`, `map.scroll.changed`,
`map.rotate.changed`, `map.tilt.changed`.

Read console output with `browser_console_messages`.

## What did NOT work

- **Coordinate / element clicking.** `browser_click` needs a DOM element ref, but
  Flutter is a canvas — there's nothing to target. Driving raw `page.mouse.click(x, y)`
  via the unsafe runner is brittle (you must guess pixel coordinates from a
  screenshot) and was abandoned. **Use the console bridge instead.**
- **`browser_resize`** — overrides the user's manual viewport; don't use it.
