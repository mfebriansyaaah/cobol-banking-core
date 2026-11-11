#!/usr/bin/env bash
# Lending Fase 1+2: real posting (toward lending 10/10). LOAN_DISBURSE moves
# money (LOAN_BOOK debit / customer credit) plus a balanced GL journal and
# links both; LOAN_REPAY collects (customer debit / LOAN_BOOK credit),
# marks rows PAID and links both. Fase 2: DEP_OPEN funds first (customer
# debit / DEPOSIT_POOL credit) plus GL linkage; DEP_SETTLE pays out
# (DEPOSIT_POOL debit / customer credit) plus a balanced GL journal and
# links both. Rejected paths post nothing; concurrent
# double-settle/disburse is refused by atomic guards. Green twice required.
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
    db_exec "DELETE FROM loan_disburse_request WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM loan_repay_request WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM deposit_settle_request WHERE deposit_id IN (SELECT id FROM deposit_account WHERE customer_email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM loan_repayment WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM loan_application WHERE customer_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM deposit_transaction WHERE deposit_id IN (SELECT id FROM deposit_account WHERE customer_email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM deposit_accrual WHERE deposit_id IN (SELECT id FROM deposit_account WHERE customer_email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM deposit_account WHERE customer_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM ledger WHERE txn_ref LIKE 'LOAN-%' OR txn_ref LIKE 'LOANRP-%' OR txn_ref LIKE 'DEP-%';"
    db_exec "DELETE FROM journal_entries WHERE txn_ref LIKE 'LOAN%' OR txn_ref LIKE 'DEP-%' OR txn_ref LIKE 'LOANRP-%';"
    db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'LOAN_DISBURSE:%' OR description LIKE 'LOAN_REPAY:%' OR description LIKE 'DEP_SETTLE:%' OR description LIKE 'DEP_OPEN:%' OR description LIKE 'DEP_CLOSE:%' OR description LIKE 'DEP_POST:%');"
    db_exec "DELETE FROM gl_journal WHERE description LIKE 'LOAN_DISBURSE:%' OR description LIKE 'LOAN_REPAY:%' OR description LIKE 'DEP_SETTLE:%' OR description LIKE 'DEP_OPEN:%' OR description LIKE 'DEP_CLOSE:%' OR description LIKE 'DEP_POST:%';"
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
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${WA}';"
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 3000.00 FROM users WHERE email='${WB}';"
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

# 21-23. Opening into a frozen pool fails closed with nothing written.
db_exec "UPDATE accounts SET status='FROZEN' WHERE account_id=${POOL};"
assert_match "open into frozen pool refused" "$(run_cobol "DEP_OPEN|${WA}|100.00|USD|12|5.00|${A}")" "ERROR\|DEPOSIT_POOL_MISSING"
assert_match "failed open wrote no row" "$(db_query "SELECT COUNT(*) FROM deposit_account WHERE customer_email='${WA}';")" "^0$"
db_exec "UPDATE accounts SET status='ACTIVE' WHERE account_id=${POOL};"

