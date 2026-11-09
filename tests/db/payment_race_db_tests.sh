#!/usr/bin/env bash
# Payment races (Fase 3, payments 10/10): true parallel requests over
# separate DB connections (COBOL_TEST_SERVE=0, one process per call).
# Double capture of one hold debits exactly once; concurrent over-settles
# are refused by the atomic guard (settled never exceeds posted); double
# instruction execute moves money once; fan-out captures all land. Every
# journal stays balanced and no balance goes negative. Green twice required.
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

export COBOL_TEST_SERVE=0
db_seed
A="admin@test.com"
WA="prcA@test.com"
WB="prcB@test.com"
CUR="$(date +%Y-%m)"
run_cobol "GL_PERIOD_OPEN|${CUR}|||||${A}" >/dev/null

cleanup_fixture() {
    db_exec "DELETE FROM ledger WHERE txn_ref LIKE 'PHL-%' OR txn_ref LIKE 'PI-PRC-%';"
    db_exec "DELETE FROM journal_entries WHERE txn_ref LIKE 'PHL-%';"
    db_exec "DELETE FROM payment_hold WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')));"
    db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${WA}','${WB}') OR to_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM payment_instruction_run WHERE instruction_id IN (SELECT id FROM payment_instruction WHERE instruction_code LIKE 'PI-RC-%');"
    db_exec "DELETE FROM payment_instruction WHERE instruction_code LIKE 'PI-RC-%';"
    db_exec "DELETE FROM payment_clearing WHERE clearing_ref LIKE 'CLR-RC-%';"
    db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'PMC_SETTLE:CLR-RC-%');"
    db_exec "DELETE FROM gl_journal WHERE description LIKE 'PMC_SETTLE:CLR-RC-%';"
    db_exec "DELETE FROM velocity_counter WHERE account_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM velocity_profile WHERE profile_code LIKE 'PRC-V-%';"
    db_exec "DELETE FROM payment_policy WHERE currency_code='USD';"
    db_exec "DELETE FROM payment_profile WHERE user_email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE account_type='CLEARING' AND currency_id=1);"
    db_exec "DELETE FROM accounts WHERE account_type='CLEARING' AND currency_id=1;"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM users WHERE email IN ('${WA}','${WB}');"
}
cleanup_fixture
for U in "$WA" "$WB"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Prc Race|1990-01-01" >/dev/null
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
CLR="$(db_query "SELECT account_id FROM accounts WHERE account_type='CLEARING' AND currency_id=1;")"
TMPD="$(mktemp -d "${TMPDIR:-/tmp}/prc.XXXXXX")"
trap 'rm -rf "$TMPD"' EXIT
bal() { db_query "SELECT balance FROM accounts WHERE account_id=$1;"; }
balanced() { db_query "SELECT COUNT(*) FROM (SELECT l.journal_id FROM ledger l WHERE l.journal_id IS NOT NULL AND EXISTS (SELECT 1 FROM ledger x WHERE x.journal_id = l.journal_id AND x.account_id IN (${ACCT},${CLR})) GROUP BY l.journal_id HAVING ABS(SUM(CASE WHEN l.type='DEBIT' THEN l.amount ELSE -l.amount END)) > 0.0001) t;"; }

# 1-8. Double capture: exactly one wins, one debit, loser refused.
run_cobol "PHL_RESERVE|${ACCT}|100.00|USD|||${A}" >/dev/null
HID="$(db_query "SELECT id FROM payment_hold WHERE account_id=${ACCT} ORDER BY id DESC LIMIT 1;")"
run_cobol "PHL_CAPTURE|${HID}|||||${A}" >"$TMPD/capA.out" 2>&1 &
run_cobol "PHL_CAPTURE|${HID}|||||${A}" >"$TMPD/capB.out" 2>&1 &
wait
assert_match "exactly one capture wins" "$(grep -o "SUCCESS|PHL_CAPTURED" "$TMPD"/cap*.out | wc -l | tr -d ' ')" "^1$"
assert_match "loser refused" "$(cat "$TMPD"/cap*.out)" "ERROR\|INVALID_STATUS"
assert_match "single debit only" "$(bal "$ACCT")" "^900.0000$"
assert_match "single credit only" "$(bal "$CLR")" "^100.0000$"
assert_match "two legs only" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='PHL-${HID}';")" "^2$"
assert_match "hold captured once" "$(db_query "SELECT status FROM payment_hold WHERE id=${HID};")" "^CAPTURED$"
assert_match "capture journal balanced" "$(balanced)" "^0$"
assert_match "no negatives" "$(db_query "SELECT COUNT(*) FROM accounts WHERE account_id IN (${ACCT},${CLR}) AND balance < 0;")" "^0$"

