#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
SET_BUILD_NUMBER=""
PLATFORM=""
PRINT_CURRENT=0

usage() {
  cat <<'USAGE'
Usage: tool/bump_build_number.sh --platform ios|macos [options]

Options:
  --platform PLATFORM
      Choose which platform build number to update: ios or macos.

  --set BUILD_NUMBER
      Set the build number instead of incrementing it.

  --dry-run
      Print the next platform build number without changing files.

  --print
      Print the current platform build number without changing files.

  --no-pub-get
      Accepted for compatibility. Platform build numbers do not modify pubspec.yaml.

  -h, --help
      Show this help.
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      shift
      [[ $# -gt 0 ]] || fail "--platform requires ios or macos"
      PLATFORM="$1"
      ;;
    --set)
      shift
      [[ $# -gt 0 ]] || fail "--set requires a build number"
      SET_BUILD_NUMBER="$1"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --print)
      PRINT_CURRENT=1
      ;;
    --no-pub-get)
      ;;
    ios|macos)
      [[ -z "$PLATFORM" ]] || fail "platform specified more than once"
      PLATFORM="$1"
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

case "$PLATFORM" in
  ios)
    CONFIG_FILE="$ROOT_DIR/ios/Runner/Configs/AppInfo.xcconfig"
    SETTING_NAME="SERLINK_IOS_BUILD_NUMBER"
    PLATFORM_LABEL="iOS"
    ;;
  macos)
    CONFIG_FILE="$ROOT_DIR/macos/Runner/Configs/AppInfo.xcconfig"
    SETTING_NAME="SERLINK_MACOS_BUILD_NUMBER"
    PLATFORM_LABEL="macOS"
    ;;
  "")
    fail "choose a platform with --platform ios or --platform macos"
    ;;
  *)
    fail "--platform must be ios or macos"
    ;;
esac

[[ -f "$CONFIG_FILE" ]] || fail "build number config not found at $CONFIG_FILE"

if [[ -n "$SET_BUILD_NUMBER" && ! "$SET_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  fail "--set must be a non-negative integer"
fi

current_line="$(grep -E "^${SETTING_NAME}[[:space:]]*=[[:space:]]*[0-9]+[[:space:]]*$" "$CONFIG_FILE" || true)"
[[ -n "$current_line" ]] || fail "$CONFIG_FILE must contain $SETTING_NAME = <number>"

current_build="${current_line#*=}"
current_build="${current_build//[[:space:]]/}"

if [[ "$PRINT_CURRENT" -eq 1 ]]; then
  echo "$current_build"
  exit 0
fi

if [[ -n "$SET_BUILD_NUMBER" ]]; then
  next_build="$SET_BUILD_NUMBER"
else
  next_build=$((current_build + 1))
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "$next_build"
  exit 0
fi

tmp_file="$(mktemp)"
awk -v setting_name="$SETTING_NAME" -v next_build="$next_build" '
  BEGIN { changed = 0 }
  $0 ~ "^" setting_name "[[:space:]]*=[[:space:]]*[0-9]+[[:space:]]*$" && changed == 0 {
    print setting_name " = " next_build
    changed = 1
    next
  }
  { print }
  END {
    if (changed == 0) {
      exit 1
    }
  }
' "$CONFIG_FILE" >"$tmp_file" || {
  rm -f "$tmp_file"
  fail "failed to update $CONFIG_FILE"
}
mv "$tmp_file" "$CONFIG_FILE"

echo "Updated $PLATFORM_LABEL build number to $next_build"
