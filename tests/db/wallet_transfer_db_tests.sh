#!/usr/bin/env bash
# Wallet transfer seam tests (maint-07): TRANSFER through the
# wallet_transfer_core JOIN. The owner opens the transaction, the callee
# runs the whole engine inside it, the owner commits or rolls back from
# the callee outcome. Pins the finalize paths (commit, replay-commit,
# rollback mapping) plus the fail-closed decision table.
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
WA="wlttA@test.com"
WB="wlttB@test.com"
for U in "$WA" "$WB"; do
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}'));"
    db_exec "DELETE FROM pending_transactions WHERE from_email='${U}' OR to_email='${U}';"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
    db_exec "DELETE FROM users WHERE email='${U}';"
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Wlt Tr|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
    db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${U}';"
done
bal() { db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='$1') AND currency_id=1;"; }

assert_match "transfer ok" "$(run_cobol "TRANSFER|${WA}|${WB}|100.00|WLTT-1|||")" "SUCCESS\|TRANSFER_OK"
assert_match "sender debited" "$(bal "$WA")" "^900.0000$"
assert_match "target credited" "$(bal "$WB")" "^1100.0000$"
assert_match "legs posted" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='WLTT-1';")" "^2$"
assert_match "replay ok" "$(run_cobol "TRANSFER|${WA}|${WB}|100.00|WLTT-1|||")" "SUCCESS\|TRANSFER_OK"
assert_match "replay moves nothing" "$(bal "$WA")" "^900.0000$"
assert_match "conflict refused" "$(run_cobol "TRANSFER|${WA}|${WB}|50.00|WLTT-1|||")" "ERROR\|IDEMPOTENCY_CONFLICT"
assert_match "self transfer refused" "$(run_cobol "TRANSFER|${WA}|${WA}|10.00|WLTT-SELF|||")" "ERROR\|SELF_TRANSFER"
assert_match "zero amount refused" "$(run_cobol "TRANSFER|${WA}|${WB}|0.00|WLTT-Z|||")" "ERROR\|INVALID_AMOUNT"
assert_match "overdraft refused" "$(run_cobol "TRANSFER|${WA}|${WB}|5000.00|WLTT-BIG|||")" "ERROR\|INSUFFICIENT_FUNDS"
assert_match "failed transfer wrote no legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='WLTT-BIG';")" "^0$"
assert_match "unknown sender refused" "$(run_cobol "TRANSFER|nobody@test.com|${WB}|10.00|WLTT-NS|||")" "ERROR\|ACCOUNT_NOT_FOUND"
db_exec "UPDATE accounts SET status='FROZEN' WHERE user_id=(SELECT id FROM users WHERE email='${WA}') AND currency_id=1;"
assert_match "frozen sender refused" "$(run_cobol "TRANSFER|${WA}|${WB}|10.00|WLTT-FR|||")" "ERROR\|ACCOUNT_FROZEN"
db_exec "UPDATE accounts SET status='ACTIVE' WHERE user_id=(SELECT id FROM users WHERE email='${WA}') AND currency_id=1;"
assert_match "transfer after unfreeze ok" "$(run_cobol "TRANSFER|${WA}|${WB}|10.00|WLTT-2|||")" "SUCCESS\|TRANSFER_OK"
assert_match "totals conserved" "$(db_query "SELECT COALESCE(SUM(balance),0) FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')) AND currency_id=1;")" "^2000.0000$"

db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')));"
db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${WA}','${WB}') OR to_email IN ('${WA}','${WB}');"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
db_exec "DELETE FROM users WHERE email IN ('${WA}','${WB}');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
