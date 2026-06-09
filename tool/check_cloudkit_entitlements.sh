#!/usr/bin/env bash
set -euo pipefail

TARGET_PATH="${1:-build/macos/Build/Products/Debug/serlink.app}"
CONTAINER_ID="iCloud.com.alkinum.serlink"

if [[ ! -e "$TARGET_PATH" ]]; then
  echo "Target not found: $TARGET_PATH" >&2
  echo "Pass an entitlements plist or a signed app bundle." >&2
  exit 1
fi

ENTITLEMENTS="$(mktemp)"
trap 'rm -f "$ENTITLEMENTS"' EXIT

if [[ -f "$TARGET_PATH" ]]; then
  cp "$TARGET_PATH" "$ENTITLEMENTS"
else
  codesign -d --entitlements :- "$TARGET_PATH" >"$ENTITLEMENTS" 2>/dev/null || {
    echo "Unable to read signed entitlements from: $TARGET_PATH" >&2
    echo "Simulator builds may be ad-hoc signed with empty entitlements." >&2
    echo "For iOS simulator checks, pass ios/Runner/DebugProfile.entitlements instead." >&2
    exit 1
  }
fi

echo "CloudKit entitlements for $TARGET_PATH:"
plutil -p "$ENTITLEMENTS"

if ! /usr/libexec/PlistBuddy -c "Print :com.apple.developer.icloud-services" "$ENTITLEMENTS" 2>/dev/null | grep -q "CloudKit"; then
  echo "Missing CloudKit in com.apple.developer.icloud-services" >&2
  exit 1
fi

if ! /usr/libexec/PlistBuddy -c "Print :com.apple.developer.icloud-container-identifiers" "$ENTITLEMENTS" 2>/dev/null | grep -q "$CONTAINER_ID"; then
  echo "Missing $CONTAINER_ID in com.apple.developer.icloud-container-identifiers" >&2
  exit 1
fi

ENVIRONMENT="$(/usr/libexec/PlistBuddy -c "Print :com.apple.developer.icloud-container-environment" "$ENTITLEMENTS" 2>/dev/null || true)"
if [[ -n "$ENVIRONMENT" ]]; then
  echo "CloudKit environment: $ENVIRONMENT"
else
  echo "CloudKit environment entitlement is not present in the signed app."
  echo "This is expected for release/distribution builds that use the production environment."
fi

echo "CloudKit entitlements look ready."
