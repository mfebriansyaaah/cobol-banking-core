#!/usr/bin/env bash
# Wallet holds (PR-5b): place/release with account-level state.
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
U="whold@test.com"
db_exec "DELETE FROM account_holds WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}'));"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM verification_logs WHERE email='${U}';"
db_exec "DELETE FROM users WHERE email='${U}';"
run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Hold Test|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${U}';"

assert_match "place ok" "$(run_cobol "PLACE_HOLD|${U}|10.00|${A}|||")" "SUCCESS\|"
hid="$(db_query "SELECT hold_id FROM account_holds WHERE account_id=(SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${U}')) ORDER BY hold_id DESC LIMIT 1;")"
assert_match "hold persisted" "$hid" "^[0-9]+$"
assert_match "hold active" "$(db_query "SELECT state FROM account_holds WHERE hold_id=${hid};")" "^PLACED$"
assert_match "held amount" "$(db_query "SELECT amount FROM account_holds WHERE hold_id=${hid};")" "^10\.0000$"
assert_match "release ok" "$(run_cobol "RELEASE_HOLD|${hid}|${A}||||")" "SUCCESS\|"
assert_match "release persisted" "$(db_query "SELECT state FROM account_holds WHERE hold_id=${hid};")" "^RELEASED$"
assert_match "double release refused" "$(run_cobol "RELEASE_HOLD|${hid}|${A}||||")" "ERROR\|UNKNOWN_TRANSACTION"
assert_match "non-admin place refused" "$(run_cobol "PLACE_HOLD|${U}|10.00|sender@test.com|||")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM account_holds WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}'));"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM verification_logs WHERE email='${U}';"
db_exec "DELETE FROM users WHERE email='${U}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
