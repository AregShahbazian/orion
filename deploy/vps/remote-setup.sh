#!/usr/bin/env bash
# Runs ON the VPS (as root). Idempotent — safe to re-run.
# Installs Caddy, lays out /root/orion, installs+starts the orion-web service, opens the
# port, and generates a CI deploy key authorized for incoming GitHub Actions deploys.
# Expects the deploy files already copied to /root/orion/ (Caddyfile, orion-web.service,
# gen-apk-index.sh) by the laptop orchestrator.
set -euo pipefail
log() { printf '\033[1;34m[orion-vps]\033[0m %s\n' "$*"; }

ORION=/root/orion

# --- Caddy -----------------------------------------------------------------------------
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

# --- Layout ----------------------------------------------------------------------------
log "laying out $ORION/site"
mkdir -p "$ORION/site/web" "$ORION/site/apk"
chmod +x "$ORION/gen-apk-index.sh"
# Seed an empty APK index so /apk/ isn't a 404 before the first deploy.
[ -f "$ORION/site/apk/index.html" ] || bash "$ORION/gen-apk-index.sh" "$ORION/site/apk"

# --- Service ---------------------------------------------------------------------------
log "installing orion-web.service"
cp "$ORION/orion-web.service" /etc/systemd/system/orion-web.service
systemctl daemon-reload
systemctl enable orion-web
systemctl restart orion-web

# --- Firewall (best-effort) ------------------------------------------------------------
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  log "opening port 8080 (ufw)"
  ufw allow 8080/tcp || true
fi

# --- CI deploy key ---------------------------------------------------------------------
KEY=/root/.ssh/orion_ci
mkdir -p /root/.ssh && chmod 700 /root/.ssh
if [ ! -f "$KEY" ]; then
  log "generating CI deploy key"
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "orion-ci" >/dev/null
fi
PUB="$(cat "$KEY.pub")"
touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
grep -qF "$PUB" /root/.ssh/authorized_keys || echo "$PUB" >> /root/.ssh/authorized_keys

# --- Report ----------------------------------------------------------------------------
sleep 0.5
log "orion-web status: $(systemctl is-active orion-web)"
log "done. Web root: $ORION/site  | CI private key: $KEY"
