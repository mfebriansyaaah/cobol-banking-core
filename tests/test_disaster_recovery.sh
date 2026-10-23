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
ADM="dr_admin@test.com"; USR="dr_user@test.com"
cleanup() {
    q "DELETE FROM dr_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM dr_test WHERE tested_by IN ('$ADM','$USR');
       DELETE FROM dr_plan WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1501,'$ADM','x','DR Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1502,'$USR','x','DR User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  DISASTER RECOVERY SUITE (PHASE 2)"
echo "======================================================================"
setup
check "define dr plan" "SUCCESS|DRC_DEFINED" \
    "$(run DRC_DEFINE "Primary DR" 60 15 "" "" "$ADM")"
PID=$(q "SELECT id FROM dr_plan WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list dr plans" "$PID" \
    "$(run DRC_LIST "" 50 0 "" "" "$ADM")"
check_contains "get dr plan" "DR_PLAN|" \
    "$(run DRC_GET "$PID" "" "" "" "" "$ADM")"
check "dr test" "SUCCESS|DRC_TESTED" \
    "$(run DRC_TEST "$PID" "PASS" "" "" "" "$ADM")"
check "complete dr" "SUCCESS|DRC_COMPLETED" \
    "$(run DRC_COMPLETE "$PID" "" "" "" "" "$ADM")"
check_contains "dr summary" "DRC_SUMMARY|" \
    "$(run DRC_SUMMARY "" "" "" "" "" "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run DRC_SUMMARY "" "" "" "" "" "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]