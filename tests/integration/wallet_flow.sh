#!/usr/bin/env bash
# Integration: signup -> transfer -> reverse -> statement.
# Proves the wallet money-path is continuous end to end.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
A="admin@test.com"
WA="wltflowA@test.com"
WB="wltflowB@test.com"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
db_exec "DELETE FROM users WHERE email IN ('${WA}','${WB}');"
for U in "$WA" "$WB"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Wlt Flow|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
    db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 500.00 FROM users WHERE email='${U}';"
done

echo "=== Wallet end-to-end flow ==="
assert_match "transfer" "$(run_cobol "TRANSFER|${WA}|${WB}|50.00|WLTFLOW-1|||")" "SUCCESS\|TRANSFER_OK"
assert_match "receiver sees funds" "$(db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${WB}');")" "^550.0000$"
assert_match "reverse" "$(run_cobol "REVERSE_TRANSFER|WLTFLOW-1|${A}|${WA}|CUSTOMER_ERROR")" "SUCCESS\|TRANSFER_REVERSED"
assert_match "sender whole" "$(db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${WA}');")" "^500.0000$"
assert_match "statement" "$(run_cobol "STATEMENT|${WA}|${WA}|USD|||")" "SUCCESS\|"

db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${WA}','${WB}') OR to_email IN ('${WA}','${WB}');"
db_exec "DELETE FROM transfer_reversals WHERE from_email IN ('${WA}','${WB}');"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
db_exec "DELETE FROM users WHERE email IN ('${WA}','${WB}');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
