#!/usr/bin/env bash
# Navigate the running app to a screen — calls ext.orion.webnav.to {screen}.
# Native counterpart of the web console's `orion.webnav.to(screen)`. Goes through
# the InteractionController, so it's recorded like a real navigation.
#
#   ./scripts/mobile/navto.sh settings
#
# Use scripts/mobile/orion.sh webnav.back to go back, and scripts/mobile/webnav.sh
# to read the resulting route. Needs a debug/profile build; pairs with
# scripts/mobile/run.sh (records the VM Service URI).
set -euo pipefail
here="$(dirname "$0")"

screen="${1:-}"
if [ -z "$screen" ]; then
  echo "usage: $0 <screen|/>   e.g. $0 settings   |   $0 /  (back to the map)" >&2
  exit 64
fi

# "/" means "go back to the map" — that's a pop (webnav.back), not an open.
if [ "$screen" = "/" ]; then
  exec "$here/orion.sh" webnav.back
fi

exec "$here/orion.sh" webnav.to screen="$screen"
