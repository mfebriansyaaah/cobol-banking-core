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
ADM="trp_admin@test.com"; USR="trp_user@test.com"
cleanup() {
    q "DELETE FROM treasury_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM treasury_position WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1350,'$ADM','x','TRP Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1351,'$USR','x','TRP User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  TREASURY POSITION SUITE (PHASE 1)"
echo "======================================================================"
setup
check "open treasury position" "SUCCESS|TRP_OPENED" \
    "$(run TRP_OPEN USD 1000000.00 2026-10-23 '' '' "$ADM")"
PID=$(q "SELECT id FROM treasury_position WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list treasury positions" "$PID" \
    "$(run TRP_LIST OPEN 50 0 '' '' "$ADM")"
check "close treasury position" "SUCCESS|TRP_CLOSED" \
    "$(run TRP_CLOSE "$PID" '' '' '' '' "$ADM")"
check "cannot close again" "ERROR|INVALID_STATUS" \
    "$(run TRP_CLOSE "$PID" '' '' '' '' "$ADM")"
check_contains "treasury summary" "TRP_SUMMARY|" \
    "$(run TRP_SUMMARY '' '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run TRP_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
