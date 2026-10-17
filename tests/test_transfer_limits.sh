#!/bin/bash
# Transfer limits suite: an optional per-transaction cap and an optional rolling
# 24h debit cap per account (env-driven; both disabled by default). A rejected
# transfer moves no money and writes no ledger row.
# Usage: ./tests/test_transfer_limits.sh

BIN="./cobol/bin/main_logic"

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

run() {
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt
    "$BIN" >/dev/null 2>&1
    cat output.txt
}

# Run with an explicit environment assignment, e.g. run_env "TRANSFER_MAX_PER_TXN=100" ...
run_env() {
    local envs="$1"; shift
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt
    env $envs "$BIN" >/dev/null 2>&1
    cat output.txt
}

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

reset() {
    q "UPDATE accounts SET balance=100000.00,status='ACTIVE' WHERE account_id=1;
       UPDATE accounts SET balance=0.00,status='ACTIVE' WHERE account_id=2;
       DELETE FROM ledger; DELETE FROM pending_transactions;"
}

echo "======================================================================"
echo "  TRANSFER LIMITS SUITE"
echo "======================================================================"

# --- disabled by default -------------------------------------------------
reset
check "no limit by default" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 5000.00 d1)"

# --- per-transaction cap -------------------------------------------------
reset
check "per-txn at the cap is allowed" "SUCCESS|TRANSFER_OK" "$(run_env 'TRANSFER_MAX_PER_TXN=100' TRANSFER sender@test.com receiver@test.com 100.00 d2)"
reset
check "per-txn over the cap is rejected" "ERROR|LIMIT_EXCEEDED" "$(run_env 'TRANSFER_MAX_PER_TXN=100' TRANSFER sender@test.com receiver@test.com 100.01 d3)"
check "per-txn rejection moved nothing" "100000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "per-txn rejection wrote no ledger" "0" "$(q "SELECT COUNT(*) FROM ledger;")"

# --- rolling 24h cap -----------------------------------------------------
reset
check "daily: first transfer under the cap" "SUCCESS|TRANSFER_OK" "$(run_env 'TRANSFER_DAILY_LIMIT=150' TRANSFER sender@test.com receiver@test.com 100.00 d4)"
check "daily: second transfer over the cap" "ERROR|DAILY_LIMIT_EXCEEDED" "$(run_env 'TRANSFER_DAILY_LIMIT=150' TRANSFER sender@test.com receiver@test.com 100.00 d5)"
check "daily: only the first moved" "99900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "daily: one debit recorded" "1" "$(q "SELECT COUNT(*) FROM ledger WHERE type='DEBIT';")"

# A transfer at exactly the remaining headroom is allowed.
reset
run_env 'TRANSFER_DAILY_LIMIT=150' TRANSFER sender@test.com receiver@test.com 100.00 d6 >/dev/null
check "daily: uses the remaining headroom" "SUCCESS|TRANSFER_OK" "$(run_env 'TRANSFER_DAILY_LIMIT=150' TRANSFER sender@test.com receiver@test.com 50.00 d7)"

# --- integer amounts respect the cap (no hidden scaling) ------------------
reset
check "integer amount over the cap is rejected" "ERROR|LIMIT_EXCEEDED" "$(run_env 'TRANSFER_MAX_PER_TXN=100' TRANSFER sender@test.com receiver@test.com 101 d101)"
check "integer rejection moved nothing" "100000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "integer rejection wrote no ledger" "0" "$(q "SELECT COUNT(*) FROM ledger;")"

# --- fewer fraction digits compare in major units --------------------------
reset
check "one-decimal amount under the cap" "SUCCESS|TRANSFER_OK" "$(run_env 'TRANSFER_MAX_PER_TXN=100' TRANSFER sender@test.com receiver@test.com 99.9 d102)"
reset
check "one-decimal amount over the cap is rejected" "ERROR|LIMIT_EXCEEDED" "$(run_env 'TRANSFER_MAX_PER_TXN=100' TRANSFER sender@test.com receiver@test.com 100.1 d103)"

# --- a malformed cap fails closed instead of silently shifting --------------
reset
check "dotted cap fails closed" "ERROR|LIMIT_EXCEEDED" "$(run_env 'TRANSFER_MAX_PER_TXN=7.50' TRANSFER sender@test.com receiver@test.com 1.00 d104)"

# --- daily cap with integer amounts ----------------------------------------
reset
check "daily: integer amount at the cap is allowed" "SUCCESS|TRANSFER_OK" "$(run_env 'TRANSFER_DAILY_LIMIT=100' TRANSFER sender@test.com receiver@test.com 100 d105)"
check "daily: a cent over the integer cap is rejected" "ERROR|DAILY_LIMIT_EXCEEDED" "$(run_env 'TRANSFER_DAILY_LIMIT=100' TRANSFER sender@test.com receiver@test.com 0.01 d107)"
check "daily: only the first moved" "99900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"

