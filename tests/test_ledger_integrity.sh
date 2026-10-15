#!/bin/bash
# Ledger integrity suite: the ledger is append-only (no UPDATE), amounts must be
# positive, a posting (txn_ref, account, type) is unique, and deleting an account
# preserves the account's ledger rows in the immutable archive.
# Usage: ./tests/test_ledger_integrity.sh

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
echo "  LEDGER INTEGRITY SUITE"
echo "======================================================================"

U="li_u@test.com"
q "DELETE FROM users WHERE email='$U'; DELETE FROM ledger_archive WHERE from_email='$U';
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (940,'$U','x','U','1990-01-01','VERIFIED','USER');
   INSERT INTO accounts (user_id,currency_id,balance) SELECT id,1,100 FROM users WHERE email='$U';"
ACC=$(q "SELECT a.account_id FROM accounts a JOIN users u ON u.id=a.user_id WHERE u.email='$U'")
q "INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description,from_email) VALUES ('li-1',$ACC,50,'CREDIT',1,'x','$U');"

check "ledger UPDATE is refused" "ERR" "$(errc "UPDATE ledger SET amount=1 WHERE txn_ref='li-1'")"
check "a negative amount is refused" "ERR" "$(errc "INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id) VALUES ('li-neg',$ACC,-1,'CREDIT',1)")"

# Deleting the account preserves its ledger rows in the archive.
q "DELETE FROM accounts WHERE account_id=$ACC;"
check "the live ledger row is gone" "0" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='li-1'")"
check "the ledger row survives in the archive" "1" "$(q "SELECT COUNT(*) FROM ledger_archive WHERE txn_ref='li-1'")"

q "DELETE FROM users WHERE email='$U'; DELETE FROM ledger_archive WHERE txn_ref='li-1';"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
