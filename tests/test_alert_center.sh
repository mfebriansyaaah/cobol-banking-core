#!/bin/bash
# Operations alert center suite (Phase 1, Sprint 1 slice 10).
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
ADM="alt_admin@test.com"; OWNER="alt_owner@test.com"; USR="alt_user@test.com"; CUST="alt_cust@test.com"; TPL="ALT_TEST"
cleanup() {
    q "DELETE FROM ops_alert_audit WHERE actor_email IN ('$ADM','$OWNER','$USR');
       DELETE FROM ops_alert WHERE source_key LIKE 'MANUAL:%' OR source_key LIKE 'OUTBOX:%' OR source_key LIKE 'SCHEDULE:%' OR source_key LIKE 'RECON:%' OR source_key LIKE 'DISPUTE:%';
       DELETE FROM notification_outbox WHERE recipient='$OWNER';
       DELETE FROM report_schedule WHERE template_code='$TPL';
       DELETE FROM reconciliation_findings WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST'));
       DELETE FROM reconciliation_runs WHERE actor_email='$ADM';
       DELETE FROM dispute_cases WHERE user_id IN (SELECT id FROM users WHERE email='$CUST');
       DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST');
       DELETE FROM users WHERE email IN ('$ADM','$OWNER','$USR','$CUST');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1050,'$ADM','x','ALT Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1051,'$OWNER','x','ALT Owner','1990-01-01','VERIFIED','MANAGER'),
       (1052,'$USR','x','ALT User','1990-01-01','VERIFIED','USER'),
       (1053,'$CUST','x','ALT Customer','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO notification_outbox (recipient,purpose,code,detail,state,attempts,last_error) VALUES
       ('$OWNER','SIGNUP','','','FAILED',1,'smtp failed'),
       ('$OWNER','PASSWORD_RESET','','','DEAD',3,'dead letter');
       INSERT INTO report_schedule (template_code,frequency,schedule_time,output_format,currency_code,recipient,enabled,next_run_date,created_by)
       VALUES ('$TPL','DAILY','09:00','CSV','IDR','$OWNER',1,DATE_SUB(CURDATE(), INTERVAL 1 DAY),'$ADM');
       INSERT INTO accounts (user_id,currency_id,balance,status) SELECT 1053,currency_id,0,'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1;
       SET @aid=LAST_INSERT_ID();
       INSERT INTO reconciliation_runs (trigger_src,actor_email,status,mismatch_count) VALUES ('MANUAL','$ADM','MISMATCH',1);
       SET @rid=LAST_INSERT_ID();
       INSERT INTO reconciliation_findings (run_id,account_id,balance,ledger_sum,status,created_at)
       VALUES (@rid,@aid,10,5,'OPEN',DATE_SUB(NOW(), INTERVAL 48 HOUR));
       INSERT INTO dispute_cases (user_id,subject,detail,state,priority,due_date)
       VALUES (1053,'ALTTEST dispute','detail','OPEN','HIGH',DATE_SUB(CURDATE(), INTERVAL 1 DAY));"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1052;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  OPERATIONS ALERT CENTER SUITE (PHASE 1)"
echo "======================================================================"
setup
OUT1="$(q "SELECT id FROM notification_outbox WHERE recipient='$OWNER' AND state='FAILED' LIMIT 1;")"
OUT2="$(q "SELECT id FROM notification_outbox WHERE recipient='$OWNER' AND state='DEAD' LIMIT 1;")"
SCH="$(q "SELECT id FROM report_schedule WHERE template_code='$TPL' LIMIT 1;")"
FIND="$(q "SELECT finding_id FROM reconciliation_findings WHERE status='OPEN' AND account_id IN (SELECT account_id FROM accounts WHERE user_id=1053) LIMIT 1;")"
DISP="$(q "SELECT case_id FROM dispute_cases WHERE subject='ALTTEST dispute' LIMIT 1;")"

check_contains "raise manual alert" "SUCCESS|ALT_RAISED|" \
    "$(run ALT_RAISE MANUAL WARNING MANUAL:1 'Manual alert' 'test detail' "$ADM")"
AID="$(q "SELECT id FROM ops_alert WHERE source_key='MANUAL:1' LIMIT 1;")"
check "raise is idempotent" "SUCCESS|ALT_RAISED|$AID|1" \
    "$(run ALT_RAISE MANUAL WARNING MANUAL:1 'Manual alert' 'updated detail' "$ADM")"
check_contains "list alerts" "MANUAL:1" \
    "$(run ALT_LIST OPEN WARNING 50 0 '' "$ADM")"
check_contains "get alert" "ALT_ALERT|$AID" \
    "$(run ALT_GET "$AID" '' '' '' '' "$ADM")"
check "acknowledge alert" "SUCCESS|ALT_ACKNOWLEDGED" \
    "$(run ALT_ACK "$AID" "$OWNER" 'taking it' '' '' "$ADM")"
check "add alert note" "SUCCESS|ALT_NOTED" \
    "$(run ALT_NOTE "$AID" 'investigating' '' '' '' "$ADM")"
check_contains "alert history" "investigating" \
    "$(run ALT_HISTORY "$AID" 50 0 '' '' "$ADM")"
check "resolve alert" "SUCCESS|ALT_RESOLVED" \
    "$(run ALT_RESOLVE "$AID" 'fixed' '' '' '' "$ADM")"
check_contains "scan failed outbox" "SUCCESS|ALT_SCANNED|" \
    "$(run ALT_SCAN_OUTBOX 50 '' '' '' '' "$ADM")"
check "outbox alert created" "1" \
    "$(q "SELECT COUNT(*) FROM ops_alert WHERE source_key='OUTBOX:$OUT2';")"
check_contains "scan due schedules" "SUCCESS|ALT_SCANNED|" \
    "$(run ALT_SCAN_SCHEDULE '' 50 '' '' '' "$ADM")"
check "schedule alert created" "1" \
    "$(q "SELECT COUNT(*) FROM ops_alert WHERE source_key='SCHEDULE:$SCH';")"
check_contains "scan aged recon" "SUCCESS|ALT_SCANNED|" \
    "$(run ALT_SCAN_RECON 50 '' '' '' '' "$ADM")"
check "recon alert created" "1" \
    "$(q "SELECT COUNT(*) FROM ops_alert WHERE source_key='RECON:$FIND';")"
check_contains "scan overdue disputes" "SUCCESS|ALT_SCANNED|" \
    "$(run ALT_SCAN_DISPUTE '' 50 '' '' '' "$ADM")"
check "dispute alert created" "1" \
    "$(q "SELECT COUNT(*) FROM ops_alert WHERE source_key='DISPUTE:$DISP';")"
check_contains "critical filter" "CRITICAL" \
    "$(run ALT_LIST '' CRITICAL 50 0 '' "$ADM")"
check_contains "alert summary" "ALT_SUMMARY|" \
    "$(run ALT_SUMMARY '' '' '' '' '' "$ADM")"
check "bad severity rejected" "ERROR|INVALID_INPUT" \
    "$(run ALT_RAISE MANUAL SEVERE MANUAL:2 'x' '' "$ADM")"
check "missing alert rejected" "ERROR|NOT_FOUND" \
    "$(run ALT_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run ALT_LIST '' '' 50 0 '' "$USR")"
check "alert audit rows recorded" "10" \
    "$(q "SELECT COUNT(*) FROM ops_alert_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('RAISE','ACK','NOTE','RESOLVE','SCAN_OUTBOX','SCAN_SCHEDULE','SCAN_RECON','SCAN_DISPUTE','AUTHZ_DENIED');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
