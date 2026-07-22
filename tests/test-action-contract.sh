#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_files=(
  action.yml
  versions.env
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

assert_empty_action_default() {
  local input_name="$1"

  awk -v input_name="$input_name" '
    $0 == "  " input_name ":" { in_input = 1; next }
    in_input && /^  [a-z0-9-]+:$/ { exit }
    in_input && /^[[:space:]]+default: ""$/ { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$repo_root/action.yml"
}

for input_name in \
  wget2-version wget2-sha256 \
  openssl-version openssl-sha256 \
  zlib-version zlib-sha256; do
  assert_empty_action_default "$input_name"
done

grep -Fq 'source "$script_dir/../versions.env"' "$repo_root/scripts/build.sh"
grep -Fq 'source "$script_dir/../versions.env"' "$repo_root/scripts/test.sh"
grep -Fq 'wget2_version="${WGET2_VERSION:-$WGET2_VERSION_DEFAULT}"' \
  "$repo_root/scripts/build.sh"
grep -Fq 'openssl_version="${OPENSSL_VERSION:-$OPENSSL_VERSION_DEFAULT}"' \
  "$repo_root/scripts/build.sh"
grep -Fq 'zlib_version="${ZLIB_VERSION:-$ZLIB_VERSION_DEFAULT}"' \
  "$repo_root/scripts/build.sh"

for variable_name in \
  WGET2_VERSION WGET2_SHA256 \
  OPENSSL_VERSION OPENSSL_SHA256 \
  ZLIB_VERSION ZLIB_SHA256; do
  grep -Fq "$variable_name:" "$repo_root/action.yml"
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
grep -Fq 'expected_version="${WGET2_VERSION:-$WGET2_VERSION_DEFAULT}"' \
  "$repo_root/scripts/test.sh"

echo "PASS: Action contract tests"
