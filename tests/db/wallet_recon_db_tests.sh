#!/usr/bin/env bash
# Wallet reconciliation (PR-5b): run/list + exception read/ack/resolve.
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

assert_match "reconcile verdict" "$(run_cobol "RECONCILE|${A}|||||")" "SUCCESS\|RECONCILED|ERROR\|MISMATCH"
assert_match "run ok" "$(run_cobol "RUN_RECONCILIATION|${A}|MANUAL||||")" "SUCCESS\|"
rid="$(db_query "SELECT run_id FROM reconciliation_runs ORDER BY run_id DESC LIMIT 1;")"
assert_match "run persisted" "$rid" "^[0-9]+$"
assert_match "run completed" "$(db_query "SELECT status FROM reconciliation_runs WHERE run_id=${rid};")" "^(COMPLETED|MISMATCH)$"
assert_match "list runs" "$(run_cobol "LIST_RECONCILIATIONS|${A}|50|0|||")" "SUCCESS\|"
assert_match "list exceptions" "$(run_cobol "LIST_EXCEPTIONS|${A}|||")" "SUCCESS\|"
fid="$(db_query "SELECT finding_id FROM reconciliation_findings WHERE status='OPEN' ORDER BY finding_id DESC LIMIT 1;")"
if [ -n "$fid" ]; then tgt="$fid"; else tgt="999999"; fi
assert_match "ack verdict" "$(run_cobol "ACK_EXCEPTION|${tgt}|${A}||||")" "SUCCESS\|EXCEPTION_ACKNOWLEDGED|ERROR\|UNKNOWN_TRANSACTION"
assert_match "resolve verdict" "$(run_cobol "RESOLVE_EXCEPTION|${tgt}|${A}|fixed|||")" "SUCCESS\|EXCEPTION_RESOLVED|ERROR\|UNKNOWN_TRANSACTION"
assert_match "non-admin run refused" "$(run_cobol "RUN_RECONCILIATION|sender@test.com|MANUAL||||")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
