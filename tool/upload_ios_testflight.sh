#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${SERLINK_ARCHIVE_PATH:-$ROOT_DIR/build/ios/archives/serlink-app-store.xcarchive}"
EXPORT_PATH="${SERLINK_EXPORT_PATH:-$ROOT_DIR/build/ios/testflight-export}"
EXPORT_OPTIONS="${SERLINK_EXPORT_OPTIONS_PLIST:-$ROOT_DIR/ios/Runner/ExportOptionsAppStore.plist}"
ALLOW_PROVISIONING_UPDATES=0
BUMP_BUILD_NUMBER=0
SET_BUILD_NUMBER=""
XCODEBUILD_ARGUMENTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump-build-number)
      BUMP_BUILD_NUMBER=1
      ;;
    --build-number)
      BUMP_BUILD_NUMBER=1
      shift
      [[ $# -gt 0 ]] || {
        echo "error: --build-number requires a value" >&2
        exit 1
      }
      SET_BUILD_NUMBER="$1"
      ;;
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

if [[ "${SERLINK_SKIP_LOCAL_SIGNING_CHECK:-}" == "1" || "$ALLOW_PROVISIONING_UPDATES" -eq 1 ]]; then
  "$ROOT_DIR/tool/check_cloudkit_release_ready.sh" \
    --distribution ios_app_store \
    --require-schema-production
else
  "$ROOT_DIR/tool/check_ios_testflight_signing.sh"
fi

if [[ "$BUMP_BUILD_NUMBER" -eq 1 ]]; then
  if [[ -n "$SET_BUILD_NUMBER" ]]; then
    "$ROOT_DIR/tool/bump_build_number.sh" --platform ios --set "$SET_BUILD_NUMBER"
  else
    "$ROOT_DIR/tool/bump_build_number.sh" --platform ios
  fi
fi

flutter build ios \
  --release \
  --config-only \
  --dart-define=SERLINK_DISTRIBUTION=app_store

xcodebuild archive \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  "${XCODEBUILD_ARGUMENTS[@]}"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  "${XCODEBUILD_ARGUMENTS[@]}"
