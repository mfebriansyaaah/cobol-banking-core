#!/usr/bin/env bash
# Payments Fase 1: real posting (toward payments 10/10). Clearing SETTLE must
# write a balanced GL journal (1200/2110) and link it; hold CAPTURE must move
# money (customer DEBIT / CLEARING-suspense CREDIT) inside the same
# transaction that flips the hold; PIC_EXECUTE must move money through
# wallet_core. Rejected paths post nothing. Green twice required.
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
WA="pstlA@test.com"
WB="pstlB@test.com"
C="CLR-PST-1"
CUR="$(date +%Y-%m)"
run_cobol "GL_PERIOD_OPEN|${CUR}|||||${A}" >/dev/null

cleanup_fixture() {
    db_exec "DELETE FROM ledger WHERE txn_ref LIKE 'PHL-%' OR txn_ref LIKE 'PI-PST-%';"
    db_exec "DELETE FROM journal_entries WHERE txn_ref LIKE 'PHL-%';"
    db_exec "DELETE FROM payment_hold WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')));"
    db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${WA}','${WB}') OR to_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM payment_instruction_run WHERE instruction_id IN (SELECT id FROM payment_instruction WHERE instruction_code LIKE 'PI-PST-%');"
    db_exec "DELETE FROM payment_instruction WHERE instruction_code LIKE 'PI-PST-%';"
    db_exec "DELETE FROM payment_clearing WHERE clearing_ref IN ('${C}','CLR-PST-2');"
    db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'PMC_SETTLE:CLR-PST-%');"
    db_exec "DELETE FROM gl_journal WHERE description LIKE 'PMC_SETTLE:CLR-PST-%';"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM users WHERE email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE account_type='CLEARING' AND currency_id=1);"
    db_exec "DELETE FROM accounts WHERE account_type='CLEARING' AND currency_id=1;"
}
cleanup_fixture
for U in "$WA" "$WB"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Pst Hold|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
    db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${U}';"
done
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'CLEARING', 0 FROM users WHERE email='${A}';"
ACCT="$(db_query "SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${WA}') AND currency_id=1;")"
CLR="$(db_query "SELECT account_id FROM accounts WHERE account_type='CLEARING' AND currency_id=1;")"
bal() { db_query "SELECT balance FROM accounts WHERE account_id=$1;"; }
total2() { db_query "SELECT COALESCE(SUM(balance),0) FROM accounts WHERE account_id IN (${ACCT},${CLR});"; }

# 1-11. Capture moves money: customer -100, suspense +100, two legs, linked.
assert_match "reserve ok" "$(run_cobol "PHL_RESERVE|${ACCT}|100.00|USD|||${A}")" "SUCCESS\|PHL_RESERVED"
HID="$(db_query "SELECT id FROM payment_hold WHERE account_id=${ACCT} ORDER BY id DESC LIMIT 1;")"
assert_match "capture ok" "$(run_cobol "PHL_CAPTURE|${HID}|||||${A}")" "SUCCESS\|PHL_CAPTURED"
assert_match "customer debited" "$(bal "$ACCT")" "^900.0000$"
assert_match "suspense credited" "$(bal "$CLR")" "^100.0000$"
assert_match "two legs posted" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='PHL-${HID}';")" "^2$"
assert_match "debit leg exact" "$(db_query "SELECT CONCAT(account_id,':',amount,':',type) FROM ledger WHERE txn_ref='PHL-${HID}' AND type='DEBIT';")" "^${ACCT}:100.0000:DEBIT$"
assert_match "credit leg exact" "$(db_query "SELECT CONCAT(account_id,':',amount,':',type) FROM ledger WHERE txn_ref='PHL-${HID}' AND type='CREDIT';")" "^${CLR}:100.0000:CREDIT$"
assert_match "legs share hold journal" "$(db_query "SELECT COUNT(DISTINCT journal_id) FROM ledger WHERE txn_ref='PHL-${HID}';")" "^1$"
assert_match "hold links journal" "$(db_query "SELECT journal_id FROM payment_hold WHERE id=${HID};")" "$(db_query "SELECT journal_id FROM ledger WHERE txn_ref='PHL-${HID}' LIMIT 1;")"
assert_match "capture journal balanced" "$(db_query "SELECT IF(SUM(CASE WHEN type='DEBIT' THEN amount ELSE -amount END)=0,'BALANCED','UNBALANCED') FROM ledger WHERE txn_ref='PHL-${HID}';")" "^BALANCED$"
assert_match "capture description keyed" "$(db_query "SELECT DISTINCT description FROM ledger WHERE txn_ref='PHL-${HID}';")" "^PHL_CAPTURE:${HID}:100.0000$"

# 12-14. Double capture refused, nothing moves twice.
assert_match "double capture refused" "$(run_cobol "PHL_CAPTURE|${HID}|||||${A}")" "ERROR\|INVALID_STATUS"
assert_match "no extra legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='PHL-${HID}';")" "^2$"
assert_match "balances frozen" "$(total2)" "^1000.0000$"

