#!/usr/bin/env bash
# Wallet conservation invariants (toward 10/10): every transfer, reversal,
# and rejected attempt must preserve the total across the fixture set, keep
# per-account ledger nets equal to balance deltas, keep every journal
# balanced, and never drive a balance negative. A fixed script of 19
# operations with hand-computed running balances (A/B start 1000.00 each);
# conservation is asserted after every phase so a leak is localized, not
# just tallied at the end. Green twice required.
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
WA="wltcsvA@test.com"
WB="wltcsvB@test.com"

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
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Wlt Csv|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
    db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${U}';"
done
bal() { db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='$1') AND currency_id=1;"; }
net() { db_query "SELECT COALESCE(SUM(CASE WHEN type='CREDIT' THEN amount ELSE -amount END),0) FROM ledger WHERE account_id=(SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='$1') AND currency_id=1);"; }
total() { db_query "SELECT COALESCE(SUM(balance),0) FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')) AND currency_id=1;"; }
neg() { db_query "SELECT COUNT(*) FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')) AND balance < 0;"; }
unbalanced() { db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'))) AND journal_id IS NOT NULL GROUP BY journal_id HAVING ABS(SUM(CASE WHEN type='DEBIT' THEN amount ELSE -amount END)) > 0.0001) t;"; }

# 1-2. Opening moves. A=900 B=1100, then A=925 B=1075.
assert_match "t1 transfer ok" "$(run_cobol "TRANSFER|${WA}|${WB}|100.00|WLTCO-1|||")" "SUCCESS\|TRANSFER_OK"
assert_match "t2 transfer ok" "$(run_cobol "TRANSFER|${WB}|${WA}|25.00|WLTCO-2|||")" "SUCCESS\|TRANSFER_OK"
# 3-4. Rejected attempts change nothing.
assert_match "t3 overdraw refused" "$(run_cobol "TRANSFER|${WA}|${WB}|99999.00|WLTCO-3|||")" "ERROR\|INSUFFICIENT_FUNDS"
assert_match "t4 self refused" "$(run_cobol "TRANSFER|${WA}|${WA}|1.00|WLTCO-4|||")" "ERROR\|SELF_TRANSFER"
assert_match "conserved after rejects" "$(total)" "^2000.0000$"
assert_match "no negatives after rejects" "$(neg)" "^0$"
# 5-6. Small transfer (A=1000 B=1000), then reversal of t1 (A=1100 B=900).
assert_match "t5 transfer ok" "$(run_cobol "TRANSFER|${WB}|${WA}|75.00|WLTCO-5|||")" "SUCCESS\|TRANSFER_OK"
assert_match "t6 reverse t1" "$(run_cobol "REVERSE_TRANSFER|WLTCO-1|${A}|${WA}|CUSTOMER_ERROR")" "SUCCESS\|TRANSFER_REVERSED"
assert_match "conserved after reversal" "$(total)" "^2000.0000$"
assert_match "no negatives after reversal" "$(neg)" "^0$"
# 7-9. Double reversal refused; same-key reuse with different amount conflicts.
assert_match "t7 double reverse refused" "$(run_cobol "REVERSE_TRANSFER|WLTCO-1|${A}|${WA}|CUSTOMER_ERROR")" "ERROR\|ALREADY_REVERSED"
assert_match "t8 same key other amount conflicts" "$(run_cobol "TRANSFER|${WA}|${WB}|50.00|WLTCO-1|||")" "ERROR\|IDEMPOTENCY_CONFLICT"
assert_match "conserved after conflicts" "$(total)" "^2000.0000$"
assert_match "t9 transfer ok" "$(run_cobol "TRANSFER|${WB}|${WA}|200.00|WLTCO-6|||")" "SUCCESS\|TRANSFER_OK"
# 10-11. Unknown reversal refused; zero amount refused. A=1300 B=700.
assert_match "t10 unknown reversal refused" "$(run_cobol "REVERSE_TRANSFER|WLTCO-NOPE|${A}|${WA}|CUSTOMER_ERROR")" "ERROR\|UNKNOWN_TRANSACTION"
assert_match "t11 zero refused" "$(run_cobol "TRANSFER|${WA}|${WB}|0.00|WLTCO-7|||")" "ERROR\|INVALID_AMOUNT"
assert_match "conserved after invalid" "$(total)" "^2000.0000$"
assert_match "no negatives after invalid" "$(neg)" "^0$"
# 12-14. Reverse t9 and t5, double reverse t9 refused. A=1100 B=900.
assert_match "t12 reverse t9" "$(run_cobol "REVERSE_TRANSFER|WLTCO-6|${A}|${WB}|CUSTOMER_ERROR")" "SUCCESS\|TRANSFER_REVERSED"
assert_match "t13 double reverse refused" "$(run_cobol "REVERSE_TRANSFER|WLTCO-6|${A}|${WB}|CUSTOMER_ERROR")" "ERROR\|ALREADY_REVERSED"
assert_match "t14 reverse t5" "$(run_cobol "REVERSE_TRANSFER|WLTCO-5|${A}|${WB}|CUSTOMER_ERROR")" "SUCCESS\|TRANSFER_REVERSED"
# 15-17. Drain A exactly, refill B->A exactly, fail past zero.
assert_match "t15 drain A ok" "$(run_cobol "TRANSFER|${WA}|${WB}|1025.00|WLTCO-8|||")" "SUCCESS\|TRANSFER_OK"
assert_match "A at zero" "$(bal "$WA")" "^0.0000$"
assert_match "t16 refill ok" "$(run_cobol "TRANSFER|${WB}|${WA}|2000.00|WLTCO-9|||")" "SUCCESS\|TRANSFER_OK"
assert_match "B at zero" "$(bal "$WB")" "^0.0000$"
assert_match "t17 past zero refused" "$(run_cobol "TRANSFER|${WB}|${WA}|0.01|WLTCO-10|||")" "ERROR\|INSUFFICIENT_FUNDS"
assert_match "conserved after extremes" "$(total)" "^2000.0000$"
assert_match "no negatives after extremes" "$(neg)" "^0$"
# 18-19. Same-key reuse with different amount conflicts; replay of a
# committed key is a no-op success without moving money.
assert_match "t18 same key other amount conflicts" "$(run_cobol "TRANSFER|${WA}|${WB}|7.00|WLTCO-8|||")" "ERROR\|IDEMPOTENCY_CONFLICT"
assert_match "t19 replay t2 is a no-op success" "$(run_cobol "TRANSFER|${WB}|${WA}|25.00|WLTCO-2|||")" "SUCCESS\|TRANSFER_OK"
assert_match "conserved at end" "$(total)" "^2000.0000$"
assert_match "no negatives at end" "$(neg)" "^0$"
# Final positions: A = 2000.00 (net +1000), B = 0.00 (net -1000).
assert_match "A final balance" "$(bal "$WA")" "^2000.0000$"
assert_match "B final balance" "$(bal "$WB")" "^0.0000$"
assert_match "A ledger net equals delta" "$(net "$WA")" "^1000.0000$"
assert_match "B ledger net equals delta" "$(net "$WB")" "^-1000.0000$"
assert_match "all journals balanced" "$(unbalanced)" "^0$"
assert_match "six committed intents recorded" "$(db_query "SELECT COUNT(*) FROM pending_transactions WHERE from_email IN ('${WA}','${WB}') AND status='COMMITTED';")" "^6$"

cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
