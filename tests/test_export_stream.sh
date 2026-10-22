#!/bin/bash
# Retained export download tokens (Phase 1, Sprint 1 slice 16).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="xst_admin@test.com"; USR="xst_user@test.com"; TPL="XST_TEST"
cleanup() {
    q "DELETE FROM export_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM export_download_token WHERE created_by IN ('$ADM','$USR');
       DELETE FROM export_archive WHERE source_code LIKE 'RPT-XST%';
       DELETE FROM report_run WHERE template_id IN (SELECT id FROM report_template WHERE template_code='$TPL');
       DELETE FROM report_template WHERE template_code='$TPL';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1170,'$ADM','x','XST Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1171,'$USR','x','XST User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO report_template (template_code,name,report_type,output_format,title,enabled,created_by)
       VALUES ('$TPL','XST Test','TRIAL_BALANCE','CSV','XST Test',1,'$ADM');
       SET @tid=LAST_INSERT_ID();
       INSERT INTO report_run (template_id,status,parameters,row_count,created_by) VALUES (@tid,'COMPLETED','fixture',1,'$ADM');
       SET @rid=LAST_INSERT_ID();
       INSERT INTO report_run_row (run_id,ordinal,row_data,debit,credit) VALUES (@rid,1,'1000,Cash,100.0000,0.0000',100,0);
       INSERT INTO export_archive (export_type,source_code,format,content,checksum,row_count,byte_count,retention_days,expires_at,created_by)
       SELECT 'REPORT','RPT-XST', 'CSV', row_data, SHA2(row_data,256),1,CHAR_LENGTH(row_data),365,DATE_ADD(CURDATE(), INTERVAL 365 DAY),'$ADM'
       FROM report_run_row WHERE run_id=@rid;"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1171;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  EXPORT DOWNLOAD TOKEN SUITE (PHASE 1)"
echo "======================================================================"
setup
AID="$(q "SELECT id FROM export_archive WHERE source_code='RPT-XST' LIMIT 1;")"
check_contains "create download token" "SUCCESS|XST_TOKEN|" \
    "$(run XST_TOKEN_CREATE "$AID" 60 3 '' '' "$ADM")"
TOKEN="$(q "SELECT token FROM export_download_token WHERE archive_id=$AID ORDER BY id DESC LIMIT 1;")"
check_contains "get download token" "XST_TOKEN|$TOKEN" \
    "$(run XST_TOKEN_GET "$TOKEN" '' '' '' '' "$ADM")"
check_contains "download chunk" "SUCCESS|XST_CHUNK|$TOKEN|0|10|1|" \
    "$(run XST_CHUNK "$TOKEN" 0 10 '' '' "$ADM")"
check "verify token checksum" "SUCCESS|XST_VERIFY|OK|$TOKEN" \
    "$(run XST_VERIFY "$TOKEN" '' '' '' '' "$ADM")"
check_contains "list tokens" "$TOKEN" "$(run XST_TOKEN_LIST 50 0 '' '' '' "$ADM")"
check "revoke token" "SUCCESS|XST_REVOKED" "$(run XST_TOKEN_REVOKE "$TOKEN" '' '' '' '' "$ADM")"
check "revoked token missing" "ERROR|NOT_FOUND" "$(run XST_TOKEN_GET "$TOKEN" '' '' '' '' "$ADM")"
check_contains "stats" "XST_STATS|" "$(run XST_STATS '' '' '' '' '' "$ADM")"
check "cleanup expired none" "SUCCESS|XST_CLEANED" "$(run XST_CLEANUP 2000-01-01 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run XST_STATS '' '' '' '' '' "$USR")"
check "export download audit rows recorded" "3" \
    "$(q "SELECT COUNT(*) FROM export_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('TOKEN_CREATE','TOKEN_REVOKE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
