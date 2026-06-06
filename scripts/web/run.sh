#!/usr/bin/env bash
# Run Orion in Chrome — the primary dev loop (maplibre_gl supports web/Android/iOS
# only). Extra args are forwarded to `flutter run`, e.g. a fixed port:
#   ./scripts/web/run.sh --web-port 8080
#
# To drive interactions on web there's no companion script: the console bridge
# exposes `window.orion` in the browser DevTools console directly, e.g.
#   await orion.dispatch('hud.followMe.tap')
#   orion.logEvents(true); orion.dump(); orion.ids
set -euo pipefail

command -v flutter >/dev/null || { echo "flutter not found on PATH" >&2; exit 1; }

exec flutter run -d chrome "$@"
