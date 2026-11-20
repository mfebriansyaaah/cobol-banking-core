#!/usr/bin/env bash
# Import row operations (PR-5c): stage/skip/unskip/error list.
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
C="IMPR-D1"
db_exec "DELETE FROM import_row WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
db_exec "DELETE FROM import_batch WHERE batch_code='${C}';"
db_exec "DELETE FROM import_audit WHERE batch_code='${C}';"

assert_match "batch create ok" "$(run_cobol "IMP_BATCH_CREATE|${C}|CSV|LEDGER|||${A}")" "SUCCESS\|"
assert_match "row stage ok" "$(run_cobol "IMP_ROW_STAGE|${C}|1|1000:10.00:0|||${A}")" "SUCCESS\|IMP_ROW_STAGED"
assert_match "batch validate ok" "$(run_cobol "IMP_BATCH_VALIDATE|${C}|||||${A}")" "SUCCESS\|"
assert_match "row persisted" "$(db_query "SELECT status FROM import_row WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='${C}') AND row_no=1;")" "^VALID$"
assert_match "row skip ok" "$(run_cobol "IMP_ROW_SKIP|${C}|1||||${A}")" "SUCCESS\|IMP_ROW_SKIPPED"
assert_match "skip persisted" "$(db_query "SELECT status FROM import_row WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='${C}') AND row_no=1;")" "^SKIPPED$"
assert_match "row unskip ok" "$(run_cobol "IMP_ROW_UNSKIP|${C}|1||||${A}")" "SUCCESS\|IMP_ROW_UNSKIPPED"
assert_match "unskip persisted" "$(db_query "SELECT status FROM import_row WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='${C}') AND row_no=1;")" "^STAGED$"
assert_match "error list ok" "$(run_cobol "IMP_ERROR_LIST|${C}|50|0|||${A}")" "SUCCESS\|"
assert_match "non-admin stage refused" "$(run_cobol "IMP_ROW_STAGE|${C}|2|1100:0:10.00|||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM import_row WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code='${C}');"
db_exec "DELETE FROM import_batch WHERE batch_code='${C}';"
db_exec "DELETE FROM import_audit WHERE batch_code='${C}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
