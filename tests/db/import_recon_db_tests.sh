#!/usr/bin/env bash
# Import reconciliation (PR-4b): start/match/read/finish over a posted batch.
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
C="IRC-D1"

cleanup() {
    db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT journal_id FROM import_posting WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}'));"
    db_exec "DELETE FROM gl_journal WHERE id IN (SELECT journal_id FROM import_posting WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}'));"
    db_exec "DELETE FROM import_recon_run WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
    db_exec "DELETE FROM import_posting WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
    db_exec "DELETE FROM import_row WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
    db_exec "DELETE FROM import_batch WHERE batch_code='${C}';"
    db_exec "DELETE FROM import_audit WHERE batch_code='${C}';"
}
cleanup

assert_match "batch create ok" "$(run_cobol "IMP_BATCH_CREATE|${C}|CSV|LEDGER|||${A}")" "SUCCESS\|"
assert_match "bulk stage ok" "$(run_cobol "IMP_BATCH_STAGE_BULK|${C}|1000:10.00:0;1100:0:10.00||||${A}")" "SUCCESS\|"
assert_match "validate ok" "$(run_cobol "IMP_BATCH_VALIDATE|${C}|||||${A}")" "SUCCESS\|"
run_cobol "GL_PERIOD_OPEN|2026-06|||||${A}" >/dev/null
assert_match "post ok" "$(run_cobol "IMPP_LEDGER|${C}|2026-06-01|PR-4b recon post|USD||${A}")" "SUCCESS\|"

assert_match "start ok" "$(run_cobol "IRC_START|${C}|||||${A}")" "SUCCESS\|"
rid="$(db_query "SELECT id FROM import_recon_run WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='${C}') ORDER BY id DESC LIMIT 1;")"
assert_match "run persisted" "$rid" "^[0-9]+$"
assert_match "match ok" "$(run_cobol "IRC_MATCH|${rid}|||||${A}")" "SUCCESS\|"
assert_match "match persisted" "$(db_query "SELECT status FROM import_recon_run WHERE id=${rid};")" "^RUNNING$"
assert_match "items classified" "$(db_query "SELECT COUNT(*) FROM import_recon_item WHERE run_id=${rid};")" "^2$"
assert_match "items ok" "$(run_cobol "IRC_ITEMS|${rid}||50|0||${A}")" "SUCCESS\|"
assert_match "list ok" "$(run_cobol "IRC_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "get ok" "$(run_cobol "IRC_GET|${rid}|||||${A}")" "SUCCESS\|"
assert_match "export ok" "$(run_cobol "IRC_EXPORT|${rid}|CSV||||${A}")" "SUCCESS\|"
assert_match "summary ok" "$(run_cobol "IRC_SUMMARY|${C}|||||${A}")" "SUCCESS\|"
assert_match "finish ok" "$(run_cobol "IRC_FINISH|${rid}|||||${A}")" "SUCCESS\|"
assert_match "finished persisted" "$(db_query "SELECT status FROM import_recon_run WHERE id=${rid};")" "^COMPLETED$"
assert_match "retry refused after finish" "$(run_cobol "IRC_RETRY|${rid}|||||${A}")" "ERROR\|INVALID_STATUS"
assert_match "missing batch rejected" "$(run_cobol "IRC_START|NO-SUCH-BATCH|||||${A}")" "ERROR\|NOT_FOUND"
assert_match "non-admin refused" "$(run_cobol "IRC_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

cleanup

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
