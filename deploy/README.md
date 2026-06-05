# Orion hosting (VPS + GitHub Actions)

Building and serving Orion is split from the **devbox** (which now only hosts Claude Code):

- **GitHub Actions** (`.github/workflows/build-and-deploy.yml`) builds web + APK on every
  push to `phase-1-map` and pushes the artifacts to the VPS over SSH.
- **The VPS** runs a small always-on **Caddy** server (`orion-web.service`) that serves
  those artifacts. The VPS no longer needs any build toolchain.

```
push to orion (phase-1-map)
        │
        ▼
GitHub Actions ── build web ──► rsync ─┐
              └─ build apk ──► scp  ───┤
                                       ▼
                       VPS  /root/orion/site/{web,apk}/
                                       │
                                  Caddy (:8080)
                                       ▼
                  http://<vps-ip>:8080/web/   and   /apk/
```

These four files live on the VPS under `/root/orion/`:
`Caddyfile`, `orion-web.service`, `gen-apk-index.sh`, and the served `site/` dir.

---

## One-time VPS setup

Run as root on the VPS.

```bash
# 1. Install Caddy (Debian/Ubuntu official repo)
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install -y caddy

# The apt package auto-enables its own caddy.service on :80 — disable it; we use ours.
systemctl disable --now caddy

# 2. Lay out /root/orion/  (copy the three files from this repo's deploy/ folder here)
mkdir -p /root/orion/site/web /root/orion/site/apk
#   -> place Caddyfile, gen-apk-index.sh at /root/orion/
chmod +x /root/orion/gen-apk-index.sh

# 3. Install + start the service
cp /root/orion/orion-web.service /etc/systemd/system/orion-web.service
systemctl daemon-reload
systemctl enable --now orion-web

# 4. Open the port (skip if no firewall / using a domain on 80+443)
ufw allow 8080/tcp 2>/dev/null || true
```

### Deploy key — let GitHub Actions push to the VPS

```bash
# On the VPS: create a key dedicated to CI and authorize its public half.
ssh-keygen -t ed25519 -f /root/.ssh/orion_ci -N "" -C "orion-ci"
cat /root/.ssh/orion_ci.pub >> /root/.ssh/authorized_keys
cat /root/.ssh/orion_ci          # <-- copy the PRIVATE key for the GitHub secret below
```

In the **orion** GitHub repo → Settings → Secrets and variables → Actions:

| Kind     | Name          | Value                              |
|----------|---------------|------------------------------------|
| Secret   | `VPS_SSH_KEY` | the private key printed above       |
| Variable | `VPS_HOST`    | VPS IP or hostname                  |
| Variable | `VPS_USER`    | `root`                              |
| Variable | `VPS_PORT`    | `22`                                |

That's it — the next push to `phase-1-map` builds and deploys.

---

## Server cheatsheet (run on the VPS as root)

```bash
# Start / stop / restart
systemctl start   orion-web
systemctl stop    orion-web
systemctl restart orion-web

# Status (running? since when? recent log lines)
systemctl status  orion-web

# Start automatically on boot (set once during setup)
systemctl enable  orion-web      # disable: systemctl disable orion-web

# Live logs
journalctl -u orion-web -f

# Apply a Caddyfile edit without dropping connections
systemctl reload  orion-web

# Quick local health check
curl -sI http://localhost:8080/web/   | head -n1
curl -sI http://localhost:8080/apk/    | head -n1
```

**URLs** (replace `<vps-ip>`; or your domain if configured):
- Web app: `http://<vps-ip>:8080/web/`
- APK index (newest first): `http://<vps-ip>:8080/apk/`

---

## Day-to-day: push → live

1. Commit and **push to `phase-1-map`** (or run the workflow manually from the Actions tab —
   it also has `workflow_dispatch`).
2. Watch the run under the repo's **Actions** tab. The `web` and `apk` jobs run in parallel
   and deploy independently — if the APK build fails, the web deploy still goes through.
3. When green:
   - **Web** is live at `/web/` (fully replaced each push).
   - A new **APK** appears at the top of `/apk/` as `app-<sha7>-<timestamp>.apk`; older
     builds are kept. On your phone, open `/apk/`, tap the newest, install.

No VPS commands are needed for a normal deploy — the server just keeps serving whatever
the workflow drops into `site/`. You only touch the VPS to start/stop the server or change
its config.

### Notes
- **APK signing:** `flutter build apk --release` with no keystore uses debug signing. Fine
  for sideloading. To ship real release builds, add a keystore (store it in GitHub Secrets,
  configure `android/key.properties` in the build step).
- **Cleaning old APKs:** they accumulate in `site/apk/`. Prune occasionally, e.g.
  `ls -t /root/orion/site/apk/*.apk | tail -n +11 | xargs -r rm` then
  `bash /root/orion/gen-apk-index.sh` to refresh the index.
- **History:** publishing used to run on a `devbox` container via `.devbox/build-*.sh` +
  a `serve` script. That's been retired — this Actions → Caddy pipeline replaces it, and
  the separate `claude-vps` box covers the Claude Code dev environment.
