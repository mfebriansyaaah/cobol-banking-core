#!/bin/bash
# Concurrent opposing transfers: with a deterministic lock order, simultaneous
# A->B and B->A transfers must all succeed (no deadlock) and conserve money.
# Each invocation runs the binary in its own working directory (ADR-0001).
# Usage: ./tests/test_concurrent_transfer.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/cobol/bin/main_logic"

if [ -f "$ROOT/tests/.dbenv" ]; then . "$ROOT/tests/.dbenv"; fi
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

run_iso() { # action p1 p2 p3 p4 -> prints output; runs in a private cwd
    local dir
    dir=$(mktemp -d)
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > "$dir/input.txt"
    ( cd "$dir" && "$BIN" ) >/dev/null 2>&1
    cat "$dir/output.txt"
    rm -rf "$dir"
}

echo "======================================================================"
echo "  CONCURRENT OPPOSING TRANSFERS SUITE"
echo "======================================================================"

q "UPDATE accounts SET balance=1000.00 WHERE account_id=1;
   UPDATE accounts SET balance=1000.00 WHERE account_id=2;
   DELETE FROM ledger; DELETE FROM pending_transactions;"

N=10
outdir=$(mktemp -d)
for i in $(seq 1 "$N"); do
    run_iso TRANSFER sender@test.com receiver@test.com 1.00 k-t1-$i > "$outdir/a$i" &
    run_iso TRANSFER receiver@test.com sender@test.com 1.00 k-t2-$i > "$outdir/b$i" &
done
wait

ok=0; bad=0
for f in "$outdir"/*; do
    if [ "$(cat "$f")" = "SUCCESS|TRANSFER_OK" ]; then ok=$((ok+1)); else bad=$((bad+1)); fi
done
rm -rf "$outdir"

check "all $((N*2)) concurrent transfers succeeded" "$((N*2))" "$ok"
check "no failed transfers" "0" "$bad"
check "money conserved (2000 total)" "2000.0000" "$(q "SELECT SUM(balance) FROM accounts WHERE account_id IN (1,2);")"
check "ledger rows intact" "$((N*4))" "$(q "SELECT COUNT(*) FROM ledger;")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
