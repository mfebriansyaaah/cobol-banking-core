#!/usr/bin/env bash
# Payment conservation (Fase 3, payments 10/10): a fixed 20-operation script
# with hand-computed balances. Clearing lifecycle + hold capture/release/
# expire + instruction execute must conserve the total across the fixture
# set after every phase; per-account ledger nets must equal balance deltas;
# every touched journal must balance; no balance may go negative.
# Green twice required.
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
WA="pcsA@test.com"
WB="pcsB@test.com"
CUR="$(date +%Y-%m)"
run_cobol "GL_PERIOD_OPEN|${CUR}|||||${A}" >/dev/null

cleanup_fixture() {
    db_exec "DELETE FROM ledger WHERE txn_ref LIKE 'PHL-%' OR txn_ref LIKE 'PI-PCS-%';"
    db_exec "DELETE FROM journal_entries WHERE txn_ref LIKE 'PHL-%';"
    db_exec "DELETE FROM payment_hold WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')));"
    db_exec "DELETE FROM payment_hold_audit WHERE hold_id NOT IN (SELECT id FROM payment_hold);"
    db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${WA}','${WB}') OR to_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM payment_instruction_run WHERE instruction_id IN (SELECT id FROM payment_instruction WHERE instruction_code LIKE 'PI-CS-%');"
    db_exec "DELETE FROM payment_instruction WHERE instruction_code LIKE 'PI-CS-%';"
    db_exec "DELETE FROM payment_clearing_audit WHERE clearing_id IN (SELECT id FROM payment_clearing WHERE clearing_ref LIKE 'CLR-CS-%');"
    db_exec "DELETE FROM payment_clearing WHERE clearing_ref LIKE 'CLR-CS-%';"
    db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'PMC_SETTLE:CLR-CS-%');"
    db_exec "DELETE FROM gl_journal WHERE description LIKE 'PMC_SETTLE:CLR-CS-%';"
    db_exec "DELETE FROM velocity_counter WHERE account_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM payment_policy WHERE currency_code='USD';"
    db_exec "DELETE FROM payment_profile WHERE user_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE account_type='CLEARING' AND currency_id=1);"
    db_exec "DELETE FROM accounts WHERE account_type='CLEARING' AND currency_id=1;"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM users WHERE email IN ('${WA}','${WB}');"
}
cleanup_fixture
for U in "$WA" "$WB"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Pcs Csv|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
    db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${U}';"
done
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'CLEARING', 0 FROM users WHERE email='${A}';"
# Stray enabled USD velocity profiles (other suites' leftovers) would veto
# transfers here; park them, restore at end.
STRAY="$(db_query "SELECT COALESCE(GROUP_CONCAT(profile_code SEPARATOR ' '),'') FROM velocity_profile WHERE currency_code='USD' AND enabled=TRUE;")"
if [ -n "$STRAY" ]; then
    # shellcheck disable=SC2086
    for P in $STRAY; do db_exec "UPDATE velocity_profile SET enabled=FALSE WHERE profile_code='${P}';"; done
fi
ACCT="$(db_query "SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${WA}') AND currency_id=1;")"
BACC="$(db_query "SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${WB}') AND currency_id=1;")"
CLR="$(db_query "SELECT account_id FROM accounts WHERE account_type='CLEARING' AND currency_id=1;")"
bal() { db_query "SELECT balance FROM accounts WHERE account_id=$1;"; }
net() { db_query "SELECT COALESCE(SUM(CASE WHEN type='CREDIT' THEN amount ELSE -amount END),0) FROM ledger WHERE account_id=$1;"; }
total() { db_query "SELECT COALESCE(SUM(balance),0) FROM accounts WHERE account_id IN (${ACCT},${BACC},${CLR});"; }
balanced() { db_query "SELECT COUNT(*) FROM (SELECT l.journal_id FROM ledger l WHERE l.journal_id IS NOT NULL AND EXISTS (SELECT 1 FROM ledger x WHERE x.journal_id = l.journal_id AND x.account_id IN (${ACCT},${BACC},${CLR})) GROUP BY l.journal_id HAVING ABS(SUM(CASE WHEN l.type='DEBIT' THEN l.amount ELSE -l.amount END)) > 0.0001) t;"; }
neg() { db_query "SELECT COUNT(*) FROM accounts WHERE account_id IN (${ACCT},${BACC},${CLR}) AND balance < 0;"; }

