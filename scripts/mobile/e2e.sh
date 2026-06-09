#!/usr/bin/env bash
# Run the integration_test E2E suite on a connected Android device/emulator via
# `flutter drive`. Same suite as scripts/web/e2e.sh — no chromedriver needed; you
# watch the automated actions on the device screen.
#
#   ./scripts/mobile/e2e.sh                               # default device
#   ./scripts/mobile/e2e.sh -d R8AIB700S807D3Z            # pick a device
#   TARGET=integration_test/foo_test.dart ./scripts/mobile/e2e.sh
set -euo pipefail

TARGET="${TARGET:-integration_test/all_tests.dart}"

command -v flutter >/dev/null || { echo "flutter not found on PATH" >&2; exit 1; }

exec flutter drive \
  --driver=test_driver/integration_test.dart \
  --target="$TARGET" \
  --dart-define=ORION_E2E=true \
  "$@"
