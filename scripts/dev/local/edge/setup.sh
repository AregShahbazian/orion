#!/usr/bin/env bash
# RUN ON YOUR LAPTOP. Provisions / re-provisions the VPS edge over one SSH connection:
# uploads the edge assets, runs the idempotent remote setup, and (first run) saves the
# CI deploy key + connection facts locally for setup-github.sh and ops.sh.
#
# Auth is key-first and safe to re-run:
#   * if .secrets/orion_ci + .secrets/vps.env exist  -> connect with the key (no password)
#   * otherwise (brand-new box)                       -> sshpass + deploy.conf password:
#       SERVER_IP / SERVER_USER / SERVER_PASSWORD [/ SERVER_SSH_PORT]
#     (copy deploy.conf.example -> deploy.conf; gitignored). Override path: DEPLOY_CONF=…
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"                  # scripts/dev/local/edge
remote_dir="$(cd "$here/../../remote/edge" && pwd)"    # scripts/dev/remote/edge (assets)
log() { printf '\033[1;34m[provision]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[provision] %s\033[0m\n' "$*" >&2; exit 1; }

mkdir -p "$here/.secrets"; chmod 700 "$here/.secrets"
KEY="$here/.secrets/orion_ci"
ENV="$here/.secrets/vps.env"

CTRL="/tmp/orion-vps-%r@%h:%p"
COMMON=(-o StrictHostKeyChecking=accept-new
        -o ControlMaster=auto -o "ControlPath=$CTRL" -o ControlPersist=120)

# Resolve connection + auth method.
FIRST_RUN=1
if [ -f "$KEY" ] && [ -f "$ENV" ]; then
  FIRST_RUN=0
  # shellcheck disable=SC1090
  source "$ENV"
  IP="$VPS_HOST"; USER="${VPS_USER:-root}"; PORT="${VPS_PORT:-22}"
  log "re-provision (key auth): $USER@$IP:$PORT"
  ssh_() { ssh -i "$KEY" "${COMMON[@]}" -p "$PORT" "$USER@$IP" "$@"; }
  scp_() { scp -i "$KEY" "${COMMON[@]}" -P "$PORT" "$@"; }
else
  command -v sshpass >/dev/null || die "sshpass not installed (apt install sshpass)"
  DEPLOY_CONF="${DEPLOY_CONF:-$here/deploy.conf}"
  [ -f "$DEPLOY_CONF" ] || die "no key yet and creds file not found: $DEPLOY_CONF (copy deploy.conf.example)"
  # shellcheck disable=SC1090
  source "$DEPLOY_CONF"
  : "${SERVER_IP:?SERVER_IP missing in $DEPLOY_CONF}"
  : "${SERVER_PASSWORD:?SERVER_PASSWORD missing in $DEPLOY_CONF}"
  IP="$SERVER_IP"; USER="${SERVER_USER:-root}"; PORT="${SERVER_SSH_PORT:-22}"
  log "first-run (password auth): $USER@$IP:$PORT"
  ssh_() { sshpass -p "$SERVER_PASSWORD" ssh "${COMMON[@]}" -p "$PORT" "$USER@$IP" "$@"; }
  scp_() { sshpass -p "$SERVER_PASSWORD" scp "${COMMON[@]}" -P "$PORT" "$@"; }
fi

ORION_HOST="${IP//./-}.sslip.io"
log "public host will be: $ORION_HOST"

log "creating /root/orion on the VPS"
ssh_ 'mkdir -p /root/orion/site/web /root/orion/site/apk'

log "uploading edge assets"
scp_ "$remote_dir/Caddyfile" "$remote_dir/orion-web.service" \
     "$remote_dir/gen-apk-index.sh" "$remote_dir/gen-landing-index.sh" \
     "$remote_dir/setup.sh" "$remote_dir/ops.sh" \
     "$USER@$IP:/root/orion/"

log "running remote setup (idempotent: Caddy, HTTPS host, orion-web, CI key)…"
ssh_ "ORION_HOST='$ORION_HOST' bash /root/orion/setup.sh"

if [ "$FIRST_RUN" -eq 1 ]; then
  log "fetching CI private key → $KEY"
  ssh_ 'cat /root/.ssh/orion_ci' > "$KEY"
  chmod 600 "$KEY"
  cat > "$ENV" <<EOF
VPS_HOST=$IP
VPS_USER=$USER
VPS_PORT=$PORT
EOF
fi

# Close the shared connection.
ssh "${COMMON[@]}" -O exit "$USER@$IP" 2>/dev/null || true

log "VPS ready → https://$ORION_HOST/web/   APK: https://$ORION_HOST/apk/"
[ "$FIRST_RUN" -eq 1 ] && log "next: ./scripts/dev/local/edge/setup-github.sh   (wires GitHub + the prod gate)"
exit 0
