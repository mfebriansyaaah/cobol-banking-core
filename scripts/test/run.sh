#!/usr/bin/env bash
# Harness for scripts/test/*.test.mjs (gate unit tests, P1-9). No database, no build.
# Runs every gate unit test in this directory and fails when any of them fails.
# Usage: scripts/test/run.sh  (or: npm run test:scripts)
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

passed=0
failed=0
failed_names=""

for t in scripts/test/*.test.mjs; do
    [ -f "$t" ] || continue
    echo "=== $t ==="
    if node --test "$t" 2>&1 | tail -5; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        failed_names="$failed_names $t"
    fi
done

echo "=== GATE TESTS: $passed passed, $failed failed ==="
if [ "$failed" -ne 0 ]; then
    echo "FAIL:$failed_names"
    exit 1
fi
echo "=== GATE TESTS GREEN ==="
