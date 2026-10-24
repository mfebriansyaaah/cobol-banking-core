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
ADM="nau_admin@test.com"; USR="nau_user@test.com"
cleanup() {
    q "DELETE FROM notification_audit WHERE enqueued_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1561,'$ADM','x','NAU Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1562,'$USR','x','NAU User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  NOTIFICATION AUDIT SUITE (PHASE 2)"
echo "======================================================================"
setup
check "enqueue notification" "SUCCESS|NAU_ENQUEUED" \
    "$(run NAU_ENQUEUE "EMAIL" "user@test.com" "" "" "" "$ADM")"
NID=$(q "SELECT id FROM notification_delivery WHERE enqueued_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list notification audit" "$NID" \
    "$(run NAU_LIST "" 50 0 "" "" "$ADM")"
check_contains "get notification audit" "NAU_ENTRY|" \
    "$(run NAU_GET "$NID" "" "" "" "" "$ADM")"
check "retry notification" "SUCCESS|NAU_RETRIED" \
    "$(run NAU_RETRY "$NID" "" "" "" "" "$ADM")"
check_contains "notification audit summary" "NAU_SUMMARY|" \
    "$(run NAU_SUMMARY "" "" "" "" "" "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run NAU_SUMMARY "" "" "" "" "" "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]