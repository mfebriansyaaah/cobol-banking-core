#!/bin/bash
# Report engine suite (Phase 1, Sprint 1 slice 3).
# One setup, table-driven report lifecycle cases.
# Usage: ./tests/test_report.sh

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
    q "DELETE FROM report_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM report_run WHERE template_id IN (SELECT id FROM report_template WHERE template_code LIKE 'RPT_TEST%' OR template_code LIKE 'TB_TEST%');
       DELETE FROM report_template WHERE template_code LIKE 'RPT_TEST%' OR template_code LIKE 'TB_TEST%';"
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
echo "  REPORT ENGINE SUITE (PHASE 1)"
echo "======================================================================"
setup

check_contains "create report template" "SUCCESS|RPT_TEMPLATE_CREATED|" \
    "$(run RPT_TEMPLATE_CREATE RPT_TEST 'Trial Balance' TRIAL_BALANCE CSV 'Trial Balance' "$ADM")"
check_contains "list report templates" "RPT_TEST:Trial Balance:TRIAL_BALANCE:CSV:1" \
    "$(run RPT_TEMPLATE_LIST 50 0 '' '' '' "$ADM")"
check "duplicate template rejected" "ERROR|DUPLICATE" \
    "$(run RPT_TEMPLATE_CREATE RPT_TEST 'Again' TRIAL_BALANCE CSV 'Again' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run RPT_TEMPLATE_LIST 50 0 '' '' '' "$USR")"

check_contains "create account column" "SUCCESS|RPT_COLUMN_CREATED|" \
    "$(run RPT_COLUMN_CREATE RPT_TEST 1 Account account_code '20,RIGHT,TEXT' "$ADM")"
check_contains "create debit column" "SUCCESS|RPT_COLUMN_CREATED|" \
    "$(run RPT_COLUMN_CREATE RPT_TEST 2 Debit debit '20,RIGHT,AMOUNT' "$ADM")"
check_contains "create credit column" "SUCCESS|RPT_COLUMN_CREATED|" \
    "$(run RPT_COLUMN_CREATE RPT_TEST 3 Credit credit '20,RIGHT,AMOUNT' "$ADM")"
check_contains "list report columns" "1:Account:account_code:20:RIGHT:TEXT" \
    "$(run RPT_COLUMN_LIST RPT_TEST 50 0 '' '' "$ADM")"
check "duplicate column rejected" "ERROR|DUPLICATE" \
    "$(run RPT_COLUMN_CREATE RPT_TEST 1 Account account_code '20,RIGHT,TEXT' "$ADM")"
check_contains "get template with columns" "RPT_TEST:Trial Balance:TRIAL_BALANCE:CSV:1:Trial Balance" \
    "$(run RPT_TEMPLATE_GET RPT_TEST 1 '' '' '' "$ADM")"

RUN_OUT="$(run RPT_RUN_START RPT_TEST '2026-10-01,2026-10-31,IDR' '' '' '' "$ADM")"
check_contains "start report run" "SUCCESS|RPT_RUN_STARTED|" "$RUN_OUT"
RUN_ID="$(printf '%s' "$RUN_OUT" | cut -d'|' -f3)"
check "add first report row" "SUCCESS|RPT_ROW_ADDED" \
    "$(run RPT_RUN_ROW "$RUN_ID" 1 100 0 '1000,Cash,100.00' "$ADM")"
check "add second report row" "SUCCESS|RPT_ROW_ADDED" \
    "$(run RPT_RUN_ROW "$RUN_ID" 2 0 100 '4000,Fee income,100.00' "$ADM")"
check "duplicate row rejected" "ERROR|DUPLICATE" \
    "$(run RPT_RUN_ROW "$RUN_ID" 1 0 0 'dup' "$ADM")"
check_contains "run status running" "RUNNING" \
    "$(run RPT_RUN_STATUS "$RUN_ID" 0 '' '' '' "$ADM")"
check "mismatched completion rejected" "ERROR|ROW_MISMATCH" \
    "$(run RPT_RUN_COMPLETE "$RUN_ID" '3,100,100' checksum '' '' "$ADM")"
check "complete report run" "SUCCESS|RPT_RUN_COMPLETED" \
    "$(run RPT_RUN_COMPLETE "$RUN_ID" '2,100,100' checksum '' '' "$ADM")"
check_contains "run status completed" "COMPLETED:2026-10-01,2026-10-31,IDR:2:100" \
    "$(run RPT_RUN_STATUS "$RUN_ID" 0 '' '' '' "$ADM")"
check "completed run cannot complete again" "ERROR|INVALID_STATUS" \
    "$(run RPT_RUN_COMPLETE "$RUN_ID" '2,100,100' checksum '' '' "$ADM")"
check_contains "export report CSV" "Account,Debit,Credit|1000,Cash,100.00" \
    "$(run RPT_RUN_EXPORT "$RUN_ID" CSV '' '' '' "$ADM")"
check_contains "run list filters completed" "RPT_TEST:COMPLETED" \
    "$(run RPT_RUN_LIST 50 0 COMPLETED RPT_TEST '' "$ADM")"

FAIL_OUT="$(run RPT_RUN_START RPT_TEST '2026-11-01,2026-11-30,IDR' '' '' '' "$ADM")"
FAIL_ID="$(printf '%s' "$FAIL_OUT" | cut -d'|' -f3)"
check "fail report run" "SUCCESS|RPT_RUN_FAILED" \
    "$(run RPT_RUN_FAIL "$FAIL_ID" TEST_FAIL 'forced failure' '' '' "$ADM")"
check_contains "failed run status" "FAILED" \
    "$(run RPT_RUN_STATUS "$FAIL_ID" 0 '' '' '' "$ADM")"
check "failed run cannot export" "ERROR|REPORT_NOT_COMPLETE" \
    "$(run RPT_RUN_EXPORT "$FAIL_ID" CSV '' '' '' "$ADM")"

check "report audit rows recorded" "9" \
    "$(q "SELECT COUNT(*) FROM report_audit WHERE actor_email IN ('$ADM','$USR');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