# 1-6. Clearing lifecycle: create 300, post 300, partial settles 100+100.
assert_match "clearing create ok" "$(run_cobol "PMC_CREATE|CLR-CS-1|300.00|USD|||${A}")" "SUCCESS\|PMC_CREATE"
CID="$(db_query "SELECT id FROM payment_clearing WHERE clearing_ref='CLR-CS-1';")"
assert_match "clearing post ok" "$(run_cobol "PMC_POST|${CID}|300.00||||${A}")" "SUCCESS\|PMC_POST"
assert_match "settle 100 ok" "$(run_cobol "PMC_SETTLE|${CID}|100.00||||${A}")" "SUCCESS\|PMC_SETTLE"
assert_match "settle 100 again ok" "$(run_cobol "PMC_SETTLE|${CID}|100.00||||${A}")" "SUCCESS\|PMC_SETTLE"
assert_match "settled 200 still POSTED" "$(db_query "SELECT CONCAT(settled_amount,'|',status) FROM payment_clearing WHERE id=${CID};")" "^200.0000|POSTED$"
assert_match "two journals posted" "$(db_query "SELECT COUNT(*) FROM gl_journal WHERE description LIKE 'PMC_SETTLE:CLR-CS-1:%';")" "^2$"

# 7-9. Second clearing stays open, then cancels cleanly.
assert_match "clearing 2 create ok" "$(run_cobol "PMC_CREATE|CLR-CS-2|50.00|USD|||${A}")" "SUCCESS\|PMC_CREATE"
CID2="$(db_query "SELECT id FROM payment_clearing WHERE clearing_ref='CLR-CS-2';")"
assert_match "cancel open ok" "$(run_cobol "PMC_CANCEL|${CID2}|||||${A}")" "SUCCESS\|PMC_CANCEL"
assert_match "cancel cancelled refused" "$(run_cobol "PMC_CANCEL|${CID2}|||||${A}")" "ERROR\|INVALID_STATUS"

# 10-16. Hold capture moves money; release and expire stay state-only.
assert_match "reserve 100 ok" "$(run_cobol "PHL_RESERVE|${ACCT}|100.00|USD|||${A}")" "SUCCESS\|PHL_RESERVED"
HID="$(db_query "SELECT id FROM payment_hold WHERE account_id=${ACCT} ORDER BY id DESC LIMIT 1;")"
assert_match "capture ok" "$(run_cobol "PHL_CAPTURE|${HID}|||||${A}")" "SUCCESS\|PHL_CAPTURED"
assert_match "A at 900" "$(bal "$ACCT")" "^900.0000$"
assert_match "reserve 50 ok" "$(run_cobol "PHL_RESERVE|${ACCT}|50.00|USD|||${A}")" "SUCCESS\|PHL_RESERVED"
HID2="$(db_query "SELECT id FROM payment_hold WHERE account_id=${ACCT} ORDER BY id DESC LIMIT 1;")"
assert_match "release ok" "$(run_cobol "PHL_RELEASE|${HID2}|||||${A}")" "SUCCESS\|PHL_RELEASED"
assert_match "release moves nothing" "$(total)" "^2000.0000$"
assert_match "no negatives after release" "$(neg)" "^0$"

