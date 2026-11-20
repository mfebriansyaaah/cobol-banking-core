#!/usr/bin/env bash
# Corporate registry cache (PR-5c): LEI upsert/read + guards.
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
LEI="529900T8BM49AURSDO66"
db_exec "DELETE FROM corporate_entities WHERE lei='${LEI}';"

assert_match "missing not found" "$(run_cobol "CORP_STATUS|${LEI}|||||")" "ERROR\|NOT_FOUND"
assert_match "short lei refused" "$(run_cobol "CORP_STATUS|SHORT|||||")" "ERROR\|INVALID_INPUT"
assert_match "resolve guard" "$(run_cobol "CORP_RESOLVE|${LEI}|Test Bank|ISSUED|Oslo|2026-11-06|sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "resolve ok" "$(run_cobol "CORP_RESOLVE|${LEI}|Test Bank|ISSUED|Oslo|2026-11-06|${A}")" "SUCCESS\|CORP_RESOLVED"
assert_match "status ok" "$(run_cobol "CORP_STATUS|${LEI}|||||")" "SUCCESS\|CORP_STATUS\|Test Bank\|ISSUED"
assert_match "re-resolve updates" "$(run_cobol "CORP_RESOLVE|${LEI}|Test Bank AS|RETIRED|Oslo|2026-11-06|${A}")" "SUCCESS\|CORP_RESOLVED"
assert_match "updated status" "$(run_cobol "CORP_STATUS|${LEI}|||||")" "SUCCESS\|CORP_STATUS\|Test Bank AS\|RETIRED"

db_exec "DELETE FROM corporate_entities WHERE lei='${LEI}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
