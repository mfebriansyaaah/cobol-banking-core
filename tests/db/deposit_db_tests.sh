#!/usr/bin/env bash
# D2 (deposit & interest) end-to-end DB tests via the COBOL binary.
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
# Fase 1: DEP_SETTLE pays out real money, so the fixture owns a wallet, the
# bank-owned DEPOSIT_POOL is capitalized, and the GL period is open.
CUR="$(date +%Y-%m)"
run_cobol "GL_PERIOD_OPEN|${CUR}|||||admin@test.com" >/dev/null
for U in dep_test@test.com dep_pool@test.com; do
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}'));"
    db_exec "DELETE FROM pending_transactions WHERE from_email='${U}' OR to_email='${U}';"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
    db_exec "DELETE FROM users WHERE email='${U}';"
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Dep T|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
done
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 0 FROM users WHERE email='dep_test@test.com';"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'DEPOSIT_POOL', 1000000.00 FROM users WHERE email='dep_pool@test.com';"

# Open a 12-month USD deposit at 5%.
open_out="$(run_cobol "DEP_OPEN|dep_test@test.com|10000.00|USD|12|5.00|admin@test.com")"
assert_match "DEP_OPEN ok" "$open_out" "SUCCESS\|DEP_OPEN\|[0-9]+"
dep_id="$(printf '%s' "$open_out" | awk -F'|' '{print $3}')"
assert_match "deposit id present" "$dep_id" "^[0-9]+$"

# maturity_date is derived from the term (12 months from today).
mat="$(db_query "SELECT maturity_date = DATE_ADD(CURDATE(), INTERVAL 12 MONTH) FROM deposit_account WHERE id=${dep_id};")"
assert_match "maturity_date = today + 12 months" "$mat" "^1$"

# GET exposes the interest fields.
get_out="$(run_cobol "DEP_GET|${dep_id}|||||admin@test.com")"
assert_match "DEP_GET ok" "$get_out" "SUCCESS\|DEPOSIT\|${dep_id}"
assert_match "GET carries accrued interest" "$get_out" "\|0.0000\|0.0000\|"

# Accrue 30 days: 10000 * 5 * 30 / 36500 = 41.0959.
acc_out="$(run_cobol "DEP_ACCRUE|${dep_id}|30||||admin@test.com")"
assert_match "DEP_ACCRUE ok" "$acc_out" "SUCCESS\|DEP_ACCRUE\|41.0959"
accrued="$(db_query "SELECT accrued_interest FROM deposit_account WHERE id=${dep_id};")"
assert_match "account accrued_interest" "$accrued" "^41.0959$"
last="$(db_query "SELECT last_accrual_date = CURDATE() FROM deposit_account WHERE id=${dep_id};")"
assert_match "last_accrual_date is today" "$last" "^1$"

# Re-accruing the same day is idempotent (upsert, not a second row).
run_cobol "DEP_ACCRUE|${dep_id}|30||||admin@test.com" >/dev/null
rows="$(db_query "SELECT COUNT(*) FROM deposit_accrual WHERE deposit_id=${dep_id};")"
assert_match "one accrual row per day" "$rows" "^1$"
interest="$(db_query "SELECT interest FROM deposit_accrual WHERE deposit_id=${dep_id};")"
assert_match "same-day accrual does not double" "$interest" "^41.0959$"

# Post moves the accrual into posted_interest and writes a transaction.
post_out="$(run_cobol "DEP_POST|${dep_id}|||||admin@test.com")"
assert_match "DEP_POST ok" "$post_out" "SUCCESS\|DEP_POST\|41.0959"
posted="$(db_query "SELECT posted_interest FROM deposit_account WHERE id=${dep_id};")"
assert_match "posted_interest" "$posted" "^41.0959$"
acc="$(db_query "SELECT accrued_interest FROM deposit_account WHERE id=${dep_id};")"
assert_match "accrued cleared after post" "$acc" "^0.0000$"
ast="$(db_query "SELECT status FROM deposit_accrual WHERE deposit_id=${dep_id};")"
assert_match "accrual marked POSTED" "$ast" "^POSTED$"
txn="$(db_query "SELECT COUNT(*) FROM deposit_transaction WHERE deposit_id=${dep_id} AND txn_type='INTEREST_POSTED';")"
assert_match "interest transaction recorded" "$txn" "^1$"

