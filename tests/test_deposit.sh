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
ADM="dep_admin@test.com"; USR="dep_user@test.com"
cleanup() {
    q "DELETE FROM deposit_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM deposit_account WHERE customer_email IN ('$ADM','$USR') OR created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1330,'$ADM','x','DEP Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1331,'$USR','x','DEP User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  DEPOSIT SUITE (PHASE 1)"
echo "======================================================================"
setup
check "open deposit" "SUCCESS|DEP_OPENED" \
    "$(run DEP_OPEN "$ADM" 10000.00 USD 12 0.04 "$ADM")"
DID=$(q "SELECT id FROM deposit_account WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "get deposit" "DEPOSIT|$DID" \
    "$(run DEP_GET "$DID" '' '' '' '' "$ADM")"
check_contains "list deposits" "$DID" \
    "$(run DEP_LIST ACTIVE 50 0 '' '' "$ADM")"
check "mature deposits" "SUCCESS|DEP_MATURED" \
    "$(run DEP_MATURE '' '' '' '' '' "$ADM")"
check "close deposit" "SUCCESS|DEP_CLOSED" \
    "$(run DEP_CLOSE "$DID" '' '' '' '' "$ADM")"
check_contains "deposit summary" "DEP_SUMMARY|" \
    "$(run DEP_SUMMARY '' '' '' '' '' "$ADM")"
check "missing deposit rejected" "ERROR|NOT_FOUND" \
    "$(run DEP_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run DEP_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
