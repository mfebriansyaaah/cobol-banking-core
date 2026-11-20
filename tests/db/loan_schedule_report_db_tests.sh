#!/usr/bin/env bash
# Loan-schedule reporting (PR-5b): summary/export/audit reads + guard.
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

assert_match "summary ok" "$(run_cobol "LSC_SUMMARY||||||${A}")" "SUCCESS\|LSC_SUMMARY"
assert_match "export ok" "$(run_cobol "LSC_EXPORT||||||${A}")" "SUCCESS\|LSC_EXPORT"
assert_match "audit ok" "$(run_cobol "LSC_AUDIT||||||${A}")" "SUCCESS\|LSC_AUDIT"
assert_match "summary non-admin refused" "$(run_cobol "LSC_SUMMARY||||||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "export non-admin refused" "$(run_cobol "LSC_EXPORT||||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
