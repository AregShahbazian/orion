#!/usr/bin/env bash
# Compile the GPX parsing Web Worker to web/gpx_worker.dart.js.
#
# Web (dart2js) has no isolates, so heavy parsing runs in a real Web Worker
# instead (see lib/features/tracks/gpx_offthread_web.dart). The worker is a
# separate Dart entrypoint that flutter build/run does NOT compile — run this
# whenever the parser (lib/features/tracks/gpx_parser.dart or track_model.dart)
# changes, and commit the resulting .js. The .js is what gets served.
set -euo pipefail
cd "$(dirname "$0")/.."

dart compile js web/gpx_worker.dart -o web/gpx_worker.dart.js -O2
echo "Built web/gpx_worker.dart.js"
