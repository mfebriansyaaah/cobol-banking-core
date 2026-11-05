#!/usr/bin/env bash
# Report builder + statement run shell coverage via run_cobol.
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
T="RPT-SHELL"
C="${T}-CLONE"
db_exec "DELETE FROM report_run WHERE template_id IN (SELECT id FROM report_template WHERE template_code='${T}' OR template_code='${C}');"
db_exec "DELETE FROM report_template_column WHERE template_id IN (SELECT id FROM report_template WHERE template_code='${T}' OR template_code='${C}');"
db_exec "DELETE FROM report_template WHERE template_code='${T}' OR template_code='${C}';"

# Template + column lifecycle.
# Retry-once helper for fixture INSERTs: CI shards share one DB, so a
# concurrent writer on the same table can deadlock us (ERROR|DB_ERROR);
# a short backoff + retry resolves it. Any other error fails immediately.
create_retry() {
    local out i
    for i in 1 2 3; do
        out="$(run_cobol "$1")"
        case "$out" in
            ERROR\|DB_ERROR) sleep 0.5;;
            *) printf '%s' "$out"; return 0;;
        esac
    done
    printf '%s' "$out"
    return 0
}
assert_match "RPT_TEMPLATE_CREATE ok" "$(create_retry "RPT_TEMPLATE_CREATE|${T}|Shell Report|TRIAL_BALANCE|CSV|Shell Title|${A}")" "SUCCESS\|"
assert_match "RPT_TEMPLATE_GET ok" "$(run_cobol "RPT_TEMPLATE_GET|${T}|||||${A}")" "SUCCESS\|"
assert_match "RPT_TEMPLATE_LIST ok" "$(run_cobol "RPT_TEMPLATE_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "RPT_TEMPLATE_UPDATE ok" "$(run_cobol "RPT_TEMPLATE_UPDATE|${T}|1|CSV|Shell Title 2||${A}")" "SUCCESS\|"
assert_match "RPT_TEMPLATE_CLONE ok" "$(run_cobol "RPT_TEMPLATE_CLONE|${T}|${C}|Clone Name|Clone Title||${A}")" "SUCCESS\|"
assert_match "RPT_COLUMN_CREATE ok" "$(create_retry "RPT_COLUMN_CREATE|${T}|1|Account|account|20,LEFT,TEXT|${A}")" "SUCCESS\|"
assert_match "RPT_COLUMN_LIST ok" "$(run_cobol "RPT_COLUMN_LIST|${T}|50|0|||${A}")" "SUCCESS\|"
assert_match "RPT_COLUMN_UPDATE ok" "$(run_cobol "RPT_COLUMN_UPDATE|${T}|1|Account No|account|20,LEFT,TEXT|${A}")" "SUCCESS\|"

# Run lifecycle on the main template.
assert_match "RPT_RUN_START ok" "$(run_cobol "RPT_RUN_START|${T}|from=2026-01-01||||${A}")" "SUCCESS\|"
runid="$(db_query "SELECT id FROM report_run WHERE template_id=(SELECT id FROM report_template WHERE template_code='${T}') ORDER BY id DESC LIMIT 1;")"
assert_match "run row present" "$runid" "^[0-9]+$"
assert_match "RPT_RUN_GENERATE ok" "$(run_cobol "RPT_RUN_GENERATE|${runid}|2026-01-01|2026-12-31|USD||${A}")" "SUCCESS\|"
assert_match "RPT_RUN_ROW ok" "$(run_cobol "RPT_RUN_ROW|${runid}|99|10.00|10.00|row99|${A}")" "SUCCESS\|"
assert_match "RPT_RUN_STATUS ok" "$(run_cobol "RPT_RUN_STATUS|${runid}|||||${A}")" "SUCCESS\|"
counts="$(db_query "SELECT CONCAT(COUNT(*), ',', COALESCE(SUM(debit),0), ',', COALESCE(SUM(credit),0)) FROM report_run_row WHERE run_id=${runid};")"
assert_match "RPT_RUN_COMPLETE ok" "$(run_cobol "RPT_RUN_COMPLETE|${runid}|${counts}|abc123|||${A}")" "SUCCESS\|"
assert_match "RPT_RUN_EXPORT ok" "$(run_cobol "RPT_RUN_EXPORT|${runid}|CSV||||${A}")" "SUCCESS\|"
assert_match "RPT_RUN_LIST ok" "$(run_cobol "RPT_RUN_LIST|50|0||||${A}")" "SUCCESS\|"

