#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER_ID="iCloud.com.alkinum.serlink"
RECORD_TYPE="SerlinkSyncObject"
PATH_FIELD="path"
DATA_FIELD="data"
EVENT_CHANNEL="serlink/cloudkit/events"
SUBSCRIPTION_ID="serlink-sync-objects"
REQUIRE_SCHEMA_PRODUCTION=0
DISTRIBUTION="all"

usage() {
  cat <<'USAGE'
Usage: tool/check_cloudkit_release_ready.sh [options]

Options:
  --distribution ios_app_store|app_store|direct|all
      Limit distribution-channel checks. Defaults to all.

  --require-schema-production
      Require an explicit confirmation that the CloudKit development schema has
      been deployed to Production in CloudKit Console.

Environment:
  SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1
      Non-interactive confirmation for --require-schema-production.
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 1
}

ok() {
  echo "ok: $*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --distribution)
      shift
      [[ $# -gt 0 ]] || fail "--distribution requires a value"
      DISTRIBUTION="$1"
      ;;
    --require-schema-production)
      REQUIRE_SCHEMA_PRODUCTION=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
  shift
done

case "$DISTRIBUTION" in
  ios_app_store|app_store|direct|all) ;;
  *) fail "unsupported distribution: $DISTRIBUTION" ;;
esac

plist_value() {
  local plist="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true
}

plist_requires_value() {
  local plist="$1"
  local key="$2"
  local expected="$3"
  local label="$4"
  if ! plist_value "$plist" "$key" | grep -q "$expected"; then
    fail "$label missing $expected in $key"
  fi
}

plist_requires_bool() {
  local plist="$1"
  local key="$2"
  local expected="$3"
  local label="$4"
  local actual
  actual="$(plist_value "$plist" "$key")"
  [[ "$actual" == "$expected" ]] || fail "$label requires $key=$expected, found '${actual:-missing}'"
}

plist_rejects_development_environment() {
  local plist="$1"
  local label="$2"
  local actual
  actual="$(plist_value "$plist" "com.apple.developer.icloud-container-environment")"
  case "$actual" in
    ""|"Production")
      ok "$label uses the CloudKit production environment"
      ;;
    "Development")
      fail "$label is still pinned to the CloudKit Development environment"
      ;;
    *)
      fail "$label has unexpected CloudKit environment: $actual"
      ;;
  esac
}

plist_requires_development_environment() {
  local plist="$1"
  local label="$2"
  local actual
  actual="$(plist_value "$plist" "com.apple.developer.icloud-container-environment")"
  [[ "$actual" == "Development" ]] || fail "$label should use CloudKit Development, found '${actual:-missing}'"
  ok "$label stays on the CloudKit development environment"
}

plist_requires_aps_environment() {
  local plist="$1"
  local expected="$2"
  local label="$3"
  local actual
  actual="$(plist_value "$plist" "com.apple.developer.aps-environment")"
  [[ "$actual" == "$expected" ]] || fail "$label requires APS $expected, found '${actual:-missing}'"
  ok "$label uses APS $expected"
}

check_cloudkit_entitlements() {
  local plist="$1"
  local label="$2"
  [[ -f "$plist" ]] || fail "$label not found: $plist"
  plutil -lint "$plist" >/dev/null
  plist_requires_value "$plist" "com.apple.developer.icloud-services" "CloudKit" "$label"
  plist_requires_value "$plist" "com.apple.developer.icloud-container-identifiers" "$CONTAINER_ID" "$label"
  ok "$label includes CloudKit and $CONTAINER_ID"
}

