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
ADM="stl_admin@test.com"; USR="stl_user@test.com"
cleanup() {
    q "DELETE FROM statement_delivery_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM statement_delivery WHERE recipient IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1270,'$ADM','x','STL Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1271,'$USR','x','STL User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  STATEMENT DELIVERY SUITE (PHASE 1)"
echo "======================================================================"
setup
check "enqueue statement delivery" "SUCCESS|STL_ENQUEUED" \
    "$(run STL_ENQUEUE STMT1 "$ADM" EMAIL 'test delivery' '' "$ADM")"
DID=$(q "SELECT id FROM statement_delivery WHERE recipient='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "get statement delivery" "STL_DELIVERY|$DID" \
    "$(run STL_GET "$DID" '' '' '' '' "$ADM")"
check_contains "list statement deliveries" "$DID" \
    "$(run STL_LIST '' 50 0 '' '' "$ADM")"
check "send statement delivery" "SUCCESS|STL_SENT" \
    "$(run STL_SEND "$DID" '' '' '' '' "$ADM")"
check "deliver statement delivery" "SUCCESS|STL_DELIVERED" \
    "$(run STL_DELIVER "$DID" '' '' '' '' "$ADM")"
check "retry not applicable" "ERROR|INVALID_STATUS" \
    "$(run STL_RETRY "$DID" '' '' '' '' "$ADM")"
check "cleanup old deliveries" "SUCCESS|STL_CLEANED" \
    "$(run STL_CLEANUP 2000-01-01 '' '' '' '' "$ADM")"
check_contains "statement delivery summary" "STL_SUMMARY|" \
    "$(run STL_SUMMARY '' '' '' '' '' "$ADM")"
check "missing delivery rejected" "ERROR|NOT_FOUND" \
    "$(run STL_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run STL_SUMMARY '' '' '' '' '' "$USR")"
check "statement delivery audit rows recorded" "1" \
    "$(q "SELECT COUNT(*) FROM statement_delivery_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('ENQUEUE','SEND','DELIVER','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
