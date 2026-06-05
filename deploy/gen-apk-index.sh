#!/usr/bin/env bash
# Regenerate the APK listing page (newest first, with file sizes) from whatever APKs are
# currently in the apk dir. Called by the build-and-deploy workflow over SSH after it
# uploads a new APK, so the index reflects every accumulated build.
#
#   bash gen-apk-index.sh [apk-dir]      # default: /root/orion/site/apk
set -euo pipefail
APK_DIR="${1:-/root/orion/site/apk}"
mkdir -p "$APK_DIR"
{
  echo '<!doctype html><meta charset="utf-8"><title>Orion APK builds</title>'
  echo '<h2>Orion APK builds — newest first</h2><ul>'
  for f in $(ls -t "$APK_DIR"/*.apk 2>/dev/null); do
    bn="$(basename "$f")"; sz="$(du -h "$f" | cut -f1)"
    printf '  <li><a href="%s">%s</a> &mdash; %s</li>\n' "$bn" "$bn" "$sz"
  done
  echo '</ul>'
} > "$APK_DIR/index.html"
echo "regenerated $APK_DIR/index.html"
