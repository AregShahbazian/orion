#!/usr/bin/env bash
# devbox project integration — Orion 'apk' target: release APK published, versioned, into
# $SERVE_DIR/apk/ (app-<sha7>-<YYMMDD-HHMMSS>.apk) with a newest-first index.html.
# Run by the devbox `build apk` command (or `build` for all targets).
# Needs the Android toolchain from .devbox/provision.sh (JDK 21 + Android SDK).
#
# Contract (env from devbox): $PROJECT_DIR = this repo's clone, $SERVE_DIR = served dir.

set -euo pipefail
PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR not set by devbox}"
SERVE_DIR="${SERVE_DIR:?SERVE_DIR not set by devbox}"
log() { printf '\033[1;34m[orion/build-apk]\033[0m %s\n' "$*"; }
command -v flutter >/dev/null 2>&1 || { echo "flutter not on PATH — toolchain provision didn't run?"; exit 1; }

log "fetching dependencies (flutter pub get)"
# Self-heals the pub cache — a container recreate (down/up) or an interrupted build can
# leave packages missing, which the build then fails on.
( cd "$PROJECT_DIR" && flutter pub get )

log "building release APK (slow on first run — Gradle/Android deps)"
( cd "$PROJECT_DIR" && flutter build apk --release )

APK_SRC="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
[ -f "$APK_SRC" ] || { echo "APK not found at $APK_SRC — build failed?"; exit 1; }

# Versioned name: app-<sha7>-<YYMMDD-HHMMSS>.apk, accumulated under $SERVE_DIR/apk/.
SHA="$(git -C "$PROJECT_DIR" rev-parse --short=7 HEAD 2>/dev/null || echo nogit)"
STAMP="$(date +%y%m%d-%H%M%S)"
APK_DIR="$SERVE_DIR/apk"
NAME="app-$SHA-$STAMP.apk"
mkdir -p "$APK_DIR"
cp -f "$APK_SRC" "$APK_DIR/$NAME"

# Regenerate the index (newest first, by mtime). /apk/ serves this as the listing page.
{
  echo '<!doctype html><meta charset="utf-8"><title>Orion APK builds</title>'
  echo '<h2>Orion APK builds — newest first</h2><ul>'
  for f in $(ls -t "$APK_DIR"/*.apk 2>/dev/null); do
    bn="$(basename "$f")"; sz="$(du -h "$f" | cut -f1)"
    printf '  <li><a href="%s">%s</a> &mdash; %s</li>\n' "$bn" "$bn" "$sz"
  done
  echo '</ul>'
} > "$APK_DIR/index.html"

log "published: $APK_DIR/$NAME   (index at /apk/ — run 'serve' to expose)"
