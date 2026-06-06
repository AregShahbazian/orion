#!/usr/bin/env bash
# Run the Orion app with `flutter run`, stripping known native/GPU log noise so the
# Dart logs and real errors stay readable.
#
# What gets filtered: Adreno/Qualcomm gralloc spam, EGL/GraphicBuffer allocation
# failures, libc property lookups, and the harmless MapLibre tile "Canceled"
# requests that fire when the network drops. Everything else — including native
# crashes, E/AndroidRuntime traces, and Dart exceptions — passes through.
#
# Any extra args are forwarded to `flutter run`, e.g.:
#   ./scripts/run.sh -d R8AIB700S807D3Z --release
set -euo pipefail

command -v flutter >/dev/null || { echo "flutter not found on PATH" >&2; exit 1; }

# Patterns to drop. Add to this list if new noise shows up.
NOISE='qdgralloc|AdrenoGLES|AdrenoUtils|Gralloc4|GraphicBufferAllocator|AHardwareBuffer|Mbgl-EGLConfigChooser|FeatureFlagsImplExport|Access denied finding property|getInterlacedFlag|Mbgl-HttpRequest.*Canceled'

# stdbuf keeps output line-buffered so logs stream live instead of in chunks.
stdbuf -oL -eL flutter run "$@" 2>&1 | grep --line-buffered -vE "$NOISE"
