#!/bin/bash
# Wallet observability suite: the TRANSFER audit row carries context
# (target:amount:currency), and stale idempotency intents are pruned past the
# retention window while fresh ones are kept.
# Usage: ./tests/test_wallet_observability.sh

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

echo "======================================================================"
echo "  WALLET OBSERVABILITY SUITE"
echo "======================================================================"

q "UPDATE accounts SET balance=1000.00,status='ACTIVE' WHERE account_id=1;
   UPDATE accounts SET balance=0.00,status='ACTIVE' WHERE account_id=2;
   DELETE FROM ledger; DELETE FROM pending_transactions; DELETE FROM pending_transactions_archive;"

# --- audit context -------------------------------------------------------
check "transfer" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 12.34 obs-1)"
check "audit detail has target/amount/currency" "receiver@test.com:12.34:USD" \
    "$(q "SELECT detail FROM audit_trail WHERE action='TRANSFER' ORDER BY audit_id DESC LIMIT 1;")"
check "audit is attributed to the sender" "sender@test.com" \
    "$(q "SELECT u.email FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE a.action='TRANSFER' ORDER BY a.audit_id DESC LIMIT 1;")"

# --- idempotency-intent retention ---------------------------------------
q "INSERT INTO pending_transactions (txn_ref, from_email, to_email, amount, status, created_at) VALUES
   ('obs-old','sender@test.com','receiver@test.com', 1.00, 'COMMITTED', DATE_SUB(NOW(), INTERVAL 40 DAY));"
check "stale intent present before" "1" "$(q "SELECT COUNT(*) FROM pending_transactions WHERE txn_ref='obs-old';")"
run TRANSFER sender@test.com receiver@test.com 1.00 obs-2 >/dev/null
check "stale intent pruned on the next transfer" "0" "$(q "SELECT COUNT(*) FROM pending_transactions WHERE txn_ref='obs-old';")"
check "stale intent archived (not lost)" "1" "$(q "SELECT COUNT(*) FROM pending_transactions_archive WHERE txn_ref='obs-old';")"
check "fresh intent kept" "1" "$(q "SELECT COUNT(*) FROM pending_transactions WHERE txn_ref='obs-2';")"

q "UPDATE accounts SET balance=1000.00 WHERE account_id=1; UPDATE accounts SET balance=0.00 WHERE account_id=2;
   DELETE FROM ledger; DELETE FROM pending_transactions; DELETE FROM pending_transactions_archive;"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
