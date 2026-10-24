#!/bin/bash
# Database constraint & rollback suite: unique/FK constraints reject bad writes
# and a transaction rolls back cleanly on failure.
# Usage: ./tests/test_db_constraints.sh

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
qerr() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>&1 1>/dev/null; }

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1));
    else echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1)); fi
}

echo "======================================================================"
echo "  DATABASE CONSTRAINTS SUITE"
echo "======================================================================"

# unique email
out=$(qerr "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (9001,'dup@test.com','x','Dup','1990-01-01','VERIFIED','USER'); INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (9002,'dup@test.com','x','Dup2','1990-01-01','VERIFIED','USER');")
if echo "$out" | grep -qi 'duplicate'; then check "duplicate email rejected" "1" "1"; else check "duplicate email rejected" "1" "0"; fi

# FK violation on ledger (non-existent account)
out=$(qerr "INSERT INTO ledger (account_id,amount,txn_ref,type,currency_id) VALUES (999999,1.00,'fk-test','DEBIT',1);")
if echo "$out" | grep -qi 'foreign key\|cannot add or update'; then check "FK violation rejected" "1" "1"; else check "FK violation rejected" "1" "0"; fi

# transaction rollback
q "CREATE TABLE IF NOT EXISTS _rb (v INT); DELETE FROM _rb;"
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "START TRANSACTION; INSERT INTO _rb VALUES (42); ROLLBACK;" >/dev/null 2>&1
cnt=$(q "SELECT COUNT(*) FROM _rb WHERE v=42;")
check "rollback removes uncommitted row" "0" "$cnt"
q "DROP TABLE _rb; DELETE FROM users WHERE email='dup@test.com'; DELETE FROM ledger WHERE txn_ref='fk-test';"

echo "----------------------------------------------------------------------"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]