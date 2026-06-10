#!/usr/bin/env bash
# Run the integration_test E2E suite in Chrome via `flutter drive`. Boots the
# real app + MapLibre map in a Chrome window you can watch, drives the suite, and
# reports pass/fail. Starts a chromedriver on :4444 if one isn't already running
# (and stops the one it started on exit).
#
#   ./scripts/web/e2e.sh                                    # the default e2e suite
#   ./scripts/web/e2e.sh hold                               # hold the window open until you Ctrl-C
#   TARGET=integration_test/foo_test.dart ./scripts/web/e2e.sh
#   ./scripts/web/e2e.sh --web-port 8080                    # extra args → flutter drive
#
# Requires chromedriver on PATH, matching your Chrome major version:
#   https://googlechromelabs.github.io/chrome-for-testing/
set -euo pipefail

TARGET="${TARGET:-integration_test/all_tests.dart}"
PORT=4444

command -v flutter >/dev/null || { echo "flutter not found on PATH" >&2; exit 1; }
command -v chromedriver >/dev/null || {
  echo "chromedriver not found on PATH — see https://googlechromelabs.github.io/chrome-for-testing/" >&2
  exit 1
}

port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; }

# Reuse a chromedriver already on $PORT; otherwise start one and stop it on exit.
if ! port_open; then
  chromedriver --port="$PORT" >/dev/null 2>&1 &
  driver_pid=$!
  trap 'kill "$driver_pid" 2>/dev/null' EXIT
  for _ in $(seq 10); do port_open && break; sleep 0.3; done
fi

# Use `-d web-server` (not `-d chrome`): Flutter only *serves* the app and
# chromedriver drives a separate Chrome at it. With `-d chrome` Flutter launches
# its own Chrome + debug service (dwds) that collides with chromedriver's, which
# kills the connection (AppConnectionException) and closes the window.
# `--no-headless` so you can watch the automated run in a real Chrome window.
# chromedriver launches Chrome headless by default with `-d web-server`. Pass
# `--headless` (it forwards after "$@", last-wins) for CI / unattended runs.
# A leading `hold` arg holds the final state on screen until you Ctrl-C (the test
# pumps indefinitely while the browser window is still open — see ORION_E2E_HOLD
# in the test). `--keep-app-running` alone doesn't help: it keeps the web server
# up but chromedriver still closes the browser. Consumed here; the rest forwards
# to flutter drive.
hold=()
[ "${1:-}" = "hold" ] && { hold=(--dart-define=ORION_E2E_HOLD=true); shift; }

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target="$TARGET" \
  --dart-define=ORION_E2E=true \
  -d web-server \
  --browser-name=chrome \
  --no-headless "${hold[@]}" "$@"
