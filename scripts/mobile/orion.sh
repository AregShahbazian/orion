#!/usr/bin/env bash
# Drive the running app's ext.orion.* service extensions from your laptop without
# pasting the VM Service URI. scripts/mobile/run.sh records the URI to
# .dart_tool/orion_vmservice on each launch; this just forwards your command to
# the Dart tool, which reads that file.
#
#   ./scripts/mobile/orion.sh dump
#   ./scripts/mobile/orion.sh logEvents on=true
#   ./scripts/mobile/orion.sh dispatch id=map.zoom.changed payload='{"zoom":12}'
#   ./scripts/mobile/orion.sh ids
#
# Override the URI ad-hoc by passing it first or setting $ORION_VM.
set -euo pipefail
cd "$(dirname "$0")/../.."
exec dart run tool/orion_remote.dart "$@"
