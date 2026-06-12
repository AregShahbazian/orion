#!/usr/bin/env bash
# Runs ON the VPS (as root). Routine edge operations — the on-box half; the laptop
# wrapper scripts/dev/local/edge/ops.sh SSHes in and calls this. The edge is the
# `edge` compose stack (caddy container, host networking) at /root/orion/edge.
#
#   bash ops.sh <status|start|stop|restart|reload|logs|health>
#
#   status   container state + recent log lines
#   start|stop|restart   the compose service
#   reload   apply a Caddyfile change with no dropped connections
#   logs     follow the container logs (Ctrl-C to stop)
#   health   curl the served web + apk paths (locally, over HTTPS)
set -euo pipefail
EDGE=/root/orion/edge
compose() { docker compose -f "$EDGE/compose.yml" "$@"; }
cmd="${1:-}"

case "$cmd" in
  status)
    docker ps --filter name=edge-caddy --format 'edge-caddy: {{.Status}}' | grep . \
      || echo "edge-caddy: NOT RUNNING"
    compose logs --tail 10 caddy 2>/dev/null || true
    ;;
  start)   compose up -d ;;
  stop)    compose stop ;;
  restart) compose restart ;;
  reload)
    compose exec -T caddy caddy reload \
      --config /root/orion/Caddyfile --adapter caddyfile --force
    ;;
  logs)    compose logs -f caddy ;;
  health)
    # shellcheck disable=SC1091  # generated on the box at setup time
    host="$(. /root/orion/orion-web.env 2>/dev/null; echo "${ORION_HOST:-}")"
    [ -n "$host" ] || { echo "no ORION_HOST in /root/orion/orion-web.env" >&2; exit 1; }
    for p in /web/ /apk/; do
      code="$(curl -sS -o /dev/null -w '%{http_code}' --resolve "$host:443:127.0.0.1" \
                "https://$host$p" || echo 000)"
      printf '%-6s %s\n' "$p" "$code"
    done
    ;;
  *) echo "usage: ops.sh <status|start|stop|restart|reload|logs|health>" >&2; exit 2 ;;
esac
