#!/usr/bin/env bash
# Wallet money-path invariants (PR-040): transfers move exact amounts,
# ledgers stay balanced, guards hold, races stay safe. Dedicated fixture
# users/accounts; global fee rows owned pre+post. Green twice required.
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
WA="wltinvA@test.com"
WB="wltinvB@test.com"

cleanup_fixture() {
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')));"
    db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${WA}','${WB}') OR to_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM transfer_reversals WHERE from_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM users WHERE email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM fee_schedule WHERE currency_id=1;"
    db_exec "DELETE FROM accounts WHERE account_type='FEE_INCOME' AND currency_id=1;"
}
cleanup_fixture
for U in "$WA" "$WB"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Wlt Inv|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
    db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${U}';"
done
bal() { db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='$1') AND currency_id=1;"; }
net() { db_query "SELECT COALESCE(SUM(CASE WHEN type='CREDIT' THEN amount ELSE -amount END),0) FROM ledger WHERE account_id=(SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='$1') AND currency_id=1);"; }

# 1. Happy path moves exact amounts; ledger nets match balances deltas.
assert_match "TRANSFER ok" "$(run_cobol "TRANSFER|${WA}|${WB}|100.00|WLTINV-1|||")" "SUCCESS\|TRANSFER_OK"
assert_match "sender debited" "$(bal "$WA")" "^900.0000$"
assert_match "receiver credited" "$(bal "$WB")" "^1100.0000$"
assert_match "sender ledger net" "$(net "$WA")" "^-100.0000$"
assert_match "receiver ledger net" "$(net "$WB")" "^100.0000$"

# 2. Idempotency replay: same key acknowledged once, no second effect.
assert_match "replay verdict" "$(run_cobol "TRANSFER|${WA}|${WB}|100.00|WLTINV-1|||")" "SUCCESS\|TRANSFER_OK|ERROR\|DUPLICATE"
assert_match "no double debit" "$(bal "$WA")" "^900.0000$"
assert_match "single pending row" "$(db_query "SELECT COUNT(*) FROM pending_transactions WHERE txn_ref='WLTINV-1';")" "^1$"

# 3. Insufficient funds refused, state untouched.
assert_match "overdraw refused" "$(run_cobol "TRANSFER|${WA}|${WB}|99999.00|WLTINV-2|||")" "ERROR\|INSUFFICIENT_FUNDS"
assert_match "balance intact" "$(bal "$WA")" "^900.0000$"

# 4. Self-transfer refused.
assert_match "self refused" "$(run_cobol "TRANSFER|${WA}|${WA}|1.00|WLTINV-3|||")" "ERROR\|SELF_TRANSFER"

# 5. Ambiguous account: second currency, unpinned refused, pinned resolves.
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 2, 0.00 FROM users WHERE email='${WB}';"
assert_match "ambiguous refused" "$(run_cobol "TRANSFER|${WA}|${WB}|1.00|WLTINV-4|||")" "ERROR\|AMBIGUOUS_ACCOUNT"
assert_match "pinned resolves" "$(run_cobol "TRANSFER|${WA}|${WB}|1.00|WLTINV-5||USD|")" "SUCCESS\|TRANSFER_OK"
assert_match "pinned debit" "$(bal "$WA")" "^899.0000$"

# 6. Reversal once-only: balances restored, second reversal refused.
assert_match "reverse ok" "$(run_cobol "REVERSE_TRANSFER|WLTINV-1|${A}|${WA}|CUSTOMER_ERROR")" "SUCCESS\|TRANSFER_REVERSED"
assert_match "sender restored" "$(bal "$WA")" "^999.0000$"
assert_match "receiver restored" "$(bal "$WB")" "^1001.0000$"
assert_match "double reverse refused" "$(run_cobol "REVERSE_TRANSFER|WLTINV-1|${A}|${WA}|CUSTOMER_ERROR")" "ERROR\|ALREADY_REVERSED"

# 7. Fee residual: flat fee debited extra, income credited exact, no dust.
db_exec "INSERT INTO fee_schedule (currency_id, fee_amount) VALUES (1, 2.50);"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'FEE_INCOME', 0 FROM users WHERE email='${A}';"
assert_match "fee transfer ok" "$(run_cobol "TRANSFER|${WA}|${WB}|100.00|WLTINV-6|USD|USD|")" "SUCCESS\|TRANSFER_OK"
assert_match "sender pays amount+fee" "$(bal "$WA")" "^896.5000$"
assert_match "receiver gets amount" "$(bal "$WB")" "^1101.0000$"
assert_match "fee income exact" "$(db_query "SELECT balance FROM accounts WHERE account_type='FEE_INCOME' AND currency_id=1;")" "^2.5000$"
db_exec "DELETE FROM fee_schedule WHERE currency_id=1;"
db_exec "DELETE FROM accounts WHERE account_type='FEE_INCOME' AND currency_id=1;"

# 8. Concurrency: two racers, 600 each on ~896.50 — exactly one wins,
# balance never negative, ledger nets still match.
db_exec "UPDATE accounts SET balance=896.50 WHERE user_id=(SELECT id FROM users WHERE email='${WA}') AND currency_id=1;"
race() {
    # Independent process, file mode (no persistent server: a child-owned
    # server would reparent to this shell on child exit and wedge `wait`).
    # FDs stay private; the noisiest shared-DB race the suite needs.
    ROOT="$ROOT" COBOL_TEST_SERVE=0 bash -c '. "$ROOT/tests/lib/db.sh"; . "$ROOT/tests/lib/cobol.sh"; require_db; run_cobol "TRANSFER|'"${WA}"'|'"${WB}"'|600.00|'"$1"'|USD|USD|"; echo'
}
race "WLTINV-R1" > /tmp/wltrace1.out 2>&1 &
rpid1=$!
race "WLTINV-R2" > /tmp/wltrace2.out 2>&1 &
rpid2=$!
wait "$rpid1"
wait "$rpid2"
wins="$(grep -c "SUCCESS|TRANSFER_OK" /tmp/wltrace1.out /tmp/wltrace2.out 2>/dev/null | awk -F: '{s+=$2} END {print s}')"
assert_match "exactly one racer wins" "$wins" "^1$"
assert_match "winner balance" "$(bal "$WA")" "^296.5000$"
assert_match "balance non-negative" "$(db_query "SELECT balance >= 0 FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${WA}') AND currency_id=1;")" "^1$"
assert_match "racer ledger consistent" "$(net "$WA")" "^-703.5000$"
rm -f /tmp/wltrace1.out /tmp/wltrace2.out

cleanup_fixture

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
