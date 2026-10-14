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

reset
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
