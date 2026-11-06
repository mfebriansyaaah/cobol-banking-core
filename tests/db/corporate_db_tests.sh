#!/usr/bin/env bash
# Corporate registry cache (PR-097): LEI upsert, shape validation, reads.
# Triage cache only; never AHU/akta proof.
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
LEI="529900T8BM49AURSDO55"
db_exec "DELETE FROM corporate_entities WHERE lei='${LEI}';"

assert_match "missing reads not found" "$(run_cobol "CORP_STATUS|${LEI}|||||")" "ERROR\|NOT_FOUND"
assert_match "short LEI refused" "$(run_cobol "CORP_STATUS|SHORT|||||")" "ERROR\|INVALID_INPUT"
assert_match "lowercase refused" "$(run_cobol "CORP_STATUS|529900t8bm49aursdo55|||||")" "ERROR\|INVALID_INPUT"
assert_match "non-admin resolve refused" "$(run_cobol "CORP_RESOLVE|${LEI}|Test Bank AS|ISSUED|Oslo|2026-11-06|sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "missing name refused" "$(run_cobol "CORP_RESOLVE|${LEI}||ISSUED|Oslo|2026-11-06|${A}")" "ERROR\|INVALID_INPUT"
assert_match "resolve ok" "$(run_cobol "CORP_RESOLVE|${LEI}|Test Bank AS|ISSUED|Oslo|2026-11-06|${A}")" "SUCCESS\|CORP_RESOLVED"
assert_match "status reads name and standing" "$(run_cobol "CORP_STATUS|${LEI}|||||")" "SUCCESS\|CORP_STATUS\|Test Bank AS\|ISSUED"
assert_match "re-resolve updates" "$(run_cobol "CORP_RESOLVE|${LEI}|Test Bank ASA|RETIRED|Oslo|2026-11-06|${A}")" "SUCCESS\|CORP_RESOLVED"
assert_match "update served" "$(run_cobol "CORP_STATUS|${LEI}|||||")" "SUCCESS\|CORP_STATUS\|Test Bank ASA\|RETIRED"

db_exec "DELETE FROM corporate_entities WHERE lei='${LEI}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
