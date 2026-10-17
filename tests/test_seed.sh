#!/bin/bash
# Seed idempotency suite: the development fixtures must be safe to apply any
# number of times — re-running the seed keeps the user/account rows, resets
# exactly the two ledger seed rows, and preserves the seeded balances.
# Usage: ./tests/test_seed.sh

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  SEED IDEMPOTENCY SUITE"
echo "======================================================================"

mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < database/seed_test_data.sql 2>/dev/null
check "first seed run succeeds" "0" "$?"
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < database/seed_test_data.sql 2>/dev/null
check "second seed run succeeds" "0" "$?"

check "seed users present exactly once" "3" "$(q "SELECT COUNT(*) FROM users WHERE email IN ('sender@test.com','receiver@test.com','admin@test.com');")"
check "seed accounts present exactly once" "2" "$(q "SELECT COUNT(*) FROM accounts WHERE account_id IN (1,2);")"
check "ledger seed rows reset to two" "2" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref IN ('INIT_001','INIT_002');")"
check "sender balance unchanged" "1000.00" "$(q "SELECT CONCAT(ROUND(balance,2)) FROM accounts WHERE account_id=1;")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
