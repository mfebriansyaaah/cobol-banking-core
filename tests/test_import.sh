#!/bin/bash
# Import/export foundation suite (Phase 1, Sprint 1 slice 3).
# One setup, table-driven staging, validation, correction, posting, export.
# Usage: ./tests/test_import.sh

BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }

ADM="report_admin@test.com"; USR="report_user@test.com"
cleanup() {
    q "DELETE FROM import_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM import_batch WHERE batch_code LIKE 'IMP_TEST%' OR batch_code LIKE 'IMP_BAD%' OR batch_code LIKE 'IMP_FAIL%' OR batch_code LIKE 'IMP_BULK%' OR batch_code LIKE 'IMP_CLONE%';"
}
setup() {
    cleanup
    q "DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (992,'$ADM','x','Report Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (993,'$USR','x','Report User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=993; DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  IMPORT/EXPORT FOUNDATION SUITE (PHASE 1)"
echo "======================================================================"
setup

check_contains "create import batch" "SUCCESS|IMP_BATCH_CREATED|" \
    "$(run IMP_BATCH_CREATE IMP_TEST source.csv LEDGER '' '' "$ADM")"
check_contains "list import batches" "IMP_TEST:source.csv:LEDGER:STAGED" \
    "$(run IMP_BATCH_LIST 50 0 '' '' '' "$ADM")"
check "duplicate batch rejected" "ERROR|DUPLICATE" \
    "$(run IMP_BATCH_CREATE IMP_TEST 'again' LEDGER '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run IMP_BATCH_LIST 50 0 '' '' '' "$USR")"

check "stage first ledger row" "SUCCESS|IMP_ROW_STAGED" \
    "$(run IMP_ROW_STAGE IMP_TEST 1 '1000:100:0' '' '' "$ADM")"
check "stage second ledger row" "SUCCESS|IMP_ROW_STAGED" \
    "$(run IMP_ROW_STAGE IMP_TEST 2 '4000:0:100' '' '' "$ADM")"
check "duplicate row rejected" "ERROR|DUPLICATE" \
    "$(run IMP_ROW_STAGE IMP_TEST 1 '1000:1:0' '' '' "$ADM")"
check "validate import batch" "SUCCESS|IMP_VALIDATED|2|0" \
    "$(run IMP_BATCH_VALIDATE IMP_TEST '' '' '' '' "$ADM")"
check_contains "batch has valid rows" "VALID" \
    "$(run IMP_BATCH_GET IMP_TEST 1 '' '' '' "$ADM")"
check "post validated batch" "SUCCESS|IMP_POSTED|2" \
    "$(run IMP_BATCH_POST IMP_TEST '' '' '' '' "$ADM")"
check_contains "batch completed" "COMPLETED:2:2:0:2" \
    "$(run IMP_BATCH_GET IMP_TEST 0 '' '' '' "$ADM")"
check_contains "batch row summary" "SUCCESS|IMP_SUMMARY|COMPLETED|2|2|0|2|" \
    "$(run IMP_BATCH_SUMMARY IMP_TEST '' '' '' '' "$ADM")"
check_contains "export posted batch" "1:POSTED:1000:100:0" \
    "$(run IMP_BATCH_EXPORT IMP_TEST CSV '' '' '' "$ADM")"
check "no import errors" "SUCCESS|IMP_ERRORS|0" \
    "$(run IMP_ERROR_LIST IMP_TEST 50 0 '' '' "$ADM")"

check_contains "create invalid batch" "SUCCESS|IMP_BATCH_CREATED|" \
    "$(run IMP_BATCH_CREATE IMP_BAD bad.csv LEDGER '' '' "$ADM")"
check "stage unknown-account row" "SUCCESS|IMP_ROW_STAGED" \
    "$(run IMP_ROW_STAGE IMP_BAD 1 '9999:100:0' '' '' "$ADM")"
check "validation finds invalid row" "SUCCESS|IMP_VALIDATED|0|1" \
    "$(run IMP_BATCH_VALIDATE IMP_BAD '' '' '' '' "$ADM")"
check_contains "error lists unknown account" "ACCOUNT_NOT_FOUND" \
    "$(run IMP_ERROR_LIST IMP_BAD 50 0 '' '' "$ADM")"
check "invalid batch cannot post" "ERROR|INVALID_ROWS" \
    "$(run IMP_BATCH_POST IMP_BAD '' '' '' '' "$ADM")"
check "correct invalid row" "SUCCESS|IMP_ROW_CORRECTED" \
    "$(run IMP_ROW_CORRECT IMP_BAD 1 '1000:100:0' '' '' "$ADM")"
check "revalidate corrected batch" "SUCCESS|IMP_VALIDATED|1|0" \
    "$(run IMP_BATCH_VALIDATE IMP_BAD '' '' '' '' "$ADM")"
check "post corrected batch" "SUCCESS|IMP_POSTED|1" \
    "$(run IMP_BATCH_POST IMP_BAD '' '' '' '' "$ADM")"

check_contains "create failable batch" "SUCCESS|IMP_BATCH_CREATED|" \
    "$(run IMP_BATCH_CREATE IMP_FAIL fail.csv REFERENCE '' '' "$ADM")"
check "fail import batch" "SUCCESS|IMP_FAILED" \
    "$(run IMP_BATCH_FAIL IMP_FAIL TEST_FAIL 'forced failure' '' '' "$ADM")"
check_contains "failed batch status" "FAILED" \
    "$(run IMP_BATCH_GET IMP_FAIL 0 '' '' '' "$ADM")"
check "retry failed batch" "SUCCESS|IMP_BATCH_RETRIED" \
    "$(run IMP_BATCH_RETRY IMP_FAIL '' '' '' '' "$ADM")"
check_contains "retried batch is staged" "STAGED" \
    "$(run IMP_BATCH_GET IMP_FAIL 0 '' '' '' "$ADM")"

check_contains "create bulk batch" "SUCCESS|IMP_BATCH_CREATED|" \
    "$(run IMP_BATCH_CREATE IMP_BULK bulk.csv LEDGER '' '' "$ADM")"
check "bulk stage rows" "SUCCESS|IMP_BULK_STAGED|4" \
    "$(run IMP_BATCH_STAGE_BULK IMP_BULK '1000:100:0;4000:0:100' '5000:10:0;1100:0:10' '' '' "$ADM")"
check "validate bulk batch" "SUCCESS|IMP_VALIDATED|4|0" \
    "$(run IMP_BATCH_VALIDATE IMP_BULK '' '' '' '' "$ADM")"
check "skip a valid row" "SUCCESS|IMP_ROW_SKIPPED" \
    "$(run IMP_ROW_SKIP IMP_BULK 4 '' '' '' "$ADM")"
check_contains "skip updates counts" "VALIDATED:4:3:0:0" \
    "$(run IMP_BATCH_GET IMP_BULK 0 '' '' '' "$ADM")"
check "unskip a row" "SUCCESS|IMP_ROW_UNSKIPPED" \
    "$(run IMP_ROW_UNSKIP IMP_BULK 4 '' '' '' "$ADM")"
check_contains "unskip resets batch" "STAGED" \
    "$(run IMP_BATCH_GET IMP_BULK 0 '' '' '' "$ADM")"
check_contains "clone completed batch" "SUCCESS|IMP_BATCH_CLONED|" \
    "$(run IMP_BATCH_CLONE IMP_TEST IMP_CLONE cloned.csv '' '' "$ADM")"
check_contains "clone rows are staged" "STAGED" \
    "$(run IMP_BATCH_GET IMP_CLONE 1 '' '' '' "$ADM")"
check "delete staged clone" "SUCCESS|IMP_BATCH_DELETED" \
    "$(run IMP_BATCH_DELETE IMP_CLONE '' '' '' '' "$ADM")"

check "missing batch rejected" "ERROR|NOT_FOUND" \
    "$(run IMP_BATCH_GET MISSING 0 '' '' '' "$ADM")"
check "staging into completed batch rejected" "ERROR|INVALID_STATUS" \
    "$(run IMP_ROW_STAGE IMP_TEST 99 '1000:1:0' '' '' "$ADM")"
check "unskip on completed batch rejected" "ERROR|INVALID_STATUS" \
    "$(run IMP_ROW_UNSKIP IMP_TEST 1 '' '' '' "$ADM")"
check "completed batch cannot be deleted" "ERROR|INVALID_STATUS" \
    "$(run IMP_BATCH_DELETE IMP_TEST '' '' '' '' "$ADM")"
check "missing error batch rejected" "ERROR|NOT_FOUND" \
    "$(run IMP_ERROR_LIST MISSING 50 0 '' '' "$ADM")"

check "missing clone source rejected" "ERROR|NOT_FOUND" \
    "$(run IMP_BATCH_CLONE MISSING IMP_X x.csv '' '' "$ADM")"
check "completed batch cannot retry" "ERROR|INVALID_STATUS" \
    "$(run IMP_BATCH_RETRY IMP_TEST '' '' '' '' "$ADM")"
check "missing summary rejected" "ERROR|NOT_FOUND" \
    "$(run IMP_BATCH_SUMMARY MISSING '' '' '' '' "$ADM")"
check "missing batch delete rejected" "ERROR|NOT_FOUND" \
    "$(run IMP_BATCH_DELETE MISSING '' '' '' '' "$ADM")"
check "missing skip batch rejected" "ERROR|NOT_FOUND" \
    "$(run IMP_ROW_SKIP MISSING 1 '' '' '' "$ADM")"

check "import audit rows recorded" "19" \
    "$(q "SELECT COUNT(*) FROM import_audit WHERE actor_email IN ('$ADM','$USR');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