# 24-33. Deposit open funds first (wallet debit / pool credit), then settle
# pays out principal + interest with linkage.
open_out="$(run_cobol "DEP_OPEN|${WB}|2000.00|USD|12|5.00|${A}")"
assert_match "open ok" "$open_out" "SUCCESS\|DEP_OPEN\|[0-9]+"
DID="$(db_query "SELECT id FROM deposit_account WHERE customer_email='${WB}' ORDER BY id DESC LIMIT 1;")"
assert_match "deposit active after funding" "$(db_query "SELECT status FROM deposit_account WHERE id=${DID};")" "^ACTIVE$"
assert_match "wallet debited by principal" "$(bal "$ACCTB")" "^1000.0000$"
assert_match "pool credited by principal" "$(bal "$POOL")" "^102000.0000$"
assert_match "two funding legs posted" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${DID}-FUND';")" "^2$"
assert_match "deposit links fund journal" "$(db_query "SELECT fund_journal_id FROM deposit_account WHERE id=${DID};")" "^[0-9]+$"
assert_match "deposit links fund gl" "$(db_query "SELECT fund_gl_journal_id FROM deposit_account WHERE id=${DID};")" "^[0-9]+$"
assert_match "funding transaction recorded" "$(db_query "SELECT COUNT(*) FROM deposit_transaction WHERE deposit_id=${DID} AND txn_type='PRINCIPAL_FUNDED';")" "^1$"
run_cobol "DEP_ACCRUE|${DID}|30||||${A}" >/dev/null
run_cobol "DEP_POST|${DID}|||||${A}" >/dev/null
assert_match "settle ok" "$(run_cobol "DEP_SETTLE|${DID}|||||${A}")" "SUCCESS\|DEP_SETTLE\|2008.2192"
assert_match "deposit closed" "$(db_query "SELECT status FROM deposit_account WHERE id=${DID};")" "^CLOSED$"
assert_match "customer paid out" "$(bal "$ACCTB")" "^3008.2192$"
assert_match "pool debited" "$(bal "$POOL")" "^99991.7808$"
assert_match "two payout legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${DID}';")" "^2$"
assert_match "deposit links journal" "$(db_query "SELECT journal_id FROM deposit_account WHERE id=${DID};")" "^[0-9]+$"
assert_match "deposit links gl" "$(db_query "SELECT gl_journal_id FROM deposit_account WHERE id=${DID};")" "^[0-9]+$"
assert_match "deposit links post gl" "$(db_query "SELECT post_gl_journal_id FROM deposit_account WHERE id=${DID};")" "^[0-9]+$"
assert_match "post gl balanced" "$(db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM gl_journal_line WHERE journal_id=(SELECT post_gl_journal_id FROM deposit_account WHERE id=${DID}) GROUP BY journal_id HAVING ABS(SUM(debit_amount - credit_amount)) > 0.0001) t;")" "^0$"
assert_match "post books expense" "$(db_query "SELECT COUNT(*) FROM gl_journal_line WHERE journal_id=(SELECT post_gl_journal_id FROM deposit_account WHERE id=${DID}) AND gl_account_code='5010';")" "^1$"
assert_match "double settle refused" "$(run_cobol "DEP_SETTLE|${DID}|||||${A}")" "ERROR\|INVALID_STATUS"

# 34-39. Conservation: the principal round-trips, only interest leaves
# the pool; every unit accounted, journals balanced.
assert_match "A final" "$(bal "$ACCTA")" "^1800.0000$"
assert_match "B final" "$(bal "$ACCTB")" "^3008.2192$"
assert_match "A ledger net equals delta" "$(net "$ACCTA")" "^800.0000$"
assert_match "B ledger net equals interest only" "$(net "$ACCTB")" "^8.2192$"
assert_match "book net equals funding minus lending" "$(net "$BOOK")" "^-800.0000$"
assert_match "pool net equals interest paid" "$(net "$POOL")" "^-8.2192$"
assert_match "all journals balanced" "$(balanced)" "^0$"
assert_match "no negatives" "$(db_query "SELECT COUNT(*) FROM accounts WHERE account_id IN (${ACCTA},${ACCTB},${BOOK},${POOL}) AND balance < 0;")" "^0$"
assert_match "total conserved" "$(total)" "^204000.0000$"

# 40-43. Concurrent double disburse: exactly one wins, no double credit.
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

