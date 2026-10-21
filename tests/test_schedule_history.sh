#!/bin/bash
# Report schedule run history and failure visibility (Phase 1, Sprint 1 slice 12).
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
ADM="rsh_admin@test.com"; USR="rsh_user@test.com"; TPL="RSH_TEST"; RCP="rsh_recipient@test.com"
cleanup() {
    q "DELETE FROM report_schedule_run WHERE schedule_id IN (SELECT id FROM report_schedule WHERE template_code='$TPL');
       DELETE FROM report_schedule WHERE template_code='$TPL';
       DELETE FROM report_run WHERE template_id IN (SELECT id FROM report_template WHERE template_code='$TPL');
       DELETE FROM report_template WHERE template_code='$TPL';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1090,'$ADM','x','RSH Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1091,'$USR','x','RSH User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO report_template (template_code,name,report_type,output_format,title,enabled,created_by)
       VALUES ('$TPL','Schedule History','TRIAL_BALANCE','CSV','Schedule History',1,'$ADM');
       SET @tid=LAST_INSERT_ID();
       INSERT INTO report_template_column (template_id,ordinal,header,source_field,width,align,column_format) VALUES
       (@tid,1,'Account','account_code',10,'LEFT','TEXT'),
       (@tid,2,'Name','name',20,'LEFT','TEXT'),
       (@tid,3,'Debit','debit',15,'RIGHT','AMOUNT'),
       (@tid,4,'Credit','credit',15,'RIGHT','AMOUNT');
       INSERT INTO report_schedule (template_code,frequency,schedule_time,output_format,currency_code,recipient,enabled,next_run_date,created_by)
       VALUES ('$TPL','DAILY','09:00','CSV','IDR','$RCP',1,CURDATE(),'$ADM');"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1091;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  REPORT SCHEDULE HISTORY SUITE (PHASE 1)"
echo "======================================================================"
setup
SID="$(q "SELECT id FROM report_schedule WHERE template_code='$TPL' LIMIT 1;")"
check_contains "run schedule" "SUCCESS|RDL_SCHEDULE_RUN|" \
    "$(run RDL_SCHEDULE_RUN "$SID" 2026-10-01 2026-10-31 '' '' "$ADM")"
check_contains "history shows completed run" "COMPLETED" \
    "$(run RDL_SCHEDULE_HISTORY "$SID" 50 0 '' '' "$ADM")"
check "history run recorded" "1" \
    "$(q "SELECT COUNT(*) FROM report_schedule_run WHERE schedule_id=$SID AND status='COMPLETED';")"
q "INSERT INTO report_schedule_run (schedule_id,status,period_from,period_to,currency_code,output_format,error_detail,created_by) VALUES ($SID,'FAILED','2026-09-01','2026-09-30','IDR','CSV','forced failure','$ADM');"
check_contains "failure list shows failed run" "forced failure" \
    "$(run RDL_SCHEDULE_FAILS 50 0 '' '' '' "$ADM")"
check "failed run recorded" "1" \
    "$(q "SELECT COUNT(*) FROM report_schedule_run WHERE schedule_id=$SID AND status='FAILED';")"
check "missing schedule history empty" "SUCCESS|RDL_HISTORY|0" \
    "$(run RDL_SCHEDULE_HISTORY 999999 50 0 '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run RDL_SCHEDULE_HISTORY "$SID" 50 0 '' '' "$USR")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
