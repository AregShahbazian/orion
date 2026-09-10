# Build & deploy

Orion has no backend. "Deploying" means publishing static artifacts — the web
bundle and a sideloadable APK — to a single VPS behind Caddy, so every branch
has a live preview and every `main` push a staging build.

The pipeline is one GitHub Actions workflow, [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).
The VPS side (Caddy, provisioning, ops scripts) is documented in
[`scripts/dev/remote/edge/README.md`](../scripts/dev/remote/edge/README.md).

## What triggers what

| Push                          | Web served at   | APK served at   | Gate            |
|-------------------------------|-----------------|-----------------|-----------------|
| version tag `v*`              | `/web/`         | `/apk/`         | manual approval |
| `main`                        | `/web/staging/` | `/apk/staging/` | auto            |
| `feature/<name>`, `dev/**`    | `/web/<name>/`  | `/apk/<name>/`  | auto            |

`feature/` is stripped from the slot name (`feature/x` → `/web/x/`); `main`
maps to the reserved `staging` slot. The web and APK jobs are independent — one
failing does not block the other. Test jobs (`unit`, `web-e2e`) run on every
push but never gate a deploy: they detect, they don't prevent.

Production releases go through GitHub's `production` environment, which
requires a reviewer to approve the run before the prod jobs execute.

## Feature previews

1. Create a `feature/<name>` branch and push.
2. CI builds and deploys to `/web/<name>/` and `/apk/<name>/`.
3. Delete the branch when done — [`preview-cleanup.yml`](../.github/workflows/preview-cleanup.yml)
   removes the preview directories from the VPS automatically.

The APK directory has a generated `index.html` listing every available build,
and the site root has a landing page listing all live slots with their
deployed commit.

## APK retention and naming

- `main` (staging) and prod keep the last 3 builds; feature previews keep 1.
  Older builds are pruned after each deploy.
- Filenames are `app-<YYMMDD-HHMMSS>-<sha7>.apk` — date-first so they sort
  chronologically.
- Release APKs are debug-signed unless a keystore is supplied (see
  `android/key.properties.example`); fine for sideloading.

## Required GitHub configuration

Settings → Secrets and variables → Actions:

- Secret `VPS_SSH_KEY` — private half of the CI deploy key
- Variables `VPS_HOST`, `VPS_USER`, `VPS_PORT`

`scripts/dev/local/edge/setup-github.sh` wires these up and creates the gated
`production` environment; `scripts/dev/local/edge/setup.sh` provisions the VPS
itself (idempotent).

## Release

There is no separate release track yet — `main` is always the latest. Tagging
`vX.Y.Z` promotes that commit to the prod root once approved.
