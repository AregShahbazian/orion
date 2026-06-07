#!/usr/bin/env bash
# Navigate the running app to a screen — dispatches nav.screen.open {screen}.
# Native counterpart of the web console's
# `orion.dispatch('nav.screen.open', {screen})`. Goes through the
# InteractionController, so it's recorded like a real navigation.
#
#   ./scripts/mobile/navto.sh settings
#
# Use scripts/mobile/orion.sh dispatch id=nav.screen.close to go back, and
# scripts/mobile/webnav.sh to read the resulting route. Needs a debug/profile
# build; pairs with scripts/mobile/run.sh (records the VM Service URI).
set -euo pipefail
cd "$(dirname "$0")/../.."

screen="${1:-}"
if [ -z "$screen" ]; then
  echo "usage: $0 <screen|/>   e.g. $0 settings   |   $0 /  (back to the map)" >&2
  exit 64
fi

# "/" means "go back to the map" — that's a pop (nav.screen.close), not a push.
if [ "$screen" = "/" ]; then
  exec dart run tool/orion_remote.dart dispatch id=nav.screen.close
fi

exec dart run tool/orion_remote.dart dispatch \
  id=nav.screen.open payload="{\"screen\":\"$screen\"}"