check_swift_contract() {
  local file="$1"
  local label="$2"
  [[ -f "$file" ]] || fail "$label not found: $file"
  grep -q "containerIdentifier = \"$CONTAINER_ID\"" "$file" \
    || fail "$label does not use container $CONTAINER_ID"
  grep -q "recordType = \"$RECORD_TYPE\"" "$file" \
    || fail "$label does not use record type $RECORD_TYPE"
  grep -q "pathField = \"$PATH_FIELD\"" "$file" \
    || fail "$label does not use path field $PATH_FIELD"
  grep -q "dataField = \"$DATA_FIELD\"" "$file" \
    || fail "$label does not use data field $DATA_FIELD"
  grep -q "eventsChannelName = \"$EVENT_CHANNEL\"" "$file" \
    || fail "$label does not expose the CloudKit event channel"
  grep -q "subscriptionID = \"$SUBSCRIPTION_ID\"" "$file" \
    || fail "$label does not install the remote change subscription"
  grep -q "writeObjectIfUnchanged" "$file" \
    || fail "$label does not expose conditional manifest writes"
  ok "$label matches the CloudKit schema and realtime sync contract"
}

check_script_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  grep -q -- "$needle" "$file" || fail "$label missing: $needle"
}

confirm_schema_production() {
  [[ "$REQUIRE_SCHEMA_PRODUCTION" -eq 1 ]] || return 0
  if [[ "${SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED:-}" == "1" ]]; then
    ok "CloudKit Production schema confirmation provided"
    return 0
  fi
  if [[ -t 0 && -t 1 ]]; then
    echo
    echo "CloudKit Production schema gate"
    echo "Before release, deploy the Development schema for $CONTAINER_ID to Production in CloudKit Console."
    read -r -p "Type 'production schema deployed' to continue: " confirmation
    [[ "$confirmation" == "production schema deployed" ]] \
      || fail "CloudKit Production schema was not confirmed"
    ok "CloudKit Production schema confirmed interactively"
    return 0
  fi
  fail "set SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 after deploying the CloudKit schema to Production"
}

cd "$ROOT_DIR"

check_cloudkit_entitlements "ios/Runner/DebugProfile.entitlements" "iOS Debug/Profile entitlements"
plist_requires_development_environment "ios/Runner/DebugProfile.entitlements" "iOS Debug/Profile entitlements"
plist_requires_aps_environment "ios/Runner/DebugProfile.entitlements" "development" "iOS Debug/Profile entitlements"

check_cloudkit_entitlements "ios/Runner/Release.entitlements" "iOS Release entitlements"
plist_rejects_development_environment "ios/Runner/Release.entitlements" "iOS Release entitlements"
plist_requires_aps_environment "ios/Runner/Release.entitlements" "production" "iOS Release entitlements"
check_script_contains "ios/Runner/Info.plist" "remote-notification" "iOS Info.plist"

if [[ "$DISTRIBUTION" == "ios_app_store" || "$DISTRIBUTION" == "all" ]]; then
  check_script_contains "tool/upload_ios_testflight.sh" "--dart-define=SERLINK_DISTRIBUTION=app_store" "iOS TestFlight upload script"
  check_script_contains "tool/upload_ios_testflight.sh" "tool/bump_build_number.sh" "iOS TestFlight upload script"
  check_script_contains "tool/upload_ios_testflight.sh" "--bump-build-number" "iOS TestFlight upload script"
  check_script_contains "tool/upload_ios_testflight.sh" "ios/Runner/ExportOptionsAppStore.plist" "iOS TestFlight upload script"
  check_script_contains "tool/upload_ios_testflight.sh" "xcodebuild archive" "iOS TestFlight upload script"
  check_script_contains "ios/Runner/ExportOptionsAppStore.plist" "<string>app-store-connect</string>" "iOS App Store export options"
  check_script_contains "ios/Runner/ExportOptionsAppStore.plist" "<string>upload</string>" "iOS App Store export options"
  check_script_contains "ios/Runner/ExportOptionsAppStore.plist" "<string>Production</string>" "iOS App Store export options"
  ok "iOS App Store Connect release surface is locked"
fi

