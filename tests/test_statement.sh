#!/bin/bash
# Statement archive suite (Sprint 1 slice 5).
# Usage: ./tests/test_statement.sh

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
    q "DELETE FROM statement_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM statement_run WHERE created_by IN ('$ADM','$USR');
       DELETE FROM ledger WHERE txn_ref LIKE 'STMT%';
       DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST');
       DELETE FROM users WHERE email IN ('$ADM','$USR','$CUST');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role,last_login_at) VALUES
       (998,'$ADM','x','Stmt Admin','1990-01-01','VERIFIED','SUPER_ADMIN',NOW()),
       (999,'$USR','x','Stmt User','1990-01-01','VERIFIED','USER',NOW()),
       (1000,'$CUST','x','Stmt Customer','1990-01-01','VERIFIED','USER',NOW())
       ON DUPLICATE KEY UPDATE role=VALUES(role), status='VERIFIED';
       INSERT INTO accounts (user_id, currency_id, balance, status)
       SELECT 1000, currency_id, 0, 'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1
       ON DUPLICATE KEY UPDATE status='ACTIVE';
       INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, created_at)
       SELECT 'STMT-OPEN', a.account_id, 500, 'CREDIT', a.currency_id, 'opening', '2026-09-30 10:00:00'
       FROM accounts a WHERE a.user_id=1000;
       INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, created_at)
       SELECT 'STMT-DEBIT', a.account_id, 100, 'DEBIT', a.currency_id, 'debit', '2026-10-02 10:00:00'
       FROM accounts a WHERE a.user_id=1000;
       INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description, created_at)
       SELECT 'STMT-CREDIT', a.account_id, 50, 'CREDIT', a.currency_id, 'credit', '2026-10-03 10:00:00'
       FROM accounts a WHERE a.user_id=1000;"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=999;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  STATEMENT ARCHIVE SUITE (PHASE 1)"
echo "======================================================================"
setup

RUN_OUT="$(run STMT_RUN_START 2026-10-01 2026-10-31 IDR '' '' "$ADM")"
check_contains "start statement run" "SUCCESS|STMT_RUN_STARTED|" "$RUN_OUT"
RUN_ID="$(printf '%s' "$RUN_OUT" | cut -d'|' -f3)"
check_contains "generate statement archive" "SUCCESS|STMT_RUN_COMPLETED|" \
    "$(run STMT_RUN_GENERATE "$RUN_ID" '' '' '' '' "$ADM")"
check_contains "statement run completed" "COMPLETED" \
    "$(run STMT_RUN_STATUS "$RUN_ID" 0 '' '' '' "$ADM")"
check_contains "archive summary" ":500." \
    "$(run STMT_ARCHIVE_GET "$CUST" "$RUN_ID" 0 '' '' "$ADM")"
check_contains "archive lines" "STMT-DEBIT" \
    "$(run STMT_ARCHIVE_GET "$CUST" "$RUN_ID" 1 '' '' "$ADM")"
check_contains "archive export" "STMT-DEBIT" \
    "$(run STMT_ARCHIVE_EXPORT "$CUST" "$RUN_ID" CSV '' '' "$ADM")"
check_contains "list statement runs" "COMPLETED" \
    "$(run STMT_RUN_LIST 50 0 COMPLETED IDR '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run STMT_RUN_LIST 50 0 '' '' '' "$USR")"

FAIL_OUT="$(run STMT_RUN_START 2026-11-01 2026-11-30 IDR '' '' "$ADM")"
FAIL_ID="$(printf '%s' "$FAIL_OUT" | cut -d'|' -f3)"
check "fail statement run" "SUCCESS|STMT_RUN_FAILED" \
    "$(run STMT_RUN_FAIL "$FAIL_ID" TEST_FAIL 'forced' '' '' "$ADM")"

check "statement audit rows recorded" "5" \
    "$(q "SELECT COUNT(*) FROM statement_audit WHERE actor_email IN ('$ADM','$USR');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
