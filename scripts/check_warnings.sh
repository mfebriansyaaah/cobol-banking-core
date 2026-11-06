#!/usr/bin/env bash
# Warning ratchet for the core modules.
#
# Usage:
#   scripts/check_warnings.sh [build.log]   compare with tests/warning_baseline.txt
#   scripts/check_warnings.sh --print [log] print current counts, do not fail
#
# The log is the stderr+stdout of ./build.sh. Every core module must be
# listed: an unlisted module escapes the ratchet entirely. When a domain is
# finished, add its modules with their current count (ideally zero), then
# lower the numbers as warnings are fixed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tests/warning_baseline.txt"
PRINT=0
if [ "${1:-}" = "--print" ]; then
    PRINT=1
    shift
fi
LOG="${1:-/tmp/build.log}"

if [ ! -f "$LOG" ]; then
    echo "FAIL: build log not found: $LOG" >&2
    exit 2
fi

# Completeness (CI-014): every cobol/src/*_core.cob plus the dispatcher and
# the C bridge must have a baseline entry. A new core module without one
# would never be checked.
missing=""
for src in "$ROOT"/cobol/src/*_core.cob "$ROOT"/cobol/src/main_logic.cob "$ROOT"/cobol/src/sql_bridge.c; do
    mod="$(basename "$src")"
    if ! grep -qE "^${mod}=" "$BASE"; then
        missing="$missing $mod"
    fi
done
if [ -n "$missing" ]; then
    echo "FAIL: core modules without a warning_baseline.txt entry:$missing" >&2
    echo "Add each with its current count (see --print), then commit the baseline." >&2
    exit 1
fi

count_for() {
    # Compiler diagnostics look like:
    #   cobol/src/main_logic.cob:43: warning: ...
    #   cobol/src/sql_bridge.c:12:3: warning: ...
    grep -cE "cobol/src/$1:[0-9]+(:[0-9]+)?: warning:" "$LOG" || true
}

fail=0
total=0
printf '%-28s %8s %8s\n' "module" "actual" "baseline"
while IFS='=' read -r file expected; do
    case "$file" in ''|\#*) continue ;; esac
    expected="${expected//[[:space:]]/}"
    actual="$(count_for "$file")"
    total=$((total + actual))
    printf '%-28s %8s %8s\n' "$file" "$actual" "$expected"
    if [ "$PRINT" -eq 0 ] && [ "$actual" -gt "$expected" ]; then
        echo "FAIL: $file has $actual warnings, baseline is $expected" >&2
        fail=1
    fi
done < "$BASE"

echo "core warnings: $total"
if [ "$PRINT" -eq 1 ]; then
    exit 0
fi
if [ "$fail" -ne 0 ]; then
    echo "Fix the regression, or lower the baseline after an intentional fix." >&2
    exit 1
fi
echo "OK: no core warning regression"
