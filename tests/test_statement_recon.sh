#!/bin/bash
# Statement reconciliation suite (Phase 1, Sprint 1 slice 12).
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
ADM="src_admin@test.com"; CUST="src_cust@test.com"
cleanup() {
    q "DELETE FROM statement_audit WHERE actor_email IN ('$ADM','$CUST');
       DELETE FROM statement_recon_run WHERE statement_run_id IN (SELECT id FROM statement_run WHERE created_by='$ADM');
       DELETE FROM statement_run WHERE created_by='$ADM';
       DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST'));
       DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST');
       DELETE FROM users WHERE email IN ('$ADM','$CUST');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1080,'$ADM','x','SRC Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1081,'$CUST','x','SRC Customer','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO accounts (user_id,currency_id,balance,status) SELECT 1081,currency_id,1000,'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1;
       SET @aid=LAST_INSERT_ID();
       INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description,created_at) VALUES
       ('SRC1',@aid,100,'DEBIT',(SELECT currency_id FROM currencies WHERE iso_code='IDR'),'match debit','2026-10-01 10:00:00'),
       ('SRC2',@aid,50,'CREDIT',(SELECT currency_id FROM currencies WHERE iso_code='IDR'),'match credit','2026-10-01 11:00:00'),
       ('SRC4',@aid,30,'DEBIT',(SELECT currency_id FROM currencies WHERE iso_code='IDR'),'amount mismatch','2026-10-01 12:00:00');
       INSERT INTO statement_run (period_start,period_end,currency_code,status,account_count,generated_count,created_by)
       VALUES ('2026-10-01','2026-10-31','IDR','COMPLETED',1,1,'$ADM');
       SET @srid=LAST_INSERT_ID();
       INSERT INTO statement_archive (run_id,account_email,currency_code,opening_balance,closing_balance,total_debit,total_credit,row_count)
       VALUES (@srid,'$CUST','IDR',1000,785,165,50,4);
       SET @arch=LAST_INSERT_ID();
       INSERT INTO statement_archive_line (archive_id,line_no,posting_date,txn_ref,source,debit_amount,credit_amount,balance_after,description) VALUES
       (@arch,1,'2026-10-01','SRC1','TRANSFER',100,0,900,'match debit'),
       (@arch,2,'2026-10-01','SRC2','TRANSFER',0,50,950,'match credit'),
       (@arch,3,'2026-10-01','SRC3','TRANSFER',25,0,925,'missing ledger'),
       (@arch,4,'2026-10-01','SRC4','TRANSFER',40,0,885,'amount mismatch');"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1081;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  STATEMENT RECONCILIATION SUITE (PHASE 1)"
echo "======================================================================"
setup
SRID="$(q "SELECT id FROM statement_run WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")"
check_contains "start statement recon" "SUCCESS|SRC_STARTED|" \
    "$(run SRC_START "$SRID" '' '' '' '' "$ADM")"
RID="$(q "SELECT id FROM statement_recon_run WHERE statement_run_id=$SRID ORDER BY id DESC LIMIT 1;")"
check_contains "match archive to ledger" "SUCCESS|SRC_MATCHED|4|2|1|1" \
    "$(run SRC_MATCH "$RID" '' '' '' '' "$ADM")"
check_contains "items list" "SRC3" \
    "$(run SRC_ITEMS "$RID" '' 50 0 '' "$ADM")"
check_contains "filter unmatched items" "UNMATCHED" \
    "$(run SRC_ITEMS "$RID" UNMATCHED 50 0 '' "$ADM")"
check_contains "export recon items" "SRC1" \
    "$(run SRC_EXPORT "$RID" CSV '' '' '' "$ADM")"
check_contains "finish recon" "SUCCESS|SRC_FINISHED|4|2|1|1" \
    "$(run SRC_FINISH "$RID" '' '' '' '' "$ADM")"
check_contains "get recon run" "COMPLETED" \
    "$(run SRC_GET "$RID" '' '' '' '' "$ADM")"
check_contains "list recon runs" "$RID" \
    "$(run SRC_LIST 50 0 '' '' '' "$ADM")"
check_contains "statement summary" "SRC_SUMMARY|$RID|COMPLETED" \
    "$(run SRC_SUMMARY "$SRID" '' '' '' '' "$ADM")"
check "finish twice rejected" "ERROR|INVALID_STATUS" \
    "$(run SRC_FINISH "$RID" '' '' '' '' "$ADM")"
check "missing statement run rejected" "ERROR|NOT_FOUND" \
    "$(run SRC_START 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run SRC_LIST 50 0 '' '' '' "$CUST")"
check "statement recon audit rows recorded" "4" \
    "$(q "SELECT COUNT(*) FROM statement_audit WHERE actor_email IN ('$ADM','$CUST') AND action IN ('RECON_START','RECON_MATCH','RECON_FINISH','AUTHZ_DENIED');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
