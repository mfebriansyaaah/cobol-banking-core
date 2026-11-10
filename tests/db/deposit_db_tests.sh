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
# Fase 2: DEP_OPEN funds the deposit, so the fixture wallet holds the
# principal, the bank-owned DEPOSIT_POOL is capitalized, and the GL period
# is open.
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
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 10000.00 FROM users WHERE email='dep_test@test.com';"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'DEPOSIT_POOL', 1000000.00 FROM users WHERE email='dep_pool@test.com';"

# Open a 12-month USD deposit at 5%. Fase 2 funds it at open: the wallet
# is debited and the pool credited, with subledger + GL linkage.
open_out="$(run_cobol "DEP_OPEN|dep_test@test.com|10000.00|USD|12|5.00|admin@test.com")"
assert_match "DEP_OPEN ok" "$open_out" "SUCCESS\|DEP_OPEN\|[0-9]+"
dep_id="$(printf '%s' "$open_out" | awk -F'|' '{print $3}')"
assert_match "deposit id present" "$dep_id" "^[0-9]+$"
assert_match "deposit active after funding" "$(db_query "SELECT status FROM deposit_account WHERE id=${dep_id};")" "^ACTIVE$"
assert_match "wallet debited by principal" "$(db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='dep_test@test.com') AND currency_id=1;")" "^0.0000$"
assert_match "pool credited by principal" "$(db_query "SELECT balance FROM accounts WHERE account_type='DEPOSIT_POOL' AND currency_id=1;")" "^1010000.0000$"
assert_match "two funding legs posted" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${dep_id}-FUND';")" "^2$"
assert_match "funding debits wallet credits pool" "$(db_query "SELECT GROUP_CONCAT(CONCAT(account_id,':',type) ORDER BY type DESC) FROM ledger WHERE txn_ref='DEP-${dep_id}-FUND';")" "^$(db_query "SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='dep_test@test.com') AND currency_id=1;"):DEBIT,$(db_query "SELECT account_id FROM accounts WHERE account_type='DEPOSIT_POOL' AND currency_id=1;"):CREDIT$"
assert_match "deposit links fund journal" "$(db_query "SELECT fund_journal_id FROM deposit_account WHERE id=${dep_id};")" "^[0-9]+$"
assert_match "deposit links fund gl" "$(db_query "SELECT fund_gl_journal_id FROM deposit_account WHERE id=${dep_id};")" "^[0-9]+$"
assert_match "funding transaction recorded" "$(db_query "SELECT COUNT(*) FROM deposit_transaction WHERE deposit_id=${dep_id} AND txn_type='PRINCIPAL_FUNDED';")" "^1$"
assert_match "funding gl balanced" "$(db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM gl_journal_line WHERE journal_id=(SELECT fund_gl_journal_id FROM deposit_account WHERE id=${dep_id}) GROUP BY journal_id HAVING ABS(SUM(debit_amount - credit_amount)) > 0.0001) t;")" "^0$"

# Opening without funds fails closed before any row is written.
db_exec "INSERT INTO users (email,password_hash,full_name,dob,status,role) VALUES ('dep_broke@test.com',CONCAT('SHA256_',SHA2('secret123',256)),'Broke','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE status='VERIFIED';"
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 10.00 FROM users WHERE email='dep_broke@test.com' ON DUPLICATE KEY UPDATE balance=10.00;"
assert_match "short wallet refused" "$(run_cobol "DEP_OPEN|dep_broke@test.com|5000.00|USD|12|5.00|admin@test.com")" "ERROR\|INSUFFICIENT_FUNDS"
assert_match "failed open wrote no row" "$(db_query "SELECT COUNT(*) FROM deposit_account WHERE customer_email='dep_broke@test.com';")" "^0$"
assert_match "failed open posted no legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE from_email='dep_broke@test.com';")" "^0$"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='dep_broke@test.com');"
db_exec "DELETE FROM users WHERE email='dep_broke@test.com';"

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

