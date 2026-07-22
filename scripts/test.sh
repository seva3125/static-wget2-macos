#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$script_dir/lib.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/wget2" >&2
  exit 2
fi

binary="$1"
case "$binary" in
  /*) ;;
  *) binary="$PWD/$binary" ;;
esac

if [[ ! -x "$binary" ]]; then
  echo "Binary is not executable: $binary" >&2
  exit 1
fi

assert_architecture "$binary" "$(uname -m)"
assert_system_linkage "$binary"

expected_version="${WGET2_VERSION:-2.2.1}"
version_output="$("$binary" --version)"
grep -Fq "GNU Wget2 $expected_version" <<<"$version_output"
grep -Eiq 'openssl' <<<"$version_output"
grep -Eiq 'zlib' <<<"$version_output"

test_root="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/test-wget2.XXXXXX")"
serve_dir="$test_root/serve"
port_file="$test_root/port"
mkdir -p "$serve_dir"
printf 'wget2 static binary smoke test\n' > "$serve_dir/fixture.txt"

server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$test_root"
}
trap cleanup EXIT

python3 - "$serve_dir" "$port_file" >"$test_root/http.log" 2>&1 <<'PY' &
import http.server
import os
import socketserver
import sys

os.chdir(sys.argv[1])
with socketserver.TCPServer(("127.0.0.1", 0), http.server.SimpleHTTPRequestHandler) as server:
    with open(sys.argv[2], "w", encoding="utf-8") as port_file:
        port_file.write(str(server.server_address[1]))
    server.serve_forever()
PY
server_pid="$!"

for _ in {1..100}; do
  [[ -s "$port_file" ]] && break
  sleep 0.05
done

if [[ ! -s "$port_file" ]]; then
  echo "Local test server did not start" >&2
  cat "$test_root/http.log" >&2
  exit 1
fi

port="$(<"$port_file")"
"$binary" --no-config --quiet --output-document="$test_root/downloaded.txt" \
  "http://127.0.0.1:$port/fixture.txt"

expected="$(shasum -a 256 "$serve_dir/fixture.txt" | awk '{print $1}')"
verify_sha256 "$expected" "$test_root/downloaded.txt"

echo "PASS: wget2 artifact smoke test"
