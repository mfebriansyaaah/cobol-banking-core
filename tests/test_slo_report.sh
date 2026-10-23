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
ADM="slo_admin@test.com"; USR="slo_user@test.com"
cleanup() {
    q "DELETE FROM slo_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM slo_measurement WHERE recorded_by IN ('$ADM','$USR');
       DELETE FROM slo_definition WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1441,'$ADM','x','SLO Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1442,'$USR','x','SLO User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  SLO REPORT SUITE (PHASE 2)"
echo "======================================================================"
setup
check "define slo" "SUCCESS|SLO_DEFINED" \
    "$(run SLO_DEFINE "API_AVAIL" 99.9 30 "" "" "$ADM")"
check_contains "list slo" "API_AVAIL" \
    "$(run SLO_LIST 50 0 "" "" "" "$ADM")"
check_contains "get slo" "SLO_GET|" \
    "$(run SLO_GET "API_AVAIL" "" "" "" "" "$ADM")"
check "record measurement (breached)" "SUCCESS|SLO_RECORDED|BREACHED" \
    "$(run SLO_RECORD "API_AVAIL" 90 100 "2026-01-01" "2026-01-31" "$ADM")"
check_contains "burn rate" "SLO_BURN|" \
    "$(run SLO_BURN "API_AVAIL" "" "" "" "" "$ADM")"
check_contains "slo summary" "SLO_SUMMARY|" \
    "$(run SLO_SUMMARY "" "" "" "" "" "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run SLO_SUMMARY "" "" "" "" "" "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]