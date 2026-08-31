#!/usr/bin/env bash
# Build a local development DMG of Serlink, branded "Serlink (Dev)".
#
# Unlike tool/build_macos_direct.sh (the formal Developer ID release path),
# this script is for local development builds:
#   - the app is branded "Serlink (Dev)" (bundle file name + display name) so
#     it can coexist with an App Store install of Serlink;
#   - the app keeps its Xcode development provisioning profile and matching
#     entitlements so the system actually lets it launch (stripping the
#     profile or signing with production entitlements gets the app killed at
#     launch with amfid error -413 "No matching profile found");
#   - after the DMG is created, intermediate .app copies are deleted so
#     LaunchServices/Spotlight do not index duplicate Serlink apps, and the
#     branded app is installed into /Applications.
#
# Notes:
#   - Signs with SERLINK_MACOS_CODE_SIGN_IDENTITY (default "Apple Development")
#     because local dev builds cannot be Developer ID signed here; such DMGs
#     are for the machine they are built on and are not notarized.
#   - CloudKit in this build talks to the Production environment (set via
#     com.apple.developer.icloud-container-environment in Direct.entitlements)
#     so it shares the same vault data as App Store / Developer ID builds.
#   - Defaults to ARCHS=arm64: the macOS 26 beta Command Line Tools ship a
#     lipo whose -verify_arch accepts only one architecture, which breaks
#     universal (arm64+x86_64) Flutter framework thinning. Override with
#     ARCHS="arm64 x86_64" once the toolchain is fixed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DISPLAY_NAME="${SERLINK_APP_DISPLAY_NAME:-Serlink (Dev)}"
CODE_SIGN_IDENTITY="${SERLINK_MACOS_CODE_SIGN_IDENTITY:-Apple Development}"
ARCHS="${ARCHS:-arm64}"
case "$ARCHS" in
  arm64) ARCH_SUFFIX=arm64 ;;
  x86_64) ARCH_SUFFIX=x86_64 ;;
  *) ARCH_SUFFIX=universal ;;
esac

ARCHIVE_PATH="$ROOT_DIR/build/dev/serlink-dev.xcarchive"
WORK_DIR="$ROOT_DIR/build/dev/dmg-staging"
BUNDLE_NAME="$DISPLAY_NAME.app"
STAGED_APP="$WORK_DIR/$BUNDLE_NAME"
HELPER_ENTITLEMENTS="$ROOT_DIR/macos/Runner/SerlinkMcp.entitlements"

echo "== flutter config (direct, release) =="
flutter build macos \
  --release \
  --dart-define=SERLINK_DISTRIBUTION=direct \
  --config-only

echo "== xcodebuild archive (ARCHS=$ARCHS) =="
rm -rf "$ARCHIVE_PATH"
xcodebuild archive \
  -workspace macos/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  SERLINK_MACOS_ENTITLEMENTS=Runner/Direct.entitlements \
  SERLINK_APP_DISPLAY_NAME="$DISPLAY_NAME" \
  ARCHS="$ARCHS" \
  -allowProvisioningUpdates

ARCHIVED_APP="$ARCHIVE_PATH/Products/Applications/serlink.app"
if [[ ! -d "$ARCHIVED_APP" ]]; then
  echo "error: archived app not found at $ARCHIVED_APP" >&2
  exit 1
fi

# Reuse the entitlements Xcode actually signed with: they match the embedded
# development provisioning profile (aps-environment=development etc.).
ENTITLEMENTS_PLIST="$WORK_DIR/archived-entitlements.plist"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
codesign -d --entitlements "$ENTITLEMENTS_PLIST.raw" --xml "$ARCHIVED_APP"
# codesign prepends an "Executable=..." line; keep only the XML plist.
sed -n '/<?xml/,$p' "$ENTITLEMENTS_PLIST.raw" > "$ENTITLEMENTS_PLIST"
rm "$ENTITLEMENTS_PLIST.raw"

echo "== stage $BUNDLE_NAME (keeping embedded provisioning profile) =="
cp -R "$ARCHIVED_APP" "$STAGED_APP"

echo "== compile and sign serlink-mcp helper =="
dart compile exe "$ROOT_DIR/cli/serlink_mcp.dart" \
  -o "$STAGED_APP/Contents/MacOS/serlink-mcp"
codesign \
  --force \
  --sign "$CODE_SIGN_IDENTITY" \
  --options runtime \
  --timestamp \
  --entitlements "$HELPER_ENTITLEMENTS" \
  --identifier com.alkinum.serlink.mcp \
  "$STAGED_APP/Contents/MacOS/serlink-mcp"

echo "== reseal app (identity: $CODE_SIGN_IDENTITY) =="
codesign \
  --force \
  --sign "$CODE_SIGN_IDENTITY" \
  --options runtime \
  --timestamp \
  --entitlements "$ENTITLEMENTS_PLIST" \
  "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$STAGED_APP/Contents/Info.plist")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$STAGED_APP/Contents/Info.plist")
DMG_PATH="$ROOT_DIR/build/Serlink-$VERSION+$BUILD_NUMBER-$ARCH_SUFFIX-dev.dmg"

echo "== create $DMG_PATH =="
rm -f "$DMG_PATH"
ln -s /Applications "$WORK_DIR/Applications"
hdiutil create \
  -volname "$DISPLAY_NAME" \
  -srcfolder "$WORK_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "== install to /Applications/$BUNDLE_NAME =="
if pgrep -f "/Applications/$BUNDLE_NAME/Contents/MacOS/" > /dev/null; then
  echo "error: /Applications/$BUNDLE_NAME is currently running; quit it first" >&2
  exit 1
fi
rm -rf "/Applications/$BUNDLE_NAME"
ditto "$STAGED_APP" "/Applications/$BUNDLE_NAME"

echo "== remove intermediate .app copies =="
rm -rf "$WORK_DIR" "$ARCHIVE_PATH"

echo "done: $DMG_PATH"
echo "installed: /Applications/$BUNDLE_NAME"
