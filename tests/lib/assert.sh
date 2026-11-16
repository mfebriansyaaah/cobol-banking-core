# shellcheck shell=bash
# TAP-style assertion helpers. Sourced by runners.
# Counters are maintained in the sourcing script's globals: T_PASS, T_FAIL, T_TOTAL.
T_PASS="${T_PASS:-0}"
T_FAIL="${T_FAIL:-0}"
T_TOTAL="${T_TOTAL:-0}"

# ok <name> <actual_output> <expected_regex>
assert_match() {
    local name="$1"
    local actual="$2"
    local expected="$3"
    T_TOTAL=$((T_TOTAL + 1))
    if printf '%s' "$actual" | grep -Eq "$expected"; then
        T_PASS=$((T_PASS + 1))
        echo "ok $T_TOTAL - $name"
    else
        T_FAIL=$((T_FAIL + 1))
        echo "not ok $T_TOTAL - $name"
        echo "  # expected /$expected/"
        echo "  # got:      $actual"
    fi
}

# Two-process keyed race: at least one winner, and every response is either
# the action's SUCCESS (a late loser may replay after commit) or its
# *_IN_PROGRESS refusal. The money invariant is asserted separately by the
# caller (single posting/journal, exact settled amount). Requiring exactly
# one SUCCESS made these tests scheduler-dependent under 4-shard runs.
assert_race_outcomes() {
    local label="$1"
    local actual="$2"
    local success="$3"
    local busy="$4"
    local successes unexpected
    successes="$(printf '%s\n' "$actual" | grep -cF "$success")"
    unexpected="$(printf '%s\n' "$actual" | grep -vF "$success" | grep -vF "$busy" | grep -c .)"
    assert_match "$label (at least one winner)" "$successes" "^[1-2]$"
    assert_match "$label (only idempotent outcomes)" "$unexpected" "^0$"
}

print_summary() {
    # TAP plan first, then the machine-readable counters. Existing consumers
    # grep for `^# pass=`; the plan line is additive. REPORT_DURATION_MS is
    # set by tests/lib/report.sh when the suite runs under the report wrapper.
    echo "1..$T_TOTAL"
    if [ -n "${REPORT_DURATION_MS:-}" ]; then
        echo "# pass=$T_PASS fail=$T_FAIL total=$T_TOTAL duration_ms=$REPORT_DURATION_MS"
    else
        echo "# pass=$T_PASS fail=$T_FAIL total=$T_TOTAL"
    fi
}
