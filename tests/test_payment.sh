#!/bin/bash
# Payment policy / limit suite (Sprint 1 slice 7).
BIN="./cobol/bin/main_logic"; . ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="pay_admin@test.com"; USR="pay_user@test.com"
cleanup() { q "DELETE FROM payment_audit WHERE actor_email IN ('$ADM','$USR'); DELETE FROM payment_profile WHERE user_email='$USR'; DELETE FROM payment_policy WHERE currency_code='IDR'; DELETE FROM ledger WHERE txn_ref LIKE 'PAYTEST%'; DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$USR'); DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1005,'$ADM','x','Pay Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1006,'$USR','x','Pay User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED'; INSERT INTO accounts (user_id,currency_id,balance,status) SELECT 1006,currency_id,0,'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1 ON DUPLICATE KEY UPDATE status='ACTIVE'; INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description,created_at) SELECT 'PAYTEST1',a.account_id,800,'DEBIT',a.currency_id,'today',NOW() FROM accounts a WHERE a.user_id=1006;"; }
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1006;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"; echo "  PAYMENT POLICY SUITE (PHASE 1)"; echo "======================================================================"; setup
check "set payment policy" "SUCCESS|PAY_POLICY_SET" "$(run PAY_POLICY_SET IDR '1000,1000,3,500,10' 1 '' '' "$ADM")"
check_contains "list payment policies" "IDR:1000" "$(run PAY_POLICY_LIST 50 0 IDR '' '' "$ADM")"
check_contains "get payment policy" "1000.0000000000" "$(run PAY_POLICY_GET IDR '' '' '' '' "$ADM")"
check "set payment profile" "SUCCESS|PAY_PROFILE_SET" "$(run PAY_PROFILE_SET "$USR" IDR '2000,2' 1 '' "$ADM")"
check_contains "list payment profiles" "IDR:2000" "$(run PAY_PROFILE_LIST "$USR" 50 0 '' '' "$ADM")"
check "daily usage" "SUCCESS|PAY_USAGE|800.0000|1" "$(run PAY_DAILY_USAGE "$USR" IDR '' '' '' "$ADM")"
check "check within policy" "SUCCESS|PAY_CHECK|OK|800.0000|1" "$(run PAY_CHECK "$USR" IDR 100 '' '' "$ADM")"
check "per-txn max blocks" "SUCCESS|PAY_CHECK|BLOCKED|PER_TXN" "$(run PAY_CHECK "$USR" IDR 1500 '' '' "$ADM")"
check "daily limit blocks" "SUCCESS|PAY_CHECK|BLOCKED|DAILY_LIMIT" "$(run PAY_CHECK "$USR" IDR 300 '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run PAY_POLICY_LIST 50 0 '' '' '' "$USR")"
check "payment audit rows recorded" "3" "$(q "SELECT COUNT(*) FROM payment_audit WHERE actor_email IN ('$ADM','$USR');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
