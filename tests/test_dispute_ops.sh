#!/bin/bash
# Dispute operations suite (Phase 1, Sprint 1 slice 9).
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
ADM="dsp_admin@test.com"; OWNER="dsp_owner@test.com"; CUST="dsp_cust@test.com"
cleanup() {
    q "DELETE FROM dispute_ops_audit WHERE actor_email IN ('$ADM','$OWNER','$CUST');
       DELETE FROM dispute_cases WHERE user_id IN (SELECT id FROM users WHERE email='$CUST');
       DELETE FROM users WHERE email IN ('$ADM','$OWNER','$CUST');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1020,'$ADM','x','DSP Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1021,'$OWNER','x','DSP Owner','1990-01-01','VERIFIED','MANAGER'),
       (1022,'$CUST','x','DSP Customer','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO dispute_cases (user_id,txn_ref,subject,detail,state,priority,due_date)
       VALUES (1022,'DSP1','DSPTEST open','detail','OPEN','NORMAL',DATE_ADD(CURDATE(), INTERVAL 3 DAY)),
              (1022,'DSP2','DSPTEST overdue','detail','ACKNOWLEDGED','HIGH',DATE_SUB(CURDATE(), INTERVAL 2 DAY)),
              (1022,'DSP3','DSPTEST resolved','detail','RESOLVED','LOW',NULL);"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1022;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  DISPUTE OPERATIONS SUITE (PHASE 1)"
echo "======================================================================"
setup
C1="$(q "SELECT case_id FROM dispute_cases WHERE txn_ref='DSP1' LIMIT 1;")"
C2="$(q "SELECT case_id FROM dispute_cases WHERE txn_ref='DSP2' LIMIT 1;")"

check "set urgent SLA" "SUCCESS|DSP_SLA_SET" \
    "$(run DSP_SLA_SET URGENT '1,4' 1 '' '' "$ADM")"
check "get urgent SLA" "SUCCESS|DSP_SLA|URGENT|1:4:1" \
    "$(run DSP_SLA_GET URGENT '' '' '' '' "$ADM")"
check_contains "list SLA policies" "URGENT:1:4:1" \
    "$(run DSP_SLA_LIST 50 0 '' '' '' "$ADM")"
check "bad SLA rejected" "ERROR|INVALID_INPUT" \
    "$(run DSP_SLA_SET URGENT '8,4' 1 '' '' "$ADM")"
check "set case priority" "SUCCESS|DSP_PRIORITY_SET" \
    "$(run DSP_PRIORITY_SET "$C1" HIGH '' '' '' "$ADM")"
check "priority persisted" "HIGH" \
    "$(q "SELECT priority FROM dispute_cases WHERE case_id=$C1;")"
check "assign case" "SUCCESS|DSP_ASSIGNED|$OWNER" \
    "$(run DSP_ASSIGN "$C1" "$OWNER" 'assigning' '' '' "$ADM")"
check "assignee persisted" "1021" \
    "$(q "SELECT assigned_to FROM dispute_cases WHERE case_id=$C1;")"
check "set due date" "SUCCESS|DSP_DUE_SET" \
    "$(run DSP_DUE_SET "$C1" 2026-11-01 '' '' '' "$ADM")"
check "due date persisted" "2026-11-01" \
    "$(q "SELECT due_date FROM dispute_cases WHERE case_id=$C1;")"
check_contains "queue by owner" "$C1" \
    "$(run DSP_QUEUE '' 50 0 "$OWNER" '' "$ADM")"
check_contains "overdue queue" "$C2" \
    "$(run DSP_OVERDUE '' 50 0 '' '' "$ADM")"
check_contains "summary reports open cases" "DSP_SUMMARY" \
    "$(run DSP_SUMMARY '' '' '' '' '' "$ADM")"
check_contains "aging lists open case" "$C1" \
    "$(run DSP_AGING OPEN 50 0 '' '' "$ADM")"
check "escalate case" "SUCCESS|DSP_ESCALATED" \
    "$(run DSP_ESCALATE "$C1" "$OWNER" 'escalating' '' '' "$ADM")"
check "escalated priority urgent" "URGENT" \
    "$(q "SELECT priority FROM dispute_cases WHERE case_id=$C1;")"
check "escalation note stored" "1" \
    "$(q "SELECT COUNT(*) FROM dispute_messages WHERE case_id=$C1 AND body='escalating';")"
check_contains "assignment history" "$OWNER" \
    "$(run DSP_HISTORY "$C1" 50 0 '' '' "$ADM")"
check "missing case rejected" "ERROR|NOT_FOUND" \
    "$(run DSP_ASSIGN 999999 "$OWNER" '' '' '' "$ADM")"
check "bad priority rejected" "ERROR|INVALID_INPUT" \
    "$(run DSP_PRIORITY_SET "$C1" CRITICAL '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run DSP_SUMMARY '' '' '' '' '' "$CUST")"
check "dispute ops audit rows recorded" "6" \
    "$(q "SELECT COUNT(*) FROM dispute_ops_audit WHERE actor_email IN ('$ADM','$CUST') AND action IN ('SLA_SET','PRIORITY_SET','ASSIGN','DUE_SET','ESCALATE','AUTHZ_DENIED');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
