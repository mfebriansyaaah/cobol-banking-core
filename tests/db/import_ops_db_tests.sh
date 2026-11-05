#!/usr/bin/env bash
# Import operations shell coverage: batch lifecycle + ledger posting.
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
C="IMP-SHELL-1"
db_exec "DELETE FROM import_row WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}' OR batch_code='${C}-CLONE');"
db_exec "DELETE FROM import_batch WHERE batch_code='${C}' OR batch_code='${C}-CLONE';"

assert_match "IMP_BATCH_CREATE ok" "$(run_cobol "IMP_BATCH_CREATE|${C}|CSV|LEDGER|||${A}")" "SUCCESS\|"
assert_match "IMP_BATCH_LIST ok" "$(run_cobol "IMP_BATCH_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "IMP_ROW_STAGE ok" "$(run_cobol "IMP_ROW_STAGE|${C}|1|1000:10.00:0|||${A}")" "SUCCESS\|IMP_ROW_STAGED"
assert_match "IMP_ROW_STAGE ok (2)" "$(run_cobol "IMP_ROW_STAGE|${C}|2|1100:0:10.00|||${A}")" "SUCCESS\|IMP_ROW_STAGED"
assert_match "IMP_BATCH_VALIDATE ok" "$(run_cobol "IMP_BATCH_VALIDATE|${C}|||||${A}")" "SUCCESS\|"
assert_match "IMP_BATCH_SUMMARY ok" "$(run_cobol "IMP_BATCH_SUMMARY|${C}|||||${A}")" "SUCCESS\|"
assert_match "IMP_BATCH_CLONE ok" "$(run_cobol "IMP_BATCH_CLONE|${C}|${C}-CLONE|CSV|||${A}")" "SUCCESS\|"
assert_match "IMP_ROW_SKIP ok" "$(run_cobol "IMP_ROW_SKIP|${C}|1||||${A}")" "SUCCESS\|IMP_ROW_SKIPPED"
assert_match "IMP_ROW_UNSKIP ok" "$(run_cobol "IMP_ROW_UNSKIP|${C}|1||||${A}")" "SUCCESS\|IMP_ROW_UNSKIPPED"
assert_match "IMP_BATCH_REVALIDATE ok" "$(run_cobol "IMP_BATCH_VALIDATE|${C}|||||${A}")" "SUCCESS\|"
assert_match "IMP_ERROR_LIST ok" "$(run_cobol "IMP_ERROR_LIST|${C}|50|0|||${A}")" "SUCCESS\|"
assert_match "IMP_BATCH_EXPORT ok" "$(run_cobol "IMP_BATCH_EXPORT|${C}|CSV||||${A}")" "SUCCESS\|IMP_EXPORT"
assert_match "IMPP_LIST ok" "$(run_cobol "IMPP_LIST|50|0||||${A}")" "SUCCESS\|"
assert_match "IMP_BATCH_FAIL ok" "$(run_cobol "IMP_BATCH_FAIL|${C}|E999|boom|||${A}")" "SUCCESS\|"
assert_match "batch failed" "$(db_query "SELECT status FROM import_batch WHERE batch_code='${C}';")" "^FAILED$"
assert_match "IMP_BATCH_RETRY ok" "$(run_cobol "IMP_BATCH_RETRY|${C}|||||${A}")" "SUCCESS\|"
assert_match "IMP_BATCH_REVALIDATE2 ok" "$(run_cobol "IMP_BATCH_VALIDATE|${C}|||||${A}")" "SUCCESS\|"
assert_match "IMPP_LEDGER ok" "$(run_cobol "IMPP_LEDGER|${C}|2026-06-01|shell post|USD||${A}")" "SUCCESS\|"
assert_match "IMP_BATCH_DELETE ok" "$(run_cobol "IMP_BATCH_DELETE|${C}-CLONE|||||${A}")" "SUCCESS\|"
assert_match "non-admin refused" "$(run_cobol "IMP_BATCH_LIST|50|0||||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM import_row WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}' OR batch_code='${C}-CLONE');"
db_exec "DELETE FROM import_batch WHERE batch_code='${C}' OR batch_code='${C}-CLONE';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
