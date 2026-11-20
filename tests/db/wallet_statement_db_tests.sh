#!/usr/bin/env bash
# Wallet statements (PR-5b): statement reads after a real transfer.
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
U1="wstmtA@test.com"
U2="wstmtB@test.com"
KEY="WSTMT-1"
db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${U1}','${U2}') OR to_email IN ('${U1}','${U2}');"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U1}','${U2}'));"
db_exec "DELETE FROM verification_logs WHERE email IN ('${U1}','${U2}');"
db_exec "DELETE FROM users WHERE email IN ('${U1}','${U2}');"
for U in "$U1" "$U2"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Stmt Test|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
    db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 500.00 FROM users WHERE email='${U}';"
done

assert_match "transfer ok" "$(run_cobol "TRANSFER|${U1}|${U2}|25.00|${KEY}|||")" "SUCCESS\|TRANSFER_OK"
stmt_out="$(run_cobol "STATEMENT|${U1}|${U1}|USD|||")"
assert_match "sender statement ok" "$stmt_out" "SUCCESS\|"
assert_match "statement lists transfer" "$stmt_out" "${KEY}"
assert_match "receiver statement ok" "$(run_cobol "STATEMENT|${U2}|${U2}|USD|||")" "SUCCESS\|"
assert_match "foreign statement refused" "$(run_cobol "STATEMENT|${U1}|${U2}|USD|||")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${U1}','${U2}') OR to_email IN ('${U1}','${U2}');"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U1}','${U2}'));"
db_exec "DELETE FROM verification_logs WHERE email IN ('${U1}','${U2}');"
db_exec "DELETE FROM users WHERE email IN ('${U1}','${U2}');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