# 44-58. Keyed repay: the same key replays the stored outcome instead of
# posting again; a different amount conflicts; concurrent keys serialize
# with one winner; doomed keys stay usable; stale keys are taken over.
assert_match "keyed repay ok" "$(run_cobol "LOAN_REPAY|${APP}|150.00|||K-LR1|${A}")" "SUCCESS\|LOAN_REPAY"
assert_match "keyed replay ok" "$(run_cobol "LOAN_REPAY|${APP}|150.00|||K-LR1|${A}")" "SUCCESS\|LOAN_REPAY"
assert_match "replay posted once" "$(db_query "SELECT COUNT(*) FROM loan_repayment WHERE loan_id=${APP} AND amount=150.00 AND status='PAID';")" "^1$"
assert_match "request recorded DONE" "$(db_query "SELECT status FROM loan_repay_request WHERE loan_id=${APP} AND idempotency_key='K-LR1';")" "^DONE$"
assert_match "different amount conflicts" "$(run_cobol "LOAN_REPAY|${APP}|160.00|||K-LR1|${A}")" "ERROR\|IDEMPOTENCY_CONFLICT"
assert_match "conflict posted nothing" "$(db_query "SELECT COUNT(*) FROM loan_repayment WHERE loan_id=${APP} AND amount=160.00;")" "^0$"
R1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; R2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'LOAN_REPAY|%s|140.00|||K-LRACE|admin@test.com\n' "$APP" >"$R1/input.txt"
printf 'LOAN_REPAY|%s|140.00|||K-LRACE|admin@test.com\n' "$APP" >"$R2/input.txt"
(cd "$R1" && timeout 30s "$BIN" >/dev/null 2>&1) &
Q1=$!
(cd "$R2" && timeout 30s "$BIN" >/dev/null 2>&1) &
Q2=$!
wait $Q1; wait $Q2
KA="$(tr -d ' \n' <"$R1/output.txt")"; KB="$(tr -d ' \n' <"$R2/output.txt")"
rm -rf "$R1" "$R2"
assert_match "exactly one keyed winner" "$(printf '%s\n%s\n' "$KA" "$KB" | grep -c "SUCCESS|LOAN_REPAY")" "^1$"
assert_match "loser sees in-progress" "$(printf '%s\n%s\n' "$KA" "$KB")" "ERROR\|REPAY_IN_PROGRESS"
assert_match "retry converges" "$(run_cobol "LOAN_REPAY|${APP}|140.00|||K-LRACE|${A}")" "SUCCESS\|LOAN_REPAY"
assert_match "single repayment for key" "$(db_query "SELECT COUNT(*) FROM loan_repayment WHERE loan_id=${APP} AND amount=140.00 AND status='PAID';")" "^1$"
run_cobol "LOAN_APPLY|${WB}|100.00|USD|12|5.0|${A}" >/dev/null
APP5="$(db_query "SELECT id FROM loan_application WHERE customer_email='${WB}' AND status='PENDING' ORDER BY id DESC LIMIT 1;")"
assert_match "keyed repay on open refused" "$(run_cobol "LOAN_REPAY|${APP5}|10.00|||K-DOOM|${A}")" "ERROR\|INVALID_STATUS"
assert_match "doomed key not blocked" "$(run_cobol "LOAN_REPAY|${APP5}|10.00|||K-DOOM|${A}")" "ERROR\|INVALID_STATUS"
assert_match "no request residue" "$(db_query "SELECT COUNT(*) FROM loan_repay_request WHERE loan_id=${APP5};")" "^0$"
db_exec "DELETE FROM loan_application WHERE id=${APP5};"
db_exec "INSERT INTO loan_repay_request (loan_id, idempotency_key, amount, status, created_at, updated_at) VALUES (${APP},'K-TAKE',130.00,'PENDING',DATE_SUB(NOW(),INTERVAL 10 MINUTE),DATE_SUB(NOW(),INTERVAL 10 MINUTE));"
assert_match "takeover succeeds" "$(run_cobol "LOAN_REPAY|${APP}|130.00|||K-TAKE|${A}")" "SUCCESS\|LOAN_REPAY"
assert_match "taken over and done" "$(db_query "SELECT status FROM loan_repay_request WHERE loan_id=${APP} AND idempotency_key='K-TAKE';")" "^DONE$"

