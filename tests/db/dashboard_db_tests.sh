#!/usr/bin/env bash
# Dashboard reads shell coverage: every DSH_* overview action via run_cobol.
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

db_seed
A="admin@test.com"

assert_match "DSH_OVERVIEW ok" "$(run_cobol "DSH_OVERVIEW||||||${A}")" "SUCCESS\|DSH_OVERVIEW"
assert_match "DSH_PAYMENTS ok" "$(run_cobol "DSH_PAYMENTS|2026-01-01|2026-12-31|USD|||${A}")" "SUCCESS\|"
assert_match "DSH_DISPUTES ok" "$(run_cobol "DSH_DISPUTES||||||${A}")" "SUCCESS\|"
assert_match "DSH_ALERTS ok" "$(run_cobol "DSH_ALERTS||||||${A}")" "SUCCESS\|"
assert_match "DSH_OUTBOX ok" "$(run_cobol "DSH_OUTBOX||||||${A}")" "SUCCESS\|"
assert_match "DSH_REPORTS ok" "$(run_cobol "DSH_REPORTS||||||${A}")" "SUCCESS\|"
assert_match "DSH_IMPORTS ok" "$(run_cobol "DSH_IMPORTS||||||${A}")" "SUCCESS\|"
assert_match "DSH_ACCOUNTS ok" "$(run_cobol "DSH_ACCOUNTS||||||${A}")" "SUCCESS\|"
assert_match "DSH_FEES ok" "$(run_cobol "DSH_FEES||||||${A}")" "SUCCESS\|"
assert_match "DSH_POLICY ok" "$(run_cobol "DSH_POLICY||||||${A}")" "SUCCESS\|"
assert_match "DSH_RECON ok" "$(run_cobol "DSH_RECON||||||${A}")" "SUCCESS\|"
assert_match "DSH_CASHFLOW ok" "$(run_cobol "DSH_CASHFLOW|2026-01-01|2026-12-31|USD|||${A}")" "SUCCESS\|"
assert_match "non-admin refused" "$(run_cobol "DSH_OVERVIEW||||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
