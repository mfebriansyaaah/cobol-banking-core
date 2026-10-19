#!/bin/bash
# Control-account uniqueness suite: bank-owned FX_PNL/FEE_INCOME accounts are
# resolved by (currency_id, account_type, status='ACTIVE') with LIMIT 1, so
# at most one ACTIVE row per pair may exist. The generated control_slot is
# non-NULL exactly for rows matching that lookup predicate, and its UNIQUE
# key rejects duplicates fail-loud at the schema layer. Missing control
# accounts keep failing closed in COBOL (DB_ERROR); INACTIVE rows of any
# kind stay unconstrained.
# Usage: ./tests/test_control_accounts.sh

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
# Run SQL, print OK when it succeeds, ERR when the statement is refused.
errc() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1" >/dev/null 2>&1 && echo OK || echo ERR; }

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  CONTROL ACCOUNT UNIQUENESS SUITE"
echo "======================================================================"

# Fixture ids 967-970 are reserved for this suite (see cleanup below).
q "DELETE FROM accounts WHERE account_id IN (967,968,969,970); DELETE FROM users WHERE id IN (967,968,969,970);
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (967,'ctl_a@test.com','x','Ctl A','1990-01-01','VERIFIED','USER'),
   (968,'ctl_b@test.com','x','Ctl B','1990-01-01','VERIFIED','USER'),
   (969,'ctl_c@test.com','x','Ctl C','1990-01-01','VERIFIED','USER'),
   (970,'ctl_d@test.com','x','Ctl D','1990-01-01','VERIFIED','USER');"

check "first ACTIVE FX_PNL accepted" "OK" "$(errc "INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES (967,967,2,0.00,'FX_PNL')")"
check "slot maps the lookup predicate" "2/FX_PNL" "$(q "SELECT control_slot FROM accounts WHERE account_id=967;")"
check "duplicate ACTIVE FX_PNL refused" "ERR" "$(errc "INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES (968,968,2,0.00,'FX_PNL')")"
check "no second row was created" "0" "$(q "SELECT COUNT(*) FROM accounts WHERE account_id=968;")"
check "INACTIVE duplicate allowed" "OK" "$(errc "INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type,status) VALUES (968,968,2,0.00,'FX_PNL','CLOSED')")"
check "INACTIVE row maps to NULL slot" "NULL" "$(q "SELECT IFNULL(control_slot,'NULL') FROM accounts WHERE account_id=968;")"
check "FROZEN row maps to NULL slot" "NULL" "$(q "UPDATE accounts SET status='FROZEN' WHERE account_id=968; SELECT IFNULL(control_slot,'NULL') FROM accounts WHERE account_id=968;")"
check "first ACTIVE FEE_INCOME accepted" "OK" "$(errc "INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES (969,969,1,0.00,'FEE_INCOME')")"
check "fee slot maps the lookup predicate" "1/FEE_INCOME" "$(q "SELECT control_slot FROM accounts WHERE account_id=969;")"
check "duplicate ACTIVE FEE_INCOME refused" "ERR" "$(errc "INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES (970,970,1,0.00,'FEE_INCOME')")"
check "exactly one ACTIVE row per pair" "1|1" "$(q "SELECT CONCAT(SUM(currency_id=2 AND account_type='FX_PNL'), '|', SUM(currency_id=1 AND account_type='FEE_INCOME')) FROM accounts WHERE status='ACTIVE' AND account_id IN (967,969);")"
check "SAVINGS rows map to NULL slot" "NULL" "$(q "SELECT IFNULL(MAX(control_slot),'NULL') FROM accounts WHERE account_id=1;")"

q "DELETE FROM accounts WHERE account_id IN (967,968,969,970); DELETE FROM users WHERE id IN (967,968,969,970);"
check "fixtures cleaned up" "0" "$(q "SELECT COUNT(*) FROM accounts WHERE account_id IN (967,968,969,970);")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
