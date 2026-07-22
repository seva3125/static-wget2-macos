#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=../scripts/lib.sh
source "$repo_root/scripts/lib.sh"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

printf 'static wget2 fixture\n' > "$test_dir/fixture.txt"
fixture_sha="$(shasum -a 256 "$test_dir/fixture.txt" | awk '{print $1}')"

cat > "$test_dir/fixture.c" <<'EOF'
int main(void) { return 0; }
EOF
cc -arch "$(uname -m)" "$test_dir/fixture.c" -o "$test_dir/fixture"
cc -arch arm64 "$test_dir/fixture.c" -o "$test_dir/fixture-arm64"
cc -arch x86_64 "$test_dir/fixture.c" -o "$test_dir/fixture-x86_64"
lipo -create \
  "$test_dir/fixture-arm64" \
  "$test_dir/fixture-x86_64" \
  -output "$test_dir/fixture-universal"

verify_sha256 "$fixture_sha" "$test_dir/fixture.txt"

if verify_sha256 "$(printf '0%.0s' {1..64})" "$test_dir/fixture.txt" 2>/dev/null; then
  echo "FAIL: verify_sha256 accepted an incorrect digest" >&2
  exit 1
fi

assert_architecture "$test_dir/fixture" "$(uname -m)"
assert_system_linkage "$test_dir/fixture"
assert_system_linkage "$test_dir/fixture-universal"

if assert_system_linkage "$test_dir/fixture.txt" 2>/dev/null; then
  echo "FAIL: assert_system_linkage ignored an otool failure" >&2
  exit 1
fi

echo "PASS: shell helper tests"
