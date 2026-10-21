#!/bin/bash
# EOD job execution suite (Sprint 1 slice 5).
# Usage: ./tests/test_eod_jobs.sh
export DORMANT_AFTER_DAYS=1
export DORMANT_GRACE_DAYS=0

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

ADM="stmt_admin@test.com"; USR="stmt_user@test.com"; CUST="stmt_cust@test.com"
cleanup() {
    q "DELETE FROM eod_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM eod_job_run WHERE business_date IN ('2026-10-21','2026-10-20','2026-10-01');
       DELETE FROM statement_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM statement_run WHERE created_by IN ('$ADM','$USR');
       DELETE FROM account_holds WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST'));
       DELETE FROM ledger WHERE txn_ref LIKE 'EODJOB%';
       DELETE FROM notification_outbox WHERE recipient='$CUST';
       DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST');
       DELETE FROM users WHERE email IN ('$ADM','$USR','$CUST');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role,last_login_at) VALUES
       (998,'$ADM','x','Stmt Admin','1990-01-01','VERIFIED','SUPER_ADMIN',NOW()),
       (999,'$USR','x','Stmt User','1990-01-01','VERIFIED','USER',NOW()),
       (1000,'$CUST','x','Stmt Customer','1990-01-01','VERIFIED','USER','2020-01-01 00:00:00')
       ON DUPLICATE KEY UPDATE role=VALUES(role), status='VERIFIED';
       INSERT INTO accounts (user_id, currency_id, balance, status)
       SELECT 1000, currency_id, 0, 'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1
       ON DUPLICATE KEY UPDATE status='ACTIVE';
       INSERT INTO account_holds (account_id, amount, state, reason, actor_email, expires_at)
       SELECT account_id, 10, 'PLACED', 'test', '$ADM', '2026-10-20 00:00:00' FROM accounts WHERE user_id=1000;
       INSERT INTO account_holds (account_id, amount, state, reason, actor_email, expires_at)
       SELECT account_id, 20, 'PLACED', 'future', '$ADM', '2026-12-01 00:00:00' FROM accounts WHERE user_id=1000;
       INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, created_at)
       SELECT 'EODJOB-1', a.account_id, 100, 'CREDIT', a.currency_id, 'eod', '2026-10-02 10:00:00'
       FROM accounts a WHERE a.user_id=1000;"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action IN ('HOLD_EXPIRED','AUTHZ_DENIED') AND user_id=999;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  EOD JOB EXECUTION SUITE (PHASE 1)"
echo "======================================================================"
setup

check "expire holds" "SUCCESS|EOD_HOLD_EXPIRED|1" \
    "$(run EODJOB_HOLD_EXPIRY 2026-10-21 '' '' '' '' "$ADM")"
check "expired hold count" "1" \
    "$(q "SELECT COUNT(*) FROM account_holds WHERE state='EXPIRED';")"
check "duplicate hold job rejected" "ERROR|JOB_ALREADY_RUN" \
    "$(run EODJOB_HOLD_EXPIRY 2026-10-21 '' '' '' '' "$ADM")"
check_contains "mark dormant users" "SUCCESS|EOD_DORMANT_MARKED|" \
    "$(run EODJOB_DORMANT_MARK 2026-10-21 '' '' '' '' "$ADM")"
check_contains "suspend dormant users" "SUCCESS|EOD_DORMANT_SUSPENDED|" \
    "$(run EODJOB_DORM_SUSPEND 2026-10-21 '' '' '' '' "$ADM")"
check "run scheduled reconciliation" "SUCCESS|EOD_RECON_RUN" \
    "$(run EODJOB_RECON 2026-10-21 '' '' '' '' "$ADM")"
check "run EOD statement job" "SUCCESS|EOD_STATEMENT_RUN" \
    "$(run EODJOB_STATEMENT 2026-10-01 2026-10-31 IDR '' '' "$ADM")"
check_contains "list EOD jobs" "HOLD_EXPIRY:COMPLETED" \
    "$(run EODJOB_LIST 50 0 COMPLETED 2026-10-21 '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run EODJOB_LIST 50 0 '' '' '' "$USR")"

check "EOD job audit rows recorded" "6" \
    "$(q "SELECT COUNT(*) FROM eod_audit WHERE actor_email IN ('$ADM','$USR');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
