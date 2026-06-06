#!/usr/bin/env bash
# Run the Orion app with `flutter run`, stripping known native/GPU log noise so the
# Dart logs and real errors stay readable.
#
# What gets filtered: Adreno/Qualcomm gralloc spam, EGL/GraphicBuffer allocation
# failures, libc property lookups, and the harmless MapLibre tile "Canceled"
# requests that fire when the network drops. Everything else — including native
# crashes, E/AndroidRuntime traces, and Dart exceptions — passes through.
#
# Runs on a connected device/emulator. Pairs with scripts/mobile/orion.sh, which
# drives the running app's ext.orion.* extensions using the URI recorded below.
#
# Any extra args are forwarded to `flutter run`, e.g.:
#   ./scripts/mobile/run.sh -d R8AIB700S807D3Z --release
set -euo pipefail

command -v flutter >/dev/null || { echo "flutter not found on PATH" >&2; exit 1; }

# Patterns to drop. Add to this list if new noise shows up.
NOISE='qdgralloc|AdrenoGLES|AdrenoUtils|Gralloc4|GraphicBufferAllocator|AHardwareBuffer|Mbgl-EGLConfigChooser|FeatureFlagsImplExport|Access denied finding property|getInterlacedFlag|Mbgl-HttpRequest.*Canceled'

# Where the VM Service URI is recorded so scripts/mobile/orion.sh can drive the running
# app (the ext.orion.* extensions) without copy-pasting it. Refreshed each launch.
URI_FILE=".dart_tool/orion_vmservice"
mkdir -p "$(dirname "$URI_FILE")"

# stdbuf keeps output line-buffered so logs stream live instead of in chunks. The
# read loop prints every line and, when the VM Service line appears, captures its
# URI to URI_FILE.
stdbuf -oL -eL flutter run "$@" 2>&1 \
  | grep --line-buffered -vE "$NOISE" \
  | while IFS= read -r line; do
      printf '%s\n' "$line"
      case "$line" in
        *"Dart VM Service"*"available at:"*)
          uri=$(printf '%s\n' "$line" | grep -oE 'https?://[^ ]+')
          [ -n "$uri" ] && printf '%s' "$uri" > "$URI_FILE"
          ;;
      esac
    done
