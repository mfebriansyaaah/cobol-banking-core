#!/usr/bin/env bash
# Lending Fase 1: real posting (toward lending 10/10). LOAN_DISBURSE moves
# money (LOAN_BOOK debit / customer credit) plus a balanced GL journal and
# links both; LOAN_REPAY collects (customer debit / LOAN_BOOK credit),
# marks rows PAID and links both; DEP_SETTLE pays out (DEPOSIT_POOL debit /
# customer credit) plus a balanced GL journal and links both. Rejected
# paths post nothing; concurrent double-settle/disburse is refused by
# atomic guards. Green twice required.
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
WA="lnpA@test.com"
WB="lnpB@test.com"
CUR="$(date +%Y-%m)"
run_cobol "GL_PERIOD_OPEN|${CUR}|||||${A}" >/dev/null

cleanup_fixture() {
    db_exec "DELETE FROM loan_repayment WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM loan_application WHERE customer_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM deposit_transaction WHERE deposit_id IN (SELECT id FROM deposit_account WHERE customer_email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM deposit_accrual WHERE deposit_id IN (SELECT id FROM deposit_account WHERE customer_email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM deposit_account WHERE customer_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM ledger WHERE txn_ref LIKE 'LOAN-%' OR txn_ref LIKE 'LOANRP-%' OR txn_ref LIKE 'DEP-%';"
    db_exec "DELETE FROM journal_entries WHERE txn_ref LIKE 'LOAN%' OR txn_ref LIKE 'DEP-%' OR txn_ref LIKE 'LOANRP-%';"
    db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'LOAN_DISBURSE:%' OR description LIKE 'LOAN_REPAY:%' OR description LIKE 'DEP_SETTLE:%');"
    db_exec "DELETE FROM gl_journal WHERE description LIKE 'LOAN_DISBURSE:%' OR description LIKE 'LOAN_REPAY:%' OR description LIKE 'DEP_SETTLE:%';"
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}','lnpLB@test.com','lnpPB@test.com')));"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}','lnpLB@test.com','lnpPB@test.com'));"
    db_exec "DELETE FROM users WHERE email IN ('${WA}','${WB}','lnpLB@test.com','lnpPB@test.com');"
}
cleanup_fixture
for U in "$WA" "$WB" lnpLB@test.com lnpPB@test.com; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Lnp T|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
done
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email IN ('${WA}','${WB}');"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'LOAN_BOOK', 100000.00 FROM users WHERE email='lnpLB@test.com';"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'DEPOSIT_POOL', 100000.00 FROM users WHERE email='lnpPB@test.com';"
ACCTA="$(db_query "SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${WA}') AND currency_id=1;")"
ACCTB="$(db_query "SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${WB}') AND currency_id=1;")"
BOOK="$(db_query "SELECT account_id FROM accounts WHERE account_type='LOAN_BOOK' AND currency_id=1;")"
POOL="$(db_query "SELECT account_id FROM accounts WHERE account_type='DEPOSIT_POOL' AND currency_id=1;")"
bal() { db_query "SELECT balance FROM accounts WHERE account_id=$1;"; }
net() { db_query "SELECT COALESCE(SUM(CASE WHEN type='CREDIT' THEN amount ELSE -amount END),0) FROM ledger WHERE account_id=$1;"; }
total() { db_query "SELECT COALESCE(SUM(balance),0) FROM accounts WHERE account_id IN (${ACCTA},${ACCTB},${BOOK},${POOL});"; }
balanced() { db_query "SELECT COUNT(*) FROM (SELECT l.journal_id FROM ledger l WHERE l.journal_id IS NOT NULL AND EXISTS (SELECT 1 FROM ledger x WHERE x.journal_id = l.journal_id AND x.account_id IN (${ACCTA},${ACCTB},${BOOK},${POOL})) GROUP BY l.journal_id HAVING ABS(SUM(CASE WHEN l.type='DEBIT' THEN l.amount ELSE -l.amount END)) > 0.0001) t;"; }

