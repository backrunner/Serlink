#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="com.alkinum.serlink"
CONTAINER_ID="iCloud.com.alkinum.serlink"
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

failures=0

fail() {
  echo "error: $*" >&2
  failures=$((failures + 1))
}

ok() {
  echo "ok: $*"
}

note() {
  echo "note: $*"
}

plist_value() {
  local plist="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true
}

profile_matches_bundle() {
  local plist="$1"
  local app_identifier
  local bundle_identifier
  app_identifier="$(plist_value "$plist" "Entitlements:application-identifier")"
  bundle_identifier="$(plist_value "$plist" "Entitlements:com.apple.application-identifier")"

  [[ "$app_identifier" == *".$BUNDLE_ID" ]] || [[ "$bundle_identifier" == *".$BUNDLE_ID" ]]
}

profile_has_cloudkit() {
  local plist="$1"
  plist_value "$plist" "Entitlements:com.apple.developer.icloud-services" | grep -q "CloudKit" \
    && plist_value "$plist" "Entitlements:com.apple.developer.icloud-container-identifiers" | grep -q "$CONTAINER_ID"
}

profile_is_ios_profile() {
  local plist="$1"
  plist_value "$plist" "Platform" | grep -q "iOS"
}

profile_is_app_store_distribution() {
  local plist="$1"
  local entitlements_environment
  local get_task_allow
  entitlements_environment="$(plist_value "$plist" "Entitlements:com.apple.developer.icloud-container-environment")"
  get_task_allow="$(plist_value "$plist" "Entitlements:get-task-allow")"

  if [[ -n "$(plist_value "$plist" "ProvisionedDevices")" ]]; then
    return 1
  fi

  [[ "$get_task_allow" != "true" ]] || return 1
  [[ "$entitlements_environment" != "Development" ]]
}

check_identity() {
  local identities
  identities="$(security find-identity -p codesigning -v 2>/dev/null || true)"
  if echo "$identities" | grep -Eq '"(Apple Distribution|iPhone Distribution): '; then
    ok "iOS App Store Connect distribution signing identity is installed"
  else
    fail "missing an Apple Distribution signing identity for iOS App Store Connect"
    note "Current identities:"
    echo "$identities" | sed 's/^/  /'
  fi
}

check_profiles() {
  if [[ ! -d "$PROFILE_DIR" ]]; then
    fail "no provisioning profiles directory found at $PROFILE_DIR"
    return
  fi

  local found_bundle=0
  local found_ready=0

  while IFS= read -r -d '' profile; do
    local plist
    plist="$(mktemp)"
    if ! security cms -D -i "$profile" >"$plist" 2>/dev/null; then
      rm -f "$plist"
      continue
    fi

    if profile_matches_bundle "$plist"; then
      found_bundle=1
      local name
      local uuid
      name="$(plist_value "$plist" "Name")"
      uuid="$(plist_value "$plist" "UUID")"
      if profile_is_ios_profile "$plist" && profile_has_cloudkit "$plist" && profile_is_app_store_distribution "$plist"; then
        found_ready=1
        ok "found iOS TestFlight-capable profile: ${name:-unknown} (${uuid:-unknown})"
      else
        note "profile for $BUNDLE_ID is not iOS TestFlight-ready: ${name:-unknown} (${uuid:-unknown})"
      fi
    fi

    rm -f "$plist"
  done < <(find "$PROFILE_DIR" -type f -name "*.mobileprovision" -print0)

  if [[ "$found_bundle" -eq 0 ]]; then
    fail "no iOS provisioning profile found for $BUNDLE_ID"
  elif [[ "$found_ready" -eq 0 ]]; then
    fail "no iOS App Store Connect profile for $BUNDLE_ID contains CloudKit production entitlements"
  fi
}

cd "$ROOT_DIR"
"$ROOT_DIR/tool/check_cloudkit_release_ready.sh" --distribution ios_app_store
check_identity
check_profiles

if [[ "$failures" -gt 0 ]]; then
  echo
  fail "iOS TestFlight signing is not ready"
  exit 1
fi

echo "iOS TestFlight signing looks ready."
