#!/usr/bin/env bash
# Notarize a signed direct-channel app, package it into a DMG, then sign,
# notarize and staple the DMG. Run after tool/build_macos_direct.sh.
#
# usage: tool/notarize_macos_dmg.sh /path/to/serlink.app /path/to/output.dmg
#
# Notary credentials (one of):
#   SERLINK_NOTARY_KEYCHAIN_PROFILE=serlink-notary
#       A profile created with `xcrun notarytool store-credentials`.
#   SERLINK_NOTARY_KEY_PATH=/path/AuthKey_XXXX.p8
#   SERLINK_NOTARY_KEY_ID=XXXX SERLINK_NOTARY_ISSUER_ID=<uuid>
#       An App Store Connect API key (used by CI).
# SERLINK_MACOS_CODE_SIGN_IDENTITY overrides the DMG signing identity
# (default "Developer ID Application").
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODE_SIGN_IDENTITY="${SERLINK_MACOS_CODE_SIGN_IDENTITY:-Developer ID Application}"

if [[ $# -ne 2 ]]; then
  echo "usage: $0 /path/to/serlink.app /path/to/output.dmg" >&2
  exit 1
fi
APP_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
DMG_PATH="$2"

if [[ -n "${SERLINK_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  NOTARY_AUTH=(--keychain-profile "$SERLINK_NOTARY_KEYCHAIN_PROFILE")
elif [[ -n "${SERLINK_NOTARY_KEY_PATH:-}" && -n "${SERLINK_NOTARY_KEY_ID:-}" && -n "${SERLINK_NOTARY_ISSUER_ID:-}" ]]; then
  NOTARY_AUTH=(--key "$SERLINK_NOTARY_KEY_PATH" --key-id "$SERLINK_NOTARY_KEY_ID" --issuer "$SERLINK_NOTARY_ISSUER_ID")
else
  echo "error: set SERLINK_NOTARY_KEYCHAIN_PROFILE or SERLINK_NOTARY_KEY_PATH/KEY_ID/ISSUER_ID" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/serlink-notary.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

# Submits a file and fails unless Apple accepts it, printing the notary log.
notarize() {
  local file="$1"
  local result="$WORK_DIR/notary-result.json"
  echo "Submitting $(basename "$file") for notarization..."
  xcrun notarytool submit "$file" "${NOTARY_AUTH[@]}" --wait \
    --output-format json >"$result"
  local status id
  status="$(plutil -extract status raw -o - "$result" 2>/dev/null || true)"
  id="$(plutil -extract id raw -o - "$result" 2>/dev/null || true)"
  echo "Notarization $id: ${status:-unknown}"
  if [[ "$status" != "Accepted" ]]; then
    if [[ -n "$id" ]]; then
      xcrun notarytool log "$id" "${NOTARY_AUTH[@]}" >&2 || true
    fi
    echo "error: notarization of $(basename "$file") was not accepted" >&2
    exit 1
  fi
}

codesign --verify --deep --strict "$APP_PATH"

# 1. Notarize and staple the app so it carries its ticket inside the DMG.
ditto -c -k --keepParent "$APP_PATH" "$WORK_DIR/app.zip"
notarize "$WORK_DIR/app.zip"
xcrun stapler staple "$APP_PATH"

# 2. Package the stapled app, then sign, notarize and staple the DMG itself.
rm -f "$DMG_PATH"
"$ROOT_DIR/tool/package_macos_dmg.sh" "$APP_PATH" "$DMG_PATH"
codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp "$DMG_PATH"
notarize "$DMG_PATH"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
echo "done: notarized $DMG_PATH"