# 59-72. Keyed settle: replay, race, doomed key, takeover, conflict guard.
run_cobol "DEP_OPEN|${WB}|1000.00|USD|12|5.00|${A}" >/dev/null
DID2="$(db_query "SELECT id FROM deposit_account WHERE customer_email='${WB}' ORDER BY id DESC LIMIT 1;")"
run_cobol "DEP_ACCRUE|${DID2}|30||||${A}" >/dev/null
run_cobol "DEP_POST|${DID2}|||||${A}" >/dev/null
assert_match "keyed settle ok" "$(run_cobol "DEP_SETTLE|${DID2}||||K-DS1|${A}")" "SUCCESS\|DEP_SETTLE\|1004.1096"
assert_match "keyed replay ok" "$(run_cobol "DEP_SETTLE|${DID2}||||K-DS1|${A}")" "SUCCESS\|DEP_SETTLE\|1004.1096"
assert_match "single payout journal" "$(db_query "SELECT COUNT(*) FROM gl_journal WHERE description LIKE 'DEP_SETTLE:${DID2}:%';")" "^1$"
assert_match "deposit links post gl" "$(db_query "SELECT post_gl_journal_id FROM deposit_account WHERE id=${DID2};")" "^[0-9]+$"
assert_match "post gl balanced" "$(db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM gl_journal_line WHERE journal_id=(SELECT post_gl_journal_id FROM deposit_account WHERE id=${DID2}) GROUP BY journal_id HAVING ABS(SUM(debit_amount - credit_amount)) > 0.0001) t;")" "^0$"
assert_match "post books expense" "$(db_query "SELECT COUNT(*) FROM gl_journal_line WHERE journal_id=(SELECT post_gl_journal_id FROM deposit_account WHERE id=${DID2}) AND gl_account_code='5010';")" "^1$"
assert_match "request recorded DONE" "$(db_query "SELECT status FROM deposit_settle_request WHERE deposit_id=${DID2} AND idempotency_key='K-DS1';")" "^DONE$"
db_exec "UPDATE deposit_settle_request SET amount = 1.00 WHERE deposit_id=${DID2} AND idempotency_key='K-DS1';"
assert_match "changed amount conflicts" "$(run_cobol "DEP_SETTLE|${DID2}||||K-DS1|${A}")" "ERROR\|IDEMPOTENCY_CONFLICT"
assert_match "conflict paid nothing new" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${DID2}';")" "^2$"
db_exec "UPDATE deposit_settle_request SET amount = 1004.1096 WHERE deposit_id=${DID2} AND idempotency_key='K-DS1';"
run_cobol "DEP_OPEN|${WB}|500.00|USD|12|5.00|${A}" >/dev/null
DID3="$(db_query "SELECT id FROM deposit_account WHERE customer_email='${WB}' ORDER BY id DESC LIMIT 1;")"
run_cobol "DEP_ACCRUE|${DID3}|30||||${A}" >/dev/null
run_cobol "DEP_POST|${DID3}|||||${A}" >/dev/null
S1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; S2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'DEP_SETTLE|%s||||K-DSRACE|admin@test.com\n' "$DID3" >"$S1/input.txt"
printf 'DEP_SETTLE|%s||||K-DSRACE|admin@test.com\n' "$DID3" >"$S2/input.txt"
(cd "$S1" && timeout 30s "$BIN" >/dev/null 2>&1) &
T1=$!
(cd "$S2" && timeout 30s "$BIN" >/dev/null 2>&1) &
T2=$!
wait $T1; wait $T2
SA="$(tr -d ' \n' <"$S1/output.txt")"; SB="$(tr -d ' \n' <"$S2/output.txt")"
rm -rf "$S1" "$S2"
assert_match "exactly one settle winner" "$(printf '%s\n%s\n' "$SA" "$SB" | grep -c "SUCCESS|DEP_SETTLE")" "^1$"
assert_match "settle loser sees in-progress" "$(printf '%s\n%s\n' "$SA" "$SB")" "ERROR\|SETTLE_IN_PROGRESS"
assert_match "settle retry converges" "$(run_cobol "DEP_SETTLE|${DID3}||||K-DSRACE|${A}")" "SUCCESS\|DEP_SETTLE\|502.0548"
assert_match "single payout for key" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${DID3}';")" "^2$"
assert_match "keyed settle on closed refused" "$(run_cobol "DEP_SETTLE|${DID}||||K-DOOM|${A}")" "ERROR\|INVALID_STATUS"
assert_match "settle doomed key not blocked" "$(run_cobol "DEP_SETTLE|${DID}||||K-DOOM|${A}")" "ERROR\|INVALID_STATUS"
assert_match "no settle request residue" "$(db_query "SELECT COUNT(*) FROM deposit_settle_request WHERE deposit_id=${DID};")" "^0$"
run_cobol "DEP_OPEN|${WA}|400.00|USD|12|5.00|${A}" >/dev/null
DID4="$(db_query "SELECT id FROM deposit_account WHERE customer_email='${WA}' ORDER BY id DESC LIMIT 1;")"
run_cobol "DEP_ACCRUE|${DID4}|30||||${A}" >/dev/null
run_cobol "DEP_POST|${DID4}|||||${A}" >/dev/null
db_exec "INSERT INTO deposit_settle_request (deposit_id, idempotency_key, amount, status, created_at, updated_at) VALUES (${DID4},'K-TAKE2',401.6438,'PENDING',DATE_SUB(NOW(),INTERVAL 10 MINUTE),DATE_SUB(NOW(),INTERVAL 10 MINUTE));"
assert_match "settle takeover succeeds" "$(run_cobol "DEP_SETTLE|${DID4}||||K-TAKE2|${A}")" "SUCCESS\|DEP_SETTLE\|401.6438"
assert_match "settle taken over and done" "$(db_query "SELECT status FROM deposit_settle_request WHERE deposit_id=${DID4} AND idempotency_key='K-TAKE2';")" "^DONE$"

