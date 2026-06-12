# Orion edge (VPS hosting)

One always-on **Caddy** on the VPS serves a single static tree
(`/root/orion/site/`) over **automatic HTTPS**. GitHub Actions (`.github/workflows/ci.yml`)
builds web + APK and pushes the artifacts to the VPS over SSH; the VPS needs no build
toolchain. Everything here runs **on the VPS** (as root); the laptop counterparts that
SSH in live in [`../../local/edge/`](../../local/edge).

## Environments = path slots (one Caddy, no extra services)

| Push                  | Web served at      | APK served at      | Gate            |
|-----------------------|--------------------|--------------------|-----------------|
| version tag `v*`      | `/web/`            | `/apk/`            | manual approval |
| `main`                | `/web/staging/`    | `/apk/staging/`    | auto            |
| `feature/<name>`,`dev/**` | `/web/<name>/` | `/apk/<name>/`     | auto            |

`feature/` is stripped (`feature/x` → `/web/x/`); `main` maps to the reserved
`staging` slot. Deleting a `feature/*` branch removes its preview dirs
(`preview-cleanup.yml`). Caddy serves nested paths, so adding a slot needs **no** VPS
change.

```
push ──► GitHub Actions ── build web ──► rsync ─┐
                        └─ build apk ──► scp  ──┤
                                                ▼
              VPS  /root/orion/site/{web,apk}/[<slot>/]
                                                │
                                       Caddy (HTTPS, 80+443)
                                                ▼
                 https://<ORION_HOST>/web/[<slot>/]   and   /apk/[<slot>/]
```

`<ORION_HOST>` is a free wildcard-DNS name (`<dashed-ip>.sslip.io`) that resolves to
the VPS IP so Let's Encrypt can issue a real cert (a bare IP cannot). `setup.sh`
derives it and writes `/root/orion/orion-web.env`, which `orion-web.service` feeds to
Caddy. Swap in a real domain later by setting `ORION_HOST` to it — no other change.

These files live on the VPS under `/root/orion/`: `Caddyfile`, `orion-web.service`,
`orion-web.env` (generated), `gen-apk-index.sh`, `gen-landing-index.sh`, `ops.sh`, and
the served `site/` dir.

## Setup (idempotent — safe to re-run)

Normally driven from the laptop: `../../local/edge/setup.sh` uploads these assets and
runs `setup.sh` here over SSH. To provision on the box directly:

```bash
# assets already in /root/orion/ (Caddyfile, orion-web.service, gen-*.sh, ops.sh)
ORION_HOST=203-0-113-10.sslip.io bash /root/orion/setup.sh   # host explicit
bash /root/orion/setup.sh                                       # host derived from IP
```

It installs Caddy (if absent), lays out `site/`, writes the host env, installs +
(re)starts `orion-web`, opens ports 80/443, and generates a CI deploy key authorized
in `authorized_keys`. Every step checks first, so it never harms a running system.

### Deploy key — let GitHub Actions push to the VPS

`setup.sh` creates `/root/.ssh/orion_ci` and authorizes it. The laptop
`../../local/edge/setup-github.sh` fetches the private half into GitHub
(`VPS_SSH_KEY` + `VPS_HOST/USER/PORT`) and creates the gated `production` environment.

## Ops cheatsheet

```bash
bash /root/orion/ops.sh status        # running? since when? recent logs
bash /root/orion/ops.sh start|stop|restart
bash /root/orion/ops.sh reload        # apply a Caddyfile edit, no dropped connections
bash /root/orion/ops.sh logs          # journalctl -u orion-web -f
bash /root/orion/ops.sh health        # curl the served web + apk paths (HTTPS)
```

From the laptop, the same without logging in: `../../local/edge/ops.sh <cmd>`.

## Notes
- **APK signing:** `flutter build apk --release` with no keystore uses debug signing —
  fine for sideloading. For real release builds add a keystore via GitHub Secrets.
- **First cert:** issuance takes a few seconds and needs ports 80+443 reachable.
- **History:** publishing used to run on a `devbox`; the Actions → Caddy pipeline
  replaced it. The edge tooling used to live in `deploy/` + `deploy/vps/` — now here
  and in `../../local/edge/`.
