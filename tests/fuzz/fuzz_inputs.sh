#!/usr/bin/env bash
# Property-based / fuzz testing: random input validation for COBOL actions.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! db_available 2>/dev/null; then echo "SKIP: DB unavailable"; exit 0; fi

FAIL=0
# Fuzz inputs: empty, huge, special chars, SQL injection attempts
FUZZ_INPUTS=(
  ""
  "||||||"
  "'; DROP TABLE users; --||||||admin@test.com"
  "A" 
  "123456789012345678901234567890"
  "NULL"
  "undefined"
  "../../../etc/passwd"
  "<script>alert(1)</script>"
)

ACTIONS=("GLA_CREATE" "BDR_CREATE" "RPB_CREATE" "PMC_CREATE" "COL_OPEN")

for action in "${ACTIONS[@]}"; do
  for input in "${FUZZ_INPUTS[@]}"; do
    printf '%s|%s|||||admin@test.com\n' "$action" "$input" > "$ROOT/input.txt"
    DB_HOST="${DB_HOST:-localhost}" DB_PORT="${DB_PORT:-3306}" \
      DB_USER="${DB_USER:-cobol_user}" DB_PASS="${DB_PASS:-cobol_pass}" \
      DB_NAME="${DB_NAME:-cobol_db}" "$ROOT/cobol/bin/main_logic" >/dev/null 2>&1
    out="$(cat "$ROOT/output.txt" 2>/dev/null)"
    # Should never crash (no empty output, no segfault)
    if [ -z "$out" ]; then
      echo "FAIL: $action with '$input' -> empty output (crash?)"
      FAIL=1
    fi
  done
done

if [ "$FAIL" -ne 0 ]; then exit 1; fi
echo "Fuzz testing passed: no crashes."