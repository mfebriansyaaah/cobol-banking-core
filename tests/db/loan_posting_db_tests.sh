#!/usr/bin/env bash
# Loan posting seam tests (maint-09): LOAN_DISBURSE / LOAN_REPAY through
# the loan_posting_core split. The owner keeps dispatch, auth guards, and
# the single transaction per action; the callee owns the pre-transaction
# resolve + GL post and the idempotency helpers. Covers the OUT protocol
# (POST_READY fields, CLEANUP paths with key reuse, and the idempotency
# replay passthroughs) plus the fail-closed books.
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
U="lnpost@test.com"
B="lnpostLB@test.com"
CUR="$(date +%Y-%m)"
run_cobol "GL_PERIOD_OPEN|${CUR}|||||${A}" >/dev/null
for E in "$U" "$B"; do
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${E}'));"
    db_exec "DELETE FROM pending_transactions WHERE from_email='${E}' OR to_email='${E}';"
    db_exec "DELETE FROM loan_repay_request WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email='${E}');"
    db_exec "DELETE FROM loan_disburse_request WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email='${E}');"
    db_exec "DELETE FROM loan_repayment WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email='${E}');"
    db_exec "DELETE FROM loan_application WHERE customer_email='${E}';"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${E}');"
    db_exec "DELETE FROM users WHERE email='${E}';"
    run_cobol "REQUEST_SIGNUP|${E}|Passw0rd!|Ln Post|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${E}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${E}|${code}" >/dev/null
done
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 5000.00 FROM users WHERE email='${U}';"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'LOAN_BOOK', 100000.00 FROM users WHERE email='${B}';"
BOOK="$(db_query "SELECT account_id FROM accounts WHERE account_type='LOAN_BOOK' AND currency_id=1;")"

run_cobol "LOAN_APPLY|${U}|1000.00|USD|12|5.0|${A}" >/dev/null
APP="$(db_query "SELECT id FROM loan_application WHERE customer_email='${U}' ORDER BY id DESC LIMIT 1;")"
run_cobol "LOAN_APPROVE|${APP}|5.0|ok|||${A}" >/dev/null
assert_match "keyed disburse ok" "$(run_cobol "LOAN_DISBURSE|${APP}||||K-LP1|${A}")" "SUCCESS\|LOAN_DISBURSE"
assert_match "keyed disburse replay ok" "$(run_cobol "LOAN_DISBURSE|${APP}||||K-LP1|${A}")" "SUCCESS\|LOAN_DISBURSE"
assert_match "mirror disburse recorded DONE" "$(db_query "SELECT CONCAT(status, '|', amount) FROM idempotency_request WHERE scope='LOAN_DISBURSE' AND entity_ref='${APP}' AND idem_key='K-LP1';")" "^DONE|1000.0000$"
assert_match "double disburse refused" "$(run_cobol "LOAN_DISBURSE|${APP}|||||${A}")" "ERROR\|INVALID_STATUS"
assert_match "disburse links gl" "$(db_query "SELECT gl_journal_id FROM loan_application WHERE id=${APP};")" "^[0-9]+$"

assert_match "keyed repay ok" "$(run_cobol "LOAN_REPAY|${APP}|200.00|||K-LP2|${A}")" "SUCCESS\|LOAN_REPAY"
assert_match "keyed repay replay ok" "$(run_cobol "LOAN_REPAY|${APP}|200.00|||K-LP2|${A}")" "SUCCESS\|LOAN_REPAY"
assert_match "changed amount conflicts" "$(run_cobol "LOAN_REPAY|${APP}|100.00|||K-LP2|${A}")" "ERROR\|IDEMPOTENCY_CONFLICT"
assert_match "mirror repay recorded DONE" "$(db_query "SELECT CONCAT(status, '|', amount) FROM idempotency_request WHERE scope='LOAN_REPAY' AND entity_ref='${APP}' AND idem_key='K-LP2';")" "^DONE|200.0000$"
assert_match "overpay refused" "$(run_cobol "LOAN_REPAY|${APP}|99999.00||||${A}")" "ERROR\|OVERPAID"
assert_match "repay unknown refused" "$(run_cobol "LOAN_REPAY|999999|10.00||||${A}")" "ERROR\|NOT_FOUND"

# Frozen book fails the disburse closed; the key stays usable after the
# cleanup ran (CLEANUP=1 deleted the PENDING row).
run_cobol "LOAN_APPLY|${U}|500.00|USD|12|5.0|${A}" >/dev/null
APP2="$(db_query "SELECT id FROM loan_application WHERE customer_email='${U}' AND status='PENDING' ORDER BY id DESC LIMIT 1;")"
run_cobol "LOAN_APPROVE|${APP2}|5.0|ok|||${A}" >/dev/null
db_exec "UPDATE accounts SET status='FROZEN' WHERE account_id=${BOOK};"
assert_match "frozen book refuses disburse" "$(run_cobol "LOAN_DISBURSE|${APP2}||||K-LP3|${A}")" "ERROR\|LOAN_BOOK_MISSING"
db_exec "UPDATE accounts SET status='ACTIVE' WHERE account_id=${BOOK};"
assert_match "key reusable after cleanup" "$(run_cobol "LOAN_DISBURSE|${APP2}||||K-LP3|${A}")" "SUCCESS\|LOAN_DISBURSE"

db_exec "DELETE FROM loan_repay_request WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email IN ('${U}'));"
db_exec "DELETE FROM loan_disburse_request WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email IN ('${U}'));"
db_exec "DELETE FROM loan_repayment WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email IN ('${U}'));"
db_exec "DELETE FROM loan_application WHERE customer_email IN ('${U}');"
db_exec "DELETE FROM ledger WHERE txn_ref LIKE 'LOAN-%' OR txn_ref LIKE 'LOANRP-%';"
db_exec "DELETE FROM journal_entries WHERE txn_ref LIKE 'LOAN%';"
db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'LOAN\\_%');"
db_exec "DELETE FROM gl_journal WHERE description LIKE 'LOAN\\_%';"
db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U}','${B}'));"
db_exec "DELETE FROM users WHERE email IN ('${U}','${B}');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
