#!/bin/bash
# On-call routing and escalation (Phase 1, Sprint 1 slice 13).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="onc_admin@test.com"; USR="onc_user@test.com"; ROT="ONC_ROT"; POL="ONC_POL"; START="$(date -d yesterday '+%F %H:%M')"; END="$(date -d tomorrow '+%F %H:%M')"
cleanup() {
    q "DELETE FROM oncall_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM oncall_page WHERE created_by IN ('$ADM','$USR');
       DELETE FROM oncall_rotation WHERE rotation_code='$ROT';
       DELETE FROM escalation_policy WHERE policy_code='$POL';
       DELETE FROM ops_alert WHERE source_key='ONC:TEST';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
 (1110,'$ADM','x','ONC Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
 (1111,'$USR','x','ONC User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
 INSERT INTO ops_alert (alert_type,severity,source_key,title,detail,created_by) VALUES ('MANUAL','WARNING','ONC:TEST','Oncall test','test page','$ADM');"; }
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1111;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  ON-CALL ROUTING SUITE (PHASE 1)"
echo "======================================================================"
setup
AID="$(q "SELECT id FROM ops_alert WHERE source_key='ONC:TEST' LIMIT 1;")"
check "set rotation" "SUCCESS|ONC_ROTATION_SET" "$(run ONC_ROTATION_SET "$ROT" 'Primary' UTC 1 '' "$ADM")"
check_contains "list rotations" "$ROT" "$(run ONC_ROTATION_LIST 50 0 '' '' '' "$ADM")"
check "add shift" "SUCCESS|ONC_SHIFT_ADDED" "$(run ONC_SHIFT_ADD "$ROT" "$USR" "$START,$END" '' '' "$ADM")"
check_contains "current on-call" "$USR" "$(run ONC_CURRENT "$ROT" '' '' '' '' "$ADM")"
check "set escalation policy" "SUCCESS|ONC_POLICY_SET" "$(run ONC_POLICY_SET "$POL" MANUAL WARNING 1 '' "$ADM")"
check "add escalation step" "SUCCESS|ONC_STEP_ADDED" "$(run ONC_STEP_ADD "$POL" "1,0,$USR,EMAIL" '' '' '' "$ADM")"
check_contains "list step" "1:0:$USR:EMAIL:1" "$(run ONC_STEP_LIST "$POL" '' '' '' '' "$ADM")"
check_contains "page alert" "SUCCESS|ONC_PAGED|" "$(run ONC_PAGE_ALERT "$AID" "$POL" 'please check' '' '' "$ADM")"
PAGE="$(q "SELECT id FROM oncall_page WHERE alert_id=$AID ORDER BY id DESC LIMIT 1;")"
check_contains "list pages" "$PAGE" "$(run ONC_PAGE_LIST '' 50 0 '' '' "$ADM")"
check "ack page" "SUCCESS|ONC_PAGE_ACKED" "$(run ONC_ACK_PAGE "$PAGE" 'ack' '' '' '' "$ADM")"
check "resolve page" "SUCCESS|ONC_PAGE_RESOLVED" "$(run ONC_RESOLVE_PAGE "$PAGE" 'resolved' '' '' '' "$ADM")"
check "missing page rejected" "ERROR|NOT_FOUND" "$(run ONC_ACK_PAGE 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run ONC_PAGE_LIST '' 50 0 '' '' "$USR")"
check "oncall audit rows recorded" "8" "$(q "SELECT COUNT(*) FROM oncall_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('ROTATION_SET','SHIFT_ADD','POLICY_SET','STEP_ADD','PAGE_ALERT','PAGE_ACK','PAGE_RESOLVE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