# 15-18. Overdraw capture fails closed with no legs.
assert_match "big reserve ok" "$(run_cobol "PHL_RESERVE|${ACCT}|99999.00|USD|||${A}")" "SUCCESS\|PHL_RESERVED"
HID2="$(db_query "SELECT id FROM payment_hold WHERE account_id=${ACCT} ORDER BY id DESC LIMIT 1;")"
assert_match "over-capture refused" "$(run_cobol "PHL_CAPTURE|${HID2}|||||${A}")" "ERROR\|INSUFFICIENT_FUNDS"
assert_match "no legs for failed capture" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='PHL-${HID2}';")" "^0$"
assert_match "failed hold stays ACTIVE" "$(db_query "SELECT status FROM payment_hold WHERE id=${HID2};")" "^ACTIVE$"

# 19-20. Missing suspense account fails closed with an explicit verdict;
# once ops creates it, the retry captures. (Deleting the suspense account
# cascades its credit leg, so the baseline below restarts from 0.)
db_exec "DELETE FROM ledger WHERE account_id=${CLR};"
db_exec "DELETE FROM accounts WHERE account_id=${CLR};"
assert_match "reserve for missing suspense" "$(run_cobol "PHL_RESERVE|${ACCT}|50.00|USD|||${A}")" "SUCCESS\|PHL_RESERVED"
HID3="$(db_query "SELECT id FROM payment_hold WHERE account_id=${ACCT} ORDER BY id DESC LIMIT 1;")"
assert_match "missing suspense refused" "$(run_cobol "PHL_CAPTURE|${HID3}|||||${A}")" "ERROR\|CLEARING_ACCOUNT_MISSING"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'CLEARING', 0 FROM users WHERE email='${A}';"
CLR="$(db_query "SELECT account_id FROM accounts WHERE account_type='CLEARING' AND currency_id=1;")"
assert_match "retry captures after ops fix" "$(run_cobol "PHL_CAPTURE|${HID3}|||||${A}")" "SUCCESS\|PHL_CAPTURED"
assert_match "customer at 850" "$(bal "$ACCT")" "^850.0000$"
assert_match "suspense restarted at 50" "$(bal "$CLR")" "^50.0000$"

# 21-23. Release stays state-only: no money moves.
assert_match "release reserve ok" "$(run_cobol "PHL_RESERVE|${ACCT}|10.00|USD|||${A}")" "SUCCESS\|PHL_RESERVED"
HID4="$(db_query "SELECT id FROM payment_hold WHERE account_id=${ACCT} ORDER BY id DESC LIMIT 1;")"
assert_match "release ok" "$(run_cobol "PHL_RELEASE|${HID4}|||||${A}")" "SUCCESS\|PHL_RELEASED"
assert_match "release posts no legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='PHL-${HID4}';")" "^0$"
assert_match "release moves no new money" "$(total2)" "^900.0000$"

# 24-30. Settle posts a balanced GL journal and links it.
assert_match "clearing create ok" "$(run_cobol "PMC_CREATE|${C}|300.00|USD|||${A}")" "SUCCESS\|PMC_CREATE"
CID="$(db_query "SELECT id FROM payment_clearing WHERE clearing_ref='${C}';")"
assert_match "clearing post ok" "$(run_cobol "PMC_POST|${CID}|300.00||||${A}")" "SUCCESS\|PMC_POST"
assert_match "settle 100 ok" "$(run_cobol "PMC_SETTLE|${CID}|100.00||||${A}")" "SUCCESS\|PMC_SETTLE"
assert_match "settle 100 again ok" "$(run_cobol "PMC_SETTLE|${CID}|100.00||||${A}")" "SUCCESS\|PMC_SETTLE"
assert_match "settled 200 still POSTED" "$(db_query "SELECT CONCAT(settled_amount,'|',status) FROM payment_clearing WHERE id=${CID};")" "^200.0000|POSTED$"
assert_match "two journals posted" "$(db_query "SELECT COUNT(*) FROM gl_journal WHERE description LIKE 'PMC_SETTLE:${C}:%';")" "^2$"
SJ="$(db_query "SELECT gl_journal_id FROM payment_clearing WHERE id=${CID};")"
assert_match "latest journal linked" "$(db_query "SELECT description FROM gl_journal WHERE id=${SJ};")" "^PMC_SETTLE:${C}:100.0000[+]100.0000$"
assert_match "linked journal balanced" "$(db_query "SELECT IF(SUM(debit_amount)=SUM(credit_amount),'BALANCED','UNBALANCED') FROM gl_journal_line WHERE journal_id=${SJ};")" "^BALANCED$"
assert_match "over-settle refused" "$(run_cobol "PMC_SETTLE|${CID}|200.00||||${A}")" "ERROR\|INVALID_AMOUNT"

# 31-33. Instruction executes through wallet_core: money moves, run logged.
assert_match "instruction create ok" "$(run_cobol "PIC_CREATE|PI-PST-1|${WA}|${WB}|25.00,USD|ONCE,2026-06-01,2026-06-01|${A}")" "SUCCESS\|PIC_CREATED"
assert_match "instruction execute ok" "$(run_cobol "PIC_EXECUTE|PI-PST-1|||||${A}")" "SUCCESS\|PIC_EXECUTED"
assert_match "execute moved money" "$(db_query "SELECT status FROM pending_transactions WHERE txn_ref LIKE 'PI-PI-PST-1-%' ORDER BY id DESC LIMIT 1;")" "^COMMITTED$"
assert_match "run recorded" "$(db_query "SELECT status FROM payment_instruction_run WHERE instruction_id=(SELECT id FROM payment_instruction WHERE instruction_code='PI-PST-1') ORDER BY id DESC LIMIT 1;")" "^COMPLETED$"

cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