check_cloudkit_entitlements "macos/Runner/DebugProfile.entitlements" "macOS Debug/Profile entitlements"
plist_requires_development_environment "macos/Runner/DebugProfile.entitlements" "macOS Debug/Profile entitlements"
plist_requires_aps_environment "macos/Runner/DebugProfile.entitlements" "development" "macOS Debug/Profile entitlements"

if [[ "$DISTRIBUTION" == "app_store" || "$DISTRIBUTION" == "all" ]]; then
  check_cloudkit_entitlements "macos/Runner/Release.entitlements" "macOS App Store entitlements"
  plist_rejects_development_environment "macos/Runner/Release.entitlements" "macOS App Store entitlements"
  plist_requires_aps_environment "macos/Runner/Release.entitlements" "production" "macOS App Store entitlements"
  plist_requires_bool "macos/Runner/Release.entitlements" "com.apple.security.app-sandbox" "true" "macOS App Store entitlements"
  plist_requires_bool "macos/Runner/Release.entitlements" "com.apple.security.network.client" "true" "macOS App Store entitlements"
  plist_requires_bool "macos/Runner/Release.entitlements" "com.apple.security.network.server" "true" "macOS App Store entitlements"
  plist_requires_bool "macos/Runner/Release.entitlements" "com.apple.security.files.user-selected.read-write" "true" "macOS App Store entitlements"
  plist_requires_bool "macos/Runner/Release.entitlements" "com.apple.security.files.downloads.read-write" "true" "macOS App Store entitlements"
  check_script_contains "tool/build_macos_app_store.sh" "--dart-define=SERLINK_DISTRIBUTION=app_store" "macOS App Store build script"
  check_script_contains "tool/build_macos_app_store.sh" "SERLINK_MACOS_ENTITLEMENTS=Runner/Release.entitlements" "macOS App Store build script"
  check_script_contains "tool/build_macos_app_store.sh" "xcodebuild archive" "macOS App Store build script"
  check_script_contains "tool/build_macos_app_store.sh" "ALLOW_PROVISIONING_UPDATES" "macOS App Store build script"
  check_script_contains "tool/upload_macos_testflight.sh" "tool/bump_build_number.sh" "macOS TestFlight upload script"
  check_script_contains "tool/upload_macos_testflight.sh" "--bump-build-number" "macOS TestFlight upload script"
  ok "macOS App Store release surface is locked"
fi

if [[ "$DISTRIBUTION" == "direct" || "$DISTRIBUTION" == "all" ]]; then
  check_cloudkit_entitlements "macos/Runner/Direct.entitlements" "macOS Direct entitlements"
  plist_rejects_development_environment "macos/Runner/Direct.entitlements" "macOS Direct entitlements"
  plist_requires_aps_environment "macos/Runner/Direct.entitlements" "production" "macOS Direct entitlements"
  if [[ "$(plist_value "macos/Runner/Direct.entitlements" "com.apple.security.app-sandbox")" == "true" ]]; then
    fail "macOS Direct entitlements should not enable the App Sandbox"
  fi
  plist_requires_bool "macos/Runner/Direct.entitlements" "com.apple.security.network.client" "true" "macOS Direct entitlements"
  plist_requires_bool "macos/Runner/Direct.entitlements" "com.apple.security.network.server" "true" "macOS Direct entitlements"
  check_script_contains "tool/build_macos_direct.sh" "--dart-define=SERLINK_DISTRIBUTION=direct" "macOS Direct build script"
  check_script_contains "tool/build_macos_direct.sh" "SERLINK_MACOS_ENTITLEMENTS=Runner/Direct.entitlements" "macOS Direct build script"
  check_script_contains "tool/build_macos_direct.sh" "Developer ID Application" "macOS Direct build script"
  ok "macOS Direct release surface is locked"
fi

check_swift_contract "ios/Runner/CloudKitSyncChannel.swift" "iOS CloudKit bridge"
check_swift_contract "macos/Runner/CloudKitSyncChannel.swift" "macOS CloudKit bridge"
confirm_schema_production

echo "CloudKit release checks passed."
