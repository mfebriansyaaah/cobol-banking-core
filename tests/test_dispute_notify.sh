#!/bin/bash
# Dispute customer notification suite (Phase 1, Sprint 1 slice 15).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="dsn_admin@test.com"; USR="dsn_user@test.com"; CUST="dsn_cust@test.com"; CASESUB="DSNTEST"
cleanup() {
    q "DELETE FROM dispute_notification_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM dispute_notification WHERE case_id IN (SELECT case_id FROM dispute_cases WHERE subject LIKE '$CASESUB%');
       DELETE FROM dispute_notification_template WHERE template_code LIKE 'DSN_%';
       DELETE FROM dispute_cases WHERE subject LIKE '$CASESUB%';
       DELETE FROM users WHERE email IN ('$ADM','$USR','$CUST');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1160,'$ADM','x','DSN Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1161,'$USR','x','DSN User','1990-01-01','VERIFIED','USER'),
       (1162,'$CUST','x','DSN Customer','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO dispute_cases (user_id,subject,detail,state) VALUES
       ((SELECT id FROM users WHERE email='$CUST'),'$CASESUB case','detail','OPEN');"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1161;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  DISPUTE CUSTOMER NOTIFICATION SUITE (PHASE 1)"
echo "======================================================================"
setup
CASEID="$(q "SELECT case_id FROM dispute_cases WHERE subject='$CASESUB case' LIMIT 1;")"
check "set notification template" "SUCCESS|DSN_TEMPLATE_SET" \
    "$(run DSN_TEMPLATE_SET DSN_OPEN OPENED EMAIL 'Your dispute was opened' 'Body text' "$ADM")"
check_contains "get notification template" "DSN_OPEN|OPENED|EMAIL" \
    "$(run DSN_TEMPLATE_GET DSN_OPEN '' '' '' '' "$ADM")"
check_contains "list notification templates" "DSN_OPEN" \
    "$(run DSN_TEMPLATE_LIST 50 0 '' '' '' "$ADM")"
check_contains "enqueue notification" "SUCCESS|DSN_ENQUEUED|" \
    "$(run DSN_ENQUEUE "$CASEID" OPENED '' DSN_OPEN '' "$ADM")"
NID="$(q "SELECT id FROM dispute_notification WHERE case_id=$CASEID ORDER BY id DESC LIMIT 1;")"
check_contains "get notification" "DSN_NOTIFICATION|$NID" \
    "$(run DSN_GET "$NID" '' '' '' '' "$ADM")"
check_contains "list notifications" "$NID" \
    "$(run DSN_LIST '' 50 0 '' '' "$ADM")"
q "UPDATE dispute_notification SET state='FAILED',last_error='smtp failed' WHERE id=$NID;"
check "retry notification" "SUCCESS|DSN_RETRIED" \
    "$(run DSN_RETRY "$NID" '' '' '' '' "$ADM")"
check_contains "summary" "DSN_SUMMARY|" \
    "$(run DSN_SUMMARY '' '' '' '' '' "$ADM")"
check "delete template" "SUCCESS|DSN_TEMPLATE_DELETED" \
    "$(run DSN_TEMPLATE_DELETE DSN_OPEN '' '' '' '' "$ADM")"
check "missing notification rejected" "ERROR|NOT_FOUND" \
    "$(run DSN_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run DSN_LIST '' 50 0 '' '' "$USR")"
check "dispute notification audit rows recorded" "5" \
    "$(q "SELECT COUNT(*) FROM dispute_notification_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('TEMPLATE_SET','ENQUEUE','RETRY','TEMPLATE_DELETE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
