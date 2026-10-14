#!/bin/bash
# Transfer validity suite: amount must be positive; same-currency moves one
# amount, cross-currency converts the target credit via exchange_rates (and is
# rejected when no rate exists). Failing these must leave balances/ledger intact.
# Usage: ./tests/test_transfer_validity.sh

BIN="./cobol/bin/main_logic"

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

setup() {
    q "DELETE FROM accounts WHERE account_id IN (961,963);
       DELETE FROM users WHERE id IN (961,963);
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (961,'idr_validity@test.com','x','IDR User','1990-01-01','VERIFIED','USER'),
       (963,'eur_validity@test.com','x','EUR User','1990-01-01','VERIFIED','USER');
       INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES
       (961,961,3,0.00,'SAVINGS'),
       (963,963,2,0.00,'SAVINGS');
       UPDATE accounts SET balance=1000.00 WHERE account_id=1;
       UPDATE accounts SET balance=0.00 WHERE account_id=2;
       DELETE FROM ledger;
       DELETE FROM pending_transactions;"
}

teardown() { q "DELETE FROM accounts WHERE account_id IN (961,963); DELETE FROM users WHERE id IN (961,963);"; }

run() {
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt
    "$BIN" >/dev/null 2>&1
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

echo "======================================================================"
echo "  TRANSFER VALIDITY SUITE"
echo "======================================================================"
setup

check "same currency ok" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 100.00 "")"
check "moved once" "900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"

setup
check "zero amount rejected" "ERROR|INVALID_AMOUNT" "$(run TRANSFER sender@test.com receiver@test.com 0 "" )"
check "zero-amount: no movement" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "zero-amount: no ledger" "0" "$(q "SELECT COUNT(*) FROM ledger;")"
check "decimal zero rejected" "ERROR|INVALID_AMOUNT" "$(run TRANSFER sender@test.com receiver@test.com 0.00 "")"

setup
check "fx converts to the target currency" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com idr_validity@test.com 100.00 "")"
check "fx sender debited in its currency" "900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "fx target credited at the rate" "1570000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=961;")"
check "fx debit ledger row" "1" "$(q "SELECT COUNT(*) FROM ledger WHERE account_id=1 AND type='DEBIT' AND amount=100.00;")"
check "fx credit ledger row" "1" "$(q "SELECT COUNT(*) FROM ledger WHERE account_id=961 AND type='CREDIT' AND amount=1570000.00;")"
check "fx rate is snapshotted on the ledger" "15700.000000" "$(q "SELECT exchange_rate FROM ledger WHERE account_id=961 AND type='CREDIT';")"

# IDR has zero minor units, so the converted credit is a whole number.
setup
check "fx respects target precision (IDR = 0)" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com idr_validity@test.com 1.23 "")"
check "fx IDR credit is whole" "19311.0000" "$(q "SELECT CAST(balance AS CHAR) FROM accounts WHERE account_id=961;")"

# Only the inverse pair exists (USD->IDR): fall back to its reciprocal.
setup
q "UPDATE accounts SET balance=100000.00 WHERE account_id=961;"
check "fx uses the inverse rate" "SUCCESS|TRANSFER_OK" "$(run TRANSFER idr_validity@test.com receiver@test.com 15700 "")"
check "fx inverse credit rounded to USD" "1.0000" "$(q "SELECT balance FROM accounts WHERE account_id=2;")"

# Neither direction exists for this pair.
setup
check "fx with no rate either way is rejected" "ERROR|RATE_NOT_FOUND" "$(run TRANSFER idr_validity@test.com eur_validity@test.com 1000 "")"
check "fx no-rate: target untouched" "0.0000" "$(q "SELECT balance FROM accounts WHERE account_id=963;")"
check "fx no-rate: no ledger" "0" "$(q "SELECT COUNT(*) FROM ledger;")"

setup
check "self-transfer rejected" "ERROR|SELF_TRANSFER" "$(run TRANSFER sender@test.com sender@test.com 100.00 "")"
check "self-transfer: no movement" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "self-transfer: no ledger" "0" "$(q "SELECT COUNT(*) FROM ledger;")"

teardown
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
