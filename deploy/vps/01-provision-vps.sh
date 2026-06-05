#!/usr/bin/env bash
# RUN ON YOUR LAPTOP. Transfers the deploy files to the VPS and runs the (idempotent)
# remote setup over a single password-authenticated SSH connection, then saves the CI
# deploy key locally for 02-setup-github.sh.
#
# Creds are read from deploy/vps/deploy.conf (gitignored, contains the root password):
#   SERVER_IP / SERVER_USER / SERVER_PASSWORD [/ SERVER_SSH_PORT]
# Override the path with DEPLOY_CONF=/path/to/deploy.conf
#
# Safe to re-run.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"        # deploy/vps
deploy_dir="$(dirname "$here")"              # deploy
log() { printf '\033[1;34m[provision]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[provision] %s\033[0m\n' "$*" >&2; exit 1; }

command -v sshpass >/dev/null || die "sshpass not installed (apt install sshpass)"

DEPLOY_CONF="${DEPLOY_CONF:-$here/deploy.conf}"
[ -f "$DEPLOY_CONF" ] || die "creds file not found: $DEPLOY_CONF (copy deploy.conf.example and fill it in)"
# shellcheck disable=SC1090
source "$DEPLOY_CONF"
: "${SERVER_IP:?SERVER_IP missing in $DEPLOY_CONF}"
: "${SERVER_PASSWORD:?SERVER_PASSWORD missing in $DEPLOY_CONF}"
USER="${SERVER_USER:-root}"
PORT="${SERVER_SSH_PORT:-22}"

# Reuse one authenticated connection for every step (one auth, no re-prompts).
CTRL="/tmp/orion-vps-%r@%h:%p"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new
          -o ControlMaster=auto -o "ControlPath=$CTRL" -o ControlPersist=120
          -p "$PORT")
SCP_OPTS=(-o StrictHostKeyChecking=accept-new
          -o ControlMaster=auto -o "ControlPath=$CTRL" -o ControlPersist=120
          -P "$PORT")
ssh_()  { sshpass -p "$SERVER_PASSWORD" ssh "${SSH_OPTS[@]}" "$USER@$SERVER_IP" "$@"; }
scp_()  { sshpass -p "$SERVER_PASSWORD" scp "${SCP_OPTS[@]}" "$@"; }

log "target: $USER@$SERVER_IP:$PORT"
log "creating /root/orion on the VPS"
ssh_ 'mkdir -p /root/orion/site/web /root/orion/site/apk'

log "uploading deploy files"
scp_ "$deploy_dir/Caddyfile" "$deploy_dir/orion-web.service" \
     "$deploy_dir/gen-apk-index.sh" "$here/remote-setup.sh" \
     "$USER@$SERVER_IP:/root/orion/"

log "running remote setup (installs Caddy, starts orion-web, makes CI key)…"
ssh_ 'bash /root/orion/remote-setup.sh'

log "fetching CI private key → $here/.secrets/orion_ci"
mkdir -p "$here/.secrets"; chmod 700 "$here/.secrets"
ssh_ 'cat /root/.ssh/orion_ci' > "$here/.secrets/orion_ci"
chmod 600 "$here/.secrets/orion_ci"

# Stash connection facts for 02-setup-github.sh.
cat > "$here/.secrets/vps.env" <<EOF
VPS_HOST=$SERVER_IP
VPS_USER=$USER
VPS_PORT=$PORT
EOF

# Close the shared connection.
ssh -o "ControlPath=$CTRL" -O exit "$USER@$SERVER_IP" 2>/dev/null || true

log "VPS ready. Web app: http://$SERVER_IP:8080/web/   APK index: http://$SERVER_IP:8080/apk/"
log "next: ./deploy/vps/02-setup-github.sh   (wires the deploy key + host into GitHub)"
