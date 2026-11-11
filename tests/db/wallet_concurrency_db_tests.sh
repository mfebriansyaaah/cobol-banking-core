#!/usr/bin/env bash
# Wallet concurrency races (toward 10/10): true parallel transfers over
# separate DB connections. run_cobol normally uses one persistent --serve
# server (one connection: requests serialize), so this suite forces file
# mode (COBOL_TEST_SERVE=0 — one process, one connection per call) and
# launches calls in background subshells. Proves: ordered locking never
# deadlocks under contention, same-key races debit exactly once, overdraw
# races fail closed without ever driving a balance negative, and every
# journal stays balanced. Green twice required.
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

# File mode: one process (one DB connection) per call. The persistent
# server would serialize every request on a single connection and the
# races below would never actually overlap.
export COBOL_TEST_SERVE=0
db_seed
WA="wltconA@test.com"
WB="wltconB@test.com"

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
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Wlt Con|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
    db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 1000.00 FROM users WHERE email='${U}';"
done
bal() { db_query "SELECT balance FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='$1') AND currency_id=1;"; }
net() { db_query "SELECT COALESCE(SUM(CASE WHEN type='CREDIT' THEN amount ELSE -amount END),0) FROM ledger WHERE account_id=(SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='$1') AND currency_id=1);"; }
neg() { db_query "SELECT COUNT(*) FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')) AND balance < 0;"; }
unbalanced_journals() { db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'))) AND journal_id IS NOT NULL GROUP BY journal_id HAVING ABS(SUM(CASE WHEN type='DEBIT' THEN amount ELSE -amount END)) > 0.0001) t;"; }
reset_race() {
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}')));"
    db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${WA}','${WB}') OR to_email IN ('${WA}','${WB}');"
    db_exec "UPDATE accounts SET balance = 1000.00 WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
}
TMPD="$(mktemp -d "${TMPDIR:-/tmp}/wltcon.XXXXXX")"
trap 'rm -rf "$TMPD"' EXIT

# 1. Opposing transfers overlap in time: ordered locking must not deadlock,
# and both atomic movements must land (net zero for each account).
run_cobol "TRANSFER|${WA}|${WB}|100.00|WLTCC-1|||" >"$TMPD/r1a.out" 2>&1 &
run_cobol "TRANSFER|${WB}|${WA}|100.00|WLTCC-2|||" >"$TMPD/r1b.out" 2>&1 &
wait
assert_match "opposing race A wins" "$(cat "$TMPD/r1a.out")" "SUCCESS\|TRANSFER_OK"
assert_match "opposing race B wins" "$(cat "$TMPD/r1b.out")" "SUCCESS\|TRANSFER_OK"
assert_match "A back to 1000" "$(bal "$WA")" "^1000.0000$"
assert_match "B back to 1000" "$(bal "$WB")" "^1000.0000$"
assert_match "A ledger net zero" "$(net "$WA")" "^0.0000$"
assert_match "B ledger net zero" "$(net "$WB")" "^0.0000$"
assert_match "two intents recorded" "$(db_query "SELECT COUNT(*) FROM pending_transactions WHERE txn_ref IN ('WLTCC-1','WLTCC-2');")" "^2$"

# 2. Overdraw race: two concurrent 800 debits against 1000. Exactly one may
# win; the loser must fail closed and no balance may ever go negative.
reset_race
run_cobol "TRANSFER|${WA}|${WB}|800.00|WLTCC-3|||" >"$TMPD/r2a.out" 2>&1 &
run_cobol "TRANSFER|${WA}|${WB}|800.00|WLTCC-4|||" >"$TMPD/r2b.out" 2>&1 &
wait
assert_match "exactly one overdraw wins" "$(printf '%s\n%s\n' "$(cat "$TMPD/r2a.out")" "$(cat "$TMPD/r2b.out")" | grep -c "SUCCESS|TRANSFER_OK")" "^1$"
assert_match "loser refused" "$(cat "$TMPD/r2a.out" "$TMPD/r2b.out")" "ERROR\|INSUFFICIENT_FUNDS"
assert_match "sender left with 200" "$(bal "$WA")" "^200.0000$"
assert_match "receiver got 800" "$(bal "$WB")" "^1800.0000$"
assert_match "sender net -800" "$(net "$WA")" "^-800.0000$"
assert_match "receiver net +800" "$(net "$WB")" "^800.0000$"
assert_match "no negative balance" "$(neg)" "^0$"

# 3. Same-key race: two concurrent submissions of one intent. Exactly one
# effect; the loser is refused, never a second debit.
# 3. Same-key race: two concurrent submissions of one intent. Exactly one
# EFFECT, never a second debit. The second caller may observe the intent
# while it is still PENDING (ERROR|TRANSFER_IN_PROGRESS) or after COMMIT
# (idempotent replay returns SUCCESS|TRANSFER_OK). Both are correct, so the
# assertions below pin the invariant (single effect) instead of the timing.
reset_race
run_cobol "TRANSFER|${WA}|${WB}|50.00|WLTCC-5|||" >"$TMPD/r3a.out" 2>&1 &
run_cobol "TRANSFER|${WA}|${WB}|50.00|WLTCC-5|||" >"$TMPD/r3b.out" 2>&1 &
wait
SAME_KEY_OUT="$(printf '%s\n%s\n' "$(cat "$TMPD/r3a.out")" "$(cat "$TMPD/r3b.out")")"
assert_match "same-key answers success or clean refusal" \
    "$(printf '%s\n' "$SAME_KEY_OUT" | grep -cE '^(SUCCESS\|TRANSFER_OK|ERROR\|TRANSFER_IN_PROGRESS)$')" "^2$"
assert_match "same-key has one or two successes (two = idempotent replay)" \
    "$(printf '%s\n' "$SAME_KEY_OUT" | grep -c "SUCCESS|TRANSFER_OK")" "^[12]$"
assert_match "same-key has no DB error" \
    "$(printf '%s\n' "$SAME_KEY_OUT" | grep -c "ERROR|DB_ERROR")" "^0$"
assert_match "single debit only" "$(bal "$WA")" "^950.0000$"
assert_match "single credit only" "$(bal "$WB")" "^1050.0000$"
assert_match "single intent row" "$(db_query "SELECT COUNT(*) FROM pending_transactions WHERE txn_ref='WLTCC-5';")" "^1$"

# 4. Fan-out: eight parallel debits, distinct keys. All must land exactly.
reset_race
for i in 1 2 3 4 5 6 7 8; do
    run_cobol "TRANSFER|${WA}|${WB}|10.00|WLTCC-6${i}|||" >"$TMPD/r4-${i}.out" 2>&1 &
done
wait
assert_match "all eight land" "$(cat "$TMPD"/r4-*.out | grep -o "SUCCESS|TRANSFER_OK" | wc -l | tr -d ' ')" "^8$"
assert_match "sender 920" "$(bal "$WA")" "^920.0000$"
assert_match "receiver 1080" "$(bal "$WB")" "^1080.0000$"
assert_match "sender net -80" "$(net "$WA")" "^-80.0000$"
assert_match "receiver net +80" "$(net "$WB")" "^80.0000$"

# 5. Every journal touching fixture accounts nets to zero, always.
assert_match "all journals balanced" "$(unbalanced_journals)" "^0$"
assert_match "no negative balance" "$(neg)" "^0$"

cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
