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
ADM="rsc_admin@test.com"; USR="rsc_user@test.com"; SCH="RSC_TEST"
cleanup() {
    q "DELETE FROM report_scheduler_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM report_scheduler_run WHERE schedule_code='$SCH';
       DELETE FROM report_scheduler WHERE schedule_code='$SCH';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1250,'$ADM','x','RSC Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1251,'$USR','x','RSC User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  REPORT SCHEDULER SUITE (PHASE 1)"
echo "======================================================================"
setup
check "save report schedule" "SUCCESS|RSC_SCHEDULE_SAVED" \
    "$(run RSC_SCHEDULE_SET "$SCH" TRIAL_BALANCE DAILY 2026-01-02 '' "$ADM")"
check_contains "get report schedule" "RSC_SCHEDULE|$SCH" \
    "$(run RSC_SCHEDULE_GET "$SCH" '' '' '' '' "$ADM")"
check_contains "list report schedules" "$SCH" \
    "$(run RSC_SCHEDULE_LIST 50 0 '' '' '' "$ADM")"
check "start report run" "SUCCESS|RSC_RUN_STARTED" \
    "$(run RSC_RUN_START "$SCH" '' '' '' '' "$ADM")"
RID=$(q "SELECT id FROM report_scheduler_run WHERE schedule_code='$SCH' ORDER BY id DESC LIMIT 1;")
check "complete report run" "SUCCESS|RSC_RUN_COMPLETED" \
    "$(run RSC_RUN_COMPLETE "$RID" 42 'none' '' '' "$ADM")"
check_contains "list report runs" "$RID" \
    "$(run RSC_RUN_LIST "$SCH" 50 0 '' '' "$ADM")"
check_contains "report schedule summary" "RSC_SUMMARY|" \
    "$(run RSC_SUMMARY '' '' '' '' '' "$ADM")"
check "delete report schedule" "SUCCESS|RSC_SCHEDULE_DELETED" \
    "$(run RSC_SCHEDULE_DELETE "$SCH" '' '' '' '' "$ADM")"
check "missing schedule rejected" "ERROR|NOT_FOUND" \
    "$(run RSC_SCHEDULE_GET 'RSC_MISSING' '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run RSC_SUMMARY '' '' '' '' '' "$USR")"
check "report scheduler audit rows recorded" "4" \
    "$(q "SELECT COUNT(*) FROM report_scheduler_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('SCHEDULE_SET','RUN_START','SCHEDULE_DELETE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
