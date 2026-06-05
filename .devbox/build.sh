#!/usr/bin/env bash
# devbox project integration — Orion build: release APK + Flutter web, published to
# $SERVE_DIR as app.apk + web/. Run by the devbox `build` command (as `dev`, login shell
# → toolchain on PATH from /etc/profile.d/devbox-project.sh).
#
# Contract (env from devbox): $PROJECT_DIR = this repo's clone, $SERVE_DIR = served dir.

set -euo pipefail
PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR not set by devbox}"
SERVE_DIR="${SERVE_DIR:?SERVE_DIR not set by devbox}"
log() { printf '\033[1;34m[orion/build]\033[0m %s\n' "$*"; }
command -v flutter >/dev/null 2>&1 || { echo "flutter not on PATH — toolchain provision didn't run?"; exit 1; }

log "building release APK (slow on first run — Gradle/Android deps)"
( cd "$PROJECT_DIR" && flutter build apk --release )

log "building Flutter web (release)"
# Served under /web/, so the base href must match (else assets 404 → blank page).
( cd "$PROJECT_DIR" && flutter build web --release --base-href /web/ )

APK_SRC="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
WEB_SRC="$PROJECT_DIR/build/web"
[ -f "$APK_SRC" ] || { echo "APK not found at $APK_SRC — build failed?"; exit 1; }
[ -d "$WEB_SRC" ] || { echo "web build not found at $WEB_SRC — build failed?"; exit 1; }

mkdir -p "$SERVE_DIR"
cp -f "$APK_SRC" "$SERVE_DIR/app.apk"
rm -rf "$SERVE_DIR/web"; cp -r "$WEB_SRC" "$SERVE_DIR/web"
log "published: $SERVE_DIR/app.apk + web/   (run 'serve' to expose)"
