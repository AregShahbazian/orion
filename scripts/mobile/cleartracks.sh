#!/usr/bin/env bash
# Delete ALL stored tracks (imported or otherwise) from the running app — the
# native counterpart of the web console's `orion.data.clearTracks()`. Dispatches
# data.tracks.clear over the VM Service via scripts/mobile/orion.sh, so it goes
# through the InteractionController and is recorded like any interaction.
#
#   ./scripts/mobile/cleartracks.sh
#
# Destructive and unconfirmed — it wipes the tracks table. Needs a debug/profile
# build (the VM Service isn't attached in release); pairs with
# scripts/mobile/run.sh (records the VM Service URI).
set -euo pipefail
here="$(dirname "$0")"

exec "$here/orion.sh" dispatch id=data.tracks.clear
