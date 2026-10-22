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
ADM="rcl_admin@test.com"; USR="rcl_user@test.com"
cleanup() {
    q "DELETE FROM regulatory_calendar_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM regulatory_calendar WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1390,'$ADM','x','RCL Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1391,'$USR','x','RCL User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  REGULATORY CALENDAR SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create calendar event" "SUCCESS|RCL_EVENT_CREATED" \
    "$(run RCL_EVENT_CREATE RCL_TEST 'Filing' OJK 2026-12-31 '' "$ADM")"
check_contains "list calendar events" "RCL_TEST" \
    "$(run RCL_EVENT_LIST OPEN 50 0 '' '' "$ADM")"
check "complete calendar event" "SUCCESS|RCL_EVENT_DONE" \
    "$(run RCL_EVENT_DONE RCL_TEST '' '' '' '' "$ADM")"
check_contains "calendar summary" "RCL_SUMMARY|" \
    "$(run RCL_SUMMARY '' '' '' '' '' "$ADM")"
check "missing event rejected" "ERROR|INVALID_STATUS" \
    "$(run RCL_EVENT_DONE RCL_MISSING '' '' '' '' "$ADM")" 2>/dev/null || true
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run RCL_SUMMARY '' '' '' '' '' "$USR")"
check "regulatory calendar audit rows recorded" "3" \
    "$(q "SELECT COUNT(*) FROM regulatory_calendar_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('CREATE','DONE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
