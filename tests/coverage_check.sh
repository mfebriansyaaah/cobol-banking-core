#!/bin/bash
# Coverage gate: COBOL statement coverage (mapped from the generated C) and
# gateway line/branch coverage, checked against the documented floors and the
# ratchet baseline. Coverage is a floor, not a correctness claim.
#
# Usage:
#   tests/coverage_check.sh                       # run both measurements
#   tests/coverage_check.sh --no-cobol            # parse the gateway report only
#   tests/coverage_check.sh --gateway-report F    # reuse a gateway run's output
#
# The CI gateway step runs the suite with --experimental-test-coverage and
# leaves its output in /tmp/opencode/gateway.out, so the gate does not repeat
# the 60-second run.
set -euo pipefail
cd "$(dirname "$0")/.."

BASELINE="tests/coverage_baseline.txt"
FLOOR=30
TOLERANCE=1.0
RUN_COBOL=1
RUN_GATEWAY=1
GATEWAY_REPORT="/tmp/opencode/gateway.out"
COBOL_JSON=""

while [ $# -gt 0 ]; do
    case "$1" in
        --no-cobol) RUN_COBOL=0 ;;
        --no-gateway) RUN_GATEWAY=0 ;;
        --gateway-report) GATEWAY_REPORT="$2"; shift ;;
        *) echo "usage: $0 [--no-cobol] [--no-gateway] [--gateway-report FILE]" >&2; exit 2 ;;
    esac
    shift
done

[ -f "$BASELINE" ] || { echo "coverage baseline missing: $BASELINE"; exit 1; }
base() { awk -v k="$1" '$1==k {print $2}' "$BASELINE"; }

fail=0
check_floor() {
    local name="$1" value="$2" floor="$3" baseline="$4"
    local ok
    ok=$(awk -v v="$value" -v f="$floor" -v b="$baseline" -v t="$TOLERANCE" \
        'BEGIN { if (v < f) print "floor"; else if (b != "" && v < b - t) print "ratchet"; else print "ok" }')
    case "$ok" in
        floor) echo "FAIL $name: $value% is below the ${floor}% floor"; fail=1 ;;
        ratchet) echo "FAIL $name: $value% dropped below the baseline ${baseline}% (tolerance ${TOLERANCE}pp)"; fail=1 ;;
        *) echo "PASS $name: ${value}% (floor ${floor}%, baseline ${baseline:-n/a}%)" ;;
    esac
}

if [ "$RUN_COBOL" -eq 1 ]; then
    COBOL_JSON="$(./scripts/coverage_cobol.sh --json --min "$FLOOR" 2>/dev/null || true)"
    if [ -z "$COBOL_JSON" ]; then
        echo "FAIL cobol coverage: the measurement produced no result"
        fail=1
    else
        total=$(printf '%s' "$COBOL_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["percent"])')
        check_floor "cobol-total" "$total" "$FLOOR" "$(base cobol_total)"
        printf '%s' "$COBOL_JSON" | python3 -c '
import json, sys
r = json.load(sys.stdin)
for m in r["modules"]:
    print("  cobol %-12s %6d/%-6d %6.2f%%" % (m["module"], m["covered"], m["executable"], m["percent"]))
'
    fi
fi

if [ "$RUN_GATEWAY" -eq 1 ]; then
    # Reuse a report only when it is both complete and recent: a stale report
    # from an earlier run would measure the wrong revision.
    fresh=0
    if [ -f "$GATEWAY_REPORT" ] && grep -q 'end of coverage report' "$GATEWAY_REPORT"; then
        if [ -n "$(find "$GATEWAY_REPORT" -mmin -60 2>/dev/null)" ]; then
            fresh=1
        fi
    fi
    if [ "$fresh" -eq 0 ]; then
        echo "== running the gateway suite with coverage ==" >&2
        ( cd middleware && node --import ./preload.mjs --test \
            --experimental-test-coverage \
            --test-coverage-lines="$FLOOR" --test-coverage-branches="$FLOOR" \
            --test-coverage-include='src/**' >"$GATEWAY_REPORT" 2>&1 ) || {
            echo "FAIL gateway coverage: the suite did not pass"
            tail -20 "$GATEWAY_REPORT"
            exit 1
        }
    fi
    summary="$(grep -E '^ℹ all files' "$GATEWAY_REPORT" | tail -1)"
    if [ -z "$summary" ]; then
        echo "FAIL gateway coverage: no summary in $GATEWAY_REPORT"
        fail=1
    else
        lines=$(printf '%s' "$summary" | awk -F'|' '{gsub(/ /,"",$2); print $2}')
        branches=$(printf '%s' "$summary" | awk -F'|' '{gsub(/ /,"",$3); print $3}')
        check_floor "gateway-lines" "$lines" "$FLOOR" "$(base gateway_lines)"
        check_floor "gateway-branches" "$branches" "$FLOOR" "$(base gateway_branches)"
    fi
fi

if [ "$fail" -ne 0 ]; then
    echo "COVERAGE GATE FAILED"
    exit 1
fi
echo "coverage gate OK"
