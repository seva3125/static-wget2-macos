#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"
# shellcheck source=../versions.env
source "$script_dir/../versions.env"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This Action builds wget2 on macOS only." >&2
  exit 1
fi

output="${1:-dist/wget2}"
case "$output" in
  /*) ;;
  *) output="$PWD/$output" ;;
esac

wget2_version="${WGET2_VERSION:-$WGET2_VERSION_DEFAULT}"
wget2_sha256="${WGET2_SHA256:-$WGET2_SHA256_DEFAULT}"
openssl_version="${OPENSSL_VERSION:-$OPENSSL_VERSION_DEFAULT}"
openssl_sha256="${OPENSSL_SHA256:-$OPENSSL_SHA256_DEFAULT}"
zlib_version="${ZLIB_VERSION:-$ZLIB_VERSION_DEFAULT}"
zlib_sha256="${ZLIB_SHA256:-$ZLIB_SHA256_DEFAULT}"
deployment_target="${MACOSX_DEPLOYMENT_TARGET:-13.0}"

arch="$(uname -m)"
case "$arch" in
  arm64)
    openssl_target="darwin64-arm64-cc"
    ;;
  x86_64)
    openssl_target="darwin64-x86_64-cc"
    ;;
  *)
    echo "Unsupported macOS architecture: $arch" >&2
    exit 1
    ;;
esac

temp_parent="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
build_root="$(mktemp -d "$temp_parent/static-wget2.XXXXXX")"
prefix="$build_root/prefix"
install_prefix="$build_root/install"
mkdir -p "$prefix" "$install_prefix"

cleanup() {
  if [[ "${KEEP_BUILD_DIR:-0}" == "1" ]]; then
    echo "Preserving build directory: $build_root"
  else
    rm -rf "$build_root"
  fi
}
trap cleanup EXIT

jobs="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 3)"

download() {
  local url="$1"
  local destination="$2"

  echo "Downloading $url"
  curl --fail --location --retry 3 --retry-delay 2 --output "$destination" "$url"
}

export MACOSX_DEPLOYMENT_TARGET="$deployment_target"

wget2_archive="$build_root/wget2-$wget2_version.tar.gz"
openssl_archive="$build_root/openssl-$openssl_version.tar.gz"
zlib_archive="$build_root/zlib-$zlib_version.tar.gz"

download "https://github.com/rockdaboot/wget2/releases/download/v$wget2_version/wget2-$wget2_version.tar.gz" "$wget2_archive"
download "https://github.com/openssl/openssl/releases/download/openssl-$openssl_version/openssl-$openssl_version.tar.gz" "$openssl_archive"
download "https://github.com/madler/zlib/releases/download/v$zlib_version/zlib-$zlib_version.tar.gz" "$zlib_archive"

verify_sha256 "$wget2_sha256" "$wget2_archive"
verify_sha256 "$openssl_sha256" "$openssl_archive"
verify_sha256 "$zlib_sha256" "$zlib_archive"

tar -xzf "$openssl_archive" -C "$build_root"
pushd "$build_root/openssl-$openssl_version" >/dev/null
./Configure "$openssl_target" no-shared no-module no-tests \
  --prefix="$prefix" \
  --openssldir=/etc/ssl
make -j"$jobs"
make install_sw
popd >/dev/null

tar -xzf "$zlib_archive" -C "$build_root"
pushd "$build_root/zlib-$zlib_version" >/dev/null
CFLAGS="-O2 -mmacosx-version-min=$deployment_target" \
  ./configure --static --prefix="$prefix"
make -j"$jobs"
make install
popd >/dev/null

tar -xzf "$wget2_archive" -C "$build_root"
pushd "$build_root/wget2-$wget2_version" >/dev/null
PKG_CONFIG_LIBDIR="$prefix/lib/pkgconfig" \
PKG_CONFIG_PATH="$prefix/lib/pkgconfig" \
CPPFLAGS="-I$prefix/include" \
CFLAGS="-O2 -mmacosx-version-min=$deployment_target" \
LDFLAGS="-L$prefix/lib -Wl,-search_paths_first -mmacosx-version-min=$deployment_target" \
OPENSSL_CFLAGS="-I$prefix/include" \
OPENSSL_LIBS="-L$prefix/lib -lssl -lcrypto -framework CoreFoundation -framework Security" \
ZLIB_CFLAGS="-I$prefix/include" \
ZLIB_LIBS="-L$prefix/lib -lz" \
./configure \
  --prefix="$install_prefix" \
  --enable-static \
  --disable-shared \
  --disable-doc \
  --disable-nls \
  --with-ssl=openssl \
  --with-openssl=auto-gpl-compat \
  --without-libdane \
  --without-libpsl \
  --without-libhsts \
  --without-libnghttp2 \
  --without-gpgme \
  --without-bzip2 \
  --with-zlib \
  --without-lzma \
  --without-brotlidec \
  --without-zstd \
  --without-lzip \
  --without-libidn2 \
  --without-libidn \
  --without-libpcre2 \
  --without-libpcre \
  --without-libmicrohttpd \
  --without-plugin-support
make -j"$jobs"
make install
popd >/dev/null

mkdir -p "$(dirname "$output")"
install -m 0755 "$install_prefix/bin/wget2" "$output"
strip -S "$output"

assert_architecture "$output" "$arch"
assert_system_linkage "$output"

echo "Built $output"
file "$output"
otool -L "$output"
