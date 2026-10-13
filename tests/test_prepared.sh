#!/bin/bash
# Prepared-statement suite: REQUEST_SIGNUP/AUTH_LOGIN run through
# SQL_PREPARE_EXEC and LIST_USERS through SQL_PREPARE_EXEC_ROWS (bound
# parameters). Values are literals, not concatenated.
# Usage: ./tests/test_prepared.sh

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

check_contains() {
    local name="$1" needle="$2" actual="$3"
    if [[ "$actual" == *"$needle"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected to contain [$needle] got [$actual])"; failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  PREPARED STATEMENT SUITE"
echo "======================================================================"

q "DELETE FROM verification_logs WHERE email='prep_ok@test.com'; DELETE FROM users WHERE email='prep_ok@test.com';"

out=$(run REQUEST_SIGNUP prep_ok@test.com 'secret123' "O'Brien-Smith" '1990-01-01')
check_contains "prepared signup" "SUCCESS|USER_CREATED" "$out"
check "name stored literally" "O'Brien-Smith" "$(q "SELECT full_name FROM users WHERE email='prep_ok@test.com';")"
code=$(echo "$out" | cut -d'|' -f3)
check "prepared verify" "SUCCESS|EMAIL_VERIFIED" "$(run VERIFY_EMAIL prep_ok@test.com "$code")"
check "prepared login ok" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN prep_ok@test.com 'secret123')"
check "prepared login wrong password" "ERROR|INVALID_CREDENTIALS" "$(run AUTH_LOGIN prep_ok@test.com 'nope')"
check "prepared login unknown" "ERROR|ACCOUNT_NOT_FOUND" "$(run AUTH_LOGIN nobody@test.com 'secret123')"

# LIST_USERS goes through SQL_PREPARE_EXEC_ROWS (bound LIMIT/OFFSET, many rows).
ADMIN="prep_admin@test.com"
q "DELETE FROM users WHERE email='$ADMIN';
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (995,'$ADMIN',CONCAT('SHA256_',SHA2('secret123',256)),'Prep Admin','1990-01-01','VERIFIED','SUPER_ADMIN');"
check "prepared list first page" "SUCCESS|LIST_DONE|1:sender@test.com;2:receiver@test.com" "$(run LIST_USERS 2 0 "$ADMIN")"
check "prepared list paging" "SUCCESS|LIST_DONE|1:sender@test.com" "$(run LIST_USERS 1 0 "$ADMIN")"
check "prepared list forbidden for non-admin" "ERROR|FORBIDDEN" "$(run LIST_USERS '' '' prep_ok@test.com)"

# TRANSFER runs through prepared statements end to end (lock, debit/credit,
# ledger, intent, audit).
q "UPDATE accounts SET balance=1000.00 WHERE account_id=1;
   UPDATE accounts SET balance=0.00 WHERE account_id=2;
   DELETE FROM ledger WHERE txn_ref NOT LIKE 'INIT_%'; DELETE FROM pending_transactions;"
check "prepared transfer" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 10.00 preptx-1)"
check "prepared transfer replay is idempotent" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 10.00 preptx-1)"
check "prepared transfer ledger rows" "2" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='preptx-1';")"
check "prepared transfer intent committed" "COMMITTED" "$(q "SELECT status FROM pending_transactions WHERE txn_ref='preptx-1';")"

q "DELETE FROM verification_logs WHERE email='prep_ok@test.com'; DELETE FROM users WHERE email IN ('prep_ok@test.com','$ADMIN');"
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
