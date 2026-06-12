#!/usr/bin/env bash
# Runs ON the VPS (as root). Routine orion-web edge operations — the on-box half; the
# laptop wrapper scripts/dev/local/edge/ops.sh SSHes in and calls this.
#
#   bash ops.sh <status|start|stop|restart|reload|logs|health>
#
#   status   service state + recent log lines
#   start|stop|restart   systemctl the unit
#   reload   apply a Caddyfile change with no dropped connections
#   logs     follow the journal (Ctrl-C to stop)
#   health   curl the served web + apk paths (locally, over HTTPS)
set -euo pipefail
UNIT=orion-web
cmd="${1:-}"

case "$cmd" in
  status)  systemctl status "$UNIT" --no-pager ;;
  start)   systemctl start   "$UNIT" ;;
  stop)    systemctl stop    "$UNIT" ;;
  restart) systemctl restart "$UNIT" ;;
  reload)  systemctl reload  "$UNIT" ;;
  logs)    journalctl -u "$UNIT" -f ;;
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