# 73-90. Close refunds the funded principal (posted interest forfeited);
# unfunded PENDING closes money-neutral; the refund is keyed.
run_cobol "DEP_OPEN|${WB}|400.00|USD|12|5.00|${A}" >/dev/null
DID5="$(db_query "SELECT id FROM deposit_account WHERE customer_email='${WB}' ORDER BY id DESC LIMIT 1;")"
run_cobol "DEP_ACCRUE|${DID5}|30||||${A}" >/dev/null
run_cobol "DEP_POST|${DID5}|||||${A}" >/dev/null
assert_match "keyed close ok" "$(run_cobol "DEP_CLOSE|${DID5}||||K-DC1|${A}")" "SUCCESS\|DEP_CLOSED\|400.0000"
assert_match "closed after refund" "$(db_query "SELECT status FROM deposit_account WHERE id=${DID5};")" "^CLOSED$"
assert_match "principal refunded, interest forfeited" "$(bal "$ACCTB")" "^3314.3836$"
assert_match "two refund legs posted" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${DID5}-REFUND';")" "^2$"
assert_match "close links journal" "$(db_query "SELECT journal_id FROM deposit_account WHERE id=${DID5};")" "^[0-9]+$"
assert_match "close links gl" "$(db_query "SELECT gl_journal_id FROM deposit_account WHERE id=${DID5};")" "^[0-9]+$"
assert_match "refund transaction recorded" "$(db_query "SELECT COUNT(*) FROM deposit_transaction WHERE deposit_id=${DID5} AND txn_type='PRINCIPAL_REFUNDED';")" "^1$"
assert_match "refund gl balanced" "$(db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM gl_journal_line WHERE journal_id=(SELECT gl_journal_id FROM deposit_account WHERE id=${DID5}) GROUP BY journal_id HAVING ABS(SUM(debit_amount - credit_amount)) > 0.0001) t;")" "^0$"
assert_match "keyed close replay ok" "$(run_cobol "DEP_CLOSE|${DID5}||||K-DC1|${A}")" "SUCCESS\|DEP_CLOSED\|400.0000"
assert_match "replay refunded once" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${DID5}-REFUND';")" "^2$"
assert_match "close on closed refused" "$(run_cobol "DEP_CLOSE|${DID5}||||K-DC2|${A}")" "ERROR\|INVALID_STATUS"
assert_match "close request recorded once" "$(db_query "SELECT COUNT(*) FROM deposit_close_request WHERE deposit_id=${DID5};")" "^1$"
run_cobol "DEP_OPEN|${WB}|100.00|USD|12|5.00|${A}" >/dev/null
DID6="$(db_query "SELECT id FROM deposit_account WHERE customer_email='${WB}' ORDER BY id DESC LIMIT 1;")"
C1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; C2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'DEP_CLOSE|%s||||K-DCRACE|admin@test.com\n' "$DID6" >"$C1/input.txt"
printf 'DEP_CLOSE|%s||||K-DCRACE|admin@test.com\n' "$DID6" >"$C2/input.txt"
(cd "$C1" && timeout 30s "$BIN" >/dev/null 2>&1) &
U1=$!
(cd "$C2" && timeout 30s "$BIN" >/dev/null 2>&1) &
U2=$!
wait $U1; wait $U2
CA="$(tr -d ' \n' <"$C1/output.txt")"; CB="$(tr -d ' \n' <"$C2/output.txt")"
rm -rf "$C1" "$C2"
assert_match "exactly one close winner" "$(printf '%s\n%s\n' "$CA" "$CB" | grep -c "SUCCESS|DEP_CLOSED")" "^1$"
assert_match "close loser sees in-progress" "$(printf '%s\n%s\n' "$CA" "$CB")" "ERROR\|CLOSE_IN_PROGRESS"
assert_match "close retry converges" "$(run_cobol "DEP_CLOSE|${DID6}||||K-DCRACE|${A}")" "SUCCESS\|DEP_CLOSED\|100.0000"
assert_match "single refund for key" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${DID6}-REFUND';")" "^2$"
db_exec "INSERT INTO deposit_account (customer_email, principal, currency, term_months, interest_rate, created_by, status) VALUES ('${WB}', 250.00, 'USD', 12, 5.00, '${A}', 'PENDING');"
DID7="$(db_query "SELECT id FROM deposit_account WHERE customer_email='${WB}' AND status='PENDING' ORDER BY id DESC LIMIT 1;")"
BW0="$(bal "$ACCTB")"
assert_match "pending close ok" "$(run_cobol "DEP_CLOSE|${DID7}||||K-DC3|${A}")" "SUCCESS\|DEP_CLOSED\|0.0000"
assert_match "pending closed" "$(db_query "SELECT status FROM deposit_account WHERE id=${DID7};")" "^CLOSED$"
assert_match "pending close moves nothing" "$(bal "$ACCTB")" "^${BW0}$"
assert_match "pending close posts no legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref LIKE 'DEP-${DID7}%';")" "^0$"

