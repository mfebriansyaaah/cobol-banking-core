#!/bin/bash
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="str_admin@test.com"; USR="str_user@test.com"
cleanup() {
    q "DELETE FROM settlement_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM settlement_item WHERE run_id IN (SELECT id FROM settlement_run WHERE started_by IN ('$ADM','$USR'));
       DELETE FROM settlement_run WHERE started_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1260,'$ADM','x','STR Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1261,'$USR','x','STR User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  SETTLEMENT RECONCILIATION SUITE (PHASE 1)"
echo "======================================================================"
setup
check "start settlement run" "SUCCESS|STR_RUN_STARTED" \
    "$(run STR_RUN_START BATCH001 '' '' '' '' "$ADM")"
RID=$(q "SELECT id FROM settlement_run WHERE started_by='$ADM' ORDER BY id DESC LIMIT 1;")
check "add matched item" "SUCCESS|STR_ITEM_ADDED" \
    "$(run STR_ITEM_ADD "$RID" TXN1 100.00 MATCHED '' "$ADM")"
check "add break item" "SUCCESS|STR_ITEM_ADDED" \
    "$(run STR_ITEM_ADD "$RID" TXN2 50.00 BREAK '' "$ADM")"
check_contains "list settlement items" "TXN1" \
    "$(run STR_ITEM_LIST "$RID" '' '' '' '' "$ADM")"
check "complete settlement run" "SUCCESS|STR_RUN_COMPLETED" \
    "$(run STR_RUN_COMPLETE "$RID" 1 1 '' '' "$ADM")"
check_contains "get settlement run" "STR_RUN|$RID" \
    "$(run STR_RUN_GET "$RID" '' '' '' '' "$ADM")"
check_contains "list settlement runs" "$RID" \
    "$(run STR_RUN_LIST '' 50 0 '' '' "$ADM")"
IID=$(q "SELECT id FROM settlement_item WHERE run_id=$RID AND status='BREAK' LIMIT 1;")
check "resolve break item" "SUCCESS|STR_ITEM_RESOLVED" \
    "$(run STR_ITEM_RESOLVE "$IID" 'note' '' '' '' "$ADM")"
check_contains "settlement summary" "STR_SUMMARY|" \
    "$(run STR_SUMMARY '' '' '' '' '' "$ADM")"
check "missing run rejected" "ERROR|NOT_FOUND" \
    "$(run STR_RUN_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run STR_SUMMARY '' '' '' '' '' "$USR")"
check "settlement audit rows recorded" "1" \
    "$(q "SELECT COUNT(*) FROM settlement_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('RUN_START','RUN_COMPLETE','ITEM_RESOLVE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
