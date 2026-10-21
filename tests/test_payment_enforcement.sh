#!/bin/bash
# Payment policy enforcement in the transfer path (Phase 1, Sprint 1 slice 11).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
ADM="pe_admin@test.com"; SENDER="pe_sender@test.com"; RECV="pe_recv@test.com"
cleanup() {
    q "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('$SENDER','$RECV')));
       DELETE FROM pending_transactions WHERE from_email IN ('$SENDER') OR to_email IN ('$RECV');
       DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('$SENDER','$RECV'));
       DELETE FROM users WHERE email IN ('$ADM','$SENDER','$RECV');
       DELETE FROM payment_policy WHERE currency_code='IDR';
       DELETE FROM payment_audit WHERE actor_email='$ADM';"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1060,'$ADM','x','PE Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1061,'$SENDER','x','PE Sender','1990-01-01','VERIFIED','USER'),
       (1062,'$RECV','x','PE Receiver','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO accounts (user_id,currency_id,balance,status) SELECT 1061,currency_id,5000,'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1;
       INSERT INTO accounts (user_id,currency_id,balance,status) SELECT 1062,currency_id,0,'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1;"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id IN (1061,1062);"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  PAYMENT POLICY ENFORCEMENT SUITE (PHASE 1)"
echo "======================================================================"
setup
SACC="$(q "SELECT account_id FROM accounts WHERE user_id=1061 LIMIT 1;")"
check "set payment policy" "SUCCESS|PAY_POLICY_SET" \
    "$(run PAY_POLICY_SET IDR '1000,5000,5,0,0' 1 '' '' "$ADM")"
check "transfer over per-txn policy blocked" "ERROR|LIMIT_EXCEEDED" \
    "$(run TRANSFER "$SENDER" "$RECV" 1500 PAYENF1 IDR IDR)"
check "blocked transfer left balance intact" "5000.0000" \
    "$(q "SELECT balance FROM accounts WHERE account_id=$SACC;")"
check "policy allows a smaller transfer" "SUCCESS|TRANSFER_OK" \
    "$(run TRANSFER "$SENDER" "$RECV" 500 PAYENF2 IDR IDR)"
check "policy usage reflected in balance" "4500.0000" \
    "$(q "SELECT balance FROM accounts WHERE account_id=$SACC;")"
check "daily policy can be tightened" "SUCCESS|PAY_POLICY_SET" \
    "$(run PAY_POLICY_SET IDR '0,500,5,0,0' 1 '' '' "$ADM")"
check "transfer over daily policy blocked" "ERROR|DAILY_LIMIT_EXCEEDED" \
    "$(run TRANSFER "$SENDER" "$RECV" 100 PAYENF3 IDR IDR)"
check "disabled policy falls back" "SUCCESS|PAY_POLICY_SET" \
    "$(run PAY_POLICY_SET IDR '0,0,0,0,0' 0 '' '' "$ADM")"
check "disabled policy allows transfer" "SUCCESS|TRANSFER_OK" \
    "$(run TRANSFER "$SENDER" "$RECV" 100 PAYENF4 IDR IDR)"
check "policy audit rows recorded" "3" \
    "$(q "SELECT COUNT(*) FROM payment_audit WHERE actor_email='$ADM' AND action='POLICY_SET';")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
