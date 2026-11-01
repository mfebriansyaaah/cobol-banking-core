#!/bin/bash
# Gateway endpoint smoke: run the full middleware test suite (all endpoints).
# Returns 0 if every test passes, 1 otherwise.
# Usage: tests/gateway/endpoint_smoke.sh
#
# The suite runs in two parts with identical coverage to `npm test`:
# test:fast (unit/contract tests, file mode) and test:gateway (HTTP
# integration through the persistent COBOL worker pool). Splitting keeps
# local iteration fast without dropping anything from the full gate.
#
# Both parts share one TEST_RUN_ID so scripts/check_test_residue.sh can verify
# the whole run left no user fixtures behind (per-file namespaces embed the
# id; see middleware/test/support.js testNamespace). Bring your own id to
# check a single run among many on a shared database:
#   TEST_RUN_ID=t$(date +%s%N) tests/gateway/endpoint_smoke.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# One id for the whole run: namespaces from both parts match one residue
# pattern, and a rerun never matches an older run's fixtures.
TEST_RUN_ID="${TEST_RUN_ID:-t$(date +%s%N)$$}"
export TEST_RUN_ID
# A follow-up CI step re-runs the residue check; hand it the id through the
# step-summary env file when running under GitHub Actions (no-op locally).
if [ -n "${GITHUB_ENV:-}" ]; then
    echo "TEST_RUN_ID=$TEST_RUN_ID" >> "$GITHUB_ENV"
fi

if [ ! -d middleware ]; then
    echo "SKIP: middleware/ absent"
    exit 0
fi

# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
require_db
db_seed

# The old check only looked at the "fail" counter. When the suite crashed while
# loading a route module there was no summary line at all, so `fail` expanded
# to 0 and the run looked clean. Require a real summary with a non-zero pass
# count before trusting the numbers.
#
# When TEST_REPORT_DIR is set, the :junit variant of each suite runs instead:
# spec still goes to the log (parsed below) and a JUnit XML lands in
# TEST_REPORT_DIR for machine-readable reporting.
run_part() {
    local script="$1" log="$2"
    echo "Running middleware suite ($script)..."
    if [ -n "${TEST_REPORT_DIR:-}" ]; then
        script="$script:junit"
    fi
    if ! TEST_REPORT_DIR="${TEST_REPORT_DIR:-}" npm --prefix middleware run "$script" >"$log" 2>&1; then
        echo "FAIL: middleware suite ($script) exited non-zero"
        tail -25 "$log"
        return 1
    fi
    if ! grep -qE '^ℹ (pass|tests) ' "$log"; then
        echo "FAIL: middleware suite ($script) produced no test summary (crash during load?)"
        tail -25 "$log"
        return 1
    fi
    local pass fail tests
    pass=$(grep -E '^ℹ pass' "$log" | awk '{print $3}')
    fail=$(grep -E '^ℹ fail' "$log" | awk '{print $3}')
    tests=$(grep -E '^ℹ tests' "$log" | awk '{print $3}')
    echo "middleware ($script): tests=${tests:-0} pass=${pass:-0} fail=${fail:-0}"
    if [ "${fail:-0}" != "0" ] || [ "${pass:-0}" -lt 1 ]; then
        echo "FAIL: middleware suite ($script) failed (pass=${pass:-0}, fail=${fail:-0})"
        tail -25 "$log"
        return 1
    fi
    return 0
}

failed=0
run_part "test:fast" /tmp/gateway_fast.log || failed=1
run_part "test:gateway" /tmp/gateway_endpoints.log || failed=1

# Every gateway test user lives in a per-file namespace embedding TEST_RUN_ID;
# each suite cleans only its own namespace, so this one query verifies the
# whole run. Kept outside the suites (instead of a third suite) so a crash
# that skips cleanup is still caught, and so CI can re-run the same check as
# its own step with the id from $GITHUB_ENV.
residue_failed=0
if ! TEST_RUN_ID="$TEST_RUN_ID" bash "$ROOT/scripts/check_test_residue.sh" > /tmp/gateway_residue.log 2>&1; then
    echo "FAIL: test run left user fixtures behind"
    cat /tmp/gateway_residue.log
    residue_failed=1
else
    cat /tmp/gateway_residue.log
fi

if [ "$failed" -ne 0 ] || [ "$residue_failed" -ne 0 ]; then
    echo "FAIL: gateway endpoint check failed"
    exit 1
fi
echo "OK: all gateway endpoints passed"
exit 0
