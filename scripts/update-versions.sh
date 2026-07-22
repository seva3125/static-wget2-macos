#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
target="${1:-$repo_root/versions.env}"
target_dir="$(cd "$(dirname "$target")" && pwd)"
candidate="$(mktemp "$target_dir/.versions.env.XXXXXX")"

cleanup() {
  if [[ -f "$candidate" ]]; then
    rm -f "$candidate"
  fi
}
trap cleanup EXIT

"$script_dir/resolve-versions.sh" > "$candidate"
chmod 0644 "$candidate"

if [[ -f "$target" ]] && cmp -s "$candidate" "$target"; then
  changed=false
else
  mv "$candidate" "$target"
  changed=true
fi

printf 'changed=%s\n' "$changed"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'changed=%s\n' "$changed" >> "$GITHUB_OUTPUT"
fi
