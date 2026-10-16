#!/bin/bash
# Assertion-count baseline: every suite in this CI run must report exactly the
# pass count in tests/baseline_counts.txt. Deleting (or silently losing)
# assertions changes the count and fails here, so coverage cannot shrink
# unnoticed. When a suite deliberately gains or loses assertions, update the
# manifest (and docs/STATUS.md) in the same change.
# Usage: ./tests/baseline_check.sh <actuals-file>  (lines: "<suite> <passes>")

set -e

ACTUALS="${1:?usage: baseline_check.sh <actuals-file>}"
BASE="tests/baseline_counts.txt"
[ -f "$BASE" ] || { echo "baseline manifest missing: $BASE"; exit 1; }
[ -f "$ACTUALS" ] || { echo "baseline actuals missing: $ACTUALS"; exit 1; }

fail=0

while read -r suite expected rest; do
    case "$suite" in ''|'#'*) continue;; esac
    [ -z "$rest" ] || { echo "baseline: bad manifest line for '$suite'"; fail=1; continue; }
    case "$expected" in ''|*[!0-9]*) echo "baseline: non-numeric expectation for '$suite'"; fail=1; continue;; esac
    got="$(awk -v s="$suite" '$1 == s {print $2}' "$ACTUALS" | head -1)"
    if [ -z "$got" ]; then
        echo "baseline: suite '$suite' did not report a count"
        fail=1
    elif [ "$got" != "$expected" ]; then
        echo "baseline: suite '$suite' reported $got passes, expected $expected"
        fail=1
    fi
done < "$BASE"

while read -r suite got _; do
    case "$suite" in ''|'#'*) continue;; esac
    if ! grep -qE "^${suite} [0-9]+$" "$BASE"; then
        echo "baseline: suite '$suite' reported but has no manifest entry"
        fail=1
    fi
done < "$ACTUALS"

[ "$fail" -eq 0 ] || { echo "BASELINE CHECK FAILED"; exit 1; }
echo "baseline check OK"
