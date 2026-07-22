#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
parser="$script_dir/resolve-versions.py"
temp_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/static-wget2-versions.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT

fetch_release() {
  local component="$1"
  local repository="$2"
  local destination="$temp_dir/$component-release.json"
  local -a curl_args=(
    --fail
    --silent
    --show-error
    --location
    --retry 3
    --header "Accept: application/vnd.github+json"
    --header "X-GitHub-Api-Version: 2022-11-28"
  )

  if [[ -n "${RELEASE_FIXTURE_DIR:-}" ]]; then
    cp "$RELEASE_FIXTURE_DIR/$component-release.json" "$destination"
  else
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      curl_args+=(--header "Authorization: Bearer $GITHUB_TOKEN")
    fi
    curl "${curl_args[@]}" \
      "https://api.github.com/repos/$repository/releases/latest" \
      --output "$destination"
  fi

  printf '%s\n' "$destination"
}

wget2_json="$(fetch_release wget2 rockdaboot/wget2)"
openssl_json="$(fetch_release openssl openssl/openssl)"
zlib_json="$(fetch_release zlib madler/zlib)"

IFS=$'\t' read -r wget2_version _wget2_url wget2_sha256 < <(
  python3 "$parser" "$wget2_json" v 'wget2-{version}.tar.gz'
)
IFS=$'\t' read -r openssl_version _openssl_url openssl_sha256 < <(
  python3 "$parser" "$openssl_json" openssl- 'openssl-{version}.tar.gz'
)
IFS=$'\t' read -r zlib_version _zlib_url zlib_sha256 < <(
  python3 "$parser" "$zlib_json" v 'zlib-{version}.tar.gz'
)

printf '%s\n' \
  "WGET2_VERSION_DEFAULT=$wget2_version" \
  "WGET2_SHA256_DEFAULT=$wget2_sha256" \
  "OPENSSL_VERSION_DEFAULT=$openssl_version" \
  "OPENSSL_SHA256_DEFAULT=$openssl_sha256" \
  "ZLIB_VERSION_DEFAULT=$zlib_version" \
  "ZLIB_SHA256_DEFAULT=$zlib_sha256"
