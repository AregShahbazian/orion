#!/usr/bin/env bash
# Screen-navigation state of the running app — the native counterpart of the web
# console's `orion.webnav`. Calls ext.orion.webnav.dump (or .location) over the VM
# Service URI that scripts/mobile/run.sh recorded (same resolution as orion.sh).
#
#   ./scripts/mobile/webnav.sh            # full state: {route, name, declaredUri, canPop, stackDepth}
#   ./scripts/mobile/webnav.sh location   # just the active route
#
# Needs a debug/profile build (the VM Service isn't attached in release).
set -euo pipefail
here="$(dirname "$0")"

if [ "${1:-}" = "location" ]; then
  exec "$here/orion.sh" webnav.location
fi
exec "$here/orion.sh" webnav.dump
