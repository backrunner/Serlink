#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-build/macos/Build/Products/Debug/serlink.app}"
CONTAINER_ID="iCloud.com.alkinum.serlink"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  echo "Build or run the macOS app first, for example: flutter run -d macos" >&2
  exit 1
fi

ENTITLEMENTS="$(mktemp)"
trap 'rm -f "$ENTITLEMENTS"' EXIT

codesign -d --entitlements :- "$APP_PATH" >"$ENTITLEMENTS" 2>/dev/null || {
  echo "Unable to read signed entitlements from: $APP_PATH" >&2
  exit 1
}

echo "Signed entitlements for $APP_PATH:"
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
  echo "CloudKit environment entitlement is not present in the signed app" >&2
  exit 1
fi

echo "CloudKit entitlements look ready."
