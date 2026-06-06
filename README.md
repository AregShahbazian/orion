# Orion — Dev Guide

Mapping app. Flutter (Android + web).

## Build & deploy

Every push to `main` or `feature/*` triggers CI (GitHub Actions) that builds a
web bundle and an APK, then deploys both to the VPS over SSH. The two builds are
independent — one failing does not block the other.

## Accessing builds

| | main | feature branch |
|---|---|---|
| Web | `/` | `/web/<name>/` |
| APK | `/apk/` | `/apk/<name>/` |

The APK directory has a generated `index.html` listing all available builds.

## APK retention

- **main** — last 3 builds kept; older ones pruned automatically after each deploy.
- **feature branches** — last 1 build kept per branch.
- **Branch deleted** — the entire preview (web + APK) is removed from the VPS automatically.

## Feature previews

1. Create a `feature/<name>` branch.
2. Push. CI deploys a preview to `/web/<name>/` and `/apk/<name>/`.
3. Delete the branch when done — preview is cleaned up automatically.

## APK filename format

`app-<YYMMDD-HHMMSS>-<sha7>.apk` — date-first so filenames sort chronologically.

## Release

No separate release track yet — `main` is always the latest. Tag with `vX.Y.Z`
as a reference point when needed.
