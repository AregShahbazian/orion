#!/usr/bin/env bash
# RUN ON YOUR LAPTOP, after setup.sh. Wires the VPS deploy key + connection facts into
# the orion repo's GitHub Actions config, and creates the gated `production` environment
# so the tag→prod deploy requires manual approval from the very first tag.
#
#   Secret    VPS_SSH_KEY            (the CI private key fetched by setup.sh)
#   Variables VPS_HOST/USER/PORT
#   Env       production             (required reviewer = the authenticated dev)
#
# Override the repo with REPO=owner/name. Safe to re-run (idempotent PUT/overwrites).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
log() { printf '\033[1;34m[gh-setup]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[gh-setup] %s\033[0m\n' "$*" >&2; exit 1; }

command -v gh >/dev/null || die "gh CLI not installed"
gh auth status >/dev/null 2>&1 || die "gh not authenticated (run: gh auth login)"

KEY="$here/.secrets/orion_ci"
ENV="$here/.secrets/vps.env"
[ -f "$KEY" ] || die "missing $KEY — run ./scripts/dev/local/edge/setup.sh first"
[ -f "$ENV" ] || die "missing $ENV — run ./scripts/dev/local/edge/setup.sh first"
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

# Gated prod environment: tag→prod jobs declare `environment: production`; without a
# pre-created protected env GitHub would auto-make an UNPROTECTED one and skip the gate.
log "ensuring gated 'production' environment (required reviewer = you)"
UID_="$(gh api user --jq .id)"
if gh api -X PUT "repos/$REPO/environments/production" \
     -f "reviewers[][type]=User" -F "reviewers[][id]=$UID_" >/dev/null; then
  log "production environment requires your approval before a prod deploy"
else
  log "WARN: could not set required reviewer (org/plan may not allow it on private repos) — set it in the repo UI"
fi

log "done. push to main → staging; push a v* tag → gated prod; feature/** → preview."
