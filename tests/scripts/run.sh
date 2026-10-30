#!/usr/bin/env bash
# Minimal harness for tests/scripts/test_*.sh (no database, no build).
# Runs every test_*.sh in this directory and fails when any of them fails.
# Usage: tests/scripts/run.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

passed=0
failed=0
failed_names=""

for t in tests/scripts/test_*.sh; do
    [ -f "$t" ] || continue
    echo "=== $t ==="
    if bash "$t"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        failed_names="$failed_names $t"
    fi
done

echo "=== SCRIPTS: $passed passed, $failed failed ==="
if [ "$failed" -ne 0 ]; then
    echo "FAIL:$failed_names"
    exit 1
fi
echo "=== SCRIPTS GREEN ==="
