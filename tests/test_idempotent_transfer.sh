#!/bin/bash
# Idempotent transfer suite (scalability/reliability item).
# A repeated idempotency key must not move money twice; distinct keys move once
# each; a failed attempt leaves no pending residue so the key can be retried.
# Usage: ./tests/test_idempotent_transfer.sh

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
       DELETE FROM pending_transactions;"
}

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
echo "  IDEMPOTENT TRANSFER SUITE"
echo "======================================================================"

reset
check "first transfer" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 100.00 k-1)"
check "moved once" "900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "replay does not move" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 100.00 k-1)"
check "still moved once" "900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "replay again" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 100.00 k-1)"
check "still moved once (2)" "900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "ledger has one movement" "2" "$(q "SELECT COUNT(*) FROM ledger;")"
check "committed intent recorded" "COMMITTED" "$(q "SELECT status FROM pending_transactions WHERE txn_ref='k-1';")"

# Reusing a committed key with different details is a conflict, not a success.
check "different amount is a conflict" "ERROR|IDEMPOTENCY_CONFLICT" "$(run TRANSFER sender@test.com receiver@test.com 5.00 k-1)"
check "different recipient is a conflict" "ERROR|IDEMPOTENCY_CONFLICT" "$(run TRANSFER sender@test.com other@test.com 100.00 k-1)"
check "different sender is a conflict" "ERROR|IDEMPOTENCY_CONFLICT" "$(run TRANSFER receiver@test.com sender@test.com 100.00 k-1)"
check "conflict did not move money" "900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "conflict added no ledger row" "2" "$(q "SELECT COUNT(*) FROM ledger;")"

check "distinct key moves again" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 50.00 k-2)"
check "two movements total" "850.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "two committed intents" "2" "$(q "SELECT COUNT(*) FROM pending_transactions WHERE status='COMMITTED';")"

# Failure path: no pending residue, and the key can be retried.
reset
check "insufficient fails" "ERROR|INSUFFICIENT_FUNDS" "$(run TRANSFER sender@test.com receiver@test.com 5000.00 k-3)"
check "no pending residue" "0" "$(q "SELECT COUNT(*) FROM pending_transactions;")"
check "balances untouched" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "retry same key succeeds" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 100.00 k-3)"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
