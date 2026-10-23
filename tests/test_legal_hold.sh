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
ADM="lho_admin@test.com"; USR="lho_user@test.com"
cleanup() {
    q "DELETE FROM legal_hold_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM legal_hold WHERE placed_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1401,'$ADM','x','LHO Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1402,'$USR','x','LHO User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  LEGAL HOLD SUITE (PHASE 3)"
echo "======================================================================"
setup
check "place legal hold" "SUCCESS|LHO_PLACED" \
    "$(run LHO_PLACE "lho_user@test.com" "CASE1" "USER" "reason" "" "$ADM")"
HID=$(q "SELECT id FROM legal_hold WHERE case_ref='CASE1' LIMIT 1;")
check_contains "list legal holds" "$HID" \
    "$(run LHO_LIST "" 50 0 "" "" "$ADM")"
check_contains "get legal hold" "LHO_HOLD|" \
    "$(run LHO_GET "$HID" "" "" "" "" "$ADM")"
check "check held" "SUCCESS|LHO_HELD" \
    "$(run LHO_CHECK "lho_user@test.com" "" "" "" "" "$ADM")"
check_contains "legal hold summary" "LHO_SUMMARY|" \
    "$(run LHO_SUMMARY "" "" "" "" "" "$ADM")"
check "release legal hold" "SUCCESS|LHO_RELEASED" \
    "$(run LHO_RELEASE "$HID" "done" "" "" "" "$ADM")"
check "check not held" "SUCCESS|LHO_NOT_HELD" \
    "$(run LHO_CHECK "lho_user@test.com" "" "" "" "" "$ADM")"
check "duplicate case rejected" "ERROR|DUPLICATE" \
    "$(run LHO_PLACE "lho_user@test.com" "CASE1" "USER" "reason" "" "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run LHO_SUMMARY "" "" "" "" "" "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]