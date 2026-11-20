#!/usr/bin/env bash
# Statement reconciliation (PR-4b): start/match/read/finish over a statement run.
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
TODAY="$(date +%F)"
STMT=""
SRC=""

cleanup() {
    if [ -n "$SRC" ]; then
        db_exec "DELETE FROM statement_recon_run WHERE id IN (${SRC});"
    fi
    if [ -n "$STMT" ]; then
        db_exec "DELETE FROM statement_archive_line WHERE archive_id IN (SELECT id FROM statement_archive WHERE run_id IN (${STMT}));"
        db_exec "DELETE FROM statement_archive WHERE run_id IN (${STMT});"
        db_exec "DELETE FROM statement_audit WHERE run_id IN (${STMT});"
        db_exec "DELETE FROM statement_run WHERE id IN (${STMT});"
    fi
}
cleanup

start_out="$(run_cobol "STMT_RUN_START|${TODAY}|${TODAY}|USD|||${A}")"
stmtid="$(printf '%s' "$start_out" | awk -F'|' '{print $3}')"
STMT="$stmtid"
assert_match "statement started" "$stmtid" "^[0-9]+$"
assert_match "statement generated" "$(run_cobol "STMT_RUN_GENERATE|${stmtid}|||||${A}")" "SUCCESS\|"

assert_match "start ok" "$(run_cobol "SRC_START|${stmtid}|||||${A}")" "SUCCESS\|"
srcid="$(db_query "SELECT id FROM statement_recon_run WHERE statement_run_id=${stmtid} ORDER BY id DESC LIMIT 1;")"
SRC="$srcid"
assert_match "run persisted" "$srcid" "^[0-9]+$"
assert_match "match ok" "$(run_cobol "SRC_MATCH|${srcid}|||||${A}")" "SUCCESS\|"
assert_match "match persisted" "$(db_query "SELECT status FROM statement_recon_run WHERE id=${srcid};")" "^RUNNING$"
assert_match "items ok" "$(run_cobol "SRC_ITEMS|${srcid}||50|0||${A}")" "SUCCESS\|"
assert_match "list ok" "$(run_cobol "SRC_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "get ok" "$(run_cobol "SRC_GET|${srcid}|||||${A}")" "SUCCESS\|"
assert_match "export ok" "$(run_cobol "SRC_EXPORT|${srcid}|CSV||||${A}")" "SUCCESS\|"
assert_match "summary ok" "$(run_cobol "SRC_SUMMARY|${stmtid}|||||${A}")" "SUCCESS\|"
assert_match "finish ok" "$(run_cobol "SRC_FINISH|${srcid}|||||${A}")" "SUCCESS\|"
assert_match "finished persisted" "$(db_query "SELECT status FROM statement_recon_run WHERE id=${srcid};")" "^COMPLETED$"
assert_match "retry refused after finish" "$(run_cobol "SRC_RETRY|${srcid}|||||${A}")" "ERROR\|INVALID_STATUS"
assert_match "missing statement rejected" "$(run_cobol "SRC_START|999999|||||${A}")" "ERROR\|NOT_FOUND"
assert_match "non-admin refused" "$(run_cobol "SRC_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

cleanup

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