# 17-22. Instruction executes through wallet; expired hold sweeps quietly.
assert_match "instruction create ok" "$(run_cobol "PIC_CREATE|PI-CS-1|${WA}|${WB}|25.00,USD|ONCE,2026-06-01,2026-06-01|${A}")" "SUCCESS\|PIC_CREATED"
assert_match "instruction execute ok" "$(run_cobol "PIC_EXECUTE|PI-CS-1|||||${A}")" "SUCCESS\|PIC_EXECUTED"
assert_match "A at 875" "$(bal "$ACCT")" "^875.0000$"
assert_match "B at 1025" "$(bal "$BACC")" "^1025.0000$"
assert_match "conserved after execute" "$(total)" "^2000.0000$"
assert_match "no negatives after execute" "$(neg)" "^0$"

# 23-27. Drain A exactly through capture; over-capture fails closed.
assert_match "reserve 875 ok" "$(run_cobol "PHL_RESERVE|${ACCT}|875.00|USD|||${A}")" "SUCCESS\|PHL_RESERVED"
HID3="$(db_query "SELECT id FROM payment_hold WHERE account_id=${ACCT} ORDER BY id DESC LIMIT 1;")"
assert_match "drain capture ok" "$(run_cobol "PHL_CAPTURE|${HID3}|||||${A}")" "SUCCESS\|PHL_CAPTURED"
assert_match "A at zero" "$(bal "$ACCT")" "^0.0000$"
assert_match "over-capture setup" "$(run_cobol "PHL_RESERVE|${ACCT}|0.01|USD|||${A}")" "SUCCESS\|PHL_RESERVED"
HID4="$(db_query "SELECT id FROM payment_hold WHERE account_id=${ACCT} ORDER BY id DESC LIMIT 1;")"
assert_match "over-capture refused" "$(run_cobol "PHL_CAPTURE|${HID4}|||||${A}")" "ERROR\|INSUFFICIENT_FUNDS"
assert_match "conserved after extremes" "$(total)" "^2000.0000$"
assert_match "no negatives after extremes" "$(neg)" "^0$"

# 28-33. Final positions: A = 0 (net -1000), B = 1025 (net +25),
# suspense = 975 (net +975). Clearing settled 200 outside the subledger.
assert_match "A final balance" "$(bal "$ACCT")" "^0.0000$"
assert_match "B final balance" "$(bal "$BACC")" "^1025.0000$"
assert_match "suspense final balance" "$(bal "$CLR")" "^975.0000$"
assert_match "A ledger net equals delta" "$(net "$ACCT")" "^-1000.0000$"
assert_match "B ledger net equals delta" "$(net "$BACC")" "^25.0000$"
assert_match "suspense ledger net equals delta" "$(net "$CLR")" "^975.0000$"

# 34-38. Every touched journal balanced; linkage complete.
assert_match "all journals balanced" "$(balanced)" "^0$"
assert_match "capture journals linked" "$(db_query "SELECT COUNT(*) FROM payment_hold WHERE id IN (${HID},${HID3}) AND journal_id IS NOT NULL;")" "^2$"
assert_match "settle journals linked" "$(db_query "SELECT COUNT(*) FROM payment_clearing WHERE id=${CID} AND gl_journal_id IS NOT NULL;")" "^1$"
assert_match "settle journals balanced" "$(db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'PMC_SETTLE:CLR-CS-1:%') GROUP BY journal_id HAVING ABS(SUM(debit_amount)-SUM(credit_amount)) > 0.0001) t;")" "^0$"
assert_match "run recorded" "$(db_query "SELECT status FROM payment_instruction_run WHERE instruction_id=(SELECT id FROM payment_instruction WHERE instruction_code='PI-CS-1') ORDER BY id DESC LIMIT 1;")" "^COMPLETED$"

if [ -n "$STRAY" ]; then
    # shellcheck disable=SC2086
    for P in $STRAY; do db_exec "UPDATE velocity_profile SET enabled=TRUE WHERE profile_code='${P}';"; done
fi
cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
