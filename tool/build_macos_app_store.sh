#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${SERLINK_ARCHIVE_PATH:-$ROOT_DIR/build/macos/archives/serlink-app-store.xcarchive}"
CODE_SIGN_IDENTITY="${SERLINK_MACOS_CODE_SIGN_IDENTITY:-Mac App Distribution}"
cd "$ROOT_DIR"

"$ROOT_DIR/tool/check_cloudkit_release_ready.sh" \
  --distribution app_store \
  --require-schema-production

flutter build macos \
  --release \
  --dart-define=SERLINK_DISTRIBUTION=app_store \
  --config-only

xcodebuild archive \
  -workspace macos/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  SERLINK_MACOS_CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  SERLINK_MACOS_ENTITLEMENTS=Runner/Release.entitlements \
  "$@"
