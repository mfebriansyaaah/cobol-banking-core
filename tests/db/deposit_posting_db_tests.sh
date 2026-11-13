#!/usr/bin/env bash
# Deposit posting seam tests (maint-06): DEP_ACCRUE / DEP_POST_INTEREST /
# DEP_SETTLE through the deposit_posting_core split. The owner keeps the
# transaction; the callee owns the pre-transaction resolve + GL post.
# Covers the OUT protocol (POST_READY fields, CLEANUP paths, and the
# settle idempotency-replay passthrough) plus the fail-closed books.
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
db_reset_deposit
CUR="$(date +%Y-%m)"
run_cobol "GL_PERIOD_OPEN|${CUR}|||||admin@test.com" >/dev/null
for U in dpost@test.com dpost_pool@test.com; do
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}'));"
    db_exec "DELETE FROM pending_transactions WHERE from_email='${U}' OR to_email='${U}';"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
    db_exec "DELETE FROM users WHERE email='${U}';"
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Dep Post|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
done
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 15000.00 FROM users WHERE email='dpost@test.com';"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'DEPOSIT_POOL', 1000000.00 FROM users WHERE email='dpost_pool@test.com';"

# Accrue 30 days on a 10000 @ 5% deposit: 10000 * 5 * 30 / 36500 = 41.0959.
open_out="$(run_cobol "DEP_OPEN|dpost@test.com|10000.00|USD|12|5.00|admin@test.com")"
assert_match "DEP_OPEN ok" "$open_out" "SUCCESS\|DEP_OPEN\|[0-9]+"
did1="$(printf '%s' "$open_out" | awk -F'|' '{print $3}')"
acc_out="$(run_cobol "DEP_ACCRUE|${did1}|30||||admin@test.com")"
assert_match "DEP_ACCRUE ok" "$acc_out" "SUCCESS\|DEP_ACCRUE\|41.0959"
assert_match "account accrued" "$(db_query "SELECT accrued_interest FROM deposit_account WHERE id=${did1};")" "^41.0959$"
assert_match "accrue unknown refused" "$(run_cobol "DEP_ACCRUE|999999|30||||admin@test.com")" "ERROR\|NOT_FOUND"

# Post drains ACCRUED rows into posted_interest with a balanced GL journal.
post_out="$(run_cobol "DEP_POST_INTEREST|${did1}|||||admin@test.com")"
assert_match "DEP_POST_INTEREST ok" "$post_out" "SUCCESS\|DEP_POST\|41.0959"
assert_match "interest posted" "$(db_query "SELECT posted_interest FROM deposit_account WHERE id=${did1};")" "^41.0959$"
assert_match "accrual rows drained" "$(db_query "SELECT COUNT(*) FROM deposit_accrual WHERE deposit_id=${did1} AND status='ACCRUED';")" "^0$"
assert_match "post links gl" "$(db_query "SELECT post_gl_journal_id FROM deposit_account WHERE id=${did1};")" "^[0-9]+$"
assert_match "post gl balanced" "$(db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM gl_journal_line WHERE journal_id=(SELECT post_gl_journal_id FROM deposit_account WHERE id=${did1}) GROUP BY journal_id HAVING ABS(SUM(debit_amount - credit_amount)) > 0.0001) t;")" "^0$"
assert_match "post drains once" "$(run_cobol "DEP_POST_INTEREST|${did1}|||||admin@test.com")" "ERROR\|NOTHING_TO_POST"

# Keyed settle on a second deposit: replay returns the stored outcome.
open2="$(run_cobol "DEP_OPEN|dpost@test.com|2000.00|USD|12|5.00|admin@test.com")"
did2="$(printf '%s' "$open2" | awk -F'|' '{print $3}')"
run_cobol "DEP_ACCRUE|${did2}|30||||admin@test.com" >/dev/null
run_cobol "DEP_POST_INTEREST|${did2}|||||admin@test.com" >/dev/null
settle_out="$(run_cobol "DEP_SETTLE|${did2}||||K-DP1|admin@test.com")"
assert_match "keyed settle ok" "$settle_out" "SUCCESS\|DEP_SETTLE\|2008.2192"
assert_match "keyed replay ok" "$(run_cobol "DEP_SETTLE|${did2}||||K-DP1|admin@test.com")" "SUCCESS\|DEP_SETTLE\|2008.2192"
assert_match "mirror settle recorded DONE" "$(db_query "SELECT CONCAT(status, '|', amount) FROM idempotency_request WHERE scope='DEP_SETTLE' AND entity_ref='${did2}' AND idem_key='K-DP1';")" "^DONE|2008.2192$"
assert_match "settle closes" "$(db_query "SELECT status FROM deposit_account WHERE id=${did2};")" "^CLOSED$"
assert_match "settle links gl" "$(db_query "SELECT gl_journal_id FROM deposit_account WHERE id=${did2};")" "^[0-9]+$"
assert_match "settle gl balanced" "$(db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM gl_journal_line WHERE journal_id=(SELECT gl_journal_id FROM deposit_account WHERE id=${did2}) GROUP BY journal_id HAVING ABS(SUM(debit_amount - credit_amount)) > 0.0001) t;")" "^0$"
assert_match "wallet credited" "$(db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='dpost@test.com') AND currency_id=1;")" "^5008.2192$"

# Unkeyed settle on the first deposit, then accrue on the closed row.
assert_match "settle ok" "$(run_cobol "DEP_SETTLE|${did1}|||||admin@test.com")" "SUCCESS\|DEP_SETTLE\|10041.0959"
assert_match "accrue on closed refused" "$(run_cobol "DEP_ACCRUE|${did1}|30||||admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "settle unknown refused" "$(run_cobol "DEP_SETTLE|999999|||||admin@test.com")" "ERROR\|NOT_FOUND"

# Frozen pool fails the settle closed before any write.
open3="$(run_cobol "DEP_OPEN|dpost@test.com|500.00|USD|12|5.00|admin@test.com")"
did3="$(printf '%s' "$open3" | awk -F'|' '{print $3}')"
db_exec "UPDATE accounts SET status='FROZEN' WHERE account_type='DEPOSIT_POOL' AND currency_id=1;"
assert_match "settle into frozen pool refused" "$(run_cobol "DEP_SETTLE|${did3}|||||admin@test.com")" "ERROR\|DEPOSIT_POOL_MISSING"
assert_match "refused settle wrote no legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${did3}';")" "^0$"
db_exec "UPDATE accounts SET status='ACTIVE' WHERE account_type='DEPOSIT_POOL' AND currency_id=1;"

db_exec "DELETE FROM ledger WHERE txn_ref LIKE 'DEP-%';"
db_exec "DELETE FROM deposit_transaction WHERE deposit_id IN (SELECT id FROM deposit_account WHERE customer_email IN ('dpost@test.com'));"
db_exec "DELETE FROM deposit_accrual WHERE deposit_id IN (SELECT id FROM deposit_account WHERE customer_email IN ('dpost@test.com'));"
db_exec "DELETE FROM deposit_settle_request WHERE deposit_id IN (SELECT id FROM deposit_account WHERE customer_email IN ('dpost@test.com'));"
db_exec "DELETE FROM deposit_account WHERE customer_email IN ('dpost@test.com');"
db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'DEP\\_%');"
db_exec "DELETE FROM gl_journal WHERE description LIKE 'DEP\\_%';"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('dpost@test.com','dpost_pool@test.com'));"
db_exec "DELETE FROM users WHERE email IN ('dpost@test.com','dpost_pool@test.com');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
