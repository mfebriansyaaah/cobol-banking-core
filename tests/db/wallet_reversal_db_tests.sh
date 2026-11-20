#!/usr/bin/env bash
# Wallet reversal (PR-5b): transfer -> reverse, balances restored.
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
U1="wrevA@test.com"
U2="wrevB@test.com"
KEY="WREV-1"
db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${U1}','${U2}') OR to_email IN ('${U1}','${U2}');"
db_exec "DELETE FROM transfer_reversals WHERE from_email IN ('${U1}','${U2}');"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U1}','${U2}'));"
db_exec "DELETE FROM verification_logs WHERE email IN ('${U1}','${U2}');"
db_exec "DELETE FROM users WHERE email IN ('${U1}','${U2}');"
for U in "$U1" "$U2"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Rev Test|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
    db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 500.00 FROM users WHERE email='${U}';"
done

assert_match "transfer ok" "$(run_cobol "TRANSFER|${U1}|${U2}|50.00|${KEY}|||")" "SUCCESS\|TRANSFER_OK"
assert_match "receiver funded" "$(db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${U2}');")" "^550.0000$"
assert_match "reverse ok" "$(run_cobol "REVERSE_TRANSFER|${KEY}|${A}|${U1}|CUSTOMER_ERROR")" "SUCCESS\|TRANSFER_REVERSED"
assert_match "sender restored" "$(db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${U1}');")" "^500.0000$"
assert_match "receiver debited" "$(db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${U2}');")" "^500.0000$"
assert_match "reversal row" "$(db_query "SELECT COUNT(*) FROM transfer_reversals WHERE orig_ref='${KEY}';")" "^1$"
assert_match "double reverse refused" "$(run_cobol "REVERSE_TRANSFER|${KEY}|${A}|${U1}|CUSTOMER_ERROR")" "ERROR\|ALREADY_REVERSED"
assert_match "non-admin refused" "$(run_cobol "REVERSE_TRANSFER|${KEY}|sender@test.com|${U1}|CUSTOMER_ERROR")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${U1}','${U2}') OR to_email IN ('${U1}','${U2}');"
db_exec "DELETE FROM transfer_reversals WHERE from_email IN ('${U1}','${U2}');"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U1}','${U2}'));"
db_exec "DELETE FROM verification_logs WHERE email IN ('${U1}','${U2}');"
db_exec "DELETE FROM users WHERE email IN ('${U1}','${U2}');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
