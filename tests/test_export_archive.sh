#!/bin/bash
# Retained export archive suite (Phase 1, Sprint 1 slice 9).
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
ADM="exp_admin@test.com"; USR="exp_user@test.com"; TPL="EXP_TEST"; BATCH="EXP_BATCH"
cleanup() {
    q "DELETE FROM export_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM export_archive WHERE source_code IN ('$BATCH') OR source_code LIKE 'RPT-%';
       DELETE FROM report_run WHERE template_id IN (SELECT id FROM report_template WHERE template_code='$TPL');
       DELETE FROM report_template WHERE template_code='$TPL';
       DELETE FROM import_batch WHERE batch_code='$BATCH';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1030,'$ADM','x','EXP Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1031,'$USR','x','EXP User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO report_template (template_code,name,report_type,output_format,title,enabled,created_by)
       VALUES ('$TPL','Export Test','TRIAL_BALANCE','CSV','Export Test',1,'$ADM');
       SET @tid=LAST_INSERT_ID();
       INSERT INTO report_run (template_id,status,parameters,row_count,created_by)
       VALUES (@tid,'COMPLETED','fixture',2,'$ADM');
       SET @rid=LAST_INSERT_ID();
       INSERT INTO report_run_row (run_id,ordinal,row_data,debit,credit) VALUES
       (@rid,1,'1000,Cash,100.0000,0.0000',100,0),
       (@rid,2,'4000,Fee income,0.0000,100.0000',0,100);
       INSERT INTO import_batch (batch_code,source_name,import_type,status,total_rows,valid_rows,invalid_rows,created_by)
       VALUES ('$BATCH','export.csv','REFERENCE','VALIDATED',2,2,0,'$ADM');
       SET @bid=LAST_INSERT_ID();
       INSERT INTO import_row (batch_id,row_no,raw_data,status) VALUES
       (@bid,1,'1000:100:0','VALID'),(@bid,2,'4000:0:100','VALID');"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1031;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  RETAINED EXPORT ARCHIVE SUITE (PHASE 1)"
echo "======================================================================"
setup
RID="$(q "SELECT id FROM report_run WHERE template_id=(SELECT id FROM report_template WHERE template_code='$TPL') LIMIT 1;")"

check_contains "archive report run" "SUCCESS|EXP_ARCHIVED|" \
    "$(run EXP_REPORT_SAVE "$RID" CSV 365 '' '' "$ADM")"
A1="$(q "SELECT id FROM export_archive WHERE source_code='RPT-$RID' AND format='CSV' LIMIT 1;")"
check "duplicate report archive rejected" "ERROR|DUPLICATE" \
    "$(run EXP_REPORT_SAVE "$RID" CSV 365 '' '' "$ADM")"
check_contains "archive import batch" "SUCCESS|EXP_ARCHIVED|" \
    "$(run EXP_IMPORT_SAVE "$BATCH" CSV 365 '' '' "$ADM")"
A2="$(q "SELECT id FROM export_archive WHERE source_code='$BATCH' AND format='CSV' LIMIT 1;")"
check_contains "list archives" "REPORT:RPT-$RID" \
    "$(run EXP_LIST 50 0 '' '' '' "$ADM")"
check_contains "filter import archives" "IMPORT:$BATCH" \
    "$(run EXP_LIST 50 0 IMPORT '' '' "$ADM")"
check_contains "get archive metadata" "COMPLETED" \
    "$(q "SELECT status FROM report_run WHERE id=$RID;")"
check_contains "get archive" "EXP_ARCHIVE|$A1" \
    "$(run EXP_GET "$A1" '' '' '' '' "$ADM")"
check_contains "archive content" "1000,Cash" \
    "$(run EXP_CONTENT "$A1" '' '' '' '' "$ADM")"
check "verify archive checksum" "SUCCESS|EXP_VERIFY|OK|$A1" \
    "$(run EXP_VERIFY "$A1" '' '' '' '' "$ADM")"
check_contains "archive stats" "EXP_STATS|" \
    "$(run EXP_STATS '' '' '' '' '' "$ADM")"
check "extend archive retention" "SUCCESS|EXP_EXTENDED" \
    "$(run EXP_EXTEND "$A1" 30 '' '' '' "$ADM")"
check "extended retention persisted" "1" \
    "$(q "SELECT COUNT(*) FROM export_archive WHERE id=$A1 AND retention_days=395;")"
check "bad archive format rejected" "ERROR|INVALID_INPUT" \
    "$(run EXP_REPORT_SAVE "$RID" JSON 30 '' '' "$ADM")"
check "missing archive rejected" "ERROR|NOT_FOUND" \
    "$(run EXP_GET 999999 '' '' '' '' "$ADM")"
q "UPDATE export_archive SET expires_at=DATE_SUB(CURDATE(), INTERVAL 1 DAY) WHERE id=$A2;"
check_contains "prune expired archives" "SUCCESS|EXP_PRUNED|" \
    "$(run EXP_PRUNE '' '' '' '' '' "$ADM")"
check "expired archive deleted" "0" \
    "$(q "SELECT COUNT(*) FROM export_archive WHERE id=$A2;")"
check "delete archive" "SUCCESS|EXP_DELETED" \
    "$(run EXP_DELETE "$A1" '' '' '' '' "$ADM")"
check "deleted archive gone" "0" \
    "$(q "SELECT COUNT(*) FROM export_archive WHERE id=$A1;")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run EXP_LIST 50 0 '' '' '' "$USR")"
check "export audit rows recorded" "6" \
    "$(q "SELECT COUNT(*) FROM export_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('REPORT_SAVE','IMPORT_SAVE','EXTEND','PRUNE','DELETE','AUTHZ_DENIED');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