# Fail + retry on a second run.
assert_match "RPT_RUN_START ok (2)" "$(run_cobol "RPT_RUN_START|${T}|from=2026-01-01||||${A}")" "SUCCESS\|"
runid2="$(db_query "SELECT id FROM report_run WHERE template_id=(SELECT id FROM report_template WHERE template_code='${T}') ORDER BY id DESC LIMIT 1;")"
assert_match "RPT_RUN_FAIL ok" "$(run_cobol "RPT_RUN_FAIL|${runid2}|E999|boom|||${A}")" "SUCCESS\|"
assert_match "RPT_RUN_RETRY ok" "$(run_cobol "RPT_RUN_RETRY|${runid2}|||||${A}")" "SUCCESS\|"
assert_match "RPT_RUN_DELETE ok" "$(run_cobol "RPT_RUN_DELETE|${runid2}|||||${A}")" "SUCCESS\|"
assert_match "RPT_TEMPLATE_DELETE ok" "$(run_cobol "RPT_TEMPLATE_DELETE|${C}|||||${A}")" "SUCCESS\|"
assert_match "non-admin refused" "$(run_cobol "RPT_TEMPLATE_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

# Statement runs: generate over a window covering today (ledger rows exist).
# Run ids are parsed from START output, never "latest global row": parallel
# suites create statement runs concurrently (ISOLATED_DB=0).
TODAY="$(date +%F)"
stmt_start_out="$(run_cobol "STMT_RUN_START|${TODAY}|${TODAY}|USD|||${A}")"
assert_match "STMT_RUN_START ok" "$stmt_start_out" "SUCCESS\|STMT_RUN_STARTED"
stmtid="$(printf '%s' "$stmt_start_out" | awk -F'|' '{print $3}')"
assert_match "stmt row present" "$stmtid" "^[0-9]+$"
assert_match "STMT_RUN_GENERATE ok" "$(run_cobol "STMT_RUN_GENERATE|${stmtid}|||||${A}")" "SUCCESS\|"
assert_match "STMT_RUN_STATUS ok" "$(run_cobol "STMT_RUN_STATUS|${stmtid}|||||${A}")" "SUCCESS\|STMT_RUN"
assert_match "STMT_RUN_LIST ok" "$(run_cobol "STMT_RUN_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "STMT_ARCHIVE_EXPORT ok" "$(run_cobol "STMT_ARCHIVE_EXPORT|sender@test.com|${stmtid}|CSV|||${A}")" "SUCCESS\|"
stmt_start_out2="$(run_cobol "STMT_RUN_START|${TODAY}|${TODAY}|USD|||${A}")"
assert_match "STMT_RUN_START ok (2)" "$stmt_start_out2" "SUCCESS\|STMT_RUN_STARTED"
stmtid2="$(printf '%s' "$stmt_start_out2" | awk -F'|' '{print $3}')"
assert_match "stmt2 id present" "$stmtid2" "^[0-9]+$"
assert_match "STMT_RUN_FAIL ok" "$(run_cobol "STMT_RUN_FAIL|${stmtid2}|E999|boom|||${A}")" "SUCCESS\|"

db_exec "DELETE FROM statement_archive_line WHERE archive_id IN (SELECT id FROM statement_archive WHERE run_id=${stmtid} OR run_id=${stmtid2});"
db_exec "DELETE FROM statement_archive WHERE run_id=${stmtid} OR run_id=${stmtid2};"
db_exec "DELETE FROM statement_run WHERE id=${stmtid} OR id=${stmtid2};"
db_exec "DELETE FROM report_run WHERE template_id IN (SELECT id FROM report_template WHERE template_code='${T}' OR template_code='${C}');"
db_exec "DELETE FROM report_template_column WHERE template_id IN (SELECT id FROM report_template WHERE template_code='${T}' OR template_code='${C}');"
db_exec "DELETE FROM report_template WHERE template_code='${T}' OR template_code='${C}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
