#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODE_SIGN_IDENTITY="${SERLINK_MACOS_CODE_SIGN_IDENTITY:-Developer ID Application}"
cd "$ROOT_DIR"

"$ROOT_DIR/tool/check_cloudkit_release_ready.sh" \
  --distribution direct \
  --require-schema-production

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
  SERLINK_DMG_INSTALLER_ENABLED=YES \
  "$@"

# Build and embed the serlink-mcp stdio helper. Direct (non-App-Store) builds
# ship it next to the main executable as a standalone MCP server that connects
# to the app only for tool calls; the App Store build excludes it by design.
APP_PATH="$ROOT_DIR/build/macos/Build/Products/Release/serlink.app"
HELPER_PATH="$APP_PATH/Contents/MacOS/serlink-mcp"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: expected app bundle not found at $APP_PATH" >&2
  exit 1
fi

dart compile exe "$ROOT_DIR/cli/serlink_mcp.dart" -o "$HELPER_PATH"

# Sign the helper like the main app: Developer ID, hardened runtime, and a
# secure timestamp so the notarized DMG passes Gatekeeper. The Dart AOT binary
# needs allow-unsigned-executable-memory or it is killed at launch under
# Hardened Runtime.
codesign \
  --force \
  --sign "$CODE_SIGN_IDENTITY" \
  --options runtime \
  --timestamp \
  --entitlements "$ROOT_DIR/macos/Runner/SerlinkMcp.entitlements" \
  --identifier com.alkinum.serlink.mcp \
  "$HELPER_PATH"

# Re-seal the app bundle; embedding the helper invalidated its seal. Nested
# frameworks keep their Xcode signatures, so no --deep here.
codesign \
  --force \
  --sign "$CODE_SIGN_IDENTITY" \
  --options runtime \
  --timestamp \
  --entitlements "$ROOT_DIR/macos/Runner/Direct.entitlements" \
  "$APP_PATH"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP_PATH/Contents/Info.plist")
DMG_PATH="${SERLINK_DMG_PATH:-$ROOT_DIR/build/Serlink-$VERSION+$BUILD_NUMBER.dmg}"
"$ROOT_DIR/tool/package_macos_dmg.sh" "$APP_PATH" "$DMG_PATH"
echo "Notarize and staple the app and DMG before distribution; see docs/macos_release.md."
