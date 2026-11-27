#!/usr/bin/env bash
# Builds and packages the Serlink Linux release.
#
# Produces, in build/dist/linux:
#   Serlink-<version>-linux-<arch>.tar.gz   portable bundle
#   Serlink-<version>-linux-<arch>.deb      Debian/Ubuntu package
#   SHA256SUMS-linux-<arch>.txt
#
# <arch> is x64 or arm64 (the build host's architecture). Requires Flutter,
# the Linux desktop toolchain (clang, cmake, ninja, pkg-config, libgtk-3-dev,
# libsecret-1-dev) and dpkg-deb. Run from any directory.
#
#   tool/package_linux.sh
#   tool/package_linux.sh --version 1.2.0-beta.1 --build-number 7
#   tool/package_linux.sh --skip-build --skip-deb
set -euo pipefail

usage() {
  sed -n '2,15s/^# \{0,1\}//p' "$0"
  echo "Options: --version V  --build-number N  --skip-build  --skip-deb"
}

version=""
build_number=""
skip_build=0
skip_deb=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) version="${2:?--version needs a value}"; shift 2 ;;
    --build-number) build_number="${2:?--build-number needs a value}"; shift 2 ;;
    --skip-build) skip_build=1; shift ;;
    --skip-deb) skip_deb=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

pubspec_version="$(sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' pubspec.yaml)"
pubspec_name="${pubspec_version%%+*}"
pubspec_build=""
[[ "$pubspec_version" == *+* ]] && pubspec_build="${pubspec_version#*+}"
version="${version:-$pubspec_name}"
build_number="${build_number:-${pubspec_build:-0}}"

label='[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*'
version_pattern="^([0-9]+\.[0-9]+\.[0-9]+)(-${label})?(\+${label})?$"
if [[ ! "$version" =~ $version_pattern ]]; then
  echo "Version '$version' is not semantic (expected MAJOR.MINOR.PATCH[-label])." >&2
  exit 1
fi
build_name="${BASH_REMATCH[1]}"

case "$(uname -m)" in
  x86_64|amd64) arch=x64; deb_arch=amd64 ;;
  aarch64|arm64) arch=arm64; deb_arch=arm64 ;;
  *) echo "Unsupported architecture $(uname -m)." >&2; exit 1 ;;
esac
base_name="Serlink-$version-linux-$arch"
app_id="com.alkinum.serlink"

echo "Serlink $version (build $build_number, linux-$arch)"

if [[ $skip_build -eq 0 ]]; then
  flutter build linux --release \
    --build-name="$build_name" \
    --build-number="$build_number" \
    --dart-define=SERLINK_DISTRIBUTION=direct
fi

bundle="$root/build/linux/$arch/release/bundle"
[[ -d "$bundle" ]] || { echo "Release bundle not found at $bundle." >&2; exit 1; }

# Fail on a bundle that would not start on a clean install.
required=(
  serlink
  lib/libapp.so
  lib/libflutter_linux_gtk.so
  lib/libflutter_pty.so
  lib/libsqlite3.so
  data/icudtl.dat
  data/flutter_assets
  "data/icons/$app_id.png"
)
missing=()
for path in "${required[@]}"; do
  [[ -e "$bundle/$path" ]] || missing+=("$path")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Release bundle is incomplete. Missing: ${missing[*]}" >&2
  exit 1
fi
unresolved="$(cd "$bundle" && for f in serlink lib/*.so; do
  ldd "$f" | sed -n "s|^[[:space:]]*\(.*not found\)|$f: \1|p"
done)"
if [[ -n "$unresolved" ]]; then
  echo "Release bundle has unresolved shared libraries:" >&2
  echo "$unresolved" >&2
  exit 1
fi
# Use the newest required symbol, including patch versions, for the package dependency.
glibc="$(cd "$bundle" && objdump -T serlink lib/*.so \
  | grep -oE 'GLIBC_[0-9]+(\.[0-9]+)+' | sort -Vu | tail -1)"
glibc="${glibc#GLIBC_}"
echo "Requires GLIBC_$glibc"
if [[ -n "${SERLINK_MAX_GLIBC:-}" ]] && dpkg --compare-versions "$glibc" gt "$SERLINK_MAX_GLIBC"; then
  echo "Bundle requires glibc $glibc, above the release baseline $SERLINK_MAX_GLIBC." >&2
  exit 1
fi

dist="$root/build/dist/linux"
rm -rf "$dist"
mkdir -p "$dist"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

# Portable archive with a top-level Serlink folder.
mkdir -p "$staging/tar/Serlink"
cp -a "$bundle/." "$staging/tar/Serlink/"
cp LICENSE NOTICE "$staging/tar/Serlink/"
tar -C "$staging/tar" --owner=0 --group=0 --numeric-owner \
  -czf "$dist/$base_name.tar.gz" Serlink
echo "Created $dist/$base_name.tar.gz"

if [[ $skip_deb -eq 0 ]]; then
  pkg="$staging/deb"
  mkdir -p "$pkg/DEBIAN" "$pkg/opt/serlink" "$pkg/usr/bin" \
    "$pkg/usr/share/applications" "$pkg/usr/share/doc/serlink"
  cp -a "$bundle/." "$pkg/opt/serlink/"
  ln -s ../../opt/serlink/serlink "$pkg/usr/bin/serlink"
  cp "linux/share/applications/$app_id.desktop" "$pkg/usr/share/applications/"
  cp -a linux/share/icons "$pkg/usr/share/"
  cat LICENSE NOTICE > "$pkg/usr/share/doc/serlink/copyright"
  find "$pkg" -type d -exec chmod 0755 {} +
  find "$pkg" -type f -exec chmod 0644 {} +
  chmod 0755 "$pkg/opt/serlink/serlink"
  find "$pkg/opt/serlink/lib" -name '*.so' -exec chmod 0755 {} +

  # Debian orders 1.2.0~beta.1 before 1.2.0, unlike a '-' suffix.
  deb_version="$version"
  if [[ "$version" == "$build_name"-* ]]; then
    deb_version="$build_name~${version#"$build_name"-}"
  fi
  installed_size="$(du -sk --exclude=DEBIAN "$pkg" | cut -f1)"
  cat > "$pkg/DEBIAN/control" <<EOF
Package: serlink
Version: $deb_version
Architecture: $deb_arch
Maintainer: BackRunner
Installed-Size: $installed_size
Depends: libc6 (>= $glibc), libgtk-3-0t64 | libgtk-3-0, libsecret-1-0
Section: net
Priority: optional
Homepage: https://serlink.alkinum.com
Description: SSH terminal and SFTP workspace
 Serlink brings SSH sessions, local terminal tabs, SFTP transfers, host
 profiles, command snippets and encrypted sync into one desktop app.
 Secrets are kept in the desktop Secret Service keyring.
EOF
  dpkg-deb --root-owner-group --build "$pkg" "$dist/$base_name.deb" >/dev/null
  echo "Created $dist/$base_name.deb"
fi

(cd "$dist" && shopt -s nullglob && sha256sum -- *.tar.gz *.deb > "SHA256SUMS-linux-$arch.txt")
cat "$dist/SHA256SUMS-linux-$arch.txt"
