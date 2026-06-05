#!/usr/bin/env bash
# devbox project integration — Orion 'web' target: Flutter web (release) published to
# $SERVE_DIR/web/. Run by the devbox `build web` command (or `build` for all targets).
# Independent of the Android toolchain — no JDK/Android SDK needed.
#
# Contract (env from devbox): $PROJECT_DIR = this repo's clone, $SERVE_DIR = served dir.

set -euo pipefail
PROJECT_DIR="${PROJECT_DIR:?PROJECT_DIR not set by devbox}"
SERVE_DIR="${SERVE_DIR:?SERVE_DIR not set by devbox}"
log() { printf '\033[1;34m[orion/build-web]\033[0m %s\n' "$*"; }
command -v flutter >/dev/null 2>&1 || { echo "flutter not on PATH — toolchain provision didn't run?"; exit 1; }

log "fetching dependencies (flutter pub get)"
# Self-heals the pub cache — a container recreate (down/up) or an interrupted build can
# leave packages missing, which dart2js then fails on (e.g. vector_math not found).
( cd "$PROJECT_DIR" && flutter pub get )

log "building Flutter web (release)"
# Served under /web/, so the base href must match (else assets 404 → blank page).
( cd "$PROJECT_DIR" && flutter build web --release --base-href /web/ )

WEB_SRC="$PROJECT_DIR/build/web"
[ -d "$WEB_SRC" ] || { echo "web build not found at $WEB_SRC — build failed?"; exit 1; }

mkdir -p "$SERVE_DIR"
rm -rf "$SERVE_DIR/web"; cp -r "$WEB_SRC" "$SERVE_DIR/web"
log "published: $SERVE_DIR/web/   (run 'serve' to expose at /web/)"
