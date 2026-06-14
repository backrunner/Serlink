#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODE_SIGN_IDENTITY="${SERLINK_MACOS_CODE_SIGN_IDENTITY:-Developer ID Application}"
cd "$ROOT_DIR"

flutter build macos \
  --release \
  --dart-define=SERLINK_DISTRIBUTION=direct \
  --config-only

xcodebuild \
  -workspace macos/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  SERLINK_MACOS_CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  SERLINK_MACOS_ENTITLEMENTS=Runner/Direct.entitlements \
  "$@"
