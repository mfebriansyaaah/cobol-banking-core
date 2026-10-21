#!/bin/bash
# EOD calendar, run, phase, and close suite (Sprint 1 slice 4).
# Usage: ./tests/test_eod.sh

BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }

ADM="fee_admin@test.com"; USR="fee_user@test.com"
cleanup() {
    q "DELETE FROM eod_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM eod_phase WHERE run_id IN (SELECT id FROM eod_run WHERE business_date IN ('2026-10-21','2026-10-20','2026-10-19'));
       DELETE FROM eod_run WHERE business_date IN ('2026-10-21','2026-10-20','2026-10-19');
       DELETE FROM eod_calendar WHERE business_date IN ('2026-10-21','2026-10-20','2026-10-19');"
}
setup() {
    cleanup
    q "DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (996,'$ADM','x','Fee Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (997,'$USR','x','Fee User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=997; DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  EOD CALENDAR / RUN SUITE (PHASE 1)"
echo "======================================================================"
setup

check "open EOD calendar" "SUCCESS|EOD_CALENDAR_OPEN" \
    "$(run EOD_CAL_OPEN 2026-10-21 23:30 '' '' '' "$ADM")"
check_contains "list EOD calendars" "2026-10-21:OPEN:23:30" \
    "$(run EOD_CAL_LIST 50 0 '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run EOD_CAL_LIST 50 0 '' '' '' "$USR")"

RUN_OUT="$(run EOD_RUN_START 2026-10-21 '' '' '' '' "$ADM")"
check_contains "start EOD run" "SUCCESS|EOD_RUN_STARTED|" "$RUN_OUT"
RUN_ID="$(printf '%s' "$RUN_OUT" | cut -d'|' -f3)"
check "active EOD run rejected" "ERROR|RUN_ACTIVE" \
    "$(run EOD_RUN_START 2026-10-21 '' '' '' '' "$ADM")"
check_contains "EOD run status pending" "PENDING" \
    "$(run EOD_RUN_STATUS "$RUN_ID" 1 '' '' '' "$ADM")"

check "start FEE phase" "SUCCESS|EOD_PHASE_SET" \
    "$(run EOD_PHASE_SET "$RUN_ID" FEE RUNNING '0,0,0' '' "$ADM")"
check "complete FEE phase" "SUCCESS|EOD_PHASE_SET" \
    "$(run EOD_PHASE_SET "$RUN_ID" FEE COMPLETED '10,100,100' '' "$ADM")"
check "invalid phase transition rejected" "ERROR|INVALID_TRANSITION" \
    "$(run EOD_PHASE_SET "$RUN_ID" FEE RUNNING '0,0,0' '' "$ADM")"
check "unbalanced phase rejected" "ERROR|UNBALANCED" \
    "$(run EOD_PHASE_SET "$RUN_ID" HOLD RUNNING '0,10,5' '' "$ADM")"
check "skip HOLD phase" "SUCCESS|EOD_PHASE_SET" \
    "$(run EOD_PHASE_SET "$RUN_ID" HOLD SKIPPED '0,0,0' '' "$ADM")"
check "skip DORMANT phase" "SUCCESS|EOD_PHASE_SET" \
    "$(run EOD_PHASE_SET "$RUN_ID" DORMANT SKIPPED '0,0,0' '' "$ADM")"
check "skip STATEMENT phase" "SUCCESS|EOD_PHASE_SET" \
    "$(run EOD_PHASE_SET "$RUN_ID" STATEMENT SKIPPED '0,0,0' '' "$ADM")"
check "skip RECON phase" "SUCCESS|EOD_PHASE_SET" \
    "$(run EOD_PHASE_SET "$RUN_ID" RECON SKIPPED '0,0,0' '' "$ADM")"
check "close EOD run" "SUCCESS|EOD_RUN_CLOSED" \
    "$(run EOD_RUN_CLOSE "$RUN_ID" '' '' '' '' "$ADM")"
check_contains "EOD run completed" "COMPLETED:5:5" \
    "$(run EOD_RUN_STATUS "$RUN_ID" 1 '' '' '' "$ADM")"
check_contains "calendar closed" "2026-10-21:CLOSED" \
    "$(run EOD_CAL_LIST 50 0 CLOSED '' '' "$ADM")"
check_contains "run list completed" "COMPLETED" \
    "$(run EOD_RUN_LIST 50 0 COMPLETED 2026-10-21 '' "$ADM")"
check "closed calendar cannot reopen" "ERROR|INVALID_STATUS" \
    "$(run EOD_CAL_OPEN 2026-10-21 23:30 '' '' '' "$ADM")"
check "missing calendar rejected" "ERROR|CALENDAR_NOT_OPEN" \
    "$(run EOD_RUN_START 2026-10-19 '' '' '' '' "$ADM")"

check "open second calendar" "SUCCESS|EOD_CALENDAR_OPEN" \
    "$(run EOD_CAL_OPEN 2026-10-20 22:00 '' '' '' "$ADM")"
FAIL_OUT="$(run EOD_RUN_START 2026-10-20 '' '' '' '' "$ADM")"
FAIL_ID="$(printf '%s' "$FAIL_OUT" | cut -d'|' -f3)"
check "fail EOD run" "SUCCESS|EOD_RUN_FAILED" \
    "$(run EOD_RUN_FAIL "$FAIL_ID" TEST_FAIL 'forced' '' '' "$ADM")"
check_contains "failed run status" "FAILED" \
    "$(run EOD_RUN_STATUS "$FAIL_ID" 0 '' '' '' "$ADM")"

check "EOD audit rows recorded" "13" \
    "$(q "SELECT COUNT(*) FROM eod_audit WHERE actor_email IN ('$ADM','$USR');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
