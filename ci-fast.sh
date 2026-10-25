#!/usr/bin/env bash
# Fast iteration CI: build + smoke invocation only.
# All validation logic lives in tests/check_cobol_c_errors.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "=== BUILD ==="
./build.sh

echo "=== SMOKE ==="
printf 'PING||||||\n' > input.txt
./cobol/bin/main_logic
out="$(cat output.txt)"
echo "PING -> $out"
echo "$out" | grep -q 'SUCCESS|PONG' || { echo "FAIL: smoke failed"; exit 1; }

echo "=== CI-FAST GREEN ==="
