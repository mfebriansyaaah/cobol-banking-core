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
ADM="drt_admin@test.com"; USR="drt_user@test.com"
cleanup() {
    q "DELETE FROM data_retention_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM data_retention_run WHERE run_by IN ('$ADM','$USR');
       DELETE FROM data_retention_policy WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1581,'$ADM','x','DRT Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1582,'$USR','x','DRT User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  DATA RETENTION SUITE (PHASE 2)"
echo "======================================================================"
setup
check "define data retention policy" "SUCCESS|DRT_DEFINED" \
    "$(run DRT_DEFINE "audit_logs" 30 "" "" "" "$ADM")"
PID=$(q "SELECT id FROM data_retention_policy WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list data retention policies" "$PID" \
    "$(run DRT_LIST "" 50 0 "" "" "$ADM")"
check_contains "get data retention policy" "DRT_POLICY|" \
    "$(run DRT_GET "$PID" "" "" "" "" "$ADM")"
check "run data retention" "SUCCESS|DRT_RAN" \
    "$(run DRT_RUN "$PID" "" "" "" "" "$ADM")"
check_contains "data retention summary" "DRT_SUMMARY|" \
    "$(run DRT_SUMMARY "" "" "" "" "" "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run DRT_SUMMARY "" "" "" "" "" "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]