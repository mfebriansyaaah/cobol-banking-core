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
ADM="chg_admin@test.com"; ADM2="chg_admin2@test.com"; USR="chg_user@test.com"
cleanup() {
    q "DELETE FROM change_audit WHERE actor_email IN ('$ADM','$ADM2','$USR');
       DELETE FROM change_request WHERE requested_by IN ('$ADM','$ADM2','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$ADM2','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1471,'$ADM','x','CHG Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1472,'$ADM2','x','CHG Admin2','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1473,'$USR','x','CHG User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  CHANGE CONTROL SUITE (PHASE 2)"
echo "======================================================================"
setup
check "request change" "SUCCESS|CHG_REQUESTED" \
    "$(run CHG_REQUEST "Deploy fix" "CODE" "LOW" "" "" "$ADM")"
CID=$(q "SELECT id FROM change_request WHERE requested_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list changes" "$CID" \
    "$(run CHG_LIST "" 50 0 "" "" "$ADM")"
check_contains "get change" "CHG_CHANGE|" \
    "$(run CHG_GET "$CID" "" "" "" "" "$ADM")"
check "approve change" "SUCCESS|CHG_APPROVED" \
    "$(run CHG_APPROVE "$CID" "" "" "" "" "$ADM2")"
check "deploy change" "SUCCESS|CHG_DEPLOYED" \
    "$(run CHG_DEPLOY "$CID" "" "" "" "" "$ADM")"
check "rollback change" "SUCCESS|CHG_ROLLED_BACK" \
    "$(run CHG_ROLLBACK "$CID" "" "" "" "" "$ADM")"
check_contains "change summary" "CHG_SUMMARY|" \
    "$(run CHG_SUMMARY "" "" "" "" "" "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run CHG_SUMMARY "" "" "" "" "" "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]