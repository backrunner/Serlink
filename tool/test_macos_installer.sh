#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/serlink-installer-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
PLATFORM_PATH="$(xcrun --sdk macosx --show-sdk-platform-path)"
TEST_FRAMEWORKS="$PLATFORM_PATH/Developer/Library/Frameworks"
TEST_BUNDLE="$TEST_DIR/InstallerTests.xctest"
mkdir -p "$TEST_BUNDLE/Contents/MacOS"
cat > "$TEST_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>InstallerTests</string>
<key>CFBundleIdentifier</key><string>com.alkinum.serlink.installer-tests</string>
<key>CFBundlePackageType</key><string>BNDL</string>
</dict></plist>
PLIST
swiftc -swift-version 5 -emit-library -module-name InstallerTests \
  -I "$PLATFORM_PATH/Developer/usr/lib" \
  -L "$PLATFORM_PATH/Developer/usr/lib" \
  -Xlinker -rpath -Xlinker "$PLATFORM_PATH/Developer/usr/lib" \
  -F "$TEST_FRAMEWORKS" -Xlinker -rpath -Xlinker "$TEST_FRAMEWORKS" \
  "$ROOT_DIR/macos/Runner/AppInstallation.swift" \
  "$ROOT_DIR/test/macos/AppInstallationTests.swift" \
  -o "$TEST_BUNDLE/Contents/MacOS/InstallerTests"
xcrun xctest "$TEST_BUNDLE"
swiftc -swift-version 5 -typecheck \
  "$ROOT_DIR/macos/Runner/AppInstallation.swift" \
  "$ROOT_DIR/macos/Runner/DirectAppInstaller.swift" \
  "$ROOT_DIR/macos/Runner/main.swift"
