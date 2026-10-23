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
ADM="rtj_admin@test.com"; USR="rtj_user@test.com"
cleanup() {
    q "DELETE FROM retention_job_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM retention_job_run WHERE executed_by IN ('$ADM','$USR');
       DELETE FROM retention_job_policy WHERE created_by IN ('$ADM','$USR');
       DELETE FROM audit_trail_archive WHERE user_id IN (SELECT id FROM users WHERE email IN ('$ADM','$USR'));
       DELETE FROM audit_trail WHERE user_id IN (SELECT id FROM users WHERE email IN ('$ADM','$USR'));
       DELETE FROM legal_hold_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM legal_hold WHERE placed_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1431,'$ADM','x','RTJ Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1432,'$USR','x','RTJ User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  RETENTION JOB SUITE (PHASE 3)"
echo "======================================================================"
setup
check "save retention policy" "SUCCESS|RTJ_POLICY_SAVED" \
    "$(run RTJ_POLICY_SET "AUDIT" 1 1 "" "" "$ADM")"
check_contains "list retention policies" "AUDIT" \
    "$(run RTJ_POLICY_LIST 50 0 "" "" "" "$ADM")"
check_contains "get retention policy" "RTJ_POLICY|" \
    "$(run RTJ_POLICY_GET "AUDIT" "" "" "" "" "$ADM")"
# insert an old audit row for the admin user
AID=$(q "SELECT id FROM users WHERE email='$ADM';")
q "INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status, created_at) VALUES ($AID, $AID, 'TEST_ACTION', 'USER', '1', 'SUCCESS', DATE_SUB(NOW(), INTERVAL 3 DAY));"
check_contains "run retention (archives old row)" "RTJ_RUN_COMPLETED|1|" \
    "$(run RTJ_RUN "AUDIT" "" "" "" "" "$ADM")"
RUNID=$(q "SELECT id FROM retention_job_run WHERE executed_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "list retention runs" "AUDIT" \
    "$(run RTJ_RUN_LIST "" 50 0 "" "" "$ADM")"
check_contains "get retention run" "RTJ_RUN|" \
    "$(run RTJ_RUN_GET "$RUNID" "" "" "" "" "$ADM")"
check_contains "retention summary" "RTJ_SUMMARY|" \
    "$(run RTJ_SUMMARY "" "" "" "" "" "$ADM")"
# idempotency: second run archives nothing
check_contains "second run idempotent" "RTJ_RUN_COMPLETED|0|" \
    "$(run RTJ_RUN "AUDIT" "" "" "" "" "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run RTJ_SUMMARY "" "" "" "" "" "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]