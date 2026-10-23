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
ADM="prc_admin@test.com"; USR="prc_user@test.com"
cleanup() {
    q "DELETE FROM procurement_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM procurement_request WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1410,'$ADM','x','PRC Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1411,'$USR','x','PRC User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  PROCUREMENT SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create procurement request" "SUCCESS|PRC_CREATED" \
    "$(run PRC_REQUEST_CREATE PRC1 'Office supplies' 500.00 '' '' "$ADM")"
RID=$(q "SELECT id FROM procurement_request WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list procurement requests" "$RID" \
    "$(run PRC_REQUEST_LIST DRAFT 50 0 '' '' "$ADM")"
check "approve procurement request" "SUCCESS|PRC_APPROVED" \
    "$(run PRC_REQUEST_APPROVE "$RID" '' '' '' '' "$ADM")"
check "order procurement request" "SUCCESS|PRC_ORDERED" \
    "$(run PRC_REQUEST_ORDER "$RID" '' '' '' '' "$ADM")"
check "cannot approve again" "ERROR|INVALID_STATUS" \
    "$(run PRC_REQUEST_APPROVE "$RID" '' '' '' '' "$ADM")"
check_contains "procurement summary" "PRC_SUMMARY|" \
    "$(run PRC_SUMMARY '' '' '' '' '' "$ADM")"
check "missing request rejected" "ERROR|INVALID_STATUS" \
    "$(run PRC_REQUEST_APPROVE 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run PRC_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
