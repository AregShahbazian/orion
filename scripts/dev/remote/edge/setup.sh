#!/usr/bin/env bash
# Runs ON the VPS (as root). Idempotent — safe to re-run anytime against a live box;
# every step checks first, then acts, so it never harms a running system.
#
# Installs Caddy, lays out /root/orion, resolves the public HTTPS host, installs +
# (re)starts the orion-web service over HTTPS, opens ports 80/443, and generates a CI
# deploy key authorized for incoming GitHub Actions deploys + laptop ops.
#
# Expects the edge assets already copied to /root/orion/ (Caddyfile, orion-web.service,
# gen-apk-index.sh, gen-landing-index.sh, ops.sh) by the laptop orchestrator (setup.sh).
#
#   ORION_HOST=203-0-113-10.sslip.io bash setup.sh   # host explicit (laptop passes this)
#   bash setup.sh                                        # host derived from the box's IP
set -euo pipefail
log() { printf '\033[1;34m[orion-vps]\033[0m %s\n' "$*"; }

ORION=/root/orion

# --- Public host ----------------------------------------------------------------------
# Prefer an explicit ORION_HOST; otherwise derive <dashed-ipv4>.sslip.io from the box's
# first global IPv4 so a real Let's Encrypt cert can be issued (a bare IP cannot).
derive_host() {
  local ip
  ip="$(ip -4 -o route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')"
  [ -n "$ip" ] || ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [ -n "$ip" ] || { echo "" ; return; }
  echo "${ip//./-}.sslip.io"
}
ORION_HOST="${ORION_HOST:-$(derive_host)}"
[ -n "$ORION_HOST" ] || { echo "could not determine ORION_HOST (pass it explicitly)" >&2; exit 1; }
log "public host: $ORION_HOST"

# --- Caddy ----------------------------------------------------------------------------
if ! command -v caddy >/dev/null 2>&1; then
  log "installing Caddy"
  apt-get update
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update && apt-get install -y caddy
else
  log "Caddy already installed ($(caddy version | head -n1))"
fi
# The apt package auto-enables its own caddy.service on :80 — we run our own unit instead.
systemctl disable --now caddy 2>/dev/null || true

# --- Layout ---------------------------------------------------------------------------
log "laying out $ORION/site"
mkdir -p "$ORION/site/web" "$ORION/site/apk"
chmod +x "$ORION/gen-apk-index.sh" "$ORION/gen-landing-index.sh" "$ORION/ops.sh" 2>/dev/null || true
# Seed an empty APK index so /apk/ isn't a 404 before the first deploy.
[ -f "$ORION/site/apk/index.html" ] || bash "$ORION/gen-apk-index.sh" "$ORION/site/apk"

# --- Host env file (only write if changed) --------------------------------------------
ENVFILE="$ORION/orion-web.env"
NEW_ENV="ORION_HOST=$ORION_HOST"
if [ ! -f "$ENVFILE" ] || [ "$(cat "$ENVFILE")" != "$NEW_ENV" ]; then
  log "writing $ENVFILE"
  printf '%s\n' "$NEW_ENV" > "$ENVFILE"
fi

# --- Service --------------------------------------------------------------------------
log "installing orion-web.service"
cp "$ORION/orion-web.service" /etc/systemd/system/orion-web.service
systemctl daemon-reload
systemctl enable orion-web
# reload if already running (no dropped connections), else start.
if systemctl is-active --quiet orion-web; then
  systemctl reload orion-web || systemctl restart orion-web
else
  systemctl restart orion-web
fi

# --- Firewall (best-effort): HTTPS needs 80 + 443 -------------------------------------
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  log "opening ports 80,443 (ufw)"
  ufw allow 80/tcp  || true
  ufw allow 443/tcp || true
fi

# --- CI / ops deploy key --------------------------------------------------------------
KEY=/root/.ssh/orion_ci
mkdir -p /root/.ssh && chmod 700 /root/.ssh
if [ ! -f "$KEY" ]; then
  log "generating CI deploy key"
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "orion-ci" >/dev/null
fi
PUB="$(cat "$KEY.pub")"
touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
grep -qF "$PUB" /root/.ssh/authorized_keys || echo "$PUB" >> /root/.ssh/authorized_keys

# --- Report ---------------------------------------------------------------------------
sleep 0.5
log "orion-web status: $(systemctl is-active orion-web)"
log "done. https://$ORION_HOST/web/  | web root: $ORION/site  | CI key: $KEY"
log "(first cert issuance takes a few seconds; needs 80+443 reachable)"
