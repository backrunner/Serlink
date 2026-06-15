#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${SERLINK_ARCHIVE_PATH:-$ROOT_DIR/build/ios/archives/serlink-app-store.xcarchive}"
EXPORT_PATH="${SERLINK_EXPORT_PATH:-$ROOT_DIR/build/ios/testflight-export}"
EXPORT_OPTIONS="${SERLINK_EXPORT_OPTIONS_PLIST:-$ROOT_DIR/ios/Runner/ExportOptionsAppStore.plist}"
ALLOW_PROVISIONING_UPDATES=0

for argument in "$@"; do
  if [[ "$argument" == "-allowProvisioningUpdates" ]]; then
    ALLOW_PROVISIONING_UPDATES=1
  fi
done

cd "$ROOT_DIR"

if [[ "${SERLINK_SKIP_LOCAL_SIGNING_CHECK:-}" == "1" || "$ALLOW_PROVISIONING_UPDATES" -eq 1 ]]; then
  "$ROOT_DIR/tool/check_cloudkit_release_ready.sh" \
    --distribution ios_app_store \
    --require-schema-production
else
  "$ROOT_DIR/tool/check_ios_testflight_signing.sh"
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
  "$@"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  "$@"
