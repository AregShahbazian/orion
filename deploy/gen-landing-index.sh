#!/usr/bin/env bash
# Regenerate the root landing page that links every deployed release — the web app and the
# APK index for `main` plus each `feature/<slot>` preview. Discovered from whatever is on
# disk under the site root, so it self-heals: each deploy re-runs it and the page reflects
# every accumulated build. Rows are sorted newest-first by the most recent build's mtime
# (i.e. the latest commit deployed for that slot).
#
#   bash gen-landing-index.sh [site-dir]      # default: /root/orion/site
set -euo pipefail
SITE_DIR="${1:-/root/orion/site}"

# Newest mtime among a slot's web build + APK index, as epoch seconds (0 if neither exists).
slot_mtime() {
  local w="$1" a="$2" t=0 m
  for p in "$w" "$a"; do
    [ -e "$p" ] && { m=$(stat -c %Y "$p"); [ "$m" -gt "$t" ] && t=$m; }
  done
  echo "$t"
}

# Emit one "<mtime>\t<li>...</li>" row so the caller can sort by the leading mtime. The
# build's datetime (the mtime, in the server's local timezone) is shown on each row.
row() {
  local mtime="$1" title="$2" web="$3" apk="$4" li when=""
  [ "$mtime" -gt 0 ] && when="$(date -d "@$mtime" '+%Y-%m-%d %H:%M')"
  li="  <li><strong>$title</strong>"
  [ -n "$when" ] && li="$li &mdash; $when"
  [ -n "$web" ] && li="$li &mdash; <a href=\"$web\">web app</a>"
  [ -n "$apk" ] && li="$li &mdash; <a href=\"$apk\">APK builds</a>"
  printf '%s\t%s</li>\n' "$mtime" "$li"
}

# A branch slot is any sub-dir of web/ or apk/ that holds its own index.html (a Flutter web
# build or a generated APK index). The Flutter asset dirs (assets/canvaskit/icons) have none.
slots() {
  for base in web apk; do
    for d in "$SITE_DIR/$base"/*/; do
      [ -f "${d}index.html" ] && basename "$d"
    done
  done 2>/dev/null | sort -u
}

{
  echo '<!doctype html><meta charset="utf-8"><title>Orion releases</title>'
  echo '<h2>Orion releases</h2><ul>'
  {
    # main
    mw=""; ma=""
    [ -f "$SITE_DIR/web/index.html" ] && mw="/web/"
    [ -f "$SITE_DIR/apk/index.html" ] && ma="/apk/"
    row "$(slot_mtime "$SITE_DIR/web/index.html" "$SITE_DIR/apk/index.html")" "main" "$mw" "$ma"

    # feature slots
    for s in $(slots); do
      w=""; a=""
      [ -f "$SITE_DIR/web/$s/index.html" ] && w="/web/$s/"
      [ -f "$SITE_DIR/apk/$s/index.html" ] && a="/apk/$s/"
      row "$(slot_mtime "$SITE_DIR/web/$s/index.html" "$SITE_DIR/apk/$s")" "$s" "$w" "$a"
    done
  } | sort -t$'\t' -k1,1nr | cut -f2-      # newest mtime first, drop the sort key
  echo '</ul>'
} > "$SITE_DIR/index.html"
echo "regenerated $SITE_DIR/index.html"