# 1-9. Disburse posts money + GL and links both; double disburse refused.
run_cobol "LOAN_APPLY|${WA}|1000.00|USD|12|5.0|${A}" >/dev/null
APP="$(db_query "SELECT id FROM loan_application WHERE customer_email='${WA}' ORDER BY id DESC LIMIT 1;")"
run_cobol "LOAN_APPROVE|${APP}|5.0|ok|||${A}" >/dev/null
assert_match "disburse ok" "$(run_cobol "LOAN_DISBURSE|${APP}|||||${A}")" "SUCCESS\|LOAN_DISBURSE"
assert_match "disbursed" "$(db_query "SELECT status FROM loan_application WHERE id=${APP};")" "^DISBURSED$"
assert_match "customer credited" "$(bal "$ACCTA")" "^2000.0000$"
assert_match "book debited" "$(bal "$BOOK")" "^99000.0000$"
assert_match "two legs posted" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='LOAN-${APP}';")" "^2$"
assert_match "debit book credit customer" "$(db_query "SELECT GROUP_CONCAT(CONCAT(account_id,':',type) ORDER BY type DESC) FROM ledger WHERE txn_ref='LOAN-${APP}';")" "^${BOOK}:DEBIT,${ACCTA}:CREDIT$"
assert_match "application links journal" "$(db_query "SELECT journal_id FROM loan_application WHERE id=${APP};")" "^[0-9]+$"
assert_match "application links gl" "$(db_query "SELECT gl_journal_id FROM loan_application WHERE id=${APP};")" "^[0-9]+$"
assert_match "double disburse refused" "$(run_cobol "LOAN_DISBURSE|${APP}|||||${A}")" "ERROR\|INVALID_STATUS"

# 10-16. Repay posts money + GL, marks PAID with linkage.
assert_match "repay on open refused" "$(run_cobol "LOAN_APPLY|${WB}|500.00|USD|12|5.0|${A}" >/dev/null; APP2=$(db_query "SELECT id FROM loan_application WHERE customer_email='${WB}' ORDER BY id DESC LIMIT 1;"); run_cobol "LOAN_REPAY|${APP2}|100.00||||${A}")" "ERROR\|INVALID_STATUS"
assert_match "no legs for refused repay" "$(db_query "SELECT COUNT(*) FROM ledger WHERE from_email='${WB}' AND description LIKE 'LOAN_REPAY%';")" "^0$"
assert_match "repay ok" "$(run_cobol "LOAN_REPAY|${APP}|200.00||||${A}")" "SUCCESS\|LOAN_REPAY"
RID="$(db_query "SELECT id FROM loan_repayment WHERE loan_id=${APP} AND status='PAID' ORDER BY id DESC LIMIT 1;")"
assert_match "repayment paid" "$(db_query "SELECT COUNT(*) FROM loan_repayment WHERE id=${RID} AND status='PAID';")" "^1$"
assert_match "customer debited" "$(bal "$ACCTA")" "^1800.0000$"
assert_match "book credited" "$(bal "$BOOK")" "^99200.0000$"
assert_match "repay links journal" "$(db_query "SELECT COUNT(DISTINCT journal_id) FROM loan_repayment WHERE loan_id=${APP} AND status='PAID';")" "^1$"

# 17-20. Over-repay fails closed; missing book fails closed.
assert_match "over-repay refused" "$(run_cobol "LOAN_REPAY|${APP}|99999.00||||${A}")" "ERROR\|INSUFFICIENT_FUNDS"
assert_match "failed repay left pending row" "$(db_query "SELECT COUNT(*) FROM loan_repayment WHERE loan_id=${APP} AND status='PENDING';")" "^1$"
assert_match "failed repay posted nothing" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref LIKE 'LOANRP-%' AND account_id=${ACCTA} AND amount=99999.0000;")" "^0$"
db_exec "UPDATE accounts SET status='FROZEN' WHERE account_id=${BOOK};"
run_cobol "LOAN_APPLY|${WB}|100.00|USD|12|5.0|${A}" >/dev/null
APP3="$(db_query "SELECT id FROM loan_application WHERE customer_email='${WB}' AND status='PENDING' ORDER BY id DESC LIMIT 1;")"
run_cobol "LOAN_APPROVE|${APP3}|5.0|ok|||${A}" >/dev/null
assert_match "pool missing fails closed" "$(run_cobol "LOAN_DISBURSE|${APP3}|||||${A}")" "ERROR\|LOAN_BOOK_MISSING"
db_exec "UPDATE accounts SET status='ACTIVE' WHERE account_id=${BOOK};"
db_exec "DELETE FROM loan_repayment WHERE loan_id=${APP3}; DELETE FROM loan_application WHERE id=${APP3};"