# Posting again has nothing left to post.
again="$(run_cobol "DEP_POST|${dep_id}|||||admin@test.com")"
assert_match "second DEP_POST rejected" "$again" "ERROR\|NOTHING_TO_POST"

# Statement returns both accrual (A:) and transaction (T:) rows.
stmt="$(run_cobol "DEP_STATEMENT|${dep_id}|||||admin@test.com")"
assert_match "DEP_STATEMENT has accrual" "$stmt" "A:.*41.0959"
assert_match "DEP_STATEMENT has transaction" "$stmt" "T:INTEREST_POSTED"

# Summary reports principal and posted interest.
sum="$(run_cobol "DEP_SUMMARY||||||admin@test.com")"
assert_match "DEP_SUMMARY ok" "$sum" "SUCCESS\|DEP_SUMMARY\|1\|1\|0\|10000.0000\|0.0000\|41.0959"

# Settle pays principal + posted interest.
set_out="$(run_cobol "DEP_SETTLE|${dep_id}|||||admin@test.com")"
assert_match "DEP_SETTLE ok" "$set_out" "SUCCESS\|DEP_SETTLE\|10041.0959"
cs="$(db_query "SELECT status FROM deposit_account WHERE id=${dep_id};")"
assert_match "status CLOSED after settle" "$cs" "^CLOSED$"
payout="$(db_query "SELECT amount FROM deposit_transaction WHERE deposit_id=${dep_id} AND txn_type='PRINCIPAL_PAYOUT';")"
assert_match "payout amount" "$payout" "^10041.0959$"

# Settling/closing twice is rejected.
close_out="$(run_cobol "DEP_CLOSE|${dep_id}|||||admin@test.com")"
assert_match "close after settle rejected" "$close_out" "ERROR\|INVALID_STATUS"

# Validation and calc endpoints work without creating rows.
val="$(run_cobol "DEP_VALIDATE|10000.00|USD|12|5.00||admin@test.com")"
assert_match "DEP_VALIDATE ok" "$val" "SUCCESS\|DEP_VALID\|493.1507"
calc="$(run_cobol "DEP_CALC|10000.00|5.00|365|||admin@test.com")"
assert_match "DEP_CALC one year" "$calc" "SUCCESS\|DEP_CALC\|500.0000\|10500.0000"

# Audit trail has the lifecycle actions.
ac="$(db_query "SELECT COUNT(*) FROM deposit_audit WHERE deposit_id=${dep_id};")"
assert_match "audit rows recorded" "$ac" "^[4-9][0-9]*$"

# LIST, MATURE and AUDIT complete the routed surface (deposit is CLOSED,
# so MATURE only proves the sweep endpoint works).
assert_match "DEP_LIST ok" "$(run_cobol "DEP_LIST||50|0|||admin@test.com")" "SUCCESS\|DEPOSITS\|"
assert_match "list carries the deposit" "$(run_cobol "DEP_LIST||50|0|||admin@test.com")" "dep_test@test.com"
assert_match "DEP_MATURE ok" "$(run_cobol "DEP_MATURE||||||admin@test.com")" "SUCCESS\|DEP_MATURED"
assert_match "DEP_AUDIT ok" "$(run_cobol "DEP_AUDIT|${dep_id}|50|0|||admin@test.com")" "SUCCESS\|DEP_AUDIT\|"

# Leave no bank-owned rows behind: the control-slot unique key is global,
# and a later suite in the same database would fail its own pool insert.
db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('dep_test@test.com','dep_pool@test.com')));"
db_exec "DELETE FROM pending_transactions WHERE from_email IN ('dep_test@test.com','dep_pool@test.com') OR to_email IN ('dep_test@test.com','dep_pool@test.com');"
db_exec "DELETE FROM deposit_transaction WHERE deposit_id=${dep_id};"
db_exec "DELETE FROM deposit_accrual WHERE deposit_id=${dep_id};"
db_exec "DELETE FROM deposit_account WHERE id=${dep_id};"
db_exec "DELETE FROM journal_entries WHERE txn_ref='DEP-${dep_id}';"
db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'DEP_SETTLE:${dep_id}:%');"
db_exec "DELETE FROM gl_journal WHERE description LIKE 'DEP_SETTLE:${dep_id}:%';"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('dep_test@test.com','dep_pool@test.com'));"
db_exec "DELETE FROM users WHERE email IN ('dep_test@test.com','dep_pool@test.com');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
