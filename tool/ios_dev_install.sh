#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="com.alkinum.serlink"
DEVICE_CONNECTION="both"
DEVICE_ID=""
DEVICE_TIMEOUT="${SERLINK_IOS_DEVICE_TIMEOUT:-20}"
INSTALL_ONLY=0
BUILD_MODE="debug"
FLUTTER_ARGS=()

usage() {
  cat <<'USAGE'
Usage: ./tool/ios_dev_install.sh [options] [-- extra flutter args]

Build and deploy the iOS development app to a physical device.

Options:
  --device <id|name>       Target a specific Flutter device id or name.
  --attached               Only discover USB/attached devices.
  --wireless               Only discover wireless devices.
  --both                   Discover both attached and wireless devices (default).
  --install-only           Install the app without attaching a Flutter run session.
  --profile                Use a profile build instead of debug.
  --device-timeout <sec>   Device discovery timeout (default: 20).
  -h, --help               Show this help.

Examples:
  ./tool/ios_dev_install.sh
  ./tool/ios_dev_install.sh --attached
  ./tool/ios_dev_install.sh --wireless --device 00008110-...
  ./tool/ios_dev_install.sh --install-only
USAGE
}

fail_no_device() {
  cat >&2 <<EOF
error: no physical iOS device was found by Flutter.

Wired setup:
  1. Connect the iPhone by USB, unlock it, and trust this computer.
  2. Enable Developer Mode on the iPhone if iOS asks for it.
  3. Run: ./tool/ios_dev_install.sh --attached

Wireless setup:
  1. Complete the wired setup once.
  2. Open Xcode > Window > Devices and Simulators.
  3. Select the iPhone and enable "Connect via network".
  4. Keep the Mac and iPhone on the same network.
  5. Run: ./tool/ios_dev_install.sh --wireless

Current Flutter devices:
EOF
  flutter devices --device-timeout="$DEVICE_TIMEOUT" --device-connection="$DEVICE_CONNECTION" >&2 || true
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device|-d)
      shift
      [[ $# -gt 0 ]] || {
        echo "error: --device requires a value" >&2
        exit 1
      }
      DEVICE_ID="$1"
      ;;
    --attached)
      DEVICE_CONNECTION="attached"
      ;;
    --wireless)
      DEVICE_CONNECTION="wireless"
      ;;
    --both)
      DEVICE_CONNECTION="both"
      ;;
    --install-only)
      INSTALL_ONLY=1
      ;;
    --profile)
      BUILD_MODE="profile"
      ;;
    --device-timeout)
      shift
      [[ $# -gt 0 ]] || {
        echo "error: --device-timeout requires a value" >&2
        exit 1
      }
      DEVICE_TIMEOUT="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      FLUTTER_ARGS+=("$@")
      break
      ;;
    *)
      FLUTTER_ARGS+=("$1")
      ;;
  esac
  shift
done

cd "$ROOT_DIR"

if [[ -z "$DEVICE_ID" ]]; then
  devices_json="$(flutter devices \
    --machine \
    --device-timeout="$DEVICE_TIMEOUT" \
    --device-connection="$DEVICE_CONNECTION")"

  ios_devices=()
  while IFS= read -r line; do
    ios_devices+=("$line")
  done < <(python3 -c '
import json
import sys

devices = json.load(sys.stdin)
for device in devices:
    platform = str(device.get("targetPlatform", "")).lower()
    if "ios" not in platform:
        continue
    if device.get("emulator"):
        continue
    print("\t".join([
        str(device.get("id", "")),
        str(device.get("name", "")),
        str(device.get("sdk", "")),
    ]))
' <<<"$devices_json")

  if [[ "${#ios_devices[@]}" -eq 0 ]]; then
    fail_no_device
    exit 1
  fi

  if [[ "${#ios_devices[@]}" -gt 1 ]]; then
    echo "error: multiple physical iOS devices found; choose one with --device:" >&2
    printf '  %s\n' "${ios_devices[@]}" >&2
    exit 1
  fi

  IFS=$'\t' read -r DEVICE_ID DEVICE_NAME DEVICE_SDK <<<"${ios_devices[0]}"
  echo "Using iOS device: $DEVICE_NAME ($DEVICE_ID) $DEVICE_SDK"
fi

mode_flag="--$BUILD_MODE"
common_args=(
  "$mode_flag"
  -d "$DEVICE_ID"
  --device-timeout="$DEVICE_TIMEOUT"
  --device-connection="$DEVICE_CONNECTION"
)

if [[ "$INSTALL_ONLY" -eq 1 ]]; then
  echo "Installing $BUILD_MODE build for $BUNDLE_ID..."
  exec flutter install "${common_args[@]}" "${FLUTTER_ARGS[@]}"
fi

echo "Running $BUILD_MODE build for $BUNDLE_ID..."
echo "Flutter hot reload is available while this command stays attached."
exec flutter run "${common_args[@]}" "${FLUTTER_ARGS[@]}"