# 91-107. Keyed disburse: the same key replays the stored outcome instead
# of posting again; concurrent keys serialize with one winner; doomed keys
# refuse pre-posting; stale keys are taken over.
run_cobol "LOAN_APPLY|${WB}|600.00|USD|12|5.0|${A}" >/dev/null
APP6="$(db_query "SELECT id FROM loan_application WHERE customer_email='${WB}' ORDER BY id DESC LIMIT 1;")"
run_cobol "LOAN_APPROVE|${APP6}|5.0|ok|||${A}" >/dev/null
assert_match "keyed disburse ok" "$(run_cobol "LOAN_DISBURSE|${APP6}||||K-D1|${A}")" "SUCCESS\|LOAN_DISBURSE"
assert_match "keyed disburse replay ok" "$(run_cobol "LOAN_DISBURSE|${APP6}||||K-D1|${A}")" "SUCCESS\|LOAN_DISBURSE"
assert_match "replay posted once" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='LOAN-${APP6}';")" "^2$"
assert_match "disburse request recorded DONE" "$(db_query "SELECT status FROM loan_disburse_request WHERE loan_id=${APP6} AND idempotency_key='K-D1';")" "^DONE$"
db_exec "UPDATE loan_disburse_request SET amount = 1.00 WHERE loan_id=${APP6} AND idempotency_key='K-D1';"
assert_match "changed amount conflicts" "$(run_cobol "LOAN_DISBURSE|${APP6}||||K-D1|${A}")" "ERROR\|IDEMPOTENCY_CONFLICT"
assert_match "conflict posted nothing new" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='LOAN-${APP6}';")" "^2$"
db_exec "UPDATE loan_disburse_request SET amount = 600.00 WHERE loan_id=${APP6} AND idempotency_key='K-D1';"
run_cobol "LOAN_APPLY|${WB}|700.00|USD|12|5.0|${A}" >/dev/null
APP7="$(db_query "SELECT id FROM loan_application WHERE customer_email='${WB}' AND status='PENDING' ORDER BY id DESC LIMIT 1;")"
run_cobol "LOAN_APPROVE|${APP7}|5.0|ok|||${A}" >/dev/null
E1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; E2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'LOAN_DISBURSE|%s||||K-DRACE|admin@test.com\n' "$APP7" >"$E1/input.txt"
printf 'LOAN_DISBURSE|%s||||K-DRACE|admin@test.com\n' "$APP7" >"$E2/input.txt"
(cd "$E1" && timeout 30s "$BIN" >/dev/null 2>&1) &
V1=$!
(cd "$E2" && timeout 30s "$BIN" >/dev/null 2>&1) &
V2=$!
wait $V1; wait $V2
EA="$(tr -d ' \n' <"$E1/output.txt")"; EB="$(tr -d ' \n' <"$E2/output.txt")"
rm -rf "$E1" "$E2"
assert_match "exactly one disburse winner" "$(printf '%s\n%s\n' "$EA" "$EB" | grep -c "SUCCESS|LOAN_DISBURSE")" "^1$"
assert_match "disburse loser sees in-progress" "$(printf '%s\n%s\n' "$EA" "$EB")" "ERROR\|DISBURSE_IN_PROGRESS"
assert_match "disburse retry converges" "$(run_cobol "LOAN_DISBURSE|${APP7}||||K-DRACE|${A}")" "SUCCESS\|LOAN_DISBURSE"
assert_match "single disbursal for key" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='LOAN-${APP7}';")" "^2$"
run_cobol "LOAN_APPLY|${WB}|100.00|USD|12|5.0|${A}" >/dev/null
APP8="$(db_query "SELECT id FROM loan_application WHERE customer_email='${WB}' AND status='PENDING' ORDER BY id DESC LIMIT 1;")"
assert_match "keyed disburse on open refused" "$(run_cobol "LOAN_DISBURSE|${APP8}||||K-DOOM|${A}")" "ERROR\|INVALID_STATUS"
assert_match "doomed disburse stays pending" "$(run_cobol "LOAN_DISBURSE|${APP8}||||K-DOOM|${A}")" "ERROR\|DISBURSE_IN_PROGRESS"
assert_match "doomed request left pending" "$(db_query "SELECT status FROM loan_disburse_request WHERE loan_id=${APP8};")" "^PENDING$"
db_exec "DELETE FROM loan_disburse_request WHERE loan_id=${APP8}; DELETE FROM loan_application WHERE id=${APP8};"
run_cobol "LOAN_APPLY|${WB}|800.00|USD|12|5.0|${A}" >/dev/null
APP9="$(db_query "SELECT id FROM loan_application WHERE customer_email='${WB}' AND status='PENDING' ORDER BY id DESC LIMIT 1;")"
run_cobol "LOAN_APPROVE|${APP9}|5.0|ok|||${A}" >/dev/null
db_exec "INSERT INTO loan_disburse_request (loan_id, idempotency_key, amount, status, created_at, updated_at) VALUES (${APP9},'K-TAKE3',800.00,'PENDING',DATE_SUB(NOW(),INTERVAL 10 MINUTE),DATE_SUB(NOW(),INTERVAL 10 MINUTE));"
assert_match "disburse takeover succeeds" "$(run_cobol "LOAN_DISBURSE|${APP9}||||K-TAKE3|${A}")" "SUCCESS\|LOAN_DISBURSE"
assert_match "disburse taken over and done" "$(db_query "SELECT status FROM loan_disburse_request WHERE loan_id=${APP9} AND idempotency_key='K-TAKE3';")" "^DONE$"

