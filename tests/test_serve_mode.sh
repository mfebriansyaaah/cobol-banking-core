#!/bin/bash
# Serve-mode suite: the binary can run long-lived, reading request lines from
# stdin and writing one result line per request (the basis for a worker pool).
# File mode (input.txt/output.txt) must stay unchanged (the default).
# Usage: ./tests/test_serve_mode.sh

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

echo "======================================================================"
echo "  SERVE MODE SUITE"
echo "======================================================================"

q "UPDATE accounts SET balance=1000.00 WHERE account_id=1;"

out=$(printf 'PING\nCHECK_BALANCE|sender@test.com|sender@test.com||\nQUIT\n' | "$BIN" --serve 2>/dev/null)
check "serve: ping" "SUCCESS|PONG" "$(printf '%s\n' "$out" | sed -n '1p')"
check "serve: check balance" "1000.00" "$(printf '%s\n' "$out" | sed -n '2p')"

out2=$(printf 'PING\nPING\nPING\nQUIT\n' | "$BIN" --serve 2>/dev/null)
check "serve: three responses" "3" "$(printf '%s\n' "$out2" | grep -c 'SUCCESS|PONG')"

check "serve: invalid action" "ERROR|INVALID_ACTION" "$(printf 'NOPE\nQUIT\n' | "$BIN" --serve 2>/dev/null)"
check "serve: ends on EOF" "SUCCESS|PONG" "$(printf 'PING\n' | "$BIN" --serve 2>/dev/null)"

# Connection lifecycle: kill the pooled DB connection under a warm serve process.
kill_db() {
    local ids
    ids=$(q "SELECT GROUP_CONCAT(id) FROM information_schema.processlist WHERE user='$DB_USER' AND id <> CONNECTION_ID();")
    for id in $(echo "$ids" | tr ',' ' '); do
        [ -n "$id" ] && [ "$id" != "NULL" ] && q "KILL $id;" >/dev/null
    done
}
q "UPDATE accounts SET balance=1000.00 WHERE account_id=1;"
out=$( { printf 'PING\n'; sleep 0.4; kill_db; sleep 0.2;
         printf 'PING\nCHECK_BALANCE|sender@test.com|sender@test.com||\nQUIT\n'; } | "$BIN" --serve 2>/dev/null )
check "lifecycle: ping before kill" "SUCCESS|PONG" "$(printf '%s\n' "$out" | sed -n '1p')"
check "lifecycle: ping after kill" "SUCCESS|PONG" "$(printf '%s\n' "$out" | sed -n '2p')"
check "lifecycle: query after kill" "1000.00" "$(printf '%s\n' "$out" | sed -n '3p')"

# Transaction over the pooled connection: one movement, idempotent replay.
q "UPDATE accounts SET balance=1000.00 WHERE account_id=1;
   UPDATE accounts SET balance=0.00 WHERE account_id=2; DELETE FROM pending_transactions;"
out=$(printf 'TRANSFER|sender@test.com|receiver@test.com|1.00|serve-lc-1\nTRANSFER|sender@test.com|receiver@test.com|1.00|serve-lc-1\nQUIT\n' | "$BIN" --serve 2>/dev/null)
check "lifecycle: transfer" "SUCCESS|TRANSFER_OK" "$(printf '%s\n' "$out" | sed -n '1p')"
check "lifecycle: replay is idempotent" "SUCCESS|TRANSFER_OK" "$(printf '%s\n' "$out" | sed -n '2p')"
check "lifecycle: moved once" "999.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"

# File mode (default, no --serve) is unchanged.
d=$(mktemp -d)
printf 'PING\n' > "$d/input.txt"
( cd "$d" && "$BIN" >/dev/null 2>&1 )
check "file mode unchanged" "SUCCESS|PONG" "$(cat "$d/output.txt")"
rm -rf "$d"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
