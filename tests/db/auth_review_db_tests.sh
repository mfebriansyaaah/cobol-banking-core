#!/usr/bin/env bash
# Access-review reads + permission matrix (PR-5a). Stateful open/close is
# covered by ops_shell_db_tests.sh; this suite stays read-only so it can run
# in parallel without racing the single-open-review invariant.
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
L="sender@test.com"

assert_match "permission admin ok" "$(run_cobol "CHECK_PERMISSION|${A}|RECONCILE_READ|||${A}")" "SUCCESS\|PERMISSION_OK"
assert_match "permission user denied" "$(run_cobol "CHECK_PERMISSION|${L}|RECONCILE_READ|||${A}")" "ERROR\|PERMISSION_DENIED"
assert_match "permissions list ok" "$(run_cobol "LIST_PERMISSIONS|${A}|||||")" "SUCCESS\|"
assert_match "reviews list ok" "$(run_cobol "LIST_ACCESS_REVIEWS|${A}|||")" "SUCCESS\|"
assert_match "missing review refused" "$(run_cobol "GET_ACCESS_REVIEW|${A}|999999||||")" "ERROR\|UNKNOWN_TRANSACTION"
assert_match "open non-admin refused" "$(run_cobol "OPEN_ACCESS_REVIEW|${L}|2026-01-01|2026-01-31")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
