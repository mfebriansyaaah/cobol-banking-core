#!/usr/bin/env bash
# Import posting (PR-4b): post a validated ledger batch to GL, then read it back.
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
C="IMPP-D1"

cleanup() {
    db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT journal_id FROM import_posting WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}'));"
    db_exec "DELETE FROM gl_journal WHERE id IN (SELECT journal_id FROM import_posting WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}'));"
    db_exec "DELETE FROM import_posting WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
    db_exec "DELETE FROM import_row WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
    db_exec "DELETE FROM import_recon_run WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
    db_exec "DELETE FROM import_batch WHERE batch_code='${C}';"
    db_exec "DELETE FROM import_audit WHERE batch_code='${C}';"
}
cleanup

assert_match "batch create ok" "$(run_cobol "IMP_BATCH_CREATE|${C}|CSV|LEDGER|||${A}")" "SUCCESS\|"
assert_match "bulk stage ok" "$(run_cobol "IMP_BATCH_STAGE_BULK|${C}|1000:10.00:0;1100:0:10.00||||${A}")" "SUCCESS\|"
assert_match "rows staged" "$(db_query "SELECT COUNT(*) FROM import_row WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='${C}');")" "^2$"
assert_match "validate ok" "$(run_cobol "IMP_BATCH_VALIDATE|${C}|||||${A}")" "SUCCESS\|"
run_cobol "GL_PERIOD_OPEN|2026-06|||||${A}" >/dev/null

post_out="$(run_cobol "IMPP_LEDGER|${C}|2026-06-01|PR-4b import post|USD||${A}")"
assert_match "post ok" "$post_out" "SUCCESS\|IMP_LEDGER_POSTED"
jid="$(printf '%s' "$post_out" | awk -F'|' '{print $3}')"
assert_match "gl journal written" "$(db_query "SELECT COUNT(*) FROM gl_journal WHERE id=${jid};")" "^1$"
assert_match "gl lines written" "$(db_query "SELECT COUNT(*) FROM gl_journal_line WHERE journal_id=${jid};")" "^2$"
assert_match "batch completed" "$(db_query "SELECT status FROM import_batch WHERE batch_code='${C}';")" "^COMPLETED$"
assert_match "posting audited" "$(db_query "SELECT COUNT(*) FROM import_audit WHERE batch_code='${C}' AND action='LEDGER_POST';")" "^1$"

pid="$(db_query "SELECT id FROM import_posting WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='${C}') LIMIT 1;")"
assert_match "post get ok" "$(run_cobol "IMPP_GET|${pid}|||||${A}")" "SUCCESS\|IMP_POSTING"
assert_match "post list ok" "$(run_cobol "IMPP_LIST|50|0||||${A}")" "${C}"

assert_match "double post rejected" "$(run_cobol "IMPP_LEDGER|${C}|2026-06-01|again|USD||${A}")" "ERROR\|INVALID_STATUS"
assert_match "missing date rejected" "$(run_cobol "IMPP_LEDGER|${C}|bad||USD||${A}")" "ERROR\|INVALID_INPUT"
assert_match "non-admin refused" "$(run_cobol "IMPP_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

cleanup

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
