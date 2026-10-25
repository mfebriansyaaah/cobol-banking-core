#!/usr/bin/env bash
# Table-driven COBOL core tests: each row is "expected grep pattern @@ input line".
# Exit 0 only if every row passes.
set -u

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
BIN="$ROOT/cobol/bin/main_logic"
fail=0
count=0
pass=0

run_case() {
    local expected="$1"
    local input="$2"
    count=$((count + 1))
    printf '%s\n' "$input" > "$ROOT/input.txt"
    "$BIN" >/dev/null 2>&1
    local out
    out="$(cat "$ROOT/output.txt" 2>/dev/null)"
    if printf '%s' "$out" | grep -Eq "$expected"; then
        pass=$((pass + 1))
    else
        echo "FAIL: expected /$expected/ got: $out (input: $input)"
        fail=1
    fi
}

# Table of cases (expected grep pattern @@ COBOL input line).
cases=(
  'SUCCESS\|PONG@@PING||||||'
  'ERROR\|MISSING_ACTION@@||||||'
  'ERROR\|INVALID_ACTION@@NO_SUCH_ACTION||||||'
  'SUCCESS\|ROLE_OK@@CHECK_ROLE|admin@test.com|SUPER_ADMIN|admin@test.com|||'
  'SUCCESS\|BALANCES@@CHECK_BALANCE|sender@test.com|sender@test.com|||'
  'SUCCESS\|LIST_DONE@@LIST_USERS|10|0|admin@test.com||'
  'SUCCESS\|USER@@GET_USER|sender@test.com|admin@test.com|||'
  'ERROR\|INVALID_CREDENTIALS@@AUTH_LOGIN|sender@test.com|wrongpass|||'
)

for row in "${cases[@]}"; do
    expected="${row%%@@*}"
    input="${row#*@@}"
    run_case "$expected" "$input"
done

echo "cobol table tests: pass=$pass fail=$((count - pass)) total=$count"
if [ "$fail" -ne 0 ]; then
    exit 1
fi
exit 0
