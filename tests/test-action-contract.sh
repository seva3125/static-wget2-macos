#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_files=(
  action.yml
  scripts/build.sh
  scripts/test.sh
  .github/workflows/build.yml
)

for relative_path in "${required_files[@]}"; do
  if [[ ! -f "$repo_root/$relative_path" ]]; then
    echo "FAIL: missing $relative_path" >&2
    exit 1
  fi
done

grep -Eq 'using:[[:space:]]*["'\'']?composite' "$repo_root/action.yml"
grep -Fq 'macos-15' "$repo_root/.github/workflows/build.yml"
grep -Fq 'macos-15-intel' "$repo_root/.github/workflows/build.yml"
grep -Fq 'lipo -create' "$repo_root/.github/workflows/build.yml"

if grep -Eq '^(OPENSSL_LIBS|ZLIB_LIBS)=.*lib(ssl|crypto|z)\.a' "$repo_root/scripts/build.sh"; then
  echo "FAIL: direct dependency archives break wget2 libtool linking on macOS" >&2
  exit 1
fi
grep -Fq 'OPENSSL_LIBS="-L$prefix/lib -lssl -lcrypto' "$repo_root/scripts/build.sh"
grep -Fq 'ZLIB_LIBS="-L$prefix/lib -lz"' "$repo_root/scripts/build.sh"

if grep -Eq 'uses: actions/(checkout|upload-artifact|download-artifact)@v[0-9]' \
  "$repo_root/.github/workflows/build.yml"; then
  echo "FAIL: first-party Actions must be pinned to immutable commits" >&2
  exit 1
fi

grep -Fq 'version_output="$("$binary" --version)"' "$repo_root/scripts/test.sh"
grep -Fq 'expected_version="${WGET2_VERSION:-2.2.1}"' "$repo_root/scripts/test.sh"

echo "PASS: Action contract tests"
