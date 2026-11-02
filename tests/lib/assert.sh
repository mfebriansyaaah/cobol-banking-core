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
