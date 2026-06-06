#!/usr/bin/env bash
# Uninstall the Orion app from my Zenfone (ASUS_AI2302) over USB debugging + adb.
#
# Prereqs: USB debugging enabled on the phone, plugged in, and authorized for this
# machine (`adb devices` should show it as "device", not "unauthorized").
#
# Override the defaults if needed:
#   PACKAGE=com.other.app DEVICE=SERIAL ./scripts/uninstall-from-zenfone.sh
set -euo pipefail

PACKAGE="${PACKAGE:-com.mby4m.orion}"
DEVICE="${DEVICE:-R8AIB700S807D3Z}"   # Zenfone 10 (ASUS_AI2302)

command -v adb >/dev/null || { echo "adb not found on PATH" >&2; exit 1; }

# Make sure the specific Zenfone is connected and authorized.
state="$(adb devices | awk -v d="$DEVICE" '$1==d {print $2}')"
case "$state" in
  device) ;;
  unauthorized) echo "Device $DEVICE is unauthorized — accept the USB debugging prompt on the phone." >&2; exit 1 ;;
  "")           echo "Device $DEVICE not connected. Plug in the Zenfone and enable USB debugging." >&2
                echo "Currently attached:" >&2; adb devices -l >&2; exit 1 ;;
  *)            echo "Device $DEVICE is in state '$state' — expected 'device'." >&2; exit 1 ;;
esac

# Bail out cleanly if the app isn't installed. Capture the list first, then grep it
# from a here-string: piping straight into `grep -q` makes grep close the pipe on
# match, killing adb with SIGPIPE (141) which `pipefail` would mis-read as "absent".
packages="$(adb -s "$DEVICE" shell pm list packages | tr -d '\r')"
if ! grep -qx "package:$PACKAGE" <<<"$packages"; then
  echo "$PACKAGE is not installed on $DEVICE — nothing to do."
  exit 0
fi

echo "Uninstalling '$PACKAGE' from $DEVICE (ASUS_AI2302)..."
adb -s "$DEVICE" uninstall "$PACKAGE"
echo "Done — '$PACKAGE' removed from $DEVICE."
