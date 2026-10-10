#!/bin/bash
# Atomic-transfer + ledger integrity suite (Phase 1).
# Verifies TRANSFER is atomic and writes an immutable ledger entry per side.
# Usage: ./tests/test_ledger_atomic.sh

BIN="./cobol/bin/main_logic"

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

reset() {
    q "UPDATE accounts SET balance=1000.00 WHERE account_id=1;
       UPDATE accounts SET balance=0.00 WHERE account_id=2;
       DELETE FROM ledger;
       INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description) VALUES
         ('INIT_001',1,1000.00,'CREDIT',1,'Initial Deposit'),
         ('INIT_002',2,0.00,'CREDIT',1,'Initial Deposit');"
}

run() {
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt
    "$BIN" >/dev/null 2>&1
    cat output.txt
}

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"
        passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"
        failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  ATOMIC TRANSFER + LEDGER INTEGRITY SUITE"
echo "======================================================================"

# --- Case A: happy path writes exactly two ledger rows and moves the money ---
reset
out=$(run TRANSFER sender@test.com receiver@test.com 100.00 "")
check "happy path output" "SUCCESS|TRANSFER_OK" "$out"
check "sender balance" "900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "target balance" "100.0000" "$(q "SELECT balance FROM accounts WHERE account_id=2;")"
check "ledger row count" "2" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref NOT LIKE 'INIT_%';")"
check "ledger debit row" "1|DEBIT|100.0000" "$(q "SELECT CONCAT(account_id,'|',type,'|',amount) FROM ledger WHERE type='DEBIT';")"
check "ledger credit row" "2|CREDIT|100.0000" "$(q "SELECT CONCAT(account_id,'|',type,'|',amount) FROM ledger WHERE type='CREDIT' AND txn_ref NOT LIKE 'INIT_%';")"
check "ledger single txn_ref" "1" "$(q "SELECT COUNT(DISTINCT txn_ref) FROM ledger WHERE txn_ref NOT LIKE 'INIT_%';")"
check "sender ledger sum equals balance" "900.00" \
    "$(q "SELECT CONCAT(ROUND(SUM(CASE WHEN type='CREDIT' THEN amount ELSE -amount END),2)) FROM ledger WHERE account_id=1;")"

# --- Case B: insufficient funds -> rollback, no ledger, balances untouched ---
reset
out=$(run TRANSFER sender@test.com receiver@test.com 5000.00 "")
check "insufficient output" "ERROR|INSUFFICIENT_FUNDS" "$out"
check "insufficient: sender untouched" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "insufficient: no ledger" "0" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref NOT LIKE 'INIT_%';")"

# --- Case C: unknown target -> rollback, sender untouched ---
reset
out=$(run TRANSFER sender@test.com nobody@test.com 100.00 "")
check "unknown target output" "ERROR|TARGET_NOT_FOUND" "$out"
check "unknown target: sender untouched" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "unknown target: no ledger" "0" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref NOT LIKE 'INIT_%';")"

# --- Case D: unknown sender -> rollback ---
reset
out=$(run TRANSFER nobody@test.com receiver@test.com 100.00 "")
check "unknown sender output" "ERROR|ACCOUNT_NOT_FOUND" "$out"
check "unknown sender: no ledger" "0" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref NOT LIKE 'INIT_%';")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
