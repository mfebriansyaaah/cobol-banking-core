#!/bin/bash
# Load smoke suite: 50 sequential transfers must all succeed within a bounded
# time, exercising the money path under sustained load without a separate tool.
# Usage: ./tests/test_load_smoke.sh

BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1));
    else echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1)); fi
}

echo "======================================================================"
echo "  LOAD SMOKE SUITE"
echo "======================================================================"

core_start
trap core_stop EXIT

q "UPDATE accounts SET balance=1000.00,status='ACTIVE' WHERE account_id=1;
   UPDATE accounts SET balance=0.00,status='ACTIVE' WHERE account_id=2;
   DELETE FROM ledger; DELETE FROM pending_transactions;"

N=50
ok=0
t0=$(date +%s%N)
for i in $(seq 1 $N); do
    out=$(core_run TRANSFER sender@test.com receiver@test.com 1.00 "")
    if [[ "$out" == SUCCESS* ]] || [[ "$out" == *TRANSFER_OK* ]]; then ok=$((ok+1)); fi
done
t1=$(date +%s%N)
elapsed_ms=$(( (t1 - t0) / 1000000 ))

check "all transfers succeed" "$N" "$ok"
check "sender balance after load" "950.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "receiver balance after load" "50.0000" "$(q "SELECT balance FROM accounts WHERE account_id=2;")"
if [ "$elapsed_ms" -lt 30000 ]; then check "load completes under 30s" "1" "1"; else check "load completes under 30s" "1" "0"; fi
echo "elapsed_ms=$elapsed_ms"

q "UPDATE accounts SET balance=1000.00 WHERE account_id=1; UPDATE accounts SET balance=0.00 WHERE account_id=2; DELETE FROM ledger; DELETE FROM pending_transactions;"

echo "----------------------------------------------------------------------"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]