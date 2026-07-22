#!/usr/bin/env bash

verify_sha256() {
  local expected="$1"
  local file="$2"
  local actual

  if [[ ! -f "$file" ]]; then
    echo "Checksum input does not exist: $file" >&2
    return 1
  fi

  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "SHA-256 mismatch for $file" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    return 1
  fi
}

assert_architecture() {
  local binary="$1"
  local expected_arch="$2"

  if ! lipo "$binary" -verify_arch "$expected_arch" >/dev/null 2>&1; then
    echo "Expected $binary to contain architecture $expected_arch" >&2
    lipo -archs "$binary" >&2 || true
    return 1
  fi
}

assert_system_linkage() {
  local binary="$1"
  local dependency
  local invalid=0
  local line
  local linkage_output

  if ! lipo "$binary" -archs >/dev/null 2>&1; then
    echo "Not a Mach-O binary: $binary" >&2
    return 1
  fi

  if ! linkage_output="$(otool -L "$binary" 2>&1)"; then
    echo "Could not inspect dynamic dependencies for $binary" >&2
    echo "$linkage_output" >&2
    return 1
  fi

  while IFS= read -r line; do
    [[ "$line" == *: ]] && continue
    read -r dependency _ <<<"$line"
    [[ -n "$dependency" ]] || continue
    case "$dependency" in
      /usr/lib/*|/System/Library/*)
        ;;
      *)
        echo "Unexpected non-system dynamic dependency: $dependency" >&2
        invalid=1
        ;;
    esac
  done <<<"$linkage_output"

  return "$invalid"
}
