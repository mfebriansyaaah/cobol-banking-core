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
ADM="scr_admin@test.com"; USR="scr_user@test.com"
cleanup() {
    q "DELETE FROM secret_rotation_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM secret_rotation WHERE scheduled_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1491,'$ADM','x','SCR Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1492,'$USR','x','SCR User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  SECRET ROTATION SUITE (PHASE 2)"
echo "======================================================================"
setup
check "schedule secret" "SUCCESS|SCR_SCHEDULED" \
    "$(run SCR_SCHEDULE "JWT_KEY" "2030-01-01 00:00" 300 "" "" "$ADM")"
SID=$(q "SELECT id FROM secret_rotation WHERE scheduled_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list secrets" "$SID" \
    "$(run SCR_LIST "" 50 0 "" "" "$ADM")"
check_contains "get secret" "SCR_SECRET|" \
    "$(run SCR_GET "$SID" "" "" "" "" "$ADM")"
check "rotate secret" "SUCCESS|SCR_ROTATED" \
    "$(run SCR_ROTATE "$SID" "" "" "" "" "$ADM")"
check "verify secret" "SUCCESS|SCR_VERIFIED" \
    "$(run SCR_VERIFY "$SID" "" "" "" "" "$ADM")"
check_contains "secret summary" "SCR_SUMMARY|" \
    "$(run SCR_SUMMARY "" "" "" "" "" "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run SCR_SUMMARY "" "" "" "" "" "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]