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
ADM="dsr_admin@test.com"; USR="dsr_user@test.com"; SUB="dsr_subject@test.com"
cleanup() {
    q "DELETE FROM dsar_request_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM dsar_request WHERE received_by IN ('$ADM','$USR');
       DELETE FROM legal_hold_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM legal_hold WHERE placed_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR','$SUB');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1421,'$ADM','x','DSR Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1422,'$USR','x','DSR User','1990-01-01','VERIFIED','USER'),
       (1423,'$SUB','x','DSR Subject','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  DSAR SUITE (PHASE 3)"
echo "======================================================================"
setup
check "receive dsar export" "SUCCESS|DSR_RECEIVED" \
    "$(run DSR_RECEIVE "$SUB" "EXPORT" "PROFILE" "" "" "$ADM")"
RID=$(q "SELECT id FROM dsar_request WHERE subject_email='$SUB' ORDER BY id DESC LIMIT 1;")
check "start dsar" "SUCCESS|DSR_STARTED" \
    "$(run DSR_START "$RID" "" "" "" "" "$ADM")"
check "fulfill export" "SUCCESS|DSR_FULFILLED" \
    "$(run DSR_FULFILL "$RID" "done" "" "" "" "$ADM")"
check "receive dsar erase" "SUCCESS|DSR_RECEIVED" \
    "$(run DSR_RECEIVE "$SUB" "ERASE" "PROFILE" "" "" "$ADM")"
EID=$(q "SELECT id FROM dsar_request WHERE subject_email='$SUB' AND request_type='ERASE' ORDER BY id DESC LIMIT 1;")
check "start erase" "SUCCESS|DSR_STARTED" \
    "$(run DSR_START "$EID" "" "" "" "" "$ADM")"
# place a legal hold to block erase
q "INSERT INTO legal_hold (subject_email, case_ref, scope, status, placed_by) VALUES ('$SUB','DSR_CASE','USER','ACTIVE','$ADM');"
check "erase blocked by legal hold" "ERROR|LEGAL_HOLD_BLOCKED" \
    "$(run DSR_FULFILL "$EID" "erase" "" "" "" "$ADM")"
q "DELETE FROM legal_hold WHERE case_ref='DSR_CASE';"
check "reject dsar" "ERROR|INVALID_STATUS" \
    "$(run DSR_REJECT "$RID" "dup" "" "" "" "$ADM")"
check_contains "dsar list" "$RID" \
    "$(run DSR_LIST "" 50 0 "" "" "$ADM")"
check_contains "dsar summary" "DSR_SUMMARY|" \
    "$(run DSR_SUMMARY "" "" "" "" "" "$ADM")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]