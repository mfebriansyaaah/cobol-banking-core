#!/bin/bash
# Batch/EOD foundation suite (Phase 1, Sprint 1 slice 2).
# Covers job/step definitions, run lifecycle, checkpoints, control totals,
# retry, EOD start guards, authorization, and audit.
# Usage: ./tests/test_batch.sh

BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

check_contains() {
    local name="$1" needle="$2" actual="$3"
    if [[ "$actual" == *"$needle"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected to contain [$needle] got [$actual])"; failed=$((failed+1))
    fi
}

ADM="batch_admin@test.com"
TOMORROW="$(date -d tomorrow +%F)"
USR="batch_user@test.com"

cleanup_rows() {
    q "DELETE FROM batch_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM batch_run WHERE job_id IN (SELECT id FROM batch_job WHERE job_code LIKE 'EOD_TEST%');
       DELETE FROM batch_job WHERE job_code LIKE 'EOD_TEST%';"
}

setup() {
    cleanup_rows
    q "DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (990,'$ADM','x','Batch Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (991,'$USR','x','Batch User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role), status='VERIFIED';"
}

teardown() {
    cleanup_rows
    q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=991;
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}

trap 'core_stop; teardown' EXIT
core_start

echo "======================================================================"
echo "  BATCH/EOD FOUNDATION SUITE (PHASE 1)"
echo "======================================================================"
setup

check_contains "create batch job" "SUCCESS|BATCH_JOB_CREATED|" \
    "$(run BATCH_JOB_CREATE EOD_TEST 'End of day' EOD DAILY '23:30,3,3600' "$ADM")"
check_contains "list batch jobs" "EOD_TEST:End of day:EOD:DAILY:1:23:30:3:3600" \
    "$(run BATCH_JOB_LIST 50 0 '' '' '' "$ADM")"
check "duplicate job rejected" "ERROR|DUPLICATE" \
    "$(run BATCH_JOB_CREATE EOD_TEST 'Again' EOD DAILY '23:30,3,3600' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run BATCH_JOB_LIST 50 0 '' '' '' "$USR")"

check "disable job" "SUCCESS|BATCH_JOB_UPDATED" \
    "$(run BATCH_JOB_UPDATE EOD_TEST 0 DAILY 23:30 3 "$ADM")"
check "disabled job cannot start" "ERROR|JOB_DISABLED" \
    "$(run BATCH_RUN_START EOD_TEST 2026-10-20 '' '' '' "$ADM")"
check "enable job" "SUCCESS|BATCH_JOB_UPDATED" \
    "$(run BATCH_JOB_UPDATE EOD_TEST 1 DAILY 23:30 3 "$ADM")"

check_contains "create extract step" "SUCCESS|BATCH_STEP_CREATED|" \
    "$(run BATCH_STEP_CREATE EOD_TEST 1 EXTRACT 'Extract' '3,1' "$ADM")"
check_contains "create post step" "SUCCESS|BATCH_STEP_CREATED|" \
    "$(run BATCH_STEP_CREATE EOD_TEST 2 POST 'Post' '3,1' "$ADM")"
check_contains "list batch steps" "1:EXTRACT:Extract:3:1" \
    "$(run BATCH_STEP_LIST EOD_TEST 50 0 '' '' "$ADM")"
check "duplicate step rejected" "ERROR|DUPLICATE" \
    "$(run BATCH_STEP_CREATE EOD_TEST 1 EXTRACT 'Again' '3,1' "$ADM")"

START_OUT="$(run BATCH_RUN_START EOD_TEST 2026-10-20 '' '' '' "$ADM")"
check_contains "start batch run" "SUCCESS|BATCH_RUN_STARTED|" "$START_OUT"
RUN_ID="$(printf '%s' "$START_OUT" | cut -d'|' -f3)"
check "active run rejected" "ERROR|RUN_ACTIVE" \
    "$(run BATCH_RUN_START EOD_TEST 2026-10-20 '' '' '' "$ADM")"
check_contains "run status running" "RUNNING" \
    "$(run BATCH_RUN_STATUS "$RUN_ID" 1 '' '' '' "$ADM")"

check "checkpoint saved" "SUCCESS|BATCH_CHECKPOINT|1" \
    "$(run BATCH_RUN_CHECKPOINT "$RUN_ID" CURSOR1 100 10 '100.00,100.00' "$ADM")"
check "unbalanced checkpoint rejected" "ERROR|UNBALANCED" \
    "$(run BATCH_RUN_CHECKPOINT "$RUN_ID" CURSOR2 100 10 '100.00,90.00' "$ADM")"

check "start extract step" "SUCCESS|BATCH_STEP_UPDATED" \
    "$(run BATCH_RUN_STEP "$RUN_ID" 1 RUNNING '0,0,0' '0,0' "$ADM")"
check "complete extract step" "SUCCESS|BATCH_STEP_UPDATED" \
    "$(run BATCH_RUN_STEP "$RUN_ID" 1 COMPLETED '10,10,0' '100.00,100.00' "$ADM")"
check "invalid step transition rejected" "ERROR|INVALID_TRANSITION" \
    "$(run BATCH_RUN_STEP "$RUN_ID" 1 RUNNING '0,0,0' '0,0' "$ADM")"
check "start post step" "SUCCESS|BATCH_STEP_UPDATED" \
    "$(run BATCH_RUN_STEP "$RUN_ID" 2 RUNNING '0,0,0' '0,0' "$ADM")"
check "complete post step" "SUCCESS|BATCH_STEP_UPDATED" \
    "$(run BATCH_RUN_STEP "$RUN_ID" 2 COMPLETED '0,0,0' '0,0' "$ADM")"

check "control total matches" "SUCCESS|BATCH_CONTROL|MATCH" \
    "$(run BATCH_CONTROL_TOTAL "$RUN_ID" COUNT 100.00 100.00 '' "$ADM")"
check "complete run" "SUCCESS|BATCH_RUN_COMPLETED" \
    "$(run BATCH_RUN_COMPLETE "$RUN_ID" '10,10,0' '100.00,100.00' '' '' "$ADM")"
check_contains "run status completed" "COMPLETED" \
    "$(run BATCH_RUN_STATUS "$RUN_ID" 1 '' '' '' "$ADM")"
check "completed run cannot complete again" "ERROR|INVALID_STATUS" \
    "$(run BATCH_RUN_COMPLETE "$RUN_ID" '10,10,0' '100.00,100.00' '' '' "$ADM")"

EOD_OUT="$(run BATCH_EOD_START 2026-10-21 EOD_TEST '' '' '' "$ADM")"
check_contains "start EOD run" "SUCCESS|BATCH_RUN_STARTED|" "$EOD_OUT"
EOD_ID="$(printf '%s' "$EOD_OUT" | cut -d'|' -f3)"
check "future EOD date rejected" "ERROR|FUTURE_DATE" \
    "$(run BATCH_EOD_START "$TOMORROW" EOD_TEST '' '' '' "$ADM")"
check "fail EOD run" "SUCCESS|BATCH_RUN_FAILED" \
    "$(run BATCH_RUN_FAIL "$EOD_ID" TEST_FAIL 'forced failure' '' '' "$ADM")"
RETRY_OUT="$(run BATCH_RUN_RETRY "$EOD_ID" '' '' '' '' "$ADM")"
check_contains "retry failed run" "SUCCESS|BATCH_RUN_RETRIED|" "$RETRY_OUT"
RETRY_ID="$(printf '%s' "$RETRY_OUT" | cut -d'|' -f3)"
check_contains "retry is running attempt 2" "RUNNING:2" \
    "$(run BATCH_RUN_STATUS "$RETRY_ID" 0 '' '' '' "$ADM")"
check_contains "run list filters by job" "EOD_TEST" \
    "$(run BATCH_RUN_LIST 50 0 '' EOD_TEST '' "$ADM")"

VAR_OUT="$(run BATCH_RUN_START EOD_TEST 2026-10-19 '' '' '' "$ADM")"
VAR_ID="$(printf '%s' "$VAR_OUT" | cut -d'|' -f3)"
check "control total variance recorded" "SUCCESS|BATCH_CONTROL|VARIANCE" \
    "$(run BATCH_CONTROL_TOTAL "$VAR_ID" COUNT 100.00 90.00 '' "$ADM")"
run BATCH_RUN_STEP "$VAR_ID" 1 RUNNING '0,0,0' '0,0' "$ADM" >/dev/null
run BATCH_RUN_STEP "$VAR_ID" 1 COMPLETED '10,10,0' '90.00,90.00' "$ADM" >/dev/null
run BATCH_RUN_STEP "$VAR_ID" 2 RUNNING '0,0,0' '0,0' "$ADM" >/dev/null
run BATCH_RUN_STEP "$VAR_ID" 2 COMPLETED '0,0,0' '0,0' "$ADM" >/dev/null
check "variance blocks completion" "ERROR|CONTROL_VARIANCE" \
    "$(run BATCH_RUN_COMPLETE "$VAR_ID" '10,10,0' '90.00,90.00' '' '' "$ADM")"

check "batch audit rows recorded" "23" \
    "$(q "SELECT COUNT(*) FROM batch_audit WHERE actor_email IN ('$ADM','$USR');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
