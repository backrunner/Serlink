#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${SERLINK_ARCHIVE_PATH:-$ROOT_DIR/build/macos/archives/serlink-app-store.xcarchive}"
CODE_SIGN_IDENTITY="${SERLINK_MACOS_CODE_SIGN_IDENTITY:-}"
ALLOW_PROVISIONING_UPDATES=0
XCODEBUILD_ARGUMENTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -allowProvisioningUpdates)
      ALLOW_PROVISIONING_UPDATES=1
      XCODEBUILD_ARGUMENTS+=("$1")
      ;;
    *)
      XCODEBUILD_ARGUMENTS+=("$1")
      ;;
  esac
  shift
done

cd "$ROOT_DIR"

"$ROOT_DIR/tool/check_cloudkit_release_ready.sh" \
  --distribution app_store \
  --require-schema-production

flutter build macos \
  --release \
  --dart-define=SERLINK_DISTRIBUTION=app_store \
  --config-only

XCODEBUILD_SETTINGS=(
  SERLINK_MACOS_ENTITLEMENTS=Runner/Release.entitlements
)

if [[ -n "$CODE_SIGN_IDENTITY" && "$ALLOW_PROVISIONING_UPDATES" -eq 0 ]]; then
  XCODEBUILD_SETTINGS+=("SERLINK_MACOS_CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY")
fi

xcodebuild archive \
  -workspace macos/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  "${XCODEBUILD_SETTINGS[@]}" \
  "${XCODEBUILD_ARGUMENTS[@]}"