# 9-15. Over-settle race: guard refuses the loser, settled stays exact.
run_cobol "PMC_CREATE|CLR-RC-1|100.00|USD|||${A}" >/dev/null
CID="$(db_query "SELECT id FROM payment_clearing WHERE clearing_ref='CLR-RC-1';")"
run_cobol "PMC_POST|${CID}|100.00||||${A}" >/dev/null
D1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; D2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'PMC_SETTLE|%s|100.00||||admin@test.com\n' "$CID" >"$D1/input.txt"
printf 'PMC_SETTLE|%s|100.00||||admin@test.com\n' "$CID" >"$D2/input.txt"
BIN="$PWD/cobol/bin/main_logic"
(cd "$D1" && timeout 30s "$BIN" >/dev/null 2>&1) &
P1=$!
(cd "$D2" && timeout 30s "$BIN" >/dev/null 2>&1) &
P2=$!
wait $P1; wait $P2
SA="$(tr -d ' \n' <"$D1/output.txt")"; SB="$(tr -d ' \n' <"$D2/output.txt")"
rm -rf "$D1" "$D2"
assert_match "exactly one settle wins" "$(printf '%s\n%s\n' "$SA" "$SB" | grep -c "SUCCESS|PMC_SETTLE")" "^1$"
assert_match "loser over-settle refused" "$(printf '%s\n%s\n' "$SA" "$SB")" "ERROR\|INVALID_AMOUNT"
assert_match "settled exact" "$(db_query "SELECT settled_amount FROM payment_clearing WHERE id=${CID};")" "^100.0000$"
assert_match "fully settled" "$(db_query "SELECT status FROM payment_clearing WHERE id=${CID};")" "^SETTLED$"
assert_match "winner linked" "$(db_query "SELECT gl_journal_id FROM payment_clearing WHERE id=${CID};")" "^[0-9]+$"
assert_match "winner journal balanced" "$(db_query "SELECT IF(SUM(debit_amount)=SUM(credit_amount),'BALANCED','UNBALANCED') FROM gl_journal_line WHERE journal_id=(SELECT gl_journal_id FROM payment_clearing WHERE id=${CID});")" "^BALANCED$"
assert_match "settle after full refused" "$(run_cobol "PMC_SETTLE|${CID}|1.00||||${A}")" "ERROR\|INVALID_STATUS"

# 16-19. Posted-but-unlinked retry re-links instead of double-posting.
# (Simulates the crash window: journal committed, linkage lost.)
run_cobol "PMC_CREATE|CLR-RC-2|200.00|USD|||${A}" >/dev/null
CID2="$(db_query "SELECT id FROM payment_clearing WHERE clearing_ref='CLR-RC-2';")"
run_cobol "PMC_POST|${CID2}|200.00||||${A}" >/dev/null
assert_match "first settle ok" "$(run_cobol "PMC_SETTLE|${CID2}|100.00||||${A}")" "SUCCESS\|PMC_SETTLE"
J1="$(db_query "SELECT gl_journal_id FROM payment_clearing WHERE id=${CID2};")"
db_exec "UPDATE payment_clearing SET settled_amount=0, gl_journal_id=NULL WHERE id=${CID2};"
assert_match "retry re-links" "$(run_cobol "PMC_SETTLE|${CID2}|100.00||||${A}")" "SUCCESS\|PMC_SETTLE"
assert_match "re-linked to same journal" "$(db_query "SELECT gl_journal_id FROM payment_clearing WHERE id=${CID2};")" "^${J1}$"
assert_match "no duplicate journal" "$(db_query "SELECT COUNT(*) FROM gl_journal WHERE description LIKE 'PMC_SETTLE:CLR-RC-2:%';")" "^1$"
assert_match "settled exact" "$(db_query "SELECT settled_amount FROM payment_clearing WHERE id=${CID2};")" "^100.0000$"

# 16-20. Double instruction execute: money moves once. The wallet transfer
# and the instruction bookkeeping are separate transactions, so a race
# loser is refused while the winner's verdict can occasionally be lost;
# a settle-up execute always converges (replay is a no-op for money).
run_cobol "PIC_CREATE|PI-RC-1|${WA}|${WB}|25.00,USD|ONCE,2026-06-01,2026-06-01|${A}" >/dev/null
run_cobol "PIC_EXECUTE|PI-RC-1|||||${A}" >"$TMPD/exA.out" 2>&1 &
run_cobol "PIC_EXECUTE|PI-RC-1|||||${A}" >"$TMPD/exB.out" 2>&1 &
wait
assert_match "settle-up execute converges" "$(run_cobol "PIC_EXECUTE|PI-RC-1|||||${A}")" "SUCCESS\|PIC_EXECUTED|ERROR\|INVALID_STATUS"
assert_match "instruction completed" "$(db_query "SELECT status FROM payment_instruction WHERE instruction_code='PI-RC-1';")" "^COMPLETED$"
assert_match "money moved once" "$(bal "$ACCT")" "^875.0000$"
assert_match "counterpart credited once" "$(db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${WB}') AND currency_id=1;")" "^1025.0000$"
assert_match "single receipt" "$(db_query "SELECT COUNT(*) FROM pending_transactions WHERE txn_ref LIKE 'PI-PI-RC-1-%';")" "^1$"

# 20-24. Fan-out: four parallel captures on four holds all land exactly.
for i in 1 2 3 4; do
    run_cobol "PHL_RESERVE|${ACCT}|10.00|USD|||${A}" >/dev/null
    H="$(db_query "SELECT id FROM payment_hold WHERE account_id=${ACCT} ORDER BY id DESC LIMIT 1;")"
    run_cobol "PHL_CAPTURE|${H}|||||${A}" >"$TMPD/fan-${i}.out" 2>&1 &
done
wait
assert_match "all four land" "$(grep -o "SUCCESS|PHL_CAPTURED" "$TMPD"/fan-*.out | wc -l | tr -d ' ')" "^4$"
assert_match "sender debited 40" "$(bal "$ACCT")" "^835.0000$"
assert_match "suspense credited 40" "$(bal "$CLR")" "^140.0000$"
assert_match "all journals balanced" "$(balanced)" "^0$"
assert_match "no negatives" "$(db_query "SELECT COUNT(*) FROM accounts WHERE account_id IN (${ACCT},${CLR}) AND balance < 0;")" "^0$"

if [ -n "$STRAY" ]; then
    # shellcheck disable=SC2086
    for P in $STRAY; do db_exec "UPDATE velocity_profile SET enabled=TRUE WHERE profile_code='${P}';"; done
fi
cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
