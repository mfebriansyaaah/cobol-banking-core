#!/usr/bin/env bash
# Statement runs (PR-4b): start/generate/status/list + failure path.
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
RUNS=""

cleanup() {
    if [ -n "$RUNS" ]; then
        db_exec "DELETE FROM statement_archive_line WHERE archive_id IN (SELECT id FROM statement_archive WHERE run_id IN (${RUNS}));"
        db_exec "DELETE FROM statement_archive WHERE run_id IN (${RUNS});"
        db_exec "DELETE FROM statement_audit WHERE run_id IN (${RUNS});"
        db_exec "DELETE FROM statement_run WHERE id IN (${RUNS});"
    fi
}
cleanup

start_out="$(run_cobol "STMT_RUN_START|${TODAY}|${TODAY}|USD|||${A}")"
assert_match "start ok" "$start_out" "SUCCESS\|STMT_RUN_STARTED"
rid="$(printf '%s' "$start_out" | awk -F'|' '{print $3}')"
RUNS="$rid"
assert_match "run persisted" "$(db_query "SELECT status FROM statement_run WHERE id=${rid};")" "^RUNNING$"
assert_match "status ok" "$(run_cobol "STMT_RUN_STATUS|${rid}|0||||${A}")" "SUCCESS\|STMT_RUN\|${rid}"
assert_match "generate ok" "$(run_cobol "STMT_RUN_GENERATE|${rid}|||||${A}")" "SUCCESS\|"
assert_match "run completed" "$(db_query "SELECT status FROM statement_run WHERE id=${rid};")" "^COMPLETED$"
assert_match "status shows completed" "$(run_cobol "STMT_RUN_STATUS|${rid}|0||||${A}")" "COMPLETED"
assert_match "list contains run" "$(run_cobol "STMT_RUN_LIST|50|0|COMPLETED|USD||${A}")" "${rid}"

fail_out="$(run_cobol "STMT_RUN_START|${TODAY}|${TODAY}|USD|||${A}")"
fid="$(printf '%s' "$fail_out" | awk -F'|' '{print $3}')"
RUNS="${rid},${fid}"
assert_match "fail ok" "$(run_cobol "STMT_RUN_FAIL|${fid}|GEN_ERROR|pr-4b failure|||${A}")" "SUCCESS\|STMT_RUN_FAILED"
assert_match "failure persisted" "$(db_query "SELECT status FROM statement_run WHERE id=${fid};")" "^FAILED$"
assert_match "double fail rejected" "$(run_cobol "STMT_RUN_FAIL|${fid}|GEN_ERROR|again|||${A}")" "ERROR\|INVALID_STATUS"

assert_match "bad date rejected" "$(run_cobol "STMT_RUN_START|2026-13-01|${TODAY}|USD|||${A}")" "ERROR\|INVALID_INPUT"
assert_match "missing run rejected" "$(run_cobol "STMT_RUN_STATUS|999999|0||||${A}")" "ERROR\|NOT_FOUND"
assert_match "non-admin refused" "$(run_cobol "STMT_RUN_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

cleanup

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
