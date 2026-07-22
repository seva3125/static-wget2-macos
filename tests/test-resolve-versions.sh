#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
parser="$repo_root/scripts/resolve-versions.py"
fixtures="$repo_root/tests/fixtures"
resolver="$repo_root/scripts/resolve-versions.sh"
updater="$repo_root/scripts/update-versions.sh"

assert_equals() {
  local expected="$1"
  local actual="$2"

  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

wget2_result="$(python3 "$parser" \
  "$fixtures/wget2-release.json" v 'wget2-{version}.tar.gz')"
assert_equals $'2.2.1\thttps://github.com/rockdaboot/wget2/releases/download/v2.2.1/wget2-2.2.1.tar.gz\td7544b13e37f18e601244fce5f5f40688ac1d6ab9541e0fbb01a32ee1fb447b4' \
  "$wget2_result"

openssl_result="$(python3 "$parser" \
  "$fixtures/openssl-release.json" openssl- 'openssl-{version}.tar.gz')"
assert_equals $'4.0.1\thttps://github.com/openssl/openssl/releases/download/openssl-4.0.1/openssl-4.0.1.tar.gz\t2db3f3a0d6ea4b59e1f094ace2c8cd536dffb87cdc39084c5afa1e6f7f37dd09' \
  "$openssl_result"

zlib_result="$(python3 "$parser" \
  "$fixtures/zlib-release.json" v 'zlib-{version}.tar.gz')"
assert_equals $'1.3.2\thttps://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz\tbb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16' \
  "$zlib_result"

if python3 "$parser" \
  "$fixtures/malformed-release.json" v 'wget2-{version}.tar.gz' 2>/dev/null; then
  echo "FAIL: malformed digest accepted" >&2
  exit 1
fi

if python3 "$parser" \
  "$fixtures/wget2-release.json" release- 'wget2-{version}.tar.gz' 2>/dev/null; then
  echo "FAIL: unexpected tag prefix accepted" >&2
  exit 1
fi

if python3 "$parser" \
  "$fixtures/wget2-release.json" v 'missing-{version}.tar.gz' 2>/dev/null; then
  echo "FAIL: missing source asset accepted" >&2
  exit 1
fi

expected_manifest=$'WGET2_VERSION_DEFAULT=2.2.1\nWGET2_SHA256_DEFAULT=d7544b13e37f18e601244fce5f5f40688ac1d6ab9541e0fbb01a32ee1fb447b4\nOPENSSL_VERSION_DEFAULT=4.0.1\nOPENSSL_SHA256_DEFAULT=2db3f3a0d6ea4b59e1f094ace2c8cd536dffb87cdc39084c5afa1e6f7f37dd09\nZLIB_VERSION_DEFAULT=1.3.2\nZLIB_SHA256_DEFAULT=bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16'
resolved_manifest="$(RELEASE_FIXTURE_DIR="$fixtures" "$resolver")"
assert_equals "$expected_manifest" "$resolved_manifest"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
manifest="$test_dir/versions.env"
printf '%s\n' "$expected_manifest" > "$manifest"

unchanged_output="$(RELEASE_FIXTURE_DIR="$fixtures" "$updater" "$manifest")"
assert_equals "changed=false" "$unchanged_output"
assert_equals "$expected_manifest" "$(<"$manifest")"

sed 's/OPENSSL_VERSION_DEFAULT=4.0.1/OPENSSL_VERSION_DEFAULT=3.5.7/' \
  "$manifest" > "$manifest.stale"
mv "$manifest.stale" "$manifest"
changed_output="$(RELEASE_FIXTURE_DIR="$fixtures" "$updater" "$manifest")"
assert_equals "changed=true" "$changed_output"
assert_equals "$expected_manifest" "$(<"$manifest")"

mkdir "$test_dir/malformed"
cp "$fixtures/wget2-release.json" "$test_dir/malformed/wget2-release.json"
cp "$fixtures/openssl-release.json" "$test_dir/malformed/openssl-release.json"
cp "$fixtures/malformed-release.json" "$test_dir/malformed/zlib-release.json"
printf '%s\n' "$expected_manifest" > "$manifest"
if RELEASE_FIXTURE_DIR="$test_dir/malformed" \
  "$updater" "$manifest" >/dev/null 2>&1; then
  echo "FAIL: updater accepted malformed release metadata" >&2
  exit 1
fi
assert_equals "$expected_manifest" "$(<"$manifest")"

echo "PASS: release metadata resolver tests"
