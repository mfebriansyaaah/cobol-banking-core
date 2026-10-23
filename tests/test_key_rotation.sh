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
ADM="kro_admin@test.com"; USR="kro_user@test.com"
cleanup() {
    q "DELETE FROM key_rotation_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM key_rotation_plan WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1411,'$ADM','x','KRO Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1412,'$USR','x','KRO User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  KEY ROTATION SUITE (PHASE 3)"
echo "======================================================================"
setup
check "create rotation plan" "SUCCESS|KRO_PLAN_CREATED" \
    "$(run KRO_PLAN_CREATE "JWT_SIGNING" 300 "2030-01-01 00:00" "" "" "$ADM")"
PID=$(q "SELECT id FROM key_rotation_plan WHERE key_name='JWT_SIGNING' AND created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list rotation plans" "$PID" \
    "$(run KRO_PLAN_LIST "" 50 0 "" "" "$ADM")"
check_contains "get rotation plan" "KRO_PLAN|" \
    "$(run KRO_PLAN_GET "$PID" "" "" "" "" "$ADM")"
check "rotate plan" "SUCCESS|KRO_ROTATED" \
    "$(run KRO_ROTATE "$PID" "" "" "" "" "$ADM")"
check "complete plan" "SUCCESS|KRO_COMPLETED" \
    "$(run KRO_COMPLETE "$PID" "" "" "" "" "$ADM")"
check "cancel already completed invalid" "ERROR|INVALID_STATUS" \
    "$(run KRO_CANCEL "$PID" "done" "" "" "" "$ADM")"
check_contains "due plans" "KRO_DUE|" \
    "$(run KRO_DUE "2031-01-01" "" "" "" "" "$ADM")"
check_contains "rotation summary" "KRO_SUMMARY|" \
    "$(run KRO_SUMMARY "" "" "" "" "" "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run KRO_SUMMARY "" "" "" "" "" "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]