#!/usr/bin/env bash
# RUN ON YOUR LAPTOP, after 01-provision-vps.sh. Wires the VPS deploy key + connection
# facts into the orion repo's GitHub Actions config via the (already authenticated) gh CLI:
#   Secret   VPS_SSH_KEY   (the CI private key fetched by step 01)
#   Variables VPS_HOST / VPS_USER / VPS_PORT
#
# Override the repo with REPO=owner/name.  Safe to re-run (overwrites the values).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
log() { printf '\033[1;34m[gh-setup]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[gh-setup] %s\033[0m\n' "$*" >&2; exit 1; }

command -v gh >/dev/null || die "gh CLI not installed"
gh auth status >/dev/null 2>&1 || die "gh not authenticated (run: gh auth login)"

KEY="$here/.secrets/orion_ci"
ENV="$here/.secrets/vps.env"
[ -f "$KEY" ] || die "missing $KEY — run ./deploy/vps/01-provision-vps.sh first"
[ -f "$ENV" ] || die "missing $ENV — run ./deploy/vps/01-provision-vps.sh first"
# shellcheck disable=SC1090
source "$ENV"

REPO="${REPO:-$(git -C "$here" config --get remote.origin.url \
  | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')}"
[ -n "$REPO" ] || die "could not determine repo — pass REPO=owner/name"
log "repo: $REPO"

log "setting secret VPS_SSH_KEY"
gh secret   set VPS_SSH_KEY -R "$REPO" < "$KEY"
log "setting variables VPS_HOST / VPS_USER / VPS_PORT"
gh variable set VPS_HOST -R "$REPO" --body "$VPS_HOST"
gh variable set VPS_USER -R "$REPO" --body "$VPS_USER"
gh variable set VPS_PORT -R "$REPO" --body "$VPS_PORT"

log "done. GitHub is wired to deploy to $VPS_USER@$VPS_HOST:$VPS_PORT"
log "push to main (or a feature/* branch for a preview) and it will build + deploy."
