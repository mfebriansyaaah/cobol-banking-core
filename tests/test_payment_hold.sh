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
ADM="phl_admin@test.com"; USR="phl_user@test.com"; ACC=1
cleanup() {
    q "DELETE FROM payment_hold WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1220,'$ADM','x','PHL Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1221,'$USR','x','PHL User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  PAYMENT HOLD SUITE (PHASE 1)"
echo "======================================================================"
setup
check "reserve payment hold" "SUCCESS|PHL_RESERVED" \
    "$(run PHL_RESERVE "$ACC" 100.00 USD '' '' "$ADM")"
HID=$(q "SELECT id FROM payment_hold WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "get payment hold" "PHL_HOLD|$HID" \
    "$(run PHL_GET "$HID" '' '' '' '' "$ADM")"
check_contains "list payment holds" "$HID" \
    "$(run PHL_LIST '' ACTIVE 50 0 '' "$ADM")"
check "release hold" "SUCCESS|PHL_RELEASED" \
    "$(run PHL_RELEASE "$HID" '' '' '' '' "$ADM")"
check "cannot release again" "ERROR|INVALID_STATUS" \
    "$(run PHL_RELEASE "$HID" '' '' '' '' "$ADM")"
check "expire idle holds" "SUCCESS|PHL_EXPIRED" \
    "$(run PHL_EXPIRE '' '' '' '' '' "$ADM")"
check_contains "hold summary" "PHL_SUMMARY|" \
    "$(run PHL_SUMMARY '' '' '' '' '' "$ADM")"
check "missing hold rejected" "ERROR|NOT_FOUND" \
    "$(run PHL_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run PHL_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
