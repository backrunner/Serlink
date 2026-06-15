#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$ROOT_DIR/pubspec.yaml"
DRY_RUN=0
RUN_PUB_GET=1
SET_BUILD_NUMBER=""

usage() {
  cat <<'USAGE'
Usage: tool/bump_build_number.sh [options]

Options:
  --set BUILD_NUMBER
      Set the build number instead of incrementing it.

  --dry-run
      Print the next version without changing files.

  --no-pub-get
      Do not run flutter pub get after changing pubspec.yaml.

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
    --set)
      shift
      [[ $# -gt 0 ]] || fail "--set requires a build number"
      SET_BUILD_NUMBER="$1"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --no-pub-get)
      RUN_PUB_GET=0
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

[[ -f "$PUBSPEC" ]] || fail "pubspec.yaml not found at $PUBSPEC"

if [[ -n "$SET_BUILD_NUMBER" && ! "$SET_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  fail "--set must be a non-negative integer"
fi

version_line="$(grep -E '^version:[[:space:]]*[0-9]+(\.[0-9]+){2}(\+[0-9]+)?[[:space:]]*$' "$PUBSPEC" || true)"
[[ -n "$version_line" ]] || fail "pubspec.yaml must contain a version like 1.0.0+1"

version_value="${version_line#version:}"
version_value="${version_value//[[:space:]]/}"
version_name="${version_value%%+*}"
current_build="0"
if [[ "$version_value" == *"+"* ]]; then
  current_build="${version_value##*+}"
fi

if [[ -n "$SET_BUILD_NUMBER" ]]; then
  next_build="$SET_BUILD_NUMBER"
else
  next_build=$((current_build + 1))
fi

next_version="$version_name+$next_build"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "$next_version"
  exit 0
fi

tmp_file="$(mktemp)"
awk -v next_version="$next_version" '
  BEGIN { changed = 0 }
  /^version:[[:space:]]*[0-9]+(\.[0-9]+){2}(\+[0-9]+)?[[:space:]]*$/ && changed == 0 {
    print "version: " next_version
    changed = 1
    next
  }
  { print }
  END {
    if (changed == 0) {
      exit 1
    }
  }
' "$PUBSPEC" >"$tmp_file" || {
  rm -f "$tmp_file"
  fail "failed to update pubspec.yaml"
}
mv "$tmp_file" "$PUBSPEC"

echo "Updated pubspec.yaml to version: $next_version"

if [[ "$RUN_PUB_GET" -eq 1 ]]; then
  cd "$ROOT_DIR"
  flutter pub get
fi