# 21-28. Deposit settle pays out principal + interest with linkage.
run_cobol "DEP_OPEN|${WB}|2000.00|USD|12|5.00|${A}" >/dev/null
DID="$(db_query "SELECT id FROM deposit_account WHERE customer_email='${WB}' ORDER BY id DESC LIMIT 1;")"
run_cobol "DEP_ACCRUE|${DID}|30||||${A}" >/dev/null
run_cobol "DEP_POST|${DID}|||||${A}" >/dev/null
assert_match "settle ok" "$(run_cobol "DEP_SETTLE|${DID}|||||${A}")" "SUCCESS\|DEP_SETTLE\|2008.2192"
assert_match "deposit closed" "$(db_query "SELECT status FROM deposit_account WHERE id=${DID};")" "^CLOSED$"
assert_match "customer paid out" "$(bal "$ACCTB")" "^3008.2192$"
assert_match "pool debited" "$(bal "$POOL")" "^97991.7808$"
assert_match "two payout legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${DID}';")" "^2$"
assert_match "deposit links journal" "$(db_query "SELECT journal_id FROM deposit_account WHERE id=${DID};")" "^[0-9]+$"
assert_match "deposit links gl" "$(db_query "SELECT gl_journal_id FROM deposit_account WHERE id=${DID};")" "^[0-9]+$"
assert_match "double settle refused" "$(run_cobol "DEP_SETTLE|${DID}|||||${A}")" "ERROR\|INVALID_STATUS"

# 29-34. Conservation: every unit accounted, journals balanced.
assert_match "A final" "$(bal "$ACCTA")" "^1800.0000$"
assert_match "B final" "$(bal "$ACCTB")" "^3008.2192$"
assert_match "A ledger net equals delta" "$(net "$ACCTA")" "^800.0000$"
assert_match "B ledger net equals delta" "$(net "$ACCTB")" "^2008.2192$"
assert_match "book net equals funding minus lending" "$(net "$BOOK")" "^-800.0000$"
assert_match "all journals balanced" "$(balanced)" "^0$"
assert_match "no negatives" "$(db_query "SELECT COUNT(*) FROM accounts WHERE account_id IN (${ACCTA},${ACCTB},${BOOK},${POOL}) AND balance < 0;")" "^0$"
assert_match "total conserved" "$(total)" "^202000.0000$"

# 35-38. Concurrent double disburse: exactly one wins, no double credit.
run_cobol "LOAN_APPLY|${WB}|300.00|USD|12|5.0|${A}" >/dev/null
APP4="$(db_query "SELECT id FROM loan_application WHERE customer_email='${WB}' AND status='PENDING' ORDER BY id DESC LIMIT 1;")"
run_cobol "LOAN_APPROVE|${APP4}|5.0|ok|||${A}" >/dev/null
D1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; D2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'LOAN_DISBURSE|%s|||||admin@test.com\n' "$APP4" >"$D1/input.txt"
printf 'LOAN_DISBURSE|%s|||||admin@test.com\n' "$APP4" >"$D2/input.txt"
BIN="$PWD/cobol/bin/main_logic"
(cd "$D1" && timeout 30s "$BIN" >/dev/null 2>&1) &
P1=$!
(cd "$D2" && timeout 30s "$BIN" >/dev/null 2>&1) &
P2=$!
wait $P1; wait $P2
DA="$(tr -d ' \n' <"$D1/output.txt")"; DB="$(tr -d ' \n' <"$D2/output.txt")"
rm -rf "$D1" "$D2"
assert_match "exactly one disburse wins" "$(printf '%s\n%s\n' "$DA" "$DB" | grep -c "SUCCESS|LOAN_DISBURSE")" "^1$"
assert_match "loser refused" "$(printf '%s\n%s\n' "$DA" "$DB")" "ERROR\|INVALID_STATUS"
assert_match "single credit only" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='LOAN-${APP4}';")" "^2$"
assert_match "no negatives after race" "$(db_query "SELECT COUNT(*) FROM accounts WHERE account_id IN (${ACCTA},${ACCTB},${BOOK},${POOL}) AND balance < 0;")" "^0$"

cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
