#!/usr/bin/env bash
# devbox project integration — Orion toolchain: JDK 21 + Flutter (stable) + Android SDK.
# Run by the devbox container entrypoint at first start, as ROOT, installing into the
# persistent /opt/toolchain volume (so it survives down/up). Idempotent: skips anything
# already present. JDK 21 because maplibre_gl requires source release 21.
#
# Contract: devbox runs this with the toolchain dir at /opt/toolchain and the container's
# login user `dev`. It writes /etc/profile.d/devbox-project.sh so every shell gets the PATH.

set -euo pipefail
TC="${TOOLCHAIN_DIR:-/opt/toolchain}"
JDK_DIR="$TC/jdk"
FLUTTER_DIR="$TC/flutter"
ANDROID_HOME="$TC/android-sdk"
JDK_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.5%2B11/OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz"
CMDLINE_VER="11076708"
ANDROID_PLATFORM="android-34"
ANDROID_BUILDTOOLS="34.0.0"
log() { printf '\033[1;34m[orion/provision]\033[0m %s\n' "$*"; }

mkdir -p "$TC"

# --- JDK 21 (portable tarball → volume) ---
if [ ! -x "$JDK_DIR/bin/java" ]; then
  log "installing JDK 21 → $JDK_DIR"
  tmp="$(mktemp -d)"; curl -fsSL "$JDK_URL" -o "$tmp/jdk.tgz"
  mkdir -p "$JDK_DIR"; tar -xzf "$tmp/jdk.tgz" -C "$JDK_DIR" --strip-components=1
  rm -rf "$tmp"
fi
export JAVA_HOME="$JDK_DIR"; export PATH="$JDK_DIR/bin:$PATH"

# --- Flutter SDK (stable) ---
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  log "cloning Flutter stable → $FLUTTER_DIR"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
git config --system --add safe.directory "$FLUTTER_DIR" 2>/dev/null || true

# --- Android cmdline-tools ---
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  log "installing Android cmdline-tools → $ANDROID_HOME"
  tmp="$(mktemp -d)"
  curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_VER}_latest.zip" -o "$tmp/cmd.zip"
  mkdir -p "$ANDROID_HOME/cmdline-tools"; unzip -q "$tmp/cmd.zip" -d "$tmp"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"; rm -rf "$tmp"
fi

# --- login PATH for all shells (project layer) ---
cat > /etc/profile.d/devbox-project.sh <<EOF
export JAVA_HOME="$JDK_DIR"
export ANDROID_HOME="$ANDROID_HOME"
export PATH="$JDK_DIR/bin:$FLUTTER_DIR/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:\$PATH"
EOF

# Hand the toolchain to dev BEFORE running flutter/sdkmanager (they refuse to run as root).
chown -R dev:dev "$TC" 2>/dev/null || true

# --- SDK packages + licenses + flutter precache (as dev) ---
if [ ! -d "$ANDROID_HOME/platform-tools" ] || [ ! -x "$FLUTTER_DIR/bin/cache/dart-sdk/bin/dart" ]; then
  log "accepting Android licenses + installing platform-tools / $ANDROID_PLATFORM / build-tools $ANDROID_BUILDTOOLS"
  su dev -c "
    export JAVA_HOME='$JDK_DIR' ANDROID_HOME='$ANDROID_HOME'
    export PATH='$JDK_DIR/bin:$FLUTTER_DIR/bin:$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH'
    yes | sdkmanager --licenses >/dev/null 2>&1 || true
    sdkmanager 'platform-tools' 'platforms;$ANDROID_PLATFORM' 'build-tools;$ANDROID_BUILDTOOLS' >/dev/null
    yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
    flutter precache --no-ios >/dev/null 2>&1 || true
    flutter --version
  "
fi
log "orion toolchain ready under $TC"
