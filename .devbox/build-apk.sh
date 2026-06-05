#!/usr/bin/env bash
# devbox project integration — Orion 'apk' target: release APK published to
# $SERVE_DIR/app.apk. Run by the devbox `build apk` command (or `build` for all targets).
# Needs the Android toolchain from .devbox/provision.sh (JDK 21 + Android SDK).
#
# Contract (env from devbox): $PROJECT_DIR = this repo's clone, $SERVE_DIR = served dir.

set -euo pipefail
PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR not set by devbox}"
SERVE_DIR="${SERVE_DIR:?SERVE_DIR not set by devbox}"
log() { printf '\033[1;34m[orion/build-apk]\033[0m %s\n' "$*"; }
command -v flutter >/dev/null 2>&1 || { echo "flutter not on PATH — toolchain provision didn't run?"; exit 1; }

log "building release APK (slow on first run — Gradle/Android deps)"
( cd "$PROJECT_DIR" && flutter build apk --release )

APK_SRC="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
[ -f "$APK_SRC" ] || { echo "APK not found at $APK_SRC — build failed?"; exit 1; }

mkdir -p "$SERVE_DIR"
cp -f "$APK_SRC" "$SERVE_DIR/app.apk"
log "published: $SERVE_DIR/app.apk   (run 'serve' to expose)"
