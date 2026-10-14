#!/bin/bash
# Account lifecycle suite: a transfer is rejected unless the sender AND target
# accounts are ACTIVE and both currencies are enabled. Reads (balance) are still
# allowed on a frozen account. Failures must move no money and write no ledger.
# Usage: ./tests/test_account_status.sh

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

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

setup() {
    q "UPDATE accounts SET balance=1000.00,status='ACTIVE' WHERE account_id=1;
       UPDATE accounts SET balance=0.00,status='ACTIVE' WHERE account_id=2;
       UPDATE currencies SET is_active=1;
       DELETE FROM ledger; DELETE FROM pending_transactions;"
}

echo "======================================================================"
echo "  ACCOUNT LIFECYCLE SUITE (status + currency)"
echo "======================================================================"

IDR="idr_status@test.com"
q "DELETE FROM accounts WHERE user_id=962; DELETE FROM users WHERE id=962;
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (962,'$IDR','x','IDR Status','1990-01-01','VERIFIED','USER');
   INSERT INTO accounts (account_id,user_id,currency_id,balance,status) VALUES
   (962,962,3,0.00,'ACTIVE');"

# --- control -------------------------------------------------------------
setup
check "active -> active succeeds" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 1.00 "")"

# --- sender account state ------------------------------------------------
setup
q "UPDATE accounts SET status='FROZEN' WHERE account_id=1;"
check "frozen sender rejected" "ERROR|ACCOUNT_FROZEN" "$(run TRANSFER sender@test.com receiver@test.com 1.00 "")"
check "frozen sender moved nothing" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "frozen sender wrote no ledger" "0" "$(q "SELECT COUNT(*) FROM ledger;")"

setup
q "UPDATE accounts SET status='CLOSED' WHERE account_id=1;"
check "closed sender rejected" "ERROR|ACCOUNT_CLOSED" "$(run TRANSFER sender@test.com receiver@test.com 1.00 "")"
check "closed sender moved nothing" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"

# --- target account state ------------------------------------------------
setup
q "UPDATE accounts SET status='FROZEN' WHERE account_id=2;"
check "frozen target rejected" "ERROR|ACCOUNT_FROZEN" "$(run TRANSFER sender@test.com receiver@test.com 1.00 "")"
check "frozen target moved nothing" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"

setup
q "UPDATE accounts SET status='CLOSED' WHERE account_id=2;"
check "closed target rejected" "ERROR|ACCOUNT_CLOSED" "$(run TRANSFER sender@test.com receiver@test.com 1.00 "")"

# --- currency state ------------------------------------------------------
setup
q "UPDATE currencies SET is_active=0 WHERE currency_id=1;"
check "inactive sender currency rejected" "ERROR|CURRENCY_INACTIVE" "$(run TRANSFER sender@test.com receiver@test.com 1.00 "")"
check "inactive currency moved nothing" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"

setup
q "UPDATE currencies SET is_active=0 WHERE currency_id=3;"
check "inactive target currency rejected" "ERROR|CURRENCY_INACTIVE" "$(run TRANSFER sender@test.com "$IDR" 1.00 "")"
q "UPDATE currencies SET is_active=1;"

# --- reads are unaffected ------------------------------------------------
setup
q "UPDATE accounts SET status='FROZEN' WHERE account_id=1;"
check "frozen account balance still readable" "SUCCESS|BALANCES|USD:1000.00:FROZEN" "$(run CHECK_BALANCE sender@test.com sender@test.com)"

q "UPDATE accounts SET status='ACTIVE' WHERE account_id IN (1,2);"
q "DELETE FROM accounts WHERE user_id=962; DELETE FROM users WHERE id=962;"
q "DELETE FROM ledger; DELETE FROM pending_transactions;
   UPDATE accounts SET balance=1000.00 WHERE account_id=1; UPDATE accounts SET balance=0.00 WHERE account_id=2;"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
