#!/bin/bash
# Build-warning ratchet: the COBOL build must not introduce new warnings.
# Counts per class are frozen in tests/warning_baseline.txt; a class above its
# baseline fails. Lower a baseline when warnings are fixed; never raise one to
# accept new warnings (docs/BUILD_WARNINGS.md explains the classes).
#
# Usage: ./tests/warning_check.sh [build-log]
#   With no argument it runs ./build.sh itself; CI passes the step-3 build log.
set -e
cd "$(dirname "$0")/.."

LOG="$1"
CLEANUP=""
if [ -z "$LOG" ]; then
    LOG="$(mktemp)"
    CLEANUP="$LOG"
    ./build.sh > "$LOG" 2>&1
fi

fail=0
while read -r cls base; do
    case "$cls" in ''|\#*) continue ;; esac
    actual="$(grep -c -- "warning:.*\[-W${cls}\]" "$LOG" 2>/dev/null || true)"
    if [ "$actual" -gt "$base" ]; then
        echo "warning class -W${cls}: $actual (baseline $base) — new warnings are not allowed"
        fail=1
    else
        echo "warning class -W${cls}: $actual (baseline $base)"
    fi
done < tests/warning_baseline.txt

total="$(grep -c "warning:" "$LOG" 2>/dev/null || true)"
echo "total warnings: $total"
[ -z "$CLEANUP" ] || rm -f "$CLEANUP"

if [ "$fail" -ne 0 ]; then
    echo "WARNING RATCHET FAILED"
    exit 1
fi
echo "warning ratchet OK"