# 108-130. Keyed open (kontrak v2, P7): the same key replays the stored
# deposit instead of funding a second one; races serialize; doomed and
# stale keys behave; a linked stale row is adopted, never duplicated.
assert_match "keyed open ok" "$(run_cobol "DEP_OPEN|${WB}|900.00|USD|12|5.00|${A}|K-O1")" "SUCCESS\|DEP_OPEN\|[0-9]+"
DID8="$(db_query "SELECT id FROM deposit_account WHERE customer_email='${WB}' ORDER BY id DESC LIMIT 1;")"
assert_match "keyed open debits wallet" "$(bal "$ACCTB")" "^4514.3836$"
assert_match "keyed open replay ok" "$(run_cobol "DEP_OPEN|${WB}|900.00|USD|12|5.00|${A}|K-O1")" "SUCCESS\|DEP_OPEN\|${DID8}"
assert_match "replay funded once" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${DID8}-FUND';")" "^2$"
assert_match "open request recorded DONE" "$(db_query "SELECT status FROM deposit_open_request WHERE idempotency_key='K-O1';")" "^DONE$"
db_exec "UPDATE deposit_open_request SET principal = 1.00 WHERE idempotency_key='K-O1';"
assert_match "changed principal conflicts" "$(run_cobol "DEP_OPEN|${WB}|900.00|USD|12|5.00|${A}|K-O1")" "ERROR\|IDEMPOTENCY_CONFLICT"
assert_match "conflict opened nothing new" "$(db_query "SELECT COUNT(*) FROM deposit_account WHERE customer_email='${WB}' AND principal=900.00;")" "^1$"
db_exec "UPDATE deposit_open_request SET principal = 900.00 WHERE idempotency_key='K-O1';"
O1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; O2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'DEP_OPEN|%s|850.00|USD|12|5.00|admin@test.com|K-ORACE\n' "$WB" >"$O1/input.txt"
printf 'DEP_OPEN|%s|850.00|USD|12|5.00|admin@test.com|K-ORACE\n' "$WB" >"$O2/input.txt"
(cd "$O1" && timeout 30s "$BIN" >/dev/null 2>&1) &
W1=$!
(cd "$O2" && timeout 30s "$BIN" >/dev/null 2>&1) &
W2=$!
wait $W1; wait $W2
OA="$(tr -d ' \n' <"$O1/output.txt")"; OB="$(tr -d ' \n' <"$O2/output.txt")"
rm -rf "$O1" "$O2"
assert_match "exactly one open winner" "$(printf '%s\n%s\n' "$OA" "$OB" | grep -c "SUCCESS\|DEP_OPEN")" "^1$"
assert_match "open loser sees in-progress" "$(printf '%s\n%s\n' "$OA" "$OB")" "ERROR\|OPEN_IN_PROGRESS"
assert_match "open retry converges" "$(run_cobol "DEP_OPEN|${WB}|850.00|USD|12|5.00|${A}|K-ORACE")" "SUCCESS\|DEP_OPEN\|[0-9]+"
assert_match "single deposit for key" "$(db_query "SELECT COUNT(*) FROM deposit_account WHERE customer_email='${WB}' AND principal=850.00;")" "^1$"
run_cobol "REQUEST_SIGNUP|lnpNW@test.com|Passw0rd!|Lnp Nw|1990-01-01" >/dev/null
nwcode="$(db_query "SELECT code FROM verification_logs WHERE email='lnpNW@test.com' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|lnpNW@test.com|${nwcode}" >/dev/null
assert_match "keyed open without wallet refused" "$(run_cobol "DEP_OPEN|lnpNW@test.com|100.00|USD|12|5.00|${A}|K-DOOM")" "ERROR\|ACCOUNT_NOT_FOUND"
assert_match "doomed open key not blocked" "$(run_cobol "DEP_OPEN|lnpNW@test.com|100.00|USD|12|5.00|${A}|K-DOOM")" "ERROR\|ACCOUNT_NOT_FOUND"
assert_match "no open request residue" "$(db_query "SELECT COUNT(*) FROM deposit_open_request WHERE idempotency_key='K-DOOM';")" "^0$"
db_exec "DELETE FROM users WHERE email='lnpNW@test.com';"
db_exec "INSERT INTO deposit_open_request (idempotency_key, customer_email, principal, currency, term_months, interest_rate, status, created_at, updated_at) VALUES ('K-OTAKE','${WB}',700.00,'USD',12,'4.00','PENDING',DATE_SUB(NOW(),INTERVAL 10 MINUTE),DATE_SUB(NOW(),INTERVAL 10 MINUTE));"
assert_match "open takeover succeeds" "$(run_cobol "DEP_OPEN|${WB}|700.00|USD|12|4.00|${A}|K-OTAKE")" "SUCCESS\|DEP_OPEN\|[0-9]+"
DID9="$(db_query "SELECT id FROM deposit_account WHERE customer_email='${WB}' AND principal=700.00 ORDER BY id DESC LIMIT 1;")"
assert_match "takeover links the fresh deposit" "$(db_query "SELECT deposit_id FROM deposit_open_request WHERE idempotency_key='K-OTAKE';")" "^${DID9}$"
assert_match "takeover taken over and done" "$(db_query "SELECT status FROM deposit_open_request WHERE idempotency_key='K-OTAKE';")" "^DONE$"
db_exec "INSERT INTO deposit_account (customer_email, principal, currency, term_months, interest_rate, created_by, status) VALUES ('${WB}', 350.00, 'USD', 12, 5.00, '${A}', 'PENDING');"
ADP="$(db_query "SELECT id FROM deposit_account WHERE customer_email='${WB}' AND status='PENDING' ORDER BY id DESC LIMIT 1;")"
db_exec "INSERT INTO deposit_open_request (idempotency_key, customer_email, principal, currency, term_months, interest_rate, status, deposit_id, created_at, updated_at) VALUES ('K-OADOPT','${WB}',350.00,'USD',12,'5.00','PENDING',${ADP},DATE_SUB(NOW(),INTERVAL 10 MINUTE),DATE_SUB(NOW(),INTERVAL 10 MINUTE));"
assert_match "adopt funds the stored deposit" "$(run_cobol "DEP_OPEN|${WB}|350.00|USD|12|5.00|${A}|K-OADOPT")" "SUCCESS\|DEP_OPEN\|${ADP}"
assert_match "adopted deposit active" "$(db_query "SELECT status FROM deposit_account WHERE id=${ADP};")" "^ACTIVE$"
assert_match "adopted deposit funded once" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='DEP-${ADP}-FUND';")" "^2$"
assert_match "no duplicate deposit" "$(db_query "SELECT COUNT(*) FROM deposit_account WHERE customer_email='${WB}' AND principal=350.00;")" "^1$"

cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
