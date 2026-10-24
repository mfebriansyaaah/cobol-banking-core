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
ADM="rau_admin@test.com"; USR="rau_user@test.com"
cleanup() {
    q "DELETE FROM report_audit_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM report_audit WHERE recorded_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1571,'$ADM','x','RAU Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1572,'$USR','x','RAU User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  REPORT AUDIT SUITE (PHASE 2)"
echo "======================================================================"
setup
check "record report audit" "SUCCESS|RAU_RECORDED" \
    "$(run RAU_RECORD "daily_report" 120 "OK" "" "" "$ADM")"
RID=$(q "SELECT id FROM report_execution_audit WHERE recorded_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list report audit" "$RID" \
    "$(run RAU_LIST "" 50 0 "" "" "$ADM")"
check_contains "get report audit" "RAU_ENTRY|" \
    "$(run RAU_GET "$RID" "" "" "" "" "$ADM")"
check_contains "report audit summary" "RAU_SUMMARY|" \
    "$(run RAU_SUMMARY "" "" "" "" "" "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run RAU_SUMMARY "" "" "" "" "" "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]