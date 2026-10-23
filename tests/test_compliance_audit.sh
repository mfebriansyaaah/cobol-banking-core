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
ADM="ca_admin@test.com"; USR="ca_user@test.com"
cleanup() {
    q "DELETE FROM compliance_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM compliance_finding WHERE raised_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1531,'$ADM','x','CA Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1532,'$USR','x','CA User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  COMPLIANCE AUDIT SUITE (PHASE 2)"
echo "======================================================================"
setup
check "raise finding" "SUCCESS|CA_RAISED" \
    "$(run CA_FINDING_RAISE "Missing control" "HIGH" "" "" "" "$ADM")"
FID=$(q "SELECT id FROM compliance_finding WHERE raised_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list findings" "$FID" \
    "$(run CA_FINDING_LIST "" 50 0 "" "" "$ADM")"
check_contains "get finding" "CA_FINDING|" \
    "$(run CA_FINDING_GET "$FID" "" "" "" "" "$ADM")"
check "close finding" "SUCCESS|CA_CLOSED" \
    "$(run CA_FINDING_CLOSE "$FID" "" "" "" "" "$ADM")"
check_contains "compliance summary" "CA_SUMMARY|" \
    "$(run CA_SUMMARY "" "" "" "" "" "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run CA_SUMMARY "" "" "" "" "" "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]