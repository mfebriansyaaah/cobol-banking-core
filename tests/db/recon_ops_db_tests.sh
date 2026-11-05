#!/usr/bin/env bash
# Recon shell coverage: bulk stage + row correct, import-recon (IRC_*) and
# statement-recon (SRC_*) lifecycles via run_cobol.
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
C="IRC-SHELL-1"
db_exec "DELETE FROM import_row WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
db_exec "DELETE FROM import_recon_run WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
db_exec "DELETE FROM import_posting WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
db_exec "DELETE FROM import_batch WHERE batch_code='${C}';"

# Bulk stage into a STAGED batch, then correct one row.
assert_match "IMP_BATCH_CREATE ok" "$(run_cobol "IMP_BATCH_CREATE|${C}|CSV|LEDGER|||${A}")" "SUCCESS\|"
assert_match "IMP_BATCH_STAGE_BULK ok" "$(run_cobol "IMP_BATCH_STAGE_BULK|${C}|1000:10.00:0;1100:0:10.00||||${A}")" "SUCCESS\|"
assert_match "rows staged" "$(db_query "SELECT COUNT(*) FROM import_row WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='${C}');")" "^2$"
assert_match "IMP_BATCH_VALIDATE ok" "$(run_cobol "IMP_BATCH_VALIDATE|${C}|||||${A}")" "SUCCESS\|"
assert_match "IMP_ROW_CORRECT ok" "$(run_cobol "IMP_ROW_CORRECT|${C}|1|1000:10.00:0|||${A}")" "SUCCESS\|IMP_ROW_CORRECTED"
assert_match "IMP_BATCH_REVALIDATE ok" "$(run_cobol "IMP_BATCH_VALIDATE|${C}|||||${A}")" "SUCCESS\|"
assert_match "IMPP_LEDGER ok (post for recon)" "$(run_cobol "IMPP_LEDGER|${C}|2026-06-01|shell recon post|USD||${A}")" "SUCCESS\|"

# Import-recon lifecycle.
assert_match "IRC_START ok" "$(run_cobol "IRC_START|${C}|||||${A}")" "SUCCESS\|"
ircid="$(db_query "SELECT id FROM import_recon_run WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='${C}') ORDER BY id DESC LIMIT 1;")"
assert_match "recon run present" "$ircid" "^[0-9]+$"
assert_match "IRC_MATCH ok" "$(run_cobol "IRC_MATCH|${ircid}|||||${A}")" "SUCCESS\|"
assert_match "IRC_ITEMS ok" "$(run_cobol "IRC_ITEMS|${ircid}||50|0||${A}")" "SUCCESS\|"
assert_match "IRC_LIST ok" "$(run_cobol "IRC_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "IRC_GET ok" "$(run_cobol "IRC_GET|${ircid}|||||${A}")" "SUCCESS\|"
assert_match "IRC_EXPORT ok" "$(run_cobol "IRC_EXPORT|${ircid}|CSV||||${A}")" "SUCCESS\|"
assert_match "IRC_SUMMARY ok" "$(run_cobol "IRC_SUMMARY|${C}|||||${A}")" "SUCCESS\|"
assert_match "IRC_FINISH ok" "$(run_cobol "IRC_FINISH|${ircid}|||||${A}")" "SUCCESS\|"
assert_match "IRC_RETRY refused after finish" "$(run_cobol "IRC_RETRY|${ircid}|||||${A}")" "ERROR\|INVALID_STATUS"

# Statement-recon lifecycle (statement run completes over today's window).
TODAY="$(date +%F)"
assert_match "STMT_RUN_START ok" "$(run_cobol "STMT_RUN_START|${TODAY}|${TODAY}|USD|||${A}")" "SUCCESS\|STMT_RUN_STARTED"
stmtid="$(db_query "SELECT id FROM statement_run ORDER BY id DESC LIMIT 1;")"
assert_match "STMT_RUN_GENERATE ok" "$(run_cobol "STMT_RUN_GENERATE|${stmtid}|||||${A}")" "SUCCESS\|"
assert_match "statement completed" "$(db_query "SELECT status FROM statement_run WHERE id=${stmtid};")" "^COMPLETED$"
assert_match "SRC_START ok" "$(run_cobol "SRC_START|${stmtid}|||||${A}")" "SUCCESS\|"
srcid="$(db_query "SELECT id FROM statement_recon_run WHERE statement_run_id=${stmtid} ORDER BY id DESC LIMIT 1;")"
assert_match "src run present" "$srcid" "^[0-9]+$"
assert_match "SRC_MATCH ok" "$(run_cobol "SRC_MATCH|${srcid}|||||${A}")" "SUCCESS\|"
assert_match "SRC_ITEMS ok" "$(run_cobol "SRC_ITEMS|${srcid}||50|0||${A}")" "SUCCESS\|"
assert_match "SRC_LIST ok" "$(run_cobol "SRC_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "SRC_GET ok" "$(run_cobol "SRC_GET|${srcid}|||||${A}")" "SUCCESS\|"
assert_match "SRC_EXPORT ok" "$(run_cobol "SRC_EXPORT|${srcid}|CSV||||${A}")" "SUCCESS\|"
assert_match "SRC_SUMMARY ok" "$(run_cobol "SRC_SUMMARY|${stmtid}|||||${A}")" "SUCCESS\|"
assert_match "SRC_FINISH ok" "$(run_cobol "SRC_FINISH|${srcid}|||||${A}")" "SUCCESS\|"
assert_match "SRC_RETRY refused after finish" "$(run_cobol "SRC_RETRY|${srcid}|||||${A}")" "ERROR\|INVALID_STATUS"
assert_match "non-admin refused" "$(run_cobol "IRC_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM statement_recon_run WHERE statement_run_id=${stmtid};"
db_exec "DELETE FROM statement_archive_line WHERE archive_id IN (SELECT id FROM statement_archive WHERE run_id=${stmtid});"
db_exec "DELETE FROM statement_archive WHERE run_id=${stmtid};"
db_exec "DELETE FROM statement_run WHERE id=${stmtid};"
db_exec "DELETE FROM import_recon_run WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
db_exec "DELETE FROM import_posting WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
db_exec "DELETE FROM import_row WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
db_exec "DELETE FROM import_batch WHERE batch_code='${C}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