# Close refunds the principal when funded (posted interest forfeited),
# so no money strands in the pool.
open2_out="$(run_cobol "DEP_OPEN|dep_test@test.com|5000.00|USD|12|5.00|admin@test.com")"
assert_match "second DEP_OPEN ok" "$open2_out" "SUCCESS\|DEP_OPEN\|[0-9]+"
dep2_id="$(printf '%s' "$open2_out" | awk -F'|' '{print $3}')"
assert_match "second wallet debited" "$(db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='dep_test@test.com') AND currency_id=1;")" "^5041.0959$"
run_cobol "DEP_ACCRUE|${dep2_id}|30|||||admin@test.com" >/dev/null
run_cobol "DEP_POST|${dep2_id}|||||admin@test.com" >/dev/null
assert_match "keyed close ok" "$(run_cobol "DEP_CLOSE|${dep2_id}||||K-CL1|admin@test.com")" "SUCCESS\|DEP_CLOSED\|5000.0000"
assert_match "closed after refund" "$(db_query "SELECT status FROM deposit_account WHERE id=${dep2_id};")" "^CLOSED$"
assert_match "principal refunded, interest forfeited" "$(db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='dep_test@test.com') AND currency_id=1;")" "^10041.0959$"
assert_match "two refund legs posted" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${dep2_id}-REFUND';")" "^2$"
assert_match "close links journal" "$(db_query "SELECT journal_id FROM deposit_account WHERE id=${dep2_id};")" "^[0-9]+$"
assert_match "close links gl" "$(db_query "SELECT gl_journal_id FROM deposit_account WHERE id=${dep2_id};")" "^[0-9]+$"
assert_match "refund transaction recorded" "$(db_query "SELECT COUNT(*) FROM deposit_transaction WHERE deposit_id=${dep2_id} AND txn_type='PRINCIPAL_REFUNDED';")" "^1$"
assert_match "refund gl balanced" "$(db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM gl_journal_line WHERE journal_id=(SELECT gl_journal_id FROM deposit_account WHERE id=${dep2_id}) GROUP BY journal_id HAVING ABS(SUM(debit_amount - credit_amount)) > 0.0001) t;")" "^0$"
assert_match "keyed close replay ok" "$(run_cobol "DEP_CLOSE|${dep2_id}||||K-CL1|admin@test.com")" "SUCCESS\|DEP_CLOSED\|5000.0000"
assert_match "replay refunded once" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${dep2_id}-REFUND';")" "^2$"
assert_match "close on closed refused" "$(run_cobol "DEP_CLOSE|${dep2_id}||||K-CL2|admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "close request recorded once" "$(db_query "SELECT COUNT(*) FROM deposit_close_request WHERE deposit_id=${dep2_id};")" "^1$"
assert_match "pool round-trips principal" "$(db_query "SELECT balance FROM accounts WHERE account_type='DEPOSIT_POOL' AND currency_id=1;")" "^999958.9041$"

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
db_exec "DELETE FROM deposit_transaction WHERE deposit_id=${dep2_id};"
db_exec "DELETE FROM deposit_accrual WHERE deposit_id=${dep2_id};"
db_exec "DELETE FROM deposit_account WHERE id=${dep2_id};"
db_exec "DELETE FROM journal_entries WHERE txn_ref='DEP-${dep_id}';"
db_exec "DELETE FROM journal_entries WHERE txn_ref='DEP-${dep_id}-FUND';"
db_exec "DELETE FROM journal_entries WHERE txn_ref='DEP-${dep2_id}-FUND';"
db_exec "DELETE FROM journal_entries WHERE txn_ref='DEP-${dep2_id}-REFUND';"
db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'DEP_SETTLE:${dep_id}:%');"
db_exec "DELETE FROM gl_journal WHERE description LIKE 'DEP_SETTLE:${dep_id}:%';"
db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'DEP_OPEN:${dep_id}:%');"
db_exec "DELETE FROM gl_journal WHERE description LIKE 'DEP_OPEN:${dep_id}:%';"
db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'DEP_OPEN:${dep2_id}:%');"
db_exec "DELETE FROM gl_journal WHERE description LIKE 'DEP_OPEN:${dep2_id}:%';"
db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'DEP_CLOSE:${dep2_id}:%');"
db_exec "DELETE FROM gl_journal WHERE description LIKE 'DEP_CLOSE:${dep2_id}:%';"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('dep_test@test.com','dep_pool@test.com'));"
db_exec "DELETE FROM users WHERE email IN ('dep_test@test.com','dep_pool@test.com');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
