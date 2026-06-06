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
REPO_URL="https://github.com/AregShahbazian/orion"

# Newest mtime among a slot's web build + APK index, as epoch seconds (0 if neither exists).
slot_mtime() {
  local w="$1" a="$2" t=0 m
  for p in "$w" "$a"; do
    [ -e "$p" ] && { m=$(stat -c %Y "$p"); [ "$m" -gt "$t" ] && t=$m; }
  done
  echo "$t"
}

# A slot's deployed commit sha7. The web deploy drops a `.orion-sha` marker next to the
# build; fall back to the sha7 embedded in the newest APK filename (app-<stamp>-<sha7>.apk).
slot_sha() {
  local webdir="$1" apkdir="$2" sha="" newest
  if [ -f "$webdir/.orion-sha" ]; then
    sha="$(tr -dc '0-9a-f' < "$webdir/.orion-sha" | cut -c1-7)"
  elif [ -d "$apkdir" ]; then
    newest="$(ls -t "$apkdir"/*.apk 2>/dev/null | head -1)"
    [ -n "$newest" ] && sha="$(basename "$newest" .apk | grep -oE '[0-9a-f]{7}$' || true)"
  fi
  echo "$sha"
}

# Emit one "<mtime>\t<li>...</li>" row so the caller can sort by the leading mtime. The
# build's datetime is embedded as a UTC <time> element; the inline script at the foot of the
# page rewrites it into whatever timezone the viewer's browser is in. The UTC text inside is
# the no-JS fallback.
row() {
  local mtime="$1" title="$2" web="$3" apk="$4" sha="$5" li when=""
  [ "$mtime" -gt 0 ] && when="<time data-epoch=\"$mtime\">$(date -u -d "@$mtime" '+%Y-%m-%d %H:%M UTC')</time>"
  li="  <li><strong>$title</strong>"
  [ -n "$when" ] && li="$li &mdash; $when"
  [ -n "$sha" ] && li="$li &mdash; <a href=\"$REPO_URL/commit/$sha\"><code>$sha</code></a>"
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
    row "$(slot_mtime "$SITE_DIR/web/index.html" "$SITE_DIR/apk/index.html")" "main" "$mw" "$ma" \
      "$(slot_sha "$SITE_DIR/web" "$SITE_DIR/apk")"

    # feature slots
    for s in $(slots); do
      w=""; a=""
      [ -f "$SITE_DIR/web/$s/index.html" ] && w="/web/$s/"
      [ -f "$SITE_DIR/apk/$s/index.html" ] && a="/apk/$s/"
      row "$(slot_mtime "$SITE_DIR/web/$s/index.html" "$SITE_DIR/apk/$s")" "$s" "$w" "$a" \
        "$(slot_sha "$SITE_DIR/web/$s" "$SITE_DIR/apk/$s")"
    done
  } | sort -t$'\t' -k1,1nr | cut -f2-      # newest mtime first, drop the sort key
  echo '</ul>'
  # Rewrite each UTC <time> into the viewer's local timezone, client-side.
  cat <<'HTML'
<script>
for (const el of document.querySelectorAll('time[data-epoch]')) {
  const d = new Date(el.dataset.epoch * 1000);
  el.textContent = d.toLocaleString([], {
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', timeZoneName: 'short',
  });
  el.title = d.toString();
}
</script>
HTML
} > "$SITE_DIR/index.html"
echo "regenerated $SITE_DIR/index.html"