# --- zero-decimal currency (IDR, prec 0) ------------------------------------
setup_idr() {
    q "DELETE FROM accounts WHERE account_id IN (971,972);
       DELETE FROM users WHERE email IN ('lim_idr_a@test.com','lim_idr_b@test.com');
       INSERT INTO users (email,password_hash,full_name,dob,status,role) VALUES
       ('lim_idr_a@test.com','x','IDR A','1990-01-01','VERIFIED','USER'),
       ('lim_idr_b@test.com','x','IDR B','1990-01-01','VERIFIED','USER');
       INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type)
       SELECT 971, id, 3, 100000, 'SAVINGS' FROM users WHERE email='lim_idr_a@test.com';
       INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type)
       SELECT 972, id, 3, 0, 'SAVINGS' FROM users WHERE email='lim_idr_b@test.com';
       DELETE FROM ledger; DELETE FROM pending_transactions;"
}
teardown_idr() {
    q "DELETE FROM ledger; DELETE FROM pending_transactions;
       DELETE FROM accounts WHERE account_id IN (971,972);
       DELETE FROM users WHERE email IN ('lim_idr_a@test.com','lim_idr_b@test.com');"
}
setup_idr
check "idr: integer over the cap is rejected" "ERROR|LIMIT_EXCEEDED" "$(run_env 'TRANSFER_MAX_PER_TXN=1000' TRANSFER lim_idr_a@test.com lim_idr_b@test.com 1500 idr1)"
check "idr: integer under the cap moves" "SUCCESS|TRANSFER_OK" "$(run_env 'TRANSFER_MAX_PER_TXN=1000' TRANSFER lim_idr_a@test.com lim_idr_b@test.com 500 idr2)"
check "idr: decimals are not representable" "ERROR|INVALID_AMOUNT" "$(run_env 'TRANSFER_MAX_PER_TXN=1000' TRANSFER lim_idr_a@test.com lim_idr_b@test.com 10.50 idr3)"
teardown_idr

# --- three-decimal currency --------------------------------------------------
setup_p3() {
    q "DELETE FROM accounts WHERE account_id IN (973,974);
       DELETE FROM users WHERE email IN ('lim_p3_a@test.com','lim_p3_b@test.com');
       DELETE FROM currencies WHERE iso_code='T3D';
       INSERT INTO currencies (iso_code,symbol,prec_val) VALUES ('T3D','T',3);
       INSERT INTO users (email,password_hash,full_name,dob,status,role) VALUES
       ('lim_p3_a@test.com','x','P3 A','1990-01-01','VERIFIED','USER'),
       ('lim_p3_b@test.com','x','P3 B','1990-01-01','VERIFIED','USER');
       INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type)
       SELECT 973, u.id, c.currency_id, 1000, 'SAVINGS' FROM users u, currencies c WHERE u.email='lim_p3_a@test.com' AND c.iso_code='T3D';
       INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type)
       SELECT 974, u.id, c.currency_id, 0, 'SAVINGS' FROM users u, currencies c WHERE u.email='lim_p3_b@test.com' AND c.iso_code='T3D';
       DELETE FROM ledger; DELETE FROM pending_transactions;"
}
teardown_p3() {
    q "DELETE FROM ledger; DELETE FROM pending_transactions;
       DELETE FROM accounts WHERE account_id IN (973,974);
       DELETE FROM users WHERE email IN ('lim_p3_a@test.com','lim_p3_b@test.com');
       DELETE FROM currencies WHERE iso_code='T3D';"
}
setup_p3
check "p3: three decimals move exactly" "SUCCESS|TRANSFER_OK" "$(run_env 'TRANSFER_MAX_PER_TXN=100' TRANSFER lim_p3_a@test.com lim_p3_b@test.com 1.234 p31)"
check "p3: debit is exact" "998.7660" "$(q "SELECT balance FROM accounts WHERE account_id=973;")"
check "p3: four decimals exceed the precision" "ERROR|INVALID_AMOUNT" "$(run_env 'TRANSFER_MAX_PER_TXN=100' TRANSFER lim_p3_a@test.com lim_p3_b@test.com 1.2345 p32)"
check "p3: over-cap millis are rejected" "ERROR|LIMIT_EXCEEDED" "$(run_env 'TRANSFER_MAX_PER_TXN=1' TRANSFER lim_p3_a@test.com lim_p3_b@test.com 1.234 p33)"
check "p3: under-cap millis move" "SUCCESS|TRANSFER_OK" "$(run_env 'TRANSFER_MAX_PER_TXN=1' TRANSFER lim_p3_a@test.com lim_p3_b@test.com 0.999 p34)"
teardown_p3

reset
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
