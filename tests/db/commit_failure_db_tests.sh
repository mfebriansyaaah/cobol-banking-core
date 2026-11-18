#!/usr/bin/env bash
# Shared transaction finalizer must fail closed when COMMIT fails.
# Test-only seam: SQL_BRIDGE_TEST + SQL_BRIDGE_TEST_FAIL_COMMIT.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

# File mode is mandatory: the seam must reach a fresh process, not a
# persistent --serve worker started without the test environment.
export COBOL_TEST_SERVE=0
db_seed

REF="TXNFIN-$(date +%s)-$$"
cleanup() {
    db_exec "DELETE FROM cost_center_audit WHERE cc_id IN (SELECT id FROM cost_center WHERE cc_ref='${REF}');"
    db_exec "DELETE FROM cost_center WHERE cc_ref='${REF}';"
}
trap cleanup EXIT
cleanup

# 1-2. Forced commit failure: ERROR|DB_ERROR and no persisted row.
out="$(SQL_BRIDGE_TEST=1 SQL_BRIDGE_TEST_FAIL_COMMIT=1 \
    run_cobol "CSC_CREATE|${REF}|Commit Fail|OPEX|||admin@test.com")"
assert_match "commit failure is surfaced" "$out" "^ERROR\|DB_ERROR$"
assert_match "failed commit leaves no row" \
    "$(db_query "SELECT COUNT(*) FROM cost_center WHERE cc_ref='${REF}';")" "^0$"

# 3-4. The normal path still commits and persists.
out="$(run_cobol "CSC_CREATE|${REF}|Commit Ok|OPEX|||admin@test.com")"
assert_match "normal commit still succeeds" "$out" "^SUCCESS\|CSC_CREATE\|[0-9]+"
assert_match "normal commit persists row" \
    "$(db_query "SELECT COUNT(*) FROM cost_center WHERE cc_ref='${REF}';")" "^1$"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
