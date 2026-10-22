#!/bin/bash
# Alert escalation automation (Phase 1, Sprint 1 slice 16).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="ale_admin@test.com"; USR="ale_user@test.com"; POL="ALE_TEST"
cleanup() {
    q "DELETE FROM alert_escalation_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM alert_escalation_run WHERE created_by IN ('$ADM');
       DELETE FROM escalation_step WHERE policy_id IN (SELECT id FROM escalation_policy WHERE policy_code='$POL');
       DELETE FROM escalation_policy WHERE policy_code='$POL';
       DELETE FROM ops_alert WHERE source_key='ALE:TEST';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1180,'$ADM','x','ALE Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1181,'$USR','x','ALE User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO ops_alert (alert_type,severity,source_key,title,detail,created_by)
       VALUES ('MANUAL','WARNING','ALE:TEST','Alert escalation test','detail','$ADM');"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1181;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  ALERT ESCALATION SUITE (PHASE 1)"
echo "======================================================================"
setup
AID="$(q "SELECT id FROM ops_alert WHERE source_key='ALE:TEST' LIMIT 1;")"
check "set escalation policy" "SUCCESS|ALE_POLICY_SET" \
    "$(run ALE_POLICY_SET "$POL" MANUAL WARNING 1 '' "$ADM")"
check "add escalation step" "SUCCESS|ALE_STEP_ADDED" \
    "$(run ALE_STEP_ADD "$POL" "1,0,$USR,EMAIL" '' '' '' "$ADM")"
check_contains "list steps" "1:0:$USR:EMAIL:1" \
    "$(run ALE_STEP_LIST "$POL" '' '' '' '' "$ADM")"
check_contains "escalate alert" "SUCCESS|ALE_ESCALATED|" \
    "$(run ALE_ESCALATE "$AID" "$POL" 'escalating' '' '' "$ADM")"
RID="$(q "SELECT id FROM alert_escalation_run WHERE alert_id=$AID ORDER BY id DESC LIMIT 1;")"
check_contains "list escalation runs" "$RID" \
    "$(run ALE_RUN_LIST '' 50 0 '' '' "$ADM")"
check_contains "get escalation run" "ALE_RUN|$RID" \
    "$(run ALE_RUN_GET "$RID" '' '' '' '' "$ADM")"
check "acknowledge run" "SUCCESS|ALE_ACKED" \
    "$(run ALE_ACK_RUN "$RID" 'ack' '' '' '' "$ADM")"
check "resolve run" "SUCCESS|ALE_RESOLVED" \
    "$(run ALE_RESOLVE_RUN "$RID" 'resolved' '' '' '' "$ADM")"
check_contains "list policies" "$POL" "$(run ALE_POLICY_LIST 50 0 '' '' '' "$ADM")"
check_contains "summary" "ALE_SUMMARY|" "$(run ALE_SUMMARY '' '' '' '' '' "$ADM")"
check "missing run rejected" "ERROR|NOT_FOUND" "$(run ALE_RUN_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run ALE_SUMMARY '' '' '' '' '' "$USR")"
check "alert escalation audit rows recorded" "6" \
    "$(q "SELECT COUNT(*) FROM alert_escalation_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('POLICY_SET','STEP_ADD','ESCALATE','ACK_RUN','RESOLVE_RUN','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
