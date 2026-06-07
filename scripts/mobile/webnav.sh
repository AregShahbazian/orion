#!/usr/bin/env bash
# Screen-navigation state of the running app — the native counterpart of the web
# console's `orion.webnav`. Calls ext.orion.webnav over the VM Service URI that
# scripts/mobile/run.sh recorded (same resolution as scripts/mobile/orion.sh).
#
#   ./scripts/mobile/webnav.sh            # full state: {route, name, declaredUri, canPop, stackDepth}
#   ./scripts/mobile/webnav.sh location   # just the active route line
#
# Needs a debug/profile build (the VM Service isn't attached in release).
set -euo pipefail
here="$(dirname "$0")"

out=$("$here/orion.sh" webnav)
if [ "${1:-}" = "location" ]; then
  printf '%s\n' "$out" | grep '"route"'
else
  printf '%s\n' "$out"
fi
