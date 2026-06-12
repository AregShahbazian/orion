#!/usr/bin/env bash
# Runs ON the VPS (as root). Idempotent — safe to re-run anytime against a live box;
# every step checks first, then acts, so it never harms a running system.
#
# Provisions the CONTAINERIZED edge: installs Docker, lays out /root/orion, resolves
# the public HTTPS host, validates the merged Caddyfile, migrates off the legacy
# orion-web systemd unit (one-time, seconds of downtime), starts the `edge` compose
# stack (caddy, host networking), opens ports 80/443, and generates a CI deploy key
# authorized for incoming GitHub Actions deploys + laptop ops.
#
# Expects the edge assets already copied by the laptop orchestrator (setup.sh):
# /root/orion/{Caddyfile,gen-apk-index.sh,gen-landing-index.sh,ops.sh,setup.sh} and
# /root/orion/edge/compose.yml.
#
#   ORION_HOST=203-0-113-10.sslip.io bash setup.sh   # host explicit (laptop passes this)
#   bash setup.sh                                        # host derived from the box's IP
set -euo pipefail
log() { printf '\033[1;34m[orion-vps]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[orion-vps] %s\033[0m\n' "$*" >&2; exit 1; }

ORION=/root/orion
EDGE="$ORION/edge"
CADDY_IMAGE=caddy:2.11
compose() { docker compose -f "$EDGE/compose.yml" "$@"; }

[ -f "$EDGE/compose.yml" ] || die "$EDGE/compose.yml missing — run the laptop setup.sh"

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
[ -n "$ORION_HOST" ] || die "could not determine ORION_HOST (pass it explicitly)"
log "public host: $ORION_HOST"

# --- Docker (replaces the old apt Caddy install) ---------------------------------------
if command -v docker >/dev/null 2>&1; then
  log "docker already installed ($(docker --version))"
else
  log "installing docker (get.docker.com)"
  curl -fsSL https://get.docker.com | sh
fi
docker compose version >/dev/null 2>&1 || {
  log "installing docker compose plugin"
  apt-get update && apt-get install -y docker-compose-plugin
}
systemctl is-active --quiet docker || systemctl start docker
systemctl is-enabled --quiet docker || systemctl enable docker
# A leftover apt caddy package would fight for :80 — keep it off.
systemctl disable --now caddy 2>/dev/null || true

# --- Layout ---------------------------------------------------------------------------
log "laying out $ORION/site"
mkdir -p "$ORION/site/web" "$ORION/site/apk" "$EDGE/data" "$EDGE/config"
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

# --- Validate the merged Caddyfile (works with the edge down; siblings use this too) ---
log "validating Caddyfile ($CADDY_IMAGE)"
docker run --rm -e "ORION_HOST=$ORION_HOST" \
  -v /root/orion:/root/orion:ro -v /root/putcafe:/root/putcafe:ro \
  "$CADDY_IMAGE" caddy validate --config "$ORION/Caddyfile" --adapter caddyfile >/dev/null \
  || die "Caddyfile failed validation — edge left untouched"

# --- One-time cert migration from the legacy systemd Caddy ----------------------------
# The orion-web unit's storage was /caddy (root service, odd XDG resolution); the
# container image sets XDG_DATA_HOME=/data, so the same state belongs in data/caddy.
# /caddy stays in place as rollback.
if [ -d /caddy ] && [ ! -d "$EDGE/data/caddy" ]; then
  log "migrating Let's Encrypt state: /caddy → $EDGE/data/caddy"
  cp -a /caddy "$EDGE/data/caddy"
fi

# --- Cutover from the legacy unit (one-time; pull first to keep the gap to seconds) ----
if systemctl is-enabled --quiet orion-web 2>/dev/null || systemctl is-active --quiet orion-web 2>/dev/null; then
  log "cutover: pulling $CADDY_IMAGE before stopping the legacy unit"
  compose pull -q || true
  log "disabling legacy orion-web.service (unit file kept on the box as rollback)"
  systemctl disable --now orion-web || true
fi

# --- Edge up + reload (cheap, no dropped connections; applies config changes) ----------
log "starting the edge stack (docker compose up -d)"
compose up -d
for i in $(seq 1 10); do
  compose exec -T caddy caddy reload --config "$ORION/Caddyfile" --adapter caddyfile --force \
    >/dev/null 2>&1 && break
  [ "$i" -eq 10 ] && die "edge container did not become ready for reload"
  sleep 1
done

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
log "edge status: $(docker ps --filter name=edge-caddy --format '{{.Status}}' | grep . || echo 'NOT RUNNING')"
log "done. https://$ORION_HOST/web/  | web root: $ORION/site  | CI key: $KEY"
log "(first cert issuance takes a few seconds; needs 80+443 reachable)"
