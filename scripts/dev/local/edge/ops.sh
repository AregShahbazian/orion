#!/usr/bin/env bash
# RUN ON YOUR LAPTOP. Routine orion-web edge operations without logging into the VPS —
# a thin SSH wrapper around scripts/dev/remote/edge/ops.sh on the box.
#
#   ./scripts/dev/local/edge/ops.sh <status|start|stop|restart|reload|logs|health>
#
# Connection facts come from .secrets/vps.env (VPS_HOST/USER/PORT) and auth from the
# key .secrets/orion_ci — both produced by setup.sh. `health` is special: it curls the
# PUBLIC https://<host>/ end-to-end from the laptop (the more meaningful check).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
die() { printf '\033[1;31m[edge-ops] %s\033[0m\n' "$*" >&2; exit 1; }

cmd="${1:-}"
case "$cmd" in status|start|stop|restart|reload|logs|health) ;; *)
  echo "usage: ops.sh <status|start|stop|restart|reload|logs|health>" >&2; exit 2 ;;
esac

KEY="$here/.secrets/orion_ci"
ENV="$here/.secrets/vps.env"
[ -f "$KEY" ] || die "missing $KEY — run ./scripts/dev/local/edge/setup.sh first"
[ -f "$ENV" ] || die "missing $ENV — run ./scripts/dev/local/edge/setup.sh first"
# shellcheck disable=SC1090
source "$ENV"
: "${VPS_HOST:?VPS_HOST missing in $ENV}"
USER="${VPS_USER:-root}"
PORT="${VPS_PORT:-22}"

if [ "$cmd" = "health" ]; then
  host="${VPS_HOST//./-}.sslip.io"
  echo "curling https://$host/ (public, end-to-end)"
  for p in /web/ /apk/; do
    printf '%-6s ' "$p"
    curl -sI "https://$host$p" | head -n1 || echo "FAILED"
  done
  exit 0
fi

exec ssh -i "$KEY" -p "$PORT" \
  -o StrictHostKeyChecking=accept-new \
  "$USER@$VPS_HOST" "bash /root/orion/ops.sh $cmd"
