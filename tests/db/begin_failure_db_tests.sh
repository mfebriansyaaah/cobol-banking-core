#!/usr/bin/env bash
# TXN-BEGIN must fail closed when START TRANSACTION fails.
# Test-only seam: SQL_BRIDGE_TEST + SQL_BRIDGE_TEST_FAIL_BEGIN.
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

# File mode is mandatory: the seam must reach a fresh process, not a
# persistent --serve worker started without the test environment.
export COBOL_TEST_SERVE=0
db_seed
U="beginfail-a@test.com"
V="beginfail-b@test.com"
for E in "$U" "$V"; do
db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${E}'));"
db_exec "DELETE FROM pending_transactions WHERE from_email='${E}' OR to_email='${E}';"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${E}');"
db_exec "DELETE FROM users WHERE email='${E}';"
run_cobol "REQUEST_SIGNUP|${E}|Passw0rd!|Begin Fail|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${E}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${E}|${code}" >/dev/null
done
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${U}';"
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${V}';"
bal() { db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='$1') AND currency_id=1;"; }
cleanup() {
db_exec "DELETE FROM ledger WHERE txn_ref LIKE 'TXNBF-%';"
db_exec "DELETE FROM pending_transactions WHERE txn_ref LIKE 'TXNBF-%';"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U}','${V}'));"
db_exec "DELETE FROM users WHERE email IN ('${U}','${V}');"
}
trap cleanup EXIT

# 1-3. Forced BEGIN failure on a money path: ERROR|DB_ERROR, no legs, no balance move.
out="$(SQL_BRIDGE_TEST=1 SQL_BRIDGE_TEST_FAIL_BEGIN=1 \
    run_cobol "TRANSFER|${U}|${V}|10.00|TXNBF-1|||")"
assert_match "begin failure is surfaced" "$out" "^ERROR\|DB_ERROR$"
assert_match "failed begin writes no legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='TXNBF-1';")" "^0$"
assert_match "failed begin moves no money" "$(bal "$U")" "^1000.0000$"

# 4-5. The normal path still commits and persists.
out="$(run_cobol "TRANSFER|${U}|${V}|10.00|TXNBF-2|||")"
assert_match "normal begin still succeeds" "$out" "^SUCCESS\|TRANSFER_OK"
assert_match "normal begin moves money" "$(bal "$U")" "^990.0000$"

# 6. A non-money create path also fails closed (cost_center, Wave 1).
REF="TXNBF-$(date +%s)-$$"
out="$(SQL_BRIDGE_TEST=1 SQL_BRIDGE_TEST_FAIL_BEGIN=1 \
    run_cobol "CSC_CREATE|${REF}|Begin Fail|OPEX|||admin@test.com")"
assert_match "begin failure fails the create" "$out" "^ERROR\|DB_ERROR$"
db_exec "DELETE FROM cost_center_audit WHERE cc_id IN (SELECT id FROM cost_center WHERE cc_ref='${REF}');"
db_exec "DELETE FROM cost_center WHERE cc_ref='${REF}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
cleanup
trap - EXIT
exit 0
