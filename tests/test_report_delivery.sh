#!/bin/bash
# Report layout and schedule delivery suite (Phase 1, Sprint 1 slice 8).
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
check_missing() { local n="$1" x="$2" a="$3"; if [[ "$a" != *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (unexpected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="rdl_admin@test.com"; USR="rdl_user@test.com"; RCP="rdl_recipient@test.com"; TPL="RDL_TEST"
cleanup() {
    q "DELETE FROM report_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM notification_outbox WHERE recipient='$RCP' AND purpose='REPORT';
       DELETE FROM report_schedule WHERE template_code='$TPL';
       DELETE FROM report_run WHERE template_id IN (SELECT id FROM report_template WHERE template_code='$TPL');
       DELETE FROM report_template WHERE template_code='$TPL';"
}
setup() {
    cleanup
    q "DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1012,'$ADM','x','RDL Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1013,'$USR','x','RDL User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO report_template (template_code,name,report_type,output_format,title,enabled,created_by)
       VALUES ('$TPL','RDL Test','TRIAL_BALANCE','CSV','Delivery Test',1,'$ADM');
       SET @tid=LAST_INSERT_ID();
       INSERT INTO report_template_column (template_id,ordinal,header,source_field,width,align,column_format) VALUES
       (@tid,1,'Account','account_code',10,'LEFT','TEXT'),
       (@tid,2,'Name','name',20,'LEFT','TEXT'),
       (@tid,3,'Debit','debit',15,'RIGHT','AMOUNT'),
       (@tid,4,'Credit','credit',15,'RIGHT','AMOUNT');
       INSERT INTO report_run (template_id,status,parameters,row_count,created_by)
       VALUES (@tid,'COMPLETED','fixture',2,'$ADM');
       SET @rid=LAST_INSERT_ID();
       INSERT INTO report_run_row (run_id,ordinal,row_data,debit,credit) VALUES
       (@rid,1,'1000,Cash,100.0000,0.0000',100,0),
       (@rid,2,'4000,Fee income,0.0000,100.0000',0,100);"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1013; DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  REPORT DELIVERY SUITE (PHASE 1)"
echo "======================================================================"
setup
RID="$(q "SELECT id FROM report_run WHERE template_id=(SELECT id FROM report_template WHERE template_code='$TPL') AND parameters='fixture' LIMIT 1;")"

check "set report layout" "SUCCESS|RDL_LAYOUT_SET" \
    "$(run RDL_LAYOUT_SET "$TPL" '100,60' 'Delivery Header' 'Delivery Footer' 1 "$ADM")"
check_contains "get report layout" "100|60|Delivery Header|Delivery Footer|1" \
    "$(run RDL_LAYOUT_GET "$TPL" '' '' '' '' "$ADM")"
check_contains "list report layouts" "$TPL:100:60:1" \
    "$(run RDL_LAYOUT_LIST 50 0 '' '' '' "$ADM")"
RENDER="$(run RDL_LAYOUT_RENDER "$RID" '' '' '' '' "$ADM")"
check_contains "render header" "SUCCESS|RDL_LAYOUT_RENDER|100|60|" "$RENDER"
check_contains "render title" "Delivery Header" "$RENDER"
check_contains "render row account" "1000" "$RENDER"
check_contains "render row name" "Cash" "$RENDER"
check_contains "render footer" "Delivery Footer" "$RENDER"
check "bad layout width rejected" "ERROR|INVALID_INPUT" \
    "$(run RDL_LAYOUT_SET "$TPL" '10,60' 'h' 'f' 1 "$ADM")"
check "missing layout rejected" "ERROR|NOT_FOUND" \
    "$(run RDL_LAYOUT_GET MISSING '' '' '' '' "$ADM")"
check "non-admin layout forbidden" "ERROR|FORBIDDEN" \
    "$(run RDL_LAYOUT_LIST 50 0 '' '' '' "$USR")"

check_contains "create report schedule" "SUCCESS|RDL_SCHEDULE_CREATED|" \
    "$(run RDL_SCHEDULE_CREATE "$TPL" DAILY 09:00 "$RCP" 'CSV,IDR' "$ADM")"
SID="$(q "SELECT id FROM report_schedule WHERE template_code='$TPL' ORDER BY id DESC LIMIT 1;")"
check_contains "list report schedules" "$TPL:DAILY:09:00:CSV:$RCP:1:" \
    "$(run RDL_SCHEDULE_LIST 50 0 '' '' '' "$ADM")"
check_contains "due schedule listed" "$SID" \
    "$(run RDL_SCHEDULE_DUE '' '' '' '' '' "$ADM")"
check "bad schedule frequency rejected" "ERROR|INVALID_INPUT" \
    "$(run RDL_SCHEDULE_CREATE "$TPL" HOURLY 09:00 "$RCP" 'CSV,IDR' "$ADM")"
check "bad schedule output rejected" "ERROR|INVALID_INPUT" \
    "$(run RDL_SCHEDULE_CREATE "$TPL" DAILY 09:00 "$RCP" 'PDF,IDR' "$ADM")"
check "update schedule" "SUCCESS|RDL_SCHEDULE_UPDATED" \
    "$(run RDL_SCHEDULE_UPDATE "$SID" 0 WEEKLY 10:30 'FIXED,USD' "$ADM")"
check_contains "disabled schedule updated" "$TPL:WEEKLY:10:30:FIXED:$RCP:0:" \
    "$(run RDL_SCHEDULE_LIST 50 0 '' '' '' "$ADM")"
check_missing "disabled schedule not due" "$SID" \
    "$(run RDL_SCHEDULE_DUE '' '' '' '' '' "$ADM")"
check "re-enable schedule" "SUCCESS|RDL_SCHEDULE_UPDATED" \
    "$(run RDL_SCHEDULE_UPDATE "$SID" 1 DAILY 09:00 'CSV,IDR' "$ADM")"
check_contains "run schedule" "SUCCESS|RDL_SCHEDULE_RUN|" \
    "$(run RDL_SCHEDULE_RUN "$SID" 2026-10-01 2026-10-31 '' '' "$ADM")"
NEW_RUN="$(q "SELECT id FROM report_run WHERE template_id=(SELECT id FROM report_template WHERE template_code='$TPL') AND parameters LIKE '2026-10-01%' ORDER BY id DESC LIMIT 1;")"
check "scheduled run completed" "COMPLETED" \
    "$(q "SELECT status FROM report_run WHERE id=$NEW_RUN;")"
check "schedule delivery outboxed" "1" \
    "$(q "SELECT COUNT(*) FROM notification_outbox WHERE recipient='$RCP' AND purpose='REPORT' AND detail='run:$NEW_RUN';")"
check "schedule last_run recorded" "1" \
    "$(q "SELECT COUNT(*) FROM report_schedule WHERE id=$SID AND last_run_at IS NOT NULL;")"
check_contains "render scheduled run" "SUCCESS|RDL_LAYOUT_RENDER|" \
    "$(run RDL_LAYOUT_RENDER "$NEW_RUN" '' '' '' '' "$ADM")"
check "missing schedule run rejected" "ERROR|NOT_FOUND" \
    "$(run RDL_SCHEDULE_RUN 999999 2026-10-01 2026-10-31 '' '' "$ADM")"
check "delete schedule" "SUCCESS|RDL_SCHEDULE_DELETED" \
    "$(run RDL_SCHEDULE_DELETE "$SID" '' '' '' '' "$ADM")"
check "deleted schedule gone" "0" \
    "$(q "SELECT COUNT(*) FROM report_schedule WHERE id=$SID;")"
check "report delivery audit recorded" "7" \
    "$(q "SELECT COUNT(*) FROM report_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('LAYOUT_SET','SCHEDULE_CREATE','SCHEDULE_UPDATE','SCHEDULE_RUN','SCHEDULE_DELETE','AUTHZ_DENIED');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
