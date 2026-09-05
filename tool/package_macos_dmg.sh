#!/usr/bin/env bash
# Package an already signed direct-channel app. Never modifies the app's seal.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -ne 2 ]]; then
  echo "usage: $0 /path/to/Serlink.app /path/to/output.dmg" >&2
  exit 1
fi
APP_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
DMG_PATH="$2"
PLIST="$APP_PATH/Contents/Info.plist"
if [[ ! -f "$PLIST" ]]; then
  echo "error: application bundle not found: $APP_PATH" >&2
  exit 1
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print SerlinkDMGInstallerEnabled' "$PLIST")" != YES ]]; then
  echo "error: rebuild with SERLINK_DMG_INSTALLER_ENABLED=YES before packaging" >&2
  exit 1
fi
if ! command -v uv >/dev/null 2>&1; then
  echo "error: uv is required for the pinned dmgbuild packaging tool (brew install uv)" >&2
  exit 1
fi
codesign --verify --deep --strict "$APP_PATH"
DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c 'Print CFBundleDisplayName' "$PLIST")
mkdir -p "$(dirname "$DMG_PATH")"
# dmgbuild writes Finder metadata directly, requires no Finder automation, and
# combines background.png/background@2x.png into a Retina TIFF automatically.
uv run --with dmgbuild==1.6.7 python -m dmgbuild \
  -s "$ROOT_DIR/macos/dmg/settings.py" \
  -D "app=$APP_PATH" \
  -D "background=$ROOT_DIR/macos/dmg/background.png" \
  "$DISPLAY_NAME" "$DMG_PATH"
hdiutil verify "$DMG_PATH"
# Check the packaged copy as well: Finder metadata added during layout can
# invalidate an otherwise valid source bundle's strict signature checks.
VALIDATION_MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/serlink-dmg-check.XXXXXX")"
cleanup() {
  hdiutil detach "$VALIDATION_MOUNT" >/dev/null 2>&1 || true
  rmdir "$VALIDATION_MOUNT" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach -nobrowse -mountpoint "$VALIDATION_MOUNT" "$DMG_PATH" >/dev/null
codesign --verify --deep --strict "$VALIDATION_MOUNT/$(basename "$APP_PATH")"
hdiutil detach "$VALIDATION_MOUNT" >/dev/null
rmdir "$VALIDATION_MOUNT"
trap - EXIT
echo "done: $DMG_PATH"
